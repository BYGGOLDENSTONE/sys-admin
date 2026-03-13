extends PanelContainer

signal building_selected(definition: BuildingDefinition)

const PANEL_BG_COLOR := Color(0.04, 0.06, 0.09, 0.93)
const BORDER_COLOR := Color(0.13, 0.67, 0.87, 0.38)
const BUTTON_NORMAL_COLOR := Color(0.08, 0.1, 0.14, 0.7)
const BUTTON_HOVER_COLOR := Color(0.12, 0.18, 0.26, 0.85)
const BUTTON_PRESSED_COLOR := Color(0.16, 0.24, 0.36, 0.9)
const LOCKED_BG_COLOR := Color(0.05, 0.06, 0.08, 0.5)
const LOCKED_BORDER_COLOR := Color(0.2, 0.22, 0.25, 0.4)
const LOCKED_TEXT_COLOR := Color(0.35, 0.38, 0.42, 0.7)
const TITLE_COLOR := Color("#00bbee")
const ACCENT_COLOR := Color(0.9, 0.6, 0.25)
const DEMO_MAX_LEVEL: int = 1

## Display order for buildings (consistent layout)
const BUILDING_ORDER: PackedStringArray = [
	"Trash", "Splitter",
	"Separator", "Classifier", "Merger", "Recoverer",
	"Research Lab", "Decryptor", "Encryptor", "Compiler",
]

## Which gig unlocks each building (for locked tooltip)
const UNLOCK_GIG: Dictionary = {
	"Separator": "Gig 2: Clean Data Only",
	"Classifier": "Gig 3: Sorting by Type",
	"Merger": "Gig 6: Streamlined Delivery",
	"Recoverer": "Gig 7: Data Recovery",
	"Research Lab": "Gig 5: Decryption Run",
	"Decryptor": "Gig 5: Decryption Run",
	"Encryptor": "Gig 8: Encryption Job",
	"Compiler": "Gig 9: Package Deal",
}

var _definitions: Array[BuildingDefinition] = []
var _gig_manager: Node = null
var _simulation_manager: Node = null
var _button_container_ref: VBoxContainer = null
var _panel_tween: Tween = null
var _is_panel_visible: bool = false

# Detail view references
var _title_label_ref: Label = null
var _scroll_container_ref: ScrollContainer = null
var _detail_container: VBoxContainer = null
var _detail_name: Label = null
var _detail_desc: Label = null
var _detail_stats: RichTextLabel = null
var _detail_upgrade_header: Label = null
var _detail_upgrade_dots: HBoxContainer = null
var _detail_upgrade_stat: RichTextLabel = null
var _detail_upgrade_btn: Button = null
var _detail_upgrade_cap: Label = null
var _selected_building: Node2D = null
var _in_detail_mode: bool = false


func _ready() -> void:
	_setup_panel_style()
	_load_definitions()
	_title_label_ref = $MarginContainer/VBoxContainer/TitleLabel
	_scroll_container_ref = $MarginContainer/VBoxContainer/ScrollContainer
	_create_buttons()
	_build_detail_ui()
	_play_slide_in()


func _process(_delta: float) -> void:
	if _in_detail_mode and _selected_building != null:
		_update_detail()


func _play_slide_in() -> void:
	modulate = Color(1, 1, 1, 0)
	var target_x: float = offset_left
	offset_left = offset_left + 60.0
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(self, "modulate:a", 1.0, 0.4).set_delay(0.2)
	_panel_tween.tween_property(self, "offset_left", target_x, 0.5).set_delay(0.2)


func _load_definitions() -> void:
	var dir := DirAccess.open("res://resources/buildings/")
	if dir == null:
		push_error("[BuildingPanel] Cannot open buildings resource directory")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var def := load("res://resources/buildings/" + file_name) as BuildingDefinition
			if def != null:
				_definitions.append(def)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("[BuildingPanel] Loaded %d building definitions" % _definitions.size())


