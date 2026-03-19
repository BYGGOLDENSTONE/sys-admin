extends Node

## Upgrade Manager — CT deliveries power 4 upgrade categories.
## No separate currency; delivering data to CT naturally upgrades your infrastructure.

signal tier_changed(category: String, new_tier: int)

## 4 upgrade categories
const CATEGORIES: Array[String] = ["routing", "decryption", "recovery", "bandwidth"]

## Tier table: cumulative MB required and multiplier per tier
## Tier 1 = base (no cost). Tier 2+ require cumulative data delivery.
const TIER_TABLE: Array[Dictionary] = [
	{"tier": 1, "cost": 0, "multiplier": 1.0},
	{"tier": 2, "cost": 100, "multiplier": 3.0},
	{"tier": 3, "cost": 500, "multiplier": 10.0},
	{"tier": 4, "cost": 2000, "multiplier": 30.0},
	{"tier": 5, "cost": 10000, "multiplier": 100.0},
	{"tier": 6, "cost": 50000, "multiplier": 300.0},
	{"tier": 7, "cost": 250000, "multiplier": 1000.0},
	{"tier": 8, "cost": 1000000, "multiplier": 3000.0},
]

## Success rate bonus per tier (additive to base rate, capped at 0.98)
const SUCCESS_BONUS_TABLE: Array[float] = [
	0.0,   # Tier 1
	0.03,  # Tier 2
	0.06,  # Tier 3
	0.10,  # Tier 4
	0.15,  # Tier 5
	0.20,  # Tier 6
	0.28,  # Tier 7
	0.38,  # Tier 8
]

## Per-category state: {cumulative_data: float, tier: int}
var _state: Dictionary = {}


func _ready() -> void:
	_reset_state()


func _reset_state() -> void:
	_state.clear()
	for cat in CATEGORIES:
		_state[cat] = {"cumulative_data": 0.0, "tier": 1}


## --- PUBLIC API ---

func add_data(content: int, state: int, tags: int, amount: int) -> void:
	## Called when data is delivered to CT. Routes to appropriate category.
	## Public → Routing. Decrypted/Encrypted tag → Decryption. Recovered → Recovery. ALL → Bandwidth.
	var amt: float = float(amount)

	# Bandwidth: ALL deliveries count
	_add_to_category("bandwidth", amt)

	# Routing: Public state data
	if state == DataEnums.DataState.PUBLIC:
		_add_to_category("routing", amt)

	# Decryption: data with DECRYPTED or ENCRYPTED tag
	if tags & 1 or tags & 4:  # DECRYPTED=1, ENCRYPTED=4
		_add_to_category("decryption", amt)

	# Recovery: data with RECOVERED tag
	if tags & 2:  # RECOVERED=2
		_add_to_category("recovery", amt)


func get_multiplier(category: String) -> float:
	## Returns speed/bandwidth multiplier for given category.
	if not _state.has(category):
		return 1.0
	var tier: int = _state[category].tier
	if tier <= 0 or tier > TIER_TABLE.size():
		return 1.0
	return TIER_TABLE[tier - 1].multiplier


func get_success_bonus(category: String) -> float:
	## Returns additive success rate bonus for given category.
	if not _state.has(category):
		return 0.0
	var tier: int = _state[category].tier
	if tier <= 0 or tier > SUCCESS_BONUS_TABLE.size():
		return 0.0
	return SUCCESS_BONUS_TABLE[tier - 1]


func get_tier(category: String) -> int:
	if not _state.has(category):
		return 1
	return _state[category].tier


func get_cumulative(category: String) -> float:
	if not _state.has(category):
		return 0.0
	return _state[category].cumulative_data


func get_next_tier_cost(category: String) -> float:
	## Returns cumulative cost for next tier, or -1 if at max.
	var tier: int = get_tier(category)
	if tier >= TIER_TABLE.size():
		return -1.0
	return float(TIER_TABLE[tier].cost)


## --- INTERNAL ---

func _add_to_category(category: String, amount: float) -> void:
	if not _state.has(category):
		return
	_state[category].cumulative_data += amount
	_check_tier_up(category)


func _check_tier_up(category: String) -> void:
	var current_tier: int = _state[category].tier
	if current_tier >= TIER_TABLE.size():
		return
	var next_cost: float = float(TIER_TABLE[current_tier].cost)
	if _state[category].cumulative_data >= next_cost:
		_state[category].tier = current_tier + 1
		print("[Upgrade] %s → Tier %d (%.1fx)" % [category, current_tier + 1, get_multiplier(category)])
		tier_changed.emit(category, current_tier + 1)
		# Check for double tier-up (if massive delivery)
		_check_tier_up(category)


## --- SAVE/LOAD ---

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	for cat in CATEGORIES:
		data[cat] = {
			"cumulative_data": _state[cat].cumulative_data,
			"tier": _state[cat].tier,
		}
	return data


func load_save_data(data: Dictionary) -> void:
	for cat in CATEGORIES:
		if data.has(cat):
			_state[cat].cumulative_data = float(data[cat].get("cumulative_data", 0.0))
			_state[cat].tier = int(data[cat].get("tier", 1))
