extends RefCounted

## Shapez-inspired infinite chunk-based source placement.
## Same source type appears multiple times — ATMs everywhere, corp servers rare.
## Sources generate lazily as the camera reveals new chunks.

const CHUNK_SIZE := 32           ## 32x32 cells per chunk
const CT_CENTER := Vector2i(256, 256)
const MIN_SOURCE_DISTANCE := 5
const MAX_PLACEMENT_ATTEMPTS := 40
const CT_EXCLUSION_RADIUS := 5   ## No sources within this of CT center
const TILE_SIZE := 64

var _pools: Dictionary = {
	"easy": ["isp_backbone", "public_database", "atm", "smart_lock", "traffic_camera", "data_kiosk", "bank_terminal"],
	"medium": ["hospital_terminal", "public_library", "shop_server", "biotech_lab"],
	"hard": ["corporate_server", "government_archive"],
	"endgame": ["military_network", "dark_web_node"],
}

## Tutorial-critical sources: fixed coordinates near CT center.
var _tutorial_sources := [
	{"name": "isp_backbone", "pos": Vector2i(262, 250)},    # NE — Gig 1
	{"name": "atm", "pos": Vector2i(263, 256)},              # E  — Gig 2
	{"name": "data_kiosk", "pos": Vector2i(249, 256)},       # W  — Gig 3
	{"name": "bank_terminal", "pos": Vector2i(256, 263)},    # S  — Gig 4
	{"name": "hospital_terminal", "pos": Vector2i(256, 272)},# S  — Gig 5
]

## Sector-based guarantees for non-tutorial sources
var _sector_guarantees := [
	{"name": "biotech_lab", "angle": PI, "r_min": 12.0, "r_max": 25.0},
]

var _world_seed: int = 0
var _source_manager: Node = null
var _placed_origins: Array[Vector2i] = []
var _generated_chunks: Dictionary = {}  ## Vector2i → true
var _ct_chunk: Vector2i


func generate_map(seed_value: int, source_manager: Node) -> void:
	_world_seed = seed_value
	_source_manager = source_manager
	_placed_origins.clear()
	_generated_chunks.clear()
	_ct_chunk = Vector2i(CT_CENTER.x / CHUNK_SIZE, CT_CENTER.y / CHUNK_SIZE)

	# Phase 1: Tutorial-safe fixed-coordinate guarantees
	_place_guaranteed()

	# Phase 2: Generate initial 7x7 chunk area around CT
	for cx in range(_ct_chunk.x - 3, _ct_chunk.x + 4):
		for cy in range(_ct_chunk.y - 3, _ct_chunk.y + 4):
			_generate_chunk(Vector2i(cx, cy))

	print("[MapGenerator] Generated map — seed: %d, sources: %d, chunks: %d" % [
		seed_value, _placed_origins.size(), _generated_chunks.size()])


## Called from main._process() — generates chunks visible to camera + 1 chunk margin.
## Rate-limited: max 2 chunks per call to avoid frame spikes during fast panning.
func try_generate_visible_chunks(camera_pos: Vector2, viewport_size: Vector2) -> void:
	if _source_manager == null:
		return
	var half_vp := viewport_size / 2.0
	var min_chunk := Vector2i(
		floori((camera_pos.x - half_vp.x) / TILE_SIZE / CHUNK_SIZE) - 1,
		floori((camera_pos.y - half_vp.y) / TILE_SIZE / CHUNK_SIZE) - 1
	)
	var max_chunk := Vector2i(
		ceili((camera_pos.x + half_vp.x) / TILE_SIZE / CHUNK_SIZE) + 1,
		ceili((camera_pos.y + half_vp.y) / TILE_SIZE / CHUNK_SIZE) + 1
	)

	var generated_this_call: int = 0
	for cx in range(min_chunk.x, max_chunk.x + 1):
		for cy in range(min_chunk.y, max_chunk.y + 1):
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

	# 1. Tutorial sources at fixed coordinates
	for entry in _tutorial_sources:
		var def := _load_source_def(entry.name)
		if def == null:
			push_warning("[MapGenerator] Tutorial source not found: %s" % entry.name)
			continue
		var pos: Vector2i = entry.pos
		var sub_seed: int = _world_seed + _placed_origins.size() * 7919
		_source_manager.place_source(def, pos, sub_seed)
		_placed_origins.append(pos)

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


