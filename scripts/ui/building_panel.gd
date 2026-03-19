extends PanelContainer

signal building_selected(definition: BuildingDefinition)

const BuildingIcon := preload("res://scripts/ui/building_icon.gd")

const PANEL_BG_COLOR := Color(0.04, 0.06, 0.09, 0.93)
const BORDER_COLOR := Color(0.13, 0.67, 0.87, 0.38)
const BUTTON_NORMAL_COLOR := Color(0.08, 0.1, 0.14, 0.7)
const BUTTON_HOVER_COLOR := Color(0.12, 0.18, 0.26, 0.85)
const BUTTON_PRESSED_COLOR := Color(0.16, 0.24, 0.36, 0.9)
const LOCKED_BG_COLOR := Color(0.05, 0.06, 0.08, 0.5)
const LOCKED_BORDER_COLOR := Color(0.2, 0.22, 0.25, 0.4)
const LOCKED_TEXT_COLOR := Color(0.35, 0.38, 0.42, 0.7)
const TITLE_COLOR := Color("#00bbee")
const ACCENT_COLOR := Color(0.9, 0.6, 0.25)
const DEMO_MAX_LEVEL: int = 1
const CELL_ICON_SIZE: float = 48.0

## Display order for buildings (consistent layout)
const BUILDING_ORDER: PackedStringArray = [
	"Trash", "Splitter",
	"Separator", "Classifier", "Scanner", "Merger", "Recoverer",
	"Key Forge", "Repair Lab", "Decryptor", "Encryptor",
]

## Which gig unlocks each building (for locked tooltip)
const UNLOCK_GIG: Dictionary = {
	"Separator": "Gig 1: First Extraction",
	"Classifier": "Gig 1: First Extraction",
	"Merger": "Gig 2: Clean Data Only",
	"Repair Lab": "Gig 4: Research Collection",
	"Recoverer": "Gig 4: Research Collection",
	"Key Forge": "Gig 5: Data Recovery",
	"Decryptor": "Gig 5: Data Recovery",
	"Encryptor": "Gig 6: Decryption Run",
}

## Cell references for guided tutorial arrow targeting
var _cell_refs: Dictionary = {}  ## building_name → PanelContainer


func get_building_button_rect(building_name: String) -> Rect2:
	var cell = _cell_refs.get(building_name)
	if cell != null and is_instance_valid(cell):
		return cell.get_global_rect()
	return Rect2()

var _definitions: Array[BuildingDefinition] = []
var _gig_manager: Node = null
var _simulation_manager: Node = null
var _upgrade_manager: Node = null
var _selected_source: Node2D = null  ## Currently selected data source
var _button_container_ref: VBoxContainer = null
var _panel_tween: Tween = null
var _is_panel_visible: bool = false

# Detail view references
var _title_label_ref: Label = null
var _scroll_container_ref: ScrollContainer = null
var _detail_container: VBoxContainer = null
var _detail_name: Label = null
var _detail_desc: Label = null
var _detail_stats: RichTextLabel = null
var _detail_filter_container: HBoxContainer = null
var _detail_filter_label: Label = null
var _detail_filter_dropdown: OptionButton = null
var _detail_upgrade_header: Label = null
var _detail_upgrade_dots: HBoxContainer = null
var _detail_upgrade_stat: RichTextLabel = null
var _detail_upgrade_btn: Button = null
var _detail_upgrade_cap: Label = null
var _ct_claim_container: VBoxContainer = null
var _ct_claim_buttons: Dictionary = {}  # category → Button
var _selected_building: Node2D = null
var _in_detail_mode: bool = false


func _ready() -> void:
	_setup_panel_style()
	_load_definitions()
	_title_label_ref = $MarginContainer/VBoxContainer/TitleLabel
	_scroll_container_ref = $MarginContainer/VBoxContainer/ScrollContainer
	_create_buttons()
	_build_detail_ui()
	_play_slide_in()


func refresh_detail() -> void:
	if _in_detail_mode and _selected_building != null:
		_update_detail()
	elif _in_detail_mode and _selected_source != null:
		_update_source_detail()


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
	_scroll_container_ref.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rebuild_buttons()


func refresh_buttons() -> void:
	_rebuild_buttons()


func refresh_building_list() -> void:
	_rebuild_buttons()

