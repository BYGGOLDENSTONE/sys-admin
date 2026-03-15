extends Node2D

const _MONO_FONT: Font = preload("res://assets/fonts/JetBrainsMono-Regular.ttf")
const TILE_SIZE: int = 64
const BODY_COLOR := Color("#0a0d14")
const BORDER_WIDTH: float = 2.0
const GLOW_WIDTH: float = 4.0
const GLOW_ALPHA: float = 0.3
const ICON_GLOW_WIDTH: float = 3.0
const ICON_GLOW_ALPHA: float = 0.25
const PORT_RADIUS: float = 6.0
const PORT_GLOW_RADIUS: float = 10.0
const PORT_HIT_RADIUS: float = 24.0
const OUTER_GLOW_WIDTH: float = 8.0
const OUTER_GLOW_ALPHA: float = 0.12
const GLOW_PULSE_SPEED: float = 2.0
const GLOW_PULSE_AMOUNT: float = 0.06

var definition: BuildingDefinition
var grid_cell: Vector2i = Vector2i.ZERO
var direction: int = 0  ## 0=default, 1=90°CW, 2=180°, 3=270°CW
var mirror_h: bool = false  ## Horizontal flip (left↔right)
var fill_ratio: float = 0.0
var _glow_time: float = 0.0
var _is_ghost: bool = false
var is_selected: bool = false
var _prev_working: bool = false
var _process_flash: float = 0.0

# Runtime state (set by SimulationManager)
var stored_data: Dictionary = {}  ## Key: packed int (DataEnums.pack_key), Value: int MB
var blocked_ports: Dictionary = {}  ## Port Purity: port_name → true
var port_carried_types: Dictionary = {}  ## Port Purity: port_name → { "content_state" → true } — cumulative record
var purity_checker: Callable  ## Set by GigManager: func(content, state) -> bool
var is_working: bool = false  ## True when building did actual work this tick
var status_reason: String = ""  ## Why the building is idle (set by SimulationManager)
var separator_mode: String = "state"  ## For separator: "state" or "content"
var separator_filter_value: int = 0  ## Filter value for separator (state or content int)
var classifier_filter_content: int = 0  ## Filter value for classifier (content int)
var selected_tier: int = 1  ## For producer: which tier to produce (1-3)
var upgrade_level: int = 0  ## Current upgrade level (0 = base)

# --- DIRTY FLAG (skip redraw when nothing changed) ---
var _draw_dirty: bool = true
var _prev_status_reason: String = ""
var _prev_stored_hash: int = 0
var _prev_fill_ratio: float = -1.0
var _prev_is_selected: bool = false

# --- POLYGON CACHE (rebuilt only when direction/mirror changes) ---
var _cached_base_poly: PackedVector2Array = PackedVector2Array()
var _cached_closed_poly: PackedVector2Array = PackedVector2Array()
var _cached_poly_dir: int = -1
var _cached_poly_mirror: bool = false
var _cached_poly_size: Vector2 = Vector2.ZERO


