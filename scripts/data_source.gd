extends Node2D

const _MONO_FONT: Font = preload("res://assets/fonts/JetBrainsMono-Regular.ttf")
const TILE_SIZE: int = 64
const GLOW_PULSE_SPEED: float = 1.5
const GLOW_PULSE_AMOUNT: float = 0.08
const RING_EXPAND_SPEED: float = 0.6
const RING_COUNT: int = 3

var definition: DataSourceDefinition
var grid_cell: Vector2i = Vector2i.ZERO  ## Top-left origin cell
var cells: Array[Vector2i] = []          ## All occupied cells (organic shape)
var discovered: bool = false
var dev_mode: bool = false
var _glow_time: float = 0.0
var _linked_uplinks: int = 0  ## How many Uplinks are tapped into this source
var _reveal_flash: float = 0.0  ## 1.0 = just revealed, fades to 0


func _process(delta: float) -> void:
	if definition == null:
		return
	_glow_time += delta
	if _reveal_flash > 0:
		_reveal_flash = max(0.0, _reveal_flash - delta * 2.0)
	queue_redraw()


func setup(def: DataSourceDefinition, origin: Vector2i, shape_cells: Array[Vector2i]) -> void:
	definition = def
	grid_cell = origin
	cells = shape_cells
	queue_redraw()


func reveal() -> void:
	discovered = true
	_reveal_flash = 1.0


func get_center_world() -> Vector2:
	if cells.is_empty():
		return global_position
	var sum := Vector2.ZERO
	for cell in cells:
		sum += Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)
	return sum / float(cells.size())


func _get_zoom_level() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam.zoom.x
	return 1.0


func _draw() -> void:
	if definition == null or cells.is_empty():
		return

	var zoom: float = _get_zoom_level()

	# Hidden state
	if not discovered and not dev_mode:
		_draw_hidden(zoom)
		return

	var accent: Color = definition.color
	var pulse: float = sin(_glow_time * GLOW_PULSE_SPEED) * GLOW_PULSE_AMOUNT

	# === PCB MODE (zoom < 0.25) — soft glowing dots ===
	if zoom < 0.25:
		_draw_pcb_source(accent, pulse, zoom)
		return

	# === MEDIUM MODE (zoom 0.25-0.45) — simplified with glow ===
	if zoom < 0.45:
		_draw_medium_source(accent, pulse, zoom)
		return

	# === FULL DETAIL MODE ===
	var base_alpha: float = 0.22 + pulse
	var border_alpha: float = 0.7 + pulse * 2.0

	# Territory tint
	_draw_territory_tint(accent)

	# Draw filled cells
	for cell in cells:
		var local_pos := Vector2(
			(cell.x - grid_cell.x) * TILE_SIZE,
			(cell.y - grid_cell.y) * TILE_SIZE
		)
		var rect := Rect2(local_pos, Vector2(TILE_SIZE, TILE_SIZE))
		draw_rect(rect, Color(accent, base_alpha), true)

	# Draw border edges
	_draw_organic_border(accent, border_alpha, 2.0, 6.0)

	# Signal rings
	var center: Vector2 = get_center_world() - global_position
	_draw_signal_rings(center, accent, 1.0)

	# Zone badge

	# Dev mode badge
	if dev_mode and not discovered:
		_draw_hidden_badge(center)

	# Source name
	_draw_source_name(center, accent)


	# Reveal flash
	if _reveal_flash > 0:
		_draw_reveal_flash()


## PCB mode: zoom-compensated glowing dots (no per-cell drawing to avoid pixel artifacts)
func _draw_pcb_source(accent: Color, pulse: float, zoom: float) -> void:
	var center: Vector2 = get_center_world() - global_position
	var inv_zoom: float = clampf(1.0 / zoom, 2.0, 8.0)

	# Soft glow halo — scales inversely with zoom for consistent screen presence (brighter)
	var glow_r: float = (30.0 + float(cells.size()) * 3.0) * inv_zoom
	draw_circle(center, glow_r, Color(accent, 0.035 + pulse * 0.01))
	draw_circle(center, glow_r * 0.5, Color(accent, 0.09 + pulse * 0.03))
	draw_circle(center, glow_r * 0.25, Color(accent, 0.2 + pulse * 0.06))

	# Bright core
	draw_circle(center, maxf(6.0, glow_r * 0.08), Color(accent, 0.4 + pulse * 3.0))
	draw_circle(center, maxf(2.5, glow_r * 0.03), Color(1.0, 1.0, 1.0, 0.5))

	if _reveal_flash > 0:
		_draw_reveal_flash()