func _create_buttons() -> void:
	_button_container_ref = $MarginContainer/VBoxContainer/ScrollContainer/ButtonContainer
	_rebuild_buttons()


func refresh_buttons() -> void:
	_rebuild_buttons()


func _rebuild_buttons() -> void:
	if _button_container_ref == null:
		return
	# Clear old buttons
	for child in _button_container_ref.get_children():
		child.queue_free()

	# Build a name->def lookup
	var def_map: Dictionary = {}
	for def in _definitions:
		def_map[def.building_name] = def

	# Re-create buttons in fixed order with staggered fade-in
	var idx := 0
	for bname in BUILDING_ORDER:
		var def: BuildingDefinition = def_map.get(bname)
		if def == null or not def.is_placeable:
			continue
		var unlocked: bool = not _gig_manager or _gig_manager.is_building_unlocked(bname)

		var button := Button.new()
		button.custom_minimum_size = Vector2(180, 48)

		if unlocked:
			button.text = def.building_name
			button.tooltip_text = def.description
			_style_button(button, def.color)
			button.pressed.connect(_on_building_button_pressed.bind(def))
		else:
			var unlock_info: String = UNLOCK_GIG.get(bname, "a gig")
			button.text = "🔒 %s" % def.building_name
			button.tooltip_text = "Unlocks after %s" % unlock_info
			button.disabled = true
			_style_locked_button(button)

		_button_container_ref.add_child(button)

		# Staggered fade-in animation
		button.modulate = Color(1, 1, 1, 0)
		button.position.x = 20.0
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(idx * 0.05)
		tw.tween_property(button, "modulate:a", 1.0, 0.3).set_delay(idx * 0.05)
		tw.tween_property(button, "position:x", 0.0, 0.3).set_delay(idx * 0.05)
		idx += 1


func _on_building_button_pressed(def: BuildingDefinition) -> void:
	building_selected.emit(def)
	print("[BuildingPanel] Building selected — %s" % def.building_name)


# --- DETAIL VIEW ---

func _build_detail_ui() -> void:
	var vbox: VBoxContainer = $MarginContainer/VBoxContainer
	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", 8)
	_detail_container.visible = false
	vbox.add_child(_detail_container)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "← Structures"
	back_btn.add_theme_font_size_override("font_size", 13)
	back_btn.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8, 0.8))
	back_btn.add_theme_color_override("font_hover_color", TITLE_COLOR)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.06, 0.08, 0.12, 0.5)
	back_style.set_content_margin_all(6)
	back_style.set_corner_radius_all(2)
	back_btn.add_theme_stylebox_override("normal", back_style)
	var back_hover := back_style.duplicate()
	back_hover.bg_color = Color(0.1, 0.14, 0.2, 0.7)
	back_btn.add_theme_stylebox_override("hover", back_hover)
	back_btn.pressed.connect(hide_building_detail)
	_detail_container.add_child(back_btn)

	# Building name
	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 18)
	_detail_container.add_child(_detail_name)

	# Description
	_detail_desc = Label.new()
	_detail_desc.add_theme_font_size_override("font_size", 12)
	_detail_desc.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.8))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_container.add_child(_detail_desc)

	# Separator
	var sep1 := HSeparator.new()
	sep1.add_theme_constant_override("separation", 4)
	_detail_container.add_child(sep1)

	# Live status
	_detail_stats = RichTextLabel.new()
	_detail_stats.bbcode_enabled = true
	_detail_stats.fit_content = true
	_detail_stats.scroll_active = false
	_detail_stats.add_theme_font_size_override("normal_font_size", 13)
	_detail_container.add_child(_detail_stats)

	# Separator
	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 4)
	_detail_container.add_child(sep2)

	# Upgrade header
	_detail_upgrade_header = Label.new()
	_detail_upgrade_header.text = "// UPGRADE"
	_detail_upgrade_header.add_theme_font_size_override("font_size", 14)
	_detail_upgrade_header.add_theme_color_override("font_color", ACCENT_COLOR)
	_detail_container.add_child(_detail_upgrade_header)

	# Level dots
	_detail_upgrade_dots = HBoxContainer.new()
	_detail_upgrade_dots.add_theme_constant_override("separation", 4)
	_detail_container.add_child(_detail_upgrade_dots)

	# Upgrade stat
	_detail_upgrade_stat = RichTextLabel.new()
	_detail_upgrade_stat.bbcode_enabled = true
	_detail_upgrade_stat.fit_content = true
	_detail_upgrade_stat.scroll_active = false
	_detail_upgrade_stat.custom_minimum_size = Vector2(0, 20)
	_detail_container.add_child(_detail_upgrade_stat)

	# Upgrade button
	_detail_upgrade_btn = Button.new()
	_detail_upgrade_btn.text = "[ UPGRADE ]"
	_detail_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	_style_upgrade_button(_detail_upgrade_btn)
	_detail_container.add_child(_detail_upgrade_btn)

	# Demo cap label
	_detail_upgrade_cap = Label.new()
	_detail_upgrade_cap.add_theme_font_size_override("font_size", 12)
	_detail_upgrade_cap.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55, 0.7))
	_detail_upgrade_cap.visible = false
	_detail_container.add_child(_detail_upgrade_cap)


