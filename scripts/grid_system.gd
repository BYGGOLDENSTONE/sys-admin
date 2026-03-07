extends Node2D

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 512
const GRID_HEIGHT: int = 512

const BG_COLOR := Color("#0a0e14")
const GRID_LINE_COLOR := Color("#2a2e3e")
const MAP_CENTER := Vector2(256 * 64, 256 * 64)  ## Center in pixels (256,256 grid * 64px)

var _occupied_cells: Dictionary = {}
var _source_cells: Dictionary = {}  ## cell → source Node2D ref

## Edge-based cable tracking
## Horizontal edge key: Vector2i(x, y) = edge from vertex (x,y) to (x+1,y)
## Vertical edge key: Vector2i(x, y) = edge from vertex (x,y) to (x,y+1)
var _cable_h_edges: Dictionary = {}  ## Vector2i → int (cable count)
var _cable_v_edges: Dictionary = {}  ## Vector2i → int (cable count)

## Proximity edges: blocked edges near buildings (1-cell buffer zone)
var _proximity_h_edges: Dictionary = {}  ## Vector2i → int (blocking count)
var _proximity_v_edges: Dictionary = {}  ## Vector2i → int (blocking count)

## Port exit vertices: edges touching these are exempt from proximity blocking
var _port_exit_vertices: Dictionary = {}  ## Vector2i → String (port_side)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE_SIZE), floori(world_pos.y / TILE_SIZE))


func world_to_vertex(world_pos: Vector2) -> Vector2i:
	return Vector2i(roundi(world_pos.x / TILE_SIZE), roundi(world_pos.y / TILE_SIZE))


func vertex_to_world(v: Vector2i) -> Vector2:
	return Vector2(v.x * TILE_SIZE, v.y * TILE_SIZE)


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
	# Check interior cable edges (edges where both adjacent cells are inside building)
	var bx := grid_pos.x
	var by := grid_pos.y
	var w := building_size.x
	var h := building_size.y
	# Horizontal interior edges
	for vx in range(bx, bx + w):
		for vy in range(by + 1, by + h):
			if _cable_h_edges.has(Vector2i(vx, vy)):
				return false
	# Vertical interior edges
	for vx in range(bx + 1, bx + w):
		for vy in range(by, by + h):
			if _cable_v_edges.has(Vector2i(vx, vy)):
				return false
	return true


func occupy(grid_pos: Vector2i, building_size: Vector2i, building_ref: Node) -> void:
	for x in range(building_size.x):
		for y in range(building_size.y):
			_occupied_cells[Vector2i(grid_pos.x + x, grid_pos.y + y)] = building_ref
	_add_proximity_edges(grid_pos, building_size)
	if building_ref and building_ref.definition:
		_register_port_exits(grid_pos, building_size, building_ref.definition)


func free_cells(grid_pos: Vector2i, building_size: Vector2i) -> void:
	var building_ref = _occupied_cells.get(grid_pos, null)
	for x in range(building_size.x):
		for y in range(building_size.y):
			_occupied_cells.erase(Vector2i(grid_pos.x + x, grid_pos.y + y))
	_remove_proximity_edges(grid_pos, building_size)
	if building_ref and building_ref.definition:
		_unregister_port_exits(grid_pos, building_size, building_ref.definition)


func get_building_at(cell: Vector2i) -> Node:
	return _occupied_cells.get(cell, null)


func occupy_source(cells: Array[Vector2i], source_ref: Node) -> void:
	for cell in cells:
		_source_cells[cell] = source_ref
	_add_source_proximity(cells)


func free_source_cells(cells: Array[Vector2i]) -> void:
	_remove_source_proximity(cells)
	for cell in cells:
		_source_cells.erase(cell)


func _add_source_proximity(cells: Array[Vector2i]) -> void:
	_modify_source_proximity(cells, 1)

func _remove_source_proximity(cells: Array[Vector2i]) -> void:
	_modify_source_proximity(cells, -1)

