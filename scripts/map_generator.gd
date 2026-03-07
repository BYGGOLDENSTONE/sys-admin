extends RefCounted

## Seed-based procedural source placement using ring-based distribution.
## Center = easy sources, outer rings = harder sources.

const MAP_CENTER := Vector2i(256, 256)
const GRID_MARGIN := 5        ## Min distance from grid edges
const GRID_MAX := 506         ## Max valid coordinate (512 - margin)
const MIN_SOURCE_DISTANCE := 14  ## Min cells between source origins
const MAX_PLACEMENT_ATTEMPTS := 40

## Ring definitions: [min_radius, max_radius, min_count, max_count, source_pool]
var _rings: Array = [
	{ "r_min": 0, "r_max": 50, "count_min": 10, "count_max": 14,
	  "sources": ["isp_backbone", "public_database", "atm", "smart_lock", "traffic_camera"] },
	{ "r_min": 50, "r_max": 105, "count_min": 10, "count_max": 14,
	  "sources": ["hospital_terminal", "public_library", "shop_server", "biotech_lab"] },
	{ "r_min": 105, "r_max": 165, "count_min": 8, "count_max": 12,
	  "sources": ["corporate_server", "government_archive"] },
	{ "r_min": 165, "r_max": 230, "count_min": 6, "count_max": 10,
	  "sources": ["military_network", "dark_web_node", "blackwall_fragment"] },
]

var _rng := RandomNumberGenerator.new()
var _placed_origins: Array[Vector2i] = []


func generate_map(seed_value: int, source_manager: Node) -> void:
	_rng.seed = seed_value
	_placed_origins.clear()

	## Always place 1 ISP Backbone at center (guaranteed start)
	var center_def := _load_source_def("isp_backbone")
	if center_def:
		var center_seed: int = seed_value
		source_manager.place_source(center_def, MAP_CENTER, center_seed)
		_placed_origins.append(MAP_CENTER)

	## Place sources ring by ring
	var source_index: int = 1
	for ring in _rings:
		var count: int = _rng.randi_range(ring["count_min"], ring["count_max"])
		var pool: Array = ring["sources"]

		for i in range(count):
			var source_name: String = pool[_rng.randi_range(0, pool.size() - 1)]
			var def := _load_source_def(source_name)
			if def == null:
				continue

			var pos: Vector2i = _find_position_in_ring(ring["r_min"], ring["r_max"])
			if pos == Vector2i(-1, -1):
				continue  ## Could not find valid position, skip

			var sub_seed: int = seed_value + source_index * 7919
			source_manager.place_source(def, pos, sub_seed)
			_placed_origins.append(pos)
			source_index += 1

	print("[MapGenerator] Generated map — seed: %d, sources: %d" % [seed_value, _placed_origins.size()])


func _find_position_in_ring(r_min: int, r_max: int) -> Vector2i:
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		## Random angle and radius within ring
		var angle: float = _rng.randf() * TAU
		var radius: float = _rng.randf_range(float(r_min), float(r_max))
		var offset := Vector2(cos(angle) * radius, sin(angle) * radius)
		var pos := Vector2i(MAP_CENTER.x + int(offset.x), MAP_CENTER.y + int(offset.y))

		## Check grid bounds
		if pos.x < GRID_MARGIN or pos.x > GRID_MAX or pos.y < GRID_MARGIN or pos.y > GRID_MAX:
			continue

		## Check minimum distance from all placed sources
		if _is_too_close(pos):
			continue

		return pos

	return Vector2i(-1, -1)  ## Failed after max attempts


func _is_too_close(pos: Vector2i) -> bool:
	for existing in _placed_origins:
		var dx: int = abs(pos.x - existing.x)
		var dy: int = abs(pos.y - existing.y)
		if dx + dy < MIN_SOURCE_DISTANCE:
			return true
	return false


func _load_source_def(source_name: String) -> DataSourceDefinition:
	var path: String = "res://resources/sources/%s.tres" % source_name
	if not ResourceLoader.exists(path):
		push_warning("[MapGenerator] Source definition not found: %s" % path)
		return null
	return load(path) as DataSourceDefinition
