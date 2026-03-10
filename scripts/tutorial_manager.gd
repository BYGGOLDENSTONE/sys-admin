extends Node

## Tutorial hint system — shows contextual guidance when gigs activate,
## buildings unlock, and when the player might be stuck.

signal hint_shown(hint_text: String)
signal hint_dismissed()

const HINT_BG := Color(0.03, 0.07, 0.12, 0.95)
const HINT_BORDER := Color(0.0, 0.7, 0.9, 0.5)
const HINT_TEXT_CLR := Color(0.82, 0.88, 0.92, 1.0)
const HINT_ACCENT := Color("#00ddff")
const HINT_KEY_CLR := Color("#ffcc44")

var _ui_layer: CanvasLayer = null
var _hint_panel: PanelContainer = null
var _hint_label: RichTextLabel = null
var _hint_queue: Array[Dictionary] = []  ## {text, duration, priority}
var _current_hint: Dictionary = {}
var _dismiss_timer: float = 0.0
var _shown_hints: Dictionary = {}  ## hint_id -> true (prevents repeats)

## Gig-specific intro hints — shown when each tutorial gig activates
var _gig_hints: Dictionary = {
	1: {
		"id": "gig1_intro",
		"text": "Find a [color=#00ddff]data source[/color] nearby and place an [color=#ffcc44]Uplink[/color] next to it.\nConnect the Uplink to the [color=#00ddff]Contract Terminal[/color] with a cable.",
		"duration": 12.0,
	},
	2: {
		"id": "gig2_intro",
		"text": "Your new [color=#ffcc44]Classifier[/color] filters data by [color=#00ddff]content type[/color].\nSelected type exits [color=#00ddff]right[/color], everything else exits [color=#00ddff]bottom[/color]. Press [color=#ffcc44]TAB[/color] to change filter.",
		"duration": 14.0,
	},
	3: {
		"id": "gig3_intro",
		"text": "The [color=#ffcc44]Separator[/color] filters by [color=#00ddff]data state[/color] instead of content.\nUse it to split [color=#00ddff]Public[/color] from [color=#00ddff]Corrupted[/color] data. Press [color=#ffcc44]TAB[/color] to change filter.",
		"duration": 14.0,
	},
	4: {
		"id": "gig4_intro",
		"text": "The [color=#ffcc44]Recoverer[/color] repairs Corrupted data using [color=#00ddff]fuel[/color].\nFeed [color=#00ddff]data[/color] from the left, [color=#00ddff]Public fuel[/color] from the top. Both inputs needed!",
		"duration": 14.0,
	},
	5: {
		"id": "gig5_intro",
		"text": "Build a [color=#ffcc44]Research Lab[/color] to produce [color=#00ddff]Keys[/color], then a [color=#ffcc44]Decryptor[/color] to unlock Encrypted data.\nDecryptor needs [color=#00ddff]data[/color] from left and a [color=#00ddff]Key[/color] from top.",
		"duration": 14.0,
	},
	6: {
		"id": "gig6_intro",
		"text": "The [color=#ffcc44]Encryptor[/color] re-encrypts processed data using a [color=#00ddff]Key[/color].\nFirst [color=#00ddff]decrypt[/color], then run through [color=#ffcc44]Encryptor[/color] — same Key supply as Decryptor.",
		"duration": 14.0,
	},
	7: {
		"id": "gig7_intro",
		"text": "The [color=#ffcc44]Compiler[/color] combines [color=#00ddff]two different data types[/color] into one [color=#00ddff]Packet[/color].\nFeed one type from [color=#00ddff]left[/color], another from [color=#00ddff]top[/color].",
		"duration": 14.0,
	},
}

