extends PanelContainer

var _building: Node2D = null
var _simulation_manager = null

var _title_label: Label
var _stat_label: RichTextLabel
var _cost_label: Label
var _upgrade_button: Button


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(220, 0)

	# Build UI in code
	var vbox := VBoxContainer.new()
	add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2, 1))
	_title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_title_label)

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
	_upgrade_button.text = "Geliştir"
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	vbox.add_child(_upgrade_button)

	# Cyberpunk panel style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.16, 0.92)
	style.border_color = Color(0.9, 0.6, 0.2, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)


func setup(sim_manager) -> void:
	_simulation_manager = sim_manager


func show_for_building(building: Node2D) -> void:
	_building = building
	if building == null or building.definition.upgrade == null:
		visible = false
		return
	visible = true
	_update_display()


func hide_panel() -> void:
	_building = null
	visible = false


func _process(_delta: float) -> void:
	if not visible or _building == null:
		return
	_update_display()


func _update_display() -> void:
	if _building == null or _building.definition == null:
		visible = false
		return

	var def: BuildingDefinition = _building.definition
	var upg: UpgradeComponent = def.upgrade
	if upg == null:
		visible = false
		return

	var level: int = _building.upgrade_level
	var max_level: int = upg.max_level

	_title_label.text = "%s — Lv.%d/%d" % [def.building_name, level, max_level]

	# Stat info
	var current_val: float = _building.get_effective_value(upg.stat_target)

	if level >= max_level:
		_stat_label.text = "[color=#ffaa44]%s: %s[/color] [color=#44ff88](MAX)[/color]" % [
			upg.stat_label, _format_stat(upg.stat_target, current_val)]
		_cost_label.text = "Tam seviye!"
		_cost_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		_upgrade_button.visible = false
	else:
		var next_val: float = upg.level_values[level] if level < upg.level_values.size() else current_val
		_stat_label.text = "[color=#aaaaaa]%s:[/color] [color=#ffffff]%s[/color] → [color=#44ff88]%s[/color]" % [
			upg.stat_label, _format_stat(upg.stat_target, current_val), _format_stat(upg.stat_target, next_val)]
		var cost: int = _simulation_manager.get_upgrade_cost(_building)
		var can_afford: bool = _simulation_manager.total_patch_data >= cost
		_cost_label.text = "Maliyet: %d Patch Data" % cost
		_cost_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if can_afford else Color(1.0, 0.4, 0.4))
		_upgrade_button.visible = true
		_upgrade_button.disabled = not can_afford


func _format_stat(stat_target: String, value: float) -> String:
	match stat_target:
		"efficiency":
			return "%d%%" % int(value * 100)
		"processing_rate":
			return "%d MB/s" % int(value)
		"capacity":
			return "%d MB" % int(value)
		"zone_radius":
			return "%d px" % int(value)
		"cooling_rate":
			return "%.1f °C/s" % value
	return "%.1f" % value


func _on_upgrade_pressed() -> void:
	if _building == null or _simulation_manager == null:
		return
	_simulation_manager.upgrade_building(_building)
