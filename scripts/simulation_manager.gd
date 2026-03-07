extends Node

signal tick_completed(tick_count: int)
signal content_discovered(content: int)
signal state_discovered(state: int)
signal speed_changed(multiplier: int, paused: bool)

const TILE_SIZE: int = 64
var _tick_count: int = 0
var speed_multiplier: int = 1
var is_paused: bool = false
var discovered_content: Dictionary = {0: true, 1: false, 2: false, 3: false, 4: false, 5: false}
var discovered_states: Dictionary = {0: true, 1: false, 2: false, 3: false}
var connection_manager: Node = null
var building_container: Node2D = null
var connection_flow_data: Dictionary = {}  # conn_index → [{content, state, amount}]

@onready var _sim_timer: Timer = $SimTimer


func _ready() -> void:
	_sim_timer.timeout.connect(_on_sim_tick)
	print("[Simulation] Manager initialized — tick: %.1fs" % _sim_timer.wait_time)


func set_speed(multiplier: int) -> void:
	speed_multiplier = clampi(multiplier, 1, 3)
	_sim_timer.wait_time = 1.0 / speed_multiplier
	if is_paused:
		is_paused = false
		_sim_timer.paused = false
	speed_changed.emit(speed_multiplier, is_paused)
	print("[Simulation] Speed set to %dx (tick: %.2fs)" % [speed_multiplier, _sim_timer.wait_time])


func toggle_pause() -> void:
	is_paused = not is_paused
	_sim_timer.paused = is_paused
	speed_changed.emit(speed_multiplier, is_paused)
	print("[Simulation] %s" % ("Paused" if is_paused else "Resumed at %dx" % speed_multiplier))


func _on_sim_tick() -> void:
	var buildings: Array[Node] = []
	for child in building_container.get_children():
		if child.has_method("is_active"):
			buildings.append(child)
	_tick_count += 1
	if buildings.is_empty():
		tick_completed.emit(_tick_count)
		return
	# Reset work flags and flow tracking
	connection_flow_data.clear()
	for b in buildings:
		b.is_working = false
	_update_generation(buildings)
	_update_storage_forward(buildings)
	_update_processing(buildings)
	_update_displays(buildings)
	tick_completed.emit(_tick_count)


# --- ROLL HELPERS ---
func _roll_content(weights: Dictionary) -> int:
	if weights.is_empty():
		return DataEnums.ContentType.STANDARD
	var roll: float = randf()
	var cumulative: float = 0.0
	for content_id in weights:
		cumulative += weights[content_id]
		if roll <= cumulative:
			return int(content_id)
	return DataEnums.ContentType.STANDARD


func _roll_state(weights: Dictionary) -> int:
	if weights.is_empty():
		return DataEnums.DataState.CLEAN
	var roll: float = randf()
	var cumulative: float = 0.0
	for state_id in weights:
		cumulative += weights[state_id]
		if roll <= cumulative:
			return int(state_id)
	return DataEnums.DataState.CLEAN


# --- DISCOVERY ---
func _check_discovery(content: int, state: int) -> void:
	if not discovered_content.get(content, false):
		discovered_content[content] = true
		content_discovered.emit(content)
		print("[Discovery] Yeni content keşfedildi: %s" % DataEnums.content_name(content))
	if not discovered_states.get(state, false):
		discovered_states[state] = true
		state_discovered.emit(state)
		print("[Discovery] Yeni state keşfedildi: %s" % DataEnums.state_name(state))


# --- DATA PUSH ---
func _push_data_from(source: Node2D, content: int, state: int, amount: int, from_port: String = "") -> int:
	var conns: Array[Dictionary] = connection_manager.get_connections()
	var targets: Array[Dictionary] = []
	for conn in conns:
		if conn.from_building == source:
			if from_port == "" or conn.from_port == from_port:
				targets.append(conn)
	if targets.is_empty():
		return 0
	var key: String = DataEnums.make_key(content, state)
	var per_target: int = maxi(1, amount / targets.size())
	var total_sent: int = 0
	var all_conns: Array[Dictionary] = conns
	for conn in targets:
		var target: Node2D = conn.to_building
		if not target.has_method("can_accept_data"):
			continue
		var to_send: int = mini(per_target, amount)
		if to_send <= 0:
			break
		if not target.accepts_data(content, state):
			continue
		if target.can_accept_data(to_send):
			target.stored_data[key] = target.stored_data.get(key, 0) + to_send
			amount -= to_send
			total_sent += to_send
			# Track flow data for particle visuals
			var conn_idx: int = all_conns.find(conn)
			if conn_idx >= 0:
				if not connection_flow_data.has(conn_idx):
					connection_flow_data[conn_idx] = []
				connection_flow_data[conn_idx].append({"content": content, "state": state, "amount": to_send})
	return total_sent


