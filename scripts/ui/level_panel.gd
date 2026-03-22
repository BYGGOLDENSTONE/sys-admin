extends PanelContainer

## Level selection panel — shows all 9 levels with detailed info cards.
## Demo: levels beyond DEMO_MAX_LEVEL show "FULL GAME" badge and are locked.

signal level_selected(level: int)
signal back_pressed()

var max_level_reached: int = 1
var completed_levels: Dictionary = {}  ## level → true

## Source pool display names
const POOL_LABELS: Dictionary = {
	"easy": "Easy",
	"medium": "Medium",
	"hard": "Hard",
	"endgame": "Endgame",
}


func _ready() -> void:
	_setup_style()
	_build_ui()


func refresh() -> void:
	## Rebuild UI when max_level_reached or completed_levels change.
	for child in get_children():
		child.queue_free()
	_build_ui()


func _setup_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.95)
	style.border_color = Color(0.0, 0.7, 0.8, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(620, 0)


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
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
	var is_demo_locked: bool = LevelConfig.IS_DEMO and level > LevelConfig.DEMO_MAX_LEVEL
	var is_unlocked: bool = level <= max_level_reached and not is_demo_locked
	var is_completed: bool = completed_levels.has(level)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(185, 140)

	# Card background
	var card_style := StyleBoxFlat.new()
	if is_completed:
		card_style.bg_color = Color(0.02, 0.08, 0.04, 0.9)
		card_style.border_color = Color(0.0, 0.8, 0.4, 0.7)
	elif is_unlocked:
		card_style.bg_color = Color(0.04, 0.06, 0.1, 0.9)
		card_style.border_color = Color(0.0, 0.7, 0.8, 0.6)
	elif is_demo_locked:
		card_style.bg_color = Color(0.04, 0.03, 0.06, 0.5)
		card_style.border_color = Color(0.3, 0.2, 0.4, 0.3)
	else:
		card_style.bg_color = Color(0.03, 0.04, 0.05, 0.6)
		card_style.border_color = Color(0.2, 0.25, 0.3, 0.3)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(4)
	card_style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Level number + description
	var num_label := Label.new()
	num_label.text = "LEVEL %d" % level
	num_label.add_theme_font_size_override("font_size", 15)
	var dim: bool = not is_unlocked
	num_label.add_theme_color_override("font_color",
		Color(0.3, 0.35, 0.4, 0.5) if dim else Color(0.8, 0.9, 0.95))
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(num_label)

	# CT size (prominent)
	var ct_label := Label.new()
	ct_label.text = "%dx%d CT" % [data.ct_size.x, data.ct_size.y]
	ct_label.add_theme_font_size_override("font_size", 22)
	ct_label.add_theme_color_override("font_color",
		Color(0.3, 0.35, 0.4, 0.4) if dim else Color(1.0, 0.75, 0.0, 0.9))
	ct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(ct_label)

	# Info line: map + ports
	var ports: int = 4 * (data.ct_size.x - 1)
	var info_text: String
	if data.is_infinite:
		info_text = "ENDLESS  ·  %d ports" % ports
	else:
		info_text = "%dx%d map  ·  %d ports" % [data.map_size, data.map_size, ports]
	var info_label := Label.new()
	info_label.text = info_text
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color",
		Color(0.3, 0.35, 0.4, 0.4) if dim else Color(0.5, 0.6, 0.7, 0.8))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)

	# Source pools
	var pool_names: PackedStringArray = []
	for p in data.source_pools:
		if POOL_LABELS.has(p):
			pool_names.append(POOL_LABELS[p])
	var pool_label := Label.new()
	pool_label.text = " + ".join(pool_names)
	pool_label.add_theme_font_size_override("font_size", 10)
	pool_label.add_theme_color_override("font_color",
		Color(0.3, 0.35, 0.4, 0.35) if dim else Color(0.45, 0.55, 0.65, 0.7))
	pool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pool_label)

	# Description
	var desc_idx: int = clampi(level - 1, 0, LevelConfig.LEVEL_DESCS.size() - 1)
	var desc_label := Label.new()
	desc_label.text = LevelConfig.LEVEL_DESCS[desc_idx]
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color",
		Color(0.3, 0.3, 0.35, 0.4) if dim else Color(0.4, 0.5, 0.6, 0.7))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_label)

	# Status badge
	if is_completed:
		var status := Label.new()
		status.text = "COMPLETE"
		status.add_theme_font_size_override("font_size", 11)
		status.add_theme_color_override("font_color", Color(0.0, 0.8, 0.4, 0.9))
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(status)
	elif is_demo_locked:
		var lock := Label.new()
		lock.text = "FULL GAME"
		lock.add_theme_font_size_override("font_size", 11)
		lock.add_theme_color_override("font_color", Color(0.55, 0.35, 0.65, 0.7))
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lock)
	elif not is_unlocked:
		var lock := Label.new()
		lock.text = "LOCKED"
		lock.add_theme_font_size_override("font_size", 11)
		lock.add_theme_color_override("font_color", Color(0.45, 0.38, 0.38, 0.6))
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lock)

	# Click handler (only unlocked levels)
	if is_unlocked:
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): level_selected.emit(level))
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