func _rebuild_buttons() -> void:
	if _button_container_ref == null:
		return
	_cell_refs.clear()
	# Clear old children
	for child in _button_container_ref.get_children():
		child.queue_free()

	# Build a name->def lookup
	var def_map: Dictionary = {}
	for def in _definitions:
		def_map[def.building_name] = def

	# Collect valid buildings in order
	var items: Array[Dictionary] = []
	for bname in BUILDING_ORDER:
		var def: BuildingDefinition = def_map.get(bname)
		if def == null or not def.is_placeable:
			continue
		var unlocked: bool = not _gig_manager or _gig_manager.is_building_unlocked(bname)
		items.append({"def": def, "unlocked": unlocked})

	# Create rows of 2 cells each
	var idx := 0
	while idx < items.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_button_container_ref.add_child(row)

		# Add 1-2 cells to this row
		for col in range(2):
			if idx >= items.size():
				# Filler for odd count — empty spacer
				var spacer := Control.new()
				spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(spacer)
				break

			var item: Dictionary = items[idx]
			var def: BuildingDefinition = item["def"]
			var unlocked: bool = item["unlocked"]

			var cell := _create_cell(def, unlocked)
			row.add_child(cell)

			# Staggered fade-in
			cell.modulate = Color(1, 1, 1, 0)
			var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(cell, "modulate:a", 1.0, 0.3).set_delay(idx * 0.05)
			idx += 1


func _create_cell(def: BuildingDefinition, unlocked: bool) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.clip_contents = true
	cell.tooltip_text = def.description if unlocked else "Unlocks after %s" % UNLOCK_GIG.get(def.building_name, "a gig")
	cell.mouse_filter = Control.MOUSE_FILTER_STOP

	# VBox: icon on top, name below
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.add_child(vbox)

	# Icon
	var icon := Control.new()
	icon.set_script(BuildingIcon)
	icon.custom_minimum_size = Vector2(CELL_ICON_SIZE, CELL_ICON_SIZE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	if unlocked:
		icon.setup(def.visual_type, def.color)
	else:
		icon.setup(def.visual_type, Color(0.35, 0.4, 0.5, 0.7))
	vbox.add_child(icon)

	# Name label
	var label := Label.new()
	label.text = def.building_name if unlocked else "???"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	if unlocked:
		label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.9))
	else:
		label.add_theme_color_override("font_color", Color(0.45, 0.5, 0.58, 0.8))
	vbox.add_child(label)

	# Style the cell
	if unlocked:
		_style_cell(cell, def.color)
		cell.gui_input.connect(_on_cell_input.bind(def))
	else:
		_style_locked_cell(cell)

	_cell_refs[def.building_name] = cell
	return cell


func _on_cell_input(event: InputEvent, def: BuildingDefinition) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		building_selected.emit(def)
		print("[BuildingPanel] Building selected — %s" % def.building_name)


# --- DETAIL VIEW ---

