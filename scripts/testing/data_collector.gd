extends Node

var simulation_manager: Node = null
var building_container: Node2D = null
var connection_manager: Node = null

var _snapshots: Array[Dictionary] = []
var _tick_count: int = 0
var _collect_every_n: int = 1
var _is_collecting: bool = false
var _session_id: String = ""


func start_collecting(every_n_ticks: int = 1) -> void:
	_collect_every_n = every_n_ticks
	_tick_count = 0
	_snapshots.clear()
	_session_id = Time.get_datetime_string_from_system().replace(":", "-")
	_is_collecting = true
	print("[DataCollector] Started — every %d ticks, session: %s" % [every_n_ticks, _session_id])


func stop_collecting() -> void:
	_is_collecting = false
	print("[DataCollector] Stopped — %d snapshots collected" % _snapshots.size())


func _on_tick_completed(tick: int) -> void:
	if not _is_collecting:
		return
	_tick_count = tick
	if _tick_count % _collect_every_n == 0:
		take_snapshot()


func take_snapshot(label: String = "") -> void:
	var snap: Dictionary = {
		"tick": _tick_count,
		"timestamp_ms": Time.get_ticks_msec(),
		"label": label,
		"credits": simulation_manager.total_credits,
		"buildings": _snapshot_buildings(),
		"connections": _snapshot_connections(),
		"global": _snapshot_global_stats(),
	}
	_snapshots.append(snap)


func _snapshot_buildings() -> Array:
	var result: Array = []
	for child in building_container.get_children():
		if not child.has_method("is_active"):
			continue
		var def: Resource = child.definition
		result.append({
			"name": def.building_name,
			"type": def.visual_type,
			"cell": [child.grid_cell.x, child.grid_cell.y],
			"heat": child.current_heat,
			"heat_max": def.max_heat,
			"is_overheated": child.is_overheated,
			"has_power": child.has_power,
			"is_active": child.is_active(),
			"is_working": child.is_working,
			"stored_data": child.stored_data.duplicate(),
			"total_stored": child.get_total_stored(),
			"storage_capacity": def.get_storage_capacity(),
		})
	return result


func _snapshot_connections() -> Array:
	var result: Array = []
	for conn in connection_manager.get_connections():
		result.append({
			"from": conn.from_building.definition.building_name,
			"from_cell": [conn.from_building.grid_cell.x, conn.from_building.grid_cell.y],
			"from_port": conn.from_port,
			"to": conn.to_building.definition.building_name,
			"to_cell": [conn.to_building.grid_cell.x, conn.to_building.grid_cell.y],
			"to_port": conn.to_port,
		})
	return result


func _snapshot_global_stats() -> Dictionary:
	var total_heat: float = 0.0
	var total_stored: int = 0
	var overheated_count: int = 0
	var unpowered_count: int = 0
	var working_count: int = 0
	var building_count: int = 0

	for child in building_container.get_children():
		if not child.has_method("is_active"):
			continue
		building_count += 1
		total_heat += child.current_heat
		total_stored += child.get_total_stored()
		if child.is_overheated:
			overheated_count += 1
		if not child.has_power:
			unpowered_count += 1
		if child.is_working:
			working_count += 1

	return {
		"building_count": building_count,
		"connection_count": connection_manager.get_connections().size(),
		"total_heat": total_heat,
		"total_stored": total_stored,
		"overheated_count": overheated_count,
		"unpowered_count": unpowered_count,
		"working_count": working_count,
	}


func save_to_file(scenario_name: String = "manual") -> String:
	var dir_path: String = "user://test_results/"
	DirAccess.make_dir_recursive_absolute(dir_path)

	var filename: String = "%s_%s.json" % [scenario_name, _session_id]
	var full_path: String = dir_path + filename

	var output: Dictionary = {
		"scenario": scenario_name,
		"session_id": _session_id,
		"total_ticks": _tick_count,
		"snapshot_count": _snapshots.size(),
		"snapshots": _snapshots,
	}

	var file := FileAccess.open(full_path, FileAccess.WRITE)
	if file == null:
		push_error("[DataCollector] Cannot write: %s" % full_path)
		return ""
	file.store_string(JSON.stringify(output, "  "))
	file.close()

	var abs_path: String = ProjectSettings.globalize_path(full_path)
	print("[DataCollector] Saved — %s (%d snapshots)" % [abs_path, _snapshots.size()])
	return abs_path


func get_snapshots() -> Array[Dictionary]:
	return _snapshots
