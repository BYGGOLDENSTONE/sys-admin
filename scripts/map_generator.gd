extends RefCounted

## Level-aware map generator: bounded or infinite, chunk-based source placement.
## Sources generate within map bounds (levels 1-8) or lazily for infinite (level 9).

const CHUNK_SIZE := 32           ## 32x32 cells per chunk
const MIN_SOURCE_DISTANCE := 8   ## Min distance between ANY two sources (Manhattan)
const MIN_SAME_TYPE_DISTANCE := 18  ## Min distance between same-type sources
const MAX_PLACEMENT_ATTEMPTS := 40
const CT_EXCLUSION_RADIUS := 5   ## No sources within this of CT center (Chebyshev)
const TILE_SIZE := 64

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
]

var _world_seed: int = 0
var _source_manager: Node = null
var _placed_origins: Array[Vector2i] = []
var _placed_names: Dictionary = {}  ## source_name → Array[Vector2i]
var _generated_chunks: Dictionary = {}  ## Vector2i → true
var _ct_chunk: Vector2i

## Level-aware configuration
var _map_center: Vector2i = Vector2i(256, 256)
var _map_bounds: Rect2i = Rect2i()  ## Cell-space bounds
var _is_bounded: bool = false
var _allowed_pools: Array = ["easy", "medium", "hard", "endgame"]
var _is_tutorial_level: bool = true
var _min_chunk: Vector2i = Vector2i()
var _max_chunk: Vector2i = Vector2i()


func configure(level: int) -> void:
	## Configure map generation parameters from level config.
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
		_min_chunk = Vector2i(_map_bounds.position.x / CHUNK_SIZE, _map_bounds.position.y / CHUNK_SIZE)
		_max_chunk = Vector2i(
			ceili(float(_map_bounds.end.x) / CHUNK_SIZE),
			ceili(float(_map_bounds.end.y) / CHUNK_SIZE)
		)


func generate_map(seed_value: int, source_manager: Node) -> void:
	_world_seed = seed_value
	_source_manager = source_manager
	_placed_origins.clear()
	_placed_names.clear()
	_generated_chunks.clear()
	_ct_chunk = Vector2i(_map_center.x / CHUNK_SIZE, _map_center.y / CHUNK_SIZE)

	# Phase 1: Tutorial-safe fixed-coordinate guarantees
	if _is_tutorial_level:
		_place_guaranteed()

	if _is_bounded:
		# Bounded: generate ALL chunks within map bounds at once
		for cx in range(_min_chunk.x, _max_chunk.x + 1):
			for cy in range(_min_chunk.y, _max_chunk.y + 1):
				_generate_chunk(Vector2i(cx, cy))
	else:
		# Infinite: generate initial 7x7 chunk area around CT
		for cx in range(_ct_chunk.x - 3, _ct_chunk.x + 4):
			for cy in range(_ct_chunk.y - 3, _ct_chunk.y + 4):
				_generate_chunk(Vector2i(cx, cy))

	print("[MapGenerator] Generated map — seed: %d, sources: %d, chunks: %d, bounded: %s" % [
		seed_value, _placed_origins.size(), _generated_chunks.size(), str(_is_bounded)])


## Called from main._process() — generates chunks visible to camera + 1 chunk margin.
## Rate-limited: max 2 chunks per call. Skipped for bounded maps (all chunks pre-generated).
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


## --- INTERNAL ---

func _place_guaranteed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _world_seed

	# 1. Tutorial sources at offsets from map center
	for entry in _tutorial_offsets:
		var def := _load_source_def(entry.name)
		if def == null:
			push_warning("[MapGenerator] Tutorial source not found: %s" % entry.name)
			continue
		var pos: Vector2i = _map_center + entry.offset
		# Clamp to bounds if bounded
		if _is_bounded:
			pos.x = clampi(pos.x, _map_bounds.position.x + 1, _map_bounds.end.x - def.grid_size.x - 1)
			pos.y = clampi(pos.y, _map_bounds.position.y + 1, _map_bounds.end.y - def.grid_size.y - 1)
		var sub_seed: int = _world_seed + _placed_origins.size() * 7919
		_source_manager.place_source(def, pos, sub_seed)
		_placed_origins.append(pos)
		_track_placed_name(entry.name, pos)

	# 2. Sector-based guarantees (Biotech Lab etc.)
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


