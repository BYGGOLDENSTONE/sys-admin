extends Node

## Upgrade Manager — CT deliveries power 4 upgrade categories.
## No separate currency; delivering data to CT naturally upgrades your infrastructure.

signal tier_changed(category: String, new_tier: int)
signal tier_claimable(category: String, tier: int)

## 4 upgrade categories
const CATEGORIES: Array[String] = ["routing", "decryption", "recovery", "bandwidth"]

## Tier table: cumulative MB required and multiplier per tier.
## Balanced for demo playtime (~1-2 hours to reach Tier 5).
## Tier 1 = base (no cost). Tier 2+ require cumulative data delivery.
const TIER_TABLE: Array[Dictionary] = [
	{"tier": 1, "cost": 0, "multiplier": 1.0},
	{"tier": 2, "cost": 40, "multiplier": 2.0},
	{"tier": 3, "cost": 150, "multiplier": 5.0},
	{"tier": 4, "cost": 500, "multiplier": 12.0},
	{"tier": 5, "cost": 1500, "multiplier": 30.0},
	{"tier": 6, "cost": 5000, "multiplier": 80.0},
	{"tier": 7, "cost": 18000, "multiplier": 200.0},
	{"tier": 8, "cost": 60000, "multiplier": 500.0},
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

## Content → Category mapping
## Only PROCESSED data counts (must have DECRYPTED or RECOVERED tag).
## Public data = 0 upgrade value.
const CONTENT_CATEGORY: Dictionary = {
	0: "routing",     # Standard → Routing
	1: "routing",     # Financial → Routing
	2: "recovery",    # Biometric → Recovery
	3: "decryption",  # Blueprint → Decryption
	4: "recovery",    # Research → Recovery
	5: "decryption",  # Classified → Decryption
}
const BANDWIDTH_RATIO: float = 0.25  ## All processed data → 25% Bandwidth


func add_data(content: int, _state: int, tags: int, amount: int) -> void:
	## Called when data is delivered to CT. Only processed data counts.
	## Content type determines primary category. Bandwidth gets 25% of all processed.
	var is_processed: bool = (tags & 1) or (tags & 2) or (tags & 4)  # DECRYPTED | RECOVERED | ENCRYPTED
	if not is_processed:
		return  # Public unprocessed data = no upgrade value
	var amt: float = float(amount)

	# Primary category based on content type
	var cat: String = CONTENT_CATEGORY.get(content, "")
	if cat != "":
		_add_to_category(cat, amt)

	# Bandwidth: 25% of all processed deliveries
	_add_to_category("bandwidth", amt * BANDWIDTH_RATIO)


func get_multiplier(category: String) -> float:
	## Returns speed/bandwidth multiplier for given category.
	if not _state.has(category):
		return 1.0
	var tier: int = _state[category].tier
	if tier <= 0 or tier > TIER_TABLE.size():
		return 1.0
	return TIER_TABLE[tier - 1].multiplier


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

func is_claimable(category: String) -> bool:
	## Returns true if enough data accumulated for next tier but not yet claimed.
	if not _state.has(category):
		return false
	var tier: int = _state[category].tier
	if tier >= TIER_TABLE.size():
		return false
	var next_cost: float = float(TIER_TABLE[tier].cost)
	return _state[category].cumulative_data >= next_cost


func claim_tier_up(category: String) -> bool:
	## Player clicks to claim tier-up. Returns true if successful.
	if not is_claimable(category):
		return false
	_state[category].tier += 1
	var new_tier: int = _state[category].tier
	print("[Upgrade] %s → Tier %d (%.1fx) — claimed" % [category, new_tier, get_multiplier(category)])
	tier_changed.emit(category, new_tier)
	return true


func _add_to_category(category: String, amount: float) -> void:
	if not _state.has(category):
		return
	var was_claimable: bool = is_claimable(category)
	_state[category].cumulative_data += amount
	# Notify when tier becomes claimable (only fires once per tier)
	if not was_claimable and is_claimable(category):
		var next_tier: int = _state[category].tier + 1
		tier_claimable.emit(category, next_tier)


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
