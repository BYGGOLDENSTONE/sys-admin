class_name BenchmarkRunner
extends RefCounted
## Stress test: spawns sources + buildings + cables, then measures real data flow performance.
## Each chain starts from an ISP Backbone source — real generation, transit, delivery.
## Usage: F7 in game, or --benchmark CLI arg.

const TILE: int = 64
const REPORT_PATH: String = "user://benchmark_report.txt"

var _building_mgr: Node = null
var _conn_mgr: Node = null
var _grid_sys: Node2D = null
var _sim_mgr: Node = null
var _source_mgr: Node = null
var _tree: SceneTree = null

## Test scale
var chain_count: int = 100       ## Number of parallel chains (each with its own source)
var chain_length: int = 10       ## Buildings per chain (after source)

## Stats
var total_sources: int = 0
var total_buildings: int = 0
var total_connections: int = 0

## Auto-report: collect N frames then write report
var _auto_report: bool = false
var _warmup_frames: int = 60     ## Skip first N frames (warmup)
var _sample_frames: int = 300    ## Collect N frames of data
var _frame_counter: int = 0
var _samples: Array[Dictionary] = []


func setup(building_mgr: Node, conn_mgr: Node, grid_sys: Node2D, sim_mgr: Node, source_mgr: Node = null) -> void:
	_building_mgr = building_mgr
	_conn_mgr = conn_mgr
	_grid_sys = grid_sys
	_sim_mgr = sim_mgr
	_source_mgr = source_mgr
	_tree = building_mgr.get_tree()


