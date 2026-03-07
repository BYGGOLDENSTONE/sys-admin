extends Node

signal building_placed(building: Node2D, cell: Vector2i)
signal building_removed(building: Node2D, cell: Vector2i)
signal building_hovered(building: Node2D)
signal building_unhovered()
signal building_selected(building: Node2D)
signal building_deselected()
signal source_hovered(source: Node2D)
signal source_unhovered()

enum State { IDLE, PLACING, CONNECTING, MOVING }

@onready var grid_system: Node2D = $"../GridSystem"
@onready var building_container: Node2D = $"../BuildingContainer"
@onready var ghost_preview: Node2D = $"../GhostPreview"

var connection_manager: Node = null
var connection_layer: Node2D = null
var undo_manager: Node = null
var source_manager: Node = null

var _building_scene: PackedScene = preload("res://scenes/building.tscn")
var _state: State = State.IDLE
var _current_definition: BuildingDefinition = null
var _ghost_cell: Vector2i = Vector2i.ZERO
var _can_place_here: bool = false
var _hovered_building: Node2D = null
var _hovered_source: Node2D = null
var _selected_building: Node2D = null

# Connecting state
var _connecting_from_building: Node2D = null
var _connecting_from_port: String = ""
var _routing_start_cell: Vector2i = Vector2i.ZERO

# Moving state
var _moving_building: Node2D = null
var _moving_original_cell: Vector2i = Vector2i.ZERO

const VALID_COLOR := Color(0, 1, 0.5, 0.4)
const INVALID_COLOR := Color(1, 0.2, 0.2, 0.4)


func start_placement(def: BuildingDefinition) -> void:
	_cancel_connecting()
	_deselect_building()
	_clear_cable_hover()
	_current_definition = def
	_state = State.PLACING
	ghost_preview.visible = true
	ghost_preview._is_ghost = true
	ghost_preview.setup(def, Vector2i.ZERO)
	# Clear hover when entering placement mode
	if _hovered_building != null:
		_hovered_building = null
		building_unhovered.emit()
	print("[BuildingManager] Placement started — building: %s" % def.building_name)


func cancel_placement() -> void:
	if _state != State.PLACING:
		return
	_state = State.IDLE
	_current_definition = null
	ghost_preview.visible = false
	print("[BuildingManager] Placement cancelled")


func _cancel_connecting() -> void:
	if _state != State.CONNECTING:
		return
	_state = State.IDLE
	_connecting_from_building = null
	_connecting_from_port = ""
	if connection_layer:
		connection_layer.preview_active = false
	print("[BuildingManager] Connection cancelled")


func _unhandled_input(event: InputEvent) -> void:
	match _state:
		State.IDLE:
			_handle_idle_input(event)
		State.PLACING:
			_handle_placing_input(event)
		State.CONNECTING:
			_handle_connecting_input(event)
		State.MOVING:
			_handle_moving_input(event)


func _process(_delta: float) -> void:
	if _state == State.PLACING:
		_update_ghost_position()
	elif _state == State.IDLE:
		_update_hover()
		_update_cable_hover()
	elif _state == State.CONNECTING:
		_update_connection_preview()
	elif _state == State.MOVING:
		_update_move_preview()


