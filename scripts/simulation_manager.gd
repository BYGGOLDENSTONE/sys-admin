extends Node

signal tick_completed(tick_count: int)
signal content_discovered(content: int)
signal state_discovered(state: int)
signal speed_changed(multiplier: int, paused: bool)

const TILE_SIZE: int = 64
const TRANSIT_GRIDS_PER_SEC: float = 3.0  ## Data transit speed: 3 grid cells per second

var _tick_count: int = 0
var speed_multiplier: int = 1
var is_paused: bool = false
var discovered_content: Dictionary = {0: true, 1: false, 2: false, 3: false, 4: false, 5: false}
var discovered_states: Dictionary = {0: true, 1: false, 2: false, 3: false}
var connection_manager: Node = null
var building_container: Node2D = null
var source_manager: Node = null
var sound_manager: Node = null
var connection_stalled: Dictionary = {}  # conn_idx → true if stalled
var _splitter_next_port: Dictionary = {}  # building instance_id → next output port index

@onready var _sim_timer: Timer = $SimTimer


func _ready() -> void:
	_sim_timer.timeout.connect(_on_sim_tick)
	print("[Simulation] Manager initialized — tick: %.1fs, transit speed: %.1f grids/s" % [_sim_timer.wait_time, TRANSIT_GRIDS_PER_SEC])


func _process(delta: float) -> void:
	if is_paused or connection_manager == null:
		return
	_advance_transit(delta)
	_deliver_arrived()


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
	# Reset work flags
	for b in buildings:
		b.is_working = false
	# 1. Deliver arrived transit items to target buildings
	_deliver_arrived()
	# 2. Normal simulation: generate → forward → process
	_update_generation(buildings)
	_update_storage_forward(buildings)
	_update_processing(buildings)
	# 4. Status, stall tracking, visuals
	_update_status_reasons(buildings)
	_update_stall_tracking()
	_update_displays(buildings)
	tick_completed.emit(_tick_count)


# --- TRANSIT SYSTEM ---
# Data travels along cables in real-time. Each connection dict stores a "transit" array.
# Transit item: {key, content, state, tier, tags, amount, t} where t goes from 0.0 (source) to 1.0 (destination).
# Items are ordered oldest-first: index 0 = closest to destination (highest t).

const TRANSIT_MIN_SPACING_GRIDS: float = 1.5  ## Minimum grid cells between transit items on a cable

func _advance_transit(delta: float) -> void:
	## Advance all in-flight transit items each frame for smooth visual movement.
	## If front item is stuck at destination (t >= 1.0), entire cable freezes.
	## Enforces minimum spacing so items don't overlap visually — each particle is trackable.
	var conns: Array[Dictionary] = connection_manager.get_connections()
	for conn in conns:
		if not conn.has("transit") or conn["transit"].is_empty():
			continue
		var transit: Array = conn["transit"]
		# If front item is stuck at destination, freeze entire cable
		if transit[0].t >= 1.0:
			continue
		var cable_grids: float = _get_cable_length_grids(conn)
		var t_advance: float = (TRANSIT_GRIDS_PER_SEC * float(speed_multiplier) * delta) / cable_grids
		var min_spacing: float = TRANSIT_MIN_SPACING_GRIDS / cable_grids
		# Advance front-to-back: each item can't get closer than min_spacing to the one ahead
		for i in range(transit.size()):
			var new_t: float = minf(transit[i].t + t_advance, 1.0)
			if i > 0:
				new_t = minf(new_t, transit[i - 1].t - min_spacing)
			transit[i].t = maxf(transit[i].t, new_t)  # Never move backwards


