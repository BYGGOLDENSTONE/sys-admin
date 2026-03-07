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


func _ready() -> void:
	_camera = get_node_or_null("../GameCamera")


func _process(delta: float) -> void:
	_particle_time += delta * PARTICLE_SPEED
	if _particle_time > 1.0:
		_particle_time -= 1.0
	queue_redraw()


func _draw() -> void:
	if connection_manager == null:
		return

	var conns: Array[Dictionary] = connection_manager.get_connections()
	for i in range(conns.size()):
		var conn: Dictionary = conns[i]
		var active: bool = _is_connection_active(conn)
		var hovered: bool = (i == hovered_cable_index)
		_draw_connection(conn, active, hovered)
		if active:
			_draw_particles(conn, i)

	if preview_active and not preview_path.is_empty():
		_draw_preview()


func _draw_connection(conn: Dictionary, active: bool, hovered: bool) -> void:
	var path: Array = conn.path
	if path.is_empty():
		return
	var accent: Color = conn.from_building.definition.color
	var points: PackedVector2Array = _build_polyline(conn)
	if points.size() < 2:
		return

	if hovered:
		draw_polyline(points, HOVER_COLOR, HOVER_WIDTH, true)

	if active:
		draw_polyline(points, Color(accent, CABLE_GLOW_ALPHA), CABLE_GLOW_WIDTH, true)
		draw_polyline(points, accent, CABLE_WIDTH, true)
	else:
		draw_polyline(points, Color(accent, CABLE_INACTIVE_ALPHA), CABLE_WIDTH, true)


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
		draw_polyline(points, color, CABLE_WIDTH, true)
		if preview_valid:
			draw_polyline(points, Color(color, 0.15), CABLE_GLOW_WIDTH, true)


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
		var offset: float = float(i) / float(count)
		var t: float = fmod(_particle_time + offset, 1.0)
		var pos: Vector2 = _get_point_along_path(points, seg_lengths, total_length, t)
		var ptype: Dictionary = ptypes[i] if i < ptypes.size() else {"color": Color("#00ff88"), "char": "0"}
		var draw_pos := pos + Vector2(-half_size, half_size)
		draw_string(font, draw_pos, ptype.char, HORIZONTAL_ALIGNMENT_LEFT, -1, PARTICLE_FONT_SIZE, Color(ptype.color, 0.4))
		draw_string(font, draw_pos, ptype.char, HORIZONTAL_ALIGNMENT_LEFT, -1, PARTICLE_FONT_SIZE, ptype.color)


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


func _build_particle_types(flow: Array, count: int) -> Array:
	var result: Array = []
	if flow.is_empty():
		for i in range(count):
			result.append({"color": Color("#00ff88"), "char": "0" if randi() % 2 == 0 else "1"})
		return result
	var total: int = 0
	for entry in flow:
		total += entry.amount
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
