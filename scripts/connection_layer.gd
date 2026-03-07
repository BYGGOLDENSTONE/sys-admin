extends Node2D

const TILE_SIZE: int = 64
const HALF_TILE: float = 32.0
const CABLE_WIDTH: float = 3.0
const CABLE_GLOW_WIDTH: float = 8.0
const CABLE_GLOW_ALPHA: float = 0.2
const CABLE_INACTIVE_ALPHA: float = 0.3
const PARTICLE_SPEED: float = 0.4
const PARTICLES_PER_CABLE: int = 8
const PARTICLE_FONT_SIZE: int = 16
const HOVER_COLOR := Color(1.0, 0.3, 0.3, 0.6)
const HOVER_WIDTH: float = 10.0
const PREVIEW_VALID_COLOR := Color(0, 1, 0.5, 0.5)
const PREVIEW_INVALID_COLOR := Color(1, 0.2, 0.2, 0.5)

var connection_manager: Node = null
var simulation_manager: Node = null
var hovered_cable_index: int = -1
var _particle_time: float = 0.0
var _camera: Camera2D = null

# Preview state (set by BuildingManager during CONNECTING)
var preview_path: Array[Vector2i] = []
var preview_active: bool = false
var preview_valid: bool = true
var preview_from_pos: Vector2 = Vector2.ZERO
var preview_to_pos: Vector2 = Vector2.ZERO

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
	_particle_time += delta * PARTICLE_SPEED
	if _particle_time > 1.0:
		_particle_time -= 1.0
	# Update flash timers
	var i: int = _flash_times.size() - 1
	while i >= 0:
		_flash_times[i] -= delta
		if _flash_times[i] <= 0:
			_flash_times.remove_at(i)
			_flash_positions.remove_at(i)
			_flash_colors.remove_at(i)
		i -= 1
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
	for i in range(conns.size()):
		var conn: Dictionary = conns[i]
		var active: bool = _is_connection_active(conn)
		var hovered: bool = (i == hovered_cable_index)
		_draw_connection(conn, active, hovered)
		# Skip particles at very low zoom (performance + readability)
		if active and zoom > 0.25:
			_draw_particles(conn, i)

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


func _draw_connection(conn: Dictionary, active: bool, hovered: bool) -> void:
	var path: Array = conn.path
	if path.is_empty():
		return
	var accent: Color = conn.from_building.definition.color
	var points: PackedVector2Array = _build_polyline(conn)
	if points.size() < 2:
		return

	var zoom: float = _get_zoom_level()
	# Scale cable thickness at low zoom so cables stay visible
	var zoom_scale: float = clampf(1.0 / zoom, 1.0, 3.5) if zoom < 1.0 else 1.0
	var core_w: float = CABLE_WIDTH * zoom_scale
	var glow_w: float = CABLE_GLOW_WIDTH * zoom_scale

	if hovered:
		draw_polyline(points, HOVER_COLOR, HOVER_WIDTH * zoom_scale, true)

	if active:
		var pulse := sin(Time.get_ticks_msec() / 200.0) * 0.5 + 0.5
		# Outer soft halo
		draw_polyline(points, Color(accent, (0.06 + pulse * 0.04) * zoom_scale), glow_w * 2.5, true)
		# Mid glow
		draw_polyline(points, Color(accent, minf((CABLE_GLOW_ALPHA + pulse * 0.1) * zoom_scale, 0.6)), glow_w, true)
		# Core line
		draw_polyline(points, accent, core_w, true)
		# Bright center highlight
		draw_polyline(points, Color(1.0, 1.0, 1.0, 0.15 + pulse * 0.05), maxf(1.0, core_w * 0.4), true)
	else:
		draw_polyline(points, Color(accent, minf(CABLE_INACTIVE_ALPHA * 0.5 * zoom_scale, 0.5)), glow_w * 0.7, true)
		draw_polyline(points, Color(accent, minf(CABLE_INACTIVE_ALPHA * zoom_scale, 0.6)), core_w, true)


func _build_polyline(conn: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	var from_pos: Vector2 = to_local(conn.from_building.get_port_world_position(conn.from_port))
	points.append(from_pos)
	for cell in conn.path:
		points.append(_cell_center(cell))
	var to_pos: Vector2 = to_local(conn.to_building.get_port_world_position(conn.to_port))
	points.append(to_pos)
	return points


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + HALF_TILE, cell.y * TILE_SIZE + HALF_TILE)


