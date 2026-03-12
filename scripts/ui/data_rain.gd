extends Control

## Falling data rain background effect for main menu.

const CHARS: String = "01ABCDEF23456789abcdef{}[]<>/|"
const COL_SPACING: float = 22.0
const CHAR_SIZE: int = 12
const FALL_SPEED_MIN: float = 25.0
const FALL_SPEED_MAX: float = 90.0
const FADE_CLR := Color(0.0, 0.6, 0.75, 0.08)
const HEAD_CLR := Color(0.0, 0.85, 0.95, 0.25)

var _columns: Array = []
var _rng := RandomNumberGenerator.new()
var _font: Font = preload("res://assets/fonts/JetBrainsMono-Regular.ttf")


func _ready() -> void:
	_rng.seed = Time.get_ticks_msec()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_columns()


func _init_columns() -> void:
	_columns.clear()
	var w: float = get_viewport_rect().size.x
	var count: int = int(w / COL_SPACING)
	for i in range(count):
		_columns.append(_make_column(i * COL_SPACING + _rng.randf_range(0, 4), true))


func _make_column(x: float, random_start: bool) -> Dictionary:
	var length: int = _rng.randi_range(6, 18)
	var h: float = get_viewport_rect().size.y
	var y: float
	if random_start:
		y = _rng.randf_range(-length * CHAR_SIZE, h)
	else:
		y = float(-length * CHAR_SIZE)
	var chars: Array = []
	for _j in range(length):
		chars.append(CHARS[_rng.randi() % CHARS.length()])
	return {"x": x, "y": y, "speed": _rng.randf_range(FALL_SPEED_MIN, FALL_SPEED_MAX),
			"length": length, "chars": chars}


func _process(delta: float) -> void:
	var h: float = get_viewport_rect().size.y
	for col in _columns:
		col.y += col.speed * delta
		if col.y - col.length * CHAR_SIZE > h:
			var nc := _make_column(col.x, false)
			col.y = nc.y
			col.speed = nc.speed
			col.length = nc.length
			col.chars = nc.chars
	queue_redraw()


func _draw() -> void:
	var h: float = get_viewport_rect().size.y
	for col in _columns:
		for i in range(col.chars.size()):
			var cy: float = col.y + i * CHAR_SIZE
			if cy < -CHAR_SIZE or cy > h:
				continue
			var color: Color
			if i == col.chars.size() - 1:
				color = HEAD_CLR
			else:
				var t: float = float(i) / maxf(col.chars.size() - 1, 1)
				color = FADE_CLR
				color.a *= (0.3 + 0.7 * t)
			draw_string(_font, Vector2(col.x, cy), col.chars[i],
						HORIZONTAL_ALIGNMENT_LEFT, -1, CHAR_SIZE, color)
