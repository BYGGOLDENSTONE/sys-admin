extends PanelContainer

const BG_COLOR := Color("#0d1117")
const BORDER_COLOR := Color("#00ccff")
const OFFSET := Vector2(16, 16)

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var info_label: Label = $MarginContainer/VBoxContainer/InfoLabel
@onready var stats_label: RichTextLabel = $MarginContainer/VBoxContainer/StatsLabel

var _target_building: Node2D = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_style()


func show_for_building(building: Node2D) -> void:
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


func hide_tooltip() -> void:
	_target_building = null
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return

	# Live update stats while visible
	if _target_building != null:
		_update_stats()

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

	# Power & work status (all buildings except power/coolant infrastructure)
	if not def.is_infrastructure():
		if not b.has_power:
			lines.append(_stat("Durum", "[color=#ff6644]● Güç Yok[/color]"))
		elif b.is_overheated:
			lines.append(_stat("Durum", "[color=#ff4422]● Aşırı Isı[/color]"))
		elif b.is_working:
			lines.append(_stat("Durum", "[color=#44ff88]● Çalışıyor[/color]"))
		else:
			lines.append(_stat("Durum", "[color=#ffcc44]● Boşta[/color]"))

	# Type-specific stats (component-based)
	if def.generator:
		lines.append(_stat("Akış", "%d MB/s" % int(def.generator.generation_rate)))
		if not def.generator.data_weights.is_empty():
			lines.append(_stat("Çıktı", _format_data_weights(def.generator.data_weights)))
	if def.storage:
		var total: int = b.get_total_stored()
		var cap: int = def.storage.capacity
		var pct: int = int(float(total) / float(cap) * 100.0) if cap > 0 else 0
		var fill_color: String = "#ff6644" if pct >= 90 else "#ffcc44" if pct >= 70 else "#44ff88"
		lines.append(_stat("Doluluk", "[color=%s]%d / %d MB (%d%%)[/color]" % [fill_color, total, cap, pct]))
		if total > 0:
			lines.append(_stat("İçerik", _format_stored_data(b.stored_data)))
		if def.storage.forward_rate > 0:
			lines.append(_stat("İletim", "%d MB/s" % int(def.storage.forward_rate)))
	if def.seller:
		lines.append(_stat("Satış", "%d MB/s (Clean)" % int(def.seller.sell_rate)))
		lines.append(_stat("Kazanç", "%.1f CR/MB" % def.seller.credits_per_mb))
		var clean_buf: int = b.stored_data.get("clean", 0)
		if clean_buf > 0:
			lines.append(_stat("Buffer", "%d MB Clean" % clean_buf))
	if def.power_provider:
		var tile_range: int = int(def.power_provider.zone_radius / 64.0)
		lines.append(_stat("Zone", "%d tile yarıçap" % tile_range))
		lines.append(_stat("Beslenen", "%d yapı" % _count_powered_buildings(b)))
	if def.coolant:
		var tile_range: int = int(def.coolant.zone_radius / 64.0)
		lines.append(_stat("Zone", "%d tile yarıçap" % tile_range))
		lines.append(_stat("Soğutma", "%.1f °C/s" % def.coolant.cooling_rate))
	if def.processor:
		lines.append(_stat("İşleme", "%d MB/s" % int(def.processor.processing_rate)))
		lines.append(_stat("Verimlilik", "%d%%" % int(def.processor.efficiency * 100)))
		if def.processor.rule == "separator":
			var filter_name: String = b.separator_filter.capitalize()
			lines.append(_stat("Sağ Port →", "[color=#44ff88]%s[/color]" % filter_name))
			lines.append(_stat("Alt Port  →", "[color=#ff8844]Corrupted[/color], [color=#44aaff]Encrypted[/color], [color=#ff4466]Malware[/color]"))
		elif def.processor.rule == "compressor":
			lines.append(_stat("Sıkıştırma", "T1 — %d%% çıktı" % int(def.processor.efficiency * 100)))
		elif def.processor.rule == "decryptor":
			lines.append(_stat("Giriş", "[color=#44aaff]Encrypted[/color]"))
			lines.append(_stat("Çıkış", "[color=#aa88ff]Research[/color]"))
	if def.research_collector:
		var rc: ResearchCollectorComponent = def.research_collector
		lines.append(_stat("Toplama", "%d MB/s" % int(rc.collection_rate)))
		lines.append(_stat("Kazanım", "%.1f RP/MB" % rc.research_per_mb))
		var research_buf: int = b.stored_data.get("research", 0)
		if research_buf > 0:
			lines.append(_stat("Buffer", "[color=#aa88ff]%d MB Research[/color]" % research_buf))

	# Heat (all buildings)
	var heat_pct: int = int(b.heat_ratio * 100.0)
	var heat_color: String
	if b.is_overheated:
		heat_color = "#ff6644"
	elif heat_pct >= 70:
		heat_color = "#ffcc44"
	elif heat_pct >= 30:
		heat_color = "#44ff88"
	else:
		heat_color = "#aabbcc"
	var heat_status: String = " [color=#ff4422]AŞIRI ISI[/color]" if b.is_overheated else ""
	lines.append(_stat("Isı", "[color=%s]%.1f / %.0f °C[/color]%s" % [heat_color, b.current_heat, def.max_heat, heat_status]))

	if def.heat_generation > 0 and not def.is_infrastructure():
		lines.append(_stat("Isı Üretimi", "+%.1f °C/s" % def.heat_generation))

	stats_label.text = "\n".join(lines)


