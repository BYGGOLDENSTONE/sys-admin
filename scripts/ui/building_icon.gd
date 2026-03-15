extends Control
## Draws a building's procedural icon for use in UI panels.
## Same shapes as building.gd but adapted for small panel cells.

const GLOW_WIDTH: float = 3.0
const GLOW_ALPHA: float = 0.25

var visual_type: String = "default"
var accent: Color = Color.CYAN


func _draw() -> void:
	var center := size / 2.0
	match visual_type:
		"classifier":
			_draw_classifier(center)
		"separator":
			_draw_separator(center)
		"decryptor":
			_draw_decryptor(center)
		"encryptor":
			_draw_encryptor(center)
		"recoverer":
			_draw_recoverer(center)
		"trash":
			_draw_trash(center)
		"research":
			_draw_research(center)
		"splitter":
			_draw_splitter(center)
		"merger":
			_draw_merger(center)
		"terminal":
			_draw_terminal(center)
		_:
			_draw_default(center)


func setup(p_visual_type: String, p_accent: Color) -> void:
	visual_type = p_visual_type
	accent = p_accent
	queue_redraw()


# --- CLASSIFIER: Diamond filter ---
func _draw_classifier(center: Vector2) -> void:
	var s: float = minf(size.x, size.y) * 0.35
	var glow := Color(accent, GLOW_ALPHA)

	var in_start := center + Vector2(-s * 0.8, 0)
	var in_end := center + Vector2(-s * 0.2, 0)
	draw_line(in_start, in_end, glow, GLOW_WIDTH)
	draw_line(in_start, in_end, accent, 2.0)

	var d: float = s * 0.3
	var diamond := PackedVector2Array([
		center + Vector2(0, -d),
		center + Vector2(d, 0),
		center + Vector2(0, d),
		center + Vector2(-d, 0),
		center + Vector2(0, -d),
	])
	draw_polyline(diamond, glow, GLOW_WIDTH)
	draw_polyline(diamond, accent, 2.0)

	var out_right := center + Vector2(s * 0.8, 0)
	draw_line(center + Vector2(d, 0), out_right, glow, GLOW_WIDTH)
	draw_line(center + Vector2(d, 0), out_right, accent, 2.0)
	draw_circle(out_right, 3.0, accent)

	var out_bottom := center + Vector2(0, s * 0.8)
	draw_line(center + Vector2(0, d), out_bottom, Color(accent, 0.4), GLOW_WIDTH)
	draw_line(center + Vector2(0, d), out_bottom, Color(accent, 0.6), 1.5)
	draw_circle(out_bottom, 2.0, Color(accent, 0.6))


# --- SEPARATOR: Circle filter ---
func _draw_separator(center: Vector2) -> void:
	var s: float = minf(size.x, size.y) * 0.35
	var glow := Color(accent, GLOW_ALPHA)

	var in_start := center + Vector2(-s * 0.8, 0)
	var in_end := center + Vector2(-s * 0.2, 0)
	draw_line(in_start, in_end, glow, GLOW_WIDTH)
	draw_line(in_start, in_end, accent, 2.0)

	draw_circle(center, 4.0, accent)

	var out_right := center + Vector2(s * 0.8, 0)
	draw_line(center, out_right, glow, GLOW_WIDTH)
	draw_line(center, out_right, accent, 2.0)
	draw_circle(out_right, 3.0, accent)

	var out_bottom := center + Vector2(0, s * 0.8)
	draw_line(center, out_bottom, Color(accent, 0.4), GLOW_WIDTH)
	draw_line(center, out_bottom, Color(accent, 0.6), 1.5)
	draw_circle(out_bottom, 2.0, Color(accent, 0.6))


# --- DECRYPTOR: Open lock ---
func _draw_decryptor(center: Vector2) -> void:
	var s: float = minf(size.x, size.y) * 0.35
	var glow := Color(accent, GLOW_ALPHA)

	var lock_w: float = s * 0.8
	var lock_h: float = s * 0.6
	var lock_rect := Rect2(center + Vector2(-lock_w / 2, -lock_h * 0.1), Vector2(lock_w, lock_h))
	draw_rect(lock_rect, Color(accent, 0.15), true)
	draw_rect(lock_rect, accent, false, 1.5)

	_draw_arc(center + Vector2(0, -lock_h * 0.1), s * 0.3, PI, TAU, glow, GLOW_WIDTH)
	_draw_arc(center + Vector2(0, -lock_h * 0.1), s * 0.3, PI, TAU, accent, 2.0)

	draw_circle(center + Vector2(0, lock_h * 0.2), 3.0, accent)
	var kh_bottom := center + Vector2(0, lock_h * 0.2 + 3)
	draw_line(kh_bottom, kh_bottom + Vector2(0, 5), accent, 2.0)


