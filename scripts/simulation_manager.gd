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
var source_manager: Node = null
var sound_manager: Node = null
var connection_flow_data: Dictionary = {}  # conn_index → [{content, state, amount}]
var connection_stalled: Dictionary = {}  # conn_idx → true if stalled
var connection_last_flow: Dictionary = {}  # conn_idx → last known flow data for stalled visuals
var _splitter_next_port: Dictionary = {}  # building instance_id → next output port index

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
	# Save current flow as last-known before clearing (for stalled particle visuals)
	for _fi in connection_flow_data:
		if not connection_flow_data[_fi].is_empty():
			connection_last_flow[_fi] = connection_flow_data[_fi].duplicate(true)
	# Reset work flags and flow tracking
	connection_flow_data.clear()
	for b in buildings:
		b.is_working = false
	_update_generation(buildings)
	_update_storage_forward(buildings)
	_update_processing(buildings)
	_update_status_reasons(buildings)
	_update_stall_tracking()
	_update_displays(buildings)
	tick_completed.emit(_tick_count)


# --- STALL TRACKING (back-pressure visual) ---
func _update_stall_tracking() -> void:
	if connection_manager == null:
		return
	var conns: Array[Dictionary] = connection_manager.get_connections()
	if conns.is_empty():
		connection_stalled.clear()
		return

	connection_stalled.clear()

	# Pass 1: Direct stalls — target can't accept data
	for i in range(conns.size()):
		var conn: Dictionary = conns[i]
		var from_b: Node2D = conn.from_building
		var to_b: Node2D = conn.to_building
		if not is_instance_valid(from_b) or not is_instance_valid(to_b):
			connection_stalled[i] = true
			continue
		if from_b.has_method("is_active") and not from_b.is_active():
			continue
		if to_b.has_method("can_accept_data") and not to_b.can_accept_data(1):
			connection_stalled[i] = true

	# Pass 2-4: Back-pressure propagation (cascade upstream)
	for _pass in range(3):
		var newly_stalled: Dictionary = {}
		var checked_buildings: Dictionary = {}
		for i in range(conns.size()):
			var from_b: Node2D = conns[i].from_building
			if not is_instance_valid(from_b):
				continue
			if checked_buildings.has(from_b):
				continue
			checked_buildings[from_b] = true
			# Check if ALL outputs of this building are stalled
			var has_output: bool = false
			var all_blocked: bool = true
			for j in range(conns.size()):
				if conns[j].from_building == from_b:
					has_output = true
					if not connection_stalled.has(j) and not newly_stalled.has(j):
						all_blocked = false
						break
			if has_output and all_blocked:
				# Mark all INPUT connections to this building as stalled
				for j in range(conns.size()):
					if conns[j].to_building == from_b and not connection_stalled.has(j):
						newly_stalled[j] = true
		if newly_stalled.is_empty():
			break
		connection_stalled.merge(newly_stalled)


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
		return DataEnums.DataState.PUBLIC
	var roll: float = randf()
	var cumulative: float = 0.0
	for state_id in weights:
		cumulative += weights[state_id]
		if roll <= cumulative:
			return int(state_id)
	return DataEnums.DataState.PUBLIC


func _roll_tier(state: int, enc_max: int, cor_max: int) -> int:
	match state:
		DataEnums.DataState.ENCRYPTED:
			return randi_range(1, maxi(1, enc_max)) if enc_max > 0 else 1
		DataEnums.DataState.CORRUPTED:
			return randi_range(1, maxi(1, cor_max)) if cor_max > 0 else 1
		DataEnums.DataState.MALWARE:
			return 1
	return 0


# --- DISCOVERY ---
func _check_discovery(content: int, state: int) -> void:
	if not discovered_content.get(content, false):
		discovered_content[content] = true
		content_discovered.emit(content)
		print("[Discovery] New content discovered: %s" % DataEnums.content_name(content))
	if not discovered_states.get(state, false):
		discovered_states[state] = true
		state_discovered.emit(state)
		print("[Discovery] New state discovered: %s" % DataEnums.state_name(state))


