extends PanelContainer

const BG_COLOR := Color(0.05, 0.07, 0.09, 0.85)
const BORDER_COLOR := Color(0.0, 0.8, 1.0, 0.6)
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
	info_label.text = "%s | %d CR" % [def.category.to_upper(), def.base_cost]
	_update_stats()
	_show_animated()


func show_for_source(source: Node2D) -> void:
	_target_building = null
	_target_source = source
	var def = source.definition
	if def == null:
		hide_tooltip()
		return

	# Hidden source — limited info
	if not source.discovered and not source.dev_mode:
		name_label.text = "Bilinmeyen Sinyal"
		name_label.add_theme_color_override("font_color", Color(def.color, 0.6))
		desc_label.text = "Yaklaşarak keşfet"
		info_label.text = "??? | ??? MB/s"
		stats_label.text = ""
		_show_animated()
		return

	name_label.text = def.source_name
	name_label.add_theme_color_override("font_color", def.color)
	desc_label.text = def.description
	info_label.text = "VERİ KAYNAĞI | %d MB/s" % int(def.bandwidth)
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
		lines.append(_stat("Durum", "[color=#44ff88]● Çalışıyor[/color]"))
	else:
		lines.append(_stat("Durum", "[color=#ffcc44]● Boşta[/color]"))

	# Type-specific stats (component-based)
	if def.generator:
		if b.linked_source != null:
			var src_def = b.linked_source.definition
			lines.append(_stat("Kaynak", "[color=%s]%s[/color]" % [src_def.color.to_html(), src_def.source_name]))
			lines.append(_stat("Akış", "%d MB/s" % int(def.generator.generation_rate)))
			lines.append(_stat("Content", _format_content_weights(b.runtime_content_weights)))
			lines.append(_stat("State", _format_state_weights(b.runtime_state_weights)))
		else:
			lines.append(_stat("Kaynak", "[color=#ff8844]Bağlı değil — kaynağın yanına yerleştir[/color]"))
	if def.classifier:
		lines.append(_stat("İşleme", "%d MB/s" % int(def.classifier.throughput_rate)))
		lines.append(_stat("Mod", "Content türüne göre ayırma"))
		lines.append(_stat("Çıkışlar", "Her content türü → ayrı port"))
	if def.probabilistic:
		lines.append(_stat("İşleme", "%d MB/s" % int(b.get_effective_value("processing_rate"))))
		lines.append(_stat("Başarı", "%%%d" % int(b.get_effective_value("success_rate") * 100)))
		lines.append(_stat("Giriş", "[color=#ff8844]Corrupted[/color]"))
		lines.append(_stat("Sağ Port →", "[color=#44ff88]Clean[/color] (kurtarılan)"))
		lines.append(_stat("Alt Port  →", "[color=#888844]Residue[/color] (dijital atık)"))
	if def.producer:
		lines.append(_stat("İşleme", "%d üretim/tick" % int(b.get_effective_value("processing_rate"))))
		lines.append(_stat("Girdi", "[color=#aa88ff]%d MB Research(Clean)[/color] → 1 Key" % def.producer.consume_amount))
		lines.append(_stat("Çıktı", "[color=#ffaa00]Decryption Key[/color]"))
		# Show stored research and keys produced
		var research_key: String = DataEnums.make_key(def.producer.input_content, def.producer.input_state)
		var stored_research: int = b.stored_data.get(research_key, 0)
		if stored_research > 0:
			lines.append(_stat("Stok", "%d MB Research bekliyor" % stored_research))
	if def.dual_input:
		lines.append(_stat("İşleme", "%d MB/s" % int(b.get_effective_value("processing_rate"))))
		lines.append(_stat("Sol Port ←", "[color=#44aaff]Encrypted[/color] veri"))
		lines.append(_stat("Üst Port ←", "[color=#ffaa00]Key[/color] (Research Lab'dan)"))
		lines.append(_stat("Çıkış →", "[color=#44ff88]Clean[/color] (content korunur)"))
		lines.append(_stat("Key/paket", "%d" % def.dual_input.key_cost))
		# Show stored keys
		var key_key: String = DataEnums.make_key(def.dual_input.key_content, DataEnums.DataState.CLEAN)
		var stored_keys: int = b.stored_data.get(key_key, 0)
		var key_color: String = "#ff6644" if stored_keys <= 0 else "#ffaa00"
		lines.append(_stat("Key Stok", "[color=%s]%d Key[/color]" % [key_color, stored_keys]))
	if def.compiler:
		lines.append(_stat("İşleme", "%d craft/tick" % int(b.get_effective_value("processing_rate"))))
		lines.append(_stat("Sol Port ←", "Clean veri (Tür A)"))
		lines.append(_stat("Üst Port ←", "Clean veri (Tür B)"))
		lines.append(_stat("Çıkış →", "[color=#66ffcc]Refined Malzeme[/color]"))
		# Show matched recipe if inputs present
		var matched_recipe: String = _get_matched_recipe(b)
		if matched_recipe != "":
			lines.append(_stat("Tarif", matched_recipe))
		# Show stored data
		var total: int = b.get_total_stored_raw()
		if total > 0:
			lines.append(_stat("Stok", _format_stored_data(b.stored_data)))
	if def.storage and def.processor == null and def.classifier == null and def.probabilistic == null and def.producer == null and def.dual_input == null and def.compiler == null:
		var total: int = b.get_total_stored()
		var cap: int = int(b.get_effective_value("capacity"))
		var pct: int = int(float(total) / float(cap) * 100.0) if cap > 0 else 0
		var fill_color: String = "#ff6644" if pct >= 90 else "#ffcc44" if pct >= 70 else "#44ff88"
		lines.append(_stat("Doluluk", "[color=%s]%d / %d MB (%d%%)[/color]" % [fill_color, total, cap, pct]))
		if total > 0:
			lines.append(_stat("İçerik", _format_stored_data(b.stored_data)))
		if def.storage.forward_rate > 0:
			lines.append(_stat("İletim", "%d MB/s" % int(def.storage.forward_rate)))
		# Show refined materials in storage
		if not b.stored_refined.is_empty():
			var refined_parts: PackedStringArray = []
			for rtype in b.stored_refined:
				if b.stored_refined[rtype] <= 0:
					continue
				var color: String = DataEnums.refined_color_hex(int(rtype))
				refined_parts.append("[color=%s]%d %s[/color]" % [
					color, b.stored_refined[rtype], DataEnums.refined_name(int(rtype))])
			if not refined_parts.is_empty():
				lines.append(_stat("Refined", ", ".join(refined_parts)))
	if def.processor:
		lines.append(_stat("İşleme", "%d MB/s" % int(b.get_effective_value("processing_rate"))))
		lines.append(_stat("Verimlilik", "%d%%" % int(b.get_effective_value("efficiency") * 100)))
		if def.processor.rule == "separator":
			var mode_name: String = "State" if def.processor.separator_mode == "state" else "Content"
			var filter_name: String
			if b.separator_mode == "content":
				filter_name = DataEnums.content_name(b.separator_filter_value)
			else:
				filter_name = DataEnums.state_name(b.separator_filter_value)
			lines.append(_stat("Mod", mode_name))
			lines.append(_stat("Sağ Port →", "[color=#44ff88]%s[/color]" % filter_name))
			lines.append(_stat("Alt Port  →", "Diğer tüm veriler"))
		elif def.processor.rule == "quarantine":
			lines.append(_stat("Giriş", "[color=#ff4466]Malware[/color]"))
			lines.append(_stat("Çıkış", "[color=#44ff88]Güvenli İmha[/color]"))
		elif def.processor.rule == "splitter":
			lines.append(_stat("Dağılım", "Eşit (%50/%50)"))
			lines.append(_stat("Portlar", "→ Right, ↓ Bottom"))
		elif def.processor.rule == "merger":
			lines.append(_stat("Birleştirme", "← Left + ↑ Top"))
			lines.append(_stat("Çıkış", "→ Right"))
	# Upgrade info
	if def.upgrade:
		var upg: UpgradeComponent = def.upgrade
		var lvl: int = b.upgrade_level
		if lvl >= upg.max_level:
			lines.append(_stat("Seviye", "[color=#44ff88]%d/%d (MAX)[/color]" % [lvl, upg.max_level]))
		else:
			lines.append(_stat("Seviye", "%d/%d" % [lvl, upg.max_level]))

	# Malware warning (non-quarantine buildings holding malware)
	var malware_amount: int = b.get_malware_amount()
	if malware_amount > 0 and not (def.processor and def.processor.rule == "quarantine"):
		lines.append(_stat("Malware", "[color=#ff4466]%d MB — Quarantine'e yönlendir![/color]" % malware_amount))

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


