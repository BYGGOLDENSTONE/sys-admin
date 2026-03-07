extends PanelContainer

signal building_unlocked(building_name: String)

const BG_COLOR := Color("#0d1117")
const BORDER_COLOR := Color("#aa88ff")

## Discovery-based unlock rules (GDD Section 11)
## Each rule: building_name → {trigger_type, trigger_value}
## trigger_type: "content_count", "content", "state"
## content_count: unlocks when N distinct content types discovered
## content: unlocks when specific ContentType discovered
## state: unlocks when specific DataState discovered
var _unlock_rules: Array[Dictionary] = [
	{"name": "Recoverer", "trigger": "state", "value": DataEnums.DataState.CORRUPTED,
	 "desc": "Bozuk veri keşfedildiğinde açılır"},
	{"name": "Classifier", "trigger": "content_count", "value": 2,
	 "desc": "2. content türü keşfedildiğinde açılır"},
	{"name": "Research Lab", "trigger": "content", "value": DataEnums.ContentType.RESEARCH,
	 "desc": "Research verisi keşfedildiğinde açılır"},
	{"name": "Decryptor", "trigger": "state", "value": DataEnums.DataState.ENCRYPTED,
	 "desc": "Encrypted veri keşfedildiğinde açılır"},
	{"name": "Compiler", "trigger": "content_count", "value": 3,
	 "desc": "3. content türü keşfedildiğinde açılır"},
	{"name": "Quarantine", "trigger": "state", "value": DataEnums.DataState.MALWARE,
	 "desc": "Malware keşfedildiğinde açılır"},
]

var _unlocked: Dictionary = {}  ## "name" -> true
var _simulation_manager: Node = null
var _building_panel: Node = null
var _info_container: VBoxContainer = null
var _title_label: Label = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_style()
	_build_ui()


func setup(sim_manager: Node, build_panel: Node) -> void:
	_simulation_manager = sim_manager
	_building_panel = build_panel
	# Connect to discovery signals
	sim_manager.content_discovered.connect(_on_content_discovered)
	sim_manager.state_discovered.connect(_on_state_discovered)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			visible = not visible
			if visible:
				_refresh_info()
			get_viewport().set_input_as_handled()


func _on_content_discovered(content: int) -> void:
	_check_unlocks()


func _on_state_discovered(state: int) -> void:
	_check_unlocks()


func _check_unlocks() -> void:
	if _simulation_manager == null:
		return
	var content_count: int = 0
	for cid in _simulation_manager.discovered_content:
		if _simulation_manager.discovered_content[cid]:
			content_count += 1

	for rule in _unlock_rules:
		if _unlocked.get(rule.name, false):
			continue
		var should_unlock: bool = false
		match rule.trigger:
			"content_count":
				should_unlock = content_count >= rule.value
			"content":
				should_unlock = _simulation_manager.discovered_content.get(rule.value, false)
			"state":
				should_unlock = _simulation_manager.discovered_states.get(rule.value, false)
		if should_unlock:
			_unlocked[rule.name] = true
			building_unlocked.emit(rule.name)
			print("[Keşif] %s açıldı!" % rule.name)
			if _building_panel and _building_panel.has_method("refresh_buttons"):
				_building_panel.refresh_buttons()
	if visible:
		_refresh_info()


func is_building_unlocked(building_name: String) -> bool:
	for rule in _unlock_rules:
		if rule.name == building_name:
			return _unlocked.get(building_name, false)
	# Not in unlock rules = always available (base buildings)
	return true


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
	_title_label.text = "// KEŞİF DURUMU [T]"
	_title_label.add_theme_color_override("font_color", BORDER_COLOR)
	_title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_title_label)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	_info_container = VBoxContainer.new()
	_info_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_info_container)


func _refresh_info() -> void:
	for child in _info_container.get_children():
		child.queue_free()

	for rule in _unlock_rules:
		var is_unlocked: bool = _unlocked.get(rule.name, false)
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.custom_minimum_size.x = 250

		if is_unlocked:
			label.text = "[color=#44ff88]● %s[/color]  [color=#667788]AÇILDI[/color]" % rule.name
		else:
			label.text = "[color=#ff8844]○ %s[/color]  [color=#667788]%s[/color]" % [rule.name, rule.desc]
		_info_container.add_child(label)


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