## Medium zoom: simplified with soft glow halo
func _draw_medium_source(accent: Color, pulse: float, zoom: float) -> void:
	var zoom_boost: float = clampf(1.0 / zoom, 1.0, 2.5)
	var base_alpha: float = (0.15 + pulse) * zoom_boost
	var border_alpha: float = (0.5 + pulse * 2.0) * zoom_boost
	var center: Vector2 = get_center_world() - global_position

	# Soft glow halo behind source (brighter)
	var glow_r: float = sqrt(float(cells.size())) * TILE_SIZE * 0.5
	draw_circle(center, glow_r * 1.2, Color(accent, 0.04 * zoom_boost))
	draw_circle(center, glow_r * 0.6, Color(accent, 0.08 * zoom_boost + pulse * 0.02))

	# Territory tint (brighter)
	_draw_territory_tint(accent, 0.08 * zoom_boost)

	# Filled cells (brighter)
	for cell in cells:
		var local_pos := Vector2(
			(cell.x - grid_cell.x) * TILE_SIZE,
			(cell.y - grid_cell.y) * TILE_SIZE
		)
		draw_rect(Rect2(local_pos, Vector2(TILE_SIZE, TILE_SIZE)), Color(accent, minf(base_alpha, 0.45)), true)

	# Thicker brighter border
	_draw_organic_border(accent, minf(border_alpha, 0.9), 3.0, 10.0)

	# Signal rings (larger, fewer)
	_draw_signal_rings(center, accent, zoom_boost)

	# Source name only (no badge, no bars)
	_draw_source_name(center, accent)

	# Reveal flash
	if _reveal_flash > 0:
		_draw_reveal_flash()


func _draw_hidden(zoom: float) -> void:
	var accent: Color = definition.color
	var pulse: float = sin(_glow_time * 0.8) * 0.1
	var alpha: float = 0.15 + pulse

	# PCB mode hidden: faint glow dot (zoom-compensated)
	if zoom < 0.25:
		var center: Vector2 = get_center_world() - global_position
		var inv_zoom: float = clampf(1.0 / zoom, 2.0, 8.0)
		var r: float = 20.0 * inv_zoom
		draw_circle(center, r, Color(accent, 0.012 + pulse * 0.3))
		draw_circle(center, r * 0.3, Color(accent, 0.025))
		return

	# Medium mode hidden: dim blob + question mark
	if zoom < 0.45:
		for cell in cells:
			var local_pos := Vector2(
				(cell.x - grid_cell.x) * TILE_SIZE,
				(cell.y - grid_cell.y) * TILE_SIZE
			)
			draw_rect(Rect2(local_pos, Vector2(TILE_SIZE, TILE_SIZE)), Color(accent, 0.04), true)
		_draw_organic_border(accent, alpha * 0.4, 2.0, 4.0)
		var center: Vector2 = get_center_world() - global_position
		var font := _MONO_FONT
		var q_dims := font.get_string_size("?", HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
		var q_pos := Vector2(center.x - q_dims.x / 2.0, center.y + q_dims.y / 4.0)
		draw_string(font, q_pos, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(accent, alpha + 0.15))
		return

	# Full detail hidden
	# Faint blob fill
	for cell in cells:
		var local_pos := Vector2(
			(cell.x - grid_cell.x) * TILE_SIZE,
			(cell.y - grid_cell.y) * TILE_SIZE
		)
		draw_rect(Rect2(local_pos, Vector2(TILE_SIZE, TILE_SIZE)), Color(accent, 0.03), true)

	# Dim border
	_draw_organic_border(accent, alpha * 0.3, 2.0, 6.0)

	# "?" icon at center
	var center: Vector2 = get_center_world() - global_position
	var font := _MONO_FONT
	var q_size := 20
	var q_text := "?"
	var q_dims := font.get_string_size(q_text, HORIZONTAL_ALIGNMENT_CENTER, -1, q_size)
	var q_pos := Vector2(center.x - q_dims.x / 2.0, center.y + q_dims.y / 4.0)
	draw_string(font, q_pos + Vector2(1, 1), q_text, HORIZONTAL_ALIGNMENT_LEFT, -1, q_size, Color(0, 0, 0, 0.5))
	draw_string(font, q_pos, q_text, HORIZONTAL_ALIGNMENT_LEFT, -1, q_size, Color(accent, alpha + 0.15))

	# "Bilinmeyen Sinyal" text below
	var sub_size := 9
	var sub_text := "Unknown Signal"
	var sub_dims := font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_size)
	var sub_pos := Vector2(center.x - sub_dims.x / 2.0, center.y + 16)
	draw_string(font, sub_pos, sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(accent, alpha * 0.5))

	# Single slow signal ring
	var phase: float = fmod(_glow_time * 0.3, 1.0)
	var radius: float = 15.0 + phase * 50.0
	var ring_alpha: float = (1.0 - phase) * 0.12
	if ring_alpha > 0.01:
		var points := PackedVector2Array()
		for j in range(33):
			var angle: float = float(j) / 32.0 * TAU
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_polyline(points, Color(accent, ring_alpha), 1.0, true)


