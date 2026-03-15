extends RefCounted

## Level-aware map generator.
## Bounded maps (levels 1-8): region-grid based, even distribution.
## Infinite maps (level 9): lazy chunk-based generation.

const CHUNK_SIZE := 32           ## 32x32 cells per chunk
const MIN_SOURCE_DISTANCE := 8   ## Min distance between ANY two sources (Manhattan)
const MIN_SAME_TYPE_DISTANCE := 18  ## Min distance between same-type sources
const MAX_PLACEMENT_ATTEMPTS := 60
const CT_EXCLUSION_RADIUS := 5   ## No sources within this of CT center (Chebyshev)
const TILE_SIZE := 64
const REGION_SIZE := 25          ## Region grid cell size for bounded maps
const MAX_PER_SOURCE_TYPE := 3   ## Max total placements per source type (includes guarantees)

var _pools: Dictionary = {
	"easy": ["isp_backbone", "public_database", "atm", "smart_lock", "traffic_camera", "data_kiosk", "bank_terminal"],
	"medium": ["hospital_terminal", "public_library", "shop_server", "biotech_lab"],
	"hard": ["corporate_server", "government_archive"],
	"endgame": ["military_network", "dark_web_node"],
}

## Tutorial-critical sources: offsets from map center.
var _tutorial_offsets := [
	{"name": "isp_backbone", "offset": Vector2i(10, -10)},    # NE — Gig 1
	{"name": "atm", "offset": Vector2i(12, 0)},                # E  — Gig 2
	{"name": "data_kiosk", "offset": Vector2i(-12, 0)},        # W  — Gig 3
	{"name": "bank_terminal", "offset": Vector2i(0, 12)},      # S  — Gig 3
	{"name": "hospital_terminal", "offset": Vector2i(0, 22)},  # SS — Gig 4
]

## Sector-based guarantees for non-tutorial sources
var _sector_guarantees := [
	{"name": "biotech_lab", "angle": PI, "r_min": 12.0, "r_max": 25.0},
	{"name": "corporate_server", "angle": -PI / 4.0, "r_min": 18.0, "r_max": 35.0},
	{"name": "government_archive", "angle": PI / 4.0, "r_min": 18.0, "r_max": 35.0},
	{"name": "corporate_server", "angle": 3.0 * PI / 4.0, "r_min": 18.0, "r_max": 35.0},
	{"name": "government_archive", "angle": -3.0 * PI / 4.0, "r_min": 18.0, "r_max": 35.0},
]

var _world_seed: int = 0
var _source_manager: Node = null
var _placed_origins: Array[Vector2i] = []
var _placed_names: Dictionary = {}  ## source_name → Array[Vector2i]
var _generated_chunks: Dictionary = {}  ## Vector2i → true (infinite mode)
var _ct_chunk: Vector2i

## Level-aware configuration
var _map_center: Vector2i = Vector2i(256, 256)
var _map_bounds: Rect2i = Rect2i()  ## Cell-space bounds
var _is_bounded: bool = false
var _allowed_pools: Array = ["easy", "medium", "hard", "endgame"]
var _is_tutorial_level: bool = true


func configure(level: int) -> void:
	var data: Dictionary = LevelConfig.get_level(level)
	_map_center = LevelConfig.get_map_center(level)
	_is_bounded = not data.is_infinite
	_allowed_pools = data.source_pools
	_is_tutorial_level = data.is_tutorial
	if _is_bounded:
		var half: int = data.map_size / 2
		_map_bounds = Rect2i(
			_map_center.x - half, _map_center.y - half,
			data.map_size, data.map_size
		)


func generate_map(seed_value: int, source_manager: Node) -> void:
	_world_seed = seed_value
	_source_manager = source_manager
	_placed_origins.clear()
	_placed_names.clear()
	_generated_chunks.clear()
	_ct_chunk = Vector2i(_map_center.x / CHUNK_SIZE, _map_center.y / CHUNK_SIZE)

	if _is_tutorial_level:
		_place_guaranteed()

	if _is_bounded:
		_generate_bounded_map()
	else:
		for cx in range(_ct_chunk.x - 3, _ct_chunk.x + 4):
			for cy in range(_ct_chunk.y - 3, _ct_chunk.y + 4):
				_generate_chunk(Vector2i(cx, cy))

	print("[MapGenerator] Generated map — seed: %d, sources: %d, bounded: %s" % [
		seed_value, _placed_origins.size(), str(_is_bounded)])


