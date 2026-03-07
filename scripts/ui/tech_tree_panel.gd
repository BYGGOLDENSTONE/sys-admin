extends PanelContainer

signal building_unlocked(building_name: String)

const BG_COLOR := Color("#0d1117")
const BORDER_COLOR := Color("#aa88ff")
const BUTTON_NORMAL := Color("#1a1e2e")
const BUTTON_HOVER := Color("#2a2e3e")
const LOCKED_COLOR := Color("#666688")

## Each entry: {name, tres_path, cost, description}
var _tech_entries: Array[Dictionary] = [
	{"name": "Recoverer", "tres": "recoverer", "cost": 30, "desc": "Corrupted veriyi Patch Data'ya dönüştürür."},
	{"name": "Quarantine", "tres": "quarantine", "cost": 50, "desc": "Malware'i güvenli şekilde bertaraf eder."},
	{"name": "Splitter", "tres": "splitter", "cost": 40, "desc": "Veriyi birden fazla hedefe dağıtır."},
	{"name": "Merger", "tres": "merger", "cost": 40, "desc": "Birden fazla kaynağı tek çıkışa birleştirir."},
]

var _unlocked: Dictionary = {}  ## "name" -> true
var _simulation_manager: Node = null
var _building_panel: Node = null
var _button_container: VBoxContainer = null
var _title_label: Label = null
var _research_info: Label = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_style()
	_build_ui()
	_refresh_buttons()


func setup(sim_manager: Node, build_panel: Node) -> void:
	_simulation_manager = sim_manager
	_building_panel = build_panel


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			visible = not visible
			if visible:
				_refresh_buttons()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	custom_minimum_size = Vector2(280, 0)

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
	_title_label.text = "// TECH TREE [T]"
	_title_label.add_theme_color_override("font_color", BORDER_COLOR)
	_title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_title_label)

	_research_info = Label.new()
	_research_info.text = "Research: 0"
	_research_info.add_theme_color_override("font_color", Color("#aabbcc"))
	_research_info.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_research_info)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	_button_container = VBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_button_container)


func _refresh_buttons() -> void:
	# Clear old buttons
	for child in _button_container.get_children():
		child.queue_free()

	_research_info.text = ""

	# Create entry for each tech
	for entry in _tech_entries:
		var is_unlocked: bool = _unlocked.get(entry.name, false)
		var can_afford: bool = true

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		_button_container.add_child(hbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 13)
		if is_unlocked:
			name_label.text = entry.name + "  [AÇILDI]"
			name_label.add_theme_color_override("font_color", Color("#44ff88"))
		else:
			name_label.text = entry.name + "  [%d RP]" % entry.cost
			name_label.add_theme_color_override("font_color", Color.WHITE if can_afford else LOCKED_COLOR)
		info_vbox.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = entry.desc
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color("#667788"))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size.x = 180
		info_vbox.add_child(desc_label)

		if not is_unlocked:
			var btn := Button.new()
			btn.text = "Aç"
			btn.custom_minimum_size = Vector2(50, 32)
			btn.disabled = not can_afford
			_style_unlock_button(btn, can_afford)
			btn.pressed.connect(_on_unlock_pressed.bind(entry))
			hbox.add_child(btn)


func _on_unlock_pressed(entry: Dictionary) -> void:
	# Mark as unlocked
	_unlocked[entry.name] = true
	building_unlocked.emit(entry.name)
	print("[TechTree] %s açıldı — %d RP harcandı" % [entry.name, entry.cost])

	_refresh_buttons()

	# Refresh building panel to show new building
	if _building_panel and _building_panel.has_method("refresh_buttons"):
		_building_panel.refresh_buttons()


func is_building_unlocked(building_name: String) -> bool:
	# Check if building is in the tech tree at all
	for entry in _tech_entries:
		if entry.name == building_name:
			return _unlocked.get(building_name, false)
	# Not in tech tree = always available
	return true


func _style_unlock_button(btn: Button, can_afford: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BUTTON_NORMAL
	style.border_color = BORDER_COLOR if can_afford else LOCKED_COLOR
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 8
	style.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = BUTTON_HOVER
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", Color.WHITE if can_afford else LOCKED_COLOR)
	btn.add_theme_font_size_override("font_size", 12)


func _setup_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.border_width_left = 1
	style.border_width_top = 2
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)