func _get_building_polygon(r: Rect2, vtype: String) -> PackedVector2Array:
	## Returns a distinctive silhouette polygon for each building type.
	## All shapes fit within the given rect — no footprint/hitbox change.
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	match vtype:
		"terminal":  # Octagon — hub, most distinctive
			var c := w * 0.2
			return PackedVector2Array([
				Vector2(x + c, y), Vector2(x + w - c, y),
				Vector2(x + w, y + c), Vector2(x + w, y + h - c),
				Vector2(x + w - c, y + h), Vector2(x + c, y + h),
				Vector2(x, y + h - c), Vector2(x, y + c)])
		"classifier":  # Bottom pointed — Y-output / sorting feel
			var notch := h * 0.15
			return PackedVector2Array([
				Vector2(x, y), Vector2(x + w, y),
				Vector2(x + w, y + h - notch),
				Vector2(x + w * 0.5, y + h),
				Vector2(x, y + h - notch)])
		"recoverer":  # Rounded rect — soft repair feel
			var cr := w * 0.15
			var pts := PackedVector2Array()
			for i in range(5):
				var angle := -PI / 2.0 + (PI / 2.0) * float(i) / 4.0
				pts.append(Vector2(x + w - cr + cos(angle) * cr, y + cr + sin(angle) * cr))
			for i in range(5):
				var angle := float(i) * PI / 8.0
				pts.append(Vector2(x + w - cr + cos(angle) * cr, y + h - cr + sin(angle) * cr))
			for i in range(5):
				var angle := PI / 2.0 + (PI / 2.0) * float(i) / 4.0
				pts.append(Vector2(x + cr + cos(angle) * cr, y + h - cr + sin(angle) * cr))
			for i in range(5):
				var angle := PI + (PI / 2.0) * float(i) / 4.0
				pts.append(Vector2(x + cr + cos(angle) * cr, y + cr + sin(angle) * cr))
			return pts
		"decryptor":  # Top notch — key slot opening
			var nw := w * 0.25
			var nd := h * 0.12
			return PackedVector2Array([
				Vector2(x, y), Vector2(x + (w - nw) * 0.5, y),
				Vector2(x + (w - nw) * 0.5, y + nd),
				Vector2(x + (w + nw) * 0.5, y + nd),
				Vector2(x + (w + nw) * 0.5, y),
				Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
		"encryptor":  # Bottom notch — key slot closing (mirror of decryptor)
			var nw := w * 0.25
			var nd := h * 0.12
			return PackedVector2Array([
				Vector2(x, y), Vector2(x + w, y),
				Vector2(x + w, y + h),
				Vector2(x + (w + nw) * 0.5, y + h),
				Vector2(x + (w + nw) * 0.5, y + h - nd),
				Vector2(x + (w - nw) * 0.5, y + h - nd),
				Vector2(x + (w - nw) * 0.5, y + h),
				Vector2(x, y + h)])
		"research":  # Pentagon — pointed top / lab roof
			var peak := h * 0.12
			return PackedVector2Array([
				Vector2(x + w * 0.5, y),
				Vector2(x + w, y + peak),
				Vector2(x + w, y + h),
				Vector2(x, y + h),
				Vector2(x, y + peak)])
		"separator":  # Chamfered rectangle — angled top-left and bottom-right
			var ch := w * 0.14
			return PackedVector2Array([
				Vector2(x + ch, y), Vector2(x + w, y),
				Vector2(x + w, y + h - ch), Vector2(x + w - ch, y + h),
				Vector2(x, y + h), Vector2(x, y + ch)])
		_:  # Default rect for splitter, merger, trash
			return PackedVector2Array([
				Vector2(x, y), Vector2(x + w, y),
				Vector2(x + w, y + h), Vector2(x, y + h)])


func _get_closed_polyline(poly: PackedVector2Array) -> PackedVector2Array:
	var closed := poly.duplicate()
	if closed.size() > 0:
		closed.append(closed[0])
	return closed


func _process(delta: float) -> void:
	if _is_ghost or definition == null:
		return
	PerfMonitor.bldg_total_count += 1
	_glow_time += delta
	# Processing flash on working state transition
	if is_working and not _prev_working:
		_process_flash = 1.0
		_draw_dirty = true
	if _prev_working != is_working:
		_draw_dirty = true
	_prev_working = is_working
	if _process_flash > 0.0:
		_process_flash = maxf(_process_flash - delta * 4.0, 0.0)
		_draw_dirty = true
	# Detect state changes that require redraw
	if status_reason != _prev_status_reason:
		_prev_status_reason = status_reason
		_draw_dirty = true
	if is_selected != _prev_is_selected:
		_prev_is_selected = is_selected
		_draw_dirty = true
	var cur_hash: int = stored_data.hash()
	if cur_hash != _prev_stored_hash:
		_prev_stored_hash = cur_hash
		_draw_dirty = true
	# Working/active buildings redraw for animated glow/pulse/breathing
	# Throttle: at far zoom, alternate frames per building to halve draw cost
	if is_working or _process_flash > 0.0:
		var _z := _get_zoom_level()
		if _z > 0.5 or Engine.get_process_frames() % 2 == (get_instance_id() % 2):
			_draw_dirty = true
	# Viewport culling — skip redraw for off-screen buildings
	if not _is_in_viewport():
		return
	if not _draw_dirty:
		return
	_draw_dirty = false
	queue_redraw()


func _is_in_viewport() -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return true
	var vp_half := get_viewport_rect().size / cam.zoom / 2.0
	var cam_pos := cam.global_position
	var my_pos := global_position
	var size_px := Vector2(definition.grid_size.x * TILE_SIZE, definition.grid_size.y * TILE_SIZE)
	var margin := 128.0
	return (my_pos.x + size_px.x + margin > cam_pos.x - vp_half.x
		and my_pos.x - margin < cam_pos.x + vp_half.x
		and my_pos.y + size_px.y + margin > cam_pos.y - vp_half.y
		and my_pos.y - margin < cam_pos.y + vp_half.y)


func setup(def: BuildingDefinition, cell: Vector2i, dir: int = 0, mirrored: bool = false) -> void:
	definition = def
	grid_cell = cell
	direction = dir
	mirror_h = mirrored
	_draw_dirty = true
	queue_redraw()


func play_place_animation() -> void:
	scale = Vector2(0.6, 0.6)
	modulate = Color(1.2, 1.4, 1.6, 0.8)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate", Color.WHITE, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func play_remove_animation() -> void:
	set_process(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.3, 0.3), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func _get_physical_side(logical_port: String) -> String:
	## Maps a logical port name to its physical side based on building rotation and mirror.
	if direction == 0 and not mirror_h:
		return logical_port
	var base_side: String
	var suffix: String = ""
	var us_pos: int = logical_port.find("_")
	if us_pos >= 0:
		base_side = logical_port.substr(0, us_pos)
		suffix = logical_port.substr(us_pos)
	else:
		base_side = logical_port
	var sides := ["left", "top", "right", "bottom"]
	var idx: int = sides.find(base_side)
	if idx < 0:
		return logical_port
	# Apply rotation first
	idx = (idx + direction) % 4
	# Apply horizontal mirror (left↔right)
	if mirror_h:
		if sides[idx] == "left":
			idx = 2  # right
		elif sides[idx] == "right":
			idx = 0  # left
	return sides[idx] + suffix


func _count_ports_on_logical_side(logical_base: String) -> int:
	var count: int = 0
	for p in definition.input_ports:
		if p == logical_base or p.begins_with(logical_base + "_"):
			count += 1
	for p in definition.output_ports:
		if p == logical_base or p.begins_with(logical_base + "_"):
			count += 1
	return count


func _rotate_polygon(poly: PackedVector2Array, center: Vector2) -> PackedVector2Array:
	if direction == 0:
		return poly
	var angle: float = direction * PI / 2.0
	var cos_a: float = cos(angle)
	var sin_a: float = sin(angle)
	var rotated := PackedVector2Array()
	for p in poly:
		var offset: Vector2 = p - center
		rotated.append(center + Vector2(
			offset.x * cos_a - offset.y * sin_a,
			offset.x * sin_a + offset.y * cos_a))
	return rotated


func _mirror_polygon(poly: PackedVector2Array, center: Vector2) -> PackedVector2Array:
	var mirrored := PackedVector2Array()
	for p in poly:
		mirrored.append(Vector2(2.0 * center.x - p.x, p.y))
	return mirrored


func get_port_local_position(port_side: String) -> Vector2:
	var physical: String = _get_physical_side(port_side)
	var base_side: String
	var port_idx: int = -1
	var us_pos: int = physical.find("_")
	if us_pos >= 0:
		base_side = physical.substr(0, us_pos)
		port_idx = int(physical.substr(us_pos + 1))
	else:
		base_side = physical

	var size := Vector2(definition.grid_size.x * TILE_SIZE, definition.grid_size.y * TILE_SIZE)

	# Count ports sharing this logical side
	var logical_base: String
	var logical_us: int = port_side.find("_")
	if logical_us >= 0:
		logical_base = port_side.substr(0, logical_us)
	else:
		logical_base = port_side
	var count: int = _count_ports_on_logical_side(logical_base)

	# Side length
	var side_len: float
	match base_side:
		"left", "right":
			side_len = size.y
		_:
			side_len = size.x

	# Offset along the side
	var offset: float
	if port_idx >= 0 and count > 1:
		offset = side_len * float(port_idx + 1) / float(count + 1)
	else:
		offset = side_len / 2.0

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


func get_total_stored() -> int:
	var total: int = 0
	for amount in stored_data.values():
		total += amount
	return total



func can_accept_data(amount: int = 1, state: int = DataEnums.DataState.PUBLIC, content: int = -1) -> bool:
	# Trash: always accepts everything
	if definition.processor != null and definition.processor.rule == "trash":
		return true
	if state == DataEnums.DataState.MALWARE:
		return false
	# Routing/filter buildings: always accept (they forward each tick, no capacity bottleneck)
	if definition.classifier != null or definition.splitter != null or definition.merger != null:
		return true
	if definition.processor != null and definition.processor.rule == "separator":
		return true
	# Fuel/keys always accepted by dual_input buildings (bypass capacity)
	if definition.dual_input:
		if definition.dual_input.fuel_matches_content and state == DataEnums.DataState.PUBLIC:
			return true
		if content == definition.dual_input.key_content:
			return true
	var cap: int = int(get_effective_value("capacity")) if definition.storage else 0
	if cap <= 0:
		return true
	return get_total_stored() + amount <= cap


func accepts_data(content: int, state: int) -> bool:
	return definition.accepts_data(content, state)


func is_active() -> bool:
	return true


func get_effective_value(stat: String) -> float:
	if definition.upgrade == null or upgrade_level <= 0:
		return _get_base_value(stat)
	if definition.upgrade.stat_target != stat:
		return _get_base_value(stat)
	var idx: int = upgrade_level - 1
	if idx < definition.upgrade.level_values.size():
		return definition.upgrade.level_values[idx]
	return _get_base_value(stat)


func _get_base_value(stat: String) -> float:
	match stat:
		"efficiency":
			return definition.processor.efficiency if definition.processor else 1.0
		"processing_rate":
			if definition.classifier:
				return definition.classifier.throughput_rate
			if definition.dual_input:
				return definition.dual_input.processing_rate
			if definition.producer:
				return definition.producer.processing_rate
			if definition.processor:
				return definition.processor.processing_rate
			return 0.0
		"capacity":
			return float(definition.storage.capacity) if definition.storage else 0.0
	return 0.0


func get_center_world() -> Vector2:
	return global_position + Vector2(
		definition.grid_size.x * TILE_SIZE / 2.0,
		definition.grid_size.y * TILE_SIZE / 2.0
	)


func _has_malware() -> bool:
	for key in stored_data:
		if stored_data[key] <= 0:
			continue
		if DataEnums.unpack_state(key) == DataEnums.DataState.MALWARE:
			return true
	return false


func get_malware_amount() -> int:
	var total: int = 0
	for key in stored_data:
		if DataEnums.unpack_state(key) == DataEnums.DataState.MALWARE:
			total += stored_data[key]
	return total


func update_display() -> void:
	if definition == null:
		return
	var cap: int = int(get_effective_value("capacity")) if definition.storage else 0
	var new_ratio: float = float(get_total_stored()) / float(cap) if cap > 0 else 0.0
	if new_ratio != _prev_fill_ratio:
		_prev_fill_ratio = new_ratio
		_draw_dirty = true
	fill_ratio = new_ratio


func get_port_at(local_pos: Vector2) -> Dictionary:
	if definition == null:
		return {}
	for port_side in definition.output_ports:
		var port_pos := get_port_local_position(port_side)
		if local_pos.distance_to(port_pos) <= PORT_HIT_RADIUS:
			return {"side": port_side, "is_output": true}
	for port_side in definition.input_ports:
		var port_pos := get_port_local_position(port_side)
		if local_pos.distance_to(port_pos) <= PORT_HIT_RADIUS:
			return {"side": port_side, "is_output": false}
	return {}


func _get_zoom_level() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam.zoom.x
	return 1.0


func _draw() -> void:
	if definition == null:
		return
	var _bldg_t0: int = Time.get_ticks_usec()

	var size := Vector2(definition.grid_size.x * TILE_SIZE, definition.grid_size.y * TILE_SIZE)
	var rect := Rect2(Vector2.ZERO, size)
	var center := size / 2.0
	var active: bool = is_active()
	var accent: Color = definition.color if active else Color(definition.color, 0.3)
	var zoom: float = _get_zoom_level()

	# Active/idle visual contrast — idle buildings desaturated toward gray
	if active and not is_working and not _is_ghost:
		accent = accent.lerp(Color(0.35, 0.35, 0.4), 0.3)

	# State-based pulse
	var pulse: float = 0.0
	if active:
		if is_working:
			pulse = (sin(_glow_time * 7.0) * 0.5 + 0.5) * GLOW_PULSE_AMOUNT * 4.0
		else:
			pulse = sin(_glow_time * GLOW_PULSE_SPEED) * GLOW_PULSE_AMOUNT * 0.5

	# === PCB MODE (zoom < 0.25) — bright chips on dark board ===
	if zoom < 0.25:
		_draw_pcb_mode(size, rect, accent, pulse)
		return

	# === MEDIUM MODE (zoom 0.25-0.45) — simplified ===
	var is_medium := zoom < 0.45

	var zoom_glow_scale: float = clampf(1.0 / zoom, 1.0, 2.5) if zoom < 1.0 else 1.0
	var outer_w: float = OUTER_GLOW_WIDTH * zoom_glow_scale  # used by selection highlight

	# Body — slightly brighter at medium zoom for visibility
	var body_color: Color = BODY_COLOR if not is_medium else Color(
		BODY_COLOR.r + accent.r * 0.05,
		BODY_COLOR.g + accent.g * 0.05,
		BODY_COLOR.b + accent.b * 0.05, 1.0)
	# Building silhouette polygon (cached — only recomputed on direction/mirror change)
	var vtype: String = definition.visual_type if definition else "default"
	if _cached_base_poly.is_empty() or _cached_poly_dir != direction \
			or _cached_poly_mirror != mirror_h or _cached_poly_size != size:
		_cached_base_poly = _get_building_polygon(rect, vtype)
		if direction != 0:
			_cached_base_poly = _rotate_polygon(_cached_base_poly, center)
		if mirror_h:
			_cached_base_poly = _mirror_polygon(_cached_base_poly, center)
		_cached_closed_poly = _get_closed_polyline(_cached_base_poly)
		_cached_poly_dir = direction
		_cached_poly_mirror = mirror_h
		_cached_poly_size = size
	var base_poly := _cached_base_poly
	# Breathing effect — working buildings gently pulse size via transform (no polygon regen)
	if is_working and active:
		var breathe_scale: float = 1.0 + sin(_glow_time * 3.0) * (1.5 / maxf(size.x, size.y))
		# Scale around center: vertex v → center + (v - center) * scale
		# Transform origin = center * (1 - scale), so draw_pos * scale + origin = correct
		var offset := center * (1.0 - breathe_scale)
		draw_set_transform(offset, 0.0, Vector2(breathe_scale, breathe_scale))
		draw_colored_polygon(base_poly, body_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_colored_polygon(base_poly, body_color)

	# Neon border (thicker at lower zoom + when selected)
	var border_w: float = BORDER_WIDTH * zoom_glow_scale
	if is_selected:
		border_w *= 2.0
	draw_polyline(_cached_closed_poly, accent, border_w)

	# Selection highlight (only at close/medium zoom)
	if is_selected:
		var sel_pulse: float = (sin(_glow_time * 4.0) * 0.5 + 0.5)
		var sel_rect := Rect2(
			Vector2(-outer_w * 1.5, -outer_w * 1.5),
			size + Vector2(outer_w * 3.0, outer_w * 3.0)
		)
		draw_rect(sel_rect, Color(accent, 0.15 + sel_pulse * 0.1), false, outer_w)
		if not is_medium:
			# Corner brackets only at close zoom
			var cb: float = 10.0
			var cw: float = 2.0
			var cc := Color(1.0, 1.0, 1.0, 0.6 + sel_pulse * 0.3)
			draw_line(Vector2(-4, -4), Vector2(-4 + cb, -4), cc, cw)
			draw_line(Vector2(-4, -4), Vector2(-4, -4 + cb), cc, cw)
			draw_line(Vector2(size.x + 4, -4), Vector2(size.x + 4 - cb, -4), cc, cw)
			draw_line(Vector2(size.x + 4, -4), Vector2(size.x + 4, -4 + cb), cc, cw)
			draw_line(Vector2(-4, size.y + 4), Vector2(-4 + cb, size.y + 4), cc, cw)
			draw_line(Vector2(-4, size.y + 4), Vector2(-4, size.y + 4 - cb), cc, cw)
			draw_line(Vector2(size.x + 4, size.y + 4), Vector2(size.x + 4 - cb, size.y + 4), cc, cw)
			draw_line(Vector2(size.x + 4, size.y + 4), Vector2(size.x + 4, size.y + 4 - cb), cc, cw)
			# Scan line
			var scan_y: float = fmod(_glow_time * 20.0, size.y + 8.0) - 4.0
			if scan_y >= -4.0 and scan_y <= size.y + 4.0:
				draw_line(Vector2(-4, scan_y), Vector2(size.x + 4, scan_y), Color(accent, 0.2), 1.0)

	# Inner detail lines (skip at medium zoom)
	if not is_medium:
		var line_color := Color(accent, 0.1)
		draw_line(Vector2(0, size.y * 0.3), Vector2(size.x, size.y * 0.3), line_color, 1.0)
		draw_line(Vector2(size.x * 0.3, 0), Vector2(size.x * 0.3, size.y * 0.3), line_color, 1.0)

	# Icon — rotate and/or mirror icon with building direction
	var icon_angle: float = direction * PI / 2.0 if direction != 0 else 0.0
	var icon_scale := Vector2(-1, 1) if mirror_h else Vector2.ONE
	if direction != 0 or mirror_h:
		draw_set_transform(center, icon_angle, icon_scale)
		_draw_icon(Vector2.ZERO, size, accent)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_icon(center, size, accent)

	# Building name — scale with zoom like source names
	var font := _MONO_FONT
	var inv_scale: float = clampf(1.0 / zoom, 1.0, 3.0)
	var font_size: int = int(11.0 * inv_scale)
	var text := definition.building_name
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := Vector2(
		(size.x - text_size.x) / 2.0,
		font_size + 4 * inv_scale
	)
	# Shadow + bright text (2 calls instead of 4)
	draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.85))
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.95))

	# Ports (always draw, but scale at medium zoom)
	_draw_ports(size, accent)

	# Status bars (skip at medium zoom)
	if not is_medium:
		pass  # Status bars removed — fill ratio is not actionable for routing buildings

	# Processing flash overlay — bright burst when building starts working
	if _process_flash > 0.0 and not is_medium:
		draw_colored_polygon(base_poly, Color(accent.r, accent.g, accent.b, _process_flash * 0.35))
		draw_polyline(_cached_closed_poly, Color(accent, _process_flash * 0.5), 2.0)

	# Malware overlay (skip for Trash — it destroys everything)
	if not _is_ghost and _has_malware():
		if not (definition.processor != null and definition.processor.rule == "trash"):
			var malware_alpha: float = 0.12 + sin(_glow_time * 6.0) * 0.06
			draw_colored_polygon(base_poly, Color(0.8, 0.0, 0.3, malware_alpha))
			draw_polyline(_cached_closed_poly, Color(0.8, 0.0, 0.3, 0.5), 2.0)

	# Status reason for idle buildings (root cause feedback)
	if not _is_ghost and active and not is_working and status_reason != "" and not is_medium:
		var reason_clr := Color(1.0, 0.75, 0.2, 0.85)
		var reason_font := _MONO_FONT
		var reason_fs := 9
		var reason_dims := reason_font.get_string_size(status_reason, HORIZONTAL_ALIGNMENT_CENTER, -1, reason_fs)
		var reason_pos := Vector2((size.x - reason_dims.x) / 2.0, size.y - 8)
		draw_string(reason_font, reason_pos + Vector2(1, 1), status_reason, HORIZONTAL_ALIGNMENT_LEFT, -1, reason_fs, Color(0, 0, 0, 0.7))
		draw_string(reason_font, reason_pos, status_reason, HORIZONTAL_ALIGNMENT_LEFT, -1, reason_fs, reason_clr)

	# Performance monitoring (aggregate across all buildings)
	PerfMonitor.bldg_draw_us += Time.get_ticks_usec() - _bldg_t0
	PerfMonitor.bldg_draw_count += 1


