extends Node

signal gig_activated(gig: Resource)
signal gig_progress_updated(gig: Resource, req_index: int, current: int, target: int)
signal gig_completed(gig: Resource)
signal building_unlocked(building_name: String)

var _all_gigs: Array = []
var _active_gigs: Array = []
var _completed_indices: Dictionary = {}  ## order_index → true
var _progress: Dictionary = {}  ## order_index → Array[int] (per-requirement count)
var _unlocked_buildings: Dictionary = {}  ## building_name → true

## Procedural gig state
var _tutorials_complete: bool = false
var _procedural_count: int = 0  ## How many procedural gigs completed (drives difficulty)
var _next_order_index: int = 100  ## Start procedural gigs at 100+
const MAX_ACTIVE_PROCEDURAL: int = 3

const CLIENT_NAMES: PackedStringArray = ["ZERO_DAY", "BROKER_7", "GHOST_SIGNAL", "DR_PATCH", "CIPHER_QUEEN", "ARCHIVE_X"]

## Starting buildings (always available)
var _starter_buildings: PackedStringArray = ["Trash", "Splitter", "Uplink"]

var building_container: Node2D = null
var _contract_terminal: Node2D = null
var upgrade_manager: Node = null  ## UpgradeManager reference for CT delivery upgrades
var skip_tutorial: bool = false  ## Level 2+: all buildings unlocked, procedural only


func _ready() -> void:
	_load_gigs()
	# Mark starter buildings as unlocked
	for b_name in _starter_buildings:
		_unlocked_buildings[b_name] = true


## Call after signals are connected to ensure notifications fire
func initialize() -> void:
	if skip_tutorial:
		_unlock_all_buildings()
		_tutorials_complete = true
		_fill_procedural_gigs()
	else:
		_activate_next_tutorial_gig()


func set_level(level: int) -> void:
	_build_content_pool_for_level(level)


func _unlock_all_buildings() -> void:
	## Unlock all placeable buildings (for Level 2+)
	var all_names: PackedStringArray = [
		"Trash", "Splitter", "Merger", "Classifier", "Scanner", "Separator",
		"Decryptor", "Encryptor", "Recoverer", "Key Forge", "Repair Lab", "Uplink"
	]
	for b_name in all_names:
		_unlocked_buildings[b_name] = true


func _load_gigs() -> void:
	# Hardcoded list — DirAccess fails in web exports (PCK packed resources)
	var gig_paths: PackedStringArray = [
		"res://resources/gigs/gig_01.tres",
		"res://resources/gigs/gig_02.tres",
		"res://resources/gigs/gig_03.tres",
		"res://resources/gigs/gig_04.tres",
		"res://resources/gigs/gig_05.tres",
		"res://resources/gigs/gig_06.tres",
		"res://resources/gigs/gig_07.tres",
		"res://resources/gigs/gig_08.tres",
		"res://resources/gigs/gig_09.tres",
	]
	for path in gig_paths:
		var gig = load(path)
		if gig != null:
			_all_gigs.append(gig)
	# Sort by order_index
	_all_gigs.sort_custom(func(a, b): return a.order_index < b.order_index)
	print("[GigManager] Loaded %d gig definitions" % _all_gigs.size())


func set_contract_terminal(terminal: Node2D) -> void:
	_contract_terminal = terminal
	_contract_terminal.purity_checker = _output_matches_any_requirement
	print("[GigManager] Contract Terminal linked")


func is_building_unlocked(building_name: String) -> bool:
	return _unlocked_buildings.get(building_name, false)


func get_active_gigs() -> Array:
	return _active_gigs


func get_progress(gig) -> Array:
	return _progress.get(gig.order_index, [])


func is_gig_completed(order_index: int) -> bool:
	return _completed_indices.has(order_index)


func are_all_gigs_completed() -> bool:
	for gig in _all_gigs:
		if not _completed_indices.has(gig.order_index):
			return false
	return _all_gigs.size() > 0


