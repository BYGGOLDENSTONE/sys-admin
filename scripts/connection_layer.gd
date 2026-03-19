extends Node2D

const _MONO_FONT: Font = preload("res://assets/fonts/JetBrainsMono-Regular.ttf")
const TILE_SIZE: int = 64
const CABLE_WIDTH: float = 5.0
const CABLE_GLOW_WIDTH: float = 11.0
const CABLE_COLOR := Color(0.67, 0.73, 0.8, 0.7)  # Silver-white — neutral PCB trace
const PARTICLE_FONT_SIZE: int = 20
const HOVER_COLOR := Color(1.0, 0.3, 0.3, 0.6)
const HOVER_WIDTH: float = 14.0
const PREVIEW_VALID_COLOR := Color(0.2, 1, 0.67, 0.5)
const PREVIEW_INVALID_COLOR := Color(1, 0.13, 0.27, 0.5)

var connection_manager: Node = null
var simulation_manager: Node = null
var hovered_cable_index: int = -1
var _camera: Camera2D = null
var _polyline_helper: RefCounted = null


# Preview state (set by BuildingManager during CONNECTING)
var preview_path: Array[Vector2i] = []
var preview_active: bool = false
var preview_valid: bool = true
var preview_from_pos: Vector2 = Vector2.ZERO
var preview_to_pos: Vector2 = Vector2.ZERO
var preview_from_port: String = ""
var preview_blocked: bool = false  ## True when cable can't reach mouse vertex

# Connection flash effect
var _flash_positions: Array[Vector2] = []
var _flash_times: Array[float] = []
var _flash_colors: Array[Color] = []
const FLASH_DURATION: float = 0.6

# Cable removal flash effect
var _removal_flash_paths: Array = []
var _removal_flash_times: Array[float] = []
var _removal_flash_colors: Array[Color] = []
const REMOVAL_FLASH_DURATION: float = 0.4

# Box selection overlay (set by BuildingManager)
var box_select_active: bool = false
var box_select_start: Vector2 = Vector2.ZERO
var box_select_end: Vector2 = Vector2.ZERO
var selected_buildings: Array = []  ## Array[Node2D] — buildings with box selection highlight

# --- TRANSIT ITEM MULTIMESH (batch rendering) ---
var _transit_mm: MultiMesh = null
var _transit_mm_node: MultiMeshInstance2D = null
var _glyph_atlas: Texture2D = null
var _transit_shader_mat: ShaderMaterial = null
var _atlas_ready: bool = false
const MAX_TRANSIT_INSTANCES: int = 4096

# Glyph mapping: content_type → atlas column index
const GLYPH_CHARS: Array = ["1", "$", "@", "#", "?", "!", "K", "P", " ", " "]
const GLYPH_MAP: Dictionary = {
	0: 0,   # STANDARD → "1"
	1: 1,   # FINANCIAL → "$"
	2: 2,   # BIOMETRIC → "@"
	3: 3,   # BLUEPRINT → "#"
	4: 4,   # RESEARCH → "?"
	5: 5,   # CLASSIFIED → "!"
	6: 6,   # KEY → "K"
}


func _ready() -> void:
	_camera = get_node_or_null("../GameCamera")
	if ClassDB.class_exists("PolylineHelper"):
		_polyline_helper = ClassDB.instantiate("PolylineHelper")
		print("[ConnectionLayer] C++ PolylineHelper loaded")
	else:
		print("[ConnectionLayer] PolylineHelper — GDScript fallback")
	_init_transit_multimesh()


func _process(delta: float) -> void:
	if connection_manager == null:
		queue_redraw()
		return

	# Update flash timers
	var fi: int = _flash_times.size() - 1
	while fi >= 0:
		_flash_times[fi] -= delta
		if _flash_times[fi] <= 0:
			_flash_times.remove_at(fi)
			_flash_positions.remove_at(fi)
			_flash_colors.remove_at(fi)
		fi -= 1
	# Update removal flash timers
	var ri: int = _removal_flash_times.size() - 1
	while ri >= 0:
		_removal_flash_times[ri] -= delta
		if _removal_flash_times[ri] <= 0:
			_removal_flash_times.remove_at(ri)
			_removal_flash_paths.remove_at(ri)
			_removal_flash_colors.remove_at(ri)
		ri -= 1
	# Update transit MultiMesh positions (before redraw)
	if _atlas_ready:
		_update_transit_multimesh()
	# Always redraw: cables have pulse animation and transit items move every frame
	queue_redraw()


