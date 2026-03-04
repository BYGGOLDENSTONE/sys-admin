extends Node2D

const CABLE_WIDTH: float = 2.0
const CABLE_GLOW_WIDTH: float = 6.0
const CABLE_GLOW_ALPHA: float = 0.25
const CABLE_INACTIVE_ALPHA: float = 0.3
const PARTICLE_SPEED: float = 0.4
const PARTICLES_PER_CABLE: int = 8
const PARTICLE_FONT_SIZE: int = 16
const BEZIER_STEPS: int = 30
const PREVIEW_COLOR := Color(1, 1, 1, 0.4)
const HOVER_GLOW_WIDTH: float = 10.0
const HOVER_COLOR := Color(1.0, 0.3, 0.3, 0.6)
const DEFAULT_PARTICLE_COLOR := Color("#00ff88")

var connection_manager: Node = null
var simulation_manager: Node = null
var hovered_cable_index: int = -1
var _camera: Camera2D = null
var _particle_time: float = 0.0

# Preview state (set by BuildingManager during CONNECTING)
var preview_from: Vector2 = Vector2.ZERO
var preview_to: Vector2 = Vector2.ZERO
var preview_active: bool = false
var preview_color: Color = PREVIEW_COLOR


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
		if hovered:
			_draw_cable_hover(conn)
		_draw_cable(conn, active)
		if active:
			_draw_particles(conn, i)

	if preview_active:
		_draw_bezier_line(preview_from, preview_to, preview_color, CABLE_WIDTH, false)


func _is_connection_active(conn: Dictionary) -> bool:
	var from_b: Node2D = conn.from_building
	var to_b: Node2D = conn.to_building
	# Source must be active
	if from_b.has_method("is_active") and not from_b.is_active():
		return false
	# Source must be actually working (producing/forwarding data this tick)
	if "is_working" in from_b and not from_b.is_working:
		return false
	# Target must be active
	if to_b.has_method("is_active") and not to_b.is_active():
		return false
	# Target must be able to accept data (storage full = no flow)
	if to_b.has_method("can_accept_data") and not to_b.can_accept_data():
		return false
	return true


func _draw_cable_hover(conn: Dictionary) -> void:
	var from_pos: Vector2 = to_local(conn.from_building.get_port_world_position(conn.from_port))
	var to_pos: Vector2 = to_local(conn.to_building.get_port_world_position(conn.to_port))
	_draw_bezier_line(from_pos, to_pos, HOVER_COLOR, HOVER_GLOW_WIDTH, true)


func _draw_cable(conn: Dictionary, active: bool) -> void:
	var from_building: Node2D = conn.from_building
	var from_pos: Vector2 = from_building.get_port_world_position(conn.from_port)
	var to_pos: Vector2 = conn.to_building.get_port_world_position(conn.to_port)
	var accent: Color = from_building.definition.color

	# Convert from world to local (this node is at 0,0)
	from_pos = to_local(from_pos)
	to_pos = to_local(to_pos)

	if active:
		# Glow layer
		_draw_bezier_line(from_pos, to_pos, Color(accent, CABLE_GLOW_ALPHA), CABLE_GLOW_WIDTH, true)
		# Main cable
		_draw_bezier_line(from_pos, to_pos, accent, CABLE_WIDTH, true)
	else:
		# Dim cable only, no glow
		_draw_bezier_line(from_pos, to_pos, Color(accent, CABLE_INACTIVE_ALPHA), CABLE_WIDTH, true)


func _get_visible_particle_count() -> int:
	if _camera == null:
		return PARTICLES_PER_CABLE
	var zoom_level: float = _camera.zoom.x
	# Zoom in (>1): full particles. Zoom out (<1): fewer particles.
	var count: int = maxi(2, int(PARTICLES_PER_CABLE * clampf(zoom_level, 0.3, 1.5)))
	return count


func _get_connection_flow(conn_index: int) -> Array:
	if simulation_manager == null:
		return []
	return simulation_manager.connection_flow_data.get(conn_index, [])


func _build_particle_types(flow: Array, count: int) -> Array:
	# Returns array of {color: Color, char: String} for each particle
	var result: Array = []
	if flow.is_empty():
		# No flow data — use default green 0/1
		for i in range(count):
			result.append({"color": DEFAULT_PARTICLE_COLOR, "char": "0" if randi() % 2 == 0 else "1"})
		return result
	# Calculate total amount for proportional distribution
	var total: int = 0
	for entry in flow:
		total += entry.amount
	if total <= 0:
		for i in range(count):
			result.append({"color": DEFAULT_PARTICLE_COLOR, "char": "0" if randi() % 2 == 0 else "1"})
		return result
	# Assign particles proportionally
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


func _draw_particles(conn: Dictionary, conn_index: int) -> void:
	var from_building: Node2D = conn.from_building
	var from_pos: Vector2 = to_local(from_building.get_port_world_position(conn.from_port))
	var to_pos: Vector2 = to_local(conn.to_building.get_port_world_position(conn.to_port))

	var dx: float = absf(to_pos.x - from_pos.x) * 0.4
	var cp1 := from_pos + Vector2(dx, 0)
	var cp2 := to_pos - Vector2(dx, 0)

	var font := ThemeDB.fallback_font
	var count: int = _get_visible_particle_count()
	var half_size: float = PARTICLE_FONT_SIZE * 0.35

	var flow: Array = _get_connection_flow(conn_index)
	var ptypes: Array = _build_particle_types(flow, count)

	for i in range(count):
		var offset: float = float(i) / float(count)
		var t: float = fmod(_particle_time + offset, 1.0)
		var pos := _cubic_bezier(from_pos, cp1, cp2, to_pos, t)
		var ptype: Dictionary = ptypes[i] if i < ptypes.size() else {"color": DEFAULT_PARTICLE_COLOR, "char": "0"}
		var ch: String = ptype.char
		var col: Color = ptype.color
		var draw_pos := pos + Vector2(-half_size, half_size)

		# Glow
		draw_string(font, draw_pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, PARTICLE_FONT_SIZE, Color(col, 0.4))
		# Main character
		draw_string(font, draw_pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, PARTICLE_FONT_SIZE, col)


func _draw_bezier_line(from_pos: Vector2, to_pos: Vector2, color: Color, width: float, use_antialias: bool) -> void:
	var dx: float = absf(to_pos.x - from_pos.x) * 0.4
	var cp1 := from_pos + Vector2(dx, 0)
	var cp2 := to_pos - Vector2(dx, 0)

	var points := PackedVector2Array()
	for i in range(BEZIER_STEPS + 1):
		var t: float = float(i) / float(BEZIER_STEPS)
		points.append(_cubic_bezier(from_pos, cp1, cp2, to_pos, t))

	if points.size() >= 2:
		draw_polyline(points, color, width, use_antialias)


func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