func run(auto_report: bool = false) -> void:
	if _building_mgr == null:
		push_error("[Benchmark] Not initialized — call setup() first")
		return
	_auto_report = auto_report
	print("[Benchmark] Starting stress test — %d chains × %d buildings + sources" % [chain_count, chain_length])
	var t0: int = Time.get_ticks_msec()

	var isp_def: DataSourceDefinition = load("res://resources/sources/isp_backbone.tres")
	var splitter_def: BuildingDefinition = load("res://resources/buildings/splitter.tres")
	var merger_def: BuildingDefinition = load("res://resources/buildings/merger.tres")
	var trash_def: BuildingDefinition = load("res://resources/buildings/trash.tres")

	# Place far from tutorial area
	var base_x: int = 120
	var base_y: int = 120
	# ISP Backbone is 2x2, buildings are 1x1
	# Layout per chain: [Source 2x2] gap [Bldg] gap [Bldg] ... [Trash]
	var h_spacing: int = 3   # horizontal spacing between buildings
	var v_spacing: int = 4   # vertical spacing between chains (source is 2x2 so need 4)
	var source_gap: int = 4  # gap from source right edge to first building

	# --- Phase 1: Place sources + buildings ---
	var all_sources: Array = []
	var all_buildings: Array = []  # [chain_idx][building_idx]

	for chain_i in range(chain_count):
		var cy: int = base_y + chain_i * v_spacing

		# Place ISP Backbone source at chain start
		var source_cell := Vector2i(base_x, cy)
		var source: Node2D = null
		if _source_mgr:
			source = _source_mgr.place_source(isp_def, source_cell)
		if source:
			total_sources += 1
			all_sources.append(source)
		else:
			all_sources.append(null)

		# Place buildings after source
		var row: Array = []
		var bldg_start_x: int = base_x + isp_def.grid_size.x + source_gap
		for b_i in range(chain_length):
			var cx: int = bldg_start_x + b_i * h_spacing
			var def: BuildingDefinition
			if b_i == chain_length - 1:
				def = trash_def
			elif b_i % 2 == 0:
				def = splitter_def
			else:
				def = merger_def
			var building: Node2D = _building_mgr.place_building_at(def, Vector2i(cx, cy))
			if building:
				row.append(building)
				total_buildings += 1
			else:
				row.append(null)
		all_buildings.append(row)

	# --- Phase 2: Connect source → first building ---
	for chain_i in range(chain_count):
		var source: Node2D = all_sources[chain_i]
		var row: Array = all_buildings[chain_i]
		if source == null or row.is_empty() or row[0] == null:
			continue

		var cy: int = base_y + chain_i * v_spacing
		var first_bldg: Node2D = row[0]

		# Source right_0 port → first building left port
		# Source is 2x2 at (base_x, cy), right edge at base_x+2
		# First building at bldg_start_x
		var source_right_x: int = base_x + isp_def.grid_size.x
		var bldg_start_x: int = base_x + isp_def.grid_size.x + source_gap
		# Path: straight horizontal from source right edge to building left edge
		var path: Array[Vector2i] = []
		# Source right_0 port exit vertex
		var start_vx: int = source_right_x + 1
		var end_vx: int = bldg_start_x
		# Y vertex: source right_0 port is at y offset ~0.5 of source height
		var path_vy: int = cy + 1  # middle of 2x2 source
		for vx in range(start_vx, end_vx + 1):
			path.append(Vector2i(vx, path_vy))
		if path.size() >= 2:
			if _conn_mgr.add_connection(source, "right_0", first_bldg, "left", path):
				total_connections += 1

	# --- Phase 3: Connect buildings in chains ---
	for chain_i in range(chain_count):
		var row: Array = all_buildings[chain_i]
		var cy: int = base_y + chain_i * v_spacing
		var bldg_start_x: int = base_x + isp_def.grid_size.x + source_gap
		for b_i in range(chain_length - 1):
			var from_b: Node2D = row[b_i]
			var to_b: Node2D = row[b_i + 1]
			if from_b == null or to_b == null:
				continue
			var from_x: int = bldg_start_x + b_i * h_spacing
			var to_x: int = bldg_start_x + (b_i + 1) * h_spacing
			var from_size: Vector2i = from_b.definition.grid_size
			var path: Array[Vector2i] = []
			var start_vx: int = from_x + from_size.x
			var end_vx: int = to_x
			for vx in range(start_vx, end_vx + 1):
				path.append(Vector2i(vx, cy))
			if path.size() >= 2:
				if _conn_mgr.add_connection(from_b, "right", to_b, "left", path):
					total_connections += 1

	var elapsed: int = Time.get_ticks_msec() - t0
	print("[Benchmark] Setup complete in %dms" % elapsed)
	print("[Benchmark]   Sources: %d" % total_sources)
	print("[Benchmark]   Buildings: %d" % total_buildings)
	print("[Benchmark]   Connections: %d" % total_connections)
	print("[Benchmark]   Data flow: REAL (sources generate every tick)")

	if _auto_report:
		print("[Benchmark] Auto-report: %d warmup + %d sample frames, then quit" % [_warmup_frames, _sample_frames])
		_tree.process_frame.connect(_on_frame)
	else:
		print("[Benchmark] Monitor 'sysadmin/*' in Godot Profiler > Monitors tab")


func _on_frame() -> void:
	_frame_counter += 1
	if _frame_counter <= _warmup_frames:
		return
	# Collect sample
	_samples.append({
		"frame_sim_us": PerfMonitor.frame_sim_us,
		"sim_cache_us": PerfMonitor.sim_cache_us,
		"sim_transit_us": PerfMonitor.sim_transit_us,
		"sim_deliver_us": PerfMonitor.sim_deliver_us,
		"sim_tick_us": PerfMonitor.sim_tick_us,
		"conn_draw_us": PerfMonitor.conn_draw_us,
		"conn_draw_items_us": PerfMonitor.conn_draw_items_us,
		"grid_draw_us": PerfMonitor.grid_draw_us,
		"grid_pcb_us": PerfMonitor.grid_pcb_us,
		"bldg_draw_us": PerfMonitor.bldg_draw_us,
		"bldg_draw_count": PerfMonitor.bldg_draw_count,
		"sim_connections": PerfMonitor.sim_connections,
		"sim_transit_items": PerfMonitor.sim_transit_items,
		"fps": Engine.get_frames_per_second(),
	})
	if _samples.size() >= _sample_frames:
		_tree.process_frame.disconnect(_on_frame)
		_write_report()
		_tree.quit()