func _build_detail_ui() -> void:
	var vbox: VBoxContainer = $MarginContainer/VBoxContainer
	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", 8)
	_detail_container.visible = false
	vbox.add_child(_detail_container)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "← Structures"
	back_btn.add_theme_font_size_override("font_size", 13)
	back_btn.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8, 0.8))
	back_btn.add_theme_color_override("font_hover_color", TITLE_COLOR)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.06, 0.08, 0.12, 0.5)
	back_style.set_content_margin_all(6)
	back_style.set_corner_radius_all(2)
	back_btn.add_theme_stylebox_override("normal", back_style)
	var back_hover := back_style.duplicate()
	back_hover.bg_color = Color(0.1, 0.14, 0.2, 0.7)
	back_btn.add_theme_stylebox_override("hover", back_hover)
	back_btn.pressed.connect(hide_building_detail)
	_detail_container.add_child(back_btn)

	# Building name
	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 18)
	_detail_container.add_child(_detail_name)

	# Description
	_detail_desc = Label.new()
	_detail_desc.add_theme_font_size_override("font_size", 12)
	_detail_desc.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.8))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_container.add_child(_detail_desc)

	# Separator
	var sep1 := HSeparator.new()
	sep1.add_theme_constant_override("separation", 4)
	_detail_container.add_child(sep1)

	# Live status
	_detail_stats = RichTextLabel.new()
	_detail_stats.bbcode_enabled = true
	_detail_stats.fit_content = true
	_detail_stats.scroll_active = false
	_detail_stats.add_theme_font_size_override("normal_font_size", 13)
	_detail_container.add_child(_detail_stats)

	# Filter dropdown (Classifier/Separator)
	_detail_filter_container = HBoxContainer.new()
	_detail_filter_container.add_theme_constant_override("separation", 8)
	_detail_filter_container.visible = false
	_detail_filter_label = Label.new()
	_detail_filter_label.text = "Filter:"
	_detail_filter_label.add_theme_font_size_override("font_size", 13)
	_detail_filter_label.add_theme_color_override("font_color", ACCENT_COLOR)
	_detail_filter_container.add_child(_detail_filter_label)
	_detail_filter_dropdown = OptionButton.new()
	_detail_filter_dropdown.add_theme_font_size_override("font_size", 13)
	_detail_filter_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_filter_dropdown.focus_mode = Control.FOCUS_NONE
	_detail_filter_dropdown.item_selected.connect(_on_filter_selected)
	_detail_filter_container.add_child(_detail_filter_dropdown)
	_detail_container.add_child(_detail_filter_container)

	# Separator
	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 4)
	_detail_container.add_child(sep2)

	# Upgrade header
	_detail_upgrade_header = Label.new()
	_detail_upgrade_header.text = "// UPGRADE"
	_detail_upgrade_header.add_theme_font_size_override("font_size", 14)
	_detail_upgrade_header.add_theme_color_override("font_color", ACCENT_COLOR)
	_detail_container.add_child(_detail_upgrade_header)

	# Level dots
	_detail_upgrade_dots = HBoxContainer.new()
	_detail_upgrade_dots.add_theme_constant_override("separation", 4)
	_detail_container.add_child(_detail_upgrade_dots)

	# Upgrade stat
	_detail_upgrade_stat = RichTextLabel.new()
	_detail_upgrade_stat.bbcode_enabled = true
	_detail_upgrade_stat.fit_content = true
	_detail_upgrade_stat.scroll_active = false
	_detail_upgrade_stat.custom_minimum_size = Vector2(0, 20)
	_detail_container.add_child(_detail_upgrade_stat)

	# Upgrade button
	_detail_upgrade_btn = Button.new()
	_detail_upgrade_btn.text = "[ UPGRADE ]"
	_detail_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	_style_upgrade_button(_detail_upgrade_btn)
	_detail_container.add_child(_detail_upgrade_btn)

	# Demo cap label
	_detail_upgrade_cap = Label.new()
	_detail_upgrade_cap.add_theme_font_size_override("font_size", 12)
	_detail_upgrade_cap.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55, 0.7))
	_detail_upgrade_cap.visible = false
	_detail_container.add_child(_detail_upgrade_cap)

	# CT Upgrade claim buttons
	_ct_claim_container = VBoxContainer.new()
	_ct_claim_container.visible = false
	_ct_claim_container.add_theme_constant_override("separation", 4)
	_detail_container.add_child(_ct_claim_container)
	var cat_labels: Dictionary = {"routing": "Routing", "decryption": "Decryption", "recovery": "Recovery", "bandwidth": "Bandwidth"}
	for cat in ["routing", "decryption", "recovery", "bandwidth"]:
		var btn := Button.new()
		btn.text = "%s — CLAIM" % cat_labels[cat]
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(0.2, 0.9, 0.6))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.12, 0.15, 0.9)
		style.border_color = Color(0.2, 0.7, 0.5, 0.6)
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.set_content_margin_all(6)
		btn.add_theme_stylebox_override("normal", style)
		var hover_style := style.duplicate()
		hover_style.bg_color = Color(0.08, 0.18, 0.2, 0.95)
		hover_style.border_color = Color(0.3, 0.9, 0.6, 0.8)
		btn.add_theme_stylebox_override("hover", hover_style)
		var disabled_style := style.duplicate()
		disabled_style.bg_color = Color(0.04, 0.06, 0.08, 0.6)
		disabled_style.border_color = Color(0.2, 0.25, 0.3, 0.3)
		btn.add_theme_stylebox_override("disabled", disabled_style)
		btn.pressed.connect(_on_claim_pressed.bind(cat))
		_ct_claim_container.add_child(btn)
		_ct_claim_buttons[cat] = btn


func _on_claim_pressed(category: String) -> void:
	if _upgrade_manager and _upgrade_manager.claim_tier_up(category):
		_update_detail()