func setup_detail(sim_manager: Node) -> void:
	_simulation_manager = sim_manager


func show_building_detail(building: Node2D) -> void:
	if building == null or building.definition == null:
		return
	# Don't show detail for Contract Terminal
	if building.definition.visual_type == "terminal":
		return
	_selected_building = building
	_in_detail_mode = true

	# Swap views
	_scroll_container_ref.visible = false
	_detail_container.visible = true
	_title_label_ref.text = "// %s" % building.definition.building_name.to_upper()
	_title_label_ref.add_theme_color_override("font_color", building.definition.color)

	# Fill static info
	_detail_name.text = building.definition.building_name
	_detail_name.add_theme_color_override("font_color", building.definition.color)
	_detail_desc.text = building.definition.description

	# Show/hide upgrade section
	var has_upgrade: bool = building.definition.upgrade != null
	_detail_upgrade_header.visible = has_upgrade
	_detail_upgrade_dots.visible = has_upgrade
	_detail_upgrade_stat.visible = has_upgrade
	_detail_upgrade_btn.visible = has_upgrade
	_detail_upgrade_cap.visible = false
	if not has_upgrade:
		_detail_upgrade_cap.visible = true
		_detail_upgrade_cap.text = "No upgrades available"

	_update_detail()


func hide_building_detail() -> void:
	_selected_building = null
	_in_detail_mode = false

	# Swap views back
	_scroll_container_ref.visible = true
	_detail_container.visible = false
	_title_label_ref.text = "// STRUCTURES"
	_title_label_ref.add_theme_color_override("font_color", TITLE_COLOR)


