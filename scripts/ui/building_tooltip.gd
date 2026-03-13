extends PanelContainer

const BG_COLOR := Color(0.04, 0.06, 0.09, 0.93)
const BORDER_COLOR := Color(0.13, 0.67, 0.87, 0.5)
const OFFSET := Vector2(16, 16)

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var info_label: Label = $MarginContainer/VBoxContainer/InfoLabel
@onready var stats_label: RichTextLabel = $MarginContainer/VBoxContainer/StatsLabel

var _target_building: Node2D = null
var _target_source: Node2D = null

var _slide_offset := Vector2.ZERO
var _anim_tween: Tween = null


func _ready() -> void:
	visible = false
	modulate = Color(1, 1, 1, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_style()


func _show_animated() -> void:
	if visible and modulate.a > 0.9: return
	visible = true
	if _anim_tween: _anim_tween.kill()
	if modulate.a == 0.0:
		_slide_offset = Vector2(0, 15)
	_anim_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	_anim_tween.tween_property(self, "_slide_offset", Vector2.ZERO, 0.2)


func show_for_building(building: Node2D) -> void:
	_target_source = null
	_target_building = building
	var def: BuildingDefinition = building.definition
	if def == null:
		hide_tooltip()
		return

	name_label.text = def.building_name
	name_label.add_theme_color_override("font_color", def.color)
	desc_label.text = def.description
	info_label.text = def.category.to_upper()
	_update_stats()
	_show_animated()


func show_for_source(source: Node2D) -> void:
	_target_building = null
	_target_source = source
	var def = source.definition
	if def == null:
		hide_tooltip()
		return

	name_label.text = def.source_name
	name_label.add_theme_color_override("font_color", def.color)
	desc_label.text = def.description
	info_label.text = "DATA SOURCE | %d MB/s" % int(def.bandwidth)
	_update_source_stats()
	_show_animated()


func hide_tooltip() -> void:
	_target_building = null
	_target_source = null
	if not visible: return
	if _anim_tween: _anim_tween.kill()
	_anim_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_anim_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.15)
	_anim_tween.tween_callback(func(): visible = false)


func _process(_delta: float) -> void:
	if not visible:
		return

	# Live update stats while visible
	if _target_building != null:
		_update_stats()
	elif _target_source != null:
		_update_source_stats()

	var mouse_pos := get_viewport().get_mouse_position()
	var viewport_size := get_viewport_rect().size
	var tip_size := size
	var pos := mouse_pos + OFFSET

	if pos.x + tip_size.x > viewport_size.x:
		pos.x = mouse_pos.x - tip_size.x - 8
	if pos.y + tip_size.y > viewport_size.y:
		pos.y = mouse_pos.y - tip_size.y - 8

	global_position = pos + _slide_offset


