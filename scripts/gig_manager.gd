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

## Starting buildings (always available)
var _starter_buildings: PackedStringArray = ["Trash", "Splitter", "Bridge"]

var building_container: Node2D = null
var _contract_terminal: Node2D = null


func _ready() -> void:
	_load_gigs()
	# Mark starter buildings as unlocked
	for b_name in _starter_buildings:
		_unlocked_buildings[b_name] = true


## Call after signals are connected to ensure notifications fire
func initialize() -> void:
	_activate_next_tutorial_gig()


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
	for key in _contract_terminal.stored_data.keys():
		var amount: int = _contract_terminal.stored_data[key]
		if amount <= 0:
			continue
		if DataEnums.is_packet(key):
			_count_packet_delivery(key, amount)
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		_count_delivery(parsed.content, parsed.state, parsed.tier, parsed.tags, amount)

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
			var parts: PackedStringArray = type_key.split("_")
			if not _output_matches_any_requirement(int(parts[0]), int(parts[1])):
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
	if upstream.definition is DataSourceDefinition:
		var src_def: DataSourceDefinition = upstream.definition
		if not _contract_terminal.port_carried_types.has(port):
			_contract_terminal.port_carried_types[port] = {}
		for c_id in src_def.content_weights:
			if src_def.content_weights[c_id] <= 0.0:
				continue
			for s_id in src_def.state_weights:
				if src_def.state_weights[s_id] <= 0.0:
					continue
				_contract_terminal.port_carried_types[port]["%d_%d" % [int(c_id), int(s_id)]] = true
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


## Check if a (content, state) is acceptable at the Contract Terminal.
## Used as callable (purity_checker) by SimulationManager at push time.
## Rules:
##   - Content matches a gig requirement AND state matches → allow (counts toward gig)
##   - Content matches a gig requirement BUT state is wrong → REJECT (force state filtering)
##   - Content doesn't match any gig requirement → allow (irrelevant data, will be trashed)
func _output_matches_any_requirement(content: int, state: int) -> bool:
	var content_relevant: bool = false
	for gig in _active_gigs:
		for req in gig.requirements:
			if req.packet_key != "":
				continue
			if req.content == content:
				content_relevant = true
				if req.state < 0 or req.state == state:
					return true  # Exact match — allow
	# Content matched a requirement but state didn't → reject (force state filtering)
	if content_relevant:
		return false
	# Content doesn't match any requirement → irrelevant, allow (will be trashed by CT)
	return true


func _count_packet_delivery(pkt_key: String, amount: int) -> void:
	# Packet = real product — counts as ONE delivery, not split into components
	for gig in _active_gigs:
		var progress_arr: Array = _progress.get(gig.order_index, [])
		for i in range(gig.requirements.size()):
			var req = gig.requirements[i]
			if req.packet_key == "":
				continue
			if req.packet_key != pkt_key:
				continue
			# Match — count packet as single delivery
			var old_val: int = progress_arr[i]
			var new_val: int = mini(old_val + amount, req.amount)
			progress_arr[i] = new_val
			if new_val > old_val:
				gig_progress_updated.emit(gig, i, new_val, req.amount)


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
		_check_wave_activations()


func _activate_next_tutorial_gig() -> void:
	for gig in _all_gigs:
		if gig.is_tutorial and not _completed_indices.has(gig.order_index):
			if gig in _active_gigs:
				return  # Already active
			_activate_gig(gig)
			return
	# All tutorials done — check wave activations
	_check_wave_activations()


func _check_wave_activations() -> void:
	var activated_any := false
	for gig in _all_gigs:
		if gig.is_tutorial:
			continue
		if _completed_indices.has(gig.order_index):
			continue
		if gig in _active_gigs:
			continue
		if not _prerequisites_met(gig):
			continue
		_activate_gig(gig)
		activated_any = true
	if activated_any:
		print("[GigManager] Wave check — new contracts activated")


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
