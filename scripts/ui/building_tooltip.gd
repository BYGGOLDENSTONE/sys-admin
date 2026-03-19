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
var upgrade_manager: Node = null  ## Set from main.gd for CT upgrade display

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
	reset_size()
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
	reset_size()
	_show_animated()


func hide_tooltip() -> void:
	_target_building = null
	_target_source = null
	if not visible: return
	if _anim_tween: _anim_tween.kill()
	_anim_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_anim_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.15)
	_anim_tween.tween_callback(func(): visible = false)


func refresh() -> void:
	if _target_building != null:
		_update_stats()
		reset_size()
	elif _target_source != null:
		_update_source_stats()
		reset_size()


func _process(_delta: float) -> void:
	if not visible:
		return

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
		var variety: int = _count_stored_variety(b, "content")
		var base: float = def.classifier.base_throughput
		var effective: int = maxi(1, int(base / float(maxi(variety, 1))))
		var variety_color: String = "#44ff88" if variety <= 1 else ("#ffcc44" if variety <= 3 else "#ff6644")
		lines.append(_stat("Throughput", "[color=%s]%d MB/s[/color] (variety: %d)" % [variety_color, effective, variety]))
		var filter_name: String = DataEnums.content_name(b.classifier_filter_content)
		lines.append(_stat("Right Port →", "[color=#44ff88]%s[/color]" % filter_name))
		lines.append(_stat("Bottom Port →", "All other content"))
	if def.scanner:
		var variety: int = _count_stored_variety(b, "sub_type")
		var base: float = def.scanner.base_throughput
		var effective: int = maxi(1, int(base / float(maxi(variety, 1))))
		var variety_color: String = "#44ff88" if variety <= 1 else ("#ffcc44" if variety <= 3 else "#ff6644")
		lines.append(_stat("Throughput", "[color=%s]%d MB/s[/color] (variety: %d)" % [variety_color, effective, variety]))
		if b.scanner_filter_sub_type >= 0:
			var sc: int = b.scanner_filter_sub_type / 4
			var so: int = b.scanner_filter_sub_type % 4
			var st_name: String = DataEnums.sub_type_name(sc, so)
			var sc_color: String = DataEnums.content_color_hex(sc)
			lines.append(_stat("Right Port →", "[color=%s]%s[/color]" % [sc_color, st_name]))
		else:
			lines.append(_stat("Right Port →", "[color=#ffcc44]No filter (Tab)[/color]"))
		lines.append(_stat("Bottom Port →", "All other sub-types"))
	if def.producer:
		lines.append(_stat("Processing", "%d production/tick" % int(b.get_effective_value("processing_rate"))))
		var output_name: String = DataEnums.content_name(def.producer.output_content)
		var output_color: String = DataEnums.content_color_hex(def.producer.output_content)
		var tier_state: int = DataEnums.DataState.ENCRYPTED if def.producer.output_content == DataEnums.ContentType.KEY else DataEnums.DataState.CORRUPTED
		var tier_str: String = DataEnums.tier_name(b.selected_tier, tier_state)
		if tier_str.is_empty():
			tier_str = "T%d" % b.selected_tier
		var tier_label: String = "[color=%s]%s %s[/color]" % [output_color, tier_str, output_name]
		lines.append(_stat("Mode", tier_label))
		var input_name: String = DataEnums.content_name(def.producer.input_content)
		var input_color: String = DataEnums.content_color_hex(def.producer.input_content)
		var recipe: String = "[color=%s]%d MB %s[/color]" % [input_color, def.producer.consume_amount, input_name]
		if b.selected_tier >= 2 and def.producer.tier2_extra_content >= 0:
			var c2_color: String = DataEnums.content_color_hex(def.producer.tier2_extra_content)
			recipe += " + [color=%s]%d MB %s[/color]" % [c2_color, def.producer.tier2_extra_amount, DataEnums.content_name(def.producer.tier2_extra_content)]
		if b.selected_tier >= 3 and def.producer.tier3_extra_content >= 0:
			var c3_color: String = DataEnums.content_color_hex(def.producer.tier3_extra_content)
			recipe += " + [color=%s]%d MB %s[/color]" % [c3_color, def.producer.tier3_extra_amount, DataEnums.content_name(def.producer.tier3_extra_content)]
		lines.append(_stat("Recipe", recipe))
		var input_key: int = DataEnums.pack_key(def.producer.input_content, def.producer.input_state)
		var stored_input: int = b.stored_data.get(input_key, 0)
		if stored_input > 0:
			lines.append(_stat("Stock", "[color=%s]%d MB %s[/color] waiting" % [input_color, stored_input, input_name]))
	if def.dual_input:
		lines.append(_stat("Throughput", "%d MB/s" % int(b.get_effective_value("processing_rate"))))
		if def.dual_input.output_tag == DataEnums.ProcessingTag.RECOVERED:
			# Recoverer — uses Repair Kits
			lines.append(_stat("Left Port ←", "[color=#ff8844]Corrupted[/color] / [color=#88aa44]Enc·Cor[/color] data"))
			lines.append(_stat("Top Port ←", "[color=#ff7744]Repair Kit[/color] (from Repair Lab)"))
			lines.append(_stat("Output →", "[color=#44ff88]Recovered[/color] (content preserved)"))
			lines.append(_stat("Kit Cost", "%d per unit" % def.dual_input.key_cost))
		elif def.dual_input.output_tag == DataEnums.ProcessingTag.ENCRYPTED:
			# Encryptor
			lines.append(_stat("Left Port ←", "[color=#44ff88]Processed[/color] data"))
			lines.append(_stat("Top Port ←", "[color=#ffaa00]Key[/color] (from Key Forge)"))
			lines.append(_stat("Output →", "[color=#44aaff]Encrypted[/color] tag added"))
			lines.append(_stat("Key Cost", "%d" % def.dual_input.key_cost))
		else:
			# Decryptor
			lines.append(_stat("Left Port ←", "[color=#44aaff]Encrypted[/color] / [color=#88aa44]Enc·Cor[/color] data"))
			lines.append(_stat("Top Port ←", "[color=#ffaa00]Key[/color] (tier must match data)"))
			lines.append(_stat("Output →", "[color=#44ff88]Decrypted[/color] (content preserved)"))
		# Show stored keys/kits (per tier)
		var consumable_name: String = DataEnums.content_name(def.dual_input.key_content)
		var consumable_color: String = DataEnums.content_color_hex(def.dual_input.key_content)
		var key_parts: PackedStringArray = []
		for kt in range(1, 4):
			var kk: int = DataEnums.pack_key(def.dual_input.key_content, DataEnums.DataState.PUBLIC, kt, 0)
			var count: int = b.stored_data.get(kk, 0)
			if count > 0:
				key_parts.append("T%d:%d" % [kt, count])
		if key_parts.is_empty():
			lines.append(_stat("%s Stock" % consumable_name, "[color=#ff6644]0[/color]"))
		else:
			lines.append(_stat("%s Stock" % consumable_name, "[color=%s]%s[/color]" % [consumable_color, ", ".join(key_parts)]))
	if def.storage and def.processor == null and def.classifier == null and def.producer == null and def.dual_input == null:
		if def.storage.forward_rate > 0:
			lines.append(_stat("Transfer", "%d MB/s" % int(def.storage.forward_rate)))
	if def.processor:
		if def.processor.rule == "separator":
			var variety: int = _count_stored_variety(b, "state")
			var base: float = def.processor.base_throughput
			var effective: int = maxi(1, int(base / float(maxi(variety, 1))))
			var variety_color: String = "#44ff88" if variety <= 1 else ("#ffcc44" if variety <= 2 else "#ff6644")
			lines.append(_stat("Throughput", "[color=%s]%d MB/s[/color] (variety: %d)" % [variety_color, effective, variety]))
			var filter_name: String
			if b.separator_mode == "content":
				filter_name = DataEnums.content_name(b.separator_filter_value)
			else:
				filter_name = DataEnums.state_name(b.separator_filter_value)
			lines.append(_stat("Right Port →", "[color=#44ff88]%s[/color]" % filter_name))
			lines.append(_stat("Bottom Port →", "All other data"))
		else:
			lines.append(_stat("Throughput", "%d MB/s" % int(b.get_effective_value("processing_rate"))))
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

	# Malware warning (non-Trash buildings holding malware)
	var malware_amount: int = b.get_malware_amount()
	if malware_amount > 0 and not (def.processor and def.processor.rule == "trash"):
		lines.append(_stat("Malware", "[color=#ff4466]%d MB — Route to Trash![/color]" % malware_amount))

	# CT Upgrade status
	if def.category == "terminal" and upgrade_manager:
		lines.append("")
		lines.append("[color=#44ccff]── UPGRADES ──[/color]")
		for cat in ["routing", "decryption", "recovery", "bandwidth"]:
			var tier: int = upgrade_manager.get_tier(cat)
			var mult: float = upgrade_manager.get_multiplier(cat)
			var cum: float = upgrade_manager.get_cumulative(cat)
			var next_cost: float = upgrade_manager.get_next_tier_cost(cat)
			var cat_label: String = cat.capitalize()
			var progress_str: String
			if next_cost < 0:
				progress_str = "[color=#44ff88]MAX[/color]"
			else:
				progress_str = "%d/%d MB" % [int(cum), int(next_cost)]
			lines.append(_stat(cat_label, "T%d (%.0fx) — %s" % [tier, mult, progress_str]))

	stats_label.text = "\n".join(lines)