## Called each simulation tick — process deliveries at Contract Terminal
func process_deliveries() -> void:
	if _contract_terminal == null:
		return
	if _active_gigs.is_empty():
		return
	if _contract_terminal.stored_data.is_empty():
		return

	# Count deliveries from accepted data (blocked ports never receive data)
	for key in _contract_terminal.stored_data:
		var amount: int = _contract_terminal.stored_data[key]
		if amount <= 0:
			continue
		var c: int = DataEnums.unpack_content(key)
		var s: int = DataEnums.unpack_state(key)
		var t: int = DataEnums.unpack_tier(key)
		var tg: int = DataEnums.unpack_tags(key)
		var st: int = DataEnums.unpack_sub_type(key)
		_count_delivery(c, s, t, tg, amount, st)
		# Feed upgrade system
		if upgrade_manager:
			upgrade_manager.add_data(c, s, tg, amount)

	# Consume all delivered data (Shapez model)
	_contract_terminal.stored_data.clear()

	# Check gig completion
	_check_completions()


# ─── PORT PURITY: Cable Type Checking ───
# Each CT port tracks what data types have flowed through its cable (cumulative).
# When a non-matching type is detected at push time, the port is instantly blocked.
# Re-evaluated when gigs change (new requirements may accept previously blocked types).
# Cleared when cable is disconnected.

## Re-evaluate all CT ports based on their recorded carried types.
## Called when gigs activate/complete (matching criteria changes).
func evaluate_ct_connections() -> void:
	if _contract_terminal == null:
		return
	_contract_terminal.blocked_ports.clear()
	for port in _contract_terminal.port_carried_types:
		var types: Dictionary = _contract_terminal.port_carried_types[port]
		for type_key in types:
			if not _output_matches_any_requirement((type_key >> 8) & 0xF, (type_key >> 4) & 0xF, type_key & 0xF):
				_contract_terminal.blocked_ports[port] = true
				break


## Called when a connection to CT is added — pre-populate types for sources.
## Source composition is fully known → block instantly before any tick.
## Other buildings have deterministic output → runtime check at first push handles them.
func on_ct_connection_added(conn: Dictionary) -> void:
	if _contract_terminal == null:
		return
	if conn.to_building != _contract_terminal:
		return
	var port: String = conn.to_port
	var upstream: Node2D = conn.from_building
	# Pre-populate for data sources (composition fully known)
	# Sources produce raw data (tags=0), so type_key includes tags=0
	if upstream.definition is DataSourceDefinition:
		var src_def: DataSourceDefinition = upstream.definition
		var sw: Dictionary = upstream.instance_state_weights if not upstream.instance_state_weights.is_empty() else src_def.state_weights
		if not _contract_terminal.port_carried_types.has(port):
			_contract_terminal.port_carried_types[port] = {}
		for c_id in src_def.content_weights:
			if src_def.content_weights[c_id] <= 0.0:
				continue
			for s_id in sw:
				if sw[s_id] <= 0.0:
					continue
				_contract_terminal.port_carried_types[port][(int(c_id) << 8) | (int(s_id) << 4) | 0] = true
		# Evaluate immediately — block before first tick
		evaluate_ct_connections()


## Called when a connection to CT is removed — clear that port's tracking.
func on_ct_connection_removed(conn: Dictionary) -> void:
	if _contract_terminal == null:
		return
	if conn.to_building != _contract_terminal:
		return
	var port: String = conn.to_port
	_contract_terminal.port_carried_types.erase(port)
	_contract_terminal.blocked_ports.erase(port)
	print("[PortPurity] CT port '%s' cleared — cable disconnected" % port)


## Check if a (content, state, tags) is acceptable at the Contract Terminal.
## Used as callable (purity_checker) by SimulationManager at push time.
## Rules:
##   - Content matches a gig requirement AND state+tags match → allow (counts toward gig)
##   - Content matches a gig requirement BUT state or tags wrong → REJECT (force proper processing)
##   - Content doesn't match any gig requirement → allow (irrelevant data, will be trashed)
func _output_matches_any_requirement(content: int, state: int, tags: int = 0) -> bool:
	var content_relevant: bool = false
	for gig in _active_gigs:
		for req in gig.requirements:
			if req.content == content:
				content_relevant = true
				if (req.state < 0 or req.state == state) and req.tags == tags:
					return true  # Exact match — allow
	# Content matched a requirement but state/tags didn't → reject (force proper processing)
	if content_relevant:
		return false
	# Content doesn't match any requirement → irrelevant, allow (will be trashed by CT)
	return true


