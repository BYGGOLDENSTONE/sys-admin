extends PanelContainer

const BG_COLOR := Color("#0d1117")
const BORDER_COLOR := Color("#00ccff")
const OFFSET := Vector2(16, 16)

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var info_label: Label = $MarginContainer/VBoxContainer/InfoLabel
@onready var stats_label: RichTextLabel = $MarginContainer/VBoxContainer/StatsLabel

var _target_building: Node2D = null
var _target_source: Node2D = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_style()


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
	visible = true


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
	info_label.text = "VERİ KAYNAĞI | %d MB/s" % int(def.bandwidth)
	_update_source_stats()
	visible = true


func hide_tooltip() -> void:
	_target_building = null
	_target_source = null
	visible = false


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

	global_position = pos


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
		lines.append(_stat("Akış", "%d MB/s" % int(def.generator.generation_rate)))
		# Show source info if linked, otherwise show default weights
		if b.linked_source != null:
			var src_def = b.linked_source.definition
			lines.append(_stat("Kaynak", "[color=%s]%s[/color]" % [src_def.color.to_html(), src_def.source_name]))
			lines.append(_stat("Content", _format_content_weights(b.runtime_content_weights)))
			lines.append(_stat("State", _format_state_weights(b.runtime_state_weights)))
		else:
			if not def.generator.content_weights.is_empty():
				lines.append(_stat("Content", _format_content_weights(def.generator.content_weights)))
			if not def.generator.state_weights.is_empty():
				lines.append(_stat("State", _format_state_weights(def.generator.state_weights)))
			lines.append(_stat("Kaynak", "[color=#ff8844]Bağlı değil — kaynağın yanına yerleştir[/color]"))
	if def.storage and def.processor == null:
		var total: int = b.get_total_stored()
		var cap: int = int(b.get_effective_value("capacity"))
		var pct: int = int(float(total) / float(cap) * 100.0) if cap > 0 else 0
		var fill_color: String = "#ff6644" if pct >= 90 else "#ffcc44" if pct >= 70 else "#44ff88"
		lines.append(_stat("Doluluk", "[color=%s]%d / %d MB (%d%%)[/color]" % [fill_color, total, cap, pct]))
		if total > 0:
			lines.append(_stat("İçerik", _format_stored_data(b.stored_data)))
		if def.storage.forward_rate > 0:
			lines.append(_stat("İletim", "%d MB/s" % int(def.storage.forward_rate)))
	if def.seller:
		lines.append(_stat("Satış", "%d MB/s (Clean)" % int(def.seller.sell_rate)))
		lines.append(_stat("Baz Fiyat", "%.1f CR/MB" % def.seller.credits_per_mb))
		if not def.seller.content_price_multipliers.is_empty():
			lines.append(_stat("Fiyatlar", _format_price_multipliers(def.seller)))
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
		elif def.processor.rule == "compressor":
			lines.append(_stat("Sıkıştırma", "%d%% çıktı" % int(b.get_effective_value("efficiency") * 100)))
		elif def.processor.rule == "decryptor":
			lines.append(_stat("Giriş", "[color=#44aaff]Encrypted[/color]"))
			lines.append(_stat("Çıkış", "[color=#44ff88]Clean[/color] (content korunur)"))
		elif def.processor.rule == "recoverer":
			lines.append(_stat("Giriş", "[color=#ff8844]Corrupted[/color]"))
			lines.append(_stat("Çıkış", "[color=#44ff88]Clean[/color] (content korunur)"))
		elif def.processor.rule == "quarantine":
			lines.append(_stat("Giriş", "[color=#ff4466]Malware[/color]"))
			lines.append(_stat("Çıkış", "[color=#44ff88]Güvenli İmha[/color]"))
		elif def.processor.rule == "splitter":
			lines.append(_stat("Dağılım", "Eşit (%50/%50)"))
			lines.append(_stat("Portlar", "→ Right, ↓ Bottom"))
		elif def.processor.rule == "merger":
			lines.append(_stat("Birleştirme", "← Left + ↑ Top"))
			lines.append(_stat("Çıkış", "→ Right"))
	if def.research_collector:
		var rc: ResearchCollectorComponent = def.research_collector
		lines.append(_stat("Toplama", "%d MB/s" % int(rc.collection_rate)))
		lines.append(_stat("Kazanım", "%.1f RP/MB" % rc.research_per_mb))
		lines.append(_stat("Kabul", "Research(Clean)"))

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


func _format_price_multipliers(sell: SellerComponent) -> String:
	var parts: PackedStringArray = []
	# Sort by multiplier descending for readability
	var sorted_keys: Array = sell.content_price_multipliers.keys()
	sorted_keys.sort_custom(func(a, b): return sell.content_price_multipliers[a] > sell.content_price_multipliers[b])
	for content_id in sorted_keys:
		var mult: float = sell.content_price_multipliers[content_id]
		var c: int = int(content_id)
		var color: String = DataEnums.content_color_hex(c)
		parts.append("[color=%s]%s(%.0fx)[/color]" % [color, DataEnums.content_name(c), mult])
	return ", ".join(parts)


func _update_source_stats() -> void:
	if _target_source == null or _target_source.definition == null:
		stats_label.text = ""
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
