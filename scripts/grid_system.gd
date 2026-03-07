extends Node2D

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 512
const GRID_HEIGHT: int = 512

const BG_COLOR := Color("#0a0e14")
const GRID_LINE_COLOR := Color("#2a2e3e")
const MAP_CENTER := Vector2(256 * 64, 256 * 64)  ## Center in pixels (256,256 grid * 64px)

var _occupied_cells: Dictionary = {}
var _source_cells: Dictionary = {}  ## cell → source Node2D ref
var _cable_cells: Dictionary = {}   ## cell → int (cable count, bridge allows up to 2)


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
			if _cable_cells.has(cell):
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



func can_place_cable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= GRID_WIDTH or cell.y < 0 or cell.y >= GRID_HEIGHT:
		return false
	if _source_cells.has(cell):
		return false
	if _occupied_cells.has(cell):
		var building: Node = _occupied_cells[cell]
		if building and building.definition and building.definition.allows_cable_crossing:
			return _cable_cells.get(cell, 0) < 2
		return false
	return not _cable_cells.has(cell)


func occupy_cable(cell: Vector2i) -> void:
	_cable_cells[cell] = _cable_cells.get(cell, 0) + 1


func free_cable(cell: Vector2i) -> void:
	var count: int = _cable_cells.get(cell, 0) - 1
	if count <= 0:
		_cable_cells.erase(cell)
	else:
		_cable_cells[cell] = count


func has_cable_at(cell: Vector2i) -> bool:
	return _cable_cells.get(cell, 0) > 0


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

	# Cell underglow (only visible cells for performance)
	var vp := get_viewport_rect().size / cam.zoom
	var cp := cam.global_position - vp / 2.0
	var sx: int = maxi(0, int(cp.x / TILE_SIZE) - 1)
	var ex: int = mini(GRID_WIDTH, int((cp.x + vp.x) / TILE_SIZE) + 2)
	var sy: int = maxi(0, int(cp.y / TILE_SIZE) - 1)
	var ey: int = mini(GRID_HEIGHT, int((cp.y + vp.y) / TILE_SIZE) + 2)

	# Underglow intensity scales with zoom (brighter when zoomed out)
	var ug_scale: float = clampf(1.0 / zoom_level, 1.0, 3.0) if zoom_level < 1.0 else 1.0

	for cell in _occupied_cells:
		if cell.x < sx or cell.x > ex or cell.y < sy or cell.y > ey:
			continue
		var building = _occupied_cells[cell]
		if building and building.definition:
			var a: Color = building.definition.color
			var r := Rect2(cell.x * TILE_SIZE, cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			draw_rect(r, Color(a, minf(0.06 * ug_scale, 0.2)), true)
			if zoom_level > 0.4:
				draw_rect(r, Color(a, 0.03), false, 1.0)

	for cell in _cable_cells:
		if cell.x < sx or cell.x > ex or cell.y < sy or cell.y > ey:
			continue
		var r := Rect2(cell.x * TILE_SIZE, cell.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(r, Color(0.0, 0.6, 0.9, minf(0.035 * ug_scale, 0.12)), true)

	# Fade out grid lines when zoomed out to prevent flickering/moire
	# Fully visible above 0.5, fully hidden below 0.2
	if zoom_level < 0.2:
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