func _handle_idle_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	var world_pos := _get_world_mouse_position()

	if event.button_index == MOUSE_BUTTON_LEFT:
		# Ctrl+click on building: start moving
		if Input.is_key_pressed(KEY_CTRL):
			var cell: Vector2i = grid_system.world_to_grid(world_pos)
			var building: Node = grid_system.get_building_at(cell)
			if building != null:
				_start_moving(building)
				return

		# Check if clicking on an output port
		var port_info := _find_port_at(world_pos, true)
		if not port_info.is_empty():
			_start_connecting(port_info.building, port_info.side)
			return

		# Click on building: select it
		var cell: Vector2i = grid_system.world_to_grid(world_pos)
		var clicked: Node = grid_system.get_building_at(cell)
		if clicked != null:
			_select_building(clicked)
		else:
			_deselect_building()

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Try to delete a cable first
		if connection_manager and connection_manager.get_connection_at_point(world_pos) >= 0:
			var idx: int = connection_manager.get_connection_at_point(world_pos)
			var conns: Array[Dictionary] = connection_manager.get_connections()
			if idx >= 0 and idx < conns.size():
				var conn: Dictionary = conns[idx]
				if undo_manager and not undo_manager.is_undoing:
					undo_manager.push_command({
						type = "remove_connection",
						from_cell = conn.from_building.grid_cell,
						from_port = conn.from_port,
						to_cell = conn.to_building.grid_cell,
						to_port = conn.to_port,
						path = conn.path.duplicate(),
					})
			connection_manager.remove_connection(idx)
			return
		# Otherwise try to delete a building
		var cell: Vector2i = grid_system.world_to_grid(world_pos)
		var building: Node = grid_system.get_building_at(cell)
		if building != null:
			_remove_building(building)


func _handle_placing_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _can_place_here:
			_place_building()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_placement()


func _handle_connecting_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var world_pos := _get_world_mouse_position()
			var port_info := _find_port_at(world_pos, false)
			if not port_info.is_empty():
				_complete_connection(port_info.building, port_info.side)
			else:
				_cancel_connecting()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_connecting()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_connecting()


func _start_connecting(building: Node2D, port_side: String) -> void:
	_connecting_from_building = building
	_connecting_from_port = port_side
	_routing_start_cell = connection_manager.get_port_exit_cell(building, port_side)
	_state = State.CONNECTING
	# Clear hover
	if _hovered_building != null:
		_hovered_building = null
		building_unhovered.emit()
	print("[BuildingManager] Connecting from %s.%s" % [building.definition.building_name, port_side])


func _complete_connection(to_building: Node2D, to_port: String) -> void:
	if connection_manager == null:
		_cancel_connecting()
		return
	var end_cell: Vector2i = connection_manager.get_port_exit_cell(to_building, to_port)
	var path: Array[Vector2i] = connection_manager.calculate_path(_routing_start_cell, end_cell)
	if path.is_empty():
		print("[BuildingManager] Cannot route cable — path blocked")
		_cancel_connecting()
		return
	var added: bool = connection_manager.add_connection(
		_connecting_from_building, _connecting_from_port, to_building, to_port, path
	)
	if added and undo_manager and not undo_manager.is_undoing:
		undo_manager.push_command({
			type = "add_connection",
			from_cell = _connecting_from_building.grid_cell,
			from_port = _connecting_from_port,
			to_cell = to_building.grid_cell,
			to_port = to_port,
			path = path.duplicate(),
		})
	_state = State.IDLE
	_connecting_from_building = null
	_connecting_from_port = ""
	if connection_layer:
		connection_layer.preview_active = false


func _update_connection_preview() -> void:
	if connection_layer == null or _connecting_from_building == null or connection_manager == null:
		return
	var mouse_pos := _get_world_mouse_position()
	var mouse_cell: Vector2i = grid_system.world_to_grid(mouse_pos)
	var from_pos: Vector2 = _connecting_from_building.get_port_world_position(_connecting_from_port)
	var preview: Array[Vector2i] = connection_manager.calculate_preview_path(_routing_start_cell, mouse_cell)
	var valid: bool = connection_manager._is_path_valid(preview) if not preview.is_empty() else false
	connection_layer.preview_path = preview
	connection_layer.preview_valid = valid
	connection_layer.preview_from_pos = from_pos
	connection_layer.preview_to_pos = mouse_pos
	connection_layer.preview_active = true


func _find_port_at(world_pos: Vector2, output_only: bool) -> Dictionary:
	for building in building_container.get_children():
		if not building.has_method("get_port_at"):
			continue
		var local_pos: Vector2 = world_pos - building.global_position
		var port: Dictionary = building.get_port_at(local_pos)
		if port.is_empty():
			continue
		if output_only and not port.is_output:
			continue
		if not output_only and port.is_output:
			continue
		return {"building": building, "side": port.side, "is_output": port.is_output}
	return {}