func _get_viewport_bounds() -> Rect2:
	## Returns camera viewport bounds in local coordinates for frustum culling.
	if _camera == null:
		return Rect2(-1e9, -1e9, 2e9, 2e9)
	var vp_size := get_viewport_rect().size / _camera.zoom
	var cam_pos := to_local(_camera.global_position)
	var margin := 256.0  # Extra margin for glow/halo overshoot
	return Rect2(cam_pos - vp_size / 2.0 - Vector2(margin, margin), vp_size + Vector2(margin * 2, margin * 2))


func _is_conn_in_viewport(conn: Dictionary, vp: Rect2) -> bool:
	## Fast AABB check: connection is visible if any of from/to buildings overlap viewport.
	var from_pos: Vector2 = to_local(conn.from_building.global_position)
	var to_pos: Vector2 = to_local(conn.to_building.global_position)
	var min_x: float = minf(from_pos.x, to_pos.x)
	var min_y: float = minf(from_pos.y, to_pos.y)
	var max_x: float = maxf(from_pos.x, to_pos.x) + TILE_SIZE * 4.0
	var max_y: float = maxf(from_pos.y, to_pos.y) + TILE_SIZE * 4.0
	return vp.intersects(Rect2(min_x, min_y, max_x - min_x, max_y - min_y))


func _draw() -> void:
	if connection_manager == null:
		return

	var _draw_t0: int = Time.get_ticks_usec()
	var zoom: float = _get_zoom_level()
	var conns: Array[Dictionary] = connection_manager.get_connections()
	var vp_bounds: Rect2 = _get_viewport_bounds()
	# Build per-frame cache of buildings with incoming transit
	var _items_us: int = 0
	var _items_calls: int = 0
	for i in range(conns.size()):
		var conn: Dictionary = conns[i]
		if not is_instance_valid(conn.from_building) or not is_instance_valid(conn.to_building):
			continue
		# Viewport frustum culling — skip cables entirely off-screen
		if not _is_conn_in_viewport(conn, vp_bounds):
			continue
		var hovered: bool = (i == hovered_cable_index)
		_draw_connection(conn, hovered)
		# Transit items: MultiMesh handles rendering when atlas is ready
		if not _atlas_ready and zoom > 0.25:
			var _it0: int = Time.get_ticks_usec()
			_draw_transit_items(conn, i)
			_items_us += Time.get_ticks_usec() - _it0
			_items_calls += 1

	if preview_active and not preview_path.is_empty():
		_draw_preview()

	# Draw connection flash effects
	for fi in range(_flash_positions.size()):
		var t: float = _flash_times[fi] / FLASH_DURATION
		var flash_pos: Vector2 = _flash_positions[fi]
		var flash_col: Color = _flash_colors[fi]
		# Expanding ring + fading
		var ring_radius: float = (1.0 - t) * 80.0
		var ring_alpha: float = t * 0.6
		draw_circle(flash_pos, ring_radius, Color(flash_col, ring_alpha * 0.15))
		draw_circle(flash_pos, ring_radius * 0.6, Color(flash_col, ring_alpha * 0.3))
		draw_circle(flash_pos, 8.0 * t, Color(1.0, 1.0, 1.0, ring_alpha * 0.5))

	# Draw cable removal flash effects (red shrink)
	for ri in range(_removal_flash_paths.size()):
		var rt: float = _removal_flash_times[ri] / REMOVAL_FLASH_DURATION
		var rpoints: PackedVector2Array = _removal_flash_paths[ri]
		var rcol: Color = _removal_flash_colors[ri]
		if rpoints.size() >= 2:
			var rw: float = CABLE_WIDTH * 3.0 * rt
			draw_polyline(rpoints, Color(rcol, rt * 0.6), maxf(1.0, rw), true)
			draw_polyline(rpoints, Color(1.0, 1.0, 1.0, rt * 0.3), maxf(1.0, rw * 0.4), true)

	# Box selection rectangle
	if box_select_active:
		var min_pos := Vector2(minf(box_select_start.x, box_select_end.x), minf(box_select_start.y, box_select_end.y))
		var max_pos := Vector2(maxf(box_select_start.x, box_select_end.x), maxf(box_select_start.y, box_select_end.y))
		var rect_pos: Vector2 = to_local(min_pos)
		var rect_size: Vector2 = max_pos - min_pos
		draw_rect(Rect2(rect_pos, rect_size), Color(0.3, 0.7, 1.0, 0.15), true)
		draw_rect(Rect2(rect_pos, rect_size), Color(0.3, 0.7, 1.0, 0.6), false, 2.0)
	# Selection highlight for box-selected buildings
	for b in selected_buildings:
		if is_instance_valid(b):
			var bpos: Vector2 = to_local(b.global_position)
			var bsize := Vector2(b.definition.grid_size.x * TILE_SIZE, b.definition.grid_size.y * TILE_SIZE)
			draw_rect(Rect2(bpos, bsize), Color(0.3, 0.7, 1.0, 0.1), true)

	# Performance monitoring
	PerfMonitor.conn_draw_us = Time.get_ticks_usec() - _draw_t0
	PerfMonitor.conn_draw_items_us = _items_us
	PerfMonitor.conn_draw_calls = _items_calls