## --- BOUNDED MAP: REGION-GRID DISTRIBUTION ---

func _generate_bounded_map() -> void:
	## Divides the map into a grid of regions and places sources evenly.
	## Inner regions get easy sources, outer regions get harder sources.
	var rng := RandomNumberGenerator.new()
	rng.seed = _world_seed + 12345

	var map_w: int = _map_bounds.size.x
	var map_h: int = _map_bounds.size.y
	var regions_x: int = maxi(3, map_w / REGION_SIZE)
	var regions_y: int = maxi(3, map_h / REGION_SIZE)
	var region_w: float = float(map_w) / regions_x
	var region_h: float = float(map_h) / regions_y

	# Center region (CT location) — skip it, tutorial sources handle center
	var center_rx: int = regions_x / 2
	var center_ry: int = regions_y / 2
	var max_dist: float = maxf(float(center_rx), float(center_ry))

	for rx in range(regions_x):
		for ry in range(regions_y):
			# Skip center region (CT + tutorial sources)
			if rx == center_rx and ry == center_ry:
				continue

			# Chebyshev distance from center region (normalized 0-1)
			var dx: float = absf(float(rx) - float(center_rx))
			var dy: float = absf(float(ry) - float(center_ry))
			var dist_ratio: float = maxf(dx, dy) / max_dist if max_dist > 0 else 0.0

			# Pick pool based on distance from center
			var pool: Array = _get_pool_for_ratio(dist_ratio)
			if pool.is_empty():
				continue

			# 1 source per region, 30% chance of a second
			var count: int = 1
			if rng.randf() < 0.3:
				count = 2

			# Region bounds in cell space
			var reg_x0: int = _map_bounds.position.x + int(rx * region_w)
			var reg_y0: int = _map_bounds.position.y + int(ry * region_h)
			var reg_x1: int = _map_bounds.position.x + int((rx + 1) * region_w)
			var reg_y1: int = _map_bounds.position.y + int((ry + 1) * region_h)

			for _i in range(count):
				var filtered: Array = pool.filter(func(n): return _get_placed_count(n) < MAX_PER_SOURCE_TYPE)
				if filtered.is_empty():
					continue
				var source_name: String = filtered[rng.randi_range(0, filtered.size() - 1)]
				var def := _load_source_def(source_name)
				if def == null:
					continue
				var pos := _find_position_in_region(
					reg_x0, reg_y0, reg_x1, reg_y1,
					def.grid_size, source_name, rng)
				if pos == Vector2i(-1, -1):
					continue
				var sub_seed: int = (_world_seed + rx * 7919 + ry * 3571 + _i * 1013) & 0x7FFFFFFF
				_source_manager.place_source(def, pos, sub_seed)
				_placed_origins.append(pos)
				_track_placed_name(source_name, pos)


func _get_pool_for_ratio(dist_ratio: float) -> Array:
	## Returns source pool based on normalized distance from center (0=center, 1=edge).
	var raw_pool: Array = []
	if dist_ratio <= 0.35:
		raw_pool = _get_allowed("easy")
	elif dist_ratio <= 0.65:
		raw_pool = _get_allowed("easy") + _get_allowed("medium")
	else:
		raw_pool = _get_allowed("medium") + _get_allowed("hard") + _get_allowed("endgame")
	if raw_pool.is_empty():
		for key in _allowed_pools:
			raw_pool += _pools.get(key, [])
	return raw_pool


func _find_position_in_region(x0: int, y0: int, x1: int, y1: int, grid_size: Vector2i, source_name: String, rng: RandomNumberGenerator) -> Vector2i:
	var min_x: int = maxi(x0, _map_bounds.position.x + 1)
	var min_y: int = maxi(y0, _map_bounds.position.y + 1)
	var max_x: int = mini(x1, _map_bounds.end.x - 1) - grid_size.x
	var max_y: int = mini(y1, _map_bounds.end.y - 1) - grid_size.y
	if min_x > max_x or min_y > max_y:
		return Vector2i(-1, -1)

	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var pos := Vector2i(rng.randi_range(min_x, max_x), rng.randi_range(min_y, max_y))
		var ct_dist: int = maxi(absi(pos.x - _map_center.x), absi(pos.y - _map_center.y))
		if ct_dist < CT_EXCLUSION_RADIUS:
			continue
		if _is_too_close(pos):
			continue
		if _is_same_type_too_close(source_name, pos):
			continue
		return pos
	return Vector2i(-1, -1)


