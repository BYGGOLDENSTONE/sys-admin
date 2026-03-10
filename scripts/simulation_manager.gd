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
var sound_manager: Node = null
var connection_flow_data: Dictionary = {}  # conn_index → [{content, state, amount}]
var connection_stalled: Dictionary = {}  # conn_idx → true if stalled
var connection_last_flow: Dictionary = {}  # conn_idx → last known flow data for stalled visuals

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
		return DataEnums.DataState.CLEAN
	var roll: float = randf()
	var cumulative: float = 0.0
	for state_id in weights:
		cumulative += weights[state_id]
		if roll <= cumulative:
			return int(state_id)
	return DataEnums.DataState.CLEAN


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
func _push_data_from(source: Node2D, content: int, state: int, amount: int, from_port: String = "", tier: int = 0) -> int:
	var conns: Array[Dictionary] = connection_manager.get_connections()
	var targets: Array[Dictionary] = []
	for conn in conns:
		if conn.from_building == source:
			if from_port == "" or conn.from_port == from_port:
				targets.append(conn)
	if targets.is_empty():
		return 0
	var key: String = DataEnums.make_key(content, state, tier)
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
		# Get tier limits from linked source
		var src_def = b.linked_source.definition if b.linked_source else null
		var enc_max: int = src_def.encrypted_max_tier if src_def else 1
		var cor_max: int = src_def.corrupted_max_tier if src_def else 1
		var total_pushed: int = 0
		for i in range(amount):
			var content: int = _roll_content(c_weights)
			var state: int = _roll_state(s_weights)
			var tier: int = _roll_tier(state, enc_max, cor_max)
			_check_discovery(content, state)
			total_pushed += _push_data_from(b, content, state, 1, "", tier)
		if total_pushed > 0:
			b.is_working = true


