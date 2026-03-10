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
var _starter_buildings: PackedStringArray = ["Uplink", "Quarantine", "Splitter", "Merger", "Bridge"]

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
	print("[GigManager] Contract Terminal linked")


func is_building_unlocked(building_name: String) -> bool:
	return _unlocked_buildings.get(building_name, false)


func get_active_gigs() -> Array:
	return _active_gigs


func get_progress(gig) -> Array:
	return _progress.get(gig.order_index, [])


func is_gig_completed(order_index: int) -> bool:
	return _completed_indices.has(order_index)


## Called each simulation tick — process deliveries at Contract Terminal
func process_deliveries() -> void:
	if _contract_terminal == null:
		return
	if _active_gigs.is_empty():
		return
	if _contract_terminal.stored_data.is_empty():
		return

	# Process each data item in Contract Terminal
	for key in _contract_terminal.stored_data.keys():
		var amount: int = _contract_terminal.stored_data[key]
		if amount <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		_count_delivery(parsed.content, parsed.state, parsed.tier, parsed.tags, amount)

	# Consume all delivered data (Shapez model)
	_contract_terminal.stored_data.clear()

	# Check gig completion
	_check_completions()


func _count_delivery(content: int, state: int, _tier: int, tags: int, amount: int) -> void:
	for gig in _active_gigs:
		var progress_arr: Array = _progress.get(gig.order_index, [])
		for i in range(gig.requirements.size()):
			var req = gig.requirements[i]
			if req.content != content:
				continue
			if req.state >= 0 and req.state != state:
				continue
			# Check tags: delivered data must have ALL required tags
			if req.tags != 0 and (tags & req.tags) != req.tags:
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

	# Unlock reward buildings
	for b_name in gig.reward_buildings:
		if not _unlocked_buildings.has(b_name):
			_unlocked_buildings[b_name] = true
			building_unlocked.emit(b_name)
			print("[GigManager] Building unlocked — %s" % b_name)

	# Activate next tutorial gig
	if gig.is_tutorial:
		_activate_next_tutorial_gig()


func _activate_next_tutorial_gig() -> void:
	for gig in _all_gigs:
		if gig.is_tutorial and not _completed_indices.has(gig.order_index):
			if gig in _active_gigs:
				return  # Already active
			_activate_gig(gig)
			return


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
