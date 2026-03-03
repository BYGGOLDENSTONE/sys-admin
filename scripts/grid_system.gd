extends Node2D

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 64
const GRID_HEIGHT: int = 64

const BG_COLOR := Color("#0a0e14")
const GRID_LINE_COLOR := Color("#2a2e3e")

var _occupied_cells: Dictionary = {}


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


func _draw() -> void:
	var grid_pixel_size := Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)
	draw_rect(Rect2(Vector2.ZERO, grid_pixel_size), BG_COLOR, true)

	for x in range(GRID_WIDTH + 1):
		var from := Vector2(x * TILE_SIZE, 0)
		var to := Vector2(x * TILE_SIZE, grid_pixel_size.y)
		draw_line(from, to, GRID_LINE_COLOR, -1.0, true)

	for y in range(GRID_HEIGHT + 1):
		var from := Vector2(0, y * TILE_SIZE)
		var to := Vector2(grid_pixel_size.x, y * TILE_SIZE)
		draw_line(from, to, GRID_LINE_COLOR, -1.0, true)
