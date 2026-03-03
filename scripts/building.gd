extends Node2D

const TILE_SIZE: int = 64
const BODY_COLOR := Color("#1a1e2e")
const BORDER_WIDTH: float = 2.0
const GLOW_WIDTH: float = 4.0
const GLOW_ALPHA: float = 0.3

var definition: BuildingDefinition
var grid_cell: Vector2i = Vector2i.ZERO


func setup(def: BuildingDefinition, cell: Vector2i) -> void:
	definition = def
	grid_cell = cell
	queue_redraw()


func _draw() -> void:
	if definition == null:
		return

	var size := Vector2(definition.grid_size.x * TILE_SIZE, definition.grid_size.y * TILE_SIZE)
	var rect := Rect2(Vector2.ZERO, size)

	# Outer glow
	var glow_rect := Rect2(
		Vector2(-GLOW_WIDTH, -GLOW_WIDTH),
		size + Vector2(GLOW_WIDTH * 2, GLOW_WIDTH * 2)
	)
	draw_rect(glow_rect, Color(definition.color, GLOW_ALPHA), false, GLOW_WIDTH)

	# Body
	draw_rect(rect, BODY_COLOR, true)

	# Neon border
	draw_rect(rect, definition.color, false, BORDER_WIDTH)

	# Building name (centered)
	var font := ThemeDB.fallback_font
	var font_size := 14
	var text_size := font.get_string_size(definition.building_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := Vector2(
		(size.x - text_size.x) / 2.0,
		(size.y + text_size.y) / 2.0 - 4
	)
	draw_string(font, text_pos, definition.building_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