## --- INFINITE MAP: CHUNK-BASED ---

func try_generate_visible_chunks(camera_pos: Vector2, viewport_size: Vector2) -> void:
	if _source_manager == null or _is_bounded:
		return
	var half_vp := viewport_size / 2.0
	var vis_min := Vector2i(
		floori((camera_pos.x - half_vp.x) / TILE_SIZE / CHUNK_SIZE) - 1,
		floori((camera_pos.y - half_vp.y) / TILE_SIZE / CHUNK_SIZE) - 1
	)
	var vis_max := Vector2i(
		ceili((camera_pos.x + half_vp.x) / TILE_SIZE / CHUNK_SIZE) + 1,
		ceili((camera_pos.y + half_vp.y) / TILE_SIZE / CHUNK_SIZE) + 1
	)
	var generated_this_call: int = 0
	for cx in range(vis_min.x, vis_max.x + 1):
		for cy in range(vis_min.y, vis_max.y + 1):
			if generated_this_call >= 2:
				return
			var chunk_pos := Vector2i(cx, cy)
			if not _generated_chunks.has(chunk_pos):
				_generate_chunk(chunk_pos)
				generated_this_call += 1


func _generate_chunk(chunk_pos: Vector2i) -> void:
	if _generated_chunks.has(chunk_pos):
		return
	_generated_chunks[chunk_pos] = true
	var dist: int = maxi(absi(chunk_pos.x - _ct_chunk.x), absi(chunk_pos.y - _ct_chunk.y))
	if dist == 0:
		return
	var chunk_rng := RandomNumberGenerator.new()
	chunk_rng.seed = ((_world_seed * 2654435761) ^ (chunk_pos.x * 73856093) ^ (chunk_pos.y * 19349669)) & 0x7FFFFFFF
	var count: int = _roll_count_infinite(dist, chunk_rng)
	if count <= 0:
		return
	var pool: Array = _get_pool_for_distance(dist)
	if pool.is_empty():
		return
	for i in range(count):
		var filtered: Array = pool.filter(func(n): return _get_placed_count(n) < MAX_PER_SOURCE_TYPE)
		if filtered.is_empty():
			continue
		var source_name: String = filtered[chunk_rng.randi_range(0, filtered.size() - 1)]
		var def := _load_source_def(source_name)
		if def == null:
			continue
		var pos := _find_position_in_chunk(chunk_pos, def.grid_size, source_name, chunk_rng)
		if pos == Vector2i(-1, -1):
			continue
		var sub_seed: int = (_world_seed + chunk_pos.x * 7919 + chunk_pos.y * 3571 + i * 1013) & 0x7FFFFFFF
		_source_manager.place_source(def, pos, sub_seed)
		_placed_origins.append(pos)
		_track_placed_name(source_name, pos)


func _get_pool_for_distance(dist: int) -> Array:
	var raw_pool: Array = []
	if dist <= 1:
		raw_pool = _get_allowed("easy")
	elif dist <= 3:
		raw_pool = _get_allowed("easy") + _get_allowed("medium")
	elif dist <= 5:
		raw_pool = _get_allowed("medium") + _get_allowed("hard")
	else:
		raw_pool = _get_allowed("hard") + _get_allowed("endgame")
	if raw_pool.is_empty():
		for key in _allowed_pools:
			raw_pool += _pools.get(key, [])
	return raw_pool