## PCB mode: glowing microchips with distinctive silhouettes per building type
func _draw_pcb_mode(size: Vector2, rect: Rect2, accent: Color, pulse: float) -> void:
	var center := size / 2.0
	var zoom: float = _get_zoom_level()
	var inv_zoom: float = clampf(1.0 / zoom, 2.0, 8.0)
	var vtype: String = definition.visual_type if definition else "default"

	# Body — tinted with accent color, using building silhouette polygon
	var chip_body := Color(
		BODY_COLOR.r + accent.r * 0.12,
		BODY_COLOR.g + accent.g * 0.12,
		BODY_COLOR.b + accent.b * 0.12, 1.0)
	# Use cached polygon (same as main draw — direction/mirror haven't changed)
	if _cached_base_poly.is_empty() or _cached_poly_dir != direction \
			or _cached_poly_mirror != mirror_h or _cached_poly_size != size:
		var vt: String = definition.visual_type if definition else "default"
		_cached_base_poly = _get_building_polygon(rect, vt)
		if direction != 0:
			_cached_base_poly = _rotate_polygon(_cached_base_poly, center)
		if mirror_h:
			_cached_base_poly = _mirror_polygon(_cached_base_poly, center)
		_cached_closed_poly = _get_closed_polyline(_cached_base_poly)
		_cached_poly_dir = direction
		_cached_poly_mirror = mirror_h
		_cached_poly_size = size
	draw_colored_polygon(_cached_base_poly, chip_body)

	# Thick bright border — silhouette shape
	var bw: float = 3.0
	if is_selected:
		bw = 5.0
	draw_polyline(_cached_closed_poly, accent, bw)

	# Center dot/pip (visible identifier)
	draw_circle(center, 5.0, Color(accent, 0.5 + pulse * 2.0))
	draw_circle(center, 2.5, accent)

	# Working indicator: brighter fill
	if is_working:
		draw_colored_polygon(_cached_base_poly, Color(accent, 0.12))

	# Malware overlay (still visible at distance — skip for Trash)
	if not _is_ghost and _has_malware():
		if not (definition.processor != null and definition.processor.rule == "trash"):
			draw_colored_polygon(_cached_base_poly, Color(0.8, 0.0, 0.3, 0.15 + sin(_glow_time * 6.0) * 0.08))


