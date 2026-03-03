extends PanelContainer

signal building_selected(definition: BuildingDefinition)

const PANEL_BG_COLOR := Color("#0d1117")
const BORDER_COLOR := Color("#00ccff")
const BUTTON_NORMAL_COLOR := Color("#1a1e2e")
const BUTTON_HOVER_COLOR := Color("#2a2e3e")
const TITLE_COLOR := Color("#00ccff")

var _definitions: Array[BuildingDefinition] = []
var _tech_tree: Node = null
var _button_container_ref: VBoxContainer = null


func _ready() -> void:
	_setup_panel_style()
	_load_definitions()
	_create_buttons()


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
	# Re-create visible buttons
	for def in _definitions:
		if _tech_tree and not _tech_tree.is_building_unlocked(def.building_name):
			continue
		var button := Button.new()
		button.text = def.building_name
		button.tooltip_text = def.description
		button.custom_minimum_size = Vector2(180, 48)
		_style_button(button, def.color)
		button.pressed.connect(_on_building_button_pressed.bind(def))
		_button_container_ref.add_child(button)


func _on_building_button_pressed(def: BuildingDefinition) -> void:
	building_selected.emit(def)
	print("[BuildingPanel] Building selected — %s" % def.building_name)


func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG_COLOR
	style.border_color = BORDER_COLOR
	style.border_width_left = 2
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)


func _style_button(button: Button, accent_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BUTTON_NORMAL_COLOR
	style.border_color = accent_color
	style.border_width_left = 3
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_left = 2
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = BUTTON_HOVER_COLOR
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = style.duplicate()
	pressed_style.bg_color = Color("#3a3e4e")
	button.add_theme_stylebox_override("pressed", pressed_style)

	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", accent_color)
	button.add_theme_color_override("font_pressed_color", accent_color)
