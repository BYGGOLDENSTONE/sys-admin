extends Node2D

## Chunk-based fog of war. Unexplored chunks get a dark overlay.
## Grid lines (drawn below this layer) remain faintly visible through fog.
## Ring 0 area starts explored. Building placement reveals nearby chunks.

const CHUNK_SIZE: int = 16  ## cells per chunk axis
const TILE_SIZE: int = 64
const CHUNK_PX: int = CHUNK_SIZE * TILE_SIZE  ## 1024 pixels per chunk
const FOG_COLOR := Color(0.02, 0.03, 0.05, 0.92)
const FOG_EDGE_COLOR := Color(0.02, 0.03, 0.05, 0.5)
const GRID_CELLS: int = 512
const CHUNKS_PER_AXIS: int = GRID_CELLS / CHUNK_SIZE  ## 32
const MAP_CENTER_CELL := Vector2i(256, 256)
const RING0_RADIUS: int = 55  ## slightly larger than ring 0 boundary (50)
const EXPLORE_RADIUS: float = 22.0  ## cells, slightly > source REVEAL_RADIUS

var _explored: Dictionary = {}  ## Vector2i(chunk_x, chunk_y) -> true


func _ready() -> void:
	_explore_ring0()


func _explore_ring0() -> void:
	for cx in range(CHUNKS_PER_AXIS):
		for cy in range(CHUNKS_PER_AXIS):
			var chunk_center := Vector2i(
				cx * CHUNK_SIZE + CHUNK_SIZE / 2,
				cy * CHUNK_SIZE + CHUNK_SIZE / 2
			)
			var dist: float = Vector2(chunk_center - MAP_CENTER_CELL).length()
			if dist <= RING0_RADIUS:
				_explored[Vector2i(cx, cy)] = true


func explore_around_building(building: Node2D, _cell: Vector2i) -> void:
	if building.definition == null:
		return
	var b_center := Vector2(
		building.grid_cell.x + building.definition.grid_size.x / 2.0,
		building.grid_cell.y + building.definition.grid_size.y / 2.0
	)
	var min_cx: int = maxi(0, int((b_center.x - EXPLORE_RADIUS) / CHUNK_SIZE))
	var max_cx: int = mini(CHUNKS_PER_AXIS - 1, int((b_center.x + EXPLORE_RADIUS) / CHUNK_SIZE))
	var min_cy: int = maxi(0, int((b_center.y - EXPLORE_RADIUS) / CHUNK_SIZE))
	var max_cy: int = mini(CHUNKS_PER_AXIS - 1, int((b_center.y + EXPLORE_RADIUS) / CHUNK_SIZE))

	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			var key := Vector2i(cx, cy)
			if _explored.has(key):
				continue
			var closest_x: float = clampf(b_center.x, cx * CHUNK_SIZE, (cx + 1) * CHUNK_SIZE - 1)
			var closest_y: float = clampf(b_center.y, cy * CHUNK_SIZE, (cy + 1) * CHUNK_SIZE - 1)
			var dist: float = abs(b_center.x - closest_x) + abs(b_center.y - closest_y)
			if dist <= EXPLORE_RADIUS:
				_explored[key] = true


func is_cell_explored(cell: Vector2i) -> bool:
	return _explored.has(Vector2i(cell.x / CHUNK_SIZE, cell.y / CHUNK_SIZE))


func _is_edge_chunk(cx: int, cy: int) -> bool:
	## Returns true if this fog chunk borders an explored chunk
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var neighbor := Vector2i(cx + dx, cy + dy)
			if neighbor.x >= 0 and neighbor.x < CHUNKS_PER_AXIS \
					and neighbor.y >= 0 and neighbor.y < CHUNKS_PER_AXIS:
				if _explored.has(neighbor):
					return true
	return false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var vp_size: Vector2 = get_viewport_rect().size / cam.zoom
	var cam_pos: Vector2 = cam.global_position - vp_size / 2.0

	var start_cx: int = maxi(0, int(cam_pos.x / CHUNK_PX))
	var end_cx: int = mini(CHUNKS_PER_AXIS - 1, int((cam_pos.x + vp_size.x) / CHUNK_PX))
	var start_cy: int = maxi(0, int(cam_pos.y / CHUNK_PX))
	var end_cy: int = mini(CHUNKS_PER_AXIS - 1, int((cam_pos.y + vp_size.y) / CHUNK_PX))

	for cx in range(start_cx, end_cx + 1):
		for cy in range(start_cy, end_cy + 1):
			if _explored.has(Vector2i(cx, cy)):
				continue
			var rect := Rect2(cx * CHUNK_PX, cy * CHUNK_PX, CHUNK_PX, CHUNK_PX)
			if _is_edge_chunk(cx, cy):
				# Edge chunks: softer fog (semi-transparent) for smooth transition
				draw_rect(rect, FOG_EDGE_COLOR)
			else:
				draw_rect(rect, FOG_COLOR)
