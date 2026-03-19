extends PanelContainer

## Persistent contract/gig tracking panel — shows active missions, progress, and rewards.
## Two tabs: MAIN (tutorial missions) and SIDE (contracts).

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
const CLIENT_CLR := Color(0.6, 0.75, 0.85, 0.9)
const STALL_CLR := Color(0.8, 0.45, 0.15, 1.0)
const STALL_TIME := 30.0

const TAB_ACTIVE_BG := Color(0.08, 0.14, 0.22, 1.0)
const TAB_INACTIVE_BG := Color(0.04, 0.06, 0.09, 0.5)

var _gig_manager: Node = null
var _upgrade_manager: Node = null
var _cards: Dictionary = {}   ## order_index -> { root, bars[], name_l, gig, tab }
var _tracked_order: int = -1
var _stall_timers: Dictionary = {}
var _body_container: VBoxContainer = null
var _scroll: ScrollContainer = null
var _divider: ColorRect = null
var _expanded: bool = false
var _title_btn: Button = null

# Tab system
var _active_tab: int = 0  ## 0 = MAIN, 1 = SIDE, 2 = UPGRADES
var _tab_main_btn: Button = null
var _tab_side_btn: Button = null
var _tab_upgrade_btn: Button = null
var _main_container: VBoxContainer = null
var _side_container: VBoxContainer = null
var _upgrade_container: VBoxContainer = null
var _upgrade_claim_buttons: Dictionary = {}  # category → Button
var _upgrade_info_labels: Dictionary = {}    # category → RichTextLabel

# Info overlay (building/source detail — replaces tab content when active)
var _info_container: VBoxContainer = null
var _info_title: Label = null
var _info_desc: Label = null
var _info_stats: RichTextLabel = null
var _info_flow: RichTextLabel = null  ## Input/output data flow display
var _info_dropdown: OptionButton = null  ## Filter selection dropdown
var _info_back_btn: Button = null
var _info_active: bool = false
var _info_target: Node2D = null  ## Currently inspected building or source
var _tab_row_ref: HBoxContainer = null
var _simulation_manager: Node = null
var _connection_manager: Node = null
var _no_main_label: Label = null
var _no_side_label: Label = null
var _main_count_pending: int = 0
var _side_count_pending: int = 0


func _ready() -> void:
	_setup_style()
	_build_ui()


func setup(gig_manager: Node) -> void:
	_gig_manager = gig_manager
	_gig_manager.gig_activated.connect(_on_gig_activated)
	_gig_manager.gig_progress_updated.connect(_on_gig_progress)
	_gig_manager.gig_completed.connect(_on_gig_completed)
	for gig in _gig_manager.get_active_gigs():
		_add_card(gig)
	_auto_track()
	_update_empty()
	_update_tab_counts()
	if not _cards.is_empty() and not _expanded:
		_toggle_expanded()


func toggle() -> void:
	_toggle_expanded()


func show_panel() -> void:
	if modulate.a < 0.5:
		mouse_filter = Control.MOUSE_FILTER_STOP
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	if not _expanded:
		_toggle_expanded()


func play_slide_in() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color(1, 1, 1, 0)
	create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT) \
		.tween_property(self, "modulate:a", 1.0, 0.3).set_delay(0.3)


# ── Style ──────────────────────────────────────────────────────

func _setup_style() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	add_theme_stylebox_override("panel", s)
	mouse_filter = Control.MOUSE_FILTER_STOP


