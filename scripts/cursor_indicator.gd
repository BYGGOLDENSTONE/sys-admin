extends Node2D
## Screen-space neon cursor indicator.
## Lives inside a CanvasLayer so it draws on top of everything.
## Always follows mouse freely. Hover glow when over a building/source.

# Neon red palette
const CURSOR_COLOR := Color(1.0, 0.12, 0.18, 0.85)
const GLOW_COLOR := Color(1.0, 0.08, 0.12, 0.2)
const HOVER_COLOR := Color(1.0, 0.25, 0.3, 1.0)
const HOVER_GLOW := Color(1.0, 0.15, 0.2, 0.3)

const BASE_RADIUS: float = 8.0
const HOVER_RADIUS: float = 10.0
const GLOW_EXTRA: float = 3.0

const LINE_WIDTH: float = 1.5
const GLOW_WIDTH: float = 3.0

const PULSE_SPEED: float = 3.5
const PULSE_AMOUNT: float = 0.8

## Set these from the parent scene to enable hover detection
var grid_system: Node2D = null
var building_manager: Node = null

var _is_hovering: bool = false
var _time: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _process(delta: float) -> void:
	_time += delta
	visible = true
	_is_hovering = false

	var screen_pos: Vector2 = get_viewport().get_mouse_position()

	if building_manager != null:
		var bm_state: int = building_manager._state
		if bm_state in [building_manager.State.PLACING, building_manager.State.MOVING, building_manager.State.COPYING]:
			visible = false
			return
		if bm_state == building_manager.State.IDLE:
			_is_hovering = (building_manager._hovered_building != null or building_manager._hovered_source != null)

	position = screen_pos
	queue_redraw()


func _draw() -> void:
	var pulse: float = sin(_time * PULSE_SPEED) * PULSE_AMOUNT
	var radius: float = (HOVER_RADIUS if _is_hovering else BASE_RADIUS) + pulse

	var color: Color = HOVER_COLOR if _is_hovering else CURSOR_COLOR
	var glow: Color = HOVER_GLOW if _is_hovering else GLOW_COLOR

	# Outer glow ring
	draw_arc(Vector2.ZERO, radius + GLOW_EXTRA, 0, TAU, 64, glow, GLOW_WIDTH, true)

	# Main ring
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, color, LINE_WIDTH, true)