func _draw_hidden_badge(center: Vector2) -> void:
	var font := _MONO_FONT
	var font_size := 10
	var label := "HIDDEN"
	var badge_color := Color(1.0, 0.4, 0.2)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var badge_pos := Vector2(center.x - text_size.x / 2.0, center.y - 42)

	var bg_rect := Rect2(badge_pos.x - 4, badge_pos.y - font_size + 1, text_size.x + 8, font_size + 4)
	draw_rect(bg_rect, Color(0, 0, 0, 0.7), true)
	draw_rect(bg_rect, Color(badge_color, 0.6), false, 1.0)
	draw_string(font, badge_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(badge_color, 0.9))


func _draw_reveal_flash() -> void:
	var accent: Color = definition.color
	var flash_alpha: float = _reveal_flash * 0.6
	for cell in cells:
		var local_pos := Vector2(
			(cell.x - grid_cell.x) * TILE_SIZE,
			(cell.y - grid_cell.y) * TILE_SIZE
		)
		draw_rect(Rect2(local_pos, Vector2(TILE_SIZE, TILE_SIZE)), Color(accent, flash_alpha), true)
	# Double expanding ring burst for impact
	var center: Vector2 = get_center_world() - global_position
	# Inner ring (fast)
	var burst1_r: float = (1.0 - _reveal_flash) * 140.0
	var burst1_a: float = _reveal_flash * 0.6
	var points1 := PackedVector2Array()
	for j in range(33):
		var angle: float = float(j) / 32.0 * TAU
		points1.append(center + Vector2(cos(angle), sin(angle)) * burst1_r)
	draw_polyline(points1, Color(accent, burst1_a), 3.0, true)
	# Outer ring (slower, wider)
	var burst2_r: float = (1.0 - _reveal_flash) * 200.0
	var burst2_a: float = _reveal_flash * 0.3
	var points2 := PackedVector2Array()
	for j in range(33):
		var angle: float = float(j) / 32.0 * TAU
		points2.append(center + Vector2(cos(angle), sin(angle)) * burst2_r)
	draw_polyline(points2, Color(accent, burst2_a), 2.0, true)
	# Center flash dot
	draw_circle(center, 8.0 * _reveal_flash, Color(1.0, 1.0, 1.0, _reveal_flash * 0.5))


