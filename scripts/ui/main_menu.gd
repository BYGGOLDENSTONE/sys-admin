extends Control

## Main Menu — entry point for SYS_ADMIN demo.
## New Game starts a fresh session, Continue loads the latest save.

const GAME_SCENE: String = "res://scenes/main.tscn"
const SaveManagerScript = preload("res://scripts/save_manager.gd")
const TITLE_COLOR := Color(0.0, 0.85, 0.9, 1.0)
const GLITCH_CHARS: String = "█▓░▒#@$%&*"
const WISHLIST_URL: String = "https://store.steampowered.com/app/PLACEHOLDER_APP_ID/SYS_ADMIN/"
const FEEDBACK_URL: String = "https://store.steampowered.com/app/PLACEHOLDER_APP_ID/SYS_ADMIN/discussions/"

var _options_btn: Button = null
var _wishlist_btn: Button = null
var _quit_btn: Button = null
var _button_vbox: VBoxContainer = null
var _slot_vbox: VBoxContainer = null
var _options_panel: VBoxContainer = null
var _title: Label = null
var _slot_buttons: Array[Button] = []

# Glitch state
var _glitch_timer: float = 0.0
var _next_glitch: float = 3.0
var _glitch_active: bool = false
var _glitch_end: float = 0.0


func _ready() -> void:
	# Apply saved settings on startup
	SettingsManager.apply_all(SettingsManager.get_settings())

	_build_ui()
	_update_continue_state()
	_next_glitch = randf_range(2.0, 5.0)
	# Fade in
	modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	_update_glitch(delta)


func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Data rain background
	var DataRainScript = preload("res://scripts/ui/data_rain.gd")
	var rain := Control.new()
	rain.set_script(DataRainScript)
	add_child(rain)

	# Main container (centered)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_box := VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 0)
	main_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(main_box)

	# Title
	_title = Label.new()
	_title.text = "SYS_ADMIN"
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", TITLE_COLOR)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_box.add_child(_title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Data Pipeline Puzzle"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.4, 0.55, 0.65, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_box.add_child(subtitle)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	main_box.add_child(spacer)

	# Menu buttons
	_button_vbox = VBoxContainer.new()
	_button_vbox.add_theme_constant_override("separation", 12)
	_button_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_child(_button_vbox)

	# Save slot buttons
	_slot_vbox = VBoxContainer.new()
	_slot_vbox.add_theme_constant_override("separation", 8)
	_button_vbox.add_child(_slot_vbox)
	_build_slot_buttons()

	# Bottom buttons spacer
	var btn_spacer := Control.new()
	btn_spacer.custom_minimum_size = Vector2(0, 8)
	_button_vbox.add_child(btn_spacer)

	_options_btn = _create_menu_button("Options")
	_options_btn.pressed.connect(_on_options)
	_button_vbox.add_child(_options_btn)

	_wishlist_btn = _create_menu_button("Wishlist Full Game")
	_wishlist_btn.pressed.connect(_on_wishlist)
	_button_vbox.add_child(_wishlist_btn)

	_quit_btn = _create_menu_button("Quit")
	_quit_btn.pressed.connect(_on_quit)
	_button_vbox.add_child(_quit_btn)

	# Options panel (hidden, replaces buttons when active)
	var OptionsPanelScript = preload("res://scripts/ui/options_panel.gd")
	_options_panel = VBoxContainer.new()
	_options_panel.set_script(OptionsPanelScript)
	_options_panel.visible = false
	_options_panel.back_pressed.connect(_on_options_back)
	main_box.add_child(_options_panel)

	# Version label
	var version_lbl := Label.new()
	version_lbl.text = "Demo v1.0"
	version_lbl.add_theme_font_size_override("font_size", 12)
	version_lbl.add_theme_color_override("font_color", Color(0.3, 0.4, 0.5, 0.5))
	version_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version_lbl.offset_right = -16.0
	version_lbl.offset_bottom = -12.0
	version_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(version_lbl)


