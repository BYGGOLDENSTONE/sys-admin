extends RefCounted

## Level-aware map generator.
## Bounded maps (levels 1-8): region-grid based, even distribution.
## Infinite maps (level 9): lazy chunk-based generation.

const CHUNK_SIZE := 32           ## 32x32 cells per chunk
const MIN_SOURCE_DISTANCE := 10  ## Min distance between ANY two sources (Manhattan)
const MIN_SAME_TYPE_DISTANCE := 24  ## Min distance between same-type sources
const MAX_PLACEMENT_ATTEMPTS := 80
const CT_EXCLUSION_RADIUS := 5   ## No sources within this of CT center (Chebyshev) — ~10x10 zone
const HARD_MIN_CT_DIST := 15     ## Hard sources must be at least this far from CT (Chebyshev)
const TILE_SIZE := 64
const REGION_SIZE := 20          ## Region grid cell size for bounded maps
const MAX_PER_SOURCE_TYPE := 15  ## Max total placements per source type (includes guarantees)

var _pools: Dictionary = {
	"easy": ["isp_backbone", "public_database", "atm", "smart_lock", "traffic_camera", "data_kiosk", "bank_terminal"],
	"medium": ["hospital_terminal", "public_library", "shop_server", "biotech_lab"],
	"hard": ["corporate_server", "government_archive"],
	"endgame": ["military_network", "dark_web_node"],
}

## Tutorial source list — placed via scatter (random positions, no fixed offsets).
## Order matters: placed first = gets best positions. Hard sources last for CT distance.
var _tutorial_sources := [
	# Easy sources (anywhere outside CT exclusion zone)
	{"name": "isp_backbone", "hard": false},
	{"name": "atm", "hard": false},
	{"name": "data_kiosk", "hard": false},
	{"name": "public_database", "hard": false},
	{"name": "smart_lock", "hard": false},
	{"name": "bank_terminal", "hard": false},
	# Medium sources
	{"name": "hospital_terminal", "hard": false},
	{"name": "biotech_lab", "hard": false},
	{"name": "shop_server", "hard": false},
	{"name": "public_library", "hard": false},
	# Hard sources — must be far from CT (HARD_MIN_CT_DIST)
	{"name": "corporate_server", "hard": true},
	{"name": "government_archive", "hard": true},
	{"name": "corporate_server", "hard": true},
	{"name": "government_archive", "hard": true},
]

## FIRE feeder mapping: source with FIRE → Easy source that produces required sub-type.
## Ensures FIRE requirements are always achievable by placing a feeder nearby.
var _fire_feeders := {
	"hospital_terminal": "smart_lock",        # FIRE: Fingerprint (Biometric)
	"public_library": "public_database",      # FIRE: Test Data (Research)
	"shop_server": "atm",                     # FIRE: Transaction Records (Financial)
	"biotech_lab": "isp_backbone",            # FIRE: Log Files (Standard)
	"corporate_server": "bank_terminal",      # FIRE: Credit History (Financial)
	"government_archive": "data_kiosk",       # FIRE: Schematics (Blueprint)
}

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
		# Tutorial maps use only guaranteed placements — no region fill
	elif _is_bounded:
		_generate_bounded_map()
	else:
		for cx in range(_ct_chunk.x - 3, _ct_chunk.x + 4):
			for cy in range(_ct_chunk.y - 3, _ct_chunk.y + 4):
				_generate_chunk(Vector2i(cx, cy))

	print("[MapGenerator] Generated map — seed: %d, sources: %d, bounded: %s" % [
		seed_value, _placed_origins.size(), str(_is_bounded)])


## --- BOUNDED MAP: REGION-GRID DISTRIBUTION ---

