extends Node2D

const TILE_SIZE: int = 64

const BG_COLOR := Color("#081420")              # Cyan-tinted dark blue
const GRID_LINE_COLOR := Color(0.28, 0.06, 0.18) # Cyberpunk magenta-red grid
const MAP_CENTER := Vector2(256 * 64, 256 * 64)  ## Center in pixels (256,256 grid * 64px)

# PCB background pattern — cyberpunk magenta-red
const PCB_TRACE_COLOR := Color(0.35, 0.08, 0.20)
const PCB_VIA_COLOR := Color(0.50, 0.12, 0.30)
const PCB_PAD_COLOR := Color(0.28, 0.06, 0.16)
const PCB_TRACE_WIDTH: float = 2.0

var _occupied_cells: Dictionary = {}
var _source_cells: Dictionary = {}  ## cell → source Node2D ref

## Edge-based cable tracking
## Horizontal edge key: Vector2i(x, y) = edge from vertex (x,y) to (x+1,y)
## Vertical edge key: Vector2i(x, y) = edge from vertex (x,y) to (x,y+1)
var _cable_h_edges: Dictionary = {}  ## Vector2i → int (cable count)
var _cable_v_edges: Dictionary = {}  ## Vector2i → int (cable count)

# GPU shader background (PCB + grid rendered entirely on GPU)
var _bg_rect: ColorRect = null
var _bg_material: ShaderMaterial = null

# GPU underglow texture — maps grid cells to building/cable colors
var _underglow_image: Image = null
var _underglow_texture: ImageTexture = null
var _underglow_dirty: bool = false
const UNDERGLOW_TEX_SIZE: int = 512
const CABLE_UNDERGLOW_COLOR := Color(0.13, 0.53, 0.73, 0.5)  # cyan, half alpha for cables



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
	var color := Color(0.3, 0.6, 0.8, 1.0)
	if building_ref and building_ref.get("definition") and building_ref.definition:
		color = Color(building_ref.definition.color, 1.0)
	for x in range(building_size.x):
		for y in range(building_size.y):
			var cell := Vector2i(grid_pos.x + x, grid_pos.y + y)
			_occupied_cells[cell] = building_ref
			_set_underglow_pixel(cell, color)


func free_cells(grid_pos: Vector2i, building_size: Vector2i) -> void:
	for x in range(building_size.x):
		for y in range(building_size.y):
			var cell := Vector2i(grid_pos.x + x, grid_pos.y + y)
			_occupied_cells.erase(cell)
			_set_underglow_pixel(cell, Color(0, 0, 0, 0))


func get_building_at(cell: Vector2i) -> Node:
	return _occupied_cells.get(cell, null)


func occupy_source(cells: Array[Vector2i], source_ref: Node) -> void:
	for cell in cells:
		_source_cells[cell] = source_ref


func free_source_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_source_cells.erase(cell)


# --- EDGE-BASED CABLE FUNCTIONS ---

func _get_edge_data(v1: Vector2i, v2: Vector2i) -> Array:
	## Returns [dictionary_ref, key] for the edge between v1 and v2
	if v1.y == v2.y:  # horizontal edge
		return [_cable_h_edges, Vector2i(mini(v1.x, v2.x), v1.y)]
	else:  # vertical edge
		return [_cable_v_edges, Vector2i(v1.x, mini(v1.y, v2.y))]


func can_place_cable_edge(v1: Vector2i, v2: Vector2i, exempt_cells: Dictionary = {}) -> bool:
	# Must be adjacent (differ by 1 in exactly one axis)
	var diff := v2 - v1
	if absi(diff.x) + absi(diff.y) != 1:
		return false
	# Check if already occupied
	var data: Array = _get_edge_data(v1, v2)
	var dict: Dictionary = data[0]
	var key: Vector2i = data[1]
	if dict.has(key):
		return false  # Edge already has a cable
	# Block if edge touches any occupied cell (building or source)
	if _edge_touches_occupied(v1, v2, exempt_cells):
		return false
	return true


func _edge_touches_occupied(v1: Vector2i, v2: Vector2i, exempt_cells: Dictionary = {}) -> bool:
	## Returns true if ANY cell adjacent to this edge is occupied.
	## Cables cannot be on building/source boundary edges — only 1 cell away.
	## exempt_cells: cells to skip (port exit areas of source/target buildings).
	var cell_a: Vector2i
	var cell_b: Vector2i
	if v1.y == v2.y:  # horizontal edge
		var x := mini(v1.x, v2.x)
		cell_a = Vector2i(x, v1.y - 1)  # cell above
		cell_b = Vector2i(x, v1.y)      # cell below
	else:  # vertical edge
		var y := mini(v1.y, v2.y)
		cell_a = Vector2i(v1.x - 1, y)  # cell left
		cell_b = Vector2i(v1.x, y)      # cell right
	if (_occupied_cells.has(cell_a) or _source_cells.has(cell_a)) and not exempt_cells.has(cell_a):
		return true
	if (_occupied_cells.has(cell_b) or _source_cells.has(cell_b)) and not exempt_cells.has(cell_b):
		return true
	return false