func _create_menu_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 50)
	btn.add_theme_font_size_override("font_size", 22)
	# Cyber-style flat button
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	style.border_color = Color(0.0, 0.7, 0.8, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	hover_style.border_color = Color(0.0, 0.9, 1.0, 0.9)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(0.04, 0.06, 0.1, 1.0)
	pressed_style.border_color = Color(0.0, 1.0, 1.0, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style := style.duplicate()
	disabled_style.bg_color = Color(0.04, 0.05, 0.06, 0.5)
	disabled_style.border_color = Color(0.2, 0.25, 0.3, 0.3)
	btn.add_theme_stylebox_override("disabled", disabled_style)

	btn.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.35, 0.4, 0.5))
	return btn


func _build_slot_buttons() -> void:
	_slot_buttons.clear()
	var slots: Array[Dictionary] = SaveManagerScript.list_slots()
	for info in slots:
		var slot_idx: int = info.slot
		var btn: Button
		if info.exists:
			var ts: String = info.get("timestamp", "")
			if ts.length() > 16:
				ts = ts.substr(0, 16)
			btn = _create_menu_button("Slot %d  —  Seed %d  (%s)" % [slot_idx, info.get("seed", 0), ts])
			btn.tooltip_text = "Load this save"
		else:
			btn = _create_menu_button("Slot %d  —  New Game" % slot_idx)
			btn.tooltip_text = "Start a new game in this slot"
		btn.pressed.connect(_on_slot_selected.bind(slot_idx))
		_slot_vbox.add_child(btn)
		_slot_buttons.append(btn)


func _update_continue_state() -> void:
	pass  ## Slot buttons handle their own state


# ── Glitch Effect ─────────────────────────────────────────────

func _update_glitch(delta: float) -> void:
	if _title == null:
		return
	_glitch_timer += delta
	if _glitch_active:
		if _glitch_timer >= _glitch_end:
			# End glitch
			_glitch_active = false
			_title.text = "SYS_ADMIN"
			_title.add_theme_color_override("font_color", TITLE_COLOR)
			_title.position.x = 0.0
			_glitch_timer = 0.0
			_next_glitch = randf_range(3.0, 8.0)
	else:
		if _glitch_timer >= _next_glitch:
			# Start glitch burst
			_glitch_active = true
			_glitch_timer = 0.0
			_glitch_end = randf_range(0.06, 0.18)
			# Corrupt 1-2 characters
			var original := "SYS_ADMIN"
			var result := original
			var corrupt_count := randi_range(1, 2)
			for _i in range(corrupt_count):
				var idx := randi_range(0, original.length() - 1)
				var gc: String = GLITCH_CHARS[randi() % GLITCH_CHARS.length()]
				result = result.substr(0, idx) + gc + result.substr(idx + 1)
			_title.text = result
			# Color flash + horizontal offset
			_title.add_theme_color_override("font_color", Color(1.0, 0.15, 0.25, 0.9))
			_title.position.x = randf_range(-6.0, 6.0)


# ── Navigation ────────────────────────────────────────────────

func _on_slot_selected(slot: int) -> void:
	# Try main save, then autosave
	var save_data: Dictionary = {}
	for path in [SaveManagerScript.slot_path(slot), SaveManagerScript.slot_auto_path(slot)]:
		if not FileAccess.file_exists(path):
			continue
		var data: Dictionary = SaveManagerScript.load_from_file(path)
		if data.get("_incompatible", false):
			continue
		if not data.is_empty():
			save_data = data
			break
	# Pass slot index to game
	save_data["_slot"] = slot
	_transition_to_game(save_data)


func _on_options() -> void:
	_button_vbox.visible = false
	_options_panel.visible = true


func _on_options_back() -> void:
	_options_panel.visible = false
	_button_vbox.visible = true


func _on_wishlist() -> void:
	OS.shell_open(WISHLIST_URL)


func _on_quit() -> void:
	get_tree().quit()


func _transition_to_game(save_data: Dictionary) -> void:
	# Disable all buttons during transition
	for btn in _slot_buttons:
		btn.disabled = true
	_options_btn.disabled = true
	_wishlist_btn.disabled = true
	_quit_btn.disabled = true

	# Fade out
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		var game_scene := load(GAME_SCENE) as PackedScene
		var game_instance := game_scene.instantiate()
		if not save_data.is_empty():
			game_instance.load_save_data = save_data
		get_tree().root.add_child(game_instance)
		queue_free()
	)
