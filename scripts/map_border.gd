extends Node2D

## Draws the map boundary as a visible border with glow effect.
## Only active for bounded maps (levels 1-8).

var bounds: Rect2 = Rect2()
var is_active: bool = false

const BORDER_COLOR := Color(0.0, 0.85, 0.95, 0.8)
const BORDER_GLOW_INNER := Color(0.0, 0.85, 0.95, 0.2)
const BORDER_WIDTH: float = 4.0
const CORNER_SIZE: float = 64.0
const CORNER_COLOR := Color(0.0, 1.0, 1.0, 0.95)
const OUTSIDE_COLOR := Color(0.01, 0.02, 0.03, 0.88)
const MARGIN: float = 8000.0  ## How far outside to darken


func setup(world_bounds: Rect2) -> void:
	bounds = world_bounds
	is_active = true
	# Draw on top of PCB grid
	z_index = 5
	queue_redraw()


func _draw() -> void:
	if not is_active:
		return

	var r := bounds

	# Dark fill outside the map boundary (4 rects forming a frame)
	# Top
	draw_rect(Rect2(r.position.x - MARGIN, r.position.y - MARGIN,
		r.size.x + MARGIN * 2, MARGIN), OUTSIDE_COLOR, true)
	# Bottom
	draw_rect(Rect2(r.position.x - MARGIN, r.end.y,
		r.size.x + MARGIN * 2, MARGIN), OUTSIDE_COLOR, true)
	# Left
	draw_rect(Rect2(r.position.x - MARGIN, r.position.y,
		MARGIN, r.size.y), OUTSIDE_COLOR, true)
	# Right
	draw_rect(Rect2(r.end.x, r.position.y,
		MARGIN, r.size.y), OUTSIDE_COLOR, true)

	# Inner glow (soft border halo)
	draw_rect(Rect2(r.position - Vector2(8, 8), r.size + Vector2(16, 16)),
		BORDER_GLOW_INNER, false, 12.0)

	# Main border line (thick, bright)
	draw_rect(r, BORDER_COLOR, false, BORDER_WIDTH)

	# Corner accents (extra bright, thicker)
	var cs := CORNER_SIZE
	var cc := CORNER_COLOR
	var cw: float = 5.0
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