func _deliver_arrived() -> void:
	## Deliver transit items that reached destination (t >= 1.0).
	## Trash: instant destroy. Inline processors: rendezvous matching.
	## Storage buildings: partial delivery when target capacity is limited.
	var conns: Array[Dictionary] = connection_manager.get_connections()
	for conn in conns:
		if not conn.has("transit") or conn["transit"].is_empty():
			continue
		var transit: Array = conn["transit"]
		var target: Node2D = conn.to_building
		if not is_instance_valid(target) or not target.has_method("can_accept_data"):
			transit.clear()
			continue
		# Deliver front items that have arrived (t >= 1.0)
		while not transit.is_empty() and transit[0].t >= 1.0:
			var item: Dictionary = transit[0]
			# Real-time pass-through for routing buildings (preserves visual identity)
			if _try_passthrough(target, item, conns):
				transit.remove_at(0)
				continue
			# Routing buildings: if pass-through failed, stall (no storage fallback)
			if target.definition != null and (target.definition.classifier != null \
					or target.definition.splitter != null or target.definition.merger != null \
					or (target.definition.processor != null and target.definition.processor.rule == "separator")):
				break
			# Trash: instant destroy — no storage needed
			if target.definition != null and target.definition.processor != null \
					and target.definition.processor.rule == "trash":
				transit.remove_at(0)
				target.is_working = true
				continue
			# Inline processor (Decryptor/Encryptor/Recoverer): leave in transit for rendezvous
			if _is_inline_processor(target):
				break
			# Reserve capacity in dual-input buildings for secondary input (keys/fuel)
			if not _dual_input_can_accept(target, item):
				break  # Primary data stopped — reserve space for keys/fuel
			# Check if target has any room
			if not target.can_accept_data(1):
				break  # Target full — item stays, cable freezes
			# Calculate deliverable amount (partial delivery if needed)
			var deliver: int = item.amount
			if not target.can_accept_data(deliver):
				if target.definition != null and target.definition.storage != null:
					var room: int = int(target.get_effective_value("capacity")) - target.get_total_stored()
					deliver = clampi(room, 1, item.amount)
				else:
					deliver = 1
			# Deliver to target building
			target.stored_data[item.key] = target.stored_data.get(item.key, 0) + deliver
			item.amount -= deliver
			if item.amount <= 0:
				transit.remove_at(0)
			else:
				break  # Remaining amount stays in transit for next tick
	# Storageless inline processing: match primary + secondary inputs on cables
	_process_inline_rendezvous(conns)


func _dual_input_can_accept(target: Node2D, item: Dictionary) -> bool:
	## For dual-input buildings (Decryptor, Encryptor, Recoverer), reserve capacity
	## for secondary input (keys/fuel). Primary data stops at 75% to prevent deadlock.
	if target.definition == null or target.definition.dual_input == null:
		return true  # Not a dual-input building — no restriction
	var dual: DualInputComponent = target.definition.dual_input
	var is_secondary: bool
	if dual.fuel_matches_content:
		# Recoverer: fuel = Public state, tier 0
		is_secondary = (item.state == DataEnums.DataState.PUBLIC and item.tier == 0)
	else:
		# Decryptor/Encryptor: fuel = Key content type
		is_secondary = (item.content == dual.key_content)
	if is_secondary:
		return true  # Secondary input always allowed up to full capacity
	var cap: int = int(target.get_effective_value("capacity"))
	var reserve: int = maxi(3, cap / 4)
	return target.get_total_stored() < cap - reserve


func _try_passthrough(building: Node2D, item: Dictionary, all_conns: Array[Dictionary]) -> bool:
	## For routing buildings (Separator, Classifier, Splitter, Merger),
	## immediately forward the transit item to the correct output cable.
	## Preserves item identity — what goes in comes out with same key/content/state.
	## Returns true if item was forwarded, false to fall back to normal storage delivery.
	var output_port: String = _get_passthrough_port(building, item)
	if output_port == "":
		return false
	# Find a non-stalled output connection for this port
	for out_conn in all_conns:
		if out_conn.from_building != building or out_conn.from_port != output_port:
			continue
		if _is_transit_stalled(out_conn):
			continue
		# Forward the transit item to output cable at t=0
		if not out_conn.has("transit"):
			out_conn["transit"] = []
		out_conn["transit"].append({
			"key": item.key, "content": item.content, "state": item.state,
			"tier": item.tier, "tags": item.tags, "amount": item.amount, "t": 0.0
		})
		building.is_working = true
		return true
	return false  # All output cables stalled or no connection found


