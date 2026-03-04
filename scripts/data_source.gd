extends Node2D

const TILE_SIZE: int = 64
const GLOW_PULSE_SPEED: float = 1.5
const GLOW_PULSE_AMOUNT: float = 0.08
const RING_EXPAND_SPEED: float = 0.6
const RING_COUNT: int = 3

var definition: DataSourceDefinition
var grid_cell: Vector2i = Vector2i.ZERO  ## Top-left origin cell
var cells: Array[Vector2i] = []          ## All occupied cells (organic shape)
var _glow_time: float = 0.0
var _linked_uplinks: int = 0  ## How many Uplinks are tapped into this source


func _process(delta: float) -> void:
	if definition == null:
		return
	_glow_time += delta
	queue_redraw()


func setup(def: DataSourceDefinition, origin: Vector2i, shape_cells: Array[Vector2i]) -> void:
	definition = def
	grid_cell = origin
	cells = shape_cells
	queue_redraw()


func get_center_world() -> Vector2:
	if cells.is_empty():
		return global_position
	var sum := Vector2.ZERO
	for cell in cells:
		sum += Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)
	return sum / float(cells.size())


func _draw() -> void:
	if definition == null or cells.is_empty():
		return

	var accent: Color = definition.color
	var pulse: float = sin(_glow_time * GLOW_PULSE_SPEED) * GLOW_PULSE_AMOUNT
	var base_alpha: float = 0.12 + pulse
	var border_alpha: float = 0.5 + pulse * 2.0

	# Draw filled cells (organic blob)
	for cell in cells:
		var local_pos := Vector2(
			(cell.x - grid_cell.x) * TILE_SIZE,
			(cell.y - grid_cell.y) * TILE_SIZE
		)
		var rect := Rect2(local_pos, Vector2(TILE_SIZE, TILE_SIZE))
		# Filled cell
		draw_rect(rect, Color(accent, base_alpha), true)

	# Draw border edges (only edges adjacent to non-source cells)
	_draw_organic_border(accent, border_alpha)

	# Signal rings (expanding circles from center)
	var center: Vector2 = get_center_world() - global_position
	_draw_signal_rings(center, accent)

	# Source name at center
	_draw_source_name(center, accent)

	# Content composition indicator (small colored bars)
	_draw_composition_bars(center, accent)


func _draw_organic_border(accent: Color, alpha: float) -> void:
	var cell_set: Dictionary = {}
	for cell in cells:
		cell_set[cell] = true

	for cell in cells:
		var local_x: float = (cell.x - grid_cell.x) * TILE_SIZE
		var local_y: float = (cell.y - grid_cell.y) * TILE_SIZE

		# Check each edge — draw border if neighbor is not in shape
		# Top edge
		if not cell_set.has(Vector2i(cell.x, cell.y - 1)):
			draw_line(
				Vector2(local_x, local_y),
				Vector2(local_x + TILE_SIZE, local_y),
				Color(accent, alpha), 2.0
			)
			# Glow
			draw_line(
				Vector2(local_x, local_y),
				Vector2(local_x + TILE_SIZE, local_y),
				Color(accent, alpha * 0.3), 6.0
			)
		# Bottom edge
		if not cell_set.has(Vector2i(cell.x, cell.y + 1)):
			draw_line(
				Vector2(local_x, local_y + TILE_SIZE),
				Vector2(local_x + TILE_SIZE, local_y + TILE_SIZE),
				Color(accent, alpha), 2.0
			)
			draw_line(
				Vector2(local_x, local_y + TILE_SIZE),
				Vector2(local_x + TILE_SIZE, local_y + TILE_SIZE),
				Color(accent, alpha * 0.3), 6.0
			)
		# Left edge
		if not cell_set.has(Vector2i(cell.x - 1, cell.y)):
			draw_line(
				Vector2(local_x, local_y),
				Vector2(local_x, local_y + TILE_SIZE),
				Color(accent, alpha), 2.0
			)
			draw_line(
				Vector2(local_x, local_y),
				Vector2(local_x, local_y + TILE_SIZE),
				Color(accent, alpha * 0.3), 6.0
			)
		# Right edge
		if not cell_set.has(Vector2i(cell.x + 1, cell.y)):
			draw_line(
				Vector2(local_x + TILE_SIZE, local_y),
				Vector2(local_x + TILE_SIZE, local_y + TILE_SIZE),
				Color(accent, alpha), 2.0
			)
			draw_line(
				Vector2(local_x + TILE_SIZE, local_y),
				Vector2(local_x + TILE_SIZE, local_y + TILE_SIZE),
				Color(accent, alpha * 0.3), 6.0
			)


func _draw_signal_rings(center: Vector2, accent: Color) -> void:
	for i in range(RING_COUNT):
		var phase: float = fmod(_glow_time * RING_EXPAND_SPEED + float(i) / float(RING_COUNT), 1.0)
		var radius: float = 20.0 + phase * 80.0
		var ring_alpha: float = (1.0 - phase) * 0.25
		if ring_alpha <= 0.01:
			continue
		var point_count: int = 32
		var points := PackedVector2Array()
		for j in range(point_count + 1):
			var angle: float = float(j) / float(point_count) * TAU
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_polyline(points, Color(accent, ring_alpha), 1.5, true)


func _draw_source_name(center: Vector2, accent: Color) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 13
	var text: String = definition.source_name
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := Vector2(center.x - text_size.x / 2.0, center.y - 12)
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
