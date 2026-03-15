extends Node2D

## Data source — grid-aligned rectangular structure with output ports.
## Players connect cables directly from source output ports to buildings.

const _MONO_FONT: Font = preload("res://assets/fonts/JetBrainsMono-Regular.ttf")
const TILE_SIZE: int = 64
const GLOW_PULSE_SPEED: float = 1.5
const GLOW_PULSE_AMOUNT: float = 0.08
const RING_EXPAND_SPEED: float = 0.6
const RING_COUNT: int = 3
const PORT_RADIUS: float = 6.0
const PORT_GLOW_RADIUS: float = 10.0
const PORT_HIT_RADIUS: float = 24.0

var definition: DataSourceDefinition
var grid_cell: Vector2i = Vector2i.ZERO  ## Top-left origin cell
var cells: Array[Vector2i] = []          ## All occupied cells (rectangular)
var dev_mode: bool = false
var _glow_time: float = 0.0

## Per-instance state weights — randomized from definition base weights.
## Content stays fixed (ATM = always Financial), but state ratios vary per instance.
var instance_state_weights: Dictionary = {}

## Output port system — generated from grid_size
var output_ports: Array[String] = []


func _process(delta: float) -> void:
	if definition == null:
		return
	_glow_time += delta
	# Viewport culling — skip redraw for off-screen sources
	if not _is_in_viewport():
		return
	queue_redraw()


func _is_in_viewport() -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return true
	var vp_half := get_viewport_rect().size / cam.zoom / 2.0
	var cam_pos := cam.global_position
	var my_pos := global_position
	var size_px := Vector2(definition.grid_size.x * TILE_SIZE, definition.grid_size.y * TILE_SIZE)
	var margin := 200.0  # Glow/ring overshoot
	return (my_pos.x + size_px.x + margin > cam_pos.x - vp_half.x
		and my_pos.x - margin < cam_pos.x + vp_half.x
		and my_pos.y + size_px.y + margin > cam_pos.y - vp_half.y
		and my_pos.y - margin < cam_pos.y + vp_half.y)


func setup(def: DataSourceDefinition, origin: Vector2i) -> void:
	definition = def
	grid_cell = origin
	_generate_rectangular_cells()
	_generate_output_ports()
	queue_redraw()


func _generate_rectangular_cells() -> void:
	cells.clear()
	for x in range(definition.grid_size.x):
		for y in range(definition.grid_size.y):
			cells.append(Vector2i(grid_cell.x + x, grid_cell.y + y))


func _generate_output_ports() -> void:
	## Generate output ports: (edge_length - 1) ports per edge
	output_ports.clear()
	var w: int = definition.grid_size.x
	var h: int = definition.grid_size.y
	# Top edge: (w - 1) ports
	for i in range(w - 1):
		output_ports.append("top_%d" % i)
	# Right edge: (h - 1) ports
	for i in range(h - 1):
		output_ports.append("right_%d" % i)
	# Bottom edge: (w - 1) ports
	for i in range(w - 1):
		output_ports.append("bottom_%d" % i)
	# Left edge: (h - 1) ports
	for i in range(h - 1):
		output_ports.append("left_%d" % i)


func get_center_world() -> Vector2:
	return global_position + Vector2(
		definition.grid_size.x * TILE_SIZE / 2.0,
		definition.grid_size.y * TILE_SIZE / 2.0
	)


## --- PORT INTERFACE (duck-typed to match building.gd) ---

func _get_physical_side(logical_port: String) -> String:
	## Sources don't rotate — physical = logical
	return logical_port


func _count_ports_on_side(base_side: String) -> int:
	var count: int = 0
	for p in output_ports:
		if p.begins_with(base_side + "_"):
			count += 1
	return count


