class_name BenchmarkRunner
extends RefCounted
## Stress test: spawns N buildings + cables + transit items, then measures performance.
## Usage: main.gd calls run() after scene is ready. Triggered by --benchmark or F7 in dev mode.

const TILE: int = 64
const REPORT_PATH: String = "user://benchmark_report.txt"

var _building_mgr: Node = null
var _conn_mgr: Node = null
var _grid_sys: Node2D = null
var _sim_mgr: Node = null
var _tree: SceneTree = null

## How many rows/columns of chains to create
var chain_count: int = 20        ## Number of parallel chains
var chain_length: int = 10       ## Buildings per chain
var transit_per_cable: int = 3   ## Transit items injected per cable

## Stats
var total_buildings: int = 0
var total_connections: int = 0
var total_transit: int = 0

## Auto-report: collect N frames then write report
var _auto_report: bool = false
var _warmup_frames: int = 60     ## Skip first N frames (warmup)
var _sample_frames: int = 300    ## Collect N frames of data
var _frame_counter: int = 0
var _samples: Array[Dictionary] = []


func setup(building_mgr: Node, conn_mgr: Node, grid_sys: Node2D, sim_mgr: Node) -> void:
	_building_mgr = building_mgr
	_conn_mgr = conn_mgr
	_grid_sys = grid_sys
	_sim_mgr = sim_mgr
	_tree = building_mgr.get_tree()


func run(auto_report: bool = false) -> void:
	if _building_mgr == null:
		push_error("[Benchmark] Not initialized — call setup() first")
		return
	_auto_report = auto_report
	print("[Benchmark] Starting stress test — %d chains × %d buildings" % [chain_count, chain_length])
	var t0: int = Time.get_ticks_msec()

	var splitter_def: BuildingDefinition = load("res://resources/buildings/splitter.tres")
	var merger_def: BuildingDefinition = load("res://resources/buildings/merger.tres")
	var trash_def: BuildingDefinition = load("res://resources/buildings/trash.tres")

	# Place buildings far from center (offset 100,100 in grid space) to avoid tutorial area
	var base_x: int = 100
	var base_y: int = 100
	# Spacing: splitter/merger are 1x1, leave 2 cells gap for cable routing
	var h_spacing: int = 3  # horizontal spacing between buildings in a chain
	var v_spacing: int = 3  # vertical spacing between chains

	var all_buildings: Array = []  # [chain_idx][building_idx]

	# --- Phase 1: Place buildings ---
	for chain_i in range(chain_count):
		var row: Array = []
		var cy: int = base_y + chain_i * v_spacing
		for b_i in range(chain_length):
			var cx: int = base_x + b_i * h_spacing
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
				push_warning("[Benchmark] Failed to place at (%d,%d)" % [cx, cy])
				row.append(null)
		all_buildings.append(row)

	# --- Phase 2: Connect buildings in chains ---
	for chain_i in range(chain_count):
		var row: Array = all_buildings[chain_i]
		var cy: int = base_y + chain_i * v_spacing
		for b_i in range(chain_length - 1):
			var from_b: Node2D = row[b_i]
			var to_b: Node2D = row[b_i + 1]
			if from_b == null or to_b == null:
				continue
			var from_port: String = "right"
			var to_port: String = "left"
			# Build path: right edge of from_b → left edge of to_b
			var from_x: int = base_x + b_i * h_spacing
			var to_x: int = base_x + (b_i + 1) * h_spacing
			# Path vertices: from building right side → to building left side
			# For 1x1 buildings: right side vertex = (from_x+1, cy), left side = (to_x, cy)
			var from_size: Vector2i = from_b.definition.grid_size
			var path: Array[Vector2i] = []
			var start_vx: int = from_x + from_size.x
			var end_vx: int = to_x
			# Straight horizontal path
			for vx in range(start_vx, end_vx + 1):
				path.append(Vector2i(vx, cy))
			if _conn_mgr.add_connection(from_b, from_port, to_b, to_port, path):
				total_connections += 1

	# --- Phase 3: Inject transit items ---
	var conns: Array = _conn_mgr.get_connections()
	for conn in conns:
		if not conn.has("transit"):
			conn["transit"] = []
		for t_i in range(transit_per_cable):
			var item: Dictionary = {
				"key": "0_0_0_0",  # Standard Public — DataEnums.make_key(0,0,0,0)
				"content": 0,
				"state": 0,  # Public
				"tier": 0,
				"tags": 0,
				"amount": 1,
				"t": float(t_i) / maxf(transit_per_cable, 1)  # Spread along cable
			}
			conn["transit"].append(item)
			total_transit += 1

	var elapsed: int = Time.get_ticks_msec() - t0
	print("[Benchmark] Setup complete in %dms" % elapsed)
	print("[Benchmark]   Buildings: %d" % total_buildings)
	print("[Benchmark]   Connections: %d" % total_connections)
	print("[Benchmark]   Transit items: %d" % total_transit)

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
	report += "Buildings: %d | Connections: %d | Transit injected: %d\n" % [total_buildings, total_connections, total_transit]
	report += "Warmup: %d frames | Sampled: %d frames\n\n" % [_warmup_frames, _samples.size()]

	# Calculate averages
	var keys: Array = ["frame_sim_us", "sim_cache_us", "sim_transit_us", "sim_deliver_us",
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
	report += "Sim total:            %.0f us\n" % (sums["frame_sim_us"] / n)
	report += "  Cache rebuild:      %.0f us\n" % (sums["sim_cache_us"] / n)
	report += "  Transit advance:    %.0f us\n" % (sums["sim_transit_us"] / n)
	report += "  Deliver arrived:    %.0f us\n" % (sums["sim_deliver_us"] / n)
	report += "Connection draw:      %.0f us\n" % (sums["conn_draw_us"] / n)
	report += "  Transit items draw: %.0f us\n" % (sums["conn_draw_items_us"] / n)
	report += "Grid draw:            %.0f us\n" % (sums["grid_draw_us"] / n)
	report += "  PCB pattern:        %.0f us\n" % (sums["grid_pcb_us"] / n)
	report += "Building draw:        %.0f us\n" % (sums["bldg_draw_us"] / n)
	report += "Buildings drawn/frame: %.0f\n" % (sums["bldg_draw_count"] / n)
	report += "Connections:          %.0f\n" % (sums["sim_connections"] / n)
	report += "Transit items:        %.0f\n" % (sums["sim_transit_items"] / n)

	report += "\n--- PEAKS (worst frame) ---\n"
	report += "Sim total:            %.0f us\n" % maxes["frame_sim_us"]
	report += "Connection draw:      %.0f us\n" % maxes["conn_draw_us"]
	report += "Grid draw:            %.0f us\n" % maxes["grid_draw_us"]
	report += "Building draw:        %.0f us\n" % maxes["bldg_draw_us"]

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
	return "Buildings: %d | Connections: %d | Transit: %d\nSim: %.0fus | Grid: %.0fus | Cables: %.0fus | Bldg: %.0fus" % [
		total_buildings, total_connections, total_transit,
		PerfMonitor.frame_sim_us, PerfMonitor.grid_draw_us,
		PerfMonitor.conn_draw_us, PerfMonitor.bldg_draw_us
	]
