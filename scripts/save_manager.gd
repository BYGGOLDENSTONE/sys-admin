extends Node

## Save/Load system for SYS_ADMIN demo.
## JSON-based save format with autosave and backup support.

const SAVE_VERSION: int = 2
const SAVE_DIR: String = "user://saves/"
const SAVE_FILE: String = "user://saves/savegame.json"
const AUTOSAVE_FILE: String = "user://saves/autosave.json"
const AUTOSAVE_BACKUP: String = "user://saves/autosave_backup.json"
const AUTOSAVE_INTERVAL: float = 300.0  ## 5 minutes

signal game_saved()
signal game_loaded()
signal save_failed(reason: String)

var building_container: Node2D = null
var connection_manager: Node = null
var source_manager: Node = null
var gig_manager: Node = null
var simulation_manager: Node = null
var fog_layer: Node2D = null
var current_seed: int = 0

var _autosave_timer: Timer = null


func setup_autosave() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL
	_autosave_timer.one_shot = false
	_autosave_timer.timeout.connect(_on_autosave_tick)
	add_child(_autosave_timer)
	_autosave_timer.start()
	print("[SaveManager] Autosave initialized — interval: %.0fs" % AUTOSAVE_INTERVAL)


func _on_autosave_tick() -> void:
	autosave()


## --- PUBLIC API ---

func save_game(path: String = SAVE_FILE) -> bool:
	var data: Dictionary = capture_state()
	return _write_save(path, data)


func autosave() -> bool:
	# Rotate: current autosave → backup, then write new
	if FileAccess.file_exists(AUTOSAVE_FILE):
		if FileAccess.file_exists(AUTOSAVE_BACKUP):
			DirAccess.remove_absolute(AUTOSAVE_BACKUP)
		DirAccess.rename_absolute(AUTOSAVE_FILE, AUTOSAVE_BACKUP)
	var data: Dictionary = capture_state()
	var ok: bool = _write_save(AUTOSAVE_FILE, data)
	if ok:
		print("[SaveManager] Autosave complete")
	return ok


func has_save(path: String = SAVE_FILE) -> bool:
	return FileAccess.file_exists(path)


func has_any_save() -> bool:
	return has_save(SAVE_FILE) or has_save(AUTOSAVE_FILE)


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
	if file_version < SAVE_VERSION:
		push_warning("[SaveManager] Incompatible save — version %d, expected %d" % [file_version, SAVE_VERSION])
		return {"_incompatible": true, "version": file_version}
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
	data["sources"] = _capture_sources()
	data["gigs"] = _capture_gigs()
	data["fog"] = _capture_fog()
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
			"stored_data": building.stored_data.duplicate(),
			"classifier_filter_content": building.classifier_filter_content,
			"separator_mode": building.separator_mode,
			"separator_filter_value": building.separator_filter_value,
			"selected_tier": building.selected_tier,
			"upgrade_level": building.upgrade_level,
		}
		result.append(entry)
	return result


func _capture_connections() -> Array:
	if connection_manager == null:
		return []
	var result: Array = []
	for conn in connection_manager.get_connections():
		var path_arr: Array = []
		for v in conn.path:
			path_arr.append([v.x, v.y])
		result.append({
			"from_x": conn.from_building.grid_cell.x,
			"from_y": conn.from_building.grid_cell.y,
			"from_port": conn.from_port,
			"to_x": conn.to_building.grid_cell.x,
			"to_y": conn.to_building.grid_cell.y,
			"to_port": conn.to_port,
			"path": path_arr,
		})
	return result


func _capture_sources() -> Dictionary:
	if source_manager == null:
		return {}
	var result: Dictionary = {}
	for source in source_manager.get_all_sources():
		var key: String = "%d_%d" % [source.grid_cell.x, source.grid_cell.y]
		result[key] = source.discovered
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
	}


func _capture_fog() -> Array:
	if fog_layer == null:
		return []
	var result: Array = []
	for chunk_key in fog_layer._explored:
		result.append([chunk_key.x, chunk_key.y])
	return result


## --- STATE RESTORE ---

func apply_state(data: Dictionary) -> bool:
	if data.is_empty() or not data.has("version"):
		push_error("[SaveManager] Invalid save data")
		return false

	# 1. Restore source discovery (before buildings so auto-link works)
	_restore_sources(data.get("sources", {}))

	# 2. Restore fog (before buildings to avoid re-exploration flash)
	_restore_fog(data.get("fog", []))

	# 3. Place saved buildings
	var building_map: Dictionary = _restore_buildings(data.get("buildings", []))

	# 4. Restore connections
	_restore_connections(data.get("connections", []), building_map)

	# 5. Restore gig state
	_restore_gigs(data.get("gigs", {}))

	# 6. Restore simulation state
	_restore_simulation(data.get("simulation", {}))

	game_loaded.emit()
	print("[SaveManager] Game state restored")
	return true


func _restore_sources(source_data: Dictionary) -> void:
	if source_manager == null:
		return
	for source in source_manager.get_all_sources():
		var key: String = "%d_%d" % [source.grid_cell.x, source.grid_cell.y]
		if source_data.has(key):
			if source_data[key] and not source.discovered:
				source.discovered = true
			elif not source_data[key] and source.discovered:
				source.discovered = false


func _restore_fog(fog_data: Array) -> void:
	if fog_layer == null:
		return
	fog_layer._explored.clear()
	for entry in fog_data:
		if entry is Array and entry.size() >= 2:
			fog_layer._explored[Vector2i(int(entry[0]), int(entry[1]))] = true


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
		var building: Node2D = bm.place_building_at(def, cell, true)
		if building == null:
			push_warning("[SaveManager] Failed to place %s at (%d,%d)" % [def_name, cell.x, cell.y])
			continue

		# Restore runtime state
		building.direction = int(entry.get("direction", 0))
		building.classifier_filter_content = int(entry.get("classifier_filter_content", 0))
		building.separator_mode = entry.get("separator_mode", "state")
		building.separator_filter_value = int(entry.get("separator_filter_value", 0))
		building.selected_tier = int(entry.get("selected_tier", 1))
		building.upgrade_level = int(entry.get("upgrade_level", 0))

		# Restore stored data
		var saved_data: Dictionary = entry.get("stored_data", {})
		building.stored_data.clear()
		for key in saved_data:
			building.stored_data[key] = int(saved_data[key])

		var map_key: String = "%d_%d" % [cell.x, cell.y]
		building_map[map_key] = building

	return building_map


func _restore_connections(connections_data: Array, building_map: Dictionary) -> void:
	if connection_manager == null:
		return

	for entry in connections_data:
		var from_key: String = "%d_%d" % [int(entry.get("from_x", 0)), int(entry.get("from_y", 0))]
		var to_key: String = "%d_%d" % [int(entry.get("to_x", 0)), int(entry.get("to_y", 0))]
		var from_building: Node2D = building_map.get(from_key, null)
		var to_building: Node2D = building_map.get(to_key, null)
		if from_building == null or to_building == null:
			push_warning("[SaveManager] Connection skipped — building not found: %s → %s" % [from_key, to_key])
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

	# Migration pass: activate any gigs whose prerequisites are now met
	# but weren't in the save (e.g. new gigs added after save was created)
	gig_manager._check_wave_activations()

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
