extends RefCounted

## Factorio-style random source placement.
## Difficulty comes from source TYPE, not position.
## Spawn guarantees ensure playable start every seed.

const MAP_CENTER := Vector2i(256, 256)
const GRID_MARGIN := 5
const GRID_MAX := 506
const MIN_SOURCE_DISTANCE := 14
const MAX_PLACEMENT_ATTEMPTS := 60
const SPAWN_RADIUS := 35       ## Easy sources guaranteed within this range
const NEAR_RADIUS := 70        ## Medium source guaranteed within this range
const MAP_RADIUS := 220        ## Max placement radius from center

var _pools: Dictionary = {
	"easy": ["isp_backbone", "public_database", "atm", "smart_lock", "traffic_camera"],
	"medium": ["hospital_terminal", "public_library", "shop_server", "biotech_lab"],
	"hard": ["corporate_server", "government_archive"],
	"endgame": ["military_network", "dark_web_node", "blackwall_fragment"],
}

## Target count ranges per difficulty
var _count_ranges: Dictionary = {
	"easy": Vector2i(10, 14),
	"medium": Vector2i(8, 10),
	"hard": Vector2i(5, 7),
	"endgame": Vector2i(2, 4),
}

var _rng := RandomNumberGenerator.new()
var _placed_origins: Array[Vector2i] = []


func generate_map(seed_value: int, source_manager: Node) -> void:
	_rng.seed = seed_value
	_placed_origins.clear()

	# Phase 1: Guaranteed placements (spawn safety)
	_place_guaranteed(seed_value, source_manager)

	# Phase 2: Fill remaining pools randomly
	_place_random_fill(seed_value, source_manager)

	print("[MapGenerator] Generated map — seed: %d, sources: %d" % [seed_value, _placed_origins.size()])


func _place_guaranteed(seed_value: int, source_manager: Node) -> void:
	# 1. ISP Backbone at center (always)
	var center_def := _load_source_def("isp_backbone")
	if center_def:
		source_manager.place_source(center_def, MAP_CENTER, seed_value)
		_placed_origins.append(MAP_CENTER)

	# 2. Second easy source near spawn
	var easy_pool: Array = _pools["easy"].duplicate()
	easy_pool.erase("isp_backbone")  # Already placed
	var second_easy: String = easy_pool[_rng.randi_range(0, easy_pool.size() - 1)]
	_place_near(second_easy, MAP_CENTER, SPAWN_RADIUS, seed_value, source_manager)

	# 3. One medium source within near radius
	var med_pool: Array = _pools["medium"]
	var first_medium: String = med_pool[_rng.randi_range(0, med_pool.size() - 1)]
	_place_near(first_medium, MAP_CENTER, NEAR_RADIUS, seed_value, source_manager)


func _place_random_fill(seed_value: int, source_manager: Node) -> void:
	var source_index: int = _placed_origins.size()

	for difficulty in ["easy", "medium", "hard", "endgame"]:
		var pool: Array = _pools[difficulty]
		var range_vec: Vector2i = _count_ranges[difficulty]
		var target_count: int = _rng.randi_range(range_vec.x, range_vec.y)

		# Count already placed from this pool
		var already_placed: int = _count_placed_from_pool(pool, source_manager)
		var remaining: int = maxi(0, target_count - already_placed)

		for _i in range(remaining):
			var source_name: String = pool[_rng.randi_range(0, pool.size() - 1)]
			var def := _load_source_def(source_name)
			if def == null:
				continue

			var pos: Vector2i = _find_random_position()
			if pos == Vector2i(-1, -1):
				continue

			var sub_seed: int = seed_value + source_index * 7919
			source_manager.place_source(def, pos, sub_seed)
			_placed_origins.append(pos)
			source_index += 1


func _place_near(source_name: String, center: Vector2i, radius: int, seed_value: int, source_manager: Node) -> bool:
	var def := _load_source_def(source_name)
	if def == null:
		return false
	var pos: Vector2i = _find_position_near(center, radius)
	if pos == Vector2i(-1, -1):
		return false
	var sub_seed: int = seed_value + _placed_origins.size() * 7919
	source_manager.place_source(def, pos, sub_seed)
	_placed_origins.append(pos)
	return true


func _find_random_position() -> Vector2i:
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var angle: float = _rng.randf() * TAU
		var radius: float = _rng.randf_range(15.0, float(MAP_RADIUS))
		var offset := Vector2(cos(angle) * radius, sin(angle) * radius)
		var pos := Vector2i(MAP_CENTER.x + int(offset.x), MAP_CENTER.y + int(offset.y))

		if not _is_valid_position(pos):
			continue
		if _is_too_close(pos):
			continue
		return pos

	return Vector2i(-1, -1)


func _find_position_near(center: Vector2i, max_radius: int) -> Vector2i:
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var angle: float = _rng.randf() * TAU
		var radius: float = _rng.randf_range(float(MIN_SOURCE_DISTANCE), float(max_radius))
		var offset := Vector2(cos(angle) * radius, sin(angle) * radius)
		var pos := Vector2i(center.x + int(offset.x), center.y + int(offset.y))

		if not _is_valid_position(pos):
			continue
		if _is_too_close(pos):
			continue
		return pos

	return Vector2i(-1, -1)


func _is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= GRID_MARGIN and pos.x <= GRID_MAX and pos.y >= GRID_MARGIN and pos.y <= GRID_MAX


func _is_too_close(pos: Vector2i) -> bool:
	for existing in _placed_origins:
		var dx: int = abs(pos.x - existing.x)
		var dy: int = abs(pos.y - existing.y)
		if dx + dy < MIN_SOURCE_DISTANCE:
			return true
	return false


func _count_placed_from_pool(pool: Array, _source_manager: Node) -> int:
	# Simple heuristic: count guaranteed placements that used this pool
	# For accuracy we'd track names, but for random fill this approximation works
	return 0  # Let random fill target full count; guaranteed placements are bonus


func _load_source_def(source_name: String) -> DataSourceDefinition:
	var path: String = "res://resources/sources/%s.tres" % source_name
	if not ResourceLoader.exists(path):
		push_warning("[MapGenerator] Source definition not found: %s" % path)
		return null
	return load(path) as DataSourceDefinition