func _draw_icon(center: Vector2, size: Vector2, accent: Color) -> void:
	var vtype: String = definition.visual_type if definition else "default"
	var icon_center := Vector2(center.x, center.y + 6)

	match vtype:
		"classifier":
			_draw_icon_classifier(icon_center, size, accent)
		"separator":
			_draw_icon_separator(icon_center, size, accent)
		"decryptor":
			_draw_icon_decryptor(icon_center, size, accent)
		"encryptor":
			_draw_icon_encryptor(icon_center, size, accent)
		"recoverer":
			_draw_icon_recoverer(icon_center, size, accent)
		"trash":
			_draw_icon_trash(icon_center, size, accent)
		"research":
			_draw_icon_research(icon_center, size, accent)
		"splitter":
			_draw_icon_splitter(icon_center, size, accent)
		"merger":
			_draw_icon_merger(icon_center, size, accent)
		"terminal":
			_draw_icon_terminal(icon_center, size, accent)
		_:
			_draw_icon_default(icon_center, size, accent)


# --- CLASSIFIER: Binary content filter (selected → right, rest → bottom) ---
func _draw_icon_classifier(center: Vector2, size: Vector2, accent: Color) -> void:
	var s: float = minf(size.x, size.y) * 0.3
	var glow := Color(accent, ICON_GLOW_ALPHA)

	# Input line (left)
	var in_start := center + Vector2(-s * 0.8, 0)
	var in_end := center + Vector2(-s * 0.2, 0)
	draw_line(in_start, in_end, glow, ICON_GLOW_WIDTH)
	draw_line(in_start, in_end, accent, 2.0)

	# Center diamond (filter node)
	var d: float = s * 0.25
	var diamond := PackedVector2Array([
		center + Vector2(0, -d),
		center + Vector2(d, 0),
		center + Vector2(0, d),
		center + Vector2(-d, 0),
		center + Vector2(0, -d),
	])
	draw_polyline(diamond, glow, ICON_GLOW_WIDTH)
	draw_polyline(diamond, accent, 2.0)

	# Right output (selected content) — bright
	var out_right := center + Vector2(s * 0.8, 0)
	draw_line(center + Vector2(d, 0), out_right, glow, ICON_GLOW_WIDTH)
	draw_line(center + Vector2(d, 0), out_right, accent, 2.0)
	draw_circle(out_right, 3.0, accent)

	# Bottom output (rest) — dimmer
	var out_bottom := center + Vector2(0, s * 0.8)
	draw_line(center + Vector2(0, d), out_bottom, Color(accent, 0.4), ICON_GLOW_WIDTH)
	draw_line(center + Vector2(0, d), out_bottom, Color(accent, 0.6), 1.5)
	draw_circle(out_bottom, 2.0, Color(accent, 0.6))


