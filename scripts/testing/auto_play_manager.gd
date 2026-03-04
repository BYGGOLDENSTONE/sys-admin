extends Node

signal scenario_started(scenario_name: String)
signal scenario_finished(scenario_name: String, success: bool)
signal action_executed(action: Dictionary)

var building_manager: Node = null
var connection_manager: Node = null
var simulation_manager: Node = null
var data_collector: Node = null
var source_manager: Node = null

var _scenario: Dictionary = {}
var _actions: Array = []
var _action_index: int = 0
var _is_running: bool = false
var _wait_ticks_remaining: int = 0
var _tick_count: int = 0

# Building references by scenario ID
var _building_refs: Dictionary = {}

# Definition cache (loaded once per name)
var _def_cache: Dictionary = {}


func run_scenario_from_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[AutoPlay] Cannot open: %s" % path)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("[AutoPlay] JSON parse error: %s" % json.get_error_message())
		return
	run_scenario(json.data)


func run_scenario(scenario: Dictionary) -> void:
	_scenario = scenario
	_actions = scenario.get("actions", [])
	_action_index = 0
	_wait_ticks_remaining = 0
	_tick_count = 0
	_building_refs.clear()
	_is_running = true
	var sname: String = scenario.get("name", "unnamed")
	scenario_started.emit(sname)
	print("[AutoPlay] Scenario started — %s (%d actions)" % [sname, _actions.size()])
	# Execute immediate actions (before first wait)
	_execute_next_actions()


func stop_scenario() -> void:
	_is_running = false
	print("[AutoPlay] Scenario stopped manually")


func is_running() -> bool:
	return _is_running


func _on_tick_completed(tick: int) -> void:
	if not _is_running:
		return
	_tick_count = tick

	if _wait_ticks_remaining > 0:
		_wait_ticks_remaining -= 1
		if _wait_ticks_remaining <= 0:
			_execute_next_actions()


func _execute_next_actions() -> void:
	while _action_index < _actions.size():
		var action: Dictionary = _actions[_action_index]
		_action_index += 1

		var action_type: String = action.get("action", "")
		var handler_name: String = "_handle_" + action_type

		if has_method(handler_name):
			var result: bool = call(handler_name, action)
			action_executed.emit(action)
			if not result:
				_finish_scenario(false)
				return
			# wait_ticks pauses execution until ticks pass
			if action_type == "wait_ticks":
				return
		else:
			push_error("[AutoPlay] Unknown action: %s" % action_type)
			_finish_scenario(false)
			return

	# All actions completed
	_finish_scenario(true)


func _finish_scenario(success: bool) -> void:
	_is_running = false
	var sname: String = _scenario.get("name", "unnamed")
	if success:
		print("[AutoPlay] Scenario PASSED — %s (ticks: %d)" % [sname, _tick_count])
	else:
		push_error("[AutoPlay] Scenario FAILED — %s at action %d" % [sname, _action_index])
	scenario_finished.emit(sname, success)


# --- ACTION HANDLERS ---

func _handle_place(action: Dictionary) -> bool:
	var def := _load_definition(action.get("building", ""))
	if def == null:
		push_error("[AutoPlay] Unknown building: %s" % action.get("building", ""))
		return false
	var cell_arr: Array = action.get("cell", [0, 0])
	var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
	var building: Node2D = building_manager.place_building_at(def, cell)
	if building == null:
		return false
	var id: String = action.get("id", "")
	if id != "":
		_building_refs[id] = building
	return true


func _handle_connect(action: Dictionary) -> bool:
	var from_b: Node2D = _building_refs.get(action.get("from", ""))
	var to_b: Node2D = _building_refs.get(action.get("to", ""))
	if from_b == null or to_b == null:
		push_error("[AutoPlay] Invalid building refs: %s -> %s" % [action.get("from", ""), action.get("to", "")])
		return false
	return connection_manager.add_connection(
		from_b, action.get("from_port", "right"),
		to_b, action.get("to_port", "left")
	)


func _handle_wait_ticks(action: Dictionary) -> bool:
	_wait_ticks_remaining = int(action.get("count", 1))
	return true


func _handle_remove(action: Dictionary) -> bool:
	var id: String = action.get("id", "")
	var building: Node2D = _building_refs.get(id)
	if building == null:
		push_error("[AutoPlay] No building ref: %s" % id)
		return false
	var cell: Vector2i = building.grid_cell
	var result: bool = building_manager.remove_building_at(cell)
	if result:
		_building_refs.erase(id)
	return result