func _get_zoom_level() -> float:
	if _camera:
		return _camera.zoom.x
	return 1.0


func _get_cached_polyline(conn: Dictionary) -> PackedVector2Array:
	## Returns cached polyline + precomputed segment lengths for this connection.
	## Cache is stored in the connection dict itself and computed once (path never changes).
	if not conn.has("_cached_polyline"):
		var points: PackedVector2Array = _build_polyline(conn)
		conn["_cached_polyline"] = points
		var seg_lengths: Array[float] = []
		var total: float = 0.0
		for i in range(1, points.size()):
			var seg_len: float = points[i - 1].distance_to(points[i])
			seg_lengths.append(seg_len)
			total += seg_len
		conn["_cached_seg_lengths"] = seg_lengths
		conn["_cached_total_length"] = total
		if _polyline_helper:
			conn["_cached_cumulative_dists"] = _polyline_helper.build_cumulative_distances(seg_lengths)
	return conn["_cached_polyline"]


func _draw_connection(conn: Dictionary, hovered: bool) -> void:
	var path: Array = conn.path
	if path.size() < 2:
		return
	var points: PackedVector2Array = _get_cached_polyline(conn)
	if points.size() < 2:
		return

	var zoom: float = _get_zoom_level()
	# Scale cable thickness at low zoom so cables stay visible
	var zoom_scale: float = clampf(1.0 / zoom, 1.0, 2.5) if zoom < 1.0 else 1.0
	var core_w: float = CABLE_WIDTH * zoom_scale

	if hovered:
		draw_polyline(points, HOVER_COLOR, HOVER_WIDTH * zoom_scale, true)

	# Cable color based on transit load (green→yellow→red)
	var cable_col: Color = CABLE_COLOR
	var transit: Array = conn.get("transit", [])
	if not transit.is_empty():
		var total: int = 0
		for ti in transit:
			total += int(ti.amount)
		var load_ratio: float = clampf(float(total) / 50.0, 0.0, 1.0)  # 50 = bandwidth reference
		if load_ratio > 0.7:
			cable_col = Color(1.0, 0.3, 0.2, 0.85)   # Red — near capacity
		elif load_ratio > 0.3:
			cable_col = Color(1.0, 0.8, 0.2, 0.8)     # Yellow — moderate
		else:
			cable_col = Color(0.2, 0.9, 0.5, 0.75)     # Green — light load
	draw_polyline(points, cable_col, core_w, true)


