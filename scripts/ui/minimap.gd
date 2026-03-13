extends Control

const MINIMAP_SIZE: int = 180
const BG_COLOR := Color(0.03, 0.05, 0.07, 0.9)
const BORDER_COLOR := Color(0.13, 0.67, 0.87, 0.5)
const BORDER_GLOW_COLOR := Color(0.13, 0.67, 0.87, 0.15)
const CAMERA_COLOR := Color(1, 1, 1, 0.6)
const BUILDING_COLOR := Color(0.2, 1.0, 0.67)
const CABLE_COLOR := Color(0.13, 0.6, 0.87, 0.25)
const TILE_PX: int = 64
const WORLD_SIZE: float = 512.0 * 64.0

var source_manager: Node = null
var building_container: Node2D = null
var camera_ref: Camera2D = null
var connection_manager: Node = null


func _ready() -> void:
	custom_minimum_size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var s: float = MINIMAP_SIZE
	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)), BG_COLOR)
	# Subtle grid overlay
	_draw_grid_overlay()
	_draw_cables()
	_draw_sources()
	_draw_buildings()
	_draw_camera_rect()
	# Border glow (outer)
	draw_rect(Rect2(Vector2(-2, -2), Vector2(s + 4, s + 4)), BORDER_GLOW_COLOR, false, 3.0)
	# Border (crisp)
	draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)), BORDER_COLOR, false, 1.0)
	# Corner accents
	var cl: float = 12.0
	var cc := Color(0.13, 0.67, 0.87, 0.7)
	draw_line(Vector2(0, 0), Vector2(cl, 0), cc, 2.0)
	draw_line(Vector2(0, 0), Vector2(0, cl), cc, 2.0)
	draw_line(Vector2(s, 0), Vector2(s - cl, 0), cc, 2.0)
	draw_line(Vector2(s, 0), Vector2(s, cl), cc, 2.0)
	draw_line(Vector2(0, s), Vector2(cl, s), cc, 2.0)
	draw_line(Vector2(0, s), Vector2(0, s - cl), cc, 2.0)
	draw_line(Vector2(s, s), Vector2(s - cl, s), cc, 2.0)
	draw_line(Vector2(s, s), Vector2(s, s - cl), cc, 2.0)


func _world_to_mini(world_pos: Vector2) -> Vector2:
	var s: float = MINIMAP_SIZE
	return Vector2(
		world_pos.x / WORLD_SIZE * s,
		world_pos.y / WORLD_SIZE * s
	)


func _draw_grid_overlay() -> void:
	var s: float = MINIMAP_SIZE
	var grid_color := Color(0.15, 0.2, 0.3, 0.15)
	var step: float = s / 8.0
	for i in range(1, 8):
		draw_line(Vector2(i * step, 0), Vector2(i * step, s), grid_color, 1.0)
		draw_line(Vector2(0, i * step), Vector2(s, i * step), grid_color, 1.0)


func _draw_cables() -> void:
	if connection_manager == null:
		return
	var conns: Array[Dictionary] = connection_manager.get_connections()
	for conn in conns:
		var from_pos: Vector2 = _world_to_mini(conn.from_building.global_position)
		var to_pos: Vector2 = _world_to_mini(conn.to_building.global_position)
		var accent: Color = Color(conn.from_building.definition.color, 0.3)
		draw_line(from_pos, to_pos, accent, 1.0, true)


func _draw_sources() -> void:
	if source_manager == null:
		return
	for src in source_manager.get_all_sources():
		var pos := _world_to_mini(Vector2(src.grid_cell.x * TILE_PX, src.grid_cell.y * TILE_PX))
		var col: Color = src.definition.color
		# Glow halo
		draw_circle(pos, 5.0, Color(col, 0.15))
		draw_circle(pos, 3.0, col)


func _draw_buildings() -> void:
	if building_container == null:
		return
	for child in building_container.get_children():
		if not child.has_method("is_active"):
			continue
		var pos := _world_to_mini(child.position)
		var col: Color = child.definition.color if child.definition else BUILDING_COLOR
		# Small glow
		draw_rect(Rect2(pos - Vector2(2, 2), Vector2(4, 4)), Color(col, 0.3))
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(2, 2)), col)


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
	# Camera rect with corner accents
	draw_rect(Rect2(mini_tl, mini_sz), Color(1, 1, 1, 0.08), true)
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
