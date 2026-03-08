extends PanelContainer

signal building_selected(definition: BuildingDefinition)

const PANEL_BG_COLOR := Color(0.04, 0.06, 0.09, 0.93)
const BORDER_COLOR := Color(0.13, 0.67, 0.87, 0.38)
const BUTTON_NORMAL_COLOR := Color(0.08, 0.1, 0.14, 0.7)
const BUTTON_HOVER_COLOR := Color(0.12, 0.18, 0.26, 0.85)
const BUTTON_PRESSED_COLOR := Color(0.16, 0.24, 0.36, 0.9)
const TITLE_COLOR := Color("#00bbee")

var _definitions: Array[BuildingDefinition] = []
var _tech_tree: Node = null
var _button_container_ref: VBoxContainer = null
var _panel_tween: Tween = null
var _is_panel_visible: bool = false


func _ready() -> void:
	_setup_panel_style()
	_load_definitions()
	_create_buttons()
	# Slide-in animation on start
	_play_slide_in()


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
	# Re-create visible buttons with staggered fade-in
	var idx := 0
	for def in _definitions:
		if _tech_tree and not _tech_tree.is_building_unlocked(def.building_name):
			continue
		var button := Button.new()
		button.text = def.building_name
		button.tooltip_text = _build_cost_tooltip(def)
		button.custom_minimum_size = Vector2(180, 48)
		_style_button(button, def.color)
		button.pressed.connect(_on_building_button_pressed.bind(def))
		_button_container_ref.add_child(button)

		# Staggered fade-in animation
		button.modulate = Color(1, 1, 1, 0)
		button.position.x = 20.0
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(idx * 0.05)
		tw.tween_property(button, "modulate:a", 1.0, 0.3).set_delay(idx * 0.05)
		tw.tween_property(button, "position:x", 0.0, 0.3).set_delay(idx * 0.05)
		idx += 1


func _build_cost_tooltip(def: BuildingDefinition) -> String:
	var parts: PackedStringArray = [def.description]
	if not def.material_costs.is_empty() or not def.refined_costs.is_empty():
		parts.append("\nMaliyet:")
		for content_type in def.material_costs:
			parts.append("  %d %s(Clean)" % [def.material_costs[content_type], DataEnums.content_name(int(content_type))])
		for refined_type in def.refined_costs:
			parts.append("  %d %s" % [def.refined_costs[refined_type], DataEnums.refined_name(int(refined_type))])
	else:
		parts.append("\nBedava")
	return "\n".join(parts)


func _on_building_button_pressed(def: BuildingDefinition) -> void:
	building_selected.emit(def)
	print("[BuildingPanel] Building selected — %s" % def.building_name)


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