func _update_stats() -> void:
	if _target_building == null or _target_building.definition == null:
		stats_label.text = ""
		return

	var b: Node2D = _target_building
	var def: BuildingDefinition = b.definition
	var lines: PackedStringArray = []

	# Work status
	if b.is_working:
		lines.append(_stat("Status", "[color=#44ff88]● Working[/color]"))
	else:
		var reason: String = b.status_reason
		if reason != "":
			lines.append(_stat("Status", "[color=#ffcc44]● Idle — %s[/color]" % reason))
		else:
			lines.append(_stat("Status", "[color=#ffcc44]● Idle[/color]"))

	# Type-specific stats (component-based)
	if def.classifier:
		lines.append(_stat("Throughput", "%d MB/s" % int(b.get_effective_value("processing_rate"))))
		var filter_name: String = DataEnums.content_name(b.classifier_filter_content)
		lines.append(_stat("Right Port →", "[color=#44ff88]%s[/color]" % filter_name))
		lines.append(_stat("Bottom Port →", "All other content"))
	if def.producer:
		lines.append(_stat("Processing", "%d production/tick" % int(b.get_effective_value("processing_rate"))))
		var tier_names: Array[String] = ["T1 Key", "T2 Strong Key", "T3 Master Key"]
		var tier_label: String = tier_names[b.selected_tier - 1] if b.selected_tier <= tier_names.size() else "T%d Key" % b.selected_tier
		lines.append(_stat("Mode", "[color=#ffaa00]%s[/color]" % tier_label))
		var recipe: String = "[color=#aa77ff]%d MB Research[/color]" % def.producer.consume_amount
		if b.selected_tier >= 2 and def.producer.tier2_extra_content >= 0:
			recipe += " + [color=#ffcc00]%d MB %s[/color]" % [def.producer.tier2_extra_amount, DataEnums.content_name(def.producer.tier2_extra_content)]
		if b.selected_tier >= 3 and def.producer.tier3_extra_content >= 0:
			recipe += " + [color=#ff33aa]%d MB %s[/color]" % [def.producer.tier3_extra_amount, DataEnums.content_name(def.producer.tier3_extra_content)]
		lines.append(_stat("Recipe", recipe))
		# Tier cycle hint removed — taught in tutorial
		var research_key: String = DataEnums.make_key(def.producer.input_content, def.producer.input_state)
		var stored_research: int = b.stored_data.get(research_key, 0)
		if stored_research > 0:
			lines.append(_stat("Stock", "%d MB Research waiting" % stored_research))
	if def.dual_input:
		lines.append(_stat("Throughput", "%d MB/s" % int(b.get_effective_value("processing_rate"))))
		if def.dual_input.fuel_matches_content:
			# Recoverer
			lines.append(_stat("Left Port ←", "[color=#ff8844]Corrupted[/color] data"))
			var fuel_tags: Array[int] = def.dual_input.required_fuel_tags
			if fuel_tags.size() >= 3:
				lines.append(_stat("Top Port ←", "Fuel: [color=#44ff88]Public[/color] / [color=#44aaff]Decrypted[/color] / [color=#44aaff]Dec·Enc[/color]"))
			else:
				lines.append(_stat("Top Port ←", "Same-type [color=#44ff88]Public[/color] data (fuel)"))
			lines.append(_stat("Output →", "[color=#44ff88]Recovered[/color] (content preserved)"))
		elif def.dual_input.output_tag == DataEnums.ProcessingTag.ENCRYPTED:
			# Encryptor
			lines.append(_stat("Left Port ←", "[color=#44ff88]Processed[/color] data"))
			lines.append(_stat("Top Port ←", "[color=#ffaa00]Key[/color] (from Research Lab)"))
			lines.append(_stat("Output →", "[color=#44aaff]Encrypted[/color] tag added"))
			lines.append(_stat("Key/packet", "%d" % def.dual_input.key_cost))
		else:
			# Decryptor
			lines.append(_stat("Left Port ←", "[color=#44aaff]Encrypted[/color] data"))
			lines.append(_stat("Top Port ←", "[color=#ffaa00]Key[/color] (tier must match data)"))
			lines.append(_stat("Output →", "[color=#44ff88]Decrypted[/color] (content preserved)"))
		# Show stored fuel/keys (per tier)
		if not def.dual_input.fuel_matches_content:
			var key_parts: PackedStringArray = []
			for kt in range(1, 4):
				var kk: String = DataEnums.make_key(def.dual_input.key_content, DataEnums.DataState.PUBLIC, kt, 0)
				var count: int = b.stored_data.get(kk, 0)
				if count > 0:
					key_parts.append("T%d:%d" % [kt, count])
			if key_parts.is_empty():
				lines.append(_stat("Key Stock", "[color=#ff6644]0 Key[/color]"))
			else:
				lines.append(_stat("Key Stock", "[color=#ffaa00]%s[/color]" % ", ".join(key_parts)))
	if def.compiler:
		lines.append(_stat("Processing", "%d craft/tick" % int(b.get_effective_value("processing_rate"))))
		lines.append(_stat("Left Port ←", "Data A (any type)"))
		lines.append(_stat("Top Port ←", "Data B (any type)"))
		lines.append(_stat("Output →", "[color=#66ffcc]Packet [A·B][/color]"))
		var total: int = b.get_total_stored()
		if total > 0:
			lines.append(_stat("Stock", _format_stored_data(b.stored_data)))
	if def.storage and def.processor == null and def.classifier == null and def.producer == null and def.dual_input == null and def.compiler == null:
		if def.storage.forward_rate > 0:
			lines.append(_stat("Transfer", "%d MB/s" % int(def.storage.forward_rate)))
	if def.processor:
		lines.append(_stat("Throughput", "%d MB/s" % int(b.get_effective_value("processing_rate"))))
		if def.processor.rule == "separator":
			var filter_name: String
			if b.separator_mode == "content":
				filter_name = DataEnums.content_name(b.separator_filter_value)
			else:
				filter_name = DataEnums.state_name(b.separator_filter_value)
			lines.append(_stat("Right Port →", "[color=#44ff88]%s[/color]" % filter_name))
			lines.append(_stat("Bottom Port →", "All other data"))
		elif def.processor.rule == "trash":
			lines.append(_stat("Input", "All data types"))
			lines.append(_stat("Mode", "Instant destruction"))
		elif def.processor.rule == "splitter":
			lines.append(_stat("Distribution", "Equal (50/50)"))
			lines.append(_stat("Ports", "→ Right, ↓ Bottom"))
		elif def.processor.rule == "merger":
			lines.append(_stat("Merging", "← Left + ↑ Top"))
			lines.append(_stat("Output", "→ Right"))
	# Upgrade info
	if def.upgrade:
		var upg: UpgradeComponent = def.upgrade
		var lvl: int = b.upgrade_level
		if lvl >= upg.max_level:
			lines.append(_stat("Level", "[color=#44ff88]%d/%d (MAX)[/color]" % [lvl, upg.max_level]))
		else:
			lines.append(_stat("Level", "%d/%d" % [lvl, upg.max_level]))

	# Malware warning (non-quarantine buildings holding malware)
	var malware_amount: int = b.get_malware_amount()
	if malware_amount > 0 and not (def.processor and def.processor.rule == "trash"):
		lines.append(_stat("Malware", "[color=#ff4466]%d MB — Route to Trash![/color]" % malware_amount))

	stats_label.text = "\n".join(lines)


