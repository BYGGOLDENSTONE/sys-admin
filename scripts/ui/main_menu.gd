extends Control

## Main Menu — entry point for SYS_ADMIN demo.
## New Game auto-assigns an empty slot. Load Game shows saved slots.

const GAME_SCENE: String = "res://scenes/main.tscn"
const SaveManagerScript = preload("res://scripts/save_manager.gd")
const TITLE_COLOR := Color(0.0, 0.85, 0.9, 1.0)
const GLITCH_CHARS: String = "█▓░▒#@$%&*"
const WISHLIST_URL: String = "https://store.steampowered.com/app/PLACEHOLDER_APP_ID/SYS_ADMIN/"
const FEEDBACK_URL: String = "https://store.steampowered.com/app/PLACEHOLDER_APP_ID/SYS_ADMIN/discussions/"

var _new_game_btn: Button = null
var _load_game_btn: Button = null
var _options_btn: Button = null
var _feedback_btn: Button = null
var _wishlist_btn: Button = null
var _quit_btn: Button = null
var _button_vbox: VBoxContainer = null
var _load_vbox: VBoxContainer = null
var _options_panel: VBoxContainer = null
var _title: Label = null

# Glitch state
var _glitch_timer: float = 0.0
var _next_glitch: float = 3.0
var _glitch_active: bool = false
var _glitch_end: float = 0.0


func _ready() -> void:
	SettingsManager.apply_all(SettingsManager.get_settings())
	_build_ui()
	_next_glitch = randf_range(2.0, 5.0)
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

	# Main menu buttons
	_button_vbox = VBoxContainer.new()
	_button_vbox.add_theme_constant_override("separation", 16)
	_button_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_child(_button_vbox)

	_new_game_btn = _create_menu_button("New Game")
	_new_game_btn.pressed.connect(_on_new_game)
	_button_vbox.add_child(_new_game_btn)

	_load_game_btn = _create_menu_button("Load Game")
	_load_game_btn.pressed.connect(_on_load_game)
	_button_vbox.add_child(_load_game_btn)

	_options_btn = _create_menu_button("Options")
	_options_btn.pressed.connect(_on_options)
	_button_vbox.add_child(_options_btn)

	_feedback_btn = _create_menu_button("Give Feedback")
	_feedback_btn.pressed.connect(_on_feedback)
	_button_vbox.add_child(_feedback_btn)

	_wishlist_btn = _create_menu_button("Wishlist Full Game")
	_wishlist_btn.pressed.connect(_on_wishlist)
	_button_vbox.add_child(_wishlist_btn)

	_quit_btn = _create_menu_button("Quit")
	_quit_btn.pressed.connect(_on_quit)
	_button_vbox.add_child(_quit_btn)

	# Load game panel (hidden, replaces buttons when active)
	_load_vbox = VBoxContainer.new()
	_load_vbox.add_theme_constant_override("separation", 10)
	_load_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_load_vbox.visible = false
	main_box.add_child(_load_vbox)

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

	# Check if any saves exist
	_update_load_button()


func _update_load_button() -> void:
	var has_saves := false
	var slots: Array[Dictionary] = SaveManagerScript.list_slots()
	for info in slots:
		if info.exists:
			has_saves = true
			break
	_load_game_btn.disabled = not has_saves
	if not has_saves:
		_load_game_btn.tooltip_text = "No saved games"


func _create_menu_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 50)
	btn.add_theme_font_size_override("font_size", 22)
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


func _format_timestamp(ts: String) -> String:
	## Convert "2026-03-15T06:34:18" → "Mar 15, 2026 — 6:34 AM"
	if ts.length() < 16:
		return ts
	var date_part: String = ts.substr(0, 10)  # "2026-03-15"
	var time_part: String = ts.substr(11, 5)  # "06:34"
	var parts: PackedStringArray = date_part.split("-")
	if parts.size() < 3:
		return ts
	var year: String = parts[0]
	var month: int = int(parts[1])
	var day: int = int(parts[2])
	var month_names: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var month_str: String = month_names[month - 1] if month >= 1 and month <= 12 else str(month)
	var time_parts: PackedStringArray = time_part.split(":")
	var hour: int = int(time_parts[0])
	var minute: String = time_parts[1] if time_parts.size() > 1 else "00"
	var ampm: String = "AM"
	if hour >= 12:
		ampm = "PM"
		if hour > 12:
			hour -= 12
	elif hour == 0:
		hour = 12
	return "%s %d, %s — %d:%s %s" % [month_str, day, year, hour, minute, ampm]


func _create_slot_button(text: String) -> Button:
	var btn := _create_menu_button(text)
	btn.custom_minimum_size = Vector2(480, 44)
	btn.add_theme_font_size_override("font_size", 18)
	return btn


# ── Glitch Effect ─────────────────────────────────────────────