func _draw_preview() -> void:
	var color: Color = PREVIEW_VALID_COLOR if preview_valid else PREVIEW_INVALID_COLOR
	var points := PackedVector2Array()
	points.append(preview_from_pos)
	for cell in preview_path:
		points.append(_cell_center(cell))
	points.append(preview_to_pos)
	if points.size() >= 2:
		var pulse := sin(Time.get_ticks_msec() / 150.0) * 0.5 + 0.5
		if preview_valid:
			# Outer glow
			draw_polyline(points, Color(color, 0.08 + pulse * 0.06), CABLE_GLOW_WIDTH * 2.0, true)
			# Mid glow
			draw_polyline(points, Color(color, 0.2 + pulse * 0.1), CABLE_GLOW_WIDTH, true)
		# Core line
		draw_polyline(points, Color(color, 0.7 + pulse * 0.3), CABLE_WIDTH + 1.0, true)
		# Endpoint dots
		draw_circle(points[0], 5.0, Color(color, 0.5 + pulse * 0.3))
		draw_circle(points[points.size() - 1], 5.0, Color(color, 0.5 + pulse * 0.3))


func _is_connection_active(conn: Dictionary) -> bool:
	var from_b: Node2D = conn.from_building
	var to_b: Node2D = conn.to_building
	if from_b.has_method("is_active") and not from_b.is_active():
		return false
	if "is_working" in from_b and not from_b.is_working:
		return false
	if to_b.has_method("is_active") and not to_b.is_active():
		return false
	if to_b.has_method("can_accept_data") and not to_b.can_accept_data(1):
		return false
	return true


func _draw_particles(conn: Dictionary, conn_index: int) -> void:
	var points: PackedVector2Array = _build_polyline(conn)
	if points.size() < 2:
		return

	var total_length: float = 0.0
	var seg_lengths: Array[float] = []
	for i in range(1, points.size()):
		var seg_len: float = points[i - 1].distance_to(points[i])
		seg_lengths.append(seg_len)
		total_length += seg_len

	if total_length <= 0:
		return

	var font := ThemeDB.fallback_font
	var count: int = _get_visible_particle_count()
	var half_size: float = PARTICLE_FONT_SIZE * 0.35

	var flow: Array = _get_connection_flow(conn_index)
	var ptypes: Array = _build_particle_types(flow, count)

	for i in range(count):
		var p_offset: float = float(i) / float(count)
		var t: float = fmod(_particle_time + p_offset, 1.0)
		var pos: Vector2 = _get_point_along_path(points, seg_lengths, total_length, t)
		var ptype: Dictionary = ptypes[i] if i < ptypes.size() else {"color": Color("#00ff88"), "char": "0"}
		var draw_pos := pos + Vector2(-half_size, half_size)
		var base_color: Color = ptype.color
		var glow_pulse: float = sin(Time.get_ticks_msec() / 120.0 + float(i) * 1.7) * 0.5 + 0.5

		# Glow halo
		draw_circle(pos, 6.0 + glow_pulse * 3.0, Color(base_color, 0.1 + glow_pulse * 0.08))
		# Inner glow
		draw_circle(pos, 3.0, Color(base_color, 0.35))
		# Character
		draw_string(font, draw_pos, ptype.char, HORIZONTAL_ALIGNMENT_LEFT, -1, PARTICLE_FONT_SIZE, Color(base_color, 0.5))
		draw_string(font, draw_pos, ptype.char, HORIZONTAL_ALIGNMENT_LEFT, -1, PARTICLE_FONT_SIZE, Color.WHITE)


func _get_point_along_path(points: PackedVector2Array, seg_lengths: Array[float], total: float, t: float) -> Vector2:
	var target_dist: float = t * total
	var accumulated: float = 0.0
	for i in range(seg_lengths.size()):
		if accumulated + seg_lengths[i] >= target_dist:
			var local_t: float = (target_dist - accumulated) / seg_lengths[i] if seg_lengths[i] > 0 else 0.0
			return points[i].lerp(points[i + 1], local_t)
		accumulated += seg_lengths[i]
	return points[points.size() - 1]


func _get_visible_particle_count() -> int:
	if _camera == null:
		return PARTICLES_PER_CABLE
	var zoom_level: float = _camera.zoom.x
	return maxi(2, int(PARTICLES_PER_CABLE * clampf(zoom_level, 0.3, 1.5)))


func _get_connection_flow(conn_index: int) -> Array:
	if simulation_manager == null:
		return []
	return simulation_manager.connection_flow_data.get(conn_index, [])


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


func _build_particle_types(flow: Array, count: int) -> Array:
	var result: Array = []
	if flow.is_empty():
		for i in range(count):
			result.append({"color": Color("#00ff88"), "char": "0" if randi() % 2 == 0 else "1"})
		return result
	var total: int = 0
	for entry in flow:
		total += entry.amount if "amount" in entry else 0
	if total <= 0:
		for i in range(count):
			result.append({"color": Color("#00ff88"), "char": "0" if randi() % 2 == 0 else "1"})
		return result
	var assigned: int = 0
	for ei in range(flow.size()):
		var entry: Dictionary = flow[ei]
		var share: int
		if ei == flow.size() - 1:
			share = count - assigned
		else:
			share = maxi(1, roundi(float(entry.amount) / float(total) * count))
			share = mini(share, count - assigned)
		var col: Color = DataEnums.state_color(entry.state)
		for _j in range(share):
			result.append({"color": col, "char": DataEnums.content_char(entry.content)})
		assigned += share
	return result