func _count_delivery(content: int, state: int, tier: int, tags: int, amount: int, sub_type: int = -1) -> void:
	for gig in _active_gigs:
		var progress_arr: Array = _progress.get(gig.order_index, [])
		for i in range(gig.requirements.size()):
			var req = gig.requirements[i]
			if req.content != content:
				continue
			if req.state >= 0 and req.state != state:
				continue
			# Check tags: exact match — different tag combo = different product
			if tags != req.tags:
				continue
			# Check sub-type if requirement specifies one
			if req.sub_type >= 0 and sub_type != req.sub_type:
				continue
			# Check minimum tier if specified
			if req.min_tier > 0 and tier < req.min_tier:
				continue
			# Match — count toward this requirement
			var old_val: int = progress_arr[i]
			var new_val: int = mini(old_val + amount, req.amount)
			progress_arr[i] = new_val
			if new_val > old_val:
				gig_progress_updated.emit(gig, i, new_val, req.amount)


func _check_completions() -> void:
	var newly_completed: Array = []
	for gig in _active_gigs:
		if _is_gig_complete(gig):
			newly_completed.append(gig)

	for gig in newly_completed:
		_complete_gig(gig)


func _is_gig_complete(gig) -> bool:
	var progress_arr: Array = _progress.get(gig.order_index, [])
	for i in range(gig.requirements.size()):
		if progress_arr[i] < gig.requirements[i].amount:
			return false
	return true


func _complete_gig(gig) -> void:
	_active_gigs.erase(gig)
	_completed_indices[gig.order_index] = true
	print("[GigManager] Gig completed — %s" % gig.gig_name)
	gig_completed.emit(gig)
	# Re-evaluate CT ports — new gigs may accept different data
	evaluate_ct_connections()

	# Unlock reward buildings
	for b_name in gig.reward_buildings:
		if not _unlocked_buildings.has(b_name):
			_unlocked_buildings[b_name] = true
			building_unlocked.emit(b_name)
			print("[GigManager] Building unlocked — %s" % b_name)

	# Progress gig chain
	if gig.is_tutorial:
		_activate_next_tutorial_gig()
	else:
		_procedural_count += 1
		_fill_procedural_gigs()


func _activate_next_tutorial_gig() -> void:
	for gig in _all_gigs:
		if gig.is_tutorial and not _completed_indices.has(gig.order_index):
			if gig in _active_gigs:
				return  # Already active
			_activate_gig(gig)
			return
	# All tutorials done — start procedural system
	if not _tutorials_complete:
		_tutorials_complete = true
		print("[GigManager] All tutorials complete — procedural contracts enabled")
	_fill_procedural_gigs()


func _fill_procedural_gigs() -> void:
	## Keep MAX_ACTIVE_PROCEDURAL gigs running at all times
	var active_count: int = 0
	for gig in _active_gigs:
		if not gig.is_tutorial:
			active_count += 1
	while active_count < MAX_ACTIVE_PROCEDURAL:
		var gig = _generate_procedural_gig()
		_all_gigs.append(gig)
		_activate_gig(gig)
		active_count += 1


func _prerequisites_met(gig) -> bool:
	for req_index in gig.prerequisite_gigs:
		if not _completed_indices.has(req_index):
			return false
	return true


func _activate_gig(gig) -> void:
	_active_gigs.append(gig)
	# Initialize progress array
	var progress_arr: Array = []
	for _i in range(gig.requirements.size()):
		progress_arr.append(0)
	_progress[gig.order_index] = progress_arr

	# Unlock reward buildings when gig becomes active (player needs them to complete it)
	for b_name in gig.reward_buildings:
		if not _unlocked_buildings.has(b_name):
			_unlocked_buildings[b_name] = true
			building_unlocked.emit(b_name)
			print("[GigManager] Building unlocked (gig active) — %s" % b_name)

	gig_activated.emit(gig)
	print("[GigManager] Gig activated — %s (order: %d)" % [gig.gig_name, gig.order_index])
	# Re-evaluate CT ports — new gig requirements change what's accepted
	evaluate_ct_connections()


# ── PROCEDURAL GIG GENERATOR ──────────────────────────────────

