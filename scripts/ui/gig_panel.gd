extends PanelContainer

## Persistent contract/gig tracking panel — shows active missions, progress, and rewards.

const PANEL_BG := Color(0.04, 0.06, 0.09, 0.93)
const BORDER_CLR := Color(0.13, 0.67, 0.87, 0.38)
const ACCENT := Color("#00bbee")
const MISSION_CLR := Color("#00bbee")
const CONTRACT_CLR := Color("#ffaa00")
const BAR_BG := Color(0.1, 0.12, 0.16, 1.0)
const BAR_FILL := Color(0.0, 0.55, 0.8, 1.0)
const DONE_CLR := Color("#44ff88")
const REWARD_CLR := Color("#aa77ff")
const DIM := Color(0.45, 0.5, 0.55, 1.0)
const BRIGHT := Color(0.85, 0.9, 0.95, 1.0)
const CARD_BG := Color(0.06, 0.08, 0.12, 0.8)
const TRACKED_GLOW := Color(0.0, 0.6, 0.8, 0.12)

var _gig_manager: Node = null
var _gig_container: VBoxContainer = null
var _cards: Dictionary = {}   ## order_index -> { root, bars[], name_l, gig }
var _no_gig_label: Label = null
var _tracked_order: int = -1


func _ready() -> void:
	_setup_style()
	_build_ui()


func setup(gig_manager: Node) -> void:
	_gig_manager = gig_manager
	_gig_manager.gig_activated.connect(_on_gig_activated)
	_gig_manager.gig_progress_updated.connect(_on_gig_progress)
	_gig_manager.gig_completed.connect(_on_gig_completed)
	# Build initial state from already-active gigs
	for gig in _gig_manager.get_active_gigs():
		_add_card(gig)
	_auto_track()
	_update_empty()


func toggle() -> void:
	if modulate.a > 0.5:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.15)
		tw.tween_callback(func(): mouse_filter = Control.MOUSE_FILTER_IGNORE)
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


func show_panel() -> void:
	if modulate.a < 0.5:
		toggle()


func play_slide_in() -> void:
	modulate = Color(1, 1, 1, 0)
	var target_x := offset_left
	offset_left -= 40.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.4).set_delay(0.4)
	tw.tween_property(self, "offset_left", target_x, 0.5).set_delay(0.4)


# ── Style ──────────────────────────────────────────────────────

func _setup_style() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.border_color = BORDER_CLR
	s.border_width_right = 2
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_right = 4
	s.shadow_color = Color(0.0, 0.4, 0.6, 0.08)
	s.shadow_size = 8
	add_theme_stylebox_override("panel", s)


# ── Layout ─────────────────────────────────────────────────────

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "// CONTRACTS"
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var div := ColorRect.new()
	div.color = Color(ACCENT, 0.25)
	div.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(div)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_gig_container = VBoxContainer.new()
	_gig_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gig_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_gig_container)

	_no_gig_label = Label.new()
	_no_gig_label.text = "No active contracts"
	_no_gig_label.add_theme_color_override("font_color", DIM)
	_no_gig_label.add_theme_font_size_override("font_size", 12)
	_no_gig_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gig_container.add_child(_no_gig_label)


# ── Card Creation ──────────────────────────────────────────────

func _add_card(gig) -> void:
	var order: int = gig.order_index
	if _cards.has(order):
		return
	var prog: Array = _gig_manager.get_progress(gig)
	var tcol: Color = MISSION_CLR if gig.is_tutorial else CONTRACT_CLR
	var tracked: bool = (order == _tracked_order)

	# Card panel
	var card := PanelContainer.new()
	_style_card(card, tcol, tracked)
	_gig_container.add_child(card)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)

	# Header: badge + name
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	cv.add_child(hdr)

	var badge := Label.new()
	badge.text = "MISSION" if gig.is_tutorial else "CONTRACT"
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", tcol)
	hdr.add_child(badge)

	var name_l := Label.new()
	name_l.text = gig.gig_name
	name_l.add_theme_font_size_override("font_size", 13)
	name_l.add_theme_color_override("font_color", BRIGHT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(name_l)

	# Description
	if gig.description != "":
		var desc := Label.new()
		desc.text = gig.description
		desc.add_theme_font_size_override("font_size", 10)
		desc.add_theme_color_override("font_color", DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(desc)

	# Requirements with progress bars
	var bars: Array = []
	for i in range(gig.requirements.size()):
		var req = gig.requirements[i]
		var cur: int = prog[i] if i < prog.size() else 0
		var tgt: int = req.amount
		var done: bool = cur >= tgt

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		cv.add_child(row)

		# Label + count
		var lr := HBoxContainer.new()
		row.add_child(lr)

		var rl := Label.new()
		rl.text = _req_text(req)
		rl.add_theme_font_size_override("font_size", 11)
		rl.add_theme_color_override("font_color", DONE_CLR if done else DIM)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lr.add_child(rl)

		var cl := Label.new()
		cl.text = "%d / %d" % [cur, tgt]
		cl.add_theme_font_size_override("font_size", 11)
		cl.add_theme_color_override("font_color", DONE_CLR if done else BRIGHT)
		lr.add_child(cl)

		# Progress bar: Control container + bg ColorRect + fill ColorRect
		var bc := Control.new()
		bc.custom_minimum_size = Vector2(0, 4)
		bc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bc)

		var bg := ColorRect.new()
		bg.color = BAR_BG
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bc.add_child(bg)

		var fl := ColorRect.new()
		fl.color = DONE_CLR if done else BAR_FILL
		fl.anchor_right = clampf(float(cur) / maxi(tgt, 1), 0.0, 1.0)
		fl.anchor_bottom = 1.0
		bc.add_child(fl)

		bars.append({"rl": rl, "cl": cl, "fl": fl, "tgt": tgt})

	# Reward buildings
	if gig.reward_buildings.size() > 0:
		var rr := HBoxContainer.new()
		rr.add_theme_constant_override("separation", 4)
		cv.add_child(rr)
		var arrow := _lbl("▸", REWARD_CLR, 11)
		rr.add_child(arrow)
		var rtxt := _lbl("Unlocks: %s" % ", ".join(gig.reward_buildings), REWARD_CLR, 11)
		rr.add_child(rtxt)

	# Store card data
	_cards[order] = {"root": card, "bars": bars, "name_l": name_l, "gig": gig}

	# Fade-in animation
	card.modulate = Color(1, 1, 1, 0)
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) \
		.tween_property(card, "modulate:a", 1.0, 0.35)


