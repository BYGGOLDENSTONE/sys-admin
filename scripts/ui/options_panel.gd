extends VBoxContainer

## Reusable options panel — audio volume sliders + fullscreen toggle.
## Used in both Main Menu and in-game Pause Menu.

signal settings_changed()
signal back_pressed()

var _master_slider: HSlider = null
var _sfx_slider: HSlider = null
var _ambient_slider: HSlider = null
var _fullscreen_check: CheckButton = null
var _crt_check: CheckButton = null
var _autosave_option: OptionButton = null
var _master_lbl: Label = null
var _sfx_lbl: Label = null
var _ambient_lbl: Label = null

## Autosave interval options: [label, seconds] — 0 = disabled
const AUTOSAVE_OPTIONS: Array = [
	["2 min", 120],
	["5 min", 300],
	["10 min", 600],
	["Off", 0],
]


func _ready() -> void:
	_build()


func _build() -> void:
	add_theme_constant_override("separation", 14)
	custom_minimum_size = Vector2(340, 0)

	# Header
	var header := Label.new()
	header.text = "OPTIONS"
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", Color(0.0, 0.85, 0.9))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)

	var sep := HSeparator.new()
	sep.modulate = Color(0.0, 0.7, 0.8, 0.4)
	add_child(sep)

	# Audio section
	var audio_label := Label.new()
	audio_label.text = "AUDIO"
	audio_label.add_theme_font_size_override("font_size", 14)
	audio_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.8))
	add_child(audio_label)

	var settings := SettingsManager.get_settings()

	var master_row := _create_slider_row("Master", int(settings.get("master_volume", 80)))
	_master_slider = master_row.slider
	_master_lbl = master_row.value_label
	_master_slider.value_changed.connect(_on_master_changed)
	add_child(master_row.container)

	var sfx_row := _create_slider_row("SFX", int(settings.get("sfx_volume", 80)))
	_sfx_slider = sfx_row.slider
	_sfx_lbl = sfx_row.value_label
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	add_child(sfx_row.container)

	var ambient_row := _create_slider_row("Ambient", int(settings.get("ambient_volume", 50)))
	_ambient_slider = ambient_row.slider
	_ambient_lbl = ambient_row.value_label
	_ambient_slider.value_changed.connect(_on_ambient_changed)
	add_child(ambient_row.container)

	# Display section
	var sep2 := HSeparator.new()
	sep2.modulate = Color(0.0, 0.7, 0.8, 0.4)
	add_child(sep2)

	var display_label := Label.new()
	display_label.text = "DISPLAY"
	display_label.add_theme_font_size_override("font_size", 14)
	display_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.8))
	add_child(display_label)

	_fullscreen_check = CheckButton.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.add_theme_font_size_override("font_size", 16)
	_fullscreen_check.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	_fullscreen_check.button_pressed = settings.get("fullscreen", false)
	_fullscreen_check.toggled.connect(_on_setting_changed)
	add_child(_fullscreen_check)

	_crt_check = CheckButton.new()
	_crt_check.text = "CRT Effect"
	_crt_check.add_theme_font_size_override("font_size", 16)
	_crt_check.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	_crt_check.button_pressed = settings.get("crt_enabled", true)
	_crt_check.toggled.connect(_on_setting_changed)
	add_child(_crt_check)

	# Game section
	var sep3 := HSeparator.new()
	sep3.modulate = Color(0.0, 0.7, 0.8, 0.4)
	add_child(sep3)

	var game_label := Label.new()
	game_label.text = "GAME"
	game_label.add_theme_font_size_override("font_size", 14)
	game_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.8))
	add_child(game_label)

	var autosave_row := HBoxContainer.new()
	autosave_row.add_theme_constant_override("separation", 10)
	var autosave_label := Label.new()
	autosave_label.text = "Autosave"
	autosave_label.add_theme_font_size_override("font_size", 15)
	autosave_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.82))
	autosave_label.custom_minimum_size = Vector2(80, 0)
	autosave_row.add_child(autosave_label)

	_autosave_option = OptionButton.new()
	_autosave_option.add_theme_font_size_override("font_size", 15)
	_autosave_option.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	var current_interval: int = int(settings.get("autosave_interval", 300))
	var selected_idx: int = 1  # default: 5 min
	for i in range(AUTOSAVE_OPTIONS.size()):
		_autosave_option.add_item(AUTOSAVE_OPTIONS[i][0], i)
		if AUTOSAVE_OPTIONS[i][1] == current_interval:
			selected_idx = i
	_autosave_option.selected = selected_idx
	_autosave_option.item_selected.connect(_on_setting_changed)
	_autosave_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	autosave_row.add_child(_autosave_option)
	add_child(autosave_row)

	# Spacer + Back
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	add_child(spacer)

	var back_btn := _create_back_button()
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)


func _create_slider_row(label_text: String, initial: int) -> Dictionary:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.82))
	label.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = initial
	slider.custom_minimum_size = Vector2(160, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_slider(slider)
	hbox.add_child(slider)

	var val_label := Label.new()
	val_label.text = "%d%%" % initial
	val_label.add_theme_font_size_override("font_size", 14)
	val_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
	val_label.custom_minimum_size = Vector2(48, 0)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(val_label)

	return {"container": hbox, "slider": slider, "value_label": val_label}


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.1, 0.14)
	track.set_corner_radius_all(3)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)

	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.0, 0.6, 0.7, 0.8)
	grab.set_corner_radius_all(3)
	grab.content_margin_top = 4
	grab.content_margin_bottom = 4
	slider.add_theme_stylebox_override("grabber_area", grab)

	var grab_hl := grab.duplicate()
	grab_hl.bg_color = Color(0.0, 0.8, 0.9, 0.9)
	slider.add_theme_stylebox_override("grabber_area_highlight", grab_hl)


func _create_back_button() -> Button:
	var btn := Button.new()
	btn.text = "Back"
	btn.custom_minimum_size = Vector2(280, 44)
	btn.add_theme_font_size_override("font_size", 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	style.border_color = Color(0.0, 0.7, 0.8, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	hover.border_color = Color(0.0, 0.9, 1.0, 0.9)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color(0.04, 0.06, 0.1, 1.0)
	pressed.border_color = Color(0.0, 1.0, 1.0, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95))
	btn.add_theme_color_override("font_hover_color", Color(0.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	return btn


func _on_master_changed(val: float) -> void:
	_master_lbl.text = "%d%%" % int(val)
	_apply_live()


func _on_sfx_changed(val: float) -> void:
	_sfx_lbl.text = "%d%%" % int(val)
	_apply_live()


func _on_ambient_changed(val: float) -> void:
	_ambient_lbl.text = "%d%%" % int(val)
	_apply_live()


func _on_setting_changed(_value) -> void:
	_apply_live()


func _apply_live() -> void:
	var data := _gather()
	SettingsManager.apply_all(data)
	settings_changed.emit()


func _on_back() -> void:
	SettingsManager.save(_gather())
	back_pressed.emit()


func _gather() -> Dictionary:
	var autosave_idx: int = _autosave_option.selected if _autosave_option else 1
	var autosave_sec: int = AUTOSAVE_OPTIONS[autosave_idx][1] if autosave_idx < AUTOSAVE_OPTIONS.size() else 300
	return {
		"master_volume": int(_master_slider.value),
		"sfx_volume": int(_sfx_slider.value),
		"ambient_volume": int(_ambient_slider.value),
		"fullscreen": _fullscreen_check.button_pressed,
		"crt_enabled": _crt_check.button_pressed,
		"autosave_interval": autosave_sec,
	}