func _generate_chunk(chunk_pos: Vector2i) -> void:
	if _generated_chunks.has(chunk_pos):
		return
	_generated_chunks[chunk_pos] = true

	# Chebyshev distance from CT chunk
	var dist: int = maxi(absi(chunk_pos.x - _ct_chunk.x), absi(chunk_pos.y - _ct_chunk.y))

	# Skip CT's own chunk (tutorial sources handle center)
	if dist == 0:
		return

	# Deterministic RNG per chunk
	var chunk_rng := RandomNumberGenerator.new()
	chunk_rng.seed = ((_world_seed * 2654435761) ^ (chunk_pos.x * 73856093) ^ (chunk_pos.y * 19349669)) & 0x7FFFFFFF

	# Roll source count for this chunk
	var count: int = _roll_count(dist, chunk_rng)
	if count <= 0:
		return

	# Get difficulty pool for this distance (filtered by level's allowed pools)
	var pool: Array = _get_pool_for_distance(dist)
	if pool.is_empty():
		return

	for i in range(count):
		var source_name: String = pool[chunk_rng.randi_range(0, pool.size() - 1)]
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
	## Returns source pool filtered by level's allowed pools.
	var raw_pool: Array = []
	if dist <= 1:
		raw_pool = _get_allowed("easy")
	elif dist <= 3:
		raw_pool = _get_allowed("easy") + _get_allowed("medium")
	elif dist <= 5:
		raw_pool = _get_allowed("medium") + _get_allowed("hard")
	else:
		raw_pool = _get_allowed("hard") + _get_allowed("endgame")
	# Fallback: if filtered pool is empty, use all allowed sources
	if raw_pool.is_empty():
		for key in _allowed_pools:
			raw_pool += _pools.get(key, [])
	return raw_pool


func _get_allowed(pool_key: String) -> Array:
	if pool_key in _allowed_pools:
		return _pools.get(pool_key, [])
	return []


func _roll_count(dist: int, rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	if _is_bounded:
		# Bounded maps: denser spawning (fewer empty chunks)
		if dist <= 1:
			if roll < 0.70: return 1
			if roll < 0.90: return 2
			return 0
		elif dist <= 2:
			if roll < 0.60: return 1
			if roll < 0.85: return 2
			return 0
		else:
			if roll < 0.55: return 1
			if roll < 0.80: return 2
			return 0
	else:
		# Infinite map: original sparse distribution
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
	var max_x: int = chunk_origin.x + CHUNK_SIZE - grid_size.x
	var max_y: int = chunk_origin.y + CHUNK_SIZE - grid_size.y

	# Clamp to map bounds if bounded
	var min_x: int = chunk_origin.x
	var min_y: int = chunk_origin.y
	if _is_bounded:
		min_x = maxi(min_x, _map_bounds.position.x)
		min_y = maxi(min_y, _map_bounds.position.y)
		max_x = mini(max_x, _map_bounds.end.x - grid_size.x)
		max_y = mini(max_y, _map_bounds.end.y - grid_size.y)
	if min_x > max_x or min_y > max_y:
		return Vector2i(-1, -1)

	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var pos := Vector2i(
			rng.randi_range(min_x, max_x),
			rng.randi_range(min_y, max_y)
		)
		# Don't place too close to CT (Chebyshev = square zone)
		var ct_dist: int = maxi(absi(pos.x - _map_center.x), absi(pos.y - _map_center.y))
		if ct_dist < CT_EXCLUSION_RADIUS:
			continue
		if _is_too_close(pos):
			continue
		if _is_same_type_too_close(source_name, pos):
			continue
		return pos

	return Vector2i(-1, -1)


func _find_position_in_sector(center_angle: float, r_min: float, r_max: float, grid_size: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var angle: float = center_angle + rng.randf_range(-0.4, 0.4)
		var radius: float = rng.randf_range(r_min, r_max)
		var offset := Vector2(cos(angle) * radius, sin(angle) * radius)
		var pos := Vector2i(_map_center.x + int(offset.x), _map_center.y + int(offset.y))
		# Check bounds
		if _is_bounded:
			if pos.x < _map_bounds.position.x or pos.x + grid_size.x > _map_bounds.end.x:
				continue
			if pos.y < _map_bounds.position.y or pos.y + grid_size.y > _map_bounds.end.y:
				continue
		if not _is_too_close(pos):
			return pos
	return Vector2i(-1, -1)


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
