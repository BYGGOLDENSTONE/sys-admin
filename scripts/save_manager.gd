extends Node

## Save/Load system for SYS_ADMIN demo.
## JSON-based save format with autosave and backup support.

const SAVE_VERSION: int = 4
const SAVE_DIR: String = "user://saves/"
const MAX_SLOTS: int = 5
const AUTOSAVE_INTERVAL: float = 300.0  ## 5 minutes

signal game_saved()
signal game_loaded()
signal save_failed(reason: String)

var building_container: Node2D = null
var connection_manager: Node = null
var source_manager: Node = null
var gig_manager: Node = null
var simulation_manager: Node = null
var current_seed: int = 0
var current_slot: int = 1  ## Active save slot (1-based)
var map_generator: RefCounted = null  ## For chunk save/load

var _autosave_timer: Timer = null


static func slot_path(slot: int) -> String:
	return "user://saves/slot_%d.json" % slot


static func slot_auto_path(slot: int) -> String:
	return "user://saves/slot_%d_auto.json" % slot


static func list_slots() -> Array[Dictionary]:
	## Returns metadata for all slots: [{slot, exists, seed, timestamp, version}]
	var result: Array[Dictionary] = []
	for i in range(1, MAX_SLOTS + 1):
		var path: String = slot_path(i)
		var auto_path: String = slot_auto_path(i)
		var info: Dictionary = {"slot": i, "exists": false}
		# Try main save, fallback to autosave
		for p in [path, auto_path]:
			if FileAccess.file_exists(p):
				var data: Dictionary = load_from_file(p)
				if not data.is_empty() and not data.get("_incompatible", false):
					info["exists"] = true
					info["seed"] = data.get("seed", 0)
					info["timestamp"] = data.get("timestamp", "")
					info["version"] = data.get("version", 0)
					var net: Dictionary = data.get("network", {})
					info["network_connected"] = int(net.get("connected", 0))
					info["network_total"] = int(net.get("total", 0))
					break
		result.append(info)
	return result


func setup_autosave() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = false
	_autosave_timer.timeout.connect(_on_autosave_tick)
	add_child(_autosave_timer)
	var interval: int = SettingsManager.get_settings().get("autosave_interval", 300)
	update_autosave_interval(interval)


func update_autosave_interval(seconds: int) -> void:
	if _autosave_timer == null:
		return
	if seconds <= 0:
		_autosave_timer.stop()
		print("[SaveManager] Autosave disabled")
	else:
		_autosave_timer.wait_time = float(seconds)
		_autosave_timer.start()
		print("[SaveManager] Autosave interval — %ds" % seconds)


func _on_autosave_tick() -> void:
	autosave()


## --- PUBLIC API ---

func save_game(path: String = "") -> bool:
	if path == "":
		path = slot_path(current_slot)
	var data: Dictionary = capture_state()
	data["slot"] = current_slot
	return _write_save(path, data)


func autosave() -> bool:
	var data: Dictionary = capture_state()
	data["slot"] = current_slot
	var ok: bool = _write_save(slot_auto_path(current_slot), data)
	if ok:
		print("[SaveManager] Autosave complete — slot %d" % current_slot)
	return ok


func has_save(path: String = "") -> bool:
	if path == "":
		path = slot_path(current_slot)
	return FileAccess.file_exists(path)


func has_any_save() -> bool:
	for i in range(1, MAX_SLOTS + 1):
		if FileAccess.file_exists(slot_path(i)) or FileAccess.file_exists(slot_auto_path(i)):
			return true
	return false


static func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[SaveManager] Save file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Cannot open save file: %s" % path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("[SaveManager] JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {}
	var data: Dictionary = json.data
	if not data.has("version"):
		push_error("[SaveManager] Invalid save file — missing version")
		return {}
	var file_version: int = int(data.version)
	# Migrate older save versions forward instead of rejecting them
	if file_version < SAVE_VERSION:
		data = _migrate_save(data, file_version)
	print("[SaveManager] Save loaded — version: %d, seed: %s" % [file_version, str(data.get("seed", "?"))])
	return data


## --- STATE CAPTURE ---

func capture_state() -> Dictionary:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"seed": current_seed,
	}
	data["simulation"] = _capture_simulation()
	data["buildings"] = _capture_buildings()
	data["connections"] = _capture_connections()
	data["gigs"] = _capture_gigs()
	data["network"] = _capture_network()
	if map_generator:
		data["generated_chunks"] = map_generator.get_generated_chunk_keys()
	return data


