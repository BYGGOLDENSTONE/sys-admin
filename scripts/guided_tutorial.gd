extends Node

## Step-based guided tutorial with animated arrow indicators.
## Only Gig 1 uses visual arrows to teach cabling.
## All other gigs use text hints via tutorial_manager (no arrows).

const ARROW_CLR := Color(1.0, 0.85, 0.0)
const GLOW_CLR := Color(1.0, 0.7, 0.0, 0.35)
const PULSE_SPD := 3.5
const BOUNCE := 10.0
const TILE: float = 64.0
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.35)

# References — untyped to allow script-specific method access
var _camera = null
var _bm = null           # building_manager
var _cm = null           # connection_manager
var _tm = null           # tutorial_manager
var _sc = null           # source_container
var _ct = null           # contract_terminal

# Overlay
var _layer = null
var _ctrl = null
var _t: float = 0.0

# State
var _gig: int = -1
var _si: int = -1
var _steps: Array = []
var _arrows: Array = []
var _conns: int = 0
var _auto_timer: float = -1.0
var _dim_screen: bool = false


func setup(refs: Dictionary) -> void:
	_camera = refs.camera
	_bm = refs.building_manager
	_cm = refs.connection_manager
	_tm = refs.tutorial_manager
	_sc = refs.source_container
	_ct = refs.contract_terminal

	# Build arrow overlay
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	var ArrowScript = preload("res://scripts/ui/arrow_overlay.gd")
	_ctrl = Control.new()
	_ctrl.set_script(ArrowScript)
	_ctrl.guided_tutorial = self
	_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_ctrl)

	# Signals for step advancement
	_cm.connection_added.connect(_on_conn)


## Called from main.gd when a gig activates
func on_gig_activated(gig) -> void:
	if not gig.is_tutorial:
		return
	var idx: int = gig.order_index
	# Only Gig 1 has arrow guidance — rest handled by tutorial_manager hints
	if idx != 1:
		return
	# Block tutorial_manager's own intro hint (guided tutorial handles Gig 1)
	if _tm:
		_tm._shown_hints["gig1_intro"] = true
	get_tree().create_timer(1.5).timeout.connect(_begin.bind(idx))


func _begin(idx: int) -> void:
	_steps = _make_steps(idx)
	if _steps.is_empty():
		return
	_gig = idx
	_si = -1
	_next()


func _next() -> void:
	_si += 1
	_conns = 0
	_auto_timer = -1.0
	_dim_screen = false

	if _si >= _steps.size():
		_arrows.clear()
		if _ctrl:
			_ctrl.queue_redraw()
		_gig = -1
		_si = -1
		_steps.clear()
		return

	var s: Dictionary = _steps[_si]
	_arrows = s.get("arrows", [])
	_dim_screen = s.get("dim", false)

	# Show hint text via tutorial_manager
	var hint: String = s.get("hint", "")
	if hint != "" and _tm:
		_tm.dismiss_current()
		_tm.show_hint(hint, s.get("dur", 15.0), "g%d_s%d" % [_gig, _si], 3)

	if _ctrl:
		_ctrl.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if not _arrows.is_empty() and _ctrl:
		_ctrl.queue_redraw()

	if _si < 0 or _si >= _steps.size():
		return

	# Poll: building_manager entering CONNECTING state
	if _steps[_si].get("advance_on") == "connecting":
		if _bm._state == 2:  # State.CONNECTING
			_next()


# ─── Arrow Rendering ───────────────────────────────────────

## Called by arrow_overlay.gd during its _draw()
func draw_arrows(canvas: Control) -> void:
	if _dim_screen and not _arrows.is_empty():
		canvas.draw_rect(Rect2(Vector2.ZERO, canvas.get_viewport_rect().size), DIM_COLOR)

	for a in _arrows:
		var p = _resolve_pos(a)
		if p.x < -999:
			continue
		var vp = canvas.get_viewport_rect().size
		if p.x < -80 or p.x > vp.x + 80 or p.y < -80 or p.y > vp.y + 80:
			continue
		_draw_arrow_at(canvas, p, a.get("label", ""))