func _modify_source_proximity(cells: Array[Vector2i], delta: int) -> void:
	var cell_set: Dictionary = {}
	for c in cells:
		cell_set[c] = true
	for cell in cells:
		var cx := cell.x
		var cy := cell.y
		var right_ext := not cell_set.has(Vector2i(cx + 1, cy))
		var left_ext := not cell_set.has(Vector2i(cx - 1, cy))
		var top_ext := not cell_set.has(Vector2i(cx, cy - 1))
		var bottom_ext := not cell_set.has(Vector2i(cx, cy + 1))
		# Right edge external? (cell to right not in source)
		if right_ext:
			var key := Vector2i(cx + 2, cy)
			_proximity_v_edges[key] = _proximity_v_edges.get(key, 0) + delta
			if _proximity_v_edges[key] <= 0:
				_proximity_v_edges.erase(key)
		# Left edge external?
		if left_ext:
			var key := Vector2i(cx - 1, cy)
			_proximity_v_edges[key] = _proximity_v_edges.get(key, 0) + delta
			if _proximity_v_edges[key] <= 0:
				_proximity_v_edges.erase(key)
		# Bottom edge external?
		if bottom_ext:
			var key := Vector2i(cx, cy + 2)
			_proximity_h_edges[key] = _proximity_h_edges.get(key, 0) + delta
			if _proximity_h_edges[key] <= 0:
				_proximity_h_edges.erase(key)
		# Top edge external?
		if top_ext:
			var key := Vector2i(cx, cy - 1)
			_proximity_h_edges[key] = _proximity_h_edges.get(key, 0) + delta
			if _proximity_h_edges[key] <= 0:
				_proximity_h_edges.erase(key)
		# Diagonal corners — block outer edges of buffer corner cells
		# Upper-right
		if right_ext and top_ext and not cell_set.has(Vector2i(cx + 1, cy - 1)):
			var hk := Vector2i(cx + 1, cy - 1)
			_proximity_h_edges[hk] = _proximity_h_edges.get(hk, 0) + delta
			if _proximity_h_edges[hk] <= 0:
				_proximity_h_edges.erase(hk)
			var vk := Vector2i(cx + 2, cy - 1)
			_proximity_v_edges[vk] = _proximity_v_edges.get(vk, 0) + delta
			if _proximity_v_edges[vk] <= 0:
				_proximity_v_edges.erase(vk)
		# Upper-left
		if left_ext and top_ext and not cell_set.has(Vector2i(cx - 1, cy - 1)):
			var hk := Vector2i(cx - 1, cy - 1)
			_proximity_h_edges[hk] = _proximity_h_edges.get(hk, 0) + delta
			if _proximity_h_edges[hk] <= 0:
				_proximity_h_edges.erase(hk)
			var vk := Vector2i(cx - 1, cy - 1)
			_proximity_v_edges[vk] = _proximity_v_edges.get(vk, 0) + delta
			if _proximity_v_edges[vk] <= 0:
				_proximity_v_edges.erase(vk)
		# Lower-right
		if right_ext and bottom_ext and not cell_set.has(Vector2i(cx + 1, cy + 1)):
			var hk := Vector2i(cx + 1, cy + 2)
			_proximity_h_edges[hk] = _proximity_h_edges.get(hk, 0) + delta
			if _proximity_h_edges[hk] <= 0:
				_proximity_h_edges.erase(hk)
			var vk := Vector2i(cx + 2, cy + 1)
			_proximity_v_edges[vk] = _proximity_v_edges.get(vk, 0) + delta
			if _proximity_v_edges[vk] <= 0:
				_proximity_v_edges.erase(vk)
		# Lower-left
		if left_ext and bottom_ext and not cell_set.has(Vector2i(cx - 1, cy + 1)):
			var hk := Vector2i(cx - 1, cy + 2)
			_proximity_h_edges[hk] = _proximity_h_edges.get(hk, 0) + delta
			if _proximity_h_edges[hk] <= 0:
				_proximity_h_edges.erase(hk)
			var vk := Vector2i(cx - 1, cy + 1)
			_proximity_v_edges[vk] = _proximity_v_edges.get(vk, 0) + delta
			if _proximity_v_edges[vk] <= 0:
				_proximity_v_edges.erase(vk)


