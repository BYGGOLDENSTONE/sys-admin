extends Node

signal building_placed(building: Node2D, cell: Vector2i)
signal building_removed(building: Node2D, cell: Vector2i)
signal building_hovered(building: Node2D)
signal building_unhovered()

enum State { IDLE, PLACING, CONNECTING }

@onready var grid_system: Node2D = $"../GridSystem"
@onready var building_container: Node2D = $"../BuildingContainer"
@onready var ghost_preview: Node2D = $"../GhostPreview"

var connection_manager: Node = null
var connection_layer: Node2D = null
var simulation_manager = null

var _building_scene: PackedScene = preload("res://scenes/building.tscn")
var _state: State = State.IDLE
var _current_definition: BuildingDefinition = null
var _ghost_cell: Vector2i = Vector2i.ZERO
var _can_place_here: bool = false
var _hovered_building: Node2D = null

# Connecting state
var _connecting_from_building: Node2D = null
var _connecting_from_port: String = ""

const VALID_COLOR := Color(0, 1, 0.5, 0.4)
const INVALID_COLOR := Color(1, 0.2, 0.2, 0.4)


func start_placement(def: BuildingDefinition) -> void:
	_cancel_connecting()
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
	_clear_power_preview()
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


func _process(_delta: float) -> void:
	if _state == State.PLACING:
		_update_ghost_position()
	elif _state == State.IDLE:
		_update_hover()
	elif _state == State.CONNECTING:
		_update_connection_preview()


func _handle_idle_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	var world_pos := _get_world_mouse_position()

	if event.button_index == MOUSE_BUTTON_LEFT:
		# Check if clicking on an output port
		var port_info := _find_port_at(world_pos, true)
		if not port_info.is_empty():
			_start_connecting(port_info.building, port_info.side)
			return

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Try to delete a cable first
		if connection_manager and connection_manager.get_connection_at_point(world_pos) >= 0:
			var idx: int = connection_manager.get_connection_at_point(world_pos)
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
	_state = State.CONNECTING
	# Clear hover
	if _hovered_building != null:
		_hovered_building = null
		building_unhovered.emit()
	print("[BuildingManager] Connecting from %s.%s" % [building.definition.building_name, port_side])


func _complete_connection(to_building: Node2D, to_port: String) -> void:
	if connection_manager:
		connection_manager.add_connection(_connecting_from_building, _connecting_from_port, to_building, to_port)
	_state = State.IDLE
	_connecting_from_building = null
	_connecting_from_port = ""
	if connection_layer:
		connection_layer.preview_active = false


func _update_connection_preview() -> void:
	if connection_layer == null or _connecting_from_building == null:
		return
	var from_pos: Vector2 = _connecting_from_building.get_port_world_position(_connecting_from_port)
	var to_pos := _get_world_mouse_position()
	connection_layer.preview_from = from_pos
	connection_layer.preview_to = to_pos
	connection_layer.preview_active = true
	connection_layer.preview_color = Color(_connecting_from_building.definition.color, 0.5)


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
	ghost_preview.modulate = VALID_COLOR if _can_place_here else INVALID_COLOR
	_update_power_preview()


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


func _place_building() -> void:
	_clear_power_preview()
	var building: Node2D = _building_scene.instantiate()
	building.setup(_current_definition, _ghost_cell)
	building.position = grid_system.grid_to_world(_ghost_cell)
	building_container.add_child(building)
	grid_system.occupy(_ghost_cell, _current_definition.grid_size, building)
	building_placed.emit(building, _ghost_cell)
	print("[BuildingManager] Building placed — %s at (%d,%d)" % [
		_current_definition.building_name, _ghost_cell.x, _ghost_cell.y
	])
	# Single placement unless Shift is held
	if not Input.is_key_pressed(KEY_SHIFT):
		cancel_placement()


func _remove_building(building: Node2D) -> void:
	var cell: Vector2i = building.grid_cell
	var def: BuildingDefinition = building.definition
	grid_system.free_cells(cell, def.grid_size)
	building_removed.emit(building, cell)
	# Clear hover if removed building was hovered
	if building == _hovered_building:
		_hovered_building = null
		building_unhovered.emit()
	print("[BuildingManager] Building removed — %s at (%d,%d)" % [
		def.building_name, cell.x, cell.y
	])
	building.queue_free()


func _get_world_mouse_position() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()


func _update_power_preview() -> void:
	if simulation_manager == null:
		return
	# Clear previous preview
	_clear_power_preview()

	if _current_definition.zone_radius > 0.0:
		# Placing a zone building (Power Cell, Coolant Rig): highlight affected buildings
		for building in building_container.get_children():
			if not building.has_method("is_active"):
				continue
			if building == ghost_preview:
				continue
			if simulation_manager._is_in_zone(ghost_preview, building):
				building.power_preview = 1
	else:
		# Placing a regular building: check if it will be in any zone
		var in_any_zone: bool = false
		for building in building_container.get_children():
			if not building.has_method("is_active"):
				continue
			if building.definition.zone_radius > 0.0:
				if simulation_manager._is_in_zone(building, ghost_preview):
					in_any_zone = true
					break
		ghost_preview.power_preview = 1 if in_any_zone else 0


func _clear_power_preview() -> void:
	ghost_preview.power_preview = 0
	for building in building_container.get_children():
		if building.has_method("is_active"):
			building.power_preview = 0
