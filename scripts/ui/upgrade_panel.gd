extends PanelContainer

var _building: Node2D = null
var _simulation_manager = null

var _title_label: Label
var _stat_label: RichTextLabel
var _cost_label: Label
var _upgrade_button: Button
var _progress_container: HBoxContainer
var _show_tween: Tween = null

const ACCENT_COLOR := Color(0.9, 0.6, 0.25)
const DEMO_MAX_LEVEL: int = 1  ## Demo allows up to level 1; higher levels teased as locked


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(240, 0)
	modulate = Color(1, 1, 1, 0)

	# Build UI in code
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", ACCENT_COLOR)
	_title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_title_label)

	# Level progress dots
	_progress_container = HBoxContainer.new()
	_progress_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_progress_container)

	_stat_label = RichTextLabel.new()
	_stat_label.bbcode_enabled = true
	_stat_label.fit_content = true
	_stat_label.custom_minimum_size = Vector2(0, 24)
	_stat_label.scroll_active = false
	vbox.add_child(_stat_label)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_cost_label)

	_upgrade_button = Button.new()
	_upgrade_button.text = "[ UPGRADE ]"
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_style_upgrade_button()
	vbox.add_child(_upgrade_button)

	# Cyberpunk panel style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.14, 0.92)
	style.border_color = Color(ACCENT_COLOR, 0.6)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(ACCENT_COLOR, 0.08)
	style.shadow_size = 4
	add_theme_stylebox_override("panel", style)


func _style_upgrade_button() -> void:
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.12, 0.05, 0.7)
	btn_style.border_color = ACCENT_COLOR
	btn_style.border_width_bottom = 2
	btn_style.corner_radius_bottom_left = 2
	btn_style.corner_radius_bottom_right = 2
	btn_style.content_margin_left = 12
	btn_style.content_margin_right = 12
	btn_style.content_margin_top = 6
	btn_style.content_margin_bottom = 6
	_upgrade_button.add_theme_stylebox_override("normal", btn_style)

	var hover := btn_style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.25, 0.2, 0.08, 0.85)
	hover.shadow_color = Color(ACCENT_COLOR, 0.15)
	hover.shadow_size = 4
	_upgrade_button.add_theme_stylebox_override("hover", hover)

	var pressed := btn_style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.3, 0.25, 0.1, 0.9)
	_upgrade_button.add_theme_stylebox_override("pressed", pressed)

	_upgrade_button.add_theme_color_override("font_color", ACCENT_COLOR)
	_upgrade_button.add_theme_color_override("font_hover_color", Color(1.0, 0.8, 0.4))
	_upgrade_button.add_theme_font_size_override("font_size", 13)


func setup(sim_manager) -> void:
	_simulation_manager = sim_manager


func show_for_building(building: Node2D) -> void:
	_building = building
	if building == null or building.definition.upgrade == null:
		hide_panel()
		return
	visible = true
	_update_display()
	_play_show_animation()


func _play_show_animation() -> void:
	if _show_tween:
		_show_tween.kill()
	_show_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_show_tween.tween_property(self, "modulate:a", 1.0, 0.25)


func hide_panel() -> void:
	_building = null
	if not visible:
		return
	if _show_tween:
		_show_tween.kill()
	_show_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_show_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	_show_tween.tween_callback(func(): visible = false)


func _process(_delta: float) -> void:
	if not visible or _building == null:
		return
	_update_display()


func _update_display() -> void:
	if _building == null or _building.definition == null:
		hide_panel()
		return

	var def: BuildingDefinition = _building.definition
	var upg: UpgradeComponent = def.upgrade
	if upg == null:
		hide_panel()
		return

	var level: int = _building.upgrade_level
	var max_level: int = upg.max_level

	_title_label.text = "%s — Lv.%d/%d" % [def.building_name, level, max_level]

	# Update progress dots
	_update_progress_dots(level, max_level, def.color)

	# Stat info
	var current_val: float = _building.get_effective_value(upg.stat_target)

	if level >= max_level:
		_stat_label.text = "[color=#ffaa44]%s: %s[/color] [color=#44ff88](MAX)[/color]" % [
			upg.stat_label, _format_stat(upg.stat_target, current_val)]
		_cost_label.text = ""
		_upgrade_button.visible = false
	elif level >= DEMO_MAX_LEVEL:
		# Demo cap reached — tease higher levels
		_stat_label.text = "[color=#ffaa44]%s: %s[/color]" % [
			upg.stat_label, _format_stat(upg.stat_target, current_val)]
		_cost_label.text = "🔒 More upgrades in full game"
		_cost_label.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55, 0.7))
		_upgrade_button.visible = false
	else:
		var next_val: float = upg.level_values[level] if level < upg.level_values.size() else current_val
		_stat_label.text = "[color=#aaaaaa]%s:[/color] [color=#ffffff]%s[/color] → [color=#44ff88]%s[/color]" % [
			upg.stat_label, _format_stat(upg.stat_target, current_val), _format_stat(upg.stat_target, next_val)]
		_cost_label.text = ""
		_upgrade_button.visible = true
		_upgrade_button.disabled = false


func _update_progress_dots(level: int, max_level: int, accent: Color) -> void:
	# Clear old dots
	for child in _progress_container.get_children():
		child.queue_free()
	# Create new dots
	for i in range(max_level):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 4)
		if i < level:
			dot.color = accent
		else:
			dot.color = Color(accent, 0.2)
		_progress_container.add_child(dot)


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
	if _building == null or _simulation_manager == null:
		return
	_simulation_manager.upgrade_building(_building)
