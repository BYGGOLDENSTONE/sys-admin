extends Camera2D

const PAN_SPEED: float = 600.0
const ZOOM_SPEED: float = 0.1
const MIN_ZOOM: float = 0.1
const MAX_ZOOM: float = 3.0
const SMOOTH_FACTOR: float = 8.0

var _target_zoom: float = 1.0
var _is_dragging: bool = false

# Trauma-based screen shake (Squirrel Eiserloh GDC technique)
var _trauma: float = 0.0
var _noise: FastNoiseLite = null
var _noise_y: float = 0.0
var _post_material: ShaderMaterial = null
const TRAUMA_DECAY: float = 1.8
const MAX_SHAKE_OFFSET: float = 12.0


func _ready() -> void:
	zoom = Vector2(_target_zoom, _target_zoom)
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 3.0
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func set_post_material(mat: ShaderMaterial) -> void:
	_post_material = mat


func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)
	_smooth_zoom(delta)

	if _trauma > 0.0:
		_noise_y += delta * 60.0
		var shake := _trauma * _trauma
		var zoom_comp := 1.0 / zoom.x
		offset.x = MAX_SHAKE_OFFSET * shake * _noise.get_noise_2d(_noise_y, 0.0) * zoom_comp
		offset.y = MAX_SHAKE_OFFSET * shake * _noise.get_noise_2d(0.0, _noise_y) * zoom_comp
		_trauma = maxf(_trauma - TRAUMA_DECAY * delta, 0.0)
	elif offset != Vector2.ZERO:
		offset = offset.lerp(Vector2.ZERO, delta * 12.0)
		if offset.length() < 0.1:
			offset = Vector2.ZERO

	# Drive chromatic aberration from trauma
	if _post_material:
		_post_material.set_shader_parameter("chromatic_aberration", _trauma * _trauma * 5.0)


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