# --- ENCRYPTOR: Closed lock ---
func _draw_encryptor(center: Vector2) -> void:
	var s: float = minf(size.x, size.y) * 0.35
	var glow := Color(accent, GLOW_ALPHA)

	var lock_w: float = s * 0.8
	var lock_h: float = s * 0.6
	var lock_rect := Rect2(center + Vector2(-lock_w / 2, -lock_h * 0.1), Vector2(lock_w, lock_h))
	draw_rect(lock_rect, Color(accent, 0.25), true)
	draw_rect(lock_rect, accent, false, 2.0)

	_draw_arc(center + Vector2(0, -lock_h * 0.1), s * 0.3, PI, TAU, glow, GLOW_WIDTH)
	_draw_arc(center + Vector2(0, -lock_h * 0.1), s * 0.3, PI, TAU, accent, 2.5)

	draw_circle(center + Vector2(0, lock_h * 0.2), 4.0, accent)
	draw_circle(center + Vector2(0, lock_h * 0.2), 2.0, Color.WHITE)


# --- RECOVERER: Circular arrow + plus ---
func _draw_recoverer(center: Vector2) -> void:
	var s: float = minf(size.x, size.y) * 0.35
	var glow := Color(accent, GLOW_ALPHA)

	_draw_arc(center, s * 0.5, PI * 0.2, PI * 1.8, glow, GLOW_WIDTH)
	_draw_arc(center, s * 0.5, PI * 0.2, PI * 1.8, accent, 2.0)

	var arrow_pos := center + Vector2(cos(PI * 0.2), sin(PI * 0.2)) * s * 0.5
	var arrow_dir := Vector2(cos(PI * 0.2 + PI / 2), sin(PI * 0.2 + PI / 2))
	draw_line(arrow_pos, arrow_pos + arrow_dir.rotated(0.5) * 6, accent, 2.0)
	draw_line(arrow_pos, arrow_pos + arrow_dir.rotated(-0.5) * 6, accent, 2.0)

	draw_line(center + Vector2(-4, 0), center + Vector2(4, 0), accent, 2.0)
	draw_line(center + Vector2(0, -4), center + Vector2(0, 4), accent, 2.0)


# --- TRASH: X mark ---
func _draw_trash(center: Vector2) -> void:
	var s: float = minf(size.x, size.y) * 0.35
	var glow := Color(accent, GLOW_ALPHA)
	var x_size: float = s * 0.45
	draw_line(center + Vector2(-x_size, -x_size), center + Vector2(x_size, x_size), glow, GLOW_WIDTH + 1)
	draw_line(center + Vector2(x_size, -x_size), center + Vector2(-x_size, x_size), glow, GLOW_WIDTH + 1)
	draw_line(center + Vector2(-x_size, -x_size), center + Vector2(x_size, x_size), accent, 2.5)
	draw_line(center + Vector2(x_size, -x_size), center + Vector2(-x_size, x_size), accent, 2.5)


# --- RESEARCH: Atom orbits ---
func _draw_research(center: Vector2) -> void:
	var s: float = minf(size.x, size.y) * 0.35
	var glow := Color(accent, GLOW_ALPHA)

	for i in range(3):
		var angle: float = i * PI / 3.0
		var points := PackedVector2Array()
		for j in range(25):
			var t: float = float(j) / 24.0 * TAU
			var px: float = cos(t) * s * 0.6
			var py: float = sin(t) * s * 0.25
			var rotated_x: float = px * cos(angle) - py * sin(angle)
			var rotated_y: float = px * sin(angle) + py * cos(angle)
			points.append(center + Vector2(rotated_x, rotated_y))
		if points.size() >= 2:
			draw_polyline(points, Color(accent, 0.4), 1.0, true)

	draw_circle(center, 4.0, glow)
	draw_circle(center, 3.0, accent)