func is_turn_corner_occupied(v: Vector2i, prev_v: Vector2i, next_v: Vector2i, exempt_cells: Dictionary = {}) -> bool:
	## When a cable turns at vertex V, check if the diagonal corner cell is occupied.
	## Prevents cables from "cutting corners" of buildings/sources.
	var d_in: Vector2i = v - prev_v
	var d_out: Vector2i = next_v - v
	# Only applies to turns (perpendicular directions)
	if d_in == d_out:
		return false  # straight line, no corner issue
	var dx: int
	var dy: int
	if d_in.x != 0:
		dx = 0 if d_in.x > 0 else -1
		dy = 0 if d_out.y < 0 else -1
	else:
		dx = 0 if d_out.x < 0 else -1
		dy = 0 if d_in.y > 0 else -1
	var cell := Vector2i(v.x + dx, v.y + dy)
	return (_occupied_cells.has(cell) or _source_cells.has(cell)) and not exempt_cells.has(cell)






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


func _pcb_hash(x: int, y: int, seed_val: int) -> int:
	return ((x * 73856093) ^ (y * 19349663) ^ (seed_val * 83492791)) & 0x7FFFFFFF


func _draw_pcb_pattern(sx: int, ex: int, sy: int, ey: int, zoom_level: float) -> void:
	## Deterministic PCB trace/via/pad pattern — "circuit board" background feel
	if zoom_level < 0.15:
		return
	var alpha_scale: float = clampf((zoom_level - 0.15) / 0.25, 0.0, 1.0)
	var trace_a: float = 0.04 * alpha_scale
	var trace_col := Color(PCB_TRACE_COLOR, trace_a)

	# Sample step — skip cells at low zoom for performance
	var step: int = 1
	if zoom_level < 0.3:
		step = 4
	elif zoom_level < 0.5:
		step = 2

	var asx: int = sx - posmod(sx, step)
	var asy: int = sy - posmod(sy, step)

	# --- Horizontal traces ---
	for y in range(asy, ey + 1, step):
		for x in range(asx, ex, step):
			var h := _pcb_hash(x, y, 1)
			if h % 11 == 0:
				var len_cells: int = (1 + (h >> 4) % 3) * step
				var x2: int = mini(x + len_cells, ex)
				draw_line(
					Vector2(x * TILE_SIZE, y * TILE_SIZE),
					Vector2(x2 * TILE_SIZE, y * TILE_SIZE),
					trace_col, PCB_TRACE_WIDTH)

	# --- Vertical traces ---
	for x in range(asx, ex + 1, step):
		for y in range(asy, ey, step):
			var h := _pcb_hash(x, y, 2)
			if h % 13 == 0:
				var len_cells: int = (1 + (h >> 4) % 3) * step
				var y2: int = mini(y + len_cells, ey)
				draw_line(
					Vector2(x * TILE_SIZE, y * TILE_SIZE),
					Vector2(x * TILE_SIZE, y2 * TILE_SIZE),
					trace_col, PCB_TRACE_WIDTH)

	# --- Via points (zoom > 0.3) ---
	if zoom_level > 0.3:
		var via_a: float = 0.06 * alpha_scale
		var via_col := Color(PCB_VIA_COLOR, via_a)
		var via_ring := Color(PCB_VIA_COLOR, via_a * 0.6)
		for x in range(asx, ex + 1, step):
			for y in range(asy, ey + 1, step):
				var h := _pcb_hash(x, y, 3)
				if h % 19 == 0:
					var pos := Vector2(x * TILE_SIZE, y * TILE_SIZE)
					draw_circle(pos, 3.5, via_col)
					draw_arc(pos, 5.0, 0.0, TAU, 8, via_ring, 1.0)

	# --- Component pads (zoom > 0.25) ---
	if zoom_level > 0.25:
		var pad_a: float = 0.035 * alpha_scale
		var pad_fill := Color(PCB_PAD_COLOR, pad_a)
		var pad_border := Color(PCB_PAD_COLOR, pad_a * 1.5)
		for x in range(sx, ex):
			for y in range(sy, ey):
				var h := _pcb_hash(x, y, 4)
				if h % 29 == 0:
					var cx: float = (x + 0.5) * TILE_SIZE
					var cy: float = (y + 0.5) * TILE_SIZE
					var ps: float = 10.0
					var pr := Rect2(cx - ps * 0.5, cy - ps * 0.5, ps, ps)
					draw_rect(pr, pad_fill, true)
					draw_rect(pr, pad_border, false, 1.0)