func _roll_count_infinite(dist: int, rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	if dist <= 2:
		if roll < 0.55: return 1
		if roll < 0.80: return 2
		return 0
	elif dist <= 4:
		if roll < 0.50: return 1
		if roll < 0.75: return 2
		return 0
	elif dist <= 7:
		if roll < 0.40: return 1
		if roll < 0.55: return 2
		return 0
	else:
		return 1 if roll < 0.25 else 0


func _find_position_in_chunk(chunk_pos: Vector2i, grid_size: Vector2i, source_name: String, rng: RandomNumberGenerator) -> Vector2i:
	var chunk_origin := chunk_pos * CHUNK_SIZE
	var min_x: int = chunk_origin.x
	var min_y: int = chunk_origin.y
	var max_x: int = chunk_origin.x + CHUNK_SIZE - grid_size.x
	var max_y: int = chunk_origin.y + CHUNK_SIZE - grid_size.y
	if min_x > max_x or min_y > max_y:
		return Vector2i(-1, -1)
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var pos := Vector2i(rng.randi_range(min_x, max_x), rng.randi_range(min_y, max_y))
		var ct_dist: int = maxi(absi(pos.x - _map_center.x), absi(pos.y - _map_center.y))
		if ct_dist < CT_EXCLUSION_RADIUS:
			continue
		if _is_too_close(pos):
			continue
		if _is_same_type_too_close(source_name, pos):
			continue
		return pos
	return Vector2i(-1, -1)


## --- SAVE/LOAD SUPPORT ---

func get_generated_chunk_keys() -> Array:
	var result: Array = []
	for key in _generated_chunks:
		result.append([key.x, key.y])
	return result


func restore_chunks(chunk_keys: Array) -> void:
	for key in chunk_keys:
		if key is Array and key.size() >= 2:
			_generate_chunk(Vector2i(int(key[0]), int(key[1])))


## --- SHARED HELPERS ---

func _place_guaranteed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _world_seed

	for entry in _tutorial_offsets:
		var def := _load_source_def(entry.name)
		if def == null:
			push_warning("[MapGenerator] Tutorial source not found: %s" % entry.name)
			continue
		var pos: Vector2i = _map_center + entry.offset
		if _is_bounded:
			pos.x = clampi(pos.x, _map_bounds.position.x + 1, _map_bounds.end.x - def.grid_size.x - 1)
			pos.y = clampi(pos.y, _map_bounds.position.y + 1, _map_bounds.end.y - def.grid_size.y - 1)
		var sub_seed: int = _world_seed + _placed_origins.size() * 7919
		_source_manager.place_source(def, pos, sub_seed)
		_placed_origins.append(pos)
		_track_placed_name(entry.name, pos)

	for entry in _sector_guarantees:
		var def := _load_source_def(entry.name)
		if def == null:
			continue
		var pos := _find_position_in_sector(entry.angle, entry.r_min, entry.r_max, def.grid_size, rng)
		if pos == Vector2i(-1, -1):
			push_warning("[MapGenerator] Failed sector placement for %s" % entry.name)
			continue
		var sub_seed: int = _world_seed + _placed_origins.size() * 7919
		_source_manager.place_source(def, pos, sub_seed)
		_placed_origins.append(pos)
		_track_placed_name(entry.name, pos)


func _find_position_in_sector(center_angle: float, r_min: float, r_max: float, grid_size: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var angle: float = center_angle + rng.randf_range(-0.4, 0.4)
		var radius: float = rng.randf_range(r_min, r_max)
		var offset := Vector2(cos(angle) * radius, sin(angle) * radius)
		var pos := Vector2i(_map_center.x + int(offset.x), _map_center.y + int(offset.y))
		if _is_bounded:
			if pos.x < _map_bounds.position.x or pos.x + grid_size.x > _map_bounds.end.x:
				continue
			if pos.y < _map_bounds.position.y or pos.y + grid_size.y > _map_bounds.end.y:
				continue
		if not _is_too_close(pos):
			return pos
	return Vector2i(-1, -1)


func _get_allowed(pool_key: String) -> Array:
	if pool_key in _allowed_pools:
		return _pools.get(pool_key, [])
	return []


func _is_too_close(pos: Vector2i) -> bool:
	for existing in _placed_origins:
		if absi(pos.x - existing.x) + absi(pos.y - existing.y) < MIN_SOURCE_DISTANCE:
			return true
	return false


func _is_same_type_too_close(source_name: String, pos: Vector2i) -> bool:
	if not _placed_names.has(source_name):
		return false
	for existing in _placed_names[source_name]:
		if absi(pos.x - existing.x) + absi(pos.y - existing.y) < MIN_SAME_TYPE_DISTANCE:
			return true
	return false


func _get_placed_count(source_name: String) -> int:
	if _placed_names.has(source_name):
		return _placed_names[source_name].size()
	return 0


func _track_placed_name(source_name: String, pos: Vector2i) -> void:
	if not _placed_names.has(source_name):
		_placed_names[source_name] = []
	_placed_names[source_name].append(pos)


func _load_source_def(source_name: String) -> DataSourceDefinition:
	var path: String = "res://resources/sources/%s.tres" % source_name
	if not ResourceLoader.exists(path):
		push_warning("[MapGenerator] Source definition not found: %s" % path)
		return null
	return load(path) as DataSourceDefinition