# --- SEPARATOR: Binary state filter (selected → right, rest → bottom) ---
func _draw_icon_separator(center: Vector2, size: Vector2, accent: Color) -> void:
	var s: float = minf(size.x, size.y) * 0.3
	var glow := Color(accent, ICON_GLOW_ALPHA)

	# Input line (left)
	var in_start := center + Vector2(-s * 0.8, 0)
	var in_end := center + Vector2(-s * 0.2, 0)
	draw_line(in_start, in_end, glow, ICON_GLOW_WIDTH)
	draw_line(in_start, in_end, accent, 2.0)

	# Center node
	draw_circle(center, 4.0, accent)

	# Right output (selected state) — bright
	var out_right := center + Vector2(s * 0.8, 0)
	draw_line(center, out_right, glow, ICON_GLOW_WIDTH)
	draw_line(center, out_right, accent, 2.0)
	draw_circle(out_right, 3.0, accent)

	# Bottom output (rest) — dimmer
	var out_bottom := center + Vector2(0, s * 0.8)
	draw_line(center, out_bottom, Color(accent, 0.4), ICON_GLOW_WIDTH)
	draw_line(center, out_bottom, Color(accent, 0.6), 1.5)
	draw_circle(out_bottom, 2.0, Color(accent, 0.6))


