extends Node2D

## Data source — grid-aligned rectangular structure with output ports.
## Players connect cables directly from source output ports to buildings.

signal fire_breached(source: Node2D)

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

## --- FIRE (Forced Isolation & Restriction Enforcer) ---
var fire_active: bool = false           ## true = FIRE blocking output, false = breached/no FIRE
var fire_progress: Dictionary = {}      ## {sub_type_id: current_amount_float}
var fire_regen_accumulator: float = 0.0 ## For regen type: accumulated regen since last feed
var fire_input_ports: Array[String] = [] ## Generated FIRE input port names (e.g. "fire_left_0")
var _fire_port_side: String = ""        ## Which side FIRE ports are on (opposite of CT direction)
var _fire_breach_flash: float = 0.0     ## Visual flash timer when FIRE is breached

## --- NETWORK STATUS (Hard sources only) ---
var network_secured: bool = false       ## Set by main.gd — true when this Hard source is SECURED


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


## Dominant content color — derived from content_weights at setup
var _dominant_color: Color = Color.CYAN

func setup(def: DataSourceDefinition, origin: Vector2i) -> void:
	definition = def
	grid_cell = origin
	_dominant_color = _compute_dominant_color()
	_generate_rectangular_cells()
	_generate_output_ports()
	_init_fire_state()
	queue_redraw()


## --- FIRE SYSTEM ---

func _init_fire_state() -> void:
	if not has_fire():
		fire_active = false
		return
	fire_active = true
	fire_progress.clear()
	for req in definition.fire_requirements:
		fire_progress[int(req.sub_type)] = 0.0


func has_fire() -> bool:
	return definition != null and definition.fire_type != "none" and not definition.fire_requirements.is_empty()


func is_fire_breached() -> bool:
	if not has_fire():
		return true
	return not fire_active


func setup_fire_ports(ct_world_pos: Vector2) -> void:
	## Calculate FIRE input port side: opposite of CT direction
	if not has_fire():
		return
	var my_center := get_center_world()
	var dir := ct_world_pos - my_center
	if absf(dir.x) >= absf(dir.y):
		_fire_port_side = "left" if dir.x > 0 else "right"
	else:
		_fire_port_side = "top" if dir.y > 0 else "bottom"
	_generate_fire_input_ports()
	## Remove output ports from the FIRE side (dedicated FIRE-only edge)
	var fire_prefix: String = _fire_port_side + "_"
	var new_output: Array[String] = []
	for p in output_ports:
		if not p.begins_with(fire_prefix):
			new_output.append(p)
	output_ports = new_output
	queue_redraw()


func _generate_fire_input_ports() -> void:
	fire_input_ports.clear()
	if _fire_port_side.is_empty():
		return
	## One FIRE input port per requirement
	var count: int = definition.fire_requirements.size()
	for i in range(count):
		fire_input_ports.append("fire_%s_%d" % [_fire_port_side, i])


func feed_fire(sub_type: int, amount: float) -> void:
	## Feed data into FIRE. Matching sub-types add progress; wrong sub-types penalize all requirements.
	if not fire_active:
		return
	if fire_progress.has(sub_type):
		fire_progress[sub_type] += amount
	else:
		## Wrong sub-type — subtract from all active requirements (forces player to filter first)
		for st in fire_progress:
			fire_progress[st] = maxf(0.0, fire_progress[st] - amount)
	_check_fire_breach()


func _check_fire_breach() -> void:
	if not fire_active:
		return
	for req in definition.fire_requirements:
		var st: int = int(req.sub_type)
		var needed: float = float(req.amount)
		if fire_progress.get(st, 0.0) < needed:
			return
	## All requirements met — breach FIRE
	fire_active = false
	_fire_breach_flash = 1.0
	fire_breached.emit(self)
	print("[FIRE] Breached — %s" % definition.source_name)


func process_fire_regen(delta: float) -> void:
	## For regen type: FIRE regenerates over time. Must be called each sim tick.
	if definition.fire_type != "regen":
		return
	if not fire_active:
		## Already breached — check if regen should re-activate
		## Regen decays progress over time; if any requirement drops below threshold, re-activate
		var should_reactivate: bool = false
		for req in definition.fire_requirements:
			var st: int = int(req.sub_type)
			var needed: float = float(req.amount)
			fire_progress[st] = maxf(0.0, fire_progress.get(st, 0.0) - definition.fire_regen_rate * delta)
			if fire_progress[st] < needed:
				should_reactivate = true
		if should_reactivate:
			fire_active = true
			print("[FIRE] Reactivated — %s (regen closed)" % definition.source_name)
	else:
		## Active FIRE — also decay progress (player must continuously feed)
		for req in definition.fire_requirements:
			var st: int = int(req.sub_type)
			fire_progress[st] = maxf(0.0, fire_progress.get(st, 0.0) - definition.fire_regen_rate * delta)