func _capture_simulation() -> Dictionary:
	if simulation_manager == null:
		return {}
	var dc: Dictionary = {}
	for k in simulation_manager.discovered_content:
		dc[str(k)] = simulation_manager.discovered_content[k]
	var ds: Dictionary = {}
	for k in simulation_manager.discovered_states:
		ds[str(k)] = simulation_manager.discovered_states[k]
	return {
		"tick_count": simulation_manager._tick_count,
		"speed_multiplier": simulation_manager.speed_multiplier,
		"is_paused": simulation_manager.is_paused,
		"discovered_content": dc,
		"discovered_states": ds,
	}


func _capture_buildings() -> Array:
	if building_container == null:
		return []
	var result: Array = []
	for building in building_container.get_children():
		if building.definition == null:
			continue
		var entry: Dictionary = {
			"name": building.definition.building_name,
			"cell_x": building.grid_cell.x,
			"cell_y": building.grid_cell.y,
			"direction": building.direction,
			"mirror_h": building.mirror_h,
			"stored_data": building.stored_data.duplicate(),
			"classifier_filter_content": building.classifier_filter_content,
			"separator_mode": building.separator_mode,
			"separator_filter_value": building.separator_filter_value,
			"selected_tier": building.selected_tier,
			"upgrade_level": building.upgrade_level,
			"blocked_ports": building.blocked_ports.duplicate(),
			"port_carried_types": _serialize_port_carried_types(building.port_carried_types),
		}
		result.append(entry)
	return result