func _stat(label: String, value: String) -> String:
	return "[color=#667788]%s:[/color]  %s" % [label, value]


func _format_content_weights(weights: Dictionary) -> String:
	var parts: PackedStringArray = []
	for content_id in weights:
		var pct: int = int(weights[content_id] * 100)
		var c: int = int(content_id)
		var color: String = DataEnums.content_color_hex(c)
		parts.append("[color=%s]%d%% %s[/color]" % [color, pct, DataEnums.content_name(c)])
	return ", ".join(parts)


func _format_state_weights(weights: Dictionary) -> String:
	var parts: PackedStringArray = []
	for state_id in weights:
		var pct: int = int(weights[state_id] * 100)
		var s: int = int(state_id)
		var color: String = DataEnums.state_color_hex(s)
		parts.append("[color=%s]%d%% %s[/color]" % [color, pct, DataEnums.state_name(s)])
	return ", ".join(parts)



func _format_stored_data(data: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in data:
		if data[key] <= 0:
			continue
		if DataEnums.is_packet(key):
			parts.append("[color=#66ffcc]%d[/color] %s" % [data[key], DataEnums.packet_label(key)])
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		var c_color: String = DataEnums.content_color_hex(parsed.content)
		var s_color: String = DataEnums.state_color_hex(parsed.state)
		var label: String = DataEnums.data_label(parsed.content, parsed.state, parsed.tier, parsed.tags)
		parts.append("[color=%s]%d[/color] [color=%s]%s[/color]" % [
			s_color, data[key], c_color, label
		])
	if parts.is_empty():
		return "Empty"
	return ", ".join(parts)


func _update_source_stats() -> void:
	if _target_source == null or _target_source.definition == null:
		stats_label.text = ""
		return
	var def = _target_source.definition
	var lines: PackedStringArray = []
	# Difficulty info
	var diff_labels: Dictionary = {"easy": "EASY", "medium": "MEDIUM", "hard": "HARD", "endgame": "ENDGAME"}
	var diff_colors: Dictionary = {"easy": "#44ff66", "medium": "#ffee44", "hard": "#ff9933", "endgame": "#ff4444"}
	var diff_label: String = diff_labels.get(def.difficulty, "???")
	var diff_color: String = diff_colors.get(def.difficulty, "#aabbcc")
	lines.append(_stat("Difficulty", "[color=%s]%s[/color]" % [diff_color, diff_label]))
	lines.append(_stat("Bandwidth", "%d MB/s" % int(def.bandwidth)))
	if not def.content_weights.is_empty():
		lines.append(_stat("Content", _format_content_weights(def.content_weights)))
	if not def.state_weights.is_empty():
		lines.append(_stat("State", _format_state_weights(def.state_weights)))
	# Show tier info for encrypted/corrupted
	if def.encrypted_max_tier > 0 and def.state_weights.has(DataEnums.DataState.ENCRYPTED):
		lines.append(_stat("Encrypted Tier", "[color=#44aaff]T1%s[/color]" % ("-T%d" % def.encrypted_max_tier if def.encrypted_max_tier > 1 else "")))
	if def.corrupted_max_tier > 0 and def.state_weights.has(DataEnums.DataState.CORRUPTED):
		lines.append(_stat("Corrupted Tier", "[color=#ff8844]T1%s[/color]" % ("-T%d" % def.corrupted_max_tier if def.corrupted_max_tier > 1 else "")))
	# Port info
	var port_count: int = _target_source.output_ports.size()
	lines.append(_stat("Output Ports", "[color=#44ff88]%d[/color]" % port_count))
	lines.append(_stat("Rate/Port", "%d MB/tick" % int(def.generation_rate)))
	stats_label.text = "\n".join(lines)


func _setup_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0, 0.5, 0.7, 0.1)
	style.shadow_size = 4
	add_theme_stylebox_override("panel", style)