# ── Layout ─────────────────────────────────────────────────────

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Clickable header
	var title_btn := Button.new()
	title_btn.text = "// CONTRACTS  ▸"
	title_btn.flat = true
	title_btn.add_theme_color_override("font_color", ACCENT)
	title_btn.add_theme_color_override("font_hover_color", Color(ACCENT, 1.0).lightened(0.3))
	title_btn.add_theme_color_override("font_pressed_color", ACCENT)
	title_btn.add_theme_font_size_override("font_size", 16)
	title_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	title_btn.focus_mode = Control.FOCUS_NONE
	title_btn.pressed.connect(_toggle_expanded)
	vbox.add_child(title_btn)
	_title_btn = title_btn

	# Body container
	_body_container = VBoxContainer.new()
	_body_container.add_theme_constant_override("separation", 8)
	_body_container.visible = false
	_body_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_body_container)

	# Tab buttons row
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	_body_container.add_child(tab_row)

	_tab_main_btn = _create_tab_btn("MAIN", 0)
	tab_row.add_child(_tab_main_btn)
	_tab_side_btn = _create_tab_btn("SIDE", 1)
	tab_row.add_child(_tab_side_btn)

	_tab_row_ref = tab_row

	_divider = ColorRect.new()
	_divider.color = Color(ACCENT, 0.25)
	_divider.custom_minimum_size = Vector2(0, 1)
	_body_container.add_child(_divider)

	# Info overlay (building/source detail — hidden by default)
	_info_container = VBoxContainer.new()
	_info_container.visible = false
	_info_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_container.add_theme_constant_override("separation", 6)
	_body_container.add_child(_info_container)
	_info_back_btn = Button.new()
	_info_back_btn.text = "<< Back to Contracts"
	_info_back_btn.flat = true
	_info_back_btn.add_theme_font_size_override("font_size", 12)
	_info_back_btn.add_theme_color_override("font_color", ACCENT)
	_info_back_btn.add_theme_color_override("font_hover_color", BRIGHT)
	_info_back_btn.pressed.connect(hide_info)
	_info_container.add_child(_info_back_btn)
	_info_title = Label.new()
	_info_title.add_theme_font_size_override("font_size", 18)
	_info_container.add_child(_info_title)
	_info_desc = Label.new()
	_info_desc.add_theme_font_size_override("font_size", 12)
	_info_desc.add_theme_color_override("font_color", DIM)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_container.add_child(_info_desc)
	var info_sep := HSeparator.new()
	info_sep.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	_info_container.add_child(info_sep)
	_info_stats = RichTextLabel.new()
	_info_stats.bbcode_enabled = true
	_info_stats.fit_content = true
	_info_stats.scroll_active = false
	_info_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_stats.add_theme_font_size_override("normal_font_size", 14)
	_info_container.add_child(_info_stats)
	# Filter dropdown (shown for Classifier/Separator/Scanner/Producer)
	_info_dropdown = OptionButton.new()
	_info_dropdown.add_theme_font_size_override("font_size", 14)
	_info_dropdown.visible = false
	_info_dropdown.item_selected.connect(_on_info_filter_changed)
	_info_container.add_child(_info_dropdown)
	# Data flow display (input → output)
	_info_flow = RichTextLabel.new()
	_info_flow.bbcode_enabled = true
	_info_flow.fit_content = true
	_info_flow.scroll_active = false
	_info_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_flow.add_theme_font_size_override("normal_font_size", 13)
	_info_container.add_child(_info_flow)

	# Scroll container — fills remaining space
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_container.add_child(_scroll)

	# Main gig container (visible by default)
	_main_container = VBoxContainer.new()
	_main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_container.add_theme_constant_override("separation", 10)
	_scroll.add_child(_main_container)

	_no_main_label = Label.new()
	_no_main_label.text = "No active missions"
	_no_main_label.add_theme_color_override("font_color", DIM)
	_no_main_label.add_theme_font_size_override("font_size", 14)
	_no_main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_container.add_child(_no_main_label)

	# Side gig container (hidden by default)
	_side_container = VBoxContainer.new()
	_side_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_container.add_theme_constant_override("separation", 10)
	_side_container.visible = false
	_scroll.add_child(_side_container)

	_no_side_label = Label.new()
	_no_side_label.text = "No active contracts"
	_no_side_label.add_theme_color_override("font_color", DIM)
	_no_side_label.add_theme_font_size_override("font_size", 14)
	_no_side_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_side_container.add_child(_no_side_label)

	# Upgrade container
	_upgrade_container = VBoxContainer.new()
	_upgrade_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_container.add_theme_constant_override("separation", 6)
	_upgrade_container.visible = false
	_scroll.add_child(_upgrade_container)
	_build_upgrade_ui()

	_update_tab_visuals()


func _create_tab_btn(label: String, tab_idx: int) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 13)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_switch_tab.bind(tab_idx))
	# Style will be applied by _update_tab_visuals
	return btn


