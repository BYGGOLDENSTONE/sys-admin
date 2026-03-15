extends PanelContainer

## Level selection panel — shows 9 levels with lock/unlock/completed states.
## Used from main menu (Level Select) and after level completion.

signal level_selected(level: int)
signal back_pressed()

var max_level_reached: int = 1
var completed_levels: Dictionary = {}  ## level → true


func _ready() -> void:
	_setup_style()
	_build_ui()


func _setup_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.95)
	style.border_color = Color(0.0, 0.7, 0.8, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(520, 0)


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "// SELECT LEVEL"
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", Color(0.0, 0.85, 0.9, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Level grid (3x3)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)

	for i in range(1, LevelConfig.MAX_LEVEL + 1):
		var card := _create_level_card(i)
		grid.add_child(card)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.add_theme_font_size_override("font_size", 18)
	_style_button(back_btn, Color(0.5, 0.6, 0.7))
	back_btn.pressed.connect(func(): back_pressed.emit())
	vbox.add_child(back_btn)


func _create_level_card(level: int) -> PanelContainer:
	var data: Dictionary = LevelConfig.get_level(level)
	var is_unlocked: bool = level <= max_level_reached
	var is_completed: bool = completed_levels.has(level)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(150, 100)

	# Card background
	var card_style := StyleBoxFlat.new()
	if is_completed:
		card_style.bg_color = Color(0.02, 0.08, 0.04, 0.9)
		card_style.border_color = Color(0.0, 0.8, 0.4, 0.7)
	elif is_unlocked:
		card_style.bg_color = Color(0.04, 0.06, 0.1, 0.9)
		card_style.border_color = Color(0.0, 0.7, 0.8, 0.6)
	else:
		card_style.bg_color = Color(0.03, 0.04, 0.05, 0.6)
		card_style.border_color = Color(0.2, 0.25, 0.3, 0.3)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(4)
	card_style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Level number
	var num_label := Label.new()
	num_label.text = "LEVEL %d" % level
	num_label.add_theme_font_size_override("font_size", 16)
	var num_color: Color = Color(0.3, 0.35, 0.4, 0.5) if not is_unlocked else Color(0.8, 0.9, 0.95)
	num_label.add_theme_color_override("font_color", num_color)
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(num_label)

	# CT size
	var ct_label := Label.new()
	ct_label.text = "%dx%d CT" % [data.ct_size.x, data.ct_size.y]
	ct_label.add_theme_font_size_override("font_size", 22)
	var ct_color: Color = Color(0.3, 0.35, 0.4, 0.4) if not is_unlocked else Color(1.0, 0.75, 0.0, 0.9)
	ct_label.add_theme_color_override("font_color", ct_color)
	ct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(ct_label)

	# Map size
	var map_label := Label.new()
	if data.is_infinite:
		map_label.text = "ENDLESS"
	else:
		map_label.text = "%dx%d" % [data.map_size, data.map_size]
	map_label.add_theme_font_size_override("font_size", 12)
	var map_color: Color = Color(0.25, 0.3, 0.35, 0.4) if not is_unlocked else Color(0.5, 0.6, 0.7, 0.7)
	map_label.add_theme_color_override("font_color", map_color)
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(map_label)

	# Status
	if is_completed:
		var status := Label.new()
		status.text = "COMPLETE"
		status.add_theme_font_size_override("font_size", 11)
		status.add_theme_color_override("font_color", Color(0.0, 0.8, 0.4, 0.8))
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(status)
	elif not is_unlocked:
		var lock := Label.new()
		lock.text = "LOCKED"
		lock.add_theme_font_size_override("font_size", 11)
		lock.add_theme_color_override("font_color", Color(0.4, 0.3, 0.3, 0.5))
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lock)

	# Click handler
	if is_unlocked:
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): level_selected.emit(level))
		# Hover style
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(0.0, 0.7, 0.8, 0.1)
		hover_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		card.add_child(btn)

	return card


func _style_button(btn: Button, accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.9)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.07, 0.1, 0.15, 0.95)
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.9)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	btn.add_theme_color_override("font_hover_color", accent)