func _get_matched_recipe(b: Node2D) -> String:
	if b.definition.compiler == null:
		return ""
	var available_contents: Dictionary = {}
	for key in b.stored_data:
		if b.stored_data[key] <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		if parsed.state == DataEnums.DataState.CLEAN:
			available_contents[parsed.content] = true
	for recipe in b.definition.compiler.recipes:
		if available_contents.has(recipe.input_a_content) and available_contents.has(recipe.input_b_content):
			var color: String = DataEnums.refined_color_hex(recipe.output_refined)
			return "[color=%s]%s[/color] (%s + %s)" % [
				color, DataEnums.refined_name(recipe.output_refined),
				DataEnums.content_name(recipe.input_a_content),
				DataEnums.content_name(recipe.input_b_content)]
	return "[color=#667788]Eşleşen tarif yok[/color]"


func _format_stored_data(data: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in data:
		if data[key] <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		var c_color: String = DataEnums.content_color_hex(parsed.content)
		var s_color: String = DataEnums.state_color_hex(parsed.state)
		parts.append("[color=%s]%d[/color] [color=%s]%s[/color]([color=%s]%s[/color])" % [
			s_color, data[key],
			c_color, DataEnums.content_name(parsed.content),
			s_color, DataEnums.state_name(parsed.state)
		])
	if parts.is_empty():
		return "Boş"
	return ", ".join(parts)


func _update_source_stats() -> void:
	if _target_source == null or _target_source.definition == null:
		stats_label.text = ""
		return
	# Hidden source — no stats update
	if not _target_source.discovered and not _target_source.dev_mode:
		return
	var def = _target_source.definition
	var lines: PackedStringArray = []
	# Zone/ring info
	if def.ring_index >= 0:
		var ring_labels: Array = ["KOLAY", "ORTA", "ZOR", "ENDGAME"]
		var ring_colors: Array = ["#44ff66", "#ffee44", "#ff9933", "#ff4444"]
		var idx: int = clampi(def.ring_index, 0, 3)
		lines.append(_stat("Bölge", "[color=%s]Ring %d — %s[/color]" % [ring_colors[idx], idx, ring_labels[idx]]))
	lines.append(_stat("Bant Genişliği", "%d MB/s" % int(def.bandwidth)))
	if not def.content_weights.is_empty():
		lines.append(_stat("Content", _format_content_weights(def.content_weights)))
	if not def.state_weights.is_empty():
		lines.append(_stat("State", _format_state_weights(def.state_weights)))
	var linked: int = _target_source._linked_uplinks
	if linked > 0:
		lines.append(_stat("Bağlı Uplink", "[color=#44ff88]%d[/color]" % linked))
	else:
		lines.append(_stat("Bağlı Uplink", "[color=#ff8844]0 — Uplink yerleştir[/color]"))
	stats_label.text = "\n".join(lines)


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