func _style_tab_btn(btn: Button, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 2
	s.corner_radius_bottom_right = 2
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	if active:
		s.bg_color = TAB_ACTIVE_BG
		s.border_color = ACCENT
		s.border_width_bottom = 2
		btn.add_theme_color_override("font_color", BRIGHT)
		btn.add_theme_color_override("font_hover_color", BRIGHT)
	else:
		s.bg_color = TAB_INACTIVE_BG
		s.border_color = Color(0.2, 0.25, 0.3, 0.4)
		s.border_width_bottom = 1
		btn.add_theme_color_override("font_color", DIM)
		btn.add_theme_color_override("font_hover_color", Color(DIM).lightened(0.2))
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_stylebox_override("pressed", s)


# ── Tab Switching ─────────────────────────────────────────────

func _switch_tab(tab_idx: int) -> void:
	if _active_tab == tab_idx:
		return
	_active_tab = tab_idx
	_update_tab_visuals()


func _update_tab_visuals() -> void:
	_style_tab_btn(_tab_main_btn, _active_tab == 0)
	_style_tab_btn(_tab_side_btn, _active_tab == 1)
	_main_container.visible = (_active_tab == 0)
	_side_container.visible = (_active_tab == 1)


func _update_tab_counts() -> void:
	var main_count: int = 0
	var side_count: int = 0
	for order in _cards:
		var cd: Dictionary = _cards[order]
		if cd.gig.is_tutorial:
			main_count += 1
		else:
			side_count += 1
	_tab_main_btn.text = "MAIN" if main_count == 0 else "MAIN (%d)" % main_count
	_tab_side_btn.text = "SIDE" if side_count == 0 else "SIDE (%d)" % side_count


func _get_container_for(gig) -> VBoxContainer:
	return _main_container if gig.is_tutorial else _side_container


# ── Card Creation ──────────────────────────────────────────────

func _add_card(gig) -> void:
	var order: int = gig.order_index
	if _cards.has(order):
		return
	var prog: Array = _gig_manager.get_progress(gig)
	var tcol: Color = MISSION_CLR if gig.is_tutorial else CONTRACT_CLR
	var tracked: bool = (order == _tracked_order)

	var card := PanelContainer.new()
	_style_card(card, tcol, tracked)
	var target_container := _get_container_for(gig)
	target_container.add_child(card)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)

	# Header: badge + name
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	cv.add_child(hdr)

	var badge := Label.new()
	badge.text = "MISSION" if gig.is_tutorial else "CONTRACT"
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", tcol)
	hdr.add_child(badge)

	var name_l := Label.new()
	name_l.text = gig.gig_name
	name_l.add_theme_font_size_override("font_size", 17)
	name_l.add_theme_color_override("font_color", BRIGHT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(name_l)

	# Description
	if gig.description != "":
		var parts: PackedStringArray = gig.description.split("\n\n", true, 1)
		if parts.size() == 2:
			var client_l := Label.new()
			client_l.text = parts[0]
			client_l.add_theme_font_size_override("font_size", 12)
			client_l.add_theme_color_override("font_color", CLIENT_CLR)
			client_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(client_l)
			var desc := Label.new()
			desc.text = parts[1]
			desc.add_theme_font_size_override("font_size", 12)
			desc.add_theme_color_override("font_color", DIM)
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(desc)
		else:
			var desc := Label.new()
			desc.text = gig.description
			desc.add_theme_font_size_override("font_size", 12)
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

		var req_wrap := PanelContainer.new()
		var rw_style := StyleBoxFlat.new()
		rw_style.bg_color = Color(0.08, 0.12, 0.18, 0.6)
		rw_style.corner_radius_top_left = 3
		rw_style.corner_radius_top_right = 3
		rw_style.corner_radius_bottom_left = 3
		rw_style.corner_radius_bottom_right = 3
		rw_style.content_margin_left = 8
		rw_style.content_margin_right = 8
		rw_style.content_margin_top = 6
		rw_style.content_margin_bottom = 6
		req_wrap.add_theme_stylebox_override("panel", rw_style)
		cv.add_child(req_wrap)

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		req_wrap.add_child(row)

		var lr := HBoxContainer.new()
		row.add_child(lr)

		var rl := RichTextLabel.new()
		rl.bbcode_enabled = true
		rl.fit_content = true
		rl.scroll_active = false
		rl.text = _req_bbcode(req, done)
		rl.add_theme_font_size_override("normal_font_size", 15)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lr.add_child(rl)

		var cl := Label.new()
		cl.text = "%d / %d" % [cur, tgt]
		cl.add_theme_font_size_override("font_size", 15)
		cl.add_theme_color_override("font_color", DONE_CLR if done else BRIGHT)
		lr.add_child(cl)

		var bc := Control.new()
		bc.custom_minimum_size = Vector2(0, 6)
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

		var stall_l := Label.new()
		stall_l.text = ""
		stall_l.add_theme_font_size_override("font_size", 11)
		stall_l.add_theme_color_override("font_color", STALL_CLR)
		stall_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stall_l.visible = false
		row.add_child(stall_l)

		bars.append({"rl": rl, "cl": cl, "fl": fl, "tgt": tgt, "stall_l": stall_l, "req": req})

	_init_stall_tracking(order, gig.requirements.size())

	# Reward buildings
	if gig.reward_buildings.size() > 0:
		var rr := HBoxContainer.new()
		rr.add_theme_constant_override("separation", 4)
		cv.add_child(rr)
		var arrow := _lbl("▸", REWARD_CLR, 13)
		rr.add_child(arrow)
		var rtxt := _lbl("Unlocks: %s" % ", ".join(gig.reward_buildings), REWARD_CLR, 13)
		rr.add_child(rtxt)

	_cards[order] = {"root": card, "bars": bars, "name_l": name_l, "gig": gig}

	# Fade-in
	card.modulate = Color(1, 1, 1, 0)
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) \
		.tween_property(card, "modulate:a", 1.0, 0.35)

	_update_tab_counts()

	# Auto-switch to the tab that has new content
	if gig.is_tutorial and _active_tab != 0:
		_switch_tab(0)
	elif not gig.is_tutorial and _active_tab != 1:
		# Only auto-switch to SIDE if no main gigs active
		var has_main: bool = false
		for o in _cards:
			if _cards[o].gig.is_tutorial:
				has_main = true
				break
		if not has_main:
			_switch_tab(1)


func _style_card(card: PanelContainer, accent: Color, tracked: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = CARD_BG
	s.border_color = accent
	s.border_width_left = 4
	s.corner_radius_top_left = 2
	s.corner_radius_bottom_left = 2
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_right = 2
	s.content_margin_left = 12
	s.content_margin_right = 10
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if tracked:
		s.shadow_color = TRACKED_GLOW
		s.shadow_size = 6
	card.add_theme_stylebox_override("panel", s)


# ── Signal Handlers ────────────────────────────────────────────

func _on_gig_activated(gig) -> void:
	_add_card(gig)
	_auto_track()
	_update_empty()
	if not _expanded:
		_toggle_expanded()


func _on_gig_progress(gig, ri: int, cur: int, tgt: int) -> void:
	var d: Dictionary = _cards.get(gig.order_index, {})
	if d.is_empty() or ri >= d.bars.size():
		return
	var b: Dictionary = d.bars[ri]
	var done: bool = cur >= tgt

	b.cl.text = "%d / %d" % [cur, tgt]
	b.cl.add_theme_color_override("font_color", DONE_CLR if done else BRIGHT)
	if b.has("req"):
		b.rl.text = _req_bbcode(b.req, done)

	if _stall_timers.has(gig.order_index):
		var timers: Array = _stall_timers[gig.order_index]
		if ri < timers.size():
			timers[ri] = 0.0
	if b.has("stall_l") and is_instance_valid(b.stall_l):
		b.stall_l.visible = false

	var ratio: float = clampf(float(cur) / maxi(tgt, 1), 0.0, 1.0)
	b.fl.color = DONE_CLR if done else BAR_FILL
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) \
		.tween_property(b.fl, "anchor_right", ratio, 0.25)

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
	_stall_timers.erase(order)
	_auto_track()
	_update_empty()
	_update_tab_counts()