# --- DECRYPTOR: Lock/key symbol ---
func _draw_icon_decryptor(center: Vector2, size: Vector2, accent: Color) -> void:
	var s: float = minf(size.x, size.y) * 0.3
	var glow := Color(accent, ICON_GLOW_ALPHA)

	# Lock body
	var lock_w: float = s * 0.8
	var lock_h: float = s * 0.6
	var lock_rect := Rect2(center + Vector2(-lock_w / 2, -lock_h * 0.1), Vector2(lock_w, lock_h))
	draw_rect(lock_rect, Color(accent, 0.15), true)
	draw_rect(lock_rect, accent, false, 1.5)

	# Lock shackle (arc on top)
	_draw_arc_segment(center + Vector2(0, -lock_h * 0.1), s * 0.3, PI, TAU, glow, ICON_GLOW_WIDTH)
	_draw_arc_segment(center + Vector2(0, -lock_h * 0.1), s * 0.3, PI, TAU, accent, 2.0)

	# Keyhole
	draw_circle(center + Vector2(0, lock_h * 0.2), 3.0, accent)
	var kh_bottom := center + Vector2(0, lock_h * 0.2 + 3)
	draw_line(kh_bottom, kh_bottom + Vector2(0, 5), accent, 2.0)


# --- ENCRYPTOR: Closed lock symbol (reverse of Decryptor) ---
func _draw_icon_encryptor(center: Vector2, size: Vector2, accent: Color) -> void:
	var s: float = minf(size.x, size.y) * 0.3
	var glow := Color(accent, ICON_GLOW_ALPHA)

	# Lock body (filled)
	var lock_w: float = s * 0.8
	var lock_h: float = s * 0.6
	var lock_rect := Rect2(center + Vector2(-lock_w / 2, -lock_h * 0.1), Vector2(lock_w, lock_h))
	draw_rect(lock_rect, Color(accent, 0.25), true)
	draw_rect(lock_rect, accent, false, 2.0)

	# Closed shackle (full arc on top)
	_draw_arc_segment(center + Vector2(0, -lock_h * 0.1), s * 0.3, PI, TAU, glow, ICON_GLOW_WIDTH)
	_draw_arc_segment(center + Vector2(0, -lock_h * 0.1), s * 0.3, PI, TAU, accent, 2.5)

	# Lock indicator (solid dot instead of keyhole)
	draw_circle(center + Vector2(0, lock_h * 0.2), 4.0, accent)
	draw_circle(center + Vector2(0, lock_h * 0.2), 2.0, Color.WHITE)