func _update_ghost_position() -> void:
	var world_pos := _get_world_mouse_position()
	_ghost_cell = grid_system.world_to_grid(world_pos)
	ghost_preview.position = grid_system.grid_to_world(_ghost_cell)
	ghost_preview.grid_cell = _ghost_cell
	_can_place_here = grid_system.can_place(_ghost_cell, _current_definition.grid_size)
	# Generators (Uplink) require an adjacent discovered source
	if _can_place_here and _current_definition.generator != null:
		_can_place_here = _has_adjacent_source(_ghost_cell, _current_definition.grid_size)
	ghost_preview.modulate = VALID_COLOR if _can_place_here else INVALID_COLOR


func _update_hover() -> void:
	var world_pos := _get_world_mouse_position()
	var cell: Vector2i = grid_system.world_to_grid(world_pos)
	var building: Node2D = grid_system.get_building_at(cell)

	if building != _hovered_building:
		_hovered_building = building
		if building != null:
			building_hovered.emit(building)
		else:
			building_unhovered.emit()

	# Source hover (when not hovering a building)
	if building == null:
		var source: Node2D = grid_system.get_source_at(cell)
		if source != _hovered_source:
			_hovered_source = source
			if source != null:
				source_hovered.emit(source)
			else:
				source_unhovered.emit()
	elif _hovered_source != null:
		_hovered_source = null
		source_unhovered.emit()


func _update_cable_hover() -> void:
	if connection_layer == null or connection_manager == null:
		return
	var world_pos := _get_world_mouse_position()
	var idx: int = connection_manager.get_connection_at_point(world_pos)
	connection_layer.hovered_cable_index = idx


func _clear_cable_hover() -> void:
	if connection_layer:
		connection_layer.hovered_cable_index = -1


func _place_building() -> void:
	var building: Node2D = _building_scene.instantiate()
	building.setup(_current_definition, _ghost_cell)
	building.position = grid_system.grid_to_world(_ghost_cell)
	building_container.add_child(building)
	grid_system.occupy(_ghost_cell, _current_definition.grid_size, building)
	building_placed.emit(building, _ghost_cell)
	if undo_manager and not undo_manager.is_undoing:
		undo_manager.push_command({type = "place", definition = _current_definition, cell = _ghost_cell})
	print("[BuildingManager] Building placed — %s at (%d,%d)" % [
		_current_definition.building_name, _ghost_cell.x, _ghost_cell.y
	])
	# Single placement unless Shift is held
	if not Input.is_key_pressed(KEY_SHIFT):
		cancel_placement()


func _has_adjacent_source(cell: Vector2i, building_size: Vector2i) -> bool:
	if source_manager == null:
		return true  # No source_manager = skip check
	var source: Node2D = source_manager.get_source_near(cell, building_size)
	return source != null and source.discovered


func _remove_building(building: Node2D) -> void:
	var cell: Vector2i = building.grid_cell
	var def: BuildingDefinition = building.definition
	# Capture connections before removal for undo
	if undo_manager and not undo_manager.is_undoing:
		var saved_conns: Array[Dictionary] = undo_manager.get_connections_for_building(building)
		undo_manager.push_command({
			type = "remove",
			definition = def,
			cell = cell,
			upgrade_level = building.upgrade_level,
			connections = saved_conns,
		})
	grid_system.free_cells(cell, def.grid_size)
	building_removed.emit(building, cell)
	# Clear hover/selection if removed building was hovered/selected
	if building == _hovered_building:
		_hovered_building = null
		building_unhovered.emit()
	if building == _selected_building:
		_deselect_building()
	print("[BuildingManager] Building removed — %s at (%d,%d)" % [
		def.building_name, cell.x, cell.y
	])
	building.queue_free()


## --- SELECTION ---

func _select_building(building: Node2D) -> void:
	if building == _selected_building:
		return
	_deselect_building()
	_selected_building = building
	building_selected.emit(building)