func _serialize_port_carried_types(pct: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for port in pct:
		var inner: Dictionary = {}
		for tk in pct[port]:
			inner[str(tk)] = true
		out[port] = inner
	return out


func _deserialize_port_carried_types(saved: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for port in saved:
		var inner: Dictionary = {}
		for tk_str in saved[port]:
			inner[int(tk_str)] = true
		out[port] = inner
	return out


func _capture_connections() -> Array:
	if connection_manager == null:
		return []
	var result: Array = []
	for conn in connection_manager.get_connections():
		var path_arr: Array = []
		for v in conn.path:
			path_arr.append([v.x, v.y])
		var is_source: bool = conn.from_building.definition is DataSourceDefinition
		result.append({
			"from_x": conn.from_building.grid_cell.x,
			"from_y": conn.from_building.grid_cell.y,
			"from_port": conn.from_port,
			"from_source": is_source,
			"to_x": conn.to_building.grid_cell.x,
			"to_y": conn.to_building.grid_cell.y,
			"to_port": conn.to_port,
			"path": path_arr,
		})
	return result


func _capture_gigs() -> Dictionary:
	if gig_manager == null:
		return {}
	var completed: Array = []
	for idx in gig_manager._completed_indices:
		completed.append(idx)
	var progress: Dictionary = {}
	for idx in gig_manager._progress:
		progress[str(idx)] = gig_manager._progress[idx]
	var unlocked: Array = []
	for b_name in gig_manager._unlocked_buildings:
		unlocked.append(b_name)
	var active: Array = []
	for gig in gig_manager._active_gigs:
		active.append(gig.order_index)
	return {
		"completed": completed,
		"progress": progress,
		"unlocked": unlocked,
		"active": active,
		"tutorials_complete": gig_manager._tutorials_complete,
		"procedural_count": gig_manager._procedural_count,
		"next_order_index": gig_manager._next_order_index,
	}


func _capture_network() -> Dictionary:
	if source_manager == null:
		return {"connected": 0, "total": 0}
	var all_sources: Array[Node2D] = source_manager.get_all_sources()
	var total: int = all_sources.size()
	var connected: int = 0
	if connection_manager != null:
		for source in all_sources:
			for conn in connection_manager.connections:
				if conn.from_building == source:
					connected += 1
					break
	return {"connected": connected, "total": total}


## --- STATE RESTORE ---

func apply_state(data: Dictionary) -> bool:
	if data.is_empty() or not data.has("version"):
		push_error("[SaveManager] Invalid save data")
		return false

	# 0. Restore generated chunks (regenerates sources from seed)
	if map_generator and data.has("generated_chunks"):
		map_generator.restore_chunks(data["generated_chunks"])

	# 1. Place saved buildings
	var building_map: Dictionary = _restore_buildings(data.get("buildings", []))

	# 2. Restore connections
	_restore_connections(data.get("connections", []), building_map)

	# 3. Restore gig state
	_restore_gigs(data.get("gigs", {}))

	# 4. Restore simulation state
	_restore_simulation(data.get("simulation", {}))

	game_loaded.emit()
	print("[SaveManager] Game state restored")
	return true


func _restore_buildings(buildings_data: Array) -> Dictionary:
	## Returns building_map: "x_y" → building Node2D (for connection restore)
	var building_map: Dictionary = {}
	if building_container == null:
		return building_map

	var grid_system: Node2D = building_container.get_parent().get_node("GridSystem")
	var bm: Node = building_container.get_parent().get_node("BuildingManager")

	for entry in buildings_data:
		var def_name: String = entry.get("name", "")
		if def_name.is_empty():
			continue

		var cell := Vector2i(int(entry.get("cell_x", 0)), int(entry.get("cell_y", 0)))
		var def: BuildingDefinition = _load_building_def(def_name)
		if def == null:
			push_warning("[SaveManager] Unknown building: %s" % def_name)
			continue

		# Place building using BuildingManager API
		var building: Node2D = bm.place_building_at(def, cell)
		if building == null:
			push_warning("[SaveManager] Failed to place %s at (%d,%d)" % [def_name, cell.x, cell.y])
			continue

		# Restore runtime state
		building.direction = int(entry.get("direction", 0))
		building.mirror_h = entry.get("mirror_h", false)
		building.classifier_filter_content = int(entry.get("classifier_filter_content", 0))
		building.separator_mode = entry.get("separator_mode", "state")
		building.separator_filter_value = int(entry.get("separator_filter_value", 0))
		building.selected_tier = int(entry.get("selected_tier", 1))
		building.upgrade_level = int(entry.get("upgrade_level", 0))

		# Restore stored data (packed int keys)
		var saved_data: Dictionary = entry.get("stored_data", {})
		building.stored_data.clear()
		for key in saved_data:
			building.stored_data[int(key)] = int(saved_data[key])

		# Restore CT port purity state
		var saved_blocked: Dictionary = entry.get("blocked_ports", {})
		if not saved_blocked.is_empty():
			building.blocked_ports = saved_blocked.duplicate()
		var saved_pct: Dictionary = entry.get("port_carried_types", {})
		if not saved_pct.is_empty():
			building.port_carried_types = _deserialize_port_carried_types(saved_pct)

		var map_key: String = "%d_%d" % [cell.x, cell.y]
		building_map[map_key] = building

	return building_map


func _restore_connections(connections_data: Array, building_map: Dictionary) -> void:
	if connection_manager == null:
		return

	var grid_system: Node2D = building_map.values()[0].get_parent().get_parent().get_node("GridSystem") if not building_map.is_empty() else null

	for entry in connections_data:
		var from_key: String = "%d_%d" % [int(entry.get("from_x", 0)), int(entry.get("from_y", 0))]
		var to_key: String = "%d_%d" % [int(entry.get("to_x", 0)), int(entry.get("to_y", 0))]
		var from_building: Node2D = building_map.get(from_key, null)
		# If from_building not found, try looking up as a data source
		if from_building == null and grid_system != null:
			var from_cell := Vector2i(int(entry.get("from_x", 0)), int(entry.get("from_y", 0)))
			from_building = grid_system.get_source_at(from_cell)
		var to_building: Node2D = building_map.get(to_key, null)
		if from_building == null or to_building == null:
			push_warning("[SaveManager] Connection skipped — node not found: %s → %s" % [from_key, to_key])
			continue
		var from_port: String = entry.get("from_port", "right")
		var to_port: String = entry.get("to_port", "left")
		var path_raw: Array = entry.get("path", [])
		var path: Array[Vector2i] = []
		for v in path_raw:
			if v is Array and v.size() >= 2:
				path.append(Vector2i(int(v[0]), int(v[1])))
		if path.size() < 2:
			push_warning("[SaveManager] Connection skipped — invalid path")
			continue
		connection_manager.add_connection(from_building, from_port, to_building, to_port, path)


func _restore_gigs(gig_data: Dictionary) -> void:
	if gig_manager == null:
		return

	# Clear current state
	gig_manager._active_gigs.clear()
	gig_manager._completed_indices.clear()
	gig_manager._progress.clear()
	# Reset unlocked to starters only
	gig_manager._unlocked_buildings.clear()
	for b_name in gig_manager._starter_buildings:
		gig_manager._unlocked_buildings[b_name] = true

	# Restore completed indices
	var completed: Array = gig_data.get("completed", [])
	for idx in completed:
		gig_manager._completed_indices[int(idx)] = true

	# Restore unlocked buildings
	var unlocked: Array = gig_data.get("unlocked", [])
	for b_name in unlocked:
		gig_manager._unlocked_buildings[b_name] = true

	# Restore progress
	var progress: Dictionary = gig_data.get("progress", {})
	for idx_str in progress:
		var arr: Array = progress[idx_str]
		var int_arr: Array = []
		for val in arr:
			int_arr.append(int(val))
		gig_manager._progress[int(idx_str)] = int_arr

	# Validate progress array sizes against current gig definitions
	for gig in gig_manager._all_gigs:
		if gig_manager._progress.has(gig.order_index):
			var arr: Array = gig_manager._progress[gig.order_index]
			var req_size: int = gig.requirements.size()
			if arr.size() < req_size:
				for _i in range(req_size - arr.size()):
					arr.append(0)
			elif arr.size() > req_size:
				arr.resize(req_size)

	# Restore active gigs (cast to int for JSON type safety)
	var active_indices: Dictionary = {}
	for idx in gig_data.get("active", []):
		active_indices[int(idx)] = true
	for gig in gig_manager._all_gigs:
		if active_indices.has(gig.order_index):
			gig_manager._active_gigs.append(gig)

	# Restore procedural state
	gig_manager._tutorials_complete = gig_data.get("tutorials_complete", false)
	gig_manager._procedural_count = int(gig_data.get("procedural_count", 0))
	gig_manager._next_order_index = int(gig_data.get("next_order_index", 100))

	# If tutorials complete and no active gigs, generate procedural
	if gig_manager._tutorials_complete and gig_manager._active_gigs.is_empty():
		gig_manager._fill_procedural_gigs()

	print("[SaveManager] Gig state restored — %d completed, %d active" % [
		gig_manager._completed_indices.size(), gig_manager._active_gigs.size()])


func _restore_simulation(sim_data: Dictionary) -> void:
	if simulation_manager == null:
		return
	simulation_manager._tick_count = int(sim_data.get("tick_count", 0))
	var speed: int = int(sim_data.get("speed_multiplier", 1))
	simulation_manager.set_speed(speed)
	# Always start unpaused after load — pause menu save captures forced pause state

	# Restore discovery
	var dc: Dictionary = sim_data.get("discovered_content", {})
	for k in dc:
		simulation_manager.discovered_content[int(k)] = dc[k]
	var ds: Dictionary = sim_data.get("discovered_states", {})
	for k in ds:
		simulation_manager.discovered_states[int(k)] = ds[k]


## --- MIGRATION ---

static func _migrate_save(data: Dictionary, from_version: int) -> Dictionary:
	## Migrate older save formats forward to current SAVE_VERSION.
	if from_version < 2:
		# v1 → v2: add missing direction/mirror_h fields to buildings
		var buildings: Array = data.get("buildings", [])
		for entry in buildings:
			if not entry.has("direction"):
				entry["direction"] = 0
			if not entry.has("mirror_h"):
				entry["mirror_h"] = false
			if not entry.has("upgrade_level"):
				entry["upgrade_level"] = 0
		# Filter out removed buildings (Uplink, Bridge)
		var filtered: Array = []
		for entry in buildings:
			var bname: String = entry.get("name", "")
			if bname == "Uplink" or bname == "Bridge":
				continue
			filtered.append(entry)
		data["buildings"] = filtered
		# Filter out connections referencing removed buildings
		var removed_cells: Dictionary = {}
		for entry in buildings:
			var bname: String = entry.get("name", "")
			if bname == "Uplink" or bname == "Bridge":
				var key: String = "%d_%d" % [int(entry.get("cell_x", 0)), int(entry.get("cell_y", 0))]
				removed_cells[key] = true
		if not removed_cells.is_empty():
			var filtered_conns: Array = []
			for conn in data.get("connections", []):
				var from_key: String = "%d_%d" % [int(conn.get("from_x", 0)), int(conn.get("from_y", 0))]
				var to_key: String = "%d_%d" % [int(conn.get("to_x", 0)), int(conn.get("to_y", 0))]
				if removed_cells.has(from_key) or removed_cells.has(to_key):
					continue
				filtered_conns.append(conn)
			data["connections"] = filtered_conns
		# Remove legacy unlocked buildings
		var gigs: Dictionary = data.get("gigs", {})
		if gigs.has("unlocked"):
			var clean_unlocked: Array = []
			for b_name in gigs["unlocked"]:
				if b_name != "Uplink" and b_name != "Bridge":
					clean_unlocked.append(b_name)
			gigs["unlocked"] = clean_unlocked
		data["version"] = 2
		print("[SaveManager] Migrated save v1 → v2")
	if from_version < 3:
		# v2 → v3: infinite map with chunk-based generation
		# No generated_chunks in old saves — they'll be regenerated from initial area + camera
		data["version"] = 3
		print("[SaveManager] Migrated save v2 → v3")
	return data


## --- HELPERS ---

func _write_save(path: String, data: Dictionary) -> bool:
	# Ensure save directory exists
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var json_text: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var err_msg: String = "Cannot write save file: %s" % path
		push_error("[SaveManager] %s" % err_msg)
		save_failed.emit(err_msg)
		return false
	file.store_string(json_text)
	file.close()
	game_saved.emit()
	print("[SaveManager] Game saved — %s" % path)
	return true


static func _load_building_def(building_name: String) -> BuildingDefinition:
	var file_name: String = building_name.to_lower().replace(" ", "_")
	var path: String = "res://resources/buildings/%s.tres" % file_name
	if not ResourceLoader.exists(path):
		push_warning("[SaveManager] Building definition not found: %s" % path)
		return null
	return load(path) as BuildingDefinition