func _ready() -> void:
	_setup_gpu_background()


func _setup_gpu_background() -> void:
	## Create full-viewport ColorRect with PCB+grid shader (zero CPU cost)
	var shader: Shader = load("res://shaders/pcb_grid.gdshader")
	if shader == null:
		push_warning("[GridSystem] PCB shader not found — falling back to CPU draw")
		return
	_bg_material = ShaderMaterial.new()
	_bg_material.shader = shader
	_bg_rect = ColorRect.new()
	_bg_rect.material = _bg_material
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Add to a CanvasLayer at z=-100 so it's always behind everything
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -100
	bg_layer.name = "PCBBackground"
	bg_layer.add_child(_bg_rect)
	add_child(bg_layer)
	_setup_underglow_texture()


func _process(_delta: float) -> void:
	# Update GPU shader uniforms with camera state
	if _bg_material:
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam:
			var zoom: float = cam.zoom.x
			var vp_size := get_viewport_rect().size / cam.zoom
			_bg_material.set_shader_parameter("camera_pos", cam.global_position)
			_bg_material.set_shader_parameter("viewport_size", vp_size)
			_bg_material.set_shader_parameter("zoom_level", zoom)
	_upload_underglow()
	queue_redraw()


func _draw() -> void:
	var _grid_t0: int = Time.get_ticks_usec()
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var zoom_level: float = cam.zoom.x

	# Background + PCB + grid are rendered by GPU shader (_bg_rect)
	# CPU fallback only if shader not loaded
	var vp_size := get_viewport_rect().size / cam.zoom
	var cam_pos := cam.global_position - vp_size / 2.0
	if _bg_material == null:
		# CPU fallback: draw background + PCB + grid
		draw_rect(Rect2(cam_pos, vp_size), BG_COLOR, true)
		var sx_f: int = int(cam_pos.x / TILE_SIZE) - 1
		var ex_f: int = int((cam_pos.x + vp_size.x) / TILE_SIZE) + 2
		var sy_f: int = int(cam_pos.y / TILE_SIZE) - 1
		var ey_f: int = int((cam_pos.y + vp_size.y) / TILE_SIZE) + 2
		_draw_pcb_pattern(sx_f, ex_f, sy_f, ey_f, zoom_level)
		_draw_grid_lines(cam_pos, vp_size, zoom_level)

	# Underglow rendered by GPU shader via underglow texture
	PerfMonitor.grid_pcb_us = 0
	PerfMonitor.grid_draw_us = Time.get_ticks_usec() - _grid_t0


func _draw_grid_lines(cam_pos: Vector2, vp_size: Vector2, zoom_level: float) -> void:
	## CPU fallback for grid lines (used when shader not available)
	var grid_step: int
	if zoom_level >= 0.8:
		grid_step = 1
	elif zoom_level >= 0.4:
		grid_step = 2
	elif zoom_level >= 0.2:
		grid_step = 4
	elif zoom_level >= 0.1:
		grid_step = 8
	else:
		grid_step = 16
	var grid_width: float = clampf(1.5 / zoom_level, 1.0, 50.0)
	var grid_a: float = clampf(0.3 + (1.0 - zoom_level) * 0.15, 0.3, 0.55)
	var line_color := Color(GRID_LINE_COLOR, grid_a)
	var start_x: int = floori(cam_pos.x / TILE_SIZE) - posmod(floori(cam_pos.x / TILE_SIZE), grid_step)
	var end_x: int = ceili((cam_pos.x + vp_size.x) / TILE_SIZE)
	var start_y: int = floori(cam_pos.y / TILE_SIZE) - posmod(floori(cam_pos.y / TILE_SIZE), grid_step)
	var end_y: int = ceili((cam_pos.y + vp_size.y) / TILE_SIZE)
	var rx: int = posmod(end_x, grid_step)
	if rx != 0:
		end_x += grid_step - rx
	var ry: int = posmod(end_y, grid_step)
	if ry != 0:
		end_y += grid_step - ry
	for x in range(start_x, end_x + 1, grid_step):
		draw_line(Vector2(x * TILE_SIZE, start_y * TILE_SIZE), Vector2(x * TILE_SIZE, end_y * TILE_SIZE), line_color, grid_width, true)
	for y in range(start_y, end_y + 1, grid_step):
		draw_line(Vector2(start_x * TILE_SIZE, y * TILE_SIZE), Vector2(end_x * TILE_SIZE, y * TILE_SIZE), line_color, grid_width, true)