## Building unlock descriptions — shown when a building unlocks
var _building_hints: Dictionary = {
	"Classifier": {
		"id": "unlock_classifier",
		"text": "[color=#ffcc44]CLASSIFIER[/color] unlocked — filters data by [color=#00ddff]content type[/color].\nInput: [color=#00ddff]left[/color]  |  Filtered: [color=#00ddff]right[/color]  |  Rest: [color=#00ddff]bottom[/color]",
		"duration": 8.0,
	},
	"Separator": {
		"id": "unlock_separator",
		"text": "[color=#ffcc44]SEPARATOR[/color] unlocked — filters data by [color=#00ddff]state[/color] (Public, Encrypted, Corrupted).\nInput: [color=#00ddff]left[/color]  |  Filtered: [color=#00ddff]right[/color]  |  Rest: [color=#00ddff]bottom[/color]",
		"duration": 8.0,
	},
	"Recoverer": {
		"id": "unlock_recoverer",
		"text": "[color=#ffcc44]RECOVERER[/color] unlocked — repairs Corrupted data.\nData: [color=#00ddff]left[/color]  |  Fuel: [color=#00ddff]top[/color]  |  Output: [color=#00ddff]right[/color]",
		"duration": 8.0,
	},
	"Research Lab": {
		"id": "unlock_research_lab",
		"text": "[color=#ffcc44]RESEARCH LAB[/color] unlocked — produces Decryption Keys.\nPress [color=#ffcc44]TAB[/color] to select Key tier. Higher tier = more ingredients needed.",
		"duration": 8.0,
	},
	"Decryptor": {
		"id": "unlock_decryptor",
		"text": "[color=#ffcc44]DECRYPTOR[/color] unlocked — breaks encryption on data.\nEncrypted data: [color=#00ddff]left[/color]  |  Key: [color=#00ddff]top[/color]  |  Output: [color=#00ddff]right[/color]",
		"duration": 8.0,
	},
	"Encryptor": {
		"id": "unlock_encryptor",
		"text": "[color=#ffcc44]ENCRYPTOR[/color] unlocked — re-encrypts processed data.\nData: [color=#00ddff]left[/color]  |  Key: [color=#00ddff]top[/color]  |  Output: [color=#00ddff]right[/color]",
		"duration": 8.0,
	},
	"Compiler": {
		"id": "unlock_compiler",
		"text": "[color=#ffcc44]COMPILER[/color] unlocked — packages two data types into one Packet.\nType A: [color=#00ddff]left[/color]  |  Type B: [color=#00ddff]top[/color]  |  Packet: [color=#00ddff]right[/color]",
		"duration": 8.0,
	},
}


func setup(ui_layer: CanvasLayer) -> void:
	_ui_layer = ui_layer
	_build_hint_panel()


func _build_hint_panel() -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Position: top-center, below notifications
	_hint_panel.anchor_left = 0.5
	_hint_panel.anchor_right = 0.5
	_hint_panel.anchor_top = 0.0
	_hint_panel.anchor_bottom = 0.0
	_hint_panel.offset_left = -220.0
	_hint_panel.offset_right = 220.0
	_hint_panel.offset_top = 50.0
	_hint_panel.offset_bottom = 50.0
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_END

	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = HINT_BG
	style.border_color = HINT_BORDER
	style.border_width_top = 2
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0.0, 0.5, 0.7, 0.1)
	style.shadow_size = 10
	_hint_panel.add_theme_stylebox_override("panel", style)

	# Layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_hint_panel.add_child(vbox)

	# Hint text (RichTextLabel for BBCode colors)
	_hint_label = RichTextLabel.new()
	_hint_label.bbcode_enabled = true
	_hint_label.fit_content = true
	_hint_label.scroll_active = false
	_hint_label.add_theme_font_size_override("normal_font_size", 13)
	_hint_label.add_theme_color_override("default_color", HINT_TEXT_CLR)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_hint_label)

	# Dismiss label
	var dismiss := Label.new()
	dismiss.text = "click to dismiss"
	dismiss.add_theme_font_size_override("font_size", 9)
	dismiss.add_theme_color_override("font_color", Color(0.4, 0.5, 0.55, 0.5))
	dismiss.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dismiss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(dismiss)

	_hint_panel.visible = false
	_hint_panel.modulate = Color(1, 1, 1, 0)
	_ui_layer.add_child(_hint_panel)

	# Click to dismiss
	_hint_panel.gui_input.connect(_on_hint_clicked)