func _auto_track() -> void:
	_tracked_order = -1
	if _gig_manager == null:
		return
	for gig in _gig_manager.get_active_gigs():
		if gig.is_tutorial:
			_tracked_order = gig.order_index
			break
	if _tracked_order < 0:
		var a: Array = _gig_manager.get_active_gigs()
		if a.size() > 0:
			_tracked_order = a[0].order_index
	for order in _cards:
		var cd = _cards[order]
		var tcol: Color = MISSION_CLR if cd.gig.is_tutorial else CONTRACT_CLR
		_style_card(cd.root, tcol, order == _tracked_order)


func rebuild_from_state() -> void:
	for order in _cards:
		var cd = _cards[order]
		if is_instance_valid(cd.root):
			cd.root.queue_free()
	_cards.clear()
	_stall_timers.clear()
	_tracked_order = -1
	if _gig_manager:
		for gig in _gig_manager.get_active_gigs():
			_add_card(gig)
	_auto_track()
	_update_empty()
	_update_tab_counts()
	if not _cards.is_empty() and not _expanded:
		_toggle_expanded()
	# Auto-switch to tab with content
	var has_main: bool = false
	var has_side: bool = false
	for order in _cards:
		if _cards[order].gig.is_tutorial:
			has_main = true
		else:
			has_side = true
	if has_main:
		_switch_tab(0)
	elif has_side:
		_switch_tab(1)


func _update_empty() -> void:
	var main_has_cards: bool = false
	var side_has_cards: bool = false
	for order in _cards:
		if _cards[order].gig.is_tutorial:
			main_has_cards = true
		else:
			side_has_cards = true
	if _no_main_label:
		_no_main_label.visible = not main_has_cards
	if _no_side_label:
		_no_side_label.visible = not side_has_cards


func _req_text(req) -> String:
	return req.label if req.label != "" else "Data"


func _req_bbcode(req, done: bool) -> String:
	if done:
		return "[color=#44ff88]%s[/color]" % _req_text(req)

	var c_hex: String = DataEnums.content_color_hex(req.content)
	var c_char: String = DataEnums.content_char(req.content)
	if req.content == DataEnums.ContentType.STANDARD:
		c_char = "0"
	var c_name: String = DataEnums.content_name(req.content)
	var result: String = "[color=%s][%s] %s[/color]" % [c_hex, c_char, c_name]

	if req.tags != 0:
		var tag_parts: PackedStringArray = []
		if req.tags & DataEnums.ProcessingTag.DECRYPTED:
			tag_parts.append("[color=#22ccff]Decrypted[/color]")
		if req.tags & DataEnums.ProcessingTag.RECOVERED:
			tag_parts.append("[color=#66dd44]Recovered[/color]")
		if req.tags & DataEnums.ProcessingTag.ENCRYPTED:
			tag_parts.append("[color=#2288ff]Encrypted[/color]")
		result += " " + "·".join(tag_parts)
	elif req.state == DataEnums.DataState.PUBLIC:
		result += " [color=#00ffaa]Public[/color]"
	elif req.state >= 0:
		var s_hex: String = DataEnums.state_color_hex(req.state)
		result += " [color=%s]%s[/color]" % [s_hex, DataEnums.state_name(req.state)]

	return result


func _toggle_expanded() -> void:
	_expanded = not _expanded
	_body_container.visible = _expanded
	_title_btn.text = "// CONTRACTS  ▾" if _expanded else "// CONTRACTS  ▸"
	if _expanded:
		_apply_panel_style(PANEL_BG)
	else:
		_apply_panel_style(Color(0, 0, 0, 0))