# --- DATA PUSH ---
func _push_data_from(source: Node2D, content: int, state: int, amount: int, from_port: String = "", tier: int = 0, tags: int = 0) -> int:
	var conns: Array[Dictionary] = connection_manager.get_connections()
	var targets: Array[Dictionary] = []
	for conn in conns:
		if conn.from_building == source:
			if from_port == "" or conn.from_port == from_port:
				targets.append(conn)
	if targets.is_empty():
		return 0
	var key: String = DataEnums.make_key(content, state, tier, tags)
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
		if target.can_accept_data(to_send, state, content):
			# Port Purity: record cable data type + check at push time
			if target.definition.category == "terminal":
				var port: String = conn.to_port
				if target.blocked_ports.has(port):
					continue
				# Record this data type on the cable
				if not target.port_carried_types.has(port):
					target.port_carried_types[port] = {}
				var type_key: String = "%d_%d" % [content, state]
				target.port_carried_types[port][type_key] = true
				# Check purity: if ANY recorded type doesn't match gig → block
				if target.purity_checker.is_valid():
					var contaminated := false
					for tk in target.port_carried_types[port]:
						var parts: PackedStringArray = tk.split("_")
						if not target.purity_checker.call(int(parts[0]), int(parts[1])):
							contaminated = true
							break
					if contaminated:
						target.blocked_ports[port] = true
						print("[PortPurity] CT port '%s' blocked — cable carries non-matching data" % port)
						continue
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


# --- DATA GENERATION (Sources) ---
func _update_generation(_buildings: Array[Node]) -> void:
	if source_manager == null or connection_manager == null:
		return
	var conns: Array[Dictionary] = connection_manager.get_connections()
	for source in source_manager.get_discovered_sources():
		var src_def: DataSourceDefinition = source.definition
		var amount: int = int(src_def.generation_rate)
		# Each connected port generates independently at full rate
		for port in source.output_ports:
			var has_connection: bool = false
			for conn in conns:
				if conn.from_building == source and conn.from_port == port:
					has_connection = true
					break
			if not has_connection:
				continue
			for _i in range(amount):
				var content: int = _roll_content(src_def.content_weights)
				var state: int = _roll_state(src_def.state_weights)
				var tier: int = _roll_tier(state, src_def.encrypted_max_tier, src_def.corrupted_max_tier)
				_check_discovery(content, state)
				_push_data_from(source, content, state, 1, port, tier)


