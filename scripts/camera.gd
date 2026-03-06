extends Camera2D

const PAN_SPEED: float = 600.0
const ZOOM_SPEED: float = 0.1
const MIN_ZOOM: float = 0.1
const MAX_ZOOM: float = 3.0
const SMOOTH_FACTOR: float = 8.0

var _target_zoom: float = 1.0
var _is_dragging: bool = false


func _ready() -> void:
	zoom = Vector2(_target_zoom, _target_zoom)


func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)
	_smooth_zoom(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _is_dragging:
		position -= event.relative / zoom


func _handle_keyboard_pan(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1
	if direction != Vector2.ZERO:
		position += direction.normalized() * PAN_SPEED * delta / zoom.x


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		_is_dragging = event.pressed
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_target_zoom = clampf(_target_zoom + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_target_zoom = clampf(_target_zoom - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)


func _smooth_zoom(delta: float) -> void:
	var new_zoom := lerpf(zoom.x, _target_zoom, SMOOTH_FACTOR * delta)
	zoom = Vector2(new_zoom, new_zoom)