func _resolve_pos(a: Dictionary) -> Vector2:
	var t = a.get("type", "")
	if t == "source_port":
		var src = _find_src(a.get("name", ""))
		if src and src.has_method("get_port_world_position"):
			return _w2s(src.get_port_world_position(a.get("port", "")))
	elif t == "ct_port":
		if _ct and _ct.has_method("get_port_world_position"):
			return _w2s(_ct.get_port_world_position(a.get("port", "")))
	return Vector2(-9999, -9999)


func _w2s(wp: Vector2) -> Vector2:
	if not _ctrl or not _camera:
		return Vector2(-9999, -9999)
	var vp = _ctrl.get_viewport_rect().size
	return (wp - _camera.get_screen_center_position()) * _camera.zoom + vp * 0.5


func _draw_arrow_at(canvas: Control, target: Vector2, text: String) -> void:
	var bounce = sin(_t * PULSE_SPD) * BOUNCE
	var alpha = 0.7 + sin(_t * PULSE_SPD * 1.5) * 0.3

	# Glow circle at target
	var gc = Color(GLOW_CLR)
	gc.a = alpha * 0.4
	canvas.draw_circle(target, 22.0 + sin(_t * 2.0) * 5.0, gc)

	# Arrow triangle pointing down
	var off = Vector2(0, bounce - 32)
	var tip = target + off + Vector2(0, 8)
	var pl = target + off + Vector2(-13, -16)
	var pr = target + off + Vector2(13, -16)
	var c = Color(ARROW_CLR)
	c.a = alpha
	canvas.draw_colored_polygon(PackedVector2Array([tip, pl, pr]), c)

	# Stem
	canvas.draw_line(target + off + Vector2(0, -16), target + off + Vector2(0, -34), c, 3.0)

	# Text label
	if text == "":
		return
	var font = ThemeDB.fallback_font
	var fs = 12
	var tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lp = target + off + Vector2(-tw * 0.5, -48)
	var bg = Rect2(lp + Vector2(-6, -fs - 2), Vector2(tw + 12, fs + 8))
	canvas.draw_rect(bg, Color(0.02, 0.05, 0.1, 0.88 * alpha))
	canvas.draw_rect(bg, Color(1.0, 0.85, 0.0, 0.4 * alpha), false, 1.0)
	canvas.draw_string(font, lp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(1.0, 0.95, 0.85, alpha))


func _find_src(display_name: String):
	for child in _sc.get_children():
		if child.definition and child.definition.source_name == display_name:
			return child
	return null


# ─── Signal Handlers ──────────────────────────────────────

func _on_conn(_c: Dictionary) -> void:
	if _si < 0 or _si >= _steps.size():
		return
	if _steps[_si].get("advance_on") != "connection":
		return
	_conns += 1
	if _conns >= _steps[_si].get("need", 1):
		_next()


# ─── Step Definitions ─────────────────────────────────────

func _make_steps(idx: int) -> Array:
	if idx == 1:
		return _gig1()
	return []


func _gig1() -> Array:
	## Teach cabling: ISP Backbone left port → CT top port
	return [
		{
			"arrows": [{"type": "source_port", "name": "ISP Backbone", "port": "left_0", "label": "Output port"}],
			"hint": "[color=#00ddff]Click[/color] on the [color=#ffcc44]ISP Backbone[/color]'s [color=#00ddff]output port[/color] (small circle on its left edge) to start drawing a cable.",
			"dur": 25.0,
			"advance_on": "connecting",
			"dim": true,
		},
		{
			"arrows": [{"type": "ct_port", "port": "top_0", "label": "Terminal input"}],
			"hint": "Route the cable toward the [color=#ffcc44]Contract Terminal[/color].\nClick on its [color=#00ddff]input port[/color] to complete the connection.",
			"dur": 30.0,
			"advance_on": "connection",
			"dim": true,
		},
	]