# --- STORAGE FORWARD ---
func _update_storage_forward(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.definition.storage == null or not b.is_active():
			continue
		if b.definition.processor != null or b.definition.splitter != null or b.definition.merger != null \
				or b.definition.producer != null or b.definition.dual_input != null \
				or b.definition.compiler != null or b.definition.classifier != null:
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
			if DataEnums.is_packet(key):
				continue
			var parsed: Dictionary = DataEnums.parse_key(key)
			var pushed: int = _push_data_from(b, parsed.content, parsed.state, mini(available, max_forward - sent), "", parsed.tier, parsed.tags)
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
		if b.definition.compiler != null:
			var max_process: int = int(b.get_effective_value("processing_rate"))
			processed = _process_compiler(b, max_process)
		elif b.definition.dual_input != null:
			var max_process: int = int(b.get_effective_value("processing_rate"))
			processed = _process_dual_input(b, max_process)
		elif b.definition.producer != null:
			var max_process: int = int(b.get_effective_value("processing_rate"))
			processed = _process_producer(b, max_process)
		elif b.definition.classifier != null:
			processed = _process_classifier(b, int(b.get_effective_value("processing_rate")))
		elif b.definition.splitter != null:
			processed = _process_splitter(b, int(b.definition.splitter.throughput_rate))
		elif b.definition.merger != null:
			processed = _process_merger(b, int(b.definition.merger.throughput_rate))
		elif b.definition.processor != null:
			var proc: ProcessorComponent = b.definition.processor
			var max_process: int = int(b.get_effective_value("processing_rate"))
			match proc.rule:
				"separator":
					processed = _process_separator(b, proc, max_process)
				"trash":
					processed = _process_trash(b)
		else:
			continue
		if processed > 0:
			b.is_working = true
		# Back-pressure: process functions now subtract sent amounts from stored_data.
		# Only clean up zero/negative entries — undelivered data stays for next tick.
		var _keys_to_remove: Array = []
		for k in b.stored_data:
			if b.stored_data[k] <= 0:
				_keys_to_remove.append(k)
		for k in _keys_to_remove:
			b.stored_data.erase(k)


func _process_classifier(b: Node2D, max_process: int) -> int:
	var processed: int = 0
	var output_ports: Array[String] = b.definition.output_ports
	if output_ports.size() < 2:
		return 0
	var primary_port: String = output_ports[0]   # right — selected content
	var secondary_port: String = output_ports[1]  # bottom — everything else
	# Both output ports must have connections — forces player to route rejected data
	if not _has_output_connection(b, primary_port) or not _has_output_connection(b, secondary_port):
		return 0
	var filter_content: int = b.classifier_filter_content
	for key in b.stored_data.keys():
		if processed >= max_process:
			break
		var available: int = b.stored_data.get(key, 0)
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		var to_process: int = mini(available, max_process - processed)
		var target_port: String = primary_port if parsed.content == filter_content else secondary_port
		var sent: int = _push_data_from(b, parsed.content, parsed.state, to_process, target_port, parsed.tier, parsed.tags)
		if sent > 0:
			b.stored_data[key] -= sent
			processed += sent
	return processed


func _process_producer(b: Node2D, max_process: int) -> int:
	var prod: ProducerComponent = b.definition.producer
	var selected: int = b.selected_tier
	var input_key: String = DataEnums.make_key(prod.input_content, prod.input_state)
	var available: int = b.stored_data.get(input_key, 0)
	if available <= 0:
		return 0
	var productions: int = mini(available / prod.consume_amount, max_process)
	if productions <= 0:
		return 0
	# Check tier-based extra content requirements
	if selected >= 2 and prod.tier2_extra_content >= 0:
		var extra2_key: String = DataEnums.make_key(prod.tier2_extra_content, prod.input_state)
		var extra2_avail: int = b.stored_data.get(extra2_key, 0)
		productions = mini(productions, extra2_avail / prod.tier2_extra_amount)
	if selected >= 3 and prod.tier3_extra_content >= 0:
		var extra3_key: String = DataEnums.make_key(prod.tier3_extra_content, prod.input_state)
		var extra3_avail: int = b.stored_data.get(extra3_key, 0)
		productions = mini(productions, extra3_avail / prod.tier3_extra_amount)
	if productions <= 0:
		return 0
	# Try to push output FIRST, then consume only what was delivered
	var sent: int = 0
	for i in range(productions):
		sent += _push_data_from(b, prod.output_content, prod.output_state, 1, "", selected)
	if sent <= 0:
		return 0
	# Consume base input proportional to actual output
	var consumed: int = sent * prod.consume_amount
	b.stored_data[input_key] -= consumed
	# Consume extra inputs proportional to actual output
	if selected >= 2 and prod.tier2_extra_content >= 0:
		var extra2_key: String = DataEnums.make_key(prod.tier2_extra_content, prod.input_state)
		b.stored_data[extra2_key] -= sent * prod.tier2_extra_amount
	if selected >= 3 and prod.tier3_extra_content >= 0:
		var extra3_key: String = DataEnums.make_key(prod.tier3_extra_content, prod.input_state)
		b.stored_data[extra3_key] -= sent * prod.tier3_extra_amount
	var tier_label: String = "T%d " % selected if selected > 0 else ""
	print("[Producer] %s: %d MB consumed → %d %sKey produced" % [
		b.definition.building_name, consumed,
		sent, tier_label])
	return consumed


func _process_dual_input(b: Node2D, max_process: int) -> int:
	var dual: DualInputComponent = b.definition.dual_input
	var processed: int = 0
	var fuel_consumed: Dictionary = {}  # fuel_key → amount consumed

	if dual.fuel_matches_content:
		# RECOVERER MODE: fuel = same content + Public state + tier 0 + tags 0
		processed = _process_dual_input_fuel_mode(b, dual, max_process, fuel_consumed)
	else:
		# KEY MODE (Decryptor/Encryptor): fuel = static key_content type
		processed = _process_dual_input_key_mode(b, dual, max_process, fuel_consumed)

	# Consume fuel
	for fuel_key in fuel_consumed:
		b.stored_data[fuel_key] -= fuel_consumed[fuel_key]
	return processed


func _process_dual_input_key_mode(b: Node2D, dual: DualInputComponent, max_process: int, fuel_consumed: Dictionary) -> int:
	var processed: int = 0
	for key in b.stored_data.keys():
		if processed >= max_process:
			break
		var available: int = b.stored_data[key]
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		if parsed.content == dual.key_content:
			continue
		if not dual.primary_input_states.is_empty() and parsed.state not in dual.primary_input_states:
			continue
		# Match Key tier to data tier (min T1)
		var tier: int = parsed.tier
		var key_tier: int = maxi(tier, 1)
		var key_key: String = DataEnums.make_key(dual.key_content, DataEnums.DataState.PUBLIC, key_tier, 0)
		var keys_available: int = b.stored_data.get(key_key, 0) - fuel_consumed.get(key_key, 0)
		if keys_available <= 0:
			continue
		var actual_key_cost: int = dual.key_cost
		if tier > 0 and tier <= dual.tier_key_costs.size():
			actual_key_cost = dual.tier_key_costs[tier - 1]
		var to_process: int = mini(available, max_process - processed)
		var keys_needed: int = to_process * actual_key_cost
		if keys_needed > keys_available:
			to_process = keys_available / actual_key_cost
		if to_process <= 0:
			continue
		var out_tags: int = parsed.tags | dual.output_tag
		var sent: int = _push_data_from(b, parsed.content, dual.output_state, to_process, "", tier, out_tags)
		if sent > 0:
			b.stored_data[key] -= sent
			processed += sent
			fuel_consumed[key_key] = fuel_consumed.get(key_key, 0) + sent * actual_key_cost
			_spawn_floating_text(b, "+%d %s" % [sent, DataEnums.tags_label(out_tags)], Color("#44ff88"))
			if sound_manager:
				sound_manager.play_process_event(b.definition.visual_type)
			print("[DualInput] %s: %d MB → %s (-%d T%d Key)" % [
				b.definition.building_name, sent,
				DataEnums.data_label(parsed.content, dual.output_state, tier, out_tags),
				sent * actual_key_cost, key_tier])
	return processed


func _process_dual_input_fuel_mode(b: Node2D, dual: DualInputComponent, max_process: int, fuel_consumed: Dictionary) -> int:
	# Recoverer: fuel must be same content, tier-based tags required
	var processed: int = 0
	for key in b.stored_data.keys():
		if processed >= max_process:
			break
		var available: int = b.stored_data[key]
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		if not dual.primary_input_states.is_empty() and parsed.state not in dual.primary_input_states:
			continue
		# Find fuel: same content, Public, tier 0, tags based on corrupted tier
		var required_tags: int = 0
		var tier: int = parsed.tier
		if tier > 0 and tier <= dual.required_fuel_tags.size():
			required_tags = dual.required_fuel_tags[tier - 1]
		var fuel_key: String = DataEnums.make_key(parsed.content, DataEnums.DataState.PUBLIC, 0, required_tags)
		var fuel_available: int = b.stored_data.get(fuel_key, 0) - fuel_consumed.get(fuel_key, 0)
		if fuel_available <= 0:
			continue
		var actual_fuel_cost: int = dual.key_cost
		if tier > 0 and tier <= dual.tier_key_costs.size():
			actual_fuel_cost = dual.tier_key_costs[tier - 1]
		var to_process: int = mini(available, max_process - processed)
		var fuel_needed: int = to_process * actual_fuel_cost
		if fuel_needed > fuel_available:
			to_process = fuel_available / actual_fuel_cost
		if to_process <= 0:
			continue
		var out_tags: int = parsed.tags | dual.output_tag
		var sent: int = _push_data_from(b, parsed.content, dual.output_state, to_process, "", tier, out_tags)
		if sent > 0:
			b.stored_data[key] -= sent
			processed += sent
			fuel_consumed[fuel_key] = fuel_consumed.get(fuel_key, 0) + sent * actual_fuel_cost
			_spawn_floating_text(b, "+%d %s" % [sent, DataEnums.tags_label(out_tags)], Color("#44ff88"))
			if sound_manager:
				sound_manager.play_process_event(b.definition.visual_type)
			print("[DualInput] %s: %d MB → %s (-%d fuel)" % [
				b.definition.building_name, sent,
				DataEnums.data_label(parsed.content, dual.output_state, tier, out_tags),
				sent * actual_fuel_cost])
	return processed


func _process_compiler(b: Node2D, _max_process: int) -> int:
	# Collect stored data entries (any state/tags, excluding packet keys)
	var entries: Array[Dictionary] = []  # [{key, content, tags, amount}]
	for key in b.stored_data:
		if DataEnums.is_packet(key):
			continue
		var amount: int = b.stored_data[key]
		if amount <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		entries.append({"key": key, "content": parsed.content, "tags": parsed.tags, "amount": amount})
	if entries.size() < 2:
		return 0
	# Find first pair of DIFFERENT entries to combine (1:1 ratio)
	var crafted: int = 0
	for i in range(entries.size()):
		if crafted >= _max_process:
			break
		for j in range(i + 1, entries.size()):
			if crafted >= _max_process:
				break
			var a: Dictionary = entries[i]
			var bb: Dictionary = entries[j]
			if a.amount <= 0 or bb.amount <= 0:
				continue
			var to_craft: int = mini(mini(a.amount, bb.amount), _max_process - crafted)
			if to_craft <= 0:
				continue
			# Create packet and push to targets FIRST
			var pkt_key: String = DataEnums.make_packet_key(a.content, a.tags, bb.content, bb.tags)
			var sent: int = _push_packet_from(b, pkt_key, to_craft)
			if sent <= 0:
				continue
			# Only consume inputs proportional to actual output
			b.stored_data[a.key] -= sent
			b.stored_data[bb.key] -= sent
			a.amount -= sent
			bb.amount -= sent
			crafted += sent
			_spawn_floating_text(b, "+%d Packet" % sent, Color("#44ff88"))
			if sound_manager:
				sound_manager.play_process_event("compiler")
			print("[Compiler] %d packet: %s" % [sent, DataEnums.packet_label(pkt_key)])
	return crafted


func _push_packet_from(source: Node2D, pkt_key: String, amount: int) -> int:
	var conns: Array[Dictionary] = connection_manager.get_connections()
	var targets: Array[Dictionary] = []
	for conn in conns:
		if conn.from_building == source:
			targets.append(conn)
	if targets.is_empty():
		return 0
	var per_target: int = maxi(1, amount / targets.size())
	var total_sent: int = 0
	for conn in targets:
		var target: Node2D = conn.to_building
		if not target.has_method("can_accept_data"):
			continue
		var to_send: int = mini(per_target, amount)
		if to_send <= 0:
			break
		# Port Purity: skip blocked CT ports
		if target.blocked_ports.has(conn.to_port):
			continue
		target.stored_data[pkt_key] = target.stored_data.get(pkt_key, 0) + to_send
		amount -= to_send
		total_sent += to_send
		# Track flow data for particle visuals
		var conn_idx: int = conns.find(conn)
		if conn_idx >= 0:
			if not connection_flow_data.has(conn_idx):
				connection_flow_data[conn_idx] = []
			connection_flow_data[conn_idx].append({
				"content": -1, "state": DataEnums.DataState.PUBLIC,
				"amount": to_send, "tier": 0, "tags": 0
			})
	return total_sent


func _process_separator(b: Node2D, proc: ProcessorComponent, max_process: int) -> int:
	var primary_port: String = b.definition.output_ports[0] if b.definition.output_ports.size() > 0 else ""
	var secondary_port: String = b.definition.output_ports[1] if b.definition.output_ports.size() > 1 else ""
	# Both output ports must have connections — forces player to route rejected data
	if primary_port == "" or secondary_port == "" or \
			not _has_output_connection(b, primary_port) or not _has_output_connection(b, secondary_port):
		return 0
	var processed: int = 0
	var mode: String = proc.separator_mode
	for key in b.stored_data.keys():
		if processed >= max_process:
			break
		var available: int = b.stored_data.get(key, 0)
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		var to_process: int = mini(available, max_process - processed)
		# Route: matching value → primary (right), rest → secondary (bottom)
		var matches: bool
		if mode == "content":
			matches = (parsed.content == b.separator_filter_value)
		else:
			matches = (parsed.state == b.separator_filter_value)
		var target_port: String = primary_port if matches else secondary_port
		if target_port == "":
			continue
		var sent: int = _push_data_from(b, parsed.content, parsed.state, to_process, target_port, parsed.tier, parsed.tags)
		if sent > 0:
			b.stored_data[key] -= sent
			processed += sent
	return processed



func _process_trash(b: Node2D) -> int:
	var total: int = b.get_total_stored_raw()
	if total > 0:
		b.stored_data.clear()
	return total


func _process_splitter(b: Node2D, max_process: int) -> int:
	var processed: int = 0
	var output_ports: Array[String] = b.definition.output_ports
	var port_count: int = output_ports.size()
	if port_count == 0:
		return 0
	var bid: int = b.get_instance_id()
	var next_idx: int = _splitter_next_port.get(bid, 0) % port_count
	for key in b.stored_data.keys():
		if processed >= max_process:
			break
		var available: int = b.stored_data.get(key, 0)
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		var to_process: int = mini(available, max_process - processed)
		# Round-robin: distribute one at a time, alternating ports
		var sent_total: int = 0
		for _unit in range(to_process):
			var port: String = output_ports[next_idx]
			var sent: int = _push_data_from(b, parsed.content, parsed.state, 1, port, parsed.tier, parsed.tags)
			if sent > 0:
				sent_total += 1
				next_idx = (next_idx + 1) % port_count
			else:
				# This port blocked — try next port once
				var alt_idx: int = (next_idx + 1) % port_count
				var alt_port: String = output_ports[alt_idx]
				var alt_sent: int = _push_data_from(b, parsed.content, parsed.state, 1, alt_port, parsed.tier, parsed.tags)
				if alt_sent > 0:
					sent_total += 1
					next_idx = (alt_idx + 1) % port_count
				else:
					break  # All ports blocked
		if sent_total > 0:
			b.stored_data[key] -= sent_total
			processed += sent_total
	_splitter_next_port[bid] = next_idx
	return processed


func _process_merger(b: Node2D, max_process: int) -> int:
	var processed: int = 0
	var output_port: String = b.definition.output_ports[0] if b.definition.output_ports.size() > 0 else ""
	if output_port == "":
		return 0
	for key in b.stored_data.keys():
		if processed >= max_process:
			break
		var available: int = b.stored_data.get(key, 0)
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		var to_process: int = mini(available, max_process - processed)
		var sent: int = _push_data_from(b, parsed.content, parsed.state, to_process, output_port, parsed.tier, parsed.tags)
		if sent > 0:
			b.stored_data[key] -= sent
			processed += sent
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


# --- EVENT FEEDBACK ---
func _spawn_floating_text(building: Node2D, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.add_theme_font_size_override("font_size", 13)

	var cx: float = building.definition.grid_size.x * TILE_SIZE / 2.0
	lbl.position = Vector2(cx - 28, -6.0)
	lbl.pivot_offset = Vector2(28, 6)
	lbl.scale = Vector2(0.4, 0.4)
	building.add_child(lbl)

	var tw := building.create_tween().set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 32.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.chain().tween_callback(lbl.queue_free)


func _add_camera_trauma(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(amount)


# --- BUILDING EVENTS ---
func _on_building_placed(building: Node2D, _cell: Vector2i) -> void:
	if building.has_method("play_place_animation"):
		building.play_place_animation()
	_add_camera_trauma(0.15)


func _on_building_removed(_building: Node2D, _cell: Vector2i) -> void:
	_add_camera_trauma(0.1)


# --- STATUS REASONS (root cause feedback for idle buildings) ---
func _update_status_reasons(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.is_working or b.definition == null:
			b.status_reason = ""
			continue
		# Trash / Contract Terminal — no reason needed
		if b.definition.visual_type == "terminal":
			b.status_reason = ""
			continue
		if b.definition.processor != null and b.definition.processor.rule == "trash":
			b.status_reason = ""
			continue
		# No data at all
		if b.get_total_stored_raw() <= 0:
			b.status_reason = "No input"
			continue
		# Compiler
		if b.definition.compiler != null:
			var types: int = 0
			for key in b.stored_data:
				if not DataEnums.is_packet(key) and b.stored_data[key] > 0:
					types += 1
			b.status_reason = "Need 2+ types" if types < 2 else "Output blocked"
			continue
		# Dual input (Decryptor/Encryptor/Recoverer)
		if b.definition.dual_input != null:
			var dual: DualInputComponent = b.definition.dual_input
			var has_primary: bool = _reason_has_primary(b, dual)
			if not has_primary:
				b.status_reason = "No input"
			elif dual.fuel_matches_content:
				b.status_reason = "Waiting for fuel" if not _reason_has_fuel(b, dual) else "Output blocked"
			else:
				b.status_reason = "Waiting for Key" if not _reason_has_keys(b, dual) else "Output blocked"
			continue
		# Producer (Research Lab)
		if b.definition.producer != null:
			var prod: ProducerComponent = b.definition.producer
			var input_key: String = DataEnums.make_key(prod.input_content, prod.input_state)
			if b.stored_data.get(input_key, 0) <= 0:
				b.status_reason = "No %s data" % DataEnums.content_name(prod.input_content)
			else:
				var missing: String = ""
				if b.selected_tier >= 2 and prod.tier2_extra_content >= 0:
					var ek: String = DataEnums.make_key(prod.tier2_extra_content, prod.input_state)
					if b.stored_data.get(ek, 0) <= 0:
						missing = DataEnums.content_name(prod.tier2_extra_content)
				if missing == "" and b.selected_tier >= 3 and prod.tier3_extra_content >= 0:
					var ek: String = DataEnums.make_key(prod.tier3_extra_content, prod.input_state)
					if b.stored_data.get(ek, 0) <= 0:
						missing = DataEnums.content_name(prod.tier3_extra_content)
				b.status_reason = ("Need %s" % missing) if missing != "" else "Output blocked"
			continue
		# Classifier — check both output connections
		if b.definition.classifier != null:
			if not _all_outputs_connected(b):
				b.status_reason = "Connect all outputs"
			else:
				b.status_reason = "Output blocked"
			continue
		# Separator — check both output connections
		if b.definition.processor != null and b.definition.processor.rule == "separator":
			if not _all_outputs_connected(b):
				b.status_reason = "Connect all outputs"
			else:
				b.status_reason = "Output blocked"
			continue
		# All others (Splitter, Merger, Bridge)
		b.status_reason = "Output blocked"


func _reason_has_primary(b: Node2D, dual: DualInputComponent) -> bool:
	for key in b.stored_data:
		if b.stored_data[key] <= 0:
			continue
		if DataEnums.is_packet(key):
			continue
		var p: Dictionary = DataEnums.parse_key(key)
		if p.content == dual.key_content:
			continue
		if dual.fuel_matches_content and p.state == DataEnums.DataState.PUBLIC and p.tier == 0:
			continue
		if not dual.primary_input_states.is_empty() and p.state not in dual.primary_input_states:
			continue
		return true
	return false


func _reason_has_keys(b: Node2D, dual: DualInputComponent) -> bool:
	for key in b.stored_data:
		if b.stored_data[key] <= 0:
			continue
		if DataEnums.is_packet(key):
			continue
		var p: Dictionary = DataEnums.parse_key(key)
		if p.content == dual.key_content:
			return true
	return false


func _reason_has_fuel(b: Node2D, dual: DualInputComponent) -> bool:
	for key in b.stored_data:
		if b.stored_data[key] <= 0:
			continue
		if DataEnums.is_packet(key):
			continue
		var p: Dictionary = DataEnums.parse_key(key)
		if p.state == DataEnums.DataState.PUBLIC and p.content != dual.key_content:
			return true
	return false


# --- CONNECTION HELPERS ---

func _has_output_connection(building: Node2D, port: String) -> bool:
	var conns: Array[Dictionary] = connection_manager.get_connections()
	for conn in conns:
		if conn.from_building == building and conn.from_port == port:
			return true
	return false


func _all_outputs_connected(b: Node2D) -> bool:
	for port in b.definition.output_ports:
		if not _has_output_connection(b, port):
			return false
	return true