func _update_glitch(delta: float) -> void:
	if _title == null:
		return
	_glitch_timer += delta
	if _glitch_active:
		if _glitch_timer >= _glitch_end:
			_glitch_active = false
			_title.text = "SYS_ADMIN"
			_title.add_theme_color_override("font_color", TITLE_COLOR)
			_title.position.x = 0.0
			_glitch_timer = 0.0
			_next_glitch = randf_range(3.0, 8.0)
	else:
		if _glitch_timer >= _next_glitch:
			_glitch_active = true
			_glitch_timer = 0.0
			_glitch_end = randf_range(0.06, 0.18)
			var original := "SYS_ADMIN"
			var result := original
			var corrupt_count := randi_range(1, 2)
			for _i in range(corrupt_count):
				var idx := randi_range(0, original.length() - 1)
				var gc: String = GLITCH_CHARS[randi() % GLITCH_CHARS.length()]
				result = result.substr(0, idx) + gc + result.substr(idx + 1)
			_title.text = result
			_title.add_theme_color_override("font_color", Color(1.0, 0.15, 0.25, 0.9))
			_title.position.x = randf_range(-6.0, 6.0)


# ── Navigation ────────────────────────────────────────────────

func _on_new_game() -> void:
	# Find first empty slot
	var slots: Array[Dictionary] = SaveManagerScript.list_slots()
	var target_slot: int = -1
	for info in slots:
		if not info.exists:
			target_slot = info.slot
			break
	if target_slot < 0:
		# All slots full — use slot 1 (overwrite oldest)
		target_slot = 1
	_transition_to_game({"_slot": target_slot})


func _on_load_game() -> void:
	_button_vbox.visible = false
	# Build slot list
	for child in _load_vbox.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "// LOAD GAME"
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", TITLE_COLOR)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_vbox.add_child(header)

	var slots: Array[Dictionary] = SaveManagerScript.list_slots()
	for info in slots:
		if not info.exists:
			continue
		var ts: String = _format_timestamp(info.get("timestamp", ""))
		var net_connected: int = info.get("network_connected", 0)
		var net_total: int = info.get("network_total", 0)
		var net_str: String = ""
		if net_total > 0:
			var pct: int = int(float(net_connected) / float(net_total) * 100.0)
			net_str = "  ·  NETWORK %d%%" % pct
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var btn := _create_slot_button("Slot %d  —  Seed %d  (%s)%s" % [info.slot, info.get("seed", 0), ts, net_str])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_slot_load.bind(info.slot))
		row.add_child(btn)
		var del_btn := _create_slot_button("X")
		del_btn.custom_minimum_size = Vector2(44, 44)
		del_btn.tooltip_text = "Delete this save"
		del_btn.pressed.connect(_on_slot_delete.bind(info.slot))
		row.add_child(del_btn)
		_load_vbox.add_child(row)

	var back_btn := _create_slot_button("Back")
	back_btn.pressed.connect(_on_load_back)
	_load_vbox.add_child(back_btn)

	_load_vbox.visible = true


func _on_slot_load(slot: int) -> void:
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
	save_data["_slot"] = slot
	_transition_to_game(save_data)


func _on_slot_delete(slot: int) -> void:
	# Show styled confirmation overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.06, 0.1, 0.95)
	panel_style.border_color = Color(0.0, 0.7, 0.8, 0.7)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "// DELETE SAVE"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3, 1.0))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = "Are you sure you want to delete Slot %d?\nThis cannot be undone." % slot
	msg_lbl.add_theme_font_size_override("font_size", 16)
	msg_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85, 0.9))
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var cancel_btn := _create_menu_button("Cancel")
	cancel_btn.custom_minimum_size = Vector2(160, 44)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.pressed.connect(overlay.queue_free)
	btn_row.add_child(cancel_btn)

	var delete_btn := _create_menu_button("Delete")
	delete_btn.custom_minimum_size = Vector2(160, 44)
	delete_btn.add_theme_font_size_override("font_size", 18)
	# Red border for delete button
	var del_style := StyleBoxFlat.new()
	del_style.bg_color = Color(0.12, 0.04, 0.04, 0.95)
	del_style.border_color = Color(1.0, 0.3, 0.25, 0.7)
	del_style.set_border_width_all(2)
	del_style.set_corner_radius_all(4)
	del_style.set_content_margin_all(12)
	delete_btn.add_theme_stylebox_override("normal", del_style)
	var del_hover := del_style.duplicate()
	del_hover.bg_color = Color(0.18, 0.06, 0.06, 0.95)
	del_hover.border_color = Color(1.0, 0.4, 0.35, 1.0)
	delete_btn.add_theme_stylebox_override("hover", del_hover)
	delete_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45, 1.0))
	delete_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.7, 0.65, 1.0))
	delete_btn.pressed.connect(func():
		overlay.queue_free()
		for path in [SaveManagerScript.slot_path(slot), SaveManagerScript.slot_auto_path(slot)]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		_on_load_game()
		_update_load_button()
	)
	btn_row.add_child(delete_btn)


func _on_load_back() -> void:
	_load_vbox.visible = false
	_button_vbox.visible = true


func _on_options() -> void:
	_button_vbox.visible = false
	_options_panel.visible = true


func _on_options_back() -> void:
	_options_panel.visible = false
	_button_vbox.visible = true


func _on_feedback() -> void:
	OS.shell_open(FEEDBACK_URL)


func _on_wishlist() -> void:
	OS.shell_open(WISHLIST_URL)


func _on_quit() -> void:
	get_tree().quit()


func _transition_to_game(save_data: Dictionary) -> void:
	# Disable all buttons
	_new_game_btn.disabled = true
	_load_game_btn.disabled = true
	_options_btn.disabled = true
	_feedback_btn.disabled = true
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