func _get_passthrough_port(building: Node2D, item: Dictionary) -> String:
	## Determine output port for real-time pass-through routing.
	## Returns "" if building is not a routing type or required ports aren't connected.
	var def = building.definition
	if def == null:
		return ""
	# Classifier: route by content
	if def.classifier != null:
		var ports: Array[String] = def.output_ports
		if ports.size() < 2:
			return ""
		if not _has_output_connection(building, ports[0]) or not _has_output_connection(building, ports[1]):
			return ""
		return ports[0] if item.content == building.classifier_filter_content else ports[1]
	# Separator: route by content or state
	if def.processor != null and def.processor.rule == "separator":
		var ports: Array[String] = def.output_ports
		if ports.size() < 2:
			return ""
		if not _has_output_connection(building, ports[0]) or not _has_output_connection(building, ports[1]):
			return ""
		var mode: String = def.processor.separator_mode
		var matches: bool
		if mode == "content":
			matches = (item.content == building.separator_filter_value)
		else:
			matches = (item.state == building.separator_filter_value)
		return ports[0] if matches else ports[1]
	# Splitter: round-robin
	if def.splitter != null:
		var port_count: int = def.output_ports.size()
		if port_count == 0:
			return ""
		var bid: int = building.get_instance_id()
		var next_idx: int = _splitter_next_port.get(bid, 0) % port_count
		var port: String = def.output_ports[next_idx]
		_splitter_next_port[bid] = (next_idx + 1) % port_count
		return port
	# Merger: single output
	if def.merger != null:
		return def.output_ports[0] if def.output_ports.size() > 0 else ""
	return ""  # Not a routing building


func _is_transit_stalled(conn: Dictionary) -> bool:
	## Returns true if cable has items waiting at destination (t >= 1.0).
	if not conn.has("transit") or conn["transit"].is_empty():
		return false
	return conn["transit"][0].t >= 1.0


# --- INLINE PROCESSING (storageless dual-input: Decryptor, Encryptor, Recoverer) ---

func _is_inline_processor(building: Node2D) -> bool:
	## Returns true for dual-input buildings that process via cable rendezvous (no storage).
	if building.definition == null:
		return false
	return building.definition.dual_input != null


func _process_inline_rendezvous(conns: Array[Dictionary]) -> void:
	## Try rendezvous matching for all inline buildings with arrived transit items.
	var checked: Dictionary = {}
	for conn in conns:
		var target: Node2D = conn.to_building
		if not is_instance_valid(target) or checked.has(target):
			continue
		if not _is_inline_processor(target):
			continue
		checked[target] = true
		_try_rendezvous(target, conns)


func _try_rendezvous(building: Node2D, conns: Array[Dictionary]) -> void:
	## Match primary + secondary inputs on cables for an inline dual-input building.
	## Both must have items arrived (t>=1.0). If matched, consume both and push output.
	var dual: DualInputComponent = building.definition.dual_input
	var max_process: int = int(building.get_effective_value("processing_rate"))
	var processed: int = 0

	for _attempt in range(max_process):
		var primary_conn: Dictionary = {}
		var secondary_conn: Dictionary = {}

		for conn in conns:
			if conn.to_building != building:
				continue
			if not conn.has("transit") or conn["transit"].is_empty():
				continue
			if conn["transit"][0].t < 1.0:
				continue
			var item: Dictionary = conn["transit"][0]
			if primary_conn.is_empty() and _is_inline_primary(dual, item):
				primary_conn = conn
			elif secondary_conn.is_empty() and _is_inline_secondary(dual, item):
				secondary_conn = conn

		if primary_conn.is_empty() or secondary_conn.is_empty():
			break

		var p_item: Dictionary = primary_conn["transit"][0]
		var s_item: Dictionary = secondary_conn["transit"][0]

		# Verify secondary matches primary (content/tier/tags)
		if not _inline_secondary_matches(dual, p_item, s_item):
			break

		# Calculate key/fuel cost
		var tier: int = p_item.tier
		var key_cost: int = dual.key_cost
		if tier > 0 and tier <= dual.tier_key_costs.size():
			key_cost = dual.tier_key_costs[tier - 1]
		if s_item.amount < key_cost:
			break

		# Push output to transit
		var out_tags: int = p_item.tags | dual.output_tag
		var sent: int = _push_data_from(building, p_item.content, dual.output_state, 1, "", tier, out_tags)
		if sent <= 0:
			break  # Output cable stalled

		# Consume primary
		p_item.amount -= 1
		if p_item.amount <= 0:
			primary_conn["transit"].remove_at(0)
		# Consume secondary
		s_item.amount -= key_cost
		if s_item.amount <= 0:
			secondary_conn["transit"].remove_at(0)

		processed += 1
		building.is_working = true
		_spawn_floating_text(building, "+%d %s" % [1, DataEnums.tags_label(out_tags)], Color("#44ff88"))
		if sound_manager:
			sound_manager.play_process_event(building.definition.visual_type)

	if processed > 0:
		var label: String = "Key" if not dual.fuel_matches_content else "fuel"
		print("[InlineProcess] %s: %d MB via rendezvous (-%d %s)" % [
			building.definition.building_name, processed, processed, label])