func _generate_chunk(chunk_pos: Vector2i) -> void:
	if _generated_chunks.has(chunk_pos):
		return
	_generated_chunks[chunk_pos] = true

	# Chebyshev distance from CT chunk
	var dist: int = maxi(absi(chunk_pos.x - _ct_chunk.x), absi(chunk_pos.y - _ct_chunk.y))

	# Skip only CT's own chunk (tutorial sources handle center)
	if dist == 0:
		return

	# Deterministic RNG per chunk — same seed+chunk = same sources always
	var chunk_rng := RandomNumberGenerator.new()
	chunk_rng.seed = ((_world_seed * 2654435761) ^ (chunk_pos.x * 73856093) ^ (chunk_pos.y * 19349669)) & 0x7FFFFFFF

	# Roll source count for this chunk
	var count: int = _roll_count(dist, chunk_rng)
	if count <= 0:
		return

	# Get difficulty pool for this distance
	var pool: Array = _get_pool_for_distance(dist)

	for i in range(count):
		var source_name: String = pool[chunk_rng.randi_range(0, pool.size() - 1)]
		var def := _load_source_def(source_name)
		if def == null:
			continue

		var pos := _find_position_in_chunk(chunk_pos, def.grid_size, chunk_rng)
		if pos == Vector2i(-1, -1):
			continue

		var sub_seed: int = (_world_seed + chunk_pos.x * 7919 + chunk_pos.y * 3571 + i * 1013) & 0x7FFFFFFF
		_source_manager.place_source(def, pos, sub_seed)
		_placed_origins.append(pos)


func _get_pool_for_distance(dist: int) -> Array:
	if dist <= 4:
		return _pools["easy"]
	elif dist <= 7:
		return _pools["easy"] + _pools["medium"]
	elif dist <= 11:
		return _pools["medium"] + _pools["hard"]
	else:
		return _pools["hard"] + _pools["endgame"]


func _roll_count(dist: int, rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	if dist <= 3:
		# Inner ring: dense — always at least 1 source
		if roll < 0.45: return 2
		if roll < 0.70: return 3
		return 1
	elif dist <= 6:
		# Mid ring: usually has sources
		if roll < 0.50: return 1
		if roll < 0.80: return 2
		return 0
	elif dist <= 10:
		# Outer ring: moderate
		return 1 if roll < 0.35 else 0
	else:
		# Far: sparse — rare corp servers and endgame
		return 1 if roll < 0.15 else 0


func _find_position_in_chunk(chunk_pos: Vector2i, grid_size: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var chunk_origin := chunk_pos * CHUNK_SIZE
	var max_x: int = chunk_origin.x + CHUNK_SIZE - grid_size.x
	var max_y: int = chunk_origin.y + CHUNK_SIZE - grid_size.y

	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var pos := Vector2i(
			rng.randi_range(chunk_origin.x, max_x),
			rng.randi_range(chunk_origin.y, max_y)
		)
		# Don't place too close to CT
		var ct_dist: int = absi(pos.x - CT_CENTER.x) + absi(pos.y - CT_CENTER.y)
		if ct_dist < CT_EXCLUSION_RADIUS:
			continue
		if _is_too_close(pos):
			continue
		return pos

	return Vector2i(-1, -1)


func _find_position_in_sector(center_angle: float, r_min: float, r_max: float, grid_size: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var angle: float = center_angle + rng.randf_range(-0.4, 0.4)
		var radius: float = rng.randf_range(r_min, r_max)
		var offset := Vector2(cos(angle) * radius, sin(angle) * radius)
		var pos := Vector2i(CT_CENTER.x + int(offset.x), CT_CENTER.y + int(offset.y))
		if not _is_too_close(pos):
			return pos
	return Vector2i(-1, -1)


func _is_too_close(pos: Vector2i) -> bool:
	for existing in _placed_origins:
		if absi(pos.x - existing.x) + absi(pos.y - existing.y) < MIN_SOURCE_DISTANCE:
			return true
	return false


func _load_source_def(source_name: String) -> DataSourceDefinition:
	var path: String = "res://resources/sources/%s.tres" % source_name
	if not ResourceLoader.exists(path):
		push_warning("[MapGenerator] Source definition not found: %s" % path)
		return null
	return load(path) as DataSourceDefinition