## Difficulty tiers define what processing tags are required.
## Tiers cycle through increasingly complex processing chains.
const PROC_TIERS: Array = [
	# tier 0-1: Public data, no processing needed
	{"tags": 0, "state": 0, "label_suffix": "Public"},
	{"tags": 0, "state": 0, "label_suffix": "Public"},
	# tier 2-3: Decrypted (needs Decryptor)
	{"tags": 1, "state": 0, "label_suffix": "Decrypted"},
	{"tags": 1, "state": 0, "label_suffix": "Decrypted"},
	# tier 4-5: Recovered (needs Recoverer)
	{"tags": 2, "state": 0, "label_suffix": "Recovered"},
	{"tags": 2, "state": 0, "label_suffix": "Recovered"},
	# tier 6-7: Decrypted·Encrypted (needs Decryptor + Encryptor chain)
	{"tags": 5, "state": 0, "label_suffix": "Decrypted\u00b7Encrypted"},
	{"tags": 5, "state": 0, "label_suffix": "Decrypted\u00b7Encrypted"},
	# tier 8-9: Recovered·Decrypted (multi-step pipeline)
	{"tags": 3, "state": 0, "label_suffix": "Recovered\u00b7Decrypted"},
	{"tags": 3, "state": 0, "label_suffix": "Recovered\u00b7Decrypted"},
	# tier 10-11: Recovered·Encrypted (Recovery + Encryption chain)
	{"tags": 6, "state": 0, "label_suffix": "Recovered\u00b7Encrypted"},
	{"tags": 6, "state": 0, "label_suffix": "Recovered\u00b7Encrypted"},
	# tier 12+: Dec·Enc (hardest single-chain — cycles back with higher amounts)
	{"tags": 5, "state": 0, "label_suffix": "Decrypted\u00b7Encrypted"},
]

## Content pool — weighted by difficulty (harder content unlocks later)
const EASY_CONTENT: Array[int] = [0, 1, 2]  # Standard, Financial, Biometric
const MID_CONTENT: Array[int] = [0, 1, 2, 4]  # + Research (available in easy/medium sources)
const HARD_CONTENT: Array[int] = [3, 4]      # Blueprint, Research

## Level-aware content pool: which content types are realistically available
var _level_content_pool: Array[int] = []


func _build_content_pool_for_level(level: int) -> void:
	## Determines which content types procedural gigs can request.
	## Based on what sources actually produce at this level.
	var data: Dictionary = LevelConfig.get_level(level)
	var pools: Array = data.source_pools
	if "hard" in pools or "endgame" in pools:
		# Hard/Endgame sources carry Blueprint + Research
		_level_content_pool = [0, 1, 2, 3, 4]
	elif "medium" in pools:
		# Medium sources carry Research but NOT Blueprint
		_level_content_pool = [0, 1, 2, 4]  # Standard, Financial, Biometric, Research
	else:
		_level_content_pool = [0, 1, 2]  # Easy only