func _count_stored_variety(b: Node2D, mode: String) -> int:
	## Count unique types in building's stored_data for throughput display.
	var types: Dictionary = {}
	for key in b.stored_data:
		if b.stored_data[key] <= 0:
			continue
		match mode:
			"content":
				types[DataEnums.unpack_content(key)] = true
			"state":
				types[DataEnums.unpack_state(key)] = true
			"sub_type":
				var c: int = DataEnums.unpack_content(key)
				var st: int = DataEnums.unpack_sub_type(key)
				types[c * 4 + st] = true
	return maxi(types.size(), 1)


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
		var c: int = DataEnums.unpack_content(key)
		var s: int = DataEnums.unpack_state(key)
		var c_color: String = DataEnums.content_color_hex(c)
		var label: String = DataEnums.data_label(c, s, DataEnums.unpack_tier(key), DataEnums.unpack_tags(key))
		var st: int = DataEnums.unpack_sub_type(key)
		var st_name: String = DataEnums.sub_type_name(c, st)
		if st_name != "":
			label = st_name + " " + label.substr(label.find(" ") + 1)  ## Replace content name with sub-type name
		var s_color: String = DataEnums.state_color_hex(s)
		parts.append("[color=%s]%d[/color] [color=%s]%s[/color]" % [
			s_color, data[key], c_color, label])
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
	var sw: Dictionary = _target_source.instance_state_weights if not _target_source.instance_state_weights.is_empty() else def.state_weights
	if not sw.is_empty():
		lines.append(_stat("State", _format_state_weights(sw)))
	# Show tier info for encrypted/corrupted
	if def.encrypted_tier > 0 and sw.has(DataEnums.DataState.ENCRYPTED):
		lines.append(_stat("Encrypted", "[color=#44aaff]%s[/color]" % DataEnums.tier_name(def.encrypted_tier, DataEnums.DataState.ENCRYPTED)))
	if def.corrupted_tier > 0 and sw.has(DataEnums.DataState.CORRUPTED):
		lines.append(_stat("Corrupted", "[color=#ff8844]%s[/color]" % DataEnums.tier_name(def.corrupted_tier, DataEnums.DataState.CORRUPTED)))
	# Sub-type info
	if not def.sub_type_pool.is_empty():
		var st_parts: PackedStringArray = []
		for entry in def.sub_type_pool:
			var c: int = int(entry.get("content", 0))
			var st: int = int(entry.get("sub_type", 0))
			var st_name: String = DataEnums.sub_type_name(c, st)
			if st_name != "":
				var c_color: String = DataEnums.content_color_hex(c)
				st_parts.append("[color=%s]%s[/color]" % [c_color, st_name])
		if not st_parts.is_empty():
			lines.append(_stat("Data Types", ", ".join(st_parts)))
	# FIRE info
	if _target_source.has_fire():
		var fire_color: String = "#ff4422" if _target_source.fire_active else "#44ff66"
		var fire_status: String = "ACTIVE" if _target_source.fire_active else "BREACHED"
		var fire_type_label: String = "Threshold" if def.fire_type == "threshold" else "Regenerating"
		lines.append(_stat("FIRE", "[color=%s]%s[/color] (%s)" % [fire_color, fire_status, fire_type_label]))
		for req in def.fire_requirements:
			var st: int = int(req.sub_type)
			var content: int = st / 4
			var offset: int = st % 4
			var req_name: String = DataEnums.sub_type_name(content, offset)
			var c_color: String = DataEnums.content_color_hex(content)
			var cur: float = _target_source.fire_progress.get(st, 0.0)
			var needed: float = float(req.amount)
			lines.append(_stat("  Needs", "[color=%s]%s[/color] — %d/%d MB" % [c_color, req_name, int(cur), int(needed)]))
		if def.fire_type == "regen":
			lines.append(_stat("  Regen", "[color=#ff8844]%.0f MB/s[/color]" % def.fire_regen_rate))
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
