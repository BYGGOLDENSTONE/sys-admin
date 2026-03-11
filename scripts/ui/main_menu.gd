extends Control

## Main Menu — entry point for SYS_ADMIN demo.
## New Game starts a fresh session, Continue loads the latest save.

const SAVE_FILE: String = "user://saves/savegame.json"
const AUTOSAVE_FILE: String = "user://saves/autosave.json"
const GAME_SCENE: String = "res://scenes/main.tscn"

var _continue_btn: Button = null
var _new_game_btn: Button = null
var _options_btn: Button = null
var _quit_btn: Button = null
var _button_vbox: VBoxContainer = null
var _options_panel: VBoxContainer = null


func _ready() -> void:
	# Apply saved settings on startup
	SettingsManager.apply_all(SettingsManager.get_settings())

	_build_ui()
	_update_continue_state()
	# Fade in
	modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.6)


func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main container (centered)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_box := VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 0)
	main_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(main_box)

	# Title
	var title := Label.new()
	title.text = "SYS_ADMIN"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 0.9, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_box.add_child(title)

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
	_button_vbox.add_theme_constant_override("separation", 16)
	_button_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_child(_button_vbox)

	_continue_btn = _create_menu_button("Continue")
	_continue_btn.pressed.connect(_on_continue)
	_button_vbox.add_child(_continue_btn)

	_new_game_btn = _create_menu_button("New Game")
	_new_game_btn.pressed.connect(_on_new_game)
	_button_vbox.add_child(_new_game_btn)

	_options_btn = _create_menu_button("Options")
	_options_btn.pressed.connect(_on_options)
	_button_vbox.add_child(_options_btn)

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
	version_lbl.text = "Demo v0.9"
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


func _update_continue_state() -> void:
	var has_save: bool = FileAccess.file_exists(SAVE_FILE) or FileAccess.file_exists(AUTOSAVE_FILE)
	_continue_btn.disabled = not has_save
	if has_save:
		_continue_btn.tooltip_text = "Resume your last session"
	else:
		_continue_btn.tooltip_text = "No saved game found"


func _on_continue() -> void:
	# Try save file first, then autosave
	var SaveManagerScript = preload("res://scripts/save_manager.gd")
	var save_data: Dictionary = {}
	if FileAccess.file_exists(SAVE_FILE):
		save_data = SaveManagerScript.load_from_file(SAVE_FILE)
	elif FileAccess.file_exists(AUTOSAVE_FILE):
		save_data = SaveManagerScript.load_from_file(AUTOSAVE_FILE)

	if save_data.is_empty():
		push_warning("[MainMenu] Failed to load save — starting new game")
		_on_new_game()
		return

	_transition_to_game(save_data)


func _on_new_game() -> void:
	_transition_to_game({})


func _on_options() -> void:
	_button_vbox.visible = false
	_options_panel.visible = true


func _on_options_back() -> void:
	_options_panel.visible = false
	_button_vbox.visible = true


func _on_quit() -> void:
	get_tree().quit()


func _transition_to_game(save_data: Dictionary) -> void:
	# Disable buttons during transition
	_continue_btn.disabled = true
	_new_game_btn.disabled = true
	_options_btn.disabled = true
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