func _build_polyline(conn: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	var path: Array = conn.path
	if path.is_empty():
		return points

	# Start from port position
	var from_pos: Vector2 = to_local(conn.from_building.get_port_world_position(conn.from_port))
	var first_v: Vector2 = _vertex_pos(path[0])
	points.append(from_pos)
	# Add stub for clean exit angle from source port (use physical side for direction)
	var from_physical: String = conn.from_building._get_physical_side(conn.from_port)
	var from_stub := _port_stub(from_pos, first_v, from_physical)
	if from_stub != from_pos and from_stub != first_v:
		points.append(from_stub)
	# Add vertex positions (grid intersection points)
	for vertex in path:
		points.append(_vertex_pos(vertex))
	# Add stub for clean entry angle into target port
	var to_pos: Vector2 = to_local(conn.to_building.get_port_world_position(conn.to_port))
	var last_v: Vector2 = _vertex_pos(path[path.size() - 1])
	var to_physical: String = conn.to_building._get_physical_side(conn.to_port)
	var to_stub := _port_stub_entry(to_pos, last_v, to_physical)
	if to_stub != last_v and to_stub != to_pos:
		points.append(to_stub)
	points.append(to_pos)
	return points


func _port_stub(port_pos: Vector2, vertex_pos: Vector2, port_side: String) -> Vector2:
	## Returns an intermediate point that ensures the cable enters/exits the port
	## at a right angle (perpendicular to the building face).
	## For 1x1 buildings (32px offset), skip stub to avoid zigzag artifacts.
	var base_side: String = port_side
	var us_pos: int = port_side.find("_")
	if us_pos >= 0:
		base_side = port_side.substr(0, us_pos)
	match base_side:
		"left", "right":
			var offset := absf(port_pos.y - vertex_pos.y)
			if offset < 1.0 or offset <= TILE_SIZE * 0.55:
				return port_pos
			return Vector2(vertex_pos.x, port_pos.y)
		"top", "bottom":
			var offset := absf(port_pos.x - vertex_pos.x)
			if offset < 1.0 or offset <= TILE_SIZE * 0.55:
				return port_pos
			return Vector2(port_pos.x, vertex_pos.y)
	return port_pos


func _port_stub_entry(port_pos: Vector2, vertex_pos: Vector2, port_side: String) -> Vector2:
	## Target port stub: first align to port's level at vertex position, then go straight into port.
	## For 1x1 buildings (32px offset), skip stub to avoid zigzag artifacts.
	if port_pos.distance_to(vertex_pos) > TILE_SIZE * 2.0:
		return port_pos
	var base_side: String = port_side
	var us_pos: int = port_side.find("_")
	if us_pos >= 0:
		base_side = port_side.substr(0, us_pos)
	match base_side:
		"left", "right":
			var offset := absf(port_pos.y - vertex_pos.y)
			if offset < 1.0 or offset <= TILE_SIZE * 0.55:
				return port_pos
			return Vector2(vertex_pos.x, port_pos.y)
		"top", "bottom":
			var offset := absf(port_pos.x - vertex_pos.x)
			if offset < 1.0 or offset <= TILE_SIZE * 0.55:
				return port_pos
			return Vector2(port_pos.x, vertex_pos.y)
	return port_pos


func _vertex_pos(v: Vector2i) -> Vector2:
	## Grid vertex position (intersection of grid lines)
	return Vector2(v.x * TILE_SIZE, v.y * TILE_SIZE)


func _draw_preview() -> void:
	var valid_color: Color = PREVIEW_VALID_COLOR
	var blocked_color: Color = PREVIEW_INVALID_COLOR
	var pulse := sin(Time.get_ticks_msec() / 150.0) * 0.5 + 0.5

	# Build valid path points (port → stub → vertices)
	var valid_points := PackedVector2Array()
	valid_points.append(preview_from_pos)
	if not preview_path.is_empty():
		var first_v: Vector2 = _vertex_pos(preview_path[0])
		var from_stub := _port_stub(preview_from_pos, first_v, _get_preview_from_port())
		if from_stub != preview_from_pos and from_stub != first_v:
			valid_points.append(from_stub)
	for vertex in preview_path:
		valid_points.append(_vertex_pos(vertex))

	# Draw valid (green) segment
	if valid_points.size() >= 2:
		draw_polyline(valid_points, Color(valid_color, 0.08 + pulse * 0.06), CABLE_GLOW_WIDTH * 2.0, true)
		draw_polyline(valid_points, Color(valid_color, 0.2 + pulse * 0.1), CABLE_GLOW_WIDTH, true)
		draw_polyline(valid_points, Color(valid_color, 0.7 + pulse * 0.3), CABLE_WIDTH + 1.0, true)
		draw_circle(valid_points[0], 5.0, Color(valid_color, 0.5 + pulse * 0.3))

	# Draw blocked (red) segment from last valid vertex to mouse
	if preview_blocked and valid_points.size() >= 1:
		var blocked_points := PackedVector2Array()
		blocked_points.append(valid_points[valid_points.size() - 1])
		blocked_points.append(preview_to_pos)
		draw_polyline(blocked_points, Color(blocked_color, 0.5 + pulse * 0.2), CABLE_WIDTH + 1.0, true)
		draw_circle(preview_to_pos, 5.0, Color(blocked_color, 0.6 + pulse * 0.3))
	elif valid_points.size() >= 1:
		# Not blocked — draw line to mouse in valid color
		var tail_points := PackedVector2Array()
		tail_points.append(valid_points[valid_points.size() - 1])
		tail_points.append(preview_to_pos)
		draw_polyline(tail_points, Color(valid_color, 0.4 + pulse * 0.2), CABLE_WIDTH, true)
		draw_circle(preview_to_pos, 5.0, Color(valid_color, 0.5 + pulse * 0.3))


func _get_preview_from_port() -> String:
	return preview_from_port if preview_from_port != "" else "right"



func _draw_transit_items(conn: Dictionary, _conn_index: int) -> void:
	## Render each transit item as a visible particle at its real position along the cable.
	## Transit items ARE the data — what you see is what's actually traveling.
	if not conn.has("transit") or conn["transit"].is_empty():
		return

	var points: PackedVector2Array = _get_cached_polyline(conn)
	if points.size() < 2:
		return

	var total_length: float = conn.get("_cached_total_length", 0.0)
	if total_length <= 0:
		return
	var seg_lengths: Array[float] = conn["_cached_seg_lengths"]

	var transit: Array = conn["transit"]
	var item_count: int = transit.size()
	# Throughput glow intensity: more items in flight = brighter cable
	var intensity: float = clampf(float(item_count) / 5.0, 0.5, 1.0)
	# Items within 1 grid cell of source are still "emerging" — don't render
	var cable_grids: float = total_length / float(TILE_SIZE)
	var min_render_t: float = 1.0 / maxf(cable_grids, 1.0)

	var font := _MONO_FONT
	# Scale font size inversely with zoom for crisp rendering at all zoom levels
	var z: float = _get_zoom_level()
	var inv_zoom: float = clampf(1.0 / z, 1.0, 3.0) if z < 1.0 else 1.0
	var fs: int = int(PARTICLE_FONT_SIZE * inv_zoom)
	var half_fs: float = fs * 0.5

	var batch_positions: PackedVector2Array
	var use_batch: bool = _polyline_helper != null and conn.has("_cached_cumulative_dists")
	if use_batch:
		batch_positions = _polyline_helper.batch_transit_positions(points, conn["_cached_cumulative_dists"], total_length, transit, min_render_t)

	for pi in range(item_count):
		var item: Dictionary = transit[pi]
		var pos: Vector2
		if use_batch:
			pos = batch_positions[pi]
			if is_nan(pos.x):
				continue
		else:
			if item.t < min_render_t:
				continue
			pos = _get_point_along_path(points, seg_lengths, total_length, item.t)

		# Derive visual from packed key
		var ikey: int = int(item.key)
		var i_state: int = DataEnums.unpack_state(ikey)
		var base_color: Color
		var ch: String
		ch = DataEnums.content_char(DataEnums.unpack_content(ikey))
		base_color = DataEnums.state_color(i_state)

		var glow_pulse: float = sin(Time.get_ticks_msec() / 120.0 + float(pi) * 1.7) * 0.5 + 0.5

		# Outer glow halo — scales with throughput intensity + zoom
		var outer_r: float = (10.0 + glow_pulse * 4.0) * (0.8 + intensity * 0.4) * inv_zoom
		draw_circle(pos, outer_r, Color(base_color, (0.08 + glow_pulse * 0.06) * intensity))
		# Inner glow
		draw_circle(pos, 6.0 * inv_zoom, Color(base_color, 0.25 + 0.15 * intensity))

		# Dark background pill behind character for contrast
		var bg_rect := Rect2(pos + Vector2(-half_fs * 0.45, -half_fs * 0.55), Vector2(half_fs * 0.9, half_fs * 1.1))
		draw_rect(bg_rect, Color(0, 0, 0, 0.65), true)

		# Character — bright colored on dark bg
		var draw_pos := pos + Vector2(-half_fs * 0.3, half_fs * 0.3)
		draw_string(font, draw_pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(base_color, 0.95))
		# White overlay for extra brightness
		draw_string(font, draw_pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.35))