# --- RECOVERER: Wrench/repair symbol ---
func _draw_icon_recoverer(center: Vector2, size: Vector2, accent: Color) -> void:
	var s: float = minf(size.x, size.y) * 0.3
	var glow := Color(accent, ICON_GLOW_ALPHA)

	# Circular arrow (recovery/restore)
	_draw_arc_segment(center, s * 0.5, PI * 0.2, PI * 1.8, glow, ICON_GLOW_WIDTH)
	_draw_arc_segment(center, s * 0.5, PI * 0.2, PI * 1.8, accent, 2.0)

	# Arrow head at the end of arc
	var arrow_pos := center + Vector2(cos(PI * 0.2), sin(PI * 0.2)) * s * 0.5
	var arrow_dir := Vector2(cos(PI * 0.2 + PI / 2), sin(PI * 0.2 + PI / 2))
	draw_line(arrow_pos, arrow_pos + arrow_dir.rotated(0.5) * 6, accent, 2.0)
	draw_line(arrow_pos, arrow_pos + arrow_dir.rotated(-0.5) * 6, accent, 2.0)

	# Center plus sign (repair)
	draw_line(center + Vector2(-4, 0), center + Vector2(4, 0), accent, 2.0)
	draw_line(center + Vector2(0, -4), center + Vector2(0, 4), accent, 2.0)


# --- TRASH: X mark (data incinerator) ---
func _draw_icon_trash(center: Vector2, size: Vector2, accent: Color) -> void:
	var s: float = minf(size.x, size.y) * 0.3
	var glow := Color(accent, ICON_GLOW_ALPHA)
	# X mark
	var x_size: float = s * 0.45
	draw_line(center + Vector2(-x_size, -x_size), center + Vector2(x_size, x_size), glow, ICON_GLOW_WIDTH + 1)
	draw_line(center + Vector2(x_size, -x_size), center + Vector2(-x_size, x_size), glow, ICON_GLOW_WIDTH + 1)
	draw_line(center + Vector2(-x_size, -x_size), center + Vector2(x_size, x_size), accent, 2.5)
	draw_line(center + Vector2(x_size, -x_size), center + Vector2(-x_size, x_size), accent, 2.5)


# --- RESEARCH LAB: Atom/science symbol ---
func _draw_icon_research(center: Vector2, size: Vector2, accent: Color) -> void:
	var s: float = minf(size.x, size.y) * 0.3
	var glow := Color(accent, ICON_GLOW_ALPHA)

	# Three orbiting ellipses
	for i in range(3):
		var angle: float = i * PI / 3.0
		var points := PackedVector2Array()
		for j in range(25):
			var t: float = float(j) / 24.0 * TAU
			var px: float = cos(t) * s * 0.6
			var py: float = sin(t) * s * 0.25
			# Rotate the ellipse
			var rotated_x: float = px * cos(angle) - py * sin(angle)
			var rotated_y: float = px * sin(angle) + py * cos(angle)
			points.append(center + Vector2(rotated_x, rotated_y))
		if points.size() >= 2:
			draw_polyline(points, Color(accent, 0.4), 1.0, true)

	# Center nucleus
	draw_circle(center, 4.0, glow)
	draw_circle(center, 3.0, accent)


# --- SPLITTER: One-to-many arrows ---
func _draw_icon_splitter(center: Vector2, size: Vector2, accent: Color) -> void:
	var s: float = minf(size.x, size.y) * 0.35
	var glow := Color(accent, ICON_GLOW_ALPHA)

	# Input (left)
	var in_pos := center + Vector2(-s * 0.6, 0)
	draw_line(in_pos, center, glow, ICON_GLOW_WIDTH)
	draw_line(in_pos, center, accent, 2.0)

	# Two outputs (right, diverging)
	var out_top := center + Vector2(s * 0.6, -s * 0.4)
	var out_bot := center + Vector2(s * 0.6, s * 0.4)
	draw_line(center, out_top, glow, ICON_GLOW_WIDTH)
	draw_line(center, out_bot, glow, ICON_GLOW_WIDTH)
	draw_line(center, out_top, accent, 1.5)
	draw_line(center, out_bot, accent, 1.5)

	# Arrow heads
	draw_line(out_top, out_top + Vector2(-5, 2), accent, 1.5)
	draw_line(out_top, out_top + Vector2(-3, 5), accent, 1.5)
	draw_line(out_bot, out_bot + Vector2(-5, -2), accent, 1.5)
	draw_line(out_bot, out_bot + Vector2(-3, -5), accent, 1.5)

	# Center dot
	draw_circle(center, 3.0, accent)


