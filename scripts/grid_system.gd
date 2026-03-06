extends Node2D

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 512
const GRID_HEIGHT: int = 512

const BG_COLOR := Color("#0a0e14")
const GRID_LINE_COLOR := Color("#2a2e3e")
const MAP_CENTER := Vector2(256 * 64, 256 * 64)  ## Center in pixels (256,256 grid * 64px)

## Ring border radii (in grid cells) and colors (easy→endgame)
const RING_BORDERS: Array = [
	{"radius": 50, "color": Color(0.3, 1.0, 0.4, 0.25)},   ## Ring 0→1: green
	{"radius": 105, "color": Color(1.0, 0.9, 0.3, 0.25)},  ## Ring 1→2: yellow
	{"radius": 165, "color": Color(1.0, 0.6, 0.2, 0.25)},  ## Ring 2→3: orange
	{"radius": 230, "color": Color(1.0, 0.3, 0.2, 0.25)},  ## Ring 3 outer: red
]

var _occupied_cells: Dictionary = {}
var _source_cells: Dictionary = {}  ## cell → source Node2D ref


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE_SIZE), floori(world_pos.y / TILE_SIZE))


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)


func can_place(grid_pos: Vector2i, building_size: Vector2i) -> bool:
	for x in range(building_size.x):
		for y in range(building_size.y):
			var cell := Vector2i(grid_pos.x + x, grid_pos.y + y)
			if cell.x < 0 or cell.x >= GRID_WIDTH or cell.y < 0 or cell.y >= GRID_HEIGHT:
				return false
			if _occupied_cells.has(cell):
				return false
			if _source_cells.has(cell):
				return false
	return true


func occupy(grid_pos: Vector2i, building_size: Vector2i, building_ref: Node) -> void:
	for x in range(building_size.x):
		for y in range(building_size.y):
			_occupied_cells[Vector2i(grid_pos.x + x, grid_pos.y + y)] = building_ref


func free_cells(grid_pos: Vector2i, building_size: Vector2i) -> void:
	for x in range(building_size.x):
		for y in range(building_size.y):
			_occupied_cells.erase(Vector2i(grid_pos.x + x, grid_pos.y + y))


func get_building_at(cell: Vector2i) -> Node:
	return _occupied_cells.get(cell, null)


func occupy_source(cells: Array[Vector2i], source_ref: Node) -> void:
	for cell in cells:
		_source_cells[cell] = source_ref


func free_source_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_source_cells.erase(cell)


func get_ring_color(ring_index: int) -> Color:
	if ring_index < 0 or ring_index >= RING_BORDERS.size():
		return Color.WHITE
	return RING_BORDERS[ring_index]["color"]


func get_ring_label(ring_index: int) -> String:
	match ring_index:
		0: return "KOLAY"
		1: return "ORTA"
		2: return "ZOR"
		3: return "ENDGAME"
		_: return "???"


func get_source_at(cell: Vector2i) -> Node:
	return _source_cells.get(cell, null)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var grid_pixel_size := Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)
	draw_rect(Rect2(Vector2.ZERO, grid_pixel_size), BG_COLOR, true)

	# Only draw visible grid lines for performance
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var zoom_level: float = cam.zoom.x

	# Fade out grid lines when zoomed out to prevent flickering/moire
	# Fully visible above 0.5, fully hidden below 0.2
	if zoom_level < 0.2:
		_draw_ring_borders(cam.global_position - get_viewport_rect().size / cam.zoom / 2.0, get_viewport_rect().size / cam.zoom)
		return
	var grid_alpha: float = clampf((zoom_level - 0.2) / 0.3, 0.0, 1.0)
	var line_color := Color(GRID_LINE_COLOR, GRID_LINE_COLOR.a * grid_alpha)

	# Skip lines at very low zoom — draw every Nth line
	var step: int = 1
	if zoom_level < 0.35:
		step = 4  # draw every 4th line
	elif zoom_level < 0.5:
		step = 2  # draw every 2nd line

	var vp_size: Vector2 = get_viewport_rect().size / cam.zoom
	var cam_pos: Vector2 = cam.global_position - vp_size / 2.0
	var start_x: int = maxi(0, int(cam_pos.x / TILE_SIZE))
	var end_x: int = mini(GRID_WIDTH, int((cam_pos.x + vp_size.x) / TILE_SIZE) + 1)
	var start_y: int = maxi(0, int(cam_pos.y / TILE_SIZE))
	var end_y: int = mini(GRID_HEIGHT, int((cam_pos.y + vp_size.y) / TILE_SIZE) + 1)

	# Align start to step for consistent grid pattern
	start_x = start_x - (start_x % step)
	start_y = start_y - (start_y % step)

	for x in range(start_x, end_x + 1, step):
		draw_line(
			Vector2(x * TILE_SIZE, start_y * TILE_SIZE),
			Vector2(x * TILE_SIZE, end_y * TILE_SIZE),
			line_color, -1.0, true
		)
	for y in range(start_y, end_y + 1, step):
		draw_line(
			Vector2(start_x * TILE_SIZE, y * TILE_SIZE),
			Vector2(end_x * TILE_SIZE, y * TILE_SIZE),
			line_color, -1.0, true
		)

	_draw_ring_borders(cam_pos, vp_size)


func _draw_ring_borders(cam_pos: Vector2, vp_size: Vector2) -> void:
	var view_rect := Rect2(cam_pos, vp_size)
	var seg_count: int = 64

	for ring in RING_BORDERS:
		var radius_px: float = float(ring["radius"]) * TILE_SIZE
		var color: Color = ring["color"]

		# Rough visibility check: if ring circle doesn't intersect viewport, skip
		var ring_rect := Rect2(
			MAP_CENTER.x - radius_px, MAP_CENTER.y - radius_px,
			radius_px * 2, radius_px * 2
		)
		if not view_rect.intersects(ring_rect):
			continue

		# Draw dashed neon circle
		var points := PackedVector2Array()
		for i in range(seg_count + 1):
			var angle: float = float(i) / float(seg_count) * TAU
			points.append(MAP_CENTER + Vector2(cos(angle), sin(angle)) * radius_px)

		# Inner glow (wider, dimmer)
		draw_polyline(points, Color(color, color.a * 0.4), 4.0, true)
		# Core line
		draw_polyline(points, color, 1.5, true)