# --- EDGE-BASED CABLE FUNCTIONS ---

func _get_edge_data(v1: Vector2i, v2: Vector2i) -> Array:
	## Returns [dictionary_ref, key] for the edge between v1 and v2
	if v1.y == v2.y:  # horizontal edge
		return [_cable_h_edges, Vector2i(mini(v1.x, v2.x), v1.y)]
	else:  # vertical edge
		return [_cable_v_edges, Vector2i(v1.x, mini(v1.y, v2.y))]


func can_place_cable_edge(v1: Vector2i, v2: Vector2i) -> bool:
	# Bounds check (vertices can be 0..GRID_WIDTH, 0..GRID_HEIGHT)
	if v1.x < 0 or v1.x > GRID_WIDTH or v1.y < 0 or v1.y > GRID_HEIGHT:
		return false
	if v2.x < 0 or v2.x > GRID_WIDTH or v2.y < 0 or v2.y > GRID_HEIGHT:
		return false
	# Must be adjacent (differ by 1 in exactly one axis)
	var diff := v2 - v1
	if absi(diff.x) + absi(diff.y) != 1:
		return false
	# Check if already occupied
	var data: Array = _get_edge_data(v1, v2)
	var dict: Dictionary = data[0]
	var key: Vector2i = data[1]
	if dict.has(key):
		# Check for bridge: if both adjacent cells have a bridge building, allow up to 2
		if dict[key] >= 2:
			return false
		if _edge_has_bridge(v1, v2):
			return dict[key] < 2
		return false
	# Check if any vertex touches a building boundary
	# (each vertex has 4 surrounding cells — if any is occupied, block)
	if _vertex_near_occupied(v1) or _vertex_near_occupied(v2):
		return false
	# Check proximity edges (1-cell buffer zone around buildings)
	if v1.y == v2.y:  # horizontal edge
		var hkey := Vector2i(mini(v1.x, v2.x), v1.y)
		if _proximity_h_edges.has(hkey):
			if not _is_port_exit_edge(v1, v2):
				return false
	else:  # vertical edge
		var vkey := Vector2i(v1.x, mini(v1.y, v2.y))
		if _proximity_v_edges.has(vkey):
			if not _is_port_exit_edge(v1, v2):
				return false
	return true


func _add_proximity_edges(grid_pos: Vector2i, building_size: Vector2i) -> void:
	_modify_proximity_edges(grid_pos, building_size, 1)

func _remove_proximity_edges(grid_pos: Vector2i, building_size: Vector2i) -> void:
	_modify_proximity_edges(grid_pos, building_size, -1)

func _modify_proximity_edges(grid_pos: Vector2i, building_size: Vector2i, delta: int) -> void:
	var bx := grid_pos.x
	var by := grid_pos.y
	var sw := building_size.x
	var sh := building_size.y
	# Right boundary → block v-edges 1 column right (range covers corner cells)
	for y in range(by - 1, by + sh + 1):
		var key := Vector2i(bx + sw + 1, y)
		_proximity_v_edges[key] = _proximity_v_edges.get(key, 0) + delta
		if _proximity_v_edges[key] <= 0:
			_proximity_v_edges.erase(key)
	# Left boundary → block v-edges 1 column left
	for y in range(by - 1, by + sh + 1):
		var key := Vector2i(bx - 1, y)
		_proximity_v_edges[key] = _proximity_v_edges.get(key, 0) + delta
		if _proximity_v_edges[key] <= 0:
			_proximity_v_edges.erase(key)
	# Top boundary → block h-edges 1 row above
	for x in range(bx - 1, bx + sw + 1):
		var key := Vector2i(x, by - 1)
		_proximity_h_edges[key] = _proximity_h_edges.get(key, 0) + delta
		if _proximity_h_edges[key] <= 0:
			_proximity_h_edges.erase(key)
	# Bottom boundary → block h-edges 1 row below
	for x in range(bx - 1, bx + sw + 1):
		var key := Vector2i(x, by + sh + 1)
		_proximity_h_edges[key] = _proximity_h_edges.get(key, 0) + delta
		if _proximity_h_edges[key] <= 0:
			_proximity_h_edges.erase(key)