func _generate_procedural_gig() -> GigDefinition:
	var gig := GigDefinition.new()
	var diff: int = _procedural_count

	# Tier wraps around PROC_TIERS with increasing base difficulty
	var cycle: int = diff / PROC_TIERS.size()  # How many full cycles completed
	var tier_idx: int = diff % PROC_TIERS.size()
	var tier_data: Dictionary = PROC_TIERS[tier_idx]

	# Pick content — filtered by level's available content types
	var content: int
	if _level_content_pool.is_empty():
		_level_content_pool = [0, 1, 2]  # Fallback
	content = _level_content_pool[randi() % _level_content_pool.size()]

	# Amount scales with difficulty — logarithmic curve, never feels flat
	# Base: 10, grows ~40% per difficulty level, soft-capped at 200
	var base_amount: int = 10 + int(diff * 3.5) + cycle * 15
	var amount: int = mini(base_amount, 200)

	# Build primary requirement
	var req := GigRequirement.new()
	req.content = content
	req.state = tier_data.state
	req.tags = tier_data.tags
	req.amount = amount
	req.label = "%s %s" % [DataEnums.content_name(content), tier_data.label_suffix]

	var reqs: Array[Resource] = [req]

	# Multi-requirement gigs: guaranteed at diff 6+, with escalating complexity
	if diff >= 6:
		var num_extra: int = 1
		if diff >= 15:
			num_extra = 2  # Triple-requirement at very high difficulty
		if diff >= 25:
			num_extra = mini(3, _level_content_pool.size() - 1)  # Quad at extreme

		var used_contents: Array[int] = [content]
		for _e in range(num_extra):
			# Pick a different content type
			var pool: Array[int] = []
			for c in _level_content_pool:
				if c not in used_contents:
					pool.append(c)
			if pool.is_empty():
				break
			var content2: int = pool[randi() % pool.size()]
			used_contents.append(content2)

			# Secondary requirements use a different (often easier) processing tier
			var sec_tier_idx: int = maxi(tier_idx - 2 - (randi() % 3), 0)
			var sec_tier: Dictionary = PROC_TIERS[sec_tier_idx]
			var sec_amount: int = maxi(amount / 2 + randi() % (amount / 4 + 1), 8)

			var req2 := GigRequirement.new()
			req2.content = content2
			req2.state = sec_tier.state
			req2.tags = sec_tier.tags
			req2.amount = sec_amount
			req2.label = "%s %s" % [DataEnums.content_name(content2), sec_tier.label_suffix]
			reqs.append(req2)

	# Sub-type requirement at high difficulty (forces Scanner usage)
	if diff >= 10 and randf() < 0.3 + float(diff - 10) * 0.05:
		var st_count: int = DataEnums.sub_type_count(content)
		if st_count > 0:
			var picked_st: int = randi() % st_count
			req.sub_type = picked_st
			var st_name: String = DataEnums.sub_type_name(content, picked_st)
			if st_name != "":
				req.label += " [%s]" % st_name

	# Generate name and description
	var client: String = CLIENT_NAMES[randi() % CLIENT_NAMES.size()]
	var gig_label: String = _proc_gig_name(content, tier_data.tags)
	if reqs.size() > 1:
		gig_label += " +" + str(reqs.size() - 1)
	gig.gig_name = gig_label
	gig.description = "%s: I need %d %s. %s\n\n%s" % [
		client, amount, req.label,
		"Plus %d more deliveries." % (reqs.size() - 1) if reqs.size() > 1 else "",
		_proc_gig_instruction(tier_data.tags)]
	gig.order_index = _next_order_index
	gig.is_tutorial = false
	gig.requirements = reqs
	gig.reward_buildings = []

	_next_order_index += 1
	print("[GigManager] Generated procedural gig — %s (difficulty %d, cycle %d, %d reqs)" % [gig.gig_name, diff, cycle, reqs.size()])
	return gig


const GIG_NAME_VARIANTS: Dictionary = {
	0: ["% Harvest", "% Extract", "% Siphon", "% Grab"],
	1: ["% Decrypt Job", "% Codebreak", "% Key Crack", "% Cipher Run"],
	2: ["% Recovery", "% Salvage", "% Restore Op", "% Data Rescue"],
	4: ["% Encryption", "% Lockdown", "% Seal Job", "% Vault Run"],
	5: ["% Secure Transfer", "% Full Cycle", "% Roundtrip", "% Lock & Key"],
	3: ["% Deep Clean", "% Dual Process", "% Pipeline Run", "% Total Purge"],
	6: ["% Armored Recovery", "% Shield & Heal", "% Fortified Salvage", "% Iron Restore"],
}

func _proc_gig_name(content: int, tags: int) -> String:
	var c_name: String = DataEnums.content_name(content)
	var variants: Array = GIG_NAME_VARIANTS.get(tags, ["% Contract"])
	var template: String = variants[randi() % variants.size()]
	return template.replace("%", c_name)


func _proc_gig_instruction(tags: int) -> String:
	match tags:
		0: return "Deliver clean Public data to the Terminal."
		1: return "Decrypt the data first — you'll need Keys from a Key Forge."
		2: return "Recover corrupted data — feed same-content Public fuel into the Recoverer."
		5: return "Decrypt first, then re-encrypt through the Encryptor. Both need Keys."
		3: return "Recover the data, then decrypt it. A multi-step pipeline."
		6: return "Recover the data, then encrypt it. Build a Recovery + Encryption chain."
	return "Process and deliver the data."