func _is_inline_primary(dual: DualInputComponent, item: Dictionary) -> bool:
	## Check if transit item is primary input for inline dual-input processing.
	if dual.fuel_matches_content:
		if item.state == DataEnums.DataState.PUBLIC and item.tier == 0:
			return false  # This is fuel, not primary
	else:
		if item.content == dual.key_content:
			return false  # This is a Key, not primary
	if not dual.primary_input_states.is_empty() and item.state not in dual.primary_input_states:
		return false
	return true


func _is_inline_secondary(dual: DualInputComponent, item: Dictionary) -> bool:
	## Check if transit item is secondary input (key/fuel) for inline processing.
	if dual.fuel_matches_content:
		return item.state == DataEnums.DataState.PUBLIC and item.tier == 0
	else:
		return item.content == dual.key_content


func _inline_secondary_matches(dual: DualInputComponent, primary: Dictionary, secondary: Dictionary) -> bool:
	## Verify that a specific secondary item matches the primary for processing.
	if dual.fuel_matches_content:
		# Recoverer: fuel must match primary content + required tags
		if secondary.content != primary.content:
			return false
		var required_tags: int = 0
		var tier: int = primary.tier
		if tier > 0 and tier <= dual.required_fuel_tags.size():
			required_tags = dual.required_fuel_tags[tier - 1]
		return secondary.tags == required_tags
	else:
		# Decryptor/Encryptor: key tier must match data tier (min T1)
		var key_tier: int = maxi(primary.tier, 1)
		return secondary.tier == key_tier


func _inline_input_status(building: Node2D, dual: DualInputComponent, check_primary: bool) -> int:
	## Returns 0=none, 1=in transit, 2=arrived (t>=1.0) for inline building inputs.
	var conns: Array[Dictionary] = connection_manager.get_connections()
	var best: int = 0
	for conn in conns:
		if conn.to_building != building:
			continue
		if not conn.has("transit") or conn["transit"].is_empty():
			continue
		for item in conn["transit"]:
			var matches: bool = _is_inline_primary(dual, item) if check_primary else _is_inline_secondary(dual, item)
			if matches:
				if item.t >= 1.0:
					return 2
				best = 1
	# Fallback: check stored_data (legacy saves)
	if building.get_total_stored() > 0:
		if check_primary and _reason_has_primary(building, dual):
			return 2
		elif not check_primary:
			if dual.fuel_matches_content and _reason_has_fuel(building, dual):
				return 2
			elif not dual.fuel_matches_content and _reason_has_keys(building, dual):
				return 2
	return best


func _get_cable_length_grids(conn: Dictionary) -> float:
	## Calculate cable length in grid cells from vertex path (Manhattan distance).
	var path: Array = conn.path
	if path.size() < 2:
		return 1.0
	var total: float = 0.0
	for i in range(1, path.size()):
		var dx: float = absf(path[i].x - path[i - 1].x)
		var dy: float = absf(path[i].y - path[i - 1].y)
		total += dx + dy
	return maxf(total, 1.0)