func _vertex_near_occupied(v: Vector2i) -> bool:
	## Check if any of the 4 cells surrounding this vertex is occupied
	for cell in [Vector2i(v.x - 1, v.y - 1), Vector2i(v.x, v.y - 1), Vector2i(v.x - 1, v.y), Vector2i(v.x, v.y)]:
		if _occupied_cells.has(cell) or _source_cells.has(cell):
			return true
	return false


func _edge_has_bridge(v1: Vector2i, v2: Vector2i) -> bool:
	## Check if any cell adjacent to this edge has a bridge building
	var cell_a: Vector2i
	var cell_b: Vector2i
	if v1.y == v2.y:
		var min_x := mini(v1.x, v2.x)
		cell_a = Vector2i(min_x, v1.y - 1)
		cell_b = Vector2i(min_x, v1.y)
	else:
		var min_y := mini(v1.y, v2.y)
		cell_a = Vector2i(v1.x - 1, min_y)
		cell_b = Vector2i(v1.x, min_y)
	for cell in [cell_a, cell_b]:
		if _occupied_cells.has(cell):
			var building = _occupied_cells[cell]
			if building and building.definition and building.definition.allows_cable_crossing:
				return true
	return false


func _is_port_exit_edge(v1: Vector2i, v2: Vector2i) -> bool:
	## Check if this edge touches a port exit vertex — exempt from proximity blocking
	for v in [v1, v2]:
		if _port_exit_vertices.has(v):
			var port_side: String = _port_exit_vertices[v]
			match port_side:
				"left", "right":
					# Horizontal port — allow vertical edges at exit vertex
					if v1.x == v2.x:
						return true
				"top", "bottom":
					# Vertical port — allow horizontal edges at exit vertex
					if v1.y == v2.y:
						return true
	return false


func _calc_port_exit_vertices(bx: int, by: int, sw: int, sh: int, port_side: String) -> Array[Vector2i]:
	match port_side:
		"right":
			var vx: int = bx + sw + 1
			var vy_mid: int = by + sh / 2
			if sh % 2 == 0:
				return [Vector2i(vx, vy_mid)]
			else:
				return [Vector2i(vx, vy_mid), Vector2i(vx, vy_mid + 1)]
		"left":
			var vx: int = bx - 1
			var vy_mid: int = by + sh / 2
			if sh % 2 == 0:
				return [Vector2i(vx, vy_mid)]
			else:
				return [Vector2i(vx, vy_mid), Vector2i(vx, vy_mid + 1)]
		"top":
			var vy: int = by - 1
			var vx_mid: int = bx + sw / 2
			if sw % 2 == 0:
				return [Vector2i(vx_mid, vy)]
			else:
				return [Vector2i(vx_mid, vy), Vector2i(vx_mid + 1, vy)]
		"bottom":
			var vy: int = by + sh + 1
			var vx_mid: int = bx + sw / 2
			if sw % 2 == 0:
				return [Vector2i(vx_mid, vy)]
			else:
				return [Vector2i(vx_mid, vy), Vector2i(vx_mid + 1, vy)]
	return []


func _register_port_exits(grid_pos: Vector2i, building_size: Vector2i, def) -> void:
	var bx := grid_pos.x
	var by := grid_pos.y
	var sw := building_size.x
	var sh := building_size.y
	for port_side in def.output_ports:
		for v in _calc_port_exit_vertices(bx, by, sw, sh, port_side):
			_port_exit_vertices[v] = port_side
	for port_side in def.input_ports:
		for v in _calc_port_exit_vertices(bx, by, sw, sh, port_side):
			_port_exit_vertices[v] = port_side


func _unregister_port_exits(grid_pos: Vector2i, building_size: Vector2i, def) -> void:
	var bx := grid_pos.x
	var by := grid_pos.y
	var sw := building_size.x
	var sh := building_size.y
	for port_side in def.output_ports:
		for v in _calc_port_exit_vertices(bx, by, sw, sh, port_side):
			_port_exit_vertices.erase(v)
	for port_side in def.input_ports:
		for v in _calc_port_exit_vertices(bx, by, sw, sh, port_side):
			_port_exit_vertices.erase(v)