func _compute_dominant_color() -> Color:
	## Hard/endgame sources use their own distinct color for map visibility.
	## Easy/medium sources use the highest-weight content type color.
	if definition.difficulty == "hard" or definition.difficulty == "endgame":
		return definition.color
	var weights: Dictionary = definition.content_weights
	if weights.is_empty():
		return definition.color
	var best_content: int = -1
	var best_weight: float = -1.0
	for content_type in weights:
		if weights[content_type] > best_weight:
			best_weight = weights[content_type]
			best_content = content_type
	if best_content >= 0:
		return DataEnums.content_color(best_content)
	return definition.color


func _generate_rectangular_cells() -> void:
	cells.clear()
	for x in range(definition.grid_size.x):
		for y in range(definition.grid_size.y):
			cells.append(Vector2i(grid_cell.x + x, grid_cell.y + y))


func _generate_output_ports() -> void:
	## Generate output ports. If output_port_count > 0, distribute that many ports
	## across edges (round-robin: top, right, bottom, left). Otherwise auto from grid_size.
	output_ports.clear()
	var w: int = definition.grid_size.x
	var h: int = definition.grid_size.y
	var target_count: int = definition.output_port_count
	if target_count <= 0:
		# Auto mode: (edge_length - 1) ports per edge
		for i in range(w - 1):
			output_ports.append("top_%d" % i)
		for i in range(h - 1):
			output_ports.append("right_%d" % i)
		for i in range(w - 1):
			output_ports.append("bottom_%d" % i)
		for i in range(h - 1):
			output_ports.append("left_%d" % i)
		return
	# Fixed count mode: distribute ports across edges round-robin
	var sides: Array[String] = ["top", "right", "bottom", "left"]
	# Max ports per side = edge_length - 1 (top/bottom = w-1, left/right = h-1)
	var max_per_side: Dictionary = {"top": w - 1, "right": h - 1, "bottom": w - 1, "left": h - 1}
	var side_counts: Dictionary = {"top": 0, "right": 0, "bottom": 0, "left": 0}
	var placed: int = 0
	var side_idx: int = 0
	while placed < target_count:
		var side: String = sides[side_idx % 4]
		if side_counts[side] < max_per_side[side]:
			side_counts[side] += 1
			placed += 1
		side_idx += 1
		if side_idx >= 4 * target_count:
			break  # Safety: prevent infinite loop
	for side in sides:
		for i in range(side_counts[side]):
			output_ports.append("%s_%d" % [side, i])


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


func _count_fire_ports_on_side(base_side: String) -> int:
	var prefix: String = "fire_%s_" % base_side
	var count: int = 0
	for p in fire_input_ports:
		if p.begins_with(prefix):
			count += 1
	return count


func get_port_local_position(port_side: String) -> Vector2:
	## Handles both output ports ("left_0") and FIRE input ports ("fire_left_0")
	var is_fire: bool = port_side.begins_with("fire_")
	var stripped: String = port_side.substr(5) if is_fire else port_side

	var base_side: String
	var port_idx: int = 0
	var us_pos: int = stripped.find("_")
	if us_pos >= 0:
		base_side = stripped.substr(0, us_pos)
		port_idx = int(stripped.substr(us_pos + 1))
	else:
		base_side = stripped

	var size := Vector2(definition.grid_size.x * TILE_SIZE, definition.grid_size.y * TILE_SIZE)
	var count: int = _count_fire_ports_on_side(base_side) if is_fire else _count_ports_on_side(base_side)

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
	## Hit-test for output ports and FIRE input ports
	for port_side in output_ports:
		var port_pos := get_port_local_position(port_side)
		if local_pos.distance_to(port_pos) <= PORT_HIT_RADIUS:
			return {"side": port_side, "is_output": true}
	for port_side in fire_input_ports:
		var port_pos := get_port_local_position(port_side)
		if local_pos.distance_to(port_pos) <= PORT_HIT_RADIUS:
			return {"side": port_side, "is_output": false, "is_fire": true}
	return {}


## --- ZOOM LEVEL ---

func _get_zoom_level() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam.zoom.x
	return 1.0


func _get_difficulty_glow_mult() -> float:
	match definition.difficulty:
		"hard": return 1.6
		"endgame": return 2.2
		_: return 1.0


## --- DRAWING ---