func clear_all_transit() -> void:
	## Clear all transit data on all connections. Used by undo/redo.
	if connection_manager == null:
		return
	var conns: Array[Dictionary] = connection_manager.get_connections()
	for conn in conns:
		if conn.has("transit"):
			conn["transit"] = []


# --- STALL TRACKING (back-pressure visual) ---
func _update_stall_tracking() -> void:
	if connection_manager == null:
		return
	var conns: Array[Dictionary] = connection_manager.get_connections()
	if conns.is_empty():
		connection_stalled.clear()
		return

	connection_stalled.clear()

	# Pass 1: Direct stalls — transit front item stuck OR target full
	for i in range(conns.size()):
		var conn: Dictionary = conns[i]
		var from_b: Node2D = conn.from_building
		var to_b: Node2D = conn.to_building
		if not is_instance_valid(from_b) or not is_instance_valid(to_b):
			connection_stalled[i] = true
			continue
		if from_b.has_method("is_active") and not from_b.is_active():
			continue
		# Transit-based stall: front item waiting at destination
		if _is_transit_stalled(conn):
			connection_stalled[i] = true
			continue
		# Traditional capacity stall (for cables with no transit yet)
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


# --- DATA PUSH (now pushes to transit instead of direct delivery) ---
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
	for conn in targets:
		var target: Node2D = conn.to_building
		if not target.has_method("can_accept_data"):
			continue
		var to_send: int = mini(per_target, amount)
		if to_send <= 0:
			break
		# Skip stalled cables (front item waiting at destination)
		if _is_transit_stalled(conn):
			continue
		# Static type filter (building definition check)
		if not target.accepts_data(content, state):
			continue
		# Port Purity: record cable data type + check at push time (CT only)
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
		# Push to transit queue at t=0
		if not conn.has("transit"):
			conn["transit"] = []
		conn["transit"].append({
			"key": key, "content": content, "state": state,
			"tier": tier, "tags": tags, "amount": to_send, "t": 0.0
		})
		amount -= to_send
		total_sent += to_send
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
			# Create packet and push to transit FIRST
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
		# Skip stalled cables
		if _is_transit_stalled(conn):
			continue
		# Port Purity: skip blocked CT ports
		if target.blocked_ports.has(conn.to_port):
			continue
		# Push to transit queue
		if not conn.has("transit"):
			conn["transit"] = []
		conn["transit"].append({
			"key": pkt_key, "content": -1, "state": DataEnums.DataState.PUBLIC,
			"tier": 0, "tags": 0, "amount": to_send, "t": 0.0
		})
		amount -= to_send
		total_sent += to_send
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
	var total: int = b.get_total_stored()
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
		# Inline dual-input (Decryptor/Encryptor/Recoverer) — check transit, not storage
		if b.definition.dual_input != null:
			var dual: DualInputComponent = b.definition.dual_input
			var pri_status: int = _inline_input_status(b, dual, true)
			var sec_status: int = _inline_input_status(b, dual, false)
			if pri_status == 0:
				b.status_reason = "No input"
			elif sec_status == 0:
				b.status_reason = "Waiting for Key" if not dual.fuel_matches_content else "Waiting for fuel"
			elif pri_status == 2 and sec_status == 2:
				b.status_reason = "Output blocked"
			else:
				b.status_reason = ""
			continue
		# No data at all — but check for data in transit heading here
		if b.get_total_stored() <= 0:
			if _has_incoming_transit(b):
				b.status_reason = ""
			else:
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
		# All others (Splitter, Merger)
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

func _has_incoming_transit(building: Node2D) -> bool:
	## Returns true if any input cable has transit items heading toward this building.
	var conns: Array[Dictionary] = connection_manager.get_connections()
	for conn in conns:
		if conn.to_building == building and conn.has("transit") and not conn["transit"].is_empty():
			return true
	return false


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
