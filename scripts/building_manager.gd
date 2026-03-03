extends Node

signal building_placed(building: Node2D, cell: Vector2i)
signal building_removed(building: Node2D, cell: Vector2i)

enum State { IDLE, PLACING }

@onready var grid_system: Node2D = $"../GridSystem"
@onready var building_container: Node2D = $"../BuildingContainer"
@onready var ghost_preview: Node2D = $"../GhostPreview"

var _building_scene: PackedScene = preload("res://scenes/building.tscn")
var _state: State = State.IDLE
var _current_definition: BuildingDefinition = null
var _ghost_cell: Vector2i = Vector2i.ZERO
var _can_place_here: bool = false

const VALID_COLOR := Color(0, 1, 0.5, 0.4)
const INVALID_COLOR := Color(1, 0.2, 0.2, 0.4)


func start_placement(def: BuildingDefinition) -> void:
	_current_definition = def
	_state = State.PLACING
	ghost_preview.visible = true
	ghost_preview.setup(def, Vector2i.ZERO)
	print("[BuildingManager] Placement started — building: %s" % def.building_name)


func cancel_placement() -> void:
	if _state != State.PLACING:
		return
	_state = State.IDLE
	_current_definition = null
	ghost_preview.visible = false
	print("[BuildingManager] Placement cancelled")


func _unhandled_input(event: InputEvent) -> void:
	match _state:
		State.IDLE:
			_handle_idle_input(event)
		State.PLACING:
			_handle_placing_input(event)


func _process(_delta: float) -> void:
	if _state == State.PLACING:
		_update_ghost_position()


func _handle_idle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var world_pos := _get_world_mouse_position()
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


func _update_ghost_position() -> void:
	var world_pos := _get_world_mouse_position()
	_ghost_cell = grid_system.world_to_grid(world_pos)
	ghost_preview.position = grid_system.grid_to_world(_ghost_cell)
	_can_place_here = grid_system.can_place(_ghost_cell, _current_definition.grid_size)
	ghost_preview.modulate = VALID_COLOR if _can_place_here else INVALID_COLOR


func _place_building() -> void:
	var building: Node2D = _building_scene.instantiate()
	building.setup(_current_definition, _ghost_cell)
	building.position = grid_system.grid_to_world(_ghost_cell)
	building_container.add_child(building)
	grid_system.occupy(_ghost_cell, _current_definition.grid_size, building)
	building_placed.emit(building, _ghost_cell)
	print("[BuildingManager] Building placed — %s at (%d,%d)" % [
		_current_definition.building_name, _ghost_cell.x, _ghost_cell.y
	])


func _remove_building(building: Node2D) -> void:
	var cell: Vector2i = building.grid_cell
	var def: BuildingDefinition = building.definition
	grid_system.free_cells(cell, def.grid_size)
	building_removed.emit(building, cell)
	print("[BuildingManager] Building removed — %s at (%d,%d)" % [
		def.building_name, cell.x, cell.y
	])
	building.queue_free()


func _get_world_mouse_position() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