# --- DATA GENERATION (Uplink) ---
func _update_generation(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.definition.generator == null or not b.is_active():
			continue
		var gen: GeneratorComponent = b.definition.generator
		var amount: int = int(gen.generation_rate)
		# Use runtime weights from linked source if available, otherwise definition weights
		var c_weights: Dictionary = b.runtime_content_weights if not b.runtime_content_weights.is_empty() else gen.content_weights
		var s_weights: Dictionary = b.runtime_state_weights if not b.runtime_state_weights.is_empty() else gen.state_weights
		var total_pushed: int = 0
		for i in range(amount):
			var content: int = _roll_content(c_weights)
			var state: int = _roll_state(s_weights)
			_check_discovery(content, state)
			total_pushed += _push_data_from(b, content, state, 1)
		if total_pushed > 0:
			b.is_working = true


# --- STORAGE FORWARD ---
func _update_storage_forward(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.definition.storage == null or not b.is_active():
			continue
		if b.definition.processor != null or b.definition.splitter != null or b.definition.merger != null:
			continue
		if b.get_total_stored() <= 0:
			continue
		var stor: StorageComponent = b.definition.storage
		var max_forward: int = int(stor.forward_rate) if stor.forward_rate > 0 else b.get_total_stored()
		max_forward = maxi(1, max_forward)
		var sent: int = 0
		for key in b.stored_data:
			if sent >= max_forward:
				break
			var available: int = b.stored_data[key]
			if available <= 0:
				continue
			var parsed: Dictionary = DataEnums.parse_key(key)
			var pushed: int = _push_data_from(b, parsed.content, parsed.state, mini(available, max_forward - sent))
			if pushed > 0:
				b.stored_data[key] -= pushed
				sent += pushed
		if sent > 0:
			b.is_working = true


# --- PROCESSING ---
func _update_processing(buildings: Array[Node]) -> void:
	for b in buildings:
		if not b.is_active() or b.get_total_stored() <= 0:
			continue
		var processed: int = 0
		# Component-based dispatch: check dedicated components first
		if b.definition.splitter != null:
			processed = _process_splitter(b, int(b.definition.splitter.throughput_rate))
		elif b.definition.merger != null:
			processed = _process_merger(b, int(b.definition.merger.throughput_rate))
		elif b.definition.processor != null:
			var proc: ProcessorComponent = b.definition.processor
			var max_process: int = int(b.get_effective_value("processing_rate"))
			match proc.rule:
				"separator":
					processed = _process_separator(b, proc, max_process)
				"decryptor":
					processed = _process_decryptor(b, proc, max_process)
				"recoverer":
					processed = _process_recoverer(b, proc, max_process)
				"quarantine":
					processed = _process_quarantine(b, proc, max_process)
		else:
			continue
		if processed > 0:
			b.is_working = true
		b.stored_data.clear()


func _process_separator(b: Node2D, proc: ProcessorComponent, max_process: int) -> int:
	var eff: float = b.get_effective_value("efficiency")
	var primary_port: String = b.definition.output_ports[0] if b.definition.output_ports.size() > 0 else ""
	var secondary_port: String = b.definition.output_ports[1] if b.definition.output_ports.size() > 1 else ""
	var processed: int = 0
	var mode: String = proc.separator_mode
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data[key]
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		var to_process: int = mini(available, max_process - processed)
		var output_amount: int = maxi(1, roundi(to_process * eff))
		# Route: matching value → primary, rest → secondary
		var matches: bool
		if mode == "content":
			matches = (parsed.content == b.separator_filter_value)
		else:
			matches = (parsed.state == b.separator_filter_value)
		var target_port: String = primary_port if matches else secondary_port
		if target_port == "":
			continue
		var sent: int = _push_data_from(b, parsed.content, parsed.state, output_amount, target_port)
		if sent > 0:
			_check_discovery(parsed.content, parsed.state)
			processed += to_process
	return processed



func _process_decryptor(b: Node2D, proc: ProcessorComponent, max_process: int) -> int:
	var eff: float = b.get_effective_value("efficiency")
	var processed: int = 0
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data[key]
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		# Only process matching input states (ENCRYPTED)
		if not proc.input_states.is_empty() and parsed.state not in proc.input_states:
			continue
		var to_process: int = mini(available, max_process - processed)
		var output_amount: int = maxi(1, roundi(to_process * eff))
		# Encrypted → Clean (content preserved)
		var sent: int = _push_data_from(b, parsed.content, DataEnums.DataState.CLEAN, output_amount)
		if sent > 0:
			processed += to_process
	return processed


func _process_recoverer(b: Node2D, proc: ProcessorComponent, max_process: int) -> int:
	var eff: float = b.get_effective_value("efficiency")
	var processed: int = 0
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data[key]
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		# Only process matching input states (CORRUPTED)
		if not proc.input_states.is_empty() and parsed.state not in proc.input_states:
			continue
		var to_process: int = mini(available, max_process - processed)
		var output_amount: int = maxi(1, roundi(to_process * eff))
		# Corrupted → Clean (content preserved), push to output port
		var sent: int = _push_data_from(b, parsed.content, DataEnums.DataState.CLEAN, output_amount)
		if sent > 0:
			processed += to_process
			print("[Recoverer] %d MB %s(Corrupted) → %d MB %s(Clean)" % [to_process, DataEnums.content_name(parsed.content), output_amount, DataEnums.content_name(parsed.content)])
	return processed


func _process_quarantine(b: Node2D, proc: ProcessorComponent, max_process: int) -> int:
	var processed: int = 0
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data[key]
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		# Only process matching input states (MALWARE)
		if not proc.input_states.is_empty() and parsed.state not in proc.input_states:
			continue
		var to_process: int = mini(available, max_process - processed)
		processed += to_process
		print("[Quarantine] Neutralized %d MB malware" % to_process)
	return processed


func _process_splitter(b: Node2D, max_process: int) -> int:
	var processed: int = 0
	var output_ports: Array[String] = b.definition.output_ports
	if output_ports.is_empty():
		return 0
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data[key]
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		var to_process: int = mini(available, max_process - processed)
		var per_port: int = maxi(1, to_process / output_ports.size())
		var sent_total: int = 0
		for port in output_ports:
			var to_send: int = mini(per_port, to_process - sent_total)
			if to_send <= 0:
				break
			var sent: int = _push_data_from(b, parsed.content, parsed.state, to_send, port)
			sent_total += sent
		if sent_total > 0:
			processed += to_process
	return processed


func _process_merger(b: Node2D, max_process: int) -> int:
	var processed: int = 0
	var output_port: String = b.definition.output_ports[0] if b.definition.output_ports.size() > 0 else ""
	if output_port == "":
		return 0
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data[key]
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		var to_process: int = mini(available, max_process - processed)
		var sent: int = _push_data_from(b, parsed.content, parsed.state, to_process, output_port)
		if sent > 0:
			processed += to_process
	return processed



# --- UPDATE DISPLAYS ---
func _update_displays(buildings: Array[Node]) -> void:
	for b in buildings:
		b.update_display()


# --- UPGRADE ---
func upgrade_building(building: Node2D) -> bool:
	var upg: UpgradeComponent = building.definition.upgrade
	if upg == null:
		return false
	if building.upgrade_level >= upg.max_level:
		return false
	building.upgrade_level += 1
	print("[Upgrade] %s upgraded to level %d" % [building.definition.building_name, building.upgrade_level])
	return true


func get_upgrade_cost(building: Node2D) -> int:
	var upg: UpgradeComponent = building.definition.upgrade
	if upg == null or building.upgrade_level >= upg.max_level:
		return -1
	return upg.costs[building.upgrade_level] if building.upgrade_level < upg.costs.size() else 0


# --- BUILDING EVENTS ---
func _on_building_placed(_building: Node2D, _cell: Vector2i) -> void:
	pass


func _on_building_removed(_building: Node2D, _cell: Vector2i) -> void:
	pass