func get_port_local_position(port_side: String) -> Vector2:
	var base_side: String
	var port_idx: int = 0
	var us_pos: int = port_side.find("_")
	if us_pos >= 0:
		base_side = port_side.substr(0, us_pos)
		port_idx = int(port_side.substr(us_pos + 1))
	else:
		base_side = port_side

	var size := Vector2(definition.grid_size.x * TILE_SIZE, definition.grid_size.y * TILE_SIZE)
	var count: int = _count_ports_on_side(base_side)

	# Side length
	var side_len: float
	match base_side:
		"left", "right":
			side_len = size.y
		_:
			side_len = size.x

	# Offset along the side: evenly distributed
	var offset: float = side_len * float(port_idx + 1) / float(count + 1)

	match base_side:
		"right":
			return Vector2(size.x, offset)
		"left":
			return Vector2(0, offset)
		"top":
			return Vector2(offset, 0)
		"bottom":
			return Vector2(offset, size.y)
	return size / 2.0


func get_port_world_position(port_side: String) -> Vector2:
	return global_position + get_port_local_position(port_side)


func get_port_at(local_pos: Vector2) -> Dictionary:
	## Hit-test for output ports (used by BuildingManager for cable start)
	for port_side in output_ports:
		var port_pos := get_port_local_position(port_side)
		if local_pos.distance_to(port_pos) <= PORT_HIT_RADIUS:
			return {"side": port_side, "is_output": true}
	return {}


## --- ZOOM LEVEL ---

func _get_zoom_level() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam.zoom.x
	return 1.0


## --- DRAWING ---

func _draw() -> void:
	if definition == null:
		return

	var zoom: float = _get_zoom_level()
	var size := Vector2(definition.grid_size.x * TILE_SIZE, definition.grid_size.y * TILE_SIZE)
	var rect := Rect2(Vector2.ZERO, size)

	var accent: Color = definition.color
	var pulse: float = sin(_glow_time * GLOW_PULSE_SPEED) * GLOW_PULSE_AMOUNT

	# === PCB MODE (zoom < 0.25) — soft glowing dots ===
	if zoom < 0.25:
		_draw_pcb_source(accent, pulse, zoom, size)
		return

	# === MEDIUM MODE (zoom 0.25-0.45) — simplified with glow ===
	if zoom < 0.45:
		_draw_medium_source(accent, pulse, zoom, size)
		return

	# === FULL DETAIL MODE ===
	var base_alpha: float = 0.22 + pulse
	var border_alpha: float = 0.7 + pulse * 2.0

	# Territory tint
	_draw_territory_tint(accent, size)

	# Draw filled rect
	draw_rect(rect, Color(accent, base_alpha), true)

	# Draw border
	draw_rect(rect, Color(accent, border_alpha), false, 2.0)
	draw_rect(rect, Color(accent, border_alpha * 0.3), false, 6.0)

	# Signal rings
	var center := size / 2.0
	_draw_signal_rings(center, accent, 1.0)

	# Source name
	_draw_source_name(center, accent)

	# Output ports
	_draw_ports(size, accent)


## PCB mode: zoom-compensated glowing dots
func _draw_pcb_source(accent: Color, pulse: float, zoom: float, size: Vector2) -> void:
	var center := size / 2.0
	var inv_zoom: float = clampf(1.0 / zoom, 2.0, 8.0)

	# Soft glow halo
	var glow_r: float = maxf(size.x, size.y) * 0.3 * inv_zoom
	draw_circle(center, glow_r, Color(accent, 0.035 + pulse * 0.01))
	draw_circle(center, glow_r * 0.5, Color(accent, 0.09 + pulse * 0.03))
	draw_circle(center, glow_r * 0.25, Color(accent, 0.2 + pulse * 0.06))

	# Bright core
	draw_circle(center, maxf(6.0, glow_r * 0.08), Color(accent, 0.4 + pulse * 3.0))
	draw_circle(center, maxf(2.5, glow_r * 0.03), Color(1.0, 1.0, 1.0, 0.5))


## Medium zoom: simplified with soft glow halo
func _draw_medium_source(accent: Color, pulse: float, zoom: float, size: Vector2) -> void:
	var zoom_boost: float = clampf(1.0 / zoom, 1.0, 2.5)
	var base_alpha: float = (0.15 + pulse) * zoom_boost
	var border_alpha: float = (0.5 + pulse * 2.0) * zoom_boost
	var center := size / 2.0
	var rect := Rect2(Vector2.ZERO, size)

	# Soft glow halo
	var glow_r: float = maxf(size.x, size.y) * 0.4
	draw_circle(center, glow_r * 1.2, Color(accent, 0.04 * zoom_boost))
	draw_circle(center, glow_r * 0.6, Color(accent, 0.08 * zoom_boost + pulse * 0.02))

	# Territory tint
	_draw_territory_tint(accent, size, 0.08 * zoom_boost)

	# Filled rect
	draw_rect(rect, Color(accent, minf(base_alpha, 0.45)), true)

	# Border
	draw_rect(rect, Color(accent, minf(border_alpha, 0.9)), false, 3.0)

	# Signal rings
	_draw_signal_rings(center, accent, zoom_boost)

	# Source name
	_draw_source_name(center, accent)