func _update_detail() -> void:
	if _selected_building == null or _selected_building.definition == null:
		hide_building_detail()
		return

	var b: Node2D = _selected_building
	var def: BuildingDefinition = b.definition

	# Live status
	var lines: PackedStringArray = []
	if b.is_working:
		lines.append("[color=#44ff88]● Working[/color]")
	else:
		var reason: String = b.status_reason
		if reason != "":
			lines.append("[color=#ffcc44]● Idle — %s[/color]" % reason)
		else:
			lines.append("[color=#ffcc44]● Idle[/color]")
	_detail_stats.text = "\n".join(lines)

	# Upgrade section
	if def.upgrade == null:
		return

	var upg: UpgradeComponent = def.upgrade
	var level: int = b.upgrade_level
	var max_level: int = upg.max_level
	var current_val: float = b.get_effective_value(upg.stat_target)

	# Update dots
	for child in _detail_upgrade_dots.get_children():
		child.queue_free()
	for i in range(max_level):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(16, 5)
		if i < level:
			dot.color = def.color
		elif i < DEMO_MAX_LEVEL:
			dot.color = Color(def.color, 0.25)
		else:
			dot.color = Color(0.3, 0.3, 0.35, 0.3)
		_detail_upgrade_dots.add_child(dot)

	# Update stat + button
	if level >= max_level:
		_detail_upgrade_stat.text = "[color=#ffaa44]%s: %s[/color] [color=#44ff88](MAX)[/color]" % [
			upg.stat_label, _format_stat(upg.stat_target, current_val)]
		_detail_upgrade_btn.visible = false
		_detail_upgrade_cap.visible = false
	elif level >= DEMO_MAX_LEVEL:
		_detail_upgrade_stat.text = "[color=#ffaa44]%s: %s[/color]" % [
			upg.stat_label, _format_stat(upg.stat_target, current_val)]
		_detail_upgrade_btn.visible = false
		_detail_upgrade_cap.visible = true
		_detail_upgrade_cap.text = "🔒 More upgrades in full game"
	else:
		var next_val: float = upg.level_values[level] if level < upg.level_values.size() else current_val
		_detail_upgrade_stat.text = "[color=#aaaaaa]%s:[/color] [color=#ffffff]%s[/color] → [color=#44ff88]%s[/color]" % [
			upg.stat_label, _format_stat(upg.stat_target, current_val), _format_stat(upg.stat_target, next_val)]
		_detail_upgrade_btn.visible = true
		_detail_upgrade_btn.disabled = false
		_detail_upgrade_cap.visible = false


func _format_stat(stat_target: String, value: float) -> String:
	match stat_target:
		"efficiency":
			return "%d%%" % int(value * 100)
		"processing_rate":
			return "%d MB/s" % int(value)
		"capacity":
			return "%d MB" % int(value)
	return "%.1f" % value


func _on_upgrade_pressed() -> void:
	if _selected_building == null or _simulation_manager == null:
		return
	_simulation_manager.upgrade_building(_selected_building)


func _style_upgrade_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.05, 0.7)
	style.border_color = ACCENT_COLOR
	style.border_width_bottom = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.25, 0.2, 0.08, 0.85)
	hover.shadow_color = Color(ACCENT_COLOR, 0.15)
	hover.shadow_size = 4
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.3, 0.25, 0.1, 0.9)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", ACCENT_COLOR)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.8, 0.4))
	btn.add_theme_font_size_override("font_size", 13)


# --- PANEL STYLING ---

func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG_COLOR
	style.border_color = BORDER_COLOR
	style.border_width_left = 2
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0.13, 0.53, 0.73, 0.06)
	style.shadow_size = 6
	add_theme_stylebox_override("panel", style)


func _style_locked_button(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = LOCKED_BG_COLOR
	style.border_color = LOCKED_BORDER_COLOR
	style.border_width_left = 3
	style.corner_radius_top_left = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_right = 1
	style.content_margin_left = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("disabled", style)
	button.add_theme_color_override("font_color", LOCKED_TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", LOCKED_TEXT_COLOR)


func _style_button(button: Button, accent_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BUTTON_NORMAL_COLOR
	style.border_color = accent_color
	style.border_width_left = 3
	style.corner_radius_top_left = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_right = 1
	style.content_margin_left = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = BUTTON_HOVER_COLOR
	hover_style.border_width_left = 5
	hover_style.shadow_color = Color(accent_color, 0.15)
	hover_style.shadow_size = 4
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = style.duplicate()
	pressed_style.bg_color = BUTTON_PRESSED_COLOR
	pressed_style.border_width_left = 5
	pressed_style.shadow_color = Color(accent_color, 0.2)
	pressed_style.shadow_size = 6
	button.add_theme_stylebox_override("pressed", pressed_style)

	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", accent_color)
	button.add_theme_color_override("font_pressed_color", accent_color)