func _draw() -> void:
	if definition == null:
		return

	var zoom: float = _get_zoom_level()
	var size := Vector2(definition.grid_size.x * TILE_SIZE, definition.grid_size.y * TILE_SIZE)
	var rect := Rect2(Vector2.ZERO, size)

	var accent: Color = _dominant_color
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

	# FIRE status overlay
	if has_fire():
		_draw_fire_status(center, size)

	# Network SECURED badge (Hard sources only)
	if definition.difficulty == "hard":
		_draw_network_badge(center)


## PCB mode: zoom-compensated glowing dots
func _draw_pcb_source(accent: Color, pulse: float, zoom: float, size: Vector2) -> void:
	var center := size / 2.0
	var inv_zoom: float = clampf(1.0 / zoom, 2.0, 8.0)
	var glow_mult: float = _get_difficulty_glow_mult()

	# Soft glow halo
	var glow_r: float = maxf(size.x, size.y) * 0.3 * inv_zoom * glow_mult
	draw_circle(center, glow_r, Color(accent, (0.035 + pulse * 0.01) * glow_mult))
	draw_circle(center, glow_r * 0.5, Color(accent, (0.09 + pulse * 0.03) * glow_mult))
	draw_circle(center, glow_r * 0.25, Color(accent, (0.2 + pulse * 0.06) * glow_mult))

	# Bright core
	var core_r: float = maxf(6.0, glow_r * 0.08) * glow_mult
	draw_circle(center, core_r, Color(accent, 0.4 + pulse * 3.0))
	draw_circle(center, core_r * 0.4, Color(1.0, 1.0, 1.0, 0.5 * glow_mult))


## Medium zoom: simplified with soft glow halo
func _draw_medium_source(accent: Color, pulse: float, zoom: float, size: Vector2) -> void:
	var zoom_boost: float = clampf(1.0 / zoom, 1.0, 2.5)
	var glow_mult: float = _get_difficulty_glow_mult()
	var base_alpha: float = (0.15 + pulse) * zoom_boost * glow_mult
	var border_alpha: float = (0.5 + pulse * 2.0) * zoom_boost * glow_mult
	var center := size / 2.0
	var rect := Rect2(Vector2.ZERO, size)

	# Soft glow halo
	var glow_r: float = maxf(size.x, size.y) * 0.4 * glow_mult
	draw_circle(center, glow_r * 1.2, Color(accent, 0.04 * zoom_boost * glow_mult))
	draw_circle(center, glow_r * 0.6, Color(accent, (0.08 * zoom_boost + pulse * 0.02) * glow_mult))

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
	## Output ports — accent color (dimmed if FIRE active)
	var out_alpha: float = 0.25 if fire_active else 0.8
	for port_side in output_ports:
		var pos := get_port_local_position(port_side)
		var gr := PORT_GLOW_RADIUS + port_pulse * 2.0
		draw_circle(pos, gr, Color(accent, (0.1 + port_pulse * 0.08) * (0.3 if fire_active else 1.0)))
		draw_circle(pos, PORT_RADIUS, Color(accent, out_alpha))
		if not fire_active:
			draw_circle(pos, PORT_RADIUS * 0.4, Color.WHITE)
	## FIRE input ports — red/orange color
	if not fire_input_ports.is_empty():
		var fire_color := Color(1.0, 0.3, 0.1) if fire_active else Color(0.2, 1.0, 0.5)
		for port_side in fire_input_ports:
			var pos := get_port_local_position(port_side)
			var gr := PORT_GLOW_RADIUS + port_pulse * 2.0
			draw_circle(pos, gr, Color(fire_color, 0.15 + port_pulse * 0.1))
			draw_circle(pos, PORT_RADIUS * 1.2, Color(fire_color, 0.9))
			draw_circle(pos, PORT_RADIUS * 0.5, Color.WHITE)