func setup_detail(sim_manager: Node) -> void:
	_simulation_manager = sim_manager


func show_building_detail(building: Node2D) -> void:
	if building == null or building.definition == null:
		return
	_selected_building = building
	_in_detail_mode = true

	# Swap views
	_scroll_container_ref.visible = false
	_detail_container.visible = true
	_title_label_ref.text = "// %s" % building.definition.building_name.to_upper()
	_title_label_ref.add_theme_color_override("font_color", building.definition.color)

	# Fill static info
	_detail_name.text = building.definition.building_name
	_detail_name.add_theme_color_override("font_color", building.definition.color)
	_detail_desc.text = building.definition.description

	# Show/hide filter dropdown
	_populate_filter_dropdown(building)

	# Show/hide upgrade section
	var has_upgrade: bool = building.definition.upgrade != null
	_detail_upgrade_header.visible = has_upgrade
	_detail_upgrade_dots.visible = has_upgrade
	_detail_upgrade_stat.visible = has_upgrade
	_detail_upgrade_btn.visible = has_upgrade
	_detail_upgrade_cap.visible = false
	if not has_upgrade:
		_detail_upgrade_cap.visible = true
		_detail_upgrade_cap.text = "No upgrades available"

	_update_detail()


func show_source_detail(source: Node2D) -> void:
	if source == null or source.definition == null:
		return
	_selected_building = null
	_selected_source = source
	_in_detail_mode = true

	_scroll_container_ref.visible = false
	_detail_container.visible = true
	_title_label_ref.text = "// %s" % source.definition.source_name.to_upper()
	_title_label_ref.add_theme_color_override("font_color", source.definition.color)

	_detail_name.text = source.definition.source_name
	_detail_name.add_theme_color_override("font_color", source.definition.color)
	_detail_desc.text = source.definition.description

	# Hide building-specific UI
	_detail_filter_container.visible = false
	_detail_upgrade_header.visible = false
	_detail_upgrade_dots.visible = false
	_detail_upgrade_stat.visible = false
	_detail_upgrade_btn.visible = false
	_detail_upgrade_cap.visible = false

	_update_source_detail()


func hide_building_detail() -> void:
	_selected_building = null
	_selected_source = null
	_in_detail_mode = false

	# Swap views back
	_scroll_container_ref.visible = true
	_detail_container.visible = false
	_title_label_ref.text = "// STRUCTURES"
	_title_label_ref.add_theme_color_override("font_color", TITLE_COLOR)


