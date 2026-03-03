extends Node2D

const CABLE_WIDTH: float = 2.0
const CABLE_GLOW_WIDTH: float = 6.0
const CABLE_GLOW_ALPHA: float = 0.25
const CABLE_INACTIVE_ALPHA: float = 0.3
const PARTICLE_COLOR := Color("#00ff88")
const PARTICLE_SPEED: float = 0.4
const PARTICLES_PER_CABLE: int = 8
const PARTICLE_FONT_SIZE: int = 16
const BEZIER_STEPS: int = 30
const PREVIEW_COLOR := Color(1, 1, 1, 0.4)

var connection_manager: Node = null
var _camera: Camera2D = null
var _particle_time: float = 0.0
var _particle_chars: Array[String] = []

# Preview state (set by BuildingManager during CONNECTING)
var preview_from: Vector2 = Vector2.ZERO
var preview_to: Vector2 = Vector2.ZERO
var preview_active: bool = false
var preview_color: Color = PREVIEW_COLOR


func _ready() -> void:
	# Pre-generate random 0/1 chars for particles
	for i in range(100):
		_particle_chars.append("0" if randf() > 0.5 else "1")
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
	for conn in conns:
		var active: bool = _is_connection_active(conn)
		_draw_cable(conn, active)
		if active:
			_draw_particles(conn)

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


func _draw_particles(conn: Dictionary) -> void:
	var from_building: Node2D = conn.from_building
	var from_pos: Vector2 = to_local(from_building.get_port_world_position(conn.from_port))
	var to_pos: Vector2 = to_local(conn.to_building.get_port_world_position(conn.to_port))

	var dx: float = absf(to_pos.x - from_pos.x) * 0.4
	var cp1 := from_pos + Vector2(dx, 0)
	var cp2 := to_pos - Vector2(dx, 0)

	var font := ThemeDB.fallback_font
	var count: int = _get_visible_particle_count()
	var half_size: float = PARTICLE_FONT_SIZE * 0.35

	for i in range(count):
		var offset: float = float(i) / float(count)
		var t: float = fmod(_particle_time + offset, 1.0)
		var pos := _cubic_bezier(from_pos, cp1, cp2, to_pos, t)
		var char_idx: int = (i + int(_particle_time * 10)) % _particle_chars.size()
		var ch: String = _particle_chars[char_idx]
		var draw_pos := pos + Vector2(-half_size, half_size)

		# Glow
		draw_string(font, draw_pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, PARTICLE_FONT_SIZE, Color(PARTICLE_COLOR, 0.4))
		# Main character
		draw_string(font, draw_pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, PARTICLE_FONT_SIZE, PARTICLE_COLOR)


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