# =============================================================================
# GPU UNDERGLOW TEXTURE — building/cable underglow via shader (Faz 3)
# =============================================================================

func _setup_underglow_texture() -> void:
	## Create underglow data texture for GPU-based rendering.
	## Each pixel = 1 grid cell. RGB = accent color, A = type (1.0 building, 0.5 cable).
	_underglow_image = Image.create(UNDERGLOW_TEX_SIZE, UNDERGLOW_TEX_SIZE, false, Image.FORMAT_RGBA8)
	_underglow_image.fill(Color(0, 0, 0, 0))
	_underglow_texture = ImageTexture.create_from_image(_underglow_image)
	if _bg_material:
		_bg_material.set_shader_parameter("underglow_tex", _underglow_texture)
		_bg_material.set_shader_parameter("underglow_tex_size", float(UNDERGLOW_TEX_SIZE))


func _set_underglow_pixel(cell: Vector2i, color: Color) -> void:
	## Set a single pixel in the underglow texture. Uses modular addressing.
	if _underglow_image == null:
		return
	var tx: int = posmod(cell.x, UNDERGLOW_TEX_SIZE)
	var ty: int = posmod(cell.y, UNDERGLOW_TEX_SIZE)
	_underglow_image.set_pixel(tx, ty, color)
	_underglow_dirty = true


func _update_cable_underglow(v1: Vector2i, v2: Vector2i, has_cable: bool) -> void:
	## Update underglow pixels for cells adjacent to a cable edge.
	if _underglow_image == null:
		return
	if has_cable:
		# Color both cells adjacent to the edge
		if v1.y == v2.y:  # horizontal edge
			var x_min: int = mini(v1.x, v2.x)
			# Cells above and below the edge
			var cell_above := Vector2i(x_min, v1.y - 1)
			var cell_below := Vector2i(x_min, v1.y)
			if not _occupied_cells.has(cell_above):
				_set_underglow_pixel(cell_above, CABLE_UNDERGLOW_COLOR)
			if not _occupied_cells.has(cell_below):
				_set_underglow_pixel(cell_below, CABLE_UNDERGLOW_COLOR)
		else:  # vertical edge
			var y_min: int = mini(v1.y, v2.y)
			var cell_left := Vector2i(v1.x - 1, y_min)
			var cell_right := Vector2i(v1.x, y_min)
			if not _occupied_cells.has(cell_left):
				_set_underglow_pixel(cell_left, CABLE_UNDERGLOW_COLOR)
			if not _occupied_cells.has(cell_right):
				_set_underglow_pixel(cell_right, CABLE_UNDERGLOW_COLOR)
	else:
		# Clear cable underglow (only if no building occupies the cell)
		if v1.y == v2.y:
			var x_min: int = mini(v1.x, v2.x)
			var cell_above := Vector2i(x_min, v1.y - 1)
			var cell_below := Vector2i(x_min, v1.y)
			if not _occupied_cells.has(cell_above) and not _has_adjacent_cable(cell_above):
				_set_underglow_pixel(cell_above, Color(0, 0, 0, 0))
			if not _occupied_cells.has(cell_below) and not _has_adjacent_cable(cell_below):
				_set_underglow_pixel(cell_below, Color(0, 0, 0, 0))
		else:
			var y_min: int = mini(v1.y, v2.y)
			var cell_left := Vector2i(v1.x - 1, y_min)
			var cell_right := Vector2i(v1.x, y_min)
			if not _occupied_cells.has(cell_left) and not _has_adjacent_cable(cell_left):
				_set_underglow_pixel(cell_left, Color(0, 0, 0, 0))
			if not _occupied_cells.has(cell_right) and not _has_adjacent_cable(cell_right):
				_set_underglow_pixel(cell_right, Color(0, 0, 0, 0))


func _has_adjacent_cable(cell: Vector2i) -> bool:
	## Check if any cable edge touches this cell.
	return (_cable_h_edges.has(cell) or _cable_h_edges.has(Vector2i(cell.x, cell.y + 1))
		or _cable_v_edges.has(cell) or _cable_v_edges.has(Vector2i(cell.x + 1, cell.y)))


func _upload_underglow() -> void:
	## Upload underglow image to GPU once per frame (only if dirty).
	if _underglow_dirty and _underglow_texture:
		_underglow_texture.update(_underglow_image)
		_underglow_dirty = false
