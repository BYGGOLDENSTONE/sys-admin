extends RefCounted

## Factorio-style random source placement with tutorial-safe guarantees.
## Tutorial-critical sources are placed in fixed sectors from center,
## ensuring every gig 1-7 has the resources it needs within reach.
## Difficulty comes from source TYPE, not position.

const MAP_CENTER := Vector2i(256, 256)
const GRID_MARGIN := 5
const GRID_MAX := 506
const MIN_SOURCE_DISTANCE := 14
const MAX_PLACEMENT_ATTEMPTS := 60
const NEAR_RADIUS := 70        ## Medium source guaranteed within this range
const MAP_RADIUS := 220        ## Max placement radius from center
const SECTOR_VARIANCE := 0.4   ## ±radians (~23°) angle spread per sector
const CT_EXCLUSION_RADIUS := 12 ## No sources within this distance of center (CT 3x3 + 10 cell buffer)

var _pools: Dictionary = {
	"easy": ["isp_backbone", "public_database", "atm", "smart_lock", "traffic_camera"],
	"medium": ["hospital_terminal", "public_library", "shop_server", "biotech_lab"],
	"hard": ["corporate_server", "government_archive"],
	"endgame": ["military_network", "dark_web_node"],
}

## Target count ranges per difficulty (demo-tuned: 12-18 sources total)
var _count_ranges: Dictionary = {
	"easy": Vector2i(5, 8),
	"medium": Vector2i(3, 5),
	"hard": Vector2i(2, 3),
	"endgame": Vector2i(1, 2),
}

## Tutorial-critical sources: sector-based placement + force discovered.
## Each gets a fixed direction from center with seed-based variance.
var _tutorial_guarantees := [
	# North: Public Database (Standard/Biometric/Research) — Gig 2-4
	{"name": "public_database", "angle": PI * 1.5, "r_min": 18.0, "r_max": 30.0},
	# East: ATM (Financial) — Gig 2-3
	{"name": "atm", "angle": 0.0, "r_min": 18.0, "r_max": 30.0},
	# South: Hospital Terminal (Biometric/Research, Encrypted) — Gig 5-6
	{"name": "hospital_terminal", "angle": PI * 0.5, "r_min": 30.0, "r_max": 50.0},
	# West: Biotech Lab (Blueprint/Research/Biometric) — Gig 7
	{"name": "biotech_lab", "angle": PI, "r_min": 30.0, "r_max": 50.0},
]

var _rng := RandomNumberGenerator.new()
var _placed_origins: Array[Vector2i] = []
var _placed_names: Array[String] = []

## Positions of tutorial-guaranteed sources (for fog reveal by main.gd)
var guaranteed_origins: Array[Vector2i] = []


func generate_map(seed_value: int, source_manager: Node) -> void:
	_rng.seed = seed_value
	_placed_origins.clear()
	_placed_names.clear()
	guaranteed_origins.clear()

	# Phase 1: Tutorial-safe sector-based guarantees
	_place_guaranteed(seed_value, source_manager)

	# Phase 2: Fill remaining pools randomly
	_place_random_fill(seed_value, source_manager)

	# Phase 3: Reveal hard/endgame sources near spawn ("see but can't process" hook)
	source_manager.reveal_hard_sources_near_spawn(MAP_CENTER, NEAR_RADIUS)

	print("[MapGenerator] Generated map — seed: %d, sources: %d, guaranteed: %d" % [
		seed_value, _placed_origins.size(), guaranteed_origins.size()])


func _place_guaranteed(seed_value: int, source_manager: Node) -> void:
	# 1. ISP Backbone near center but outside CT exclusion zone — Gig 1 safe start
	var center_def := _load_source_def("isp_backbone")
	if center_def:
		var isp_pos := _find_position_in_sector(PI * 0.25, float(CT_EXCLUSION_RADIUS), float(CT_EXCLUSION_RADIUS) + 6.0)
		if isp_pos == Vector2i(-1, -1):
			isp_pos = Vector2i(MAP_CENTER.x + CT_EXCLUSION_RADIUS + 2, MAP_CENTER.y - CT_EXCLUSION_RADIUS - 2)
		source_manager.place_source(center_def, isp_pos, seed_value, true)
		_placed_origins.append(isp_pos)
		_placed_names.append("isp_backbone")
		guaranteed_origins.append(isp_pos)

	# 2. Tutorial sources in fixed sectors (all discovered from start)
	for entry in _tutorial_guarantees:
		var pos := _find_position_in_sector(entry.angle, entry.r_min, entry.r_max)
		if pos == Vector2i(-1, -1):
			push_warning("[MapGenerator] Failed sector placement for %s" % entry.name)
			continue
		var def := _load_source_def(entry.name)
		if def == null:
			continue
		var sub_seed: int = seed_value + _placed_origins.size() * 7919
		source_manager.place_source(def, pos, sub_seed, true)
		_placed_origins.append(pos)
		_placed_names.append(entry.name)
		guaranteed_origins.append(pos)


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
			_placed_names.append(source_name)
			source_index += 1


func _find_position_in_sector(center_angle: float, r_min: float, r_max: float) -> Vector2i:
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var angle: float = center_angle + _rng.randf_range(-SECTOR_VARIANCE, SECTOR_VARIANCE)
		var radius: float = _rng.randf_range(r_min, r_max)
		var offset := Vector2(cos(angle) * radius, sin(angle) * radius)
		var pos := Vector2i(MAP_CENTER.x + int(offset.x), MAP_CENTER.y + int(offset.y))
		if _is_valid_position(pos) and not _is_too_close(pos):
			return pos
	return Vector2i(-1, -1)


func _find_random_position() -> Vector2i:
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		var angle: float = _rng.randf() * TAU
		var radius: float = _rng.randf_range(float(CT_EXCLUSION_RADIUS), float(MAP_RADIUS))
		var offset := Vector2(cos(angle) * radius, sin(angle) * radius)
		var pos := Vector2i(MAP_CENTER.x + int(offset.x), MAP_CENTER.y + int(offset.y))

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
	var count: int = 0
	for placed_name in _placed_names:
		if placed_name in pool:
			count += 1
	return count


func _load_source_def(source_name: String) -> DataSourceDefinition:
	var path: String = "res://resources/sources/%s.tres" % source_name
	if not ResourceLoader.exists(path):
		push_warning("[MapGenerator] Source definition not found: %s" % path)
		return null
	return load(path) as DataSourceDefinition