func _generate_bounded_map() -> void:
	## Divides the map into a grid of regions and places 1 source per region.
	## Regions are shuffled before processing to prevent left-to-right pool exhaustion bias.
	var rng := RandomNumberGenerator.new()
	rng.seed = _world_seed + 12345

	var map_w: int = _map_bounds.size.x
	var map_h: int = _map_bounds.size.y
	var regions_x: int = maxi(3, map_w / REGION_SIZE)
	var regions_y: int = maxi(3, map_h / REGION_SIZE)
	var region_w: float = float(map_w) / regions_x
	var region_h: float = float(map_h) / regions_y
	var center_rx: int = regions_x / 2
	var center_ry: int = regions_y / 2
	var max_dist: float = maxf(float(center_rx), float(center_ry))

	# Build region list then Fisher-Yates shuffle (seeded, deterministic)
	var region_list: Array[Vector2i] = []
	for rx in range(regions_x):
		for ry in range(regions_y):
			if rx == center_rx and ry == center_ry:
				continue
			region_list.append(Vector2i(rx, ry))
	for i in range(region_list.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = region_list[i]
		region_list[i] = region_list[j]
		region_list[j] = tmp

	for region in region_list:
		var rx: int = region.x
		var ry: int = region.y
		var dx: float = absf(float(rx) - float(center_rx))
		var dy: float = absf(float(ry) - float(center_ry))
		var dist_ratio: float = maxf(dx, dy) / max_dist if max_dist > 0 else 0.0

		var pool: Array = _get_pool_for_ratio(dist_ratio)

		# Region center in cell space
		var reg_cx: int = _map_bounds.position.x + int((float(rx) + 0.5) * region_w)
		var reg_cy: int = _map_bounds.position.y + int((float(ry) + 0.5) * region_h)

		var filtered: Array = pool.filter(func(n): return _get_placed_count(n) < MAX_PER_SOURCE_TYPE)
		if filtered.is_empty():
			## Primary pool exhausted — fall back to any allowed type with remaining capacity
			var fallback: Array = []
			for key in _allowed_pools:
				fallback += _pools.get(key, [])
			filtered = fallback.filter(func(n): return _get_placed_count(n) < MAX_PER_SOURCE_TYPE)
		if filtered.is_empty():
			continue

		var source_name: String = filtered[rng.randi_range(0, filtered.size() - 1)]
		var def := _load_source_def(source_name)
		if def == null:
			continue
		var pos := _find_position_near_center(reg_cx, reg_cy, def.grid_size, source_name, rng)
		if pos == Vector2i(-1, -1):
			continue
		var sub_seed: int = (_world_seed + rx * 7919 + ry * 3571) & 0x7FFFFFFF
		_source_manager.place_source(def, pos, sub_seed)
		_placed_origins.append(pos)
		_track_placed_name(source_name, pos)
		_place_fire_feeder(source_name, pos, rng)


func _get_pool_for_ratio(dist_ratio: float) -> Array:
	## Returns source pool based on normalized distance from center (0=center, 1=edge).
	## Inner zone (≤0.30): easy only — close to CT, learner-friendly
	## Mid zone (0.30-0.55): easy + medium — FIRE introduction range
	## Outer zone (>0.55): medium + hard — far from CT, high threat
	var raw_pool: Array = []
	if dist_ratio <= 0.30:
		raw_pool = _get_allowed("easy")
	elif dist_ratio <= 0.55:
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


func _find_position_near_center(cx: int, cy: int, grid_size: Vector2i, source_name: String, rng: RandomNumberGenerator) -> Vector2i:
	## Try positions expanding outward from region center.
	## Early attempts are close to center; later attempts spread further.
	## This ensures near-uniform spacing equal to REGION_SIZE.
	var max_jitter: int = REGION_SIZE / 2
	for attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var jitter: int = mini(2 + attempt / 4, max_jitter)
		var ox: int = rng.randi_range(-jitter, jitter)
		var oy: int = rng.randi_range(-jitter, jitter)
		var pos := Vector2i(cx + ox - grid_size.x / 2, cy + oy - grid_size.y / 2)
		if _is_bounded:
			pos.x = clampi(pos.x, _map_bounds.position.x + 1, _map_bounds.end.x - grid_size.x - 1)
			pos.y = clampi(pos.y, _map_bounds.position.y + 1, _map_bounds.end.y - grid_size.y - 1)
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
		# Place FIRE feeder nearby for FIRE sources
		_place_fire_feeder(source_name, pos, chunk_rng)


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
	## Scatter placement: each source gets a random valid position across the map.
	## Hard sources are pushed away from CT (HARD_MIN_CT_DIST).
	## Non-hard sources can go anywhere outside CT exclusion zone.
	var rng := RandomNumberGenerator.new()
	rng.seed = _world_seed

	for entry in _tutorial_sources:
		var def := _load_source_def(entry.name)
		if def == null:
			push_warning("[MapGenerator] Tutorial source not found: %s" % entry.name)
			continue
		var min_ct: int = HARD_MIN_CT_DIST if entry.hard else CT_EXCLUSION_RADIUS
		var pos := _find_scattered_position(def.grid_size, entry.name, min_ct, rng)
		if pos == Vector2i(-1, -1):
			push_warning("[MapGenerator] Failed scatter placement for %s" % entry.name)
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


func _find_scattered_position(grid_size: Vector2i, source_name: String, min_ct_dist: int, rng: RandomNumberGenerator) -> Vector2i:
	## Random position anywhere on the map outside the CT exclusion zone.
	## min_ct_dist: minimum Chebyshev distance from map center (CT).
	if not _is_bounded:
		return Vector2i(-1, -1)
	var margin: int = 2
	var min_x: int = _map_bounds.position.x + margin
	var min_y: int = _map_bounds.position.y + margin
	var max_x: int = _map_bounds.end.x - grid_size.x - margin
	var max_y: int = _map_bounds.end.y - grid_size.y - margin
	if min_x > max_x or min_y > max_y:
		return Vector2i(-1, -1)
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var pos := Vector2i(rng.randi_range(min_x, max_x), rng.randi_range(min_y, max_y))
		var ct_dist: int = maxi(absi(pos.x - _map_center.x), absi(pos.y - _map_center.y))
		if ct_dist < min_ct_dist:
			continue
		if _is_too_close(pos):
			continue
		if _is_same_type_too_close(source_name, pos):
			continue
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


## --- FIRE FEEDER PAIRING ---

func _place_fire_feeder(source_name: String, source_pos: Vector2i, rng: RandomNumberGenerator) -> void:
	if not _fire_feeders.has(source_name):
		return
	var feeder_name: String = _fire_feeders[source_name]
	if _get_placed_count(feeder_name) >= MAX_PER_SOURCE_TYPE:
		return
	var feeder_def := _load_source_def(feeder_name)
	if feeder_def == null:
		return
	var feeder_pos := _find_position_near(source_pos, feeder_def.grid_size, feeder_name, rng, 8, 15)
	if feeder_pos == Vector2i(-1, -1):
		push_warning("[MapGenerator] Failed to place FIRE feeder %s near %s" % [feeder_name, source_name])
		return
	var feeder_seed: int = (_world_seed + source_pos.x * 3571 + source_pos.y * 7919) & 0x7FFFFFFF
	_source_manager.place_source(feeder_def, feeder_pos, feeder_seed)
	_placed_origins.append(feeder_pos)
	_track_placed_name(feeder_name, feeder_pos)


func _find_position_near(center: Vector2i, grid_size: Vector2i, source_name: String, rng: RandomNumberGenerator, min_dist: int, max_dist: int) -> Vector2i:
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var offset_x: int = rng.randi_range(-max_dist, max_dist)
		var offset_y: int = rng.randi_range(-max_dist, max_dist)
		var manhattan: int = absi(offset_x) + absi(offset_y)
		if manhattan < min_dist or manhattan > max_dist * 2:
			continue
		var pos := Vector2i(center.x + offset_x, center.y + offset_y)
		if _is_bounded:
			if pos.x < _map_bounds.position.x or pos.x + grid_size.x > _map_bounds.end.x:
				continue
			if pos.y < _map_bounds.position.y or pos.y + grid_size.y > _map_bounds.end.y:
				continue
		var ct_dist: int = maxi(absi(pos.x - _map_center.x), absi(pos.y - _map_center.y))
		if ct_dist < CT_EXCLUSION_RADIUS:
			continue
		if _is_too_close(pos):
			continue
		if _is_same_type_too_close(source_name, pos):
			continue
		return pos
	return Vector2i(-1, -1)
