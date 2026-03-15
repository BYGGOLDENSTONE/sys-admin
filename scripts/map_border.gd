extends Node2D

## Draws the map boundary as a visible border with glow effect.
## Only active for bounded maps (levels 1-8).

var bounds: Rect2 = Rect2()
var is_active: bool = false

const BORDER_COLOR := Color(0.0, 0.75, 0.85, 0.6)
const BORDER_GLOW_COLOR := Color(0.0, 0.75, 0.85, 0.08)
const BORDER_WIDTH: float = 3.0
const GLOW_WIDTH: float = 24.0
const CORNER_SIZE: float = 48.0
const CORNER_COLOR := Color(0.0, 0.9, 1.0, 0.8)


func setup(world_bounds: Rect2) -> void:
	bounds = world_bounds
	is_active = true
	queue_redraw()


func _draw() -> void:
	if not is_active:
		return

	var r := bounds

	# Outer glow (wide, soft)
	draw_rect(Rect2(r.position - Vector2(GLOW_WIDTH, GLOW_WIDTH),
		r.size + Vector2(GLOW_WIDTH * 2, GLOW_WIDTH * 2)),
		BORDER_GLOW_COLOR, false, GLOW_WIDTH)

	# Inner glow (medium)
	draw_rect(Rect2(r.position - Vector2(6, 6), r.size + Vector2(12, 12)),
		Color(BORDER_COLOR, 0.15), false, 8.0)

	# Main border line
	draw_rect(r, BORDER_COLOR, false, BORDER_WIDTH)

	# Corner accents (bright, thicker)
	var cs := CORNER_SIZE
	var cc := CORNER_COLOR
	var cw: float = 4.0
	# Top-left
	draw_line(r.position, r.position + Vector2(cs, 0), cc, cw)
	draw_line(r.position, r.position + Vector2(0, cs), cc, cw)
	# Top-right
	var tr := Vector2(r.end.x, r.position.y)
	draw_line(tr, tr + Vector2(-cs, 0), cc, cw)
	draw_line(tr, tr + Vector2(0, cs), cc, cw)
	# Bottom-left
	var bl := Vector2(r.position.x, r.end.y)
	draw_line(bl, bl + Vector2(cs, 0), cc, cw)
	draw_line(bl, bl + Vector2(0, -cs), cc, cw)
	# Bottom-right
	draw_line(r.end, r.end + Vector2(-cs, 0), cc, cw)
	draw_line(r.end, r.end + Vector2(0, -cs), cc, cw)

	# "OUT OF BOUNDS" vibe — dark fill outside (subtle darkening beyond border)
	# Draw 4 large dark rects around the map
	var far: float = 100000.0
	var dark := Color(0.01, 0.02, 0.03, 0.7)
	# Top
	draw_rect(Rect2(r.position.x - far, r.position.y - far, r.size.x + far * 2, far), dark, true)
	# Bottom
	draw_rect(Rect2(r.position.x - far, r.end.y, r.size.x + far * 2, far), dark, true)
	# Left
	draw_rect(Rect2(r.position.x - far, r.position.y, far, r.size.y), dark, true)
	# Right
	draw_rect(Rect2(r.end.x, r.position.y, far, r.size.y), dark, true)