func _write_report() -> void:
	var report: String = "=== SYS_ADMIN Benchmark Report ===\n"
	report += "Date: %s\n" % Time.get_datetime_string_from_system()
	report += "Sources: %d | Buildings: %d | Connections: %d\n" % [total_sources, total_buildings, total_connections]
	report += "Data flow: REAL (source generation + transit + delivery)\n"
	report += "Warmup: %d frames | Sampled: %d frames\n\n" % [_warmup_frames, _samples.size()]

	# Calculate averages
	var keys: Array = ["frame_sim_us", "sim_cache_us", "sim_transit_us", "sim_deliver_us", "sim_tick_us",
		"conn_draw_us", "conn_draw_items_us", "grid_draw_us", "grid_pcb_us",
		"bldg_draw_us", "bldg_draw_count", "sim_connections", "sim_transit_items", "fps"]
	var sums: Dictionary = {}
	var maxes: Dictionary = {}
	for k in keys:
		sums[k] = 0.0
		maxes[k] = 0.0
	for s in _samples:
		for k in keys:
			sums[k] += s[k]
			maxes[k] = maxf(maxes[k], s[k])

	var n: float = _samples.size()
	report += "--- AVERAGES (per frame) ---\n"
	report += "FPS:                  %.1f (min: %.1f)\n" % [sums["fps"] / n, _min_val("fps")]
	report += "Sim total (frame):    %.0f us\n" % (sums["frame_sim_us"] / n)
	report += "  Cache rebuild:      %.0f us\n" % (sums["sim_cache_us"] / n)
	report += "  Transit advance:    %.0f us\n" % (sums["sim_transit_us"] / n)
	report += "  Deliver arrived:    %.0f us\n" % (sums["sim_deliver_us"] / n)
	report += "Sim tick:             %.0f us\n" % (sums["sim_tick_us"] / n)
	report += "Connection draw:      %.0f us\n" % (sums["conn_draw_us"] / n)
	report += "  Transit items draw: %.0f us\n" % (sums["conn_draw_items_us"] / n)
	report += "Grid draw:            %.0f us\n" % (sums["grid_draw_us"] / n)
	report += "  PCB pattern:        %.0f us\n" % (sums["grid_pcb_us"] / n)
	report += "Building draw:        %.0f us\n" % (sums["bldg_draw_us"] / n)
	report += "Buildings drawn/frame: %.0f\n" % (sums["bldg_draw_count"] / n)
	report += "Connections:          %.0f\n" % (sums["sim_connections"] / n)
	report += "Transit items:        %.0f\n" % (sums["sim_transit_items"] / n)

	report += "\n--- PEAKS (worst frame) ---\n"
	report += "Sim total (frame):    %.0f us\n" % maxes["frame_sim_us"]
	report += "Sim tick:             %.0f us\n" % maxes["sim_tick_us"]
	report += "Connection draw:      %.0f us\n" % maxes["conn_draw_us"]
	report += "Grid draw:            %.0f us\n" % maxes["grid_draw_us"]
	report += "Building draw:        %.0f us\n" % maxes["bldg_draw_us"]
	report += "Transit items:        %.0f (peak)\n" % maxes["sim_transit_items"]

	# Write to file
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(report)
		file.close()
		var real_path: String = ProjectSettings.globalize_path(REPORT_PATH)
		print("[Benchmark] Report written to: %s" % real_path)
		print(report)
	else:
		print("[Benchmark] ERROR: Could not write report file")
		print(report)


func _min_val(key: String) -> float:
	var m: float = INF
	for s in _samples:
		m = minf(m, s[key])
	return m


func get_summary() -> String:
	return "Sources: %d | Buildings: %d | Connections: %d\nTransit: %d items | Sim: %.0fus | Grid: %.0fus | Cables: %.0fus | Bldg: %.0fus | FPS: %d" % [
		total_sources, total_buildings, total_connections,
		PerfMonitor.sim_transit_items,
		PerfMonitor.frame_sim_us, PerfMonitor.grid_draw_us,
		PerfMonitor.conn_draw_us, PerfMonitor.bldg_draw_us,
		Engine.get_frames_per_second()
	]