func _on_hint_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		dismiss_current()


func show_hint(text: String, duration: float = 10.0, hint_id: String = "", priority: int = 0) -> void:
	# Don't repeat the same hint
	if hint_id != "" and _shown_hints.has(hint_id):
		return

	var hint := {"text": text, "duration": duration, "id": hint_id, "priority": priority}

	# If nothing showing, display immediately
	if _current_hint.is_empty():
		_display_hint(hint)
	else:
		# Higher priority replaces current; same/lower queues
		if priority > _current_hint.get("priority", 0):
			_hint_queue.push_front(_current_hint)
			_display_hint(hint)
		else:
			_hint_queue.append(hint)


func dismiss_current() -> void:
	if _current_hint.is_empty():
		return
	_current_hint = {}
	_dismiss_timer = 0.0
	# Fade out
	var tw := create_tween()
	tw.tween_property(_hint_panel, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		_hint_panel.visible = false
		hint_dismissed.emit()
		_show_next_queued()
	)


func _display_hint(hint: Dictionary) -> void:
	_current_hint = hint
	_dismiss_timer = hint.duration
	if hint.id != "":
		_shown_hints[hint.id] = true

	_hint_label.text = hint.text
	_hint_panel.visible = true

	# Animate in
	_hint_panel.modulate = Color(1, 1, 1, 0)
	_hint_panel.offset_top = 40.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hint_panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(_hint_panel, "offset_top", 50.0, 0.3)
	hint_shown.emit(hint.text)


func _show_next_queued() -> void:
	if _hint_queue.is_empty():
		return
	# Sort by priority descending
	_hint_queue.sort_custom(func(a, b): return a.get("priority", 0) > b.get("priority", 0))
	var next: Dictionary = _hint_queue.pop_front()
	_display_hint(next)


func _process(delta: float) -> void:
	if _current_hint.is_empty():
		return
	_dismiss_timer -= delta
	if _dismiss_timer <= 0.0:
		dismiss_current()


## Called when a tutorial gig activates
func on_gig_activated(gig) -> void:
	if not gig.is_tutorial:
		return
	var hint_data: Dictionary = _gig_hints.get(gig.order_index, {})
	if hint_data.is_empty():
		return
	# Delay slightly so gig notification shows first
	get_tree().create_timer(1.2).timeout.connect(func():
		show_hint(hint_data.text, hint_data.duration, hint_data.id, 1)
	)


## Completion messages per tutorial gig
var _completion_hints: Dictionary = {
	1: "Good — you've got data flowing! Next: learn to sort it.",
	2: "Content filtering mastered! Next: learn to filter by state.",
	3: "State filtering done! Next: repair corrupted data.",
	4: "Recovery pipeline built! Next: unlock encryption.",
	5: "Decryption online! Next: learn re-encryption.",
	6: "Full encrypt/decrypt chain! Last step: package data.",
	7: "All core mechanics learned! New contracts available.",
}


## Called when a gig completes
func on_gig_completed(gig) -> void:
	if not gig.is_tutorial:
		return
	# Dismiss current hint if it was for this gig
	var expected_id: String = "gig%d_intro" % gig.order_index
	if _current_hint.get("id", "") == expected_id:
		dismiss_current()
	# Show completion hint after a short delay
	var msg: String = _completion_hints.get(gig.order_index, "")
	if msg != "":
		get_tree().create_timer(2.5).timeout.connect(func():
			show_hint("[color=#44ff88]%s[/color]" % msg, 6.0, "gig%d_done" % gig.order_index, 0)
		)


## Called when a building unlocks
func on_building_unlocked(building_name: String) -> void:
	var hint_data: Dictionary = _building_hints.get(building_name, {})
	if hint_data.is_empty():
		return
	show_hint(hint_data.text, hint_data.duration, hint_data.id, 2)