func _handle_snapshot(action: Dictionary) -> bool:
	if data_collector:
		data_collector.take_snapshot(action.get("label", "manual"))
	return true


func _handle_assert(action: Dictionary) -> bool:
	var check: String = action.get("check", "")
	var result: bool = false
	match check:
		"credits_gt":
			result = simulation_manager.total_credits > action.get("value", 0)
		"credits_lt":
			result = simulation_manager.total_credits < action.get("value", 0)
		"building_active":
			var b: Node2D = _building_refs.get(action.get("id", ""))
			result = b != null and b.is_active()
		"building_not_active":
			var b: Node2D = _building_refs.get(action.get("id", ""))
			result = b != null and not b.is_active()
		"storage_above":
			var b: Node2D = _building_refs.get(action.get("id", ""))
			result = b != null and b.get_total_stored() > action.get("value", 0)
		"storage_below":
			var b: Node2D = _building_refs.get(action.get("id", ""))
			result = b != null and b.get_total_stored() < action.get("value", 0)
		"patch_data_gt":
			result = simulation_manager.total_patch_data > action.get("value", 0)
		"research_gt":
			result = simulation_manager.total_research > action.get("value", 0)
		"neutralized_gt":
			result = simulation_manager.total_neutralized > action.get("value", 0)
		"uplink_linked":
			var b: Node2D = _building_refs.get(action.get("id", ""))
			result = b != null and b.linked_source != null
		"uplink_not_linked":
			var b: Node2D = _building_refs.get(action.get("id", ""))
			result = b != null and b.linked_source == null
		_:
			push_error("[AutoPlay] Unknown assert check: %s" % check)
			return false

	if not result:
		push_warning("[AutoPlay] Assert FAILED — check: %s, action: %s" % [check, str(action)])
	else:
		print("[AutoPlay] Assert PASSED — %s" % check)
	return result


func _handle_place_source(action: Dictionary) -> bool:
	if source_manager == null:
		push_error("[AutoPlay] source_manager not set")
		return false
	var source_name: String = action.get("source", "")
	var path: String = "res://resources/sources/%s.tres" % source_name
	if not ResourceLoader.exists(path):
		push_error("[AutoPlay] Unknown source: %s" % source_name)
		return false
	var def = load(path) as DataSourceDefinition
	if def == null:
		return false
	var cell_arr: Array = action.get("cell", [0, 0])
	var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
	var seed_val: int = int(action.get("seed", -1))
	var source: Node2D = source_manager.place_source(def, cell, seed_val)
	return source != null


func _handle_generate_map(action: Dictionary) -> bool:
	if source_manager == null:
		push_error("[AutoPlay] source_manager not set")
		return false
	var seed_val: int = int(action.get("seed", 12345))
	source_manager.clear_all_sources()
	var MapGeneratorScript = preload("res://scripts/map_generator.gd")
	var generator := MapGeneratorScript.new()
	generator.generate_map(seed_val, source_manager)
	print("[AutoPlay] Map generated — seed: %d" % seed_val)
	return true


func _handle_set_seed(action: Dictionary) -> bool:
	## Set seed for subsequent generate_map calls (stored in action, no persistent state needed)
	print("[AutoPlay] Seed noted: %d (use generate_map to apply)" % int(action.get("seed", 0)))
	return true


func _handle_assert_source_count(action: Dictionary) -> bool:
	if source_manager == null:
		push_error("[AutoPlay] source_manager not set")
		return false
	var sources: Array = source_manager.get_all_sources()
	var count: int = sources.size()
	var check: String = action.get("check", "gte")
	var value: int = int(action.get("value", 0))
	var result: bool = false
	match check:
		"gte":
			result = count >= value
		"lte":
			result = count <= value
		"eq":
			result = count == value
		_:
			push_error("[AutoPlay] Unknown source_count check: %s" % check)
			return false
	if not result:
		push_warning("[AutoPlay] Assert source_count FAILED — count: %d, check: %s %d" % [count, check, value])
	else:
		print("[AutoPlay] Assert source_count PASSED — count: %d %s %d" % [count, check, value])
	return result


# --- HELPERS ---

func _load_definition(building_name: String) -> BuildingDefinition:
	if _def_cache.has(building_name):
		return _def_cache[building_name]
	var path: String = "res://resources/buildings/%s.tres" % building_name
	if not ResourceLoader.exists(path):
		return null
	var def = load(path) as BuildingDefinition
	if def:
		_def_cache[building_name] = def
	return def