func _deselect_building() -> void:
	if _selected_building == null:
		return
	_selected_building = null
	building_deselected.emit()


## Programmatic API (AutoPlayManager ve test sistemleri için)

func place_building_at(def: BuildingDefinition, cell: Vector2i, skip_source_check: bool = false) -> Node2D:
	if not grid_system.can_place(cell, def.grid_size):
		push_warning("[BuildingManager] Cannot place %s at (%d,%d) — blocked" % [def.building_name, cell.x, cell.y])
		return null
	if not skip_source_check and def.generator != null and not _has_adjacent_source(cell, def.grid_size):
		push_warning("[BuildingManager] Cannot place %s at (%d,%d) — no adjacent source" % [def.building_name, cell.x, cell.y])
		return null
	var building: Node2D = _building_scene.instantiate()
	building.setup(def, cell)
	building.position = grid_system.grid_to_world(cell)
	building_container.add_child(building)
	grid_system.occupy(cell, def.grid_size, building)
	building_placed.emit(building, cell)
	print("[BuildingManager] API placed — %s at (%d,%d)" % [def.building_name, cell.x, cell.y])
	return building


func remove_building_at(cell: Vector2i) -> bool:
	var building: Node = grid_system.get_building_at(cell)
	if building == null:
		push_warning("[BuildingManager] No building at (%d,%d)" % [cell.x, cell.y])
		return false
	_remove_building(building)
	return true


## --- MOVING ---

func _start_moving(building: Node2D) -> void:
	_moving_building = building
	_moving_original_cell = building.grid_cell
	_state = State.MOVING
	# Free original cells so ghost can check placement
	grid_system.free_cells(_moving_original_cell, building.definition.grid_size)
	# Setup ghost preview with same definition
	ghost_preview.visible = true
	ghost_preview._is_ghost = true
	ghost_preview.setup(building.definition, Vector2i.ZERO)
	# Hide the actual building while moving
	_moving_building.visible = false
	# Clear hover
	if _hovered_building != null:
		_hovered_building = null
		building_unhovered.emit()
	print("[BuildingManager] Moving started — %s from (%d,%d)" % [
		building.definition.building_name, _moving_original_cell.x, _moving_original_cell.y
	])


func _handle_moving_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _can_place_here:
			_complete_move()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_moving()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_moving()


func _update_move_preview() -> void:
	var world_pos := _get_world_mouse_position()
	_ghost_cell = grid_system.world_to_grid(world_pos)
	ghost_preview.position = grid_system.grid_to_world(_ghost_cell)
	ghost_preview.grid_cell = _ghost_cell
	_can_place_here = grid_system.can_place(_ghost_cell, _moving_building.definition.grid_size)
	ghost_preview.modulate = VALID_COLOR if _can_place_here else INVALID_COLOR


func _complete_move() -> void:
	var def: BuildingDefinition = _moving_building.definition
	# Occupy new cells
	grid_system.occupy(_ghost_cell, def.grid_size, _moving_building)
	_moving_building.grid_cell = _ghost_cell
	_moving_building.position = grid_system.grid_to_world(_ghost_cell)
	_moving_building.visible = true
	ghost_preview.visible = false
	if undo_manager and not undo_manager.is_undoing:
		undo_manager.push_command({
			type = "move",
			definition = def,
			old_cell = _moving_original_cell,
			new_cell = _ghost_cell,
		})
	print("[BuildingManager] Building moved — %s to (%d,%d)" % [
		def.building_name, _ghost_cell.x, _ghost_cell.y
	])
	_moving_building = null
	_state = State.IDLE


func _cancel_moving() -> void:
	# Restore original cells
	var def: BuildingDefinition = _moving_building.definition
	grid_system.occupy(_moving_original_cell, def.grid_size, _moving_building)
	_moving_building.visible = true
	ghost_preview.visible = false
	_moving_building = null
	_state = State.IDLE
	print("[BuildingManager] Move cancelled")


func _get_world_mouse_position() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