# --- SPLITTER: One-to-two diverging ---
func _draw_splitter(center: Vector2) -> void:
	var s: float = minf(size.x, size.y) * 0.4
	var glow := Color(accent, GLOW_ALPHA)

	var in_pos := center + Vector2(-s * 0.6, 0)
	draw_line(in_pos, center, glow, GLOW_WIDTH)
	draw_line(in_pos, center, accent, 2.0)

	var out_top := center + Vector2(s * 0.6, -s * 0.4)
	var out_bot := center + Vector2(s * 0.6, s * 0.4)
	draw_line(center, out_top, glow, GLOW_WIDTH)
	draw_line(center, out_bot, glow, GLOW_WIDTH)
	draw_line(center, out_top, accent, 1.5)
	draw_line(center, out_bot, accent, 1.5)

	draw_line(out_top, out_top + Vector2(-5, 2), accent, 1.5)
	draw_line(out_top, out_top + Vector2(-3, 5), accent, 1.5)
	draw_line(out_bot, out_bot + Vector2(-5, -2), accent, 1.5)
	draw_line(out_bot, out_bot + Vector2(-3, -5), accent, 1.5)

	draw_circle(center, 3.0, accent)


# --- MERGER: Two-to-one converging ---
func _draw_merger(center: Vector2) -> void:
	var s: float = minf(size.x, size.y) * 0.4
	var glow := Color(accent, GLOW_ALPHA)

	var in_top := center + Vector2(-s * 0.6, -s * 0.4)
	var in_bot := center + Vector2(-s * 0.6, s * 0.4)
	draw_line(in_top, center, glow, GLOW_WIDTH)
	draw_line(in_bot, center, glow, GLOW_WIDTH)
	draw_line(in_top, center, accent, 1.5)
	draw_line(in_bot, center, accent, 1.5)

	var out_pos := center + Vector2(s * 0.6, 0)
	draw_line(center, out_pos, glow, GLOW_WIDTH)
	draw_line(center, out_pos, accent, 2.0)

	draw_line(out_pos, out_pos + Vector2(-5, -3), accent, 1.5)
	draw_line(out_pos, out_pos + Vector2(-5, 3), accent, 1.5)

	draw_circle(center, 3.0, accent)


# --- TERMINAL: Monitor + stand + arrow ---
func _draw_terminal(center: Vector2) -> void:
	var s: float = minf(size.x, size.y) * 0.35
	var glow := Color(accent, GLOW_ALPHA)

	var mon_w: float = s * 1.2
	var mon_h: float = s * 0.8
	var mon_rect := Rect2(center + Vector2(-mon_w / 2, -mon_h / 2 - s * 0.1), Vector2(mon_w, mon_h))
	draw_rect(mon_rect, Color(accent, 0.15), true)
	draw_rect(mon_rect, glow, false, GLOW_WIDTH)
	draw_rect(mon_rect, accent, false, 2.0)

	var stand_top := Vector2(center.x, mon_rect.end.y)
	var stand_bot := Vector2(center.x, mon_rect.end.y + s * 0.3)
	draw_line(stand_top, stand_bot, accent, 2.0)
	draw_line(stand_bot + Vector2(-s * 0.3, 0), stand_bot + Vector2(s * 0.3, 0), accent, 2.0)

	var arrow_tip := Vector2(center.x, center.y - s * 0.1)
	draw_line(arrow_tip + Vector2(0, -s * 0.35), arrow_tip, glow, GLOW_WIDTH)
	draw_line(arrow_tip + Vector2(0, -s * 0.35), arrow_tip, accent, 2.0)
	draw_line(arrow_tip, arrow_tip + Vector2(-4, -6), accent, 2.0)
	draw_line(arrow_tip, arrow_tip + Vector2(4, -6), accent, 2.0)


# --- DEFAULT: Simple dot ---
func _draw_default(center: Vector2) -> void:
	draw_circle(center, 4.0, Color(accent, 0.5))


# --- Utility: Arc drawing ---
func _draw_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	var point_count: int = maxi(8, int((end_angle - start_angle) / PI * 16))
	var points := PackedVector2Array()
	for i in range(point_count + 1):
		var t: float = float(i) / float(point_count)
		var angle: float = start_angle + t * (end_angle - start_angle)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if points.size() >= 2:
		draw_polyline(points, color, width, true)
