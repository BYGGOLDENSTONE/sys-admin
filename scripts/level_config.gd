class_name LevelConfig
extends RefCounted

## Static level configuration for NetFactory // BREACH progression system.
## 9 levels: CT grows from 2x2 to 10x10, map from 100x100 to infinite.

const IS_DEMO: bool = true  ## Demo build flag
const DEMO_MAX_LEVEL: int = 2  ## Highest playable level in demo

const LEVELS: Array[Dictionary] = [
	{  # Level 1
		"ct_size": Vector2i(2, 2),
		"map_size": 50,
		"source_pools": ["easy", "medium", "hard"],
		"is_tutorial": true,
		"is_infinite": false,
	},
	{  # Level 2
		"ct_size": Vector2i(3, 3),
		"map_size": 200,
		"source_pools": ["easy", "medium", "hard"],
		"is_tutorial": false,
		"is_infinite": false,
	},
	{  # Level 3
		"ct_size": Vector2i(4, 4),
		"map_size": 300,
		"source_pools": ["easy", "medium", "hard"],
		"is_tutorial": false,
		"is_infinite": false,
	},
	{  # Level 4
		"ct_size": Vector2i(5, 5),
		"map_size": 400,
		"source_pools": ["easy", "medium", "hard", "endgame"],
		"is_tutorial": false,
		"is_infinite": false,
	},
	{  # Level 5
		"ct_size": Vector2i(6, 6),
		"map_size": 500,
		"source_pools": ["easy", "medium", "hard", "endgame"],
		"is_tutorial": false,
		"is_infinite": false,
	},
	{  # Level 6
		"ct_size": Vector2i(7, 7),
		"map_size": 600,
		"source_pools": ["easy", "medium", "hard", "endgame"],
		"is_tutorial": false,
		"is_infinite": false,
	},
	{  # Level 7
		"ct_size": Vector2i(8, 8),
		"map_size": 700,
		"source_pools": ["easy", "medium", "hard", "endgame"],
		"is_tutorial": false,
		"is_infinite": false,
	},
	{  # Level 8
		"ct_size": Vector2i(9, 9),
		"map_size": 800,
		"source_pools": ["easy", "medium", "hard", "endgame"],
		"is_tutorial": false,
		"is_infinite": false,
	},
	{  # Level 9 — Endless
		"ct_size": Vector2i(10, 10),
		"map_size": 0,
		"source_pools": ["easy", "medium", "hard", "endgame"],
		"is_tutorial": false,
		"is_infinite": true,
	},
]

const MAX_LEVEL: int = 9

## Brief descriptions shown in level-select UI
const LEVEL_DESCS: Array[String] = [
	"Tutorial — learn the basics",        # 1
	"Freeplay — all buildings unlocked",   # 2
	"Expanding networks",                  # 3
	"Endgame sources appear",              # 4
	"Large-scale routing",                 # 5
	"Deep encryption chains",              # 6
	"Mass parallel processing",            # 7
	"Full network complexity",             # 8
	"Endless — infinite map",              # 9
]


static func get_level(idx: int) -> Dictionary:
	## Returns level data (1-based index). Clamps to valid range.
	var i: int = clampi(idx, 1, MAX_LEVEL) - 1
	return LEVELS[i]


static func get_ct_input_ports(level: int) -> Array[String]:
	## Generates input port names for CT at given level.
	## Formula: ports_per_side = ct_size - 1, total = 4 * (ct_size - 1)
	var data: Dictionary = get_level(level)
	var ct_size: int = data.ct_size.x
	var ports_per_side: int = ct_size - 1
	var result: Array[String] = []
	for side in ["left", "right", "top", "bottom"]:
		for i in range(ports_per_side):
			result.append("%s_%d" % [side, i])
	return result


static func get_map_center(level: int) -> Vector2i:
	## Returns the grid-cell center of the map for the given level.
	var data: Dictionary = get_level(level)
	if data.is_infinite:
		return Vector2i(256, 256)  # Legacy infinite center
	var half: int = data.map_size / 2
	return Vector2i(half, half)


static func get_map_center_world(level: int) -> Vector2:
	## Returns the pixel-space center of the map.
	var center: Vector2i = get_map_center(level)
	return Vector2(center.x * 64.0 + 32.0, center.y * 64.0 + 32.0)