func _apply_panel_style(bg: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	if bg.a > 0.1:
		s.border_color = BORDER_CLR
		s.border_width_right = 2
		s.corner_radius_top_right = 4
		s.corner_radius_bottom_right = 4
		s.shadow_color = Color(0.0, 0.4, 0.6, 0.08)
		s.shadow_size = 8
	add_theme_stylebox_override("panel", s)


func _gui_input(event: InputEvent) -> void:
	if _expanded and event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
				MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			accept_event()


func _lbl(text: String, color: Color, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


# ── Stall Detection ──────────────────────────────────────────

const STALL_HINTS: Dictionary = {
	1: ["Draw a cable from a source's output port to the Contract Terminal"],
	2: ["Use a Separator (set to Public with E) to filter out Corrupted data"],
	3: ["Chain Separator + Classifier to filter both state and content", "Both Financial and Biometric need to reach the Terminal"],
	4: ["Find a source carrying Research data — Hospital Terminal is south of center"],
	5: ["Recoverer needs TWO inputs: Corrupted data from left, Repair Kit from top (Repair Lab makes kits)"],
	6: ["Decryptor needs Encrypted data from left, Key from top (Key Forge makes Keys from Research data)"],
	7: ["Decrypt first, then Encrypt — both need Keys. The data gets Decrypted AND Encrypted tags"],
	8: ["Use all your tools — multiple sources and processing chains may be needed"],
}


func _process(delta: float) -> void:
	# Update stall timers for active cards
	for order in _cards:
		var cd: Dictionary = _cards[order]
		var gig = cd.gig
		if not _stall_timers.has(order):
			continue
		var timers: Array = _stall_timers[order]
		var prog: Array = _gig_manager.get_progress(gig) if _gig_manager else []
		for i in range(timers.size()):
			var cur: int = prog[i] if i < prog.size() else 0
			var tgt: int = gig.requirements[i].amount if i < gig.requirements.size() else 1
			if cur >= tgt:
				continue
			timers[i] += delta
			if timers[i] >= STALL_TIME and i < cd.bars.size():
				var stall_l: Label = cd.bars[i].get("stall_l")
				if stall_l and not stall_l.visible:
					var hints: Array = STALL_HINTS.get(order, [])
					if i < hints.size():
						stall_l.text = "? %s" % hints[i]
					elif hints.size() > 0:
						stall_l.text = "? %s" % hints[0]
					else:
						stall_l.text = "? No progress — check your pipeline"
					stall_l.visible = true
					if cd.bars[i].has("fl"):
						cd.bars[i].fl.color = STALL_CLR


func _init_stall_tracking(order: int, req_count: int) -> void:
	var timers: Array = []
	for _i in range(req_count):
		timers.append(0.0)
	_stall_timers[order] = timers


# ── Info Overlay (Building/Source Detail) ──────────────────────

func show_building_info(building: Node2D) -> void:
	if building == null or building.definition == null:
		return
	_info_target = building
	_info_active = true
	_info_title.text = building.definition.building_name
	_info_title.add_theme_color_override("font_color", building.definition.color)
	_info_desc.text = building.definition.description
	# Show upgrade buttons inline for CT
	var is_ct: bool = building.definition.category == "terminal"
	if is_ct and _upgrade_container.get_parent() != _info_container:
		_upgrade_container.get_parent().remove_child(_upgrade_container)
		_info_container.add_child(_upgrade_container)
	_upgrade_container.visible = is_ct
	_show_info_overlay()
	_update_info()


func show_source_info(source: Node2D) -> void:
	if source == null or source.definition == null:
		return
	_info_target = source
	_info_active = true
	_info_title.text = source.definition.source_name
	_info_title.add_theme_color_override("font_color", source.definition.color)
	_info_desc.text = source.definition.description
	_show_info_overlay()
	_update_info()


func hide_info() -> void:
	_info_active = false
	_info_target = null
	_info_container.visible = false
	# Return upgrade container to scroll if it was reparented
	if _upgrade_container.get_parent() == _info_container:
		_info_container.remove_child(_upgrade_container)
		_scroll.add_child(_upgrade_container)
	_upgrade_container.visible = false
	_tab_row_ref.visible = true
	_scroll.visible = true
	_divider.visible = true
	_update_tab_visuals()


func _show_info_overlay() -> void:
	## Show info, hide tabs and scroll
	_info_container.visible = true
	_tab_row_ref.visible = false
	_scroll.visible = false
	_divider.visible = false
	# Ensure panel is visible and expanded
	if not _expanded:
		_toggle_expanded()
	show_panel()


func _update_info() -> void:
	if _info_target == null or not is_instance_valid(_info_target):
		hide_info()
		return
	var lines: PackedStringArray = []
	var def = _info_target.definition
	if def is BuildingDefinition:
		_update_info_building(lines, _info_target, def)
		_populate_info_dropdown(_info_target, def)
		_update_info_flow(_info_target)
	else:
		_update_info_source(lines, _info_target, def)
		_info_dropdown.visible = false
		_info_flow.text = ""
	_info_stats.text = "\n".join(lines)


func _update_info_building(lines: PackedStringArray, b: Node2D, def: BuildingDefinition) -> void:
	# Status
	if b.is_working:
		lines.append("[color=#44ff88]● Working[/color]")
	else:
		var reason: String = b.status_reason if b.status_reason != "" else ""
		lines.append("[color=#ffcc44]● Idle%s[/color]" % (" — " + reason if reason != "" else ""))

	# Throughput / type info
	if def.classifier:
		lines.append("[color=#667788]Throughput:[/color] %d MB/s" % int(b.get_effective_value("processing_rate")))
		lines.append("[color=#667788]Filter:[/color] [color=#44ff88]%s[/color] → right, rest → bottom" % DataEnums.content_name(b.classifier_filter_content))
	if def.scanner:
		lines.append("[color=#667788]Throughput:[/color] %d MB/s" % int(def.scanner.throughput_rate))
		if b.scanner_filter_sub_type >= 0:
			var sc: int = b.scanner_filter_sub_type / 4
			var so: int = b.scanner_filter_sub_type % 4
			lines.append("[color=#667788]Filter:[/color] [color=%s]%s[/color] → right, rest → bottom" % [DataEnums.content_color_hex(sc), DataEnums.sub_type_name(sc, so)])
		else:
			lines.append("[color=#667788]Filter:[/color] [color=#ffcc44]None (press Tab)[/color]")
	if def.processor and def.processor.rule == "separator":
		lines.append("[color=#667788]Throughput:[/color] %d MB/s" % int(b.get_effective_value("processing_rate")))
		var fname: String = DataEnums.state_name(b.separator_filter_value) if b.separator_mode == "state" else DataEnums.content_name(b.separator_filter_value)
		lines.append("[color=#667788]Filter:[/color] [color=#44ff88]%s[/color] → right, rest → bottom" % fname)
	if def.dual_input:
		lines.append("[color=#667788]Throughput:[/color] %d MB/s" % int(b.get_effective_value("processing_rate")))
		if def.dual_input.fuel_matches_content:
			lines.append("[color=#667788]Mode:[/color] Recoverer — Repair Kit from top")
		elif def.dual_input.output_tag == 4:
			lines.append("[color=#667788]Mode:[/color] Encryptor — Key from top")
		else:
			lines.append("[color=#667788]Mode:[/color] Decryptor — Key from top")
		# Key/Kit stock
		var cname: String = DataEnums.content_name(def.dual_input.key_content)
		var stock_parts: PackedStringArray = []
		for kt in range(1, 4):
			var kk: int = DataEnums.pack_key(def.dual_input.key_content, DataEnums.DataState.PUBLIC, kt, 0)
			var count: int = b.stored_data.get(kk, 0)
			if count > 0:
				stock_parts.append("T%d: %d" % [kt, count])
		lines.append("[color=#667788]%s Stock:[/color] %s" % [cname, ", ".join(stock_parts) if not stock_parts.is_empty() else "[color=#ff6644]0[/color]"])
	if def.producer:
		lines.append("[color=#667788]Rate:[/color] %d/tick" % int(b.get_effective_value("processing_rate")))
		lines.append("[color=#667788]Tier:[/color] T%d" % b.selected_tier)
	if def.processor and def.processor.rule == "trash":
		lines.append("[color=#667788]Mode:[/color] Instant destruction")
	if def.splitter:
		lines.append("[color=#667788]Mode:[/color] Split 50/50")
	if def.merger:
		lines.append("[color=#667788]Mode:[/color] Merge inputs → right")

	# Stored data
	var total: int = b.get_total_stored()
	if total > 0:
		var cap: int = int(b.get_effective_value("capacity")) if b.has_method("get_effective_value") else 0
		lines.append("")
		lines.append("[color=#667788]Stored:[/color] %d%s MB" % [total, " / %d" % cap if cap > 0 else ""])
		for key in b.stored_data:
			if b.stored_data[key] <= 0:
				continue
			var c: int = DataEnums.unpack_content(key)
			var s: int = DataEnums.unpack_state(key)
			var label: String = DataEnums.data_label(c, s, DataEnums.unpack_tier(key), DataEnums.unpack_tags(key))
			lines.append("  [color=%s]%d[/color] [color=%s]%s[/color]" % [DataEnums.state_color_hex(s), b.stored_data[key], DataEnums.content_color_hex(c), label])

	# CT: show upgrades inline
	if def.category == "terminal" and _upgrade_manager:
		lines.append("")
		lines.append("[color=#44ccff]── UPGRADES ──[/color]")
		_refresh_upgrade_ui()


func _update_info_source(lines: PackedStringArray, src: Node2D, def) -> void:
	# Difficulty
	var diff_colors: Dictionary = {"easy": "#44ff66", "medium": "#ffee44", "hard": "#ff9933", "endgame": "#ff4444"}
	var dc: String = diff_colors.get(def.difficulty, "#aabbcc")
	lines.append("[color=%s]%s[/color]  |  %d MB/s  |  %d ports" % [dc, def.difficulty.to_upper(), int(def.bandwidth), src.output_ports.size()])

	# FIRE
	if src.has_fire():
		lines.append("")
		var fc: String = "#ff4422" if src.fire_active else "#44ff66"
		var fs: String = "ACTIVE" if src.fire_active else "BREACHED"
		var ft: String = "Threshold" if def.fire_type == "threshold" else "Regenerating"
		lines.append("[color=%s]FIRE: %s[/color] (%s)" % [fc, fs, ft])
		for req in def.fire_requirements:
			var st: int = int(req.sub_type)
			var content: int = st / 4
			var offset: int = st % 4
			var rn: String = DataEnums.sub_type_name(content, offset)
			var cc: String = DataEnums.content_color_hex(content)
			var cur: float = src.fire_progress.get(st, 0.0)
			lines.append("  Needs [color=%s]%s[/color] — %d / %d MB" % [cc, rn, int(cur), int(req.amount)])
		if def.fire_type == "regen":
			lines.append("  [color=#ff8844]Regen: %.0f MB/s[/color]" % def.fire_regen_rate)

	# Content
	lines.append("")
	lines.append("[color=#667788]Content:[/color]")
	for cid in def.content_weights:
		var pct: int = int(def.content_weights[cid] * 100)
		lines.append("  [color=%s]%d%% %s[/color]" % [DataEnums.content_color_hex(int(cid)), pct, DataEnums.content_name(int(cid))])

	# State
	var sw: Dictionary = src.instance_state_weights if not src.instance_state_weights.is_empty() else def.state_weights
	lines.append("[color=#667788]State:[/color]")
	for sid in sw:
		var pct: int = int(sw[sid] * 100)
		lines.append("  [color=%s]%d%% %s[/color]" % [DataEnums.state_color_hex(int(sid)), pct, DataEnums.state_name(int(sid))])

	# Sub-types
	if not def.sub_type_pool.is_empty():
		lines.append("[color=#667788]Sub-Types:[/color]")
		for entry in def.sub_type_pool:
			var c: int = int(entry.get("content", 0))
			var st: int = int(entry.get("sub_type", 0))
			lines.append("  [color=%s]%s[/color]" % [DataEnums.content_color_hex(c), DataEnums.sub_type_name(c, st)])


# ── Filter Dropdown + Data Flow ────────────────────────────────

func _populate_info_dropdown(b: Node2D, def: BuildingDefinition) -> void:
	_info_dropdown.clear()
	_info_dropdown.visible = false
	if def.classifier:
		_info_dropdown.visible = true
		for c in range(6):
			var label: String = "%s  %s" % [DataEnums.content_char(c), DataEnums.content_name(c)]
			_info_dropdown.add_item(label, c)
			_info_dropdown.set_item_icon(c, _make_color_icon(DataEnums.content_color(c)))
		_info_dropdown.selected = b.classifier_filter_content
	elif def.processor and def.processor.rule == "separator":
		_info_dropdown.visible = true
		if b.separator_mode == "state":
			var states: Array[int] = [0, 1, 2]
			for i in range(states.size()):
				_info_dropdown.add_item(DataEnums.state_name(states[i]), states[i])
				_info_dropdown.set_item_icon(i, _make_color_icon(DataEnums.state_color(states[i])))
			var idx: int = states.find(b.separator_filter_value)
			_info_dropdown.selected = maxi(idx, 0)
		else:
			for c in range(6):
				var label: String = "%s  %s" % [DataEnums.content_char(c), DataEnums.content_name(c)]
				_info_dropdown.add_item(label, c)
				_info_dropdown.set_item_icon(c, _make_color_icon(DataEnums.content_color(c)))
			_info_dropdown.selected = b.separator_filter_value
	elif def.scanner:
		_info_dropdown.visible = true
		var seen: Dictionary = {}
		for key in b.stored_data:
			if b.stored_data[key] > 0:
				var c: int = DataEnums.unpack_content(key)
				var st: int = DataEnums.unpack_sub_type(key)
				if st >= 0:
					seen[c * 4 + st] = true
		var idx: int = 0
		var sel: int = 0
		for pid in seen:
			var c: int = pid / 4
			var st: int = pid % 4
			var sname: String = DataEnums.sub_type_name(c, st)
			if sname.is_empty():
				sname = "%s #%d" % [DataEnums.content_name(c), st]
			_info_dropdown.add_item("%s  %s" % [DataEnums.content_char(c), sname], pid)
			_info_dropdown.set_item_icon(idx, _make_color_icon(DataEnums.content_color(c)))
			if pid == b.scanner_filter_sub_type:
				sel = idx
			idx += 1
		if _info_dropdown.item_count > 0:
			_info_dropdown.selected = sel
	elif def.producer and def.producer.max_tier > 1:
		_info_dropdown.visible = true
		for t in range(1, def.producer.max_tier + 1):
			_info_dropdown.add_item("Tier %d" % t, t)
		_info_dropdown.selected = b.selected_tier - 1


func _make_color_icon(color: Color) -> ImageTexture:
	## Create a small colored square icon for dropdown items.
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
		_info_dropdown.selected = b.selected_tier - 1


func _on_info_filter_changed(idx: int) -> void:
	if _info_target == null or not is_instance_valid(_info_target):
		return
	var def = _info_target.definition
	if not (def is BuildingDefinition):
		return
	var value: int = _info_dropdown.get_item_id(idx)
	if def.classifier:
		_info_target.classifier_filter_content = value
	elif def.processor and def.processor.rule == "separator":
		_info_target.separator_filter_value = value
	elif def.scanner:
		_info_target.scanner_filter_sub_type = value
	elif def.producer:
		_info_target.selected_tier = value
	_update_info()


func _update_info_flow(b: Node2D) -> void:
	## Show input data types and output data types based on connections.
	if _connection_manager == null:
		_info_flow.text = ""
		return
	var bid: int = b.get_instance_id()
	var lines: PackedStringArray = []

	# Input: data types on cables coming INTO this building
	var input_types: Dictionary = {}  # packed_key → total amount
	for conn in _connection_manager.connections:
		if conn.to_building == b:
			for ti in conn.get("transit", []):
				var key: int = int(ti.key)
				input_types[key] = input_types.get(key, 0) + int(ti.amount)
	# Also count stored data as "input waiting"
	for key in b.stored_data:
		if b.stored_data[key] > 0:
			input_types[key] = input_types.get(key, 0) + b.stored_data[key]

	if not input_types.is_empty():
		lines.append("[color=#44ccff]INPUT ←[/color]")
		var seen_input: Dictionary = {}
		for key in input_types:
			var c: int = DataEnums.unpack_content(key)
			var s: int = DataEnums.unpack_state(key)
			var st: int = DataEnums.unpack_sub_type(key)
			var label_key: String = "%d_%d_%d" % [c, s, st]
			if seen_input.has(label_key):
				continue
			seen_input[label_key] = true
			var cc: String = DataEnums.content_color_hex(c)
			var sc: String = DataEnums.state_color_hex(s)
			var st_name: String = DataEnums.sub_type_name(c, st) if st >= 0 else DataEnums.content_name(c)
			var s_name: String = DataEnums.state_name(s)
			lines.append("  [color=%s]%s[/color] [color=%s]%s[/color]" % [cc, st_name, sc, s_name])

	# Output: data types on cables going FROM this building
	var output_types: Dictionary = {}
	for conn in _connection_manager.connections:
		if conn.from_building == b:
			for ti in conn.get("transit", []):
				var key: int = int(ti.key)
				var port: String = conn.from_port
				if not output_types.has(port):
					output_types[port] = {}
				output_types[port][key] = output_types[port].get(key, 0) + int(ti.amount)

	if not output_types.is_empty():
		lines.append("")
		lines.append("[color=#44ff88]OUTPUT →[/color]")
		for port in output_types:
			var port_label: String = port.replace("_", " ").capitalize()
			var seen_output: Dictionary = {}
			var port_parts: PackedStringArray = []
			for key in output_types[port]:
				var c: int = DataEnums.unpack_content(key)
				var s: int = DataEnums.unpack_state(key)
				var st: int = DataEnums.unpack_sub_type(key)
				var label_key: String = "%d_%d_%d" % [c, s, st]
				if seen_output.has(label_key):
					continue
				seen_output[label_key] = true
				var cc: String = DataEnums.content_color_hex(c)
				var sc: String = DataEnums.state_color_hex(s)
				var st_name: String = DataEnums.sub_type_name(c, st) if st >= 0 else DataEnums.content_name(c)
				var s_name: String = DataEnums.state_name(s)
				port_parts.append("[color=%s]%s[/color] [color=%s]%s[/color]" % [cc, st_name, sc, s_name])
			lines.append("  [color=#667788]%s:[/color] %s" % [port_label, ", ".join(port_parts)])

	_info_flow.text = "\n".join(lines)


# ── Upgrade Tab ────────────────────────────────────────────────

func _build_upgrade_ui() -> void:
	var cat_data: Array[Dictionary] = [
		{"key": "routing", "label": "ROUTING", "desc": "Separator, Classifier, Scanner speed", "content": [0, 1]},
		{"key": "decryption", "label": "DECRYPTION", "desc": "Decryptor, Encryptor, Key Forge speed + Key success rate", "content": [3, 5]},
		{"key": "recovery", "label": "RECOVERY", "desc": "Recoverer, Repair Lab speed + Recovery success rate", "content": [2, 4]},
		{"key": "bandwidth", "label": "BANDWIDTH", "desc": "Source generation speed + cable capacity", "content": []},
	]
	for cd in cat_data:
		var cat: String = cd.key
		# Category header with content colors
		var header := RichTextLabel.new()
		header.bbcode_enabled = true
		header.fit_content = true
		header.scroll_active = false
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_theme_font_size_override("normal_font_size", 15)
		_upgrade_container.add_child(header)
		_upgrade_info_labels[cat] = header
		# Description
		var desc := Label.new()
		desc.text = cd.desc
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_upgrade_container.add_child(desc)
		# Needs label (which content types)
		var needs := RichTextLabel.new()
		needs.bbcode_enabled = true
		needs.fit_content = true
		needs.scroll_active = false
		needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		needs.add_theme_font_size_override("normal_font_size", 12)
		var parts: PackedStringArray = []
		for cid in cd.content:
			parts.append("[color=%s]%s[/color]" % [DataEnums.content_color_hex(cid), DataEnums.content_name(cid)])
		var needs_text: String = ", ".join(parts) if not parts.is_empty() else "All processed data (25%)"
		needs.text = "[color=#556677]Needs:[/color] %s [color=#556677](Decrypted / Recovered)[/color]" % needs_text
		_upgrade_container.add_child(needs)
		# Claim button
		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 14)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.12, 0.18, 0.9)
		style.border_color = Color(0.15, 0.5, 0.4, 0.6)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = Color(0.08, 0.2, 0.25, 0.95)
		hover.border_color = Color(0.3, 0.9, 0.6, 0.8)
		btn.add_theme_stylebox_override("hover", hover)
		var dis := style.duplicate()
		dis.bg_color = Color(0.04, 0.07, 0.1, 0.6)
		dis.border_color = Color(0.12, 0.16, 0.2, 0.3)
		btn.add_theme_stylebox_override("disabled", dis)
		btn.pressed.connect(_on_upgrade_claim.bind(cat))
		_upgrade_container.add_child(btn)
		_upgrade_claim_buttons[cat] = btn
		# Spacer
		var spacer := HSeparator.new()
		spacer.add_theme_constant_override("separation", 4)
		spacer.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
		_upgrade_container.add_child(spacer)