# --- STORAGE FORWARD ---
func _update_storage_forward(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.definition.storage == null or not b.is_active():
			continue
		if b.definition.processor != null or b.definition.splitter != null or b.definition.merger != null \
				or b.definition.producer != null or b.definition.dual_input != null \
				or b.definition.compiler != null:
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
			var pushed: int = _push_data_from(b, parsed.content, parsed.state, mini(available, max_forward - sent), "", parsed.tier)
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
			processed = _process_classifier(b, int(b.definition.classifier.throughput_rate))
		elif b.definition.splitter != null:
			processed = _process_splitter(b, int(b.definition.splitter.throughput_rate))
		elif b.definition.merger != null:
			processed = _process_merger(b, int(b.definition.merger.throughput_rate))
		elif b.definition.probabilistic != null:
			var max_process: int = int(b.get_effective_value("processing_rate"))
			processed = _process_probabilistic(b, max_process)
		elif b.definition.processor != null:
			var proc: ProcessorComponent = b.definition.processor
			var max_process: int = int(b.get_effective_value("processing_rate"))
			match proc.rule:
				"separator":
					processed = _process_separator(b, proc, max_process)
				"quarantine":
					processed = _process_quarantine(b, proc, max_process)
		else:
			continue
		if processed > 0:
			b.is_working = true
		# Producer accumulates input — don't clear
		# Dual_input: clear processed data but keep keys
		# Compiler: keep unprocessed data (accumulates both inputs)
		if b.definition.producer != null:
			pass  # Keep all stored data (accumulates input)
		elif b.definition.compiler != null:
			pass  # Keep stored data (needs both inputs to accumulate)
		elif b.definition.dual_input != null:
			var key_key: String = DataEnums.make_key(b.definition.dual_input.key_content, DataEnums.DataState.CLEAN)
			var saved_keys: int = b.stored_data.get(key_key, 0)
			b.stored_data.clear()
			if saved_keys > 0:
				b.stored_data[key_key] = saved_keys
		else:
			b.stored_data.clear()


func _process_classifier(b: Node2D, max_process: int) -> int:
	var processed: int = 0
	var output_ports: Array[String] = b.definition.output_ports
	if output_ports.is_empty():
		return 0
	# Group stored data by content type
	var content_groups: Dictionary = {}  # content_id → [{key, amount}]
	for key in b.stored_data:
		var available: int = b.stored_data[key]
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		var cid: int = parsed.content
		if not content_groups.has(cid):
			content_groups[cid] = []
		content_groups[cid].append({"key": key, "content": cid, "state": parsed.state, "tier": parsed.tier, "amount": available})
	# Assign each content type to a port (round-robin by content id)
	var content_ids: Array = content_groups.keys()
	content_ids.sort()
	for i in range(content_ids.size()):
		if processed >= max_process:
			break
		var cid: int = content_ids[i]
		var port: String = output_ports[i % output_ports.size()]
		for entry in content_groups[cid]:
			if processed >= max_process:
				break
			var to_process: int = mini(entry.amount, max_process - processed)
			var sent: int = _push_data_from(b, entry.content, entry.state, to_process, port, entry.tier)
			if sent > 0:
				processed += sent
	return processed


func _process_probabilistic(b: Node2D, max_process: int) -> int:
	var prob: ProbabilisticComponent = b.definition.probabilistic
	var base_success: float = b.get_effective_value("success_rate")
	var output_ports: Array[String] = b.definition.output_ports
	var clean_port: String = output_ports[0] if output_ports.size() > 0 else ""
	var residue_port: String = prob.residue_port if prob.residue_port != "" else ""
	var processed: int = 0
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data[key]
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		if not prob.input_states.is_empty() and parsed.state not in prob.input_states:
			continue
		# Tier-based success rate
		var tier: int = parsed.tier
		var actual_success: float = base_success
		if tier > 0 and tier <= prob.tier_success_rates.size():
			actual_success = prob.tier_success_rates[tier - 1]
		var to_process: int = mini(available, max_process - processed)
		# Process each unit individually for probability
		var success_count: int = 0
		var fail_count: int = 0
		for _i in range(to_process):
			if randf() <= actual_success:
				success_count += 1
			else:
				fail_count += 1
		# Push successful recoveries (output is Clean, tier=0)
		if success_count > 0 and clean_port != "":
			_push_data_from(b, parsed.content, prob.output_state, success_count, clean_port)
		# Push residue (failed recoveries)
		if fail_count > 0 and residue_port != "":
			_push_data_from(b, parsed.content, DataEnums.DataState.RESIDUE, fail_count, residue_port)
		processed += to_process
		if success_count > 0 or fail_count > 0:
			var tier_label: String = " T%d" % tier if tier > 0 else ""
			print("[Recoverer] %d MB %s%s → %d Clean + %d Residue (%%%d)" % [
				to_process, DataEnums.content_name(parsed.content), tier_label,
				success_count, fail_count, int(actual_success * 100)])
	return processed


func _process_producer(b: Node2D, max_process: int) -> int:
	var prod: ProducerComponent = b.definition.producer
	var input_key: String = DataEnums.make_key(prod.input_content, prod.input_state)
	var available: int = b.stored_data.get(input_key, 0)
	if available <= 0:
		return 0
	var productions: int = mini(available / prod.consume_amount, max_process)
	if productions <= 0:
		return 0
	var consumed: int = productions * prod.consume_amount
	b.stored_data[input_key] -= consumed
	var sent: int = 0
	for i in range(productions):
		sent += _push_data_from(b, prod.output_content, prod.output_state, 1)
	if sent > 0:
		print("[Producer] %s: %d MB %s consumed → %d Key produced" % [
			b.definition.building_name, consumed,
			DataEnums.content_name(prod.input_content), sent])
	return consumed


func _process_dual_input(b: Node2D, max_process: int) -> int:
	var dual: DualInputComponent = b.definition.dual_input
	# Count available keys
	var key_key: String = DataEnums.make_key(dual.key_content, DataEnums.DataState.CLEAN)
	var keys_available: int = b.stored_data.get(key_key, 0)
	if keys_available <= 0:
		return 0
	var processed: int = 0
	var keys_used: int = 0
	for key in b.stored_data.keys():
		if processed >= max_process:
			break
		var available: int = b.stored_data[key]
		if available <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		# Skip key data — it's fuel, not processed
		if parsed.content == dual.key_content:
			continue
		# Only process matching input states
		if not dual.primary_input_states.is_empty() and parsed.state not in dual.primary_input_states:
			continue
		# Tier-based key cost
		var tier: int = parsed.tier
		var actual_key_cost: int = dual.key_cost
		if tier > 0 and tier <= dual.tier_key_costs.size():
			actual_key_cost = dual.tier_key_costs[tier - 1]
		var to_process: int = mini(available, max_process - processed)
		# Limit by available keys
		var keys_needed: int = to_process * actual_key_cost
		if keys_needed > keys_available - keys_used:
			to_process = (keys_available - keys_used) / actual_key_cost
		if to_process <= 0:
			break
		var sent: int = _push_data_from(b, parsed.content, dual.output_state, to_process)
		if sent > 0:
			processed += sent
			keys_used += sent * actual_key_cost
			var tier_label: String = " T%d" % tier if tier > 0 else ""
			_spawn_floating_text(b, "+%d Clean" % sent, Color("#44ff88"))
			if sound_manager:
				sound_manager.play_process_event("decryptor")
			print("[DualInput] %s: %d MB %s(%s%s) → %s (-%d Key)" % [
				b.definition.building_name, sent,
				DataEnums.content_name(parsed.content),
				DataEnums.state_name(parsed.state), tier_label,
				DataEnums.state_name(dual.output_state),
				sent * actual_key_cost])
	# Consume used keys
	if keys_used > 0:
		b.stored_data[key_key] -= keys_used
	return processed


func _process_compiler(b: Node2D, max_process: int) -> int:
	var comp: CompilerComponent = b.definition.compiler
	if comp.recipes.is_empty():
		return 0
	# Collect available Clean data by content type
	var available_by_content: Dictionary = {}  # content_id → amount
	for key in b.stored_data:
		var amount: int = b.stored_data[key]
		if amount <= 0:
			continue
		var parsed: Dictionary = DataEnums.parse_key(key)
		if parsed.state != DataEnums.DataState.CLEAN:
			continue
		available_by_content[parsed.content] = available_by_content.get(parsed.content, 0) + amount
	# Try each recipe and find one that matches
	var crafted: int = 0
	for recipe in comp.recipes:
		if crafted >= max_process:
			break
		var has_a: int = available_by_content.get(recipe.input_a_content, 0)
		var has_b: int = available_by_content.get(recipe.input_b_content, 0)
		if has_a < recipe.input_a_cost or has_b < recipe.input_b_cost:
			continue
		# How many can we craft?
		var max_from_a: int = has_a / recipe.input_a_cost
		var max_from_b: int = has_b / recipe.input_b_cost
		var to_craft: int = mini(mini(max_from_a, max_from_b), max_process - crafted)
		if to_craft <= 0:
			continue
		# Consume inputs
		var consumed_a: int = to_craft * recipe.input_a_cost
		var consumed_b: int = to_craft * recipe.input_b_cost
		var key_a: String = DataEnums.make_key(recipe.input_a_content, DataEnums.DataState.CLEAN)
		var key_b: String = DataEnums.make_key(recipe.input_b_content, DataEnums.DataState.CLEAN)
		b.stored_data[key_a] = b.stored_data.get(key_a, 0) - consumed_a
		b.stored_data[key_b] = b.stored_data.get(key_b, 0) - consumed_b
		available_by_content[recipe.input_a_content] -= consumed_a
		available_by_content[recipe.input_b_content] -= consumed_b
		# Produce refined output — store in global refined storage
		_add_refined_to_storage(recipe.output_refined, to_craft)
		crafted += to_craft
		_spawn_floating_text(b, "+%d %s" % [to_craft, DataEnums.refined_name(recipe.output_refined)], Color("#44ff88"))
		if sound_manager:
			sound_manager.play_process_event("compiler")
		print("[Compiler] %d x %s crafted (%d %s + %d %s consumed)" % [
			to_craft, DataEnums.refined_name(recipe.output_refined),
			consumed_a, DataEnums.content_name(recipe.input_a_content),
			consumed_b, DataEnums.content_name(recipe.input_b_content)])
	return crafted


func _add_refined_to_storage(refined_type: int, amount: int) -> void:
	# Add refined materials to all connected Storage buildings (or global pool)
	for child in building_container.get_children():
		if not child.has_method("is_active"):
			continue
		if child.definition != null and child.definition.storage != null:
			child.stored_refined[refined_type] = child.stored_refined.get(refined_type, 0) + amount
			return
	# Fallback: no storage found, log warning
	push_warning("[Compiler] No Storage building found for refined output!")


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
		var sent: int = _push_data_from(b, parsed.content, parsed.state, output_amount, target_port, parsed.tier)
		if sent > 0:
			_check_discovery(parsed.content, parsed.state)
			processed += to_process
	return processed



func _process_quarantine(b: Node2D, _proc: ProcessorComponent, _max_process: int) -> int:
	# Flush mode: count down timer, reject input, then purge
	if b.is_flushing:
		b.flush_timer -= _sim_timer.wait_time * speed_multiplier
		if b.flush_timer <= 0.0:
			var purged: int = b.get_total_stored_raw()
			b.stored_data.clear()
			b.is_flushing = false
			b.flush_timer = 0.0
			_spawn_floating_text(b, "PURGED %d MB" % purged, Color(1.0, 0.3, 0.4))
			_add_camera_trauma(0.15 + purged * 0.01)
			if sound_manager:
				sound_manager.play_process_event("quarantine")
			print("[Quarantine] Flush complete — %d MB purged" % purged)
		return 0
	# Accumulate mode: check if capacity reached → trigger flush
	var cap: int = int(b.get_effective_value("capacity")) if b.definition.storage else 50
	var stored: int = b.get_total_stored_raw()
	if stored >= cap:
		b.is_flushing = true
		b.flush_timer = b.FLUSH_DURATION
		_spawn_floating_text(b, "FLUSHING...", Color(1.0, 0.6, 0.2))
		print("[Quarantine] Capacity reached (%d/%d) — flush started (%.1fs)" % [stored, cap, b.FLUSH_DURATION])
		return 0
	# Not full yet — just accumulate (data already stored by _push_data)
	return 0


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
			var sent: int = _push_data_from(b, parsed.content, parsed.state, to_send, port, parsed.tier)
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
		var sent: int = _push_data_from(b, parsed.content, parsed.state, to_process, output_port, parsed.tier)
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
