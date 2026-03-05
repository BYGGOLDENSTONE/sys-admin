extends Control

const MINIMAP_SIZE: int = 180
const BG_COLOR := Color(0.04, 0.06, 0.08, 0.9)
const BORDER_COLOR := Color(0, 0.8, 1.0, 0.5)
const CAMERA_COLOR := Color(1, 1, 1, 0.6)
const BUILDING_COLOR := Color(0, 1, 0.53)
const TILE_PX: int = 64
const WORLD_SIZE: float = 256.0 * 64.0

var source_manager: Node = null
var building_container: Node2D = null
var camera_ref: Camera2D = null


func _ready() -> void:
	custom_minimum_size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var s: float = MINIMAP_SIZE
	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)), BG_COLOR)
	_draw_rings()
	_draw_sources()
	_draw_buildings()
	_draw_camera_rect()
	# Border
	draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)), BORDER_COLOR, false, 1.0)


func _world_to_mini(world_pos: Vector2) -> Vector2:
	var s: float = MINIMAP_SIZE
	return Vector2(
		world_pos.x / WORLD_SIZE * s,
		world_pos.y / WORLD_SIZE * s
	)


func _draw_rings() -> void:
	var s: float = MINIMAP_SIZE
	var center := Vector2(s / 2.0, s / 2.0)
	var rings: Array = [
		[25, Color(0.3, 1.0, 0.4, 0.2)],
		[50, Color(1.0, 0.9, 0.3, 0.2)],
		[80, Color(1.0, 0.6, 0.2, 0.2)],
		[115, Color(1.0, 0.3, 0.2, 0.2)],
	]
	for ring in rings:
		var r_px: float = float(ring[0]) * TILE_PX / WORLD_SIZE * s
		draw_arc(center, r_px, 0, TAU, 64, ring[1], 1.0)


func _draw_sources() -> void:
	if source_manager == null:
		return
	for src in source_manager.get_all_sources():
		if not src.discovered and not source_manager.dev_mode:
			continue
		var pos := _world_to_mini(Vector2(src.grid_cell.x * TILE_PX, src.grid_cell.y * TILE_PX))
		var col: Color = src.definition.color if src.discovered else Color(0.4, 0.4, 0.4, 0.4)
		draw_circle(pos, 3.0, col)


func _draw_buildings() -> void:
	if building_container == null:
		return
	for child in building_container.get_children():
		if not child.has_method("is_active"):
			continue
		var pos := _world_to_mini(child.position)
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(2, 2)), BUILDING_COLOR)


func _draw_camera_rect() -> void:
	if camera_ref == null:
		return
	var vp_size := get_viewport().get_visible_rect().size
	var visible_area := vp_size / camera_ref.zoom
	var tl := camera_ref.position - visible_area / 2.0
	var mini_tl := _world_to_mini(tl)
	var s: float = MINIMAP_SIZE
	var mini_sz := Vector2(
		visible_area.x / WORLD_SIZE * s,
		visible_area.y / WORLD_SIZE * s
	)
	draw_rect(Rect2(mini_tl, mini_sz), CAMERA_COLOR, false, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_navigate(event.position)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_navigate(event.position)


func _navigate(local_pos: Vector2) -> void:
	if camera_ref == null:
		return
	var s: float = MINIMAP_SIZE
	camera_ref.position = Vector2(
		local_pos.x / s * WORLD_SIZE,
		local_pos.y / s * WORLD_SIZE
	)
