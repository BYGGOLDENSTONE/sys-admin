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

const CLIENT_NAMES: PackedStringArray = ["FIXER_NULL", "BROKER_7", "GHOST_SIGNAL", "DR_PATCH", "CIPHER_QUEEN", "ARCHIVE_X"]

## Starting buildings (always available)
var _starter_buildings: PackedStringArray = ["Trash", "Splitter"]

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
		"Decryptor", "Encryptor", "Recoverer", "Key Forge", "Repair Lab"
	]
	for b_name in all_names:
		_unlocked_buildings[b_name] = true


func _load_gigs() -> void:
	var dir := DirAccess.open("res://resources/gigs/")
	if dir == null:
		push_warning("[GigManager] Cannot open gigs directory")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var gig = load("res://resources/gigs/" + file_name)
			if gig != null:
				_all_gigs.append(gig)
		file_name = dir.get_next()
	dir.list_dir_end()
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
		_count_delivery(c, s, t, tg, amount)
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


func _count_delivery(content: int, state: int, tier: int, tags: int, amount: int) -> void:
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

## Difficulty tiers define what processing tags are required
const PROC_TIERS: Array = [
	# tier 0-2: Public data, no processing needed
	{"tags": 0, "state": 0, "label_suffix": "Public"},
	{"tags": 0, "state": 0, "label_suffix": "Public"},
	{"tags": 0, "state": 0, "label_suffix": "Public"},
	# tier 3-4: Decrypted (needs Decryptor)
	{"tags": 1, "state": 0, "label_suffix": "Decrypted"},
	{"tags": 1, "state": 0, "label_suffix": "Decrypted"},
	# tier 5-6: Recovered (needs Recoverer)
	{"tags": 2, "state": 0, "label_suffix": "Recovered"},
	{"tags": 2, "state": 0, "label_suffix": "Recovered"},
	# tier 7-8: Decrypted·Encrypted (needs Decryptor + Encryptor chain)
	{"tags": 5, "state": 0, "label_suffix": "Decrypted\u00b7Encrypted"},
	{"tags": 5, "state": 0, "label_suffix": "Decrypted\u00b7Encrypted"},
	# tier 9+: Recovered·Decrypted or multi-requirement
	{"tags": 3, "state": 0, "label_suffix": "Recovered\u00b7Decrypted"},
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
	var tier_idx: int = mini(diff, PROC_TIERS.size() - 1)
	var tier_data: Dictionary = PROC_TIERS[tier_idx]

	# Pick content — filtered by level's available content types
	var content: int
	if _level_content_pool.is_empty():
		_level_content_pool = [0, 1, 2]  # Fallback
	content = _level_content_pool[randi() % _level_content_pool.size()]

	# Amount scales with difficulty
	var amount: int = 8 + mini(diff, 10) * 2

	# Build requirement
	var req := GigRequirement.new()
	req.content = content
	req.state = tier_data.state
	req.tags = tier_data.tags
	req.amount = amount
	req.label = "%s %s" % [DataEnums.content_name(content), tier_data.label_suffix]

	# Multi-requirement at high difficulty (2 different content types)
	var reqs: Array[Resource] = [req]
	if diff >= 8 and randf() < 0.5:
		var content2: int = content
		while content2 == content:
			content2 = (EASY_CONTENT + HARD_CONTENT)[randi() % 5]
		var prev_tier: Dictionary = PROC_TIERS[maxi(tier_idx - 2, 0)]
		var req2 := GigRequirement.new()
		req2.content = content2
		req2.state = prev_tier.state
		req2.tags = prev_tier.tags
		req2.amount = maxi(amount - 5, 5)
		req2.label = "%s %s" % [DataEnums.content_name(content2), prev_tier.label_suffix]
		reqs.append(req2)

	# Generate name and description
	var client: String = CLIENT_NAMES[randi() % CLIENT_NAMES.size()]
	gig.gig_name = _proc_gig_name(content, tier_data.tags)
	gig.description = "%s: I need %d %s. Get it flowing.\n\n%s" % [
		client, amount, req.label, _proc_gig_instruction(tier_data.tags)]
	gig.order_index = _next_order_index
	gig.is_tutorial = false
	gig.requirements = reqs
	gig.reward_buildings = []

	_next_order_index += 1
	print("[GigManager] Generated procedural gig — %s (difficulty %d)" % [gig.gig_name, diff])
	return gig


func _proc_gig_name(content: int, tags: int) -> String:
	var c_name: String = DataEnums.content_name(content)
	match tags:
		0: return "%s Harvest" % c_name
		1: return "%s Decrypt Job" % c_name
		2: return "%s Recovery" % c_name
		4: return "%s Encryption" % c_name
		5: return "%s Secure Transfer" % c_name
		3: return "%s Deep Clean" % c_name
	return "%s Contract" % c_name


func _proc_gig_instruction(tags: int) -> String:
	match tags:
		0: return "Deliver clean Public data to the Terminal."
		1: return "Decrypt the data first — you'll need Keys from a Key Forge."
		2: return "Recover corrupted data — feed same-content Public fuel into the Recoverer."
		5: return "Decrypt first, then re-encrypt through the Encryptor. Both need Keys."
		3: return "Recover the data, then decrypt it. A multi-step pipeline."
	return "Process and deliver the data."
