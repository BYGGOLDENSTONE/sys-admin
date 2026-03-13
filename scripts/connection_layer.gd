extends Node2D

const _MONO_FONT: Font = preload("res://assets/fonts/JetBrainsMono-Regular.ttf")
const TILE_SIZE: int = 64
const CABLE_WIDTH: float = 5.0
const CABLE_GLOW_WIDTH: float = 11.0
const CABLE_GLOW_ALPHA: float = 0.2
const CABLE_INACTIVE_ALPHA: float = 0.12
const PARTICLE_FONT_SIZE: int = 20
const HOVER_COLOR := Color(1.0, 0.3, 0.3, 0.6)
const HOVER_WIDTH: float = 14.0
const PREVIEW_VALID_COLOR := Color(0.2, 1, 0.67, 0.5)
const PREVIEW_INVALID_COLOR := Color(1, 0.13, 0.27, 0.5)

var connection_manager: Node = null
var simulation_manager: Node = null
var hovered_cable_index: int = -1
var _camera: Camera2D = null
# Per-frame cache: buildings that have transit items heading toward them
var _has_incoming: Dictionary = {}  # building → true

# Cable state constants
const CABLE_FLOWING: int = 0
const CABLE_STALLED: int = 1
const CABLE_INACTIVE: int = 2

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


func _ready() -> void:
	_camera = get_node_or_null("../GameCamera")


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
	queue_redraw()


func _draw() -> void:
	if connection_manager == null:
		return

	var zoom: float = _get_zoom_level()
	var conns: Array[Dictionary] = connection_manager.get_connections()
	# Build per-frame cache of buildings with incoming transit
	_has_incoming.clear()
	for c in conns:
		if c.has("transit") and not c["transit"].is_empty():
			_has_incoming[c.to_building] = true
	for i in range(conns.size()):
		var conn: Dictionary = conns[i]
		var cable_state: int = _get_cable_state(conn, i)
		var hovered: bool = (i == hovered_cable_index)
		_draw_connection(conn, cable_state != CABLE_INACTIVE, hovered)
		if zoom > 0.25:
			_draw_transit_items(conn, i)

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
	return conn["_cached_polyline"]


func _draw_connection(conn: Dictionary, active: bool, hovered: bool) -> void:
	var path: Array = conn.path
	if path.size() < 2:
		return
	var accent: Color = conn.from_building.definition.color
	var points: PackedVector2Array = _get_cached_polyline(conn)
	if points.size() < 2:
		return

	var zoom: float = _get_zoom_level()
	# Scale cable thickness at low zoom so cables stay visible
	var zoom_scale: float = clampf(1.0 / zoom, 1.0, 2.5) if zoom < 1.0 else 1.0
	var core_w: float = CABLE_WIDTH * zoom_scale
	var glow_w: float = CABLE_GLOW_WIDTH * zoom_scale

	if hovered:
		draw_polyline(points, HOVER_COLOR, HOVER_WIDTH * zoom_scale, true)

	if active:
		var pulse := sin(Time.get_ticks_msec() / 200.0) * 0.5 + 0.5
		# Outer soft halo — wider for "glowing wire" feel
		draw_polyline(points, Color(accent, (0.08 + pulse * 0.06) * zoom_scale), glow_w * 2.0, true)
		# Mid glow
		draw_polyline(points, Color(accent, minf((CABLE_GLOW_ALPHA + pulse * 0.12) * zoom_scale, 0.6)), glow_w, true)
		# Core line
		draw_polyline(points, accent, core_w, true)
		# Bright center highlight — boosted for screenshot contrast
		draw_polyline(points, Color(1.0, 1.0, 1.0, 0.2 + pulse * 0.1), maxf(1.0, core_w * 0.4), true)
	else:
		draw_polyline(points, Color(accent, minf(CABLE_INACTIVE_ALPHA * 0.4 * zoom_scale, 0.25)), glow_w * 0.4, true)
		draw_polyline(points, Color(accent, minf(CABLE_INACTIVE_ALPHA * 0.8 * zoom_scale, 0.35)), core_w, true)


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


func _get_cable_state(conn: Dictionary, conn_index: int) -> int:
	var from_b: Node2D = conn.from_building
	var to_b: Node2D = conn.to_building
	# Source must be active (buildings only — data sources are always active)
	if from_b.has_method("is_active") and not from_b.is_active():
		return CABLE_INACTIVE
	# Check simulation stalled tracking
	if simulation_manager and simulation_manager.connection_stalled.get(conn_index, false):
		return CABLE_STALLED
	# Transit data — if items are in flight, cable is flowing
	if conn.has("transit") and not conn["transit"].is_empty():
		return CABLE_FLOWING
	# Source working → flowing (building-only fallback)
	if "is_working" in from_b and from_b.is_working:
		return CABLE_FLOWING
	# Source has data incoming → output cables stay active (routing buildings)
	if _has_incoming.has(from_b):
		return CABLE_FLOWING
	# Target full → stalled (fallback check)
	if to_b.has_method("can_accept_data") and not to_b.can_accept_data(1):
		return CABLE_STALLED
	return CABLE_INACTIVE


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
	var half_fs: float = PARTICLE_FONT_SIZE * 0.5

	for pi in range(item_count):
		var item: Dictionary = transit[pi]
		if item.t < min_render_t:
			continue  # Still emerging from source — don't render yet
		var pos: Vector2 = _get_point_along_path(points, seg_lengths, total_length, item.t)

		# Derive visual from actual data type
		var base_color: Color
		var ch: String
		if item.content < 0:
			# Packet — purple-pink, "P" character
			ch = "P"
			base_color = Color(0.9, 0.3, 1.0)
		else:
			ch = DataEnums.content_char(item.content)
			base_color = DataEnums.state_color(item.state)

		var glow_pulse: float = sin(Time.get_ticks_msec() / 120.0 + float(pi) * 1.7) * 0.5 + 0.5

		# Outer glow halo — scales with throughput intensity
		var outer_r: float = (10.0 + glow_pulse * 4.0) * (0.8 + intensity * 0.4)
		draw_circle(pos, outer_r, Color(base_color, (0.08 + glow_pulse * 0.06) * intensity))
		# Inner glow
		draw_circle(pos, 6.0, Color(base_color, 0.25 + 0.15 * intensity))

		# Dark background pill behind character for contrast
		var bg_rect := Rect2(pos + Vector2(-half_fs * 0.45, -half_fs * 0.55), Vector2(half_fs * 0.9, half_fs * 1.1))
		draw_rect(bg_rect, Color(0, 0, 0, 0.65), true)

		# Character — bright colored on dark bg
		var draw_pos := pos + Vector2(-half_fs * 0.3, half_fs * 0.3)
		draw_string(font, draw_pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, PARTICLE_FONT_SIZE, Color(base_color, 0.95))
		# White overlay for extra brightness
		draw_string(font, draw_pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, PARTICLE_FONT_SIZE, Color(1, 1, 1, 0.35))


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
