extends PanelContainer

const BG_COLOR := Color("#0d1117")
const BORDER_COLOR := Color("#00ccff")
const OFFSET := Vector2(16, 16)

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var info_label: Label = $MarginContainer/VBoxContainer/InfoLabel

var _target_building: Node2D = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_style()


func show_for_building(building: Node2D) -> void:
	if building == _target_building:
		return
	_target_building = building
	var def: BuildingDefinition = building.definition
	if def == null:
		hide_tooltip()
		return

	name_label.text = def.building_name
	name_label.add_theme_color_override("font_color", def.color)
	desc_label.text = def.description
	info_label.text = "%s | %d CR" % [def.category.to_upper(), def.base_cost]
	visible = true


func hide_tooltip() -> void:
	_target_building = null
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var viewport_size := get_viewport_rect().size
	var tip_size := size
	var pos := mouse_pos + OFFSET

	# Keep tooltip within viewport
	if pos.x + tip_size.x > viewport_size.x:
		pos.x = mouse_pos.x - tip_size.x - 8
	if pos.y + tip_size.y > viewport_size.y:
		pos.y = mouse_pos.y - tip_size.y - 8

	global_position = pos


func _setup_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