func _stat(label: String, value: String) -> String:
	return "[color=#667788]%s:[/color]  %s" % [label, value]


func _format_data_weights(weights: Dictionary) -> String:
	var parts: PackedStringArray = []
	var type_colors: Dictionary = {
		"clean": "#44ff88",
		"corrupted": "#ff8844",
		"encrypted": "#44aaff",
		"malware": "#ff4466",
		"research": "#aa88ff"
	}
	for dtype in weights:
		var pct: int = int(weights[dtype] * 100)
		var color: String = type_colors.get(dtype, "#aabbcc")
		parts.append("[color=%s]%d%% %s[/color]" % [color, pct, dtype.capitalize()])
	return ", ".join(parts)


func _format_stored_data(data: Dictionary) -> String:
	var parts: PackedStringArray = []
	var type_colors: Dictionary = {
		"clean": "#44ff88",
		"corrupted": "#ff8844",
		"encrypted": "#44aaff",
		"malware": "#ff4466",
		"research": "#aa88ff"
	}
	for dtype in data:
		if data[dtype] > 0:
			var color: String = type_colors.get(dtype, "#aabbcc")
			parts.append("[color=%s]%d %s[/color]" % [color, data[dtype], dtype.capitalize()])
	if parts.is_empty():
		return "Boş"
	return ", ".join(parts)


func _count_powered_buildings(power_cell: Node2D) -> int:
	var count: int = 0
	var container: Node2D = power_cell.get_parent()
	if container == null:
		return 0
	for child in container.get_children():
		if child == power_cell or not child.has_method("is_active"):
			continue
		if child.definition == null or child.definition.is_infrastructure():
			continue
		if _is_in_zone(power_cell, child):
			count += 1
	return count


func _is_in_zone(source: Node2D, target: Node2D) -> bool:
	var tile_range: int = int(source.definition.get_zone_radius() / 64)
	var src_cell: Vector2i = source.grid_cell
	var src_size: Vector2i = source.definition.grid_size
	var tgt_cell: Vector2i = target.grid_cell
	var tgt_size: Vector2i = target.definition.grid_size
	var zone_left: int = src_cell.x - tile_range
	var zone_top: int = src_cell.y - tile_range
	var zone_right: int = src_cell.x + src_size.x + tile_range - 1
	var zone_bottom: int = src_cell.y + src_size.y + tile_range - 1
	var tgt_right: int = tgt_cell.x + tgt_size.x - 1
	var tgt_bottom: int = tgt_cell.y + tgt_size.y - 1
	return tgt_cell.x >= zone_left and tgt_right <= zone_right \
		and tgt_cell.y >= zone_top and tgt_bottom <= zone_bottom


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