func _on_upgrade_claim(category: String) -> void:
	if _upgrade_manager and _upgrade_manager.claim_tier_up(category):
		_refresh_upgrade_ui()


func _refresh_upgrade_ui() -> void:
	if _upgrade_manager == null:
		return
	for cat in ["routing", "decryption", "recovery", "bandwidth"]:
		var tier: int = _upgrade_manager.get_tier(cat)
		var mult: float = _upgrade_manager.get_multiplier(cat)
		var cum: float = _upgrade_manager.get_cumulative(cat)
		var next_cost: float = _upgrade_manager.get_next_tier_cost(cat)
		var claimable: bool = _upgrade_manager.is_claimable(cat)
		var tier_color: String = "#44ff88" if tier >= 3 else ("#ffcc44" if tier >= 2 else "#44ccff")
		# Update header
		if _upgrade_info_labels.has(cat):
			_upgrade_info_labels[cat].text = "[color=%s]%s  T%d[/color]  [color=#aabbcc](%.0fx speed)[/color]" % [tier_color, cat.to_upper(), tier, mult]
		# Update button
		if _upgrade_claim_buttons.has(cat):
			var btn: Button = _upgrade_claim_buttons[cat]
			btn.disabled = not claimable
			if next_cost < 0:
				btn.text = "MAXED OUT"
				btn.disabled = true
				btn.add_theme_color_override("font_color", Color(0.3, 0.4, 0.5))
			elif claimable:
				btn.text = ">> CLAIM T%d <<   (%d / %d MB)" % [tier + 1, int(cum), int(next_cost)]
				btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
			else:
				btn.text = "%d / %d MB" % [int(cum), int(next_cost)]
				btn.add_theme_color_override("font_color", Color(0.4, 0.55, 0.65))