func occupy_cable_edge(v1: Vector2i, v2: Vector2i) -> void:
	var data: Array = _get_edge_data(v1, v2)
	var dict: Dictionary = data[0]
	var key: Vector2i = data[1]
	dict[key] = dict.get(key, 0) + 1


func free_cable_edge(v1: Vector2i, v2: Vector2i) -> void:
	var data: Array = _get_edge_data(v1, v2)
	var dict: Dictionary = data[0]
	var key: Vector2i = data[1]
	var count: int = dict.get(key, 0) - 1
	if count <= 0:
		dict.erase(key)
	else:
		dict[key] = count


func has_cable_at_edge(v1: Vector2i, v2: Vector2i) -> bool:
	var data: Array = _get_edge_data(v1, v2)
	return data[0].get(data[1], 0) > 0


func get_cable_edge_at_point(world_pos: Vector2) -> Array:
	## Returns [v1, v2] of the nearest cable edge to world_pos, or empty array
	var vx: float = world_pos.x / TILE_SIZE
	var vy: float = world_pos.y / TILE_SIZE
	# Check the 4 nearest edges
	var near_v := Vector2i(roundi(vx), roundi(vy))
	var best_dist: float = 20.0  # max pixel distance to detect
	var best_edge: Array = []
	# Check edges around the nearest vertex
	var candidates: Array[Array] = [
		[near_v, near_v + Vector2i(1, 0)],
		[near_v, near_v + Vector2i(-1, 0)],
		[near_v, near_v + Vector2i(0, 1)],
		[near_v, near_v + Vector2i(0, -1)],
	]
	# Also check edges from adjacent vertices
	var cell := Vector2i(floori(vx), floori(vy))
	candidates.append([cell, cell + Vector2i(1, 0)])
	candidates.append([cell, cell + Vector2i(0, 1)])
	candidates.append([cell + Vector2i(1, 0), cell + Vector2i(1, 1)])
	candidates.append([cell + Vector2i(0, 1), cell + Vector2i(1, 1)])
	for pair in candidates:
		var v1: Vector2i = pair[0]
		var v2: Vector2i = pair[1]
		if not has_cable_at_edge(v1, v2):
			continue
		var p1 := Vector2(v1.x * TILE_SIZE, v1.y * TILE_SIZE)
		var p2 := Vector2(v2.x * TILE_SIZE, v2.y * TILE_SIZE)
		var closest := Geometry2D.get_closest_point_to_segment(world_pos, p1, p2)
		var dist: float = world_pos.distance_to(closest)
		if dist < best_dist:
			best_dist = dist
			best_edge = [v1, v2]
	return best_edge


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

	# Cable edge underglow
	var cable_ug := Color(0.0, 0.6, 0.9, minf(0.06 * ug_scale, 0.15))
	var cable_w: float = maxf(2.0, 4.0 * ug_scale)
	for edge_key in _cable_h_edges:
		if edge_key.x < sx - 1 or edge_key.x > ex + 1 or edge_key.y < sy - 1 or edge_key.y > ey + 1:
			continue
		var p1 := Vector2(edge_key.x * TILE_SIZE, edge_key.y * TILE_SIZE)
		var p2 := Vector2((edge_key.x + 1) * TILE_SIZE, edge_key.y * TILE_SIZE)
		draw_line(p1, p2, cable_ug, cable_w)
	for edge_key in _cable_v_edges:
		if edge_key.x < sx - 1 or edge_key.x > ex + 1 or edge_key.y < sy - 1 or edge_key.y > ey + 1:
			continue
		var p1 := Vector2(edge_key.x * TILE_SIZE, edge_key.y * TILE_SIZE)
		var p2 := Vector2(edge_key.x * TILE_SIZE, (edge_key.y + 1) * TILE_SIZE)
		draw_line(p1, p2, cable_ug, cable_w)

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
