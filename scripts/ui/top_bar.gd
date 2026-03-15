extends PanelContainer

const BG_COLOR := Color("#0a0f16")
const BORDER_COLOR := Color("#00bbee")
const DIVIDER_COLOR := Color("#00bbee40")

var _speed_label: Label
var _city_label: Label
var _seed_label: Label
var _dev_label: Label
var _speed_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_style()
	_build_ui()


func _setup_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.border_width_bottom = 1
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0.13, 0.67, 0.87, 0.08)
	style.shadow_size = 4
	add_theme_stylebox_override("panel", style)


func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	# Speed
	_speed_label = _make_label("> 1x", Color(0, 1, 0.53), 18)
	_speed_label.custom_minimum_size.x = 130
	hbox.add_child(_speed_label)

	# City Control
	_city_label = _make_label("NETWORK: 0%", Color(0.4, 0.7, 0.9, 0.8), 14)
	_city_label.visible = false
	hbox.add_child(_city_label)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer)

	# Dev mode
	_dev_label = _make_label("[DEV]", Color(1, 0.3, 0.3), 14)
	_dev_label.visible = false
	hbox.add_child(_dev_label)

	# Seed
	_seed_label = _make_label("SEED: 0", Color(0.5, 0.5, 0.5, 0.7), 14)
	hbox.add_child(_seed_label)


func _make_label(text: String, color: Color, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _make_divider() -> ColorRect:
	var div := ColorRect.new()
	div.color = DIVIDER_COLOR
	div.custom_minimum_size = Vector2(1, 0)
	div.size_flags_vertical = Control.SIZE_EXPAND_FILL
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return div


# --- Public API ---

func update_speed(multiplier: int, paused: bool) -> void:
	if paused:
		_speed_label.text = "|| PAUSED"
		_speed_label.add_theme_color_override("font_color", Color(1, 0.13, 0.27))
	else:
		_speed_label.text = "%s %dx" % [">".repeat(multiplier), multiplier]
		var speed_color: Color
		match multiplier:
			1: speed_color = Color(0.2, 1, 0.67)     # Mint green
			2: speed_color = Color(1.0, 0.8, 0.2)    # Gold
			3: speed_color = Color(1.0, 0.5, 0.15)   # Amber
			_: speed_color = Color(1.0, 0.3, 0.15)   # Orange-red
		_speed_label.add_theme_color_override("font_color", speed_color)
	# Pulse animation on change
	_play_speed_pulse()


func _play_speed_pulse() -> void:
	if _speed_tween:
		_speed_tween.kill()
	_speed_label.scale = Vector2(1.15, 1.15)
	_speed_label.pivot_offset = _speed_label.size / 2.0
	_speed_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_speed_tween.tween_property(_speed_label, "scale", Vector2.ONE, 0.3)


func update_seed(seed_value: int) -> void:
	_seed_label.text = "SEED: %d" % seed_value


func set_dev_visible(show: bool) -> void:
	_dev_label.visible = show


func update_city_control(connected: int, total: int) -> void:
	if total <= 0:
		_city_label.visible = false
		return
	_city_label.visible = true
	var pct: int = int(float(connected) / float(total) * 100.0)
	_city_label.text = "NETWORK: %d/%d (%d%%)" % [connected, total, pct]
	# Color shifts from cool blue to bright green as coverage grows
	var t: float = clampf(float(pct) / 100.0, 0.0, 1.0)
	_city_label.add_theme_color_override("font_color", Color(0.3, 0.5 + t * 0.5, 0.7 + t * 0.3, 0.85))