func _draw_signal_rings(center: Vector2, accent: Color, scale: float = 1.0) -> void:
	for i in range(RING_COUNT):
		var phase: float = fmod(_glow_time * RING_EXPAND_SPEED + float(i) / float(RING_COUNT), 1.0)
		var radius: float = (20.0 + phase * 80.0) * scale
		var ring_alpha: float = (1.0 - phase) * 0.4
		if ring_alpha <= 0.01:
			continue
		draw_arc(center, radius, 0.0, TAU, 24, Color(accent, ring_alpha), 2.0 * scale, true)


func _draw_source_name(center: Vector2, accent: Color) -> void:
	var font := _MONO_FONT
	var zoom: float = _get_zoom_level()
	var inv_scale: float = clampf(1.0 / zoom, 1.0, 3.0)
	var font_size: int = int(13.0 * inv_scale)
	var text: String = definition.source_name
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var y_offset: float = -12.0 * inv_scale
	var text_pos := Vector2(center.x - text_size.x / 2.0, center.y + y_offset)
	# Shadow
	draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.7))
	# Text
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(accent, 0.9))


func _draw_territory_tint(accent: Color, size: Vector2, tint_alpha: float = 0.06) -> void:
	var tint_color := Color(accent, tint_alpha)
	var t := float(TILE_SIZE)
	var w: float = size.x
	var h: float = size.y
	# 4 border strips instead of per-cell rects (16 rects → 4)
	draw_rect(Rect2(-t, -t, w + 2.0 * t, t), tint_color, true)       # Top strip
	draw_rect(Rect2(-t, h, w + 2.0 * t, t), tint_color, true)        # Bottom strip
	draw_rect(Rect2(-t, 0.0, t, h), tint_color, true)                 # Left strip
	draw_rect(Rect2(w, 0.0, t, h), tint_color, true)                  # Right strip


func _draw_ports(size: Vector2, accent: Color) -> void:
	var port_pulse: float = sin(_glow_time * 3.0) * 0.5 + 0.5
	for port_side in output_ports:
		var pos := get_port_local_position(port_side)
		var gr := PORT_GLOW_RADIUS + port_pulse * 2.0
		draw_circle(pos, gr, Color(accent, 0.1 + port_pulse * 0.08))
		draw_circle(pos, PORT_RADIUS, Color(accent, 0.8))
		draw_circle(pos, PORT_RADIUS * 0.4, Color.WHITE)


func _draw_zone_badge(center: Vector2) -> void:
	var diff_labels: Dictionary = {"medium": "MEDIUM", "hard": "HARD", "endgame": "ENDGAME"}
	var diff_colors: Dictionary = {
		"easy": Color(0.2, 1.0, 0.67),
		"medium": Color(1.0, 0.8, 0.2),
		"hard": Color(1.0, 0.4, 0.2),
		"endgame": Color(1.0, 0.13, 0.27),
	}

	var label: String = diff_labels.get(definition.difficulty, "")
	if label == "":
		return
	var badge_color: Color = diff_colors.get(definition.difficulty, Color.WHITE)

	var font := _MONO_FONT
	var font_size := 10
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var badge_pos := Vector2(center.x - text_size.x / 2.0, center.y - 28)

	var bg_rect := Rect2(badge_pos.x - 4, badge_pos.y - font_size + 1, text_size.x + 8, font_size + 4)
	draw_rect(bg_rect, Color(0, 0, 0, 0.6), true)
	draw_rect(bg_rect, Color(badge_color, 0.5), false, 1.0)
	draw_string(font, badge_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(badge_color, 0.9))