func _update_detail() -> void:
	if _selected_building == null or _selected_building.definition == null:
		hide_building_detail()
		return

	var b: Node2D = _selected_building
	var def: BuildingDefinition = b.definition

	# Live status + type-specific stats
	var lines: PackedStringArray = []
	if b.is_working:
		lines.append("[color=#44ff88]● Working[/color]")
	else:
		var reason: String = b.status_reason
		if reason != "":
			lines.append("[color=#ffcc44]● Idle — %s[/color]" % reason)
		else:
			lines.append("[color=#ffcc44]● Idle[/color]")

	# Type-specific live info
	if def.classifier:
		lines.append("[color=#888888]Throughput:[/color] %d MB/s" % int(b.get_effective_value("processing_rate")))
		var filter_name: String = DataEnums.content_name(b.classifier_filter_content)
		lines.append("[color=#888888]Right →[/color] [color=#44ff88]%s[/color]" % filter_name)
		lines.append("[color=#888888]Bottom →[/color] All other content")
	if def.scanner:
		lines.append("[color=#888888]Throughput:[/color] %d MB/s" % int(def.scanner.throughput_rate))
		var pid: int = b.scanner_filter_sub_type
		var st_label: String = "(no filter)"
		if pid >= 0:
			var fc: int = pid / 4
			var fst: int = pid % 4
			var stn: String = DataEnums.sub_type_name(fc, fst)
			if stn != "":
				st_label = stn
		lines.append("[color=#888888]Right →[/color] [color=#44ff88]%s[/color]" % st_label)
		lines.append("[color=#888888]Bottom →[/color] All other sub-types")
	if def.producer:
		lines.append("[color=#888888]Rate:[/color] %d/tick" % int(b.get_effective_value("processing_rate")))
		var tier_names: Array[String] = ["T1 Key", "T2 Strong Key", "T3 Master Key"]
		var tier_label: String = tier_names[b.selected_tier - 1] if b.selected_tier <= tier_names.size() else "T%d Key" % b.selected_tier
		lines.append("[color=#888888]Mode:[/color] [color=#ffaa00]%s[/color]" % tier_label)
		var recipe: String = "[color=#aa77ff]%d MB Research[/color]" % def.producer.consume_amount
		if b.selected_tier >= 2 and def.producer.tier2_extra_content >= 0:
			recipe += " + [color=#ffcc00]%d MB %s[/color]" % [def.producer.tier2_extra_amount, DataEnums.content_name(def.producer.tier2_extra_content)]
		if b.selected_tier >= 3 and def.producer.tier3_extra_content >= 0:
			recipe += " + [color=#ff33aa]%d MB %s[/color]" % [def.producer.tier3_extra_amount, DataEnums.content_name(def.producer.tier3_extra_content)]
		lines.append("[color=#888888]Recipe:[/color] %s" % recipe)
	if def.dual_input:
		lines.append("[color=#888888]Throughput:[/color] %d MB/s" % int(b.get_effective_value("processing_rate")))
		if not def.dual_input.fuel_matches_content:
			var key_parts: PackedStringArray = []
			for kt in range(1, 4):
				var kk: int = DataEnums.pack_key(def.dual_input.key_content, DataEnums.DataState.PUBLIC, kt, 0)
				var count: int = b.stored_data.get(kk, 0)
				if count > 0:
					key_parts.append("T%d:%d" % [kt, count])
			if key_parts.is_empty():
				lines.append("[color=#888888]Key Stock:[/color] [color=#ff6644]0[/color]")
			else:
				lines.append("[color=#888888]Key Stock:[/color] [color=#ffaa00]%s[/color]" % ", ".join(key_parts))
	if def.processor:
		if def.processor.rule == "separator":
			lines.append("[color=#888888]Throughput:[/color] %d MB/s" % int(b.get_effective_value("processing_rate")))
			var filter_name: String
			if b.separator_mode == "content":
				filter_name = DataEnums.content_name(b.separator_filter_value)
			else:
				filter_name = DataEnums.state_name(b.separator_filter_value)
			lines.append("[color=#888888]Right →[/color] [color=#44ff88]%s[/color]" % filter_name)
			lines.append("[color=#888888]Bottom →[/color] All other data")
		elif def.processor.rule == "splitter":
			lines.append("[color=#888888]Distribution:[/color] Equal (50/50)")
		elif def.processor.rule == "merger":
			lines.append("[color=#888888]Merging:[/color] ← Left + ↑ Top → Right")
		elif def.processor.rule == "trash":
			lines.append("[color=#888888]Mode:[/color] Instant destruction")
	# CT: show upgrade categories + claim buttons
	var is_ct: bool = def.category == "terminal"
	_ct_claim_container.visible = is_ct and _upgrade_manager != null
	if is_ct and _upgrade_manager:
		lines.append("")
		lines.append("[color=#44ccff]── UPGRADES ──[/color]")
		for cat in ["routing", "decryption", "recovery", "bandwidth"]:
			var tier: int = _upgrade_manager.get_tier(cat)
			var mult: float = _upgrade_manager.get_multiplier(cat)
			var cum: float = _upgrade_manager.get_cumulative(cat)
			var next_cost: float = _upgrade_manager.get_next_tier_cost(cat)
			var cat_label: String = cat.capitalize()
			var progress_str: String
			if next_cost < 0:
				progress_str = "[color=#44ff88]MAX[/color]"
			else:
				progress_str = "%d / %d MB" % [int(cum), int(next_cost)]
			var tier_color: String = "#44ff88" if tier >= 3 else ("#ffcc44" if tier >= 2 else "#aabbcc")
			lines.append("[color=%s]%s T%d[/color] (%.0fx) — %s" % [tier_color, cat_label, tier, mult, progress_str])
			# Update claim button state
			if _ct_claim_buttons.has(cat):
				var btn: Button = _ct_claim_buttons[cat]
				var claimable: bool = _upgrade_manager.is_claimable(cat)
				btn.disabled = not claimable
				if next_cost < 0:
					btn.text = "%s — MAX" % cat_label
					btn.disabled = true
				elif claimable:
					btn.text = "%s — CLAIM T%d!" % [cat_label, tier + 1]
					btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
				else:
					btn.text = "%s T%d — %d / %d MB" % [cat_label, tier, int(cum), int(next_cost)]
					btn.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))

	# Stored data summary
	var total_stored: int = b.get_total_stored()
	if total_stored > 0:
		var cap: int = int(b.get_effective_value("capacity")) if b.has_method("get_effective_value") else 0
		if cap > 0:
			lines.append("[color=#888888]Stored:[/color] %d / %d MB" % [total_stored, cap])
		else:
			lines.append("[color=#888888]Stored:[/color] %d MB" % total_stored)
		# Show data breakdown for CT
		if def.category == "terminal":
			for key in b.stored_data:
				if b.stored_data[key] <= 0:
					continue
				var c: int = DataEnums.unpack_content(key)
				var s: int = DataEnums.unpack_state(key)
				var c_color: String = DataEnums.content_color_hex(c)
				var s_color: String = DataEnums.state_color_hex(s)
				var label: String = DataEnums.data_label(c, s, DataEnums.unpack_tier(key), DataEnums.unpack_tags(key))
				lines.append("  [color=%s]%d[/color] [color=%s]%s[/color]" % [s_color, b.stored_data[key], c_color, label])

	_detail_stats.text = "\n".join(lines)

	# Live-update filter dropdown selection
	if _detail_filter_container.visible:
		if def.classifier:
			_detail_filter_dropdown.selected = b.classifier_filter_content
		elif def.processor and def.processor.rule == "separator":
			if b.separator_mode == "state":
				var state_cycle: Array[int] = [0, 1, 2]
				_detail_filter_dropdown.selected = maxi(state_cycle.find(b.separator_filter_value), 0)
			else:
				_detail_filter_dropdown.selected = b.separator_filter_value
		elif def.producer and def.producer.max_tier > 1:
			_detail_filter_dropdown.selected = b.selected_tier - 1

	# Upgrade section
	if def.upgrade == null:
		return

	var upg: UpgradeComponent = def.upgrade
	var level: int = b.upgrade_level
	var max_level: int = upg.max_level
	var current_val: float = b.get_effective_value(upg.stat_target)

	# Update dots
	for child in _detail_upgrade_dots.get_children():
		child.queue_free()
	for i in range(max_level):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(16, 5)
		if i < level:
			dot.color = def.color
		elif i < DEMO_MAX_LEVEL:
			dot.color = Color(def.color, 0.25)
		else:
			dot.color = Color(0.3, 0.3, 0.35, 0.3)
		_detail_upgrade_dots.add_child(dot)

	# Update stat + button
	if level >= max_level:
		_detail_upgrade_stat.text = "[color=#ffaa44]%s: %s[/color] [color=#44ff88](MAX)[/color]" % [
			upg.stat_label, _format_stat(upg.stat_target, current_val)]
		_detail_upgrade_btn.visible = false
		_detail_upgrade_cap.visible = false
	elif level >= DEMO_MAX_LEVEL:
		_detail_upgrade_stat.text = "[color=#ffaa44]%s: %s[/color]" % [
			upg.stat_label, _format_stat(upg.stat_target, current_val)]
		_detail_upgrade_btn.visible = false
		_detail_upgrade_cap.visible = true
		_detail_upgrade_cap.text = "🔒 More upgrades in full game"
	else:
		var next_val: float = upg.level_values[level] if level < upg.level_values.size() else current_val
		_detail_upgrade_stat.text = "[color=#aaaaaa]%s:[/color] [color=#ffffff]%s[/color] → [color=#44ff88]%s[/color]" % [
			upg.stat_label, _format_stat(upg.stat_target, current_val), _format_stat(upg.stat_target, next_val)]
		_detail_upgrade_btn.visible = true
		_detail_upgrade_btn.disabled = false
		_detail_upgrade_cap.visible = false