func _draw_organic_border(accent: Color, alpha: float, line_w: float = 2.0, glow_w: float = 6.0) -> void:
	var cell_set: Dictionary = {}
	for cell in cells:
		cell_set[cell] = true

	for cell in cells:
		var local_x: float = (cell.x - grid_cell.x) * TILE_SIZE
		var local_y: float = (cell.y - grid_cell.y) * TILE_SIZE

		# Top edge
		if not cell_set.has(Vector2i(cell.x, cell.y - 1)):
			draw_line(Vector2(local_x, local_y), Vector2(local_x + TILE_SIZE, local_y),
				Color(accent, alpha), line_w)
			draw_line(Vector2(local_x, local_y), Vector2(local_x + TILE_SIZE, local_y),
				Color(accent, alpha * 0.3), glow_w)
		# Bottom edge
		if not cell_set.has(Vector2i(cell.x, cell.y + 1)):
			draw_line(Vector2(local_x, local_y + TILE_SIZE), Vector2(local_x + TILE_SIZE, local_y + TILE_SIZE),
				Color(accent, alpha), line_w)
			draw_line(Vector2(local_x, local_y + TILE_SIZE), Vector2(local_x + TILE_SIZE, local_y + TILE_SIZE),
				Color(accent, alpha * 0.3), glow_w)
		# Left edge
		if not cell_set.has(Vector2i(cell.x - 1, cell.y)):
			draw_line(Vector2(local_x, local_y), Vector2(local_x, local_y + TILE_SIZE),
				Color(accent, alpha), line_w)
			draw_line(Vector2(local_x, local_y), Vector2(local_x, local_y + TILE_SIZE),
				Color(accent, alpha * 0.3), glow_w)
		# Right edge
		if not cell_set.has(Vector2i(cell.x + 1, cell.y)):
			draw_line(Vector2(local_x + TILE_SIZE, local_y), Vector2(local_x + TILE_SIZE, local_y + TILE_SIZE),
				Color(accent, alpha), line_w)
			draw_line(Vector2(local_x + TILE_SIZE, local_y), Vector2(local_x + TILE_SIZE, local_y + TILE_SIZE),
				Color(accent, alpha * 0.3), glow_w)


func _draw_signal_rings(center: Vector2, accent: Color, scale: float = 1.0) -> void:
	for i in range(RING_COUNT):
		var phase: float = fmod(_glow_time * RING_EXPAND_SPEED + float(i) / float(RING_COUNT), 1.0)
		var radius: float = (20.0 + phase * 80.0) * scale
		var ring_alpha: float = (1.0 - phase) * 0.4
		if ring_alpha <= 0.01:
			continue
		var point_count: int = 32
		var points := PackedVector2Array()
		for j in range(point_count + 1):
			var angle: float = float(j) / float(point_count) * TAU
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_polyline(points, Color(accent, ring_alpha), 2.0 * scale, true)


func _draw_source_name(center: Vector2, accent: Color) -> void:
	var font := _MONO_FONT
	var zoom: float = _get_zoom_level()
	# Scale font inversely with zoom, clamped so it stays readable but not huge
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


func _draw_composition_bars(center: Vector2, _accent: Color) -> void:
	if definition.content_weights.is_empty():
		return
	var bar_width: float = 60.0
	var bar_height: float = 4.0
	var bar_y: float = center.y + 8
	var bar_x: float = center.x - bar_width / 2.0

	# Background
	draw_rect(Rect2(Vector2(bar_x - 1, bar_y - 1), Vector2(bar_width + 2, bar_height + 2)), Color(0, 0, 0, 0.5), true)

	# Content segments
	var offset: float = 0.0
	for content_id in definition.content_weights:
		var weight: float = definition.content_weights[content_id]
		var seg_width: float = weight * bar_width
		if seg_width < 1.0:
			continue
		var color: Color = DataEnums.content_color(int(content_id))
		draw_rect(Rect2(Vector2(bar_x + offset, bar_y), Vector2(seg_width, bar_height)), Color(color, 0.8), true)
		offset += seg_width


func _draw_territory_tint(accent: Color, tint_alpha: float = 0.06) -> void:
	var cell_set: Dictionary = {}
	for cell in cells:
		cell_set[cell] = true

	var tint_color := Color(accent, tint_alpha)
	for cell in cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var neighbor := Vector2i(cell.x + dx, cell.y + dy)
				if cell_set.has(neighbor):
					continue
				var local_pos := Vector2(
					(neighbor.x - grid_cell.x) * TILE_SIZE,
					(neighbor.y - grid_cell.y) * TILE_SIZE
				)
				cell_set[neighbor] = false
				draw_rect(Rect2(local_pos, Vector2(TILE_SIZE, TILE_SIZE)), tint_color, true)


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