func _style_card(card: PanelContainer, accent: Color, tracked: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = CARD_BG
	s.border_color = accent
	s.border_width_left = 3
	s.corner_radius_top_left = 2
	s.corner_radius_bottom_left = 2
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_right = 2
	s.content_margin_left = 10
	s.content_margin_right = 8
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	if tracked:
		s.shadow_color = TRACKED_GLOW
		s.shadow_size = 6
	card.add_theme_stylebox_override("panel", s)


# ── Signal Handlers ────────────────────────────────────────────

func _on_gig_activated(gig) -> void:
	_add_card(gig)
	_auto_track()
	_update_empty()


func _on_gig_progress(gig, ri: int, cur: int, tgt: int) -> void:
	var d: Dictionary = _cards.get(gig.order_index, {})
	if d.is_empty() or ri >= d.bars.size():
		return
	var b: Dictionary = d.bars[ri]
	var done: bool = cur >= tgt

	# Update text
	b.cl.text = "%d / %d" % [cur, tgt]
	b.cl.add_theme_color_override("font_color", DONE_CLR if done else BRIGHT)
	b.rl.add_theme_color_override("font_color", DONE_CLR if done else DIM)

	# Animate fill
	var ratio: float = clampf(float(cur) / maxi(tgt, 1), 0.0, 1.0)
	b.fl.color = DONE_CLR if done else BAR_FILL
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) \
		.tween_property(b.fl, "anchor_right", ratio, 0.25)

	# Pulse count label
	b.cl.pivot_offset = b.cl.size / 2.0
	b.cl.scale = Vector2(1.15, 1.15)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(b.cl, "scale", Vector2.ONE, 0.25)


func _on_gig_completed(gig) -> void:
	var order: int = gig.order_index
	var d: Dictionary = _cards.get(order, {})
	if d.is_empty():
		return
	d.name_l.add_theme_color_override("font_color", DONE_CLR)
	var tw := create_tween()
	tw.tween_property(d.root, "modulate", Color(0.6, 1.0, 0.75, 1.0), 0.15)
	tw.tween_property(d.root, "modulate", Color.WHITE, 0.25)
	tw.tween_interval(1.5)
	tw.tween_property(d.root, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_remove_card.bind(order))


# ── Helpers ────────────────────────────────────────────────────

func _remove_card(order: int) -> void:
	if _cards.has(order):
		if is_instance_valid(_cards[order].root):
			_cards[order].root.queue_free()
		_cards.erase(order)
	_auto_track()
	_update_empty()


func _auto_track() -> void:
	_tracked_order = -1
	if _gig_manager == null:
		return
	# Prefer first active tutorial gig
	for gig in _gig_manager.get_active_gigs():
		if gig.is_tutorial:
			_tracked_order = gig.order_index
			break
	# Otherwise first active gig
	if _tracked_order < 0:
		var a: Array = _gig_manager.get_active_gigs()
		if a.size() > 0:
			_tracked_order = a[0].order_index
	# Refresh card styles
	for order in _cards:
		var cd = _cards[order]
		var tcol: Color = MISSION_CLR if cd.gig.is_tutorial else CONTRACT_CLR
		_style_card(cd.root, tcol, order == _tracked_order)


func _update_empty() -> void:
	if _no_gig_label:
		_no_gig_label.visible = _cards.is_empty()


func _req_text(req) -> String:
	if req.packet_key != "":
		return DataEnums.packet_label(req.packet_key)
	return req.label if req.label != "" else "Data"


func _lbl(text: String, color: Color, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