func _format_stat(stat_target: String, value: float) -> String:
	match stat_target:
		"efficiency":
			return "%d%%" % int(value * 100)
		"processing_rate":
			return "%d MB/s" % int(value)
		"capacity":
			return "%d MB" % int(value)
	return "%.1f" % value


func _on_upgrade_pressed() -> void:
	if _selected_building == null or _simulation_manager == null:
		return
	_simulation_manager.upgrade_building(_selected_building)


func _style_upgrade_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.05, 0.7)
	style.border_color = ACCENT_COLOR
	style.border_width_bottom = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.25, 0.2, 0.08, 0.85)
	hover.shadow_color = Color(ACCENT_COLOR, 0.15)
	hover.shadow_size = 4
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.3, 0.25, 0.1, 0.9)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", ACCENT_COLOR)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.8, 0.4))
	btn.add_theme_font_size_override("font_size", 13)


# --- PANEL STYLING ---

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


func _style_locked_cell(cell: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.15, 0.8)
	style.border_color = Color(0.3, 0.33, 0.4, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 6
	style.content_margin_bottom = 4
	cell.add_theme_stylebox_override("panel", style)


func _style_cell(cell: PanelContainer, accent_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BUTTON_NORMAL_COLOR
	style.border_color = Color(accent_color, 0.5)
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 6
	style.content_margin_bottom = 4
	cell.add_theme_stylebox_override("panel", style)

	# Hover/press feedback via mouse_entered/exited
	var normal_style := style
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = BUTTON_HOVER_COLOR
	hover_style.border_color = accent_color
	hover_style.shadow_color = Color(accent_color, 0.15)
	hover_style.shadow_size = 4

	cell.mouse_entered.connect(func() -> void:
		cell.add_theme_stylebox_override("panel", hover_style)
	)
	cell.mouse_exited.connect(func() -> void:
		cell.add_theme_stylebox_override("panel", normal_style)
	)


func _update_source_detail() -> void:
	if _selected_source == null or _selected_source.definition == null:
		hide_building_detail()
		return
	var src: Node2D = _selected_source
	var def = src.definition
	var lines: PackedStringArray = []

	# Difficulty
	var diff_colors: Dictionary = {"easy": "#44ff66", "medium": "#ffee44", "hard": "#ff9933", "endgame": "#ff4444"}
	var diff_color: String = diff_colors.get(def.difficulty, "#aabbcc")
	lines.append("[color=%s]%s[/color] | %d MB/s" % [diff_color, def.difficulty.to_upper(), int(def.bandwidth)])

	# FIRE status
	if src.has_fire():
		var fire_color: String = "#ff4422" if src.fire_active else "#44ff66"
		var fire_status: String = "ACTIVE" if src.fire_active else "BREACHED"
		var fire_type_label: String = "Threshold" if def.fire_type == "threshold" else "Regenerating"
		lines.append("[color=%s]FIRE: %s[/color] (%s)" % [fire_color, fire_status, fire_type_label])
		for req in def.fire_requirements:
			var st: int = int(req.sub_type)
			var content: int = st / 4
			var offset: int = st % 4
			var req_name: String = DataEnums.sub_type_name(content, offset)
			var c_color: String = DataEnums.content_color_hex(content)
			var cur: float = src.fire_progress.get(st, 0.0)
			var needed: float = float(req.amount)
			lines.append("  [color=%s]%s[/color] — %d / %d MB" % [c_color, req_name, int(cur), int(needed)])

	# Content weights
	lines.append("")
	lines.append("[color=#667788]Content:[/color]")
	for content_id in def.content_weights:
		var pct: int = int(def.content_weights[content_id] * 100)
		var c: int = int(content_id)
		var c_color: String = DataEnums.content_color_hex(c)
		lines.append("  [color=%s]%d%% %s[/color]" % [c_color, pct, DataEnums.content_name(c)])

	# State weights
	var sw: Dictionary = src.instance_state_weights if not src.instance_state_weights.is_empty() else def.state_weights
	lines.append("[color=#667788]State:[/color]")
	for state_id in sw:
		var pct: int = int(sw[state_id] * 100)
		var s: int = int(state_id)
		var s_color: String = DataEnums.state_color_hex(s)
		lines.append("  [color=%s]%d%% %s[/color]" % [s_color, pct, DataEnums.state_name(s)])

	# Sub-types
	if not def.sub_type_pool.is_empty():
		lines.append("[color=#667788]Sub-Types:[/color]")
		for entry in def.sub_type_pool:
			var c: int = int(entry.get("content", 0))
			var st: int = int(entry.get("sub_type", 0))
			var st_name: String = DataEnums.sub_type_name(c, st)
			var c_color: String = DataEnums.content_color_hex(c)
			lines.append("  [color=%s]%s[/color]" % [c_color, st_name])

	# Ports
	lines.append("")
	lines.append("[color=#667788]Output Ports:[/color] %d" % src.output_ports.size())
	if not src.fire_input_ports.is_empty():
		lines.append("[color=#667788]FIRE Ports:[/color] %d" % src.fire_input_ports.size())

	_detail_stats.text = "\n".join(lines)


func _populate_filter_dropdown(building: Node2D) -> void:
	_detail_filter_dropdown.clear()
	var def: BuildingDefinition = building.definition
	if def.classifier:
		_detail_filter_container.visible = true
		_detail_filter_label.text = "Content Filter:"
		for i in range(6):
			_detail_filter_dropdown.add_item(DataEnums.content_name(i), i)
		_detail_filter_dropdown.selected = building.classifier_filter_content
	elif def.scanner:
		_detail_filter_container.visible = true
		_detail_filter_label.text = "Sub-Type Filter:"
		# Group by content with color icons
		var sel_idx: int = 0
		var idx: int = 0
		var popup: PopupMenu = _detail_filter_dropdown.get_popup()
		for c in range(6):
			var count: int = DataEnums.sub_type_count(c)
			if count <= 0:
				continue
			# Content header separator
			_detail_filter_dropdown.add_separator("— %s —" % DataEnums.content_name(c))
			# Create color swatch icon for this content
			var color: Color = DataEnums.content_color(c)
			var icon: ImageTexture = _make_color_icon(color)
			for st in range(count):
				var pid: int = c * 4 + st
				var stn: String = DataEnums.sub_type_name(c, st)
				if stn == "":
					stn = "%s #%d" % [DataEnums.content_name(c), st]
				_detail_filter_dropdown.add_item(stn, pid)
				# Set icon on the popup menu item (last added)
				var item_idx: int = popup.item_count - 1
				popup.set_item_icon(item_idx, icon)
				popup.set_item_icon_max_width(item_idx, 12)
				if pid == building.scanner_filter_sub_type:
					sel_idx = idx
				idx += 1
		if idx == 0:
			_detail_filter_dropdown.add_item("(no data)", 0)
		else:
			_detail_filter_dropdown.selected = mini(sel_idx, idx - 1)
	elif def.processor and def.processor.rule == "separator":
		_detail_filter_container.visible = true
		if building.separator_mode == "state":
			_detail_filter_label.text = "State Filter:"
			var state_cycle: Array[int] = [0, 1, 2]
			for s in state_cycle:
				_detail_filter_dropdown.add_item(DataEnums.state_name(s), s)
			# Find the dropdown index for current value
			var sel_idx: int = state_cycle.find(building.separator_filter_value)
			_detail_filter_dropdown.selected = maxi(sel_idx, 0)
		else:
			_detail_filter_label.text = "Content Filter:"
			for i in range(6):
				_detail_filter_dropdown.add_item(DataEnums.content_name(i), i)
			_detail_filter_dropdown.selected = building.separator_filter_value
	elif def.producer and def.producer.max_tier > 1:
		_detail_filter_container.visible = true
		_detail_filter_label.text = "Tier:"
		var tier_state: int = DataEnums.DataState.ENCRYPTED if def.producer.output_content == DataEnums.ContentType.KEY else DataEnums.DataState.CORRUPTED
		var output_name: String = DataEnums.content_name(def.producer.output_content)
		for t in range(1, def.producer.max_tier + 1):
			var tier_str: String = DataEnums.tier_name(t, tier_state)
			if tier_str.is_empty():
				tier_str = "T%d" % t
			_detail_filter_dropdown.add_item("%s %s" % [tier_str, output_name], t)
		_detail_filter_dropdown.selected = building.selected_tier - 1
	else:
		_detail_filter_container.visible = false


static func _make_color_icon(color: Color, size: int = 12) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _on_filter_selected(index: int) -> void:
	if _selected_building == null or _selected_building.definition == null:
		return
	var def: BuildingDefinition = _selected_building.definition
	var id: int = _detail_filter_dropdown.get_item_id(index)
	if def.classifier:
		_selected_building.classifier_filter_content = id
	elif def.scanner:
		_selected_building.scanner_filter_sub_type = id  # packed_id = content*4 + sub_type
	elif def.processor and def.processor.rule == "separator":
		_selected_building.separator_filter_value = id
	elif def.producer and def.producer.max_tier > 1:
		_selected_building.selected_tier = id
	_update_detail()
