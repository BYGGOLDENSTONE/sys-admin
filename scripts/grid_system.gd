extends Node2D

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 256
const GRID_HEIGHT: int = 256

const BG_COLOR := Color("#0a0e14")
const GRID_LINE_COLOR := Color("#2a2e3e")

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


func get_source_at(cell: Vector2i) -> Node:
	return _source_cells.get(cell, null)


func _draw() -> void:
	var grid_pixel_size := Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)
	draw_rect(Rect2(Vector2.ZERO, grid_pixel_size), BG_COLOR, true)

	# Only draw visible grid lines for performance
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var vp_size: Vector2 = get_viewport_rect().size / cam.zoom
	var cam_pos: Vector2 = cam.global_position - vp_size / 2.0
	var start_x: int = maxi(0, int(cam_pos.x / TILE_SIZE))
	var end_x: int = mini(GRID_WIDTH, int((cam_pos.x + vp_size.x) / TILE_SIZE) + 1)
	var start_y: int = maxi(0, int(cam_pos.y / TILE_SIZE))
	var end_y: int = mini(GRID_HEIGHT, int((cam_pos.y + vp_size.y) / TILE_SIZE) + 1)

	for x in range(start_x, end_x + 1):
		draw_line(
			Vector2(x * TILE_SIZE, start_y * TILE_SIZE),
			Vector2(x * TILE_SIZE, end_y * TILE_SIZE),
			GRID_LINE_COLOR, -1.0, true
		)
	for y in range(start_y, end_y + 1):
		draw_line(
			Vector2(start_x * TILE_SIZE, y * TILE_SIZE),
			Vector2(end_x * TILE_SIZE, y * TILE_SIZE),
			GRID_LINE_COLOR, -1.0, true
		)