func _get_point_along_path(points: PackedVector2Array, seg_lengths: Array[float], total: float, t: float) -> Vector2:
	var target_dist: float = t * total
	var accumulated: float = 0.0
	for i in range(seg_lengths.size()):
		if accumulated + seg_lengths[i] >= target_dist:
			var local_t: float = (target_dist - accumulated) / seg_lengths[i] if seg_lengths[i] > 0 else 0.0
			return points[i].lerp(points[i + 1], local_t)
		accumulated += seg_lengths[i]
	return points[points.size() - 1]


func play_connection_flash(building: Node2D) -> void:
	if building == null or building.definition == null:
		return
	var pos: Vector2 = to_local(building.get_center_world())
	_flash_positions.append(pos)
	_flash_times.append(FLASH_DURATION)
	_flash_colors.append(building.definition.color)


func play_removal_flash(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 2:
		return
	_removal_flash_paths.append(points)
	_removal_flash_times.append(REMOVAL_FLASH_DURATION)
	_removal_flash_colors.append(color)


# =============================================================================
# TRANSIT ITEM MULTIMESH — batch rendering (Faz 2)
# =============================================================================

func _init_transit_multimesh() -> void:
	## Set up MultiMesh for transit item rendering. Atlas built asynchronously.
	var shader: Shader = load("res://shaders/transit_item.gdshader")
	if shader == null:
		push_warning("[ConnectionLayer] transit_item.gdshader not found — using fallback draw")
		return

	# Quad mesh — each transit item rendered as a quad
	var quad := QuadMesh.new()
	quad.size = Vector2(64.0, 64.0)

	_transit_mm = MultiMesh.new()
	_transit_mm.transform_format = MultiMesh.TRANSFORM_2D
	_transit_mm.use_colors = true
	_transit_mm.use_custom_data = true
	_transit_mm.instance_count = 0
	_transit_mm.mesh = quad

	_transit_shader_mat = ShaderMaterial.new()
	_transit_shader_mat.shader = shader

	_transit_mm_node = MultiMeshInstance2D.new()
	_transit_mm_node.multimesh = _transit_mm
	_transit_mm_node.material = _transit_shader_mat
	add_child(_transit_mm_node)

	# Build glyph atlas asynchronously (takes 2 frames)
	_build_glyph_atlas_async()


func _build_glyph_atlas_async() -> void:
	## Render glyph atlas via SubViewport — white characters on transparent bg.
	var cell_size: int = 48
	var atlas_w: int = cell_size * GLYPH_CHARS.size()

	var vp := SubViewport.new()
	vp.size = Vector2i(atlas_w, cell_size)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var container := Control.new()
	container.size = Vector2(atlas_w, cell_size)
	vp.add_child(container)

	for i in range(GLYPH_CHARS.size()):
		var lbl := Label.new()
		lbl.text = GLYPH_CHARS[i]
		lbl.add_theme_font_override("font", _MONO_FONT)
		lbl.add_theme_font_size_override("font_size", 36)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(i * cell_size, 0)
		lbl.custom_minimum_size = Vector2(cell_size, cell_size)
		lbl.size = Vector2(cell_size, cell_size)
		container.add_child(lbl)

	add_child(vp)

	# Wait several frames for SubViewport to render properly
	for _f in range(4):
		await get_tree().process_frame

	if not is_instance_valid(vp):
		push_warning("[ConnectionLayer] SubViewport lost — glyph atlas failed")
		return

	var img: Image = vp.get_texture().get_image()

	# Validate atlas has content (not all transparent)
	var has_content: bool = false
	for y in range(mini(cell_size, img.get_height())):
		for x in range(mini(atlas_w, img.get_width())):
			if img.get_pixel(x, y).a > 0.01:
				has_content = true
				break
		if has_content:
			break

	if not has_content:
		push_warning("[ConnectionLayer] Glyph atlas is empty — falling back to CPU transit draw")
		vp.queue_free()
		return

	_glyph_atlas = ImageTexture.create_from_image(img)
	_transit_shader_mat.set_shader_parameter("glyph_atlas", _glyph_atlas)
	_transit_shader_mat.set_shader_parameter("atlas_cols", float(GLYPH_CHARS.size()))

	vp.queue_free()
	_atlas_ready = true
	print("[ConnectionLayer] Transit MultiMesh ready — %d glyph atlas (%dx%d)" % [GLYPH_CHARS.size(), atlas_w, cell_size])


func _update_transit_multimesh() -> void:
	## Update MultiMesh instance transforms/colors from live transit data.
	## Called every frame from _process() when atlas is ready.
	if _transit_mm == null or connection_manager == null:
		return

	var conns: Array[Dictionary] = connection_manager.get_connections()
	var vp_bounds: Rect2 = _get_viewport_bounds()
	var zoom: float = _get_zoom_level()

	# Hide transit items at extreme zoom-out (too small to see)
	if zoom < 0.15:
		if _transit_mm.visible_instance_count > 0:
			_transit_mm.visible_instance_count = 0
		return

	# Scale: grows at zoom-out (max 2x), shrinks slightly at zoom-in (min 0.8x)
	var inv_zoom: float = clampf(1.0 / zoom, 0.8, 2.0)
	var instance_idx: int = 0

	# Ensure enough capacity
	if _transit_mm.instance_count < MAX_TRANSIT_INSTANCES:
		_transit_mm.instance_count = MAX_TRANSIT_INSTANCES

	for conn in conns:
		if not conn.has("transit") or conn["transit"].is_empty():
			continue
		if not _is_conn_in_viewport(conn, vp_bounds):
			continue

		var points: PackedVector2Array = _get_cached_polyline(conn)
		if points.size() < 2:
			continue
		var total_length: float = conn.get("_cached_total_length", 0.0)
		if total_length <= 0.0:
			continue

		var transit: Array = conn["transit"]
		var item_count: int = transit.size()
		var intensity: float = clampf(float(item_count) / 5.0, 0.5, 1.0)
		var cable_grids: float = total_length / float(TILE_SIZE)
		var min_render_t: float = 1.0 / maxf(cable_grids, 1.0)

		# Batch positions from C++
		var batch_positions: PackedVector2Array = PackedVector2Array()
		var use_batch: bool = _polyline_helper != null and conn.has("_cached_cumulative_dists")
		if use_batch:
			batch_positions = _polyline_helper.batch_transit_positions(
				points, conn["_cached_cumulative_dists"], total_length, transit, min_render_t)

		var seg_lengths: Array[float] = conn["_cached_seg_lengths"]

		for pi in range(item_count):
			if instance_idx >= MAX_TRANSIT_INSTANCES:
				break

			var item: Dictionary = transit[pi]
			var pos: Vector2

			if use_batch and batch_positions.size() > pi:
				pos = batch_positions[pi]
				if is_nan(pos.x):
					continue
			else:
				if item.t < min_render_t:
					continue
				pos = _get_point_along_path(points, seg_lengths, total_length, item.t)

			# Glyph index + state color from packed key
			var mkey: int = int(item.key)
			var m_content: int = DataEnums.unpack_content(mkey)
			var glyph_idx: int = GLYPH_MAP.get(m_content, 0)
			var base_color: Color = DataEnums.state_color(DataEnums.unpack_state(mkey))

			# Transform: position + zoom-adaptive scale
			var xf := Transform2D(0.0, Vector2(inv_zoom, inv_zoom), 0.0, pos)
			_transit_mm.set_instance_transform_2d(instance_idx, xf)
			_transit_mm.set_instance_color(instance_idx, base_color)
			# Custom data encoded in 0-1 range (Color clamps to 0-1!)
			# x = glyph_index / 10.0 (0.0-0.9), y = reserved, z = fract(phase), w = intensity
			var encoded_glyph: float = float(glyph_idx) / 10.0
			var encoded_phase: float = fmod(float(pi) * 0.17, 1.0)
			_transit_mm.set_instance_custom_data(instance_idx,
				Color(encoded_glyph, 0.0, encoded_phase, intensity))

			instance_idx += 1

		if instance_idx >= MAX_TRANSIT_INSTANCES:
			break

	_transit_mm.visible_instance_count = instance_idx