func _draw_fire_status(center: Vector2, size: Vector2) -> void:
	var font := _MONO_FONT
	var zoom: float = _get_zoom_level()
	var inv_scale: float = clampf(1.0 / zoom, 1.0, 3.0)

	## Calculate total progress ratio
	var total_needed: float = 0.0
	var total_current: float = 0.0
	for req in definition.fire_requirements:
		var st: int = int(req.sub_type)
		var needed: float = float(req.amount)
		total_needed += needed
		total_current += minf(fire_progress.get(st, 0.0), needed)
	var ratio: float = total_current / maxf(total_needed, 1.0)

	if fire_active:
		## FIRE Active — red shield icon + progress bar
		var fire_color := Color(1.0, 0.3, 0.1)

		## Shield icon (simple triangle/circle)
		var icon_y: float = center.y + 8.0 * inv_scale
		var icon_r: float = 8.0 * inv_scale
		draw_circle(Vector2(center.x, icon_y), icon_r, Color(fire_color, 0.7))
		draw_circle(Vector2(center.x, icon_y), icon_r * 0.5, Color(1.0, 1.0, 1.0, 0.4))

		## "FIRE" label
		var label_size: int = int(9.0 * inv_scale)
		var label := "FIRE"
		var ls := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, label_size)
		var label_pos := Vector2(center.x - ls.x / 2.0, icon_y + icon_r + label_size + 2.0 * inv_scale)
		draw_string(font, label_pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color(0, 0, 0, 0.7))
		draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color(fire_color, 0.9))

		## Progress bar
		var bar_w: float = size.x * 0.6
		var bar_h: float = 4.0 * inv_scale
		var bar_x: float = center.x - bar_w / 2.0
		var bar_y: float = label_pos.y + 4.0 * inv_scale
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0, 0, 0, 0.5), true)
		if ratio > 0.0:
			draw_rect(Rect2(bar_x, bar_y, bar_w * ratio, bar_h), Color(fire_color, 0.8), true)
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(fire_color, 0.4), false, 1.0)

		## Progress text (e.g., "12/50 MB")
		if definition.fire_requirements.size() == 1:
			var req = definition.fire_requirements[0]
			var cur: float = fire_progress.get(int(req.sub_type), 0.0)
			var txt := "%d/%d MB" % [int(cur), int(req.amount)]
			var txt_size: int = int(8.0 * inv_scale)
			var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, txt_size)
			var txt_pos := Vector2(center.x - ts.x / 2.0, bar_y + bar_h + txt_size + 2.0 * inv_scale)
			draw_string(font, txt_pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, txt_size, Color(fire_color, 0.7))
	else:
		## FIRE Breached — dramatic green burst then subtle indicator
		if _fire_breach_flash > 0.0:
			var flash_alpha: float = _fire_breach_flash * 0.4
			# Full-source green overlay
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 1.0, 0.5, flash_alpha), true)
			# Expanding shockwave rings
			var ring_progress: float = 1.0 - _fire_breach_flash
			for r in range(3):
				var rp: float = ring_progress + float(r) * 0.15
				if rp > 0.0 and rp < 1.0:
					var ring_r: float = maxf(size.x, size.y) * (0.3 + rp * 1.2)
					var ring_a: float = (1.0 - rp) * 0.5
					draw_arc(center, ring_r, 0.0, TAU, 32, Color(0.2, 1.0, 0.5, ring_a), 3.0 * (1.0 - rp), true)
			# Bright center burst
			var burst_r: float = maxf(size.x, size.y) * 0.3 * _fire_breach_flash
			draw_circle(center, burst_r, Color(0.3, 1.0, 0.6, _fire_breach_flash * 0.6))
			draw_circle(center, burst_r * 0.3, Color(1.0, 1.0, 1.0, _fire_breach_flash * 0.8))
			_fire_breach_flash = maxf(0.0, _fire_breach_flash - 0.012)

		## Small green unlock icon
		var icon_y: float = center.y + 8.0 * inv_scale
		var icon_r: float = 5.0 * inv_scale
		var breach_color := Color(0.2, 1.0, 0.5, 0.5 + sin(_glow_time * 2.0) * 0.15)
		draw_circle(Vector2(center.x, icon_y), icon_r, breach_color)
		draw_circle(Vector2(center.x, icon_y), icon_r * 0.4, Color(1.0, 1.0, 1.0, 0.3))


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


func _draw_network_badge(center: Vector2) -> void:
	## Draws SECURED/UNSECURED badge above Hard sources.
	var font := _MONO_FONT
	var font_size := 11
	var label: String
	var badge_color: Color
	var glow_alpha: float

	if network_secured:
		label = "SECURED"
		badge_color = Color(0.2, 1.0, 0.4)
		glow_alpha = 0.12 + sin(_glow_time * 2.0) * 0.04
	else:
		label = "UNSECURED"
		badge_color = Color(1.0, 0.3, 0.2)
		glow_alpha = 0.06

	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var size := Vector2(definition.grid_size.x * TILE_SIZE, definition.grid_size.y * TILE_SIZE)
	var badge_pos := Vector2(center.x - text_size.x / 2.0, -14.0)

	# Background glow
	var bg_rect := Rect2(badge_pos.x - 6, badge_pos.y - font_size, text_size.x + 12, font_size + 6)
	draw_rect(bg_rect, Color(0, 0, 0, 0.7), true)
	draw_rect(bg_rect, Color(badge_color, 0.6), false, 1.5)
	# Subtle glow behind
	draw_rect(Rect2(bg_rect.position - Vector2(3, 3), bg_rect.size + Vector2(6, 6)),
		Color(badge_color, glow_alpha), true)
	draw_string(font, badge_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(badge_color, 0.95))