# --- MERGER: Many-to-one arrows ---
func _draw_icon_merger(center: Vector2, size: Vector2, accent: Color) -> void:
	var s: float = minf(size.x, size.y) * 0.35
	var glow := Color(accent, ICON_GLOW_ALPHA)

	# Two inputs (left, converging)
	var in_top := center + Vector2(-s * 0.6, -s * 0.4)
	var in_bot := center + Vector2(-s * 0.6, s * 0.4)
	draw_line(in_top, center, glow, ICON_GLOW_WIDTH)
	draw_line(in_bot, center, glow, ICON_GLOW_WIDTH)
	draw_line(in_top, center, accent, 1.5)
	draw_line(in_bot, center, accent, 1.5)

	# Output (right)
	var out_pos := center + Vector2(s * 0.6, 0)
	draw_line(center, out_pos, glow, ICON_GLOW_WIDTH)
	draw_line(center, out_pos, accent, 2.0)

	# Arrow head
	draw_line(out_pos, out_pos + Vector2(-5, -3), accent, 1.5)
	draw_line(out_pos, out_pos + Vector2(-5, 3), accent, 1.5)

	# Center dot
	draw_circle(center, 3.0, accent)


# --- TERMINAL: Mission hub / delivery icon ---
func _draw_icon_terminal(center: Vector2, size: Vector2, accent: Color) -> void:
	var s: float = minf(size.x, size.y) * 0.3
	var glow := Color(accent, ICON_GLOW_ALPHA)

	# Monitor outline
	var mon_w: float = s * 1.2
	var mon_h: float = s * 0.8
	var mon_rect := Rect2(center + Vector2(-mon_w / 2, -mon_h / 2 - s * 0.1), Vector2(mon_w, mon_h))
	draw_rect(mon_rect, Color(accent, 0.15), true)
	draw_rect(mon_rect, glow, false, ICON_GLOW_WIDTH)
	draw_rect(mon_rect, accent, false, 2.0)

	# Stand below monitor
	var stand_top := Vector2(center.x, mon_rect.end.y)
	var stand_bot := Vector2(center.x, mon_rect.end.y + s * 0.3)
	draw_line(stand_top, stand_bot, accent, 2.0)
	draw_line(stand_bot + Vector2(-s * 0.3, 0), stand_bot + Vector2(s * 0.3, 0), accent, 2.0)

	# Arrow pointing into screen (delivery)
	var arrow_tip := Vector2(center.x, center.y - s * 0.1)
	draw_line(arrow_tip + Vector2(0, -s * 0.35), arrow_tip, glow, ICON_GLOW_WIDTH)
	draw_line(arrow_tip + Vector2(0, -s * 0.35), arrow_tip, accent, 2.0)
	draw_line(arrow_tip, arrow_tip + Vector2(-4, -6), accent, 2.0)
	draw_line(arrow_tip, arrow_tip + Vector2(4, -6), accent, 2.0)


# --- DEFAULT: Simple dot ---
func _draw_icon_default(center: Vector2, _size: Vector2, accent: Color) -> void:
	draw_circle(center, 4.0, Color(accent, 0.5))


# --- PORTS ---
func _draw_ports(size: Vector2, accent: Color) -> void:
	if definition == null:
		return

	var zoom: float = _get_zoom_level()
	var port_pulse: float = 0.0
	if is_active() and is_working:
		port_pulse = sin(_glow_time * 5.0) * 0.5 + 0.5

	# Output ports (accent color)
	for port_side in definition.output_ports:
		var pos := get_port_local_position(port_side)
		if zoom > 0.5:
			# Full detail: glow + solid + inner dot (3 circles)
			var gr := PORT_GLOW_RADIUS + port_pulse * 4.0
			draw_circle(pos, gr, Color(accent, 0.12 + port_pulse * 0.15))
			draw_circle(pos, PORT_RADIUS, Color(accent, 0.8))
			draw_circle(pos, PORT_RADIUS * 0.4, Color.WHITE)
		else:
			# Medium/far: solid + inner dot (2 circles)
			draw_circle(pos, PORT_RADIUS, Color(accent, 0.8))
			draw_circle(pos, PORT_RADIUS * 0.4, Color.WHITE)
	# Input ports (white/dim)
	for port_side in definition.input_ports:
		var pos := get_port_local_position(port_side)
		if zoom > 0.5:
			var gr := PORT_GLOW_RADIUS + port_pulse * 2.0
			draw_circle(pos, gr, Color(1, 1, 1, 0.08 + port_pulse * 0.08))
			draw_circle(pos, PORT_RADIUS, Color(0.6, 0.65, 0.7, 0.8))
			draw_circle(pos, PORT_RADIUS * 0.4, Color.WHITE)
		else:
			draw_circle(pos, PORT_RADIUS, Color(0.6, 0.65, 0.7, 0.8))
			draw_circle(pos, PORT_RADIUS * 0.4, Color.WHITE)


# --- UTILITY: Draw arc segment ---
func _draw_arc_segment(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	var point_count: int = maxi(8, int((end_angle - start_angle) / PI * 16))
	var points := PackedVector2Array()
	for i in range(point_count + 1):
		var t: float = float(i) / float(point_count)
		var angle: float = start_angle + t * (end_angle - start_angle)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if points.size() >= 2:
		draw_polyline(points, color, width, true)
