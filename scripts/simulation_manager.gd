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
var discovered_states: Dictionary = {0: true, 1: false, 2: false}
var connection_manager: Node = null
var building_container: Node2D = null
var source_manager: Node = null
var sound_manager: Node = null
var connection_stalled: Dictionary = {}  # conn_idx → true if stalled
var _splitter_next_port: Dictionary = {}  # building instance_id → next output port index

# --- BUILDING CACHE (event-based, avoids get_children() every tick) ---
var _building_cache: Array[Node] = []
var _building_cache_dirty: bool = true

# --- C++ NATIVE ACCELERATORS (fallback to GDScript if DLL not loaded) ---
var _transit_sim: RefCounted = null
var _stall_prop: RefCounted = null
var _delivery_engine: RefCounted = null
var _sim_kernel: RefCounted = null

# --- DELIVERY METADATA (rebuilt when conn cache changes, used by C++ DeliveryEngine) ---
var _conn_target_types: PackedInt32Array = PackedInt32Array()
var _conn_target_filters: PackedInt32Array = PackedInt32Array()
var _conn_target_bids: Array = []  # Array[int] instance_ids
var _target_ports: Dictionary = {}  # bid → Array[String] output port names

# --- CONNECTION CACHE (event-based dirty flag, rebuilt only when topology changes) ---
var _cached_conns: Array[Dictionary] = []
var _conn_from: Dictionary = {}    # building_instance_id → Array[int] conn indices
var _conn_to: Dictionary = {}      # building_instance_id → Array[int] conn indices
var _output_ports: Dictionary = {} # building_instance_id → {port_name → conn_index}
var _conn_cache_dirty: bool = true

@onready var _sim_timer: Timer = $SimTimer


func _ready() -> void:
	_sim_timer.timeout.connect(_on_sim_tick)
	PerfMonitor.register_monitors()
	if ClassDB.class_exists("TransitSimulator"):
		_transit_sim = ClassDB.instantiate("TransitSimulator")
		print("[Simulation] C++ TransitSimulator loaded")
	else:
		print("[Simulation] TransitSimulator — GDScript fallback")
	if ClassDB.class_exists("StallPropagator"):
		_stall_prop = ClassDB.instantiate("StallPropagator")
		print("[Simulation] C++ StallPropagator loaded")
	else:
		print("[Simulation] StallPropagator — GDScript fallback")
	if ClassDB.class_exists("DeliveryEngine"):
		_delivery_engine = ClassDB.instantiate("DeliveryEngine")
		print("[Simulation] C++ DeliveryEngine loaded")
	else:
		print("[Simulation] DeliveryEngine — GDScript fallback")
	if ClassDB.class_exists("SimKernel"):
		_sim_kernel = ClassDB.instantiate("SimKernel")
		print("[Simulation] C++ SimKernel loaded")
	else:
		print("[Simulation] SimKernel — GDScript fallback")
	print("[Simulation] Manager initialized — tick: %.1fs, transit speed: %.1f grids/s" % [_sim_timer.wait_time, TRANSIT_GRIDS_PER_SEC])


func _rebuild_conn_cache() -> void:
	if not _conn_cache_dirty:
		return
	_cached_conns = connection_manager.get_connections()
	_conn_from.clear()
	_conn_to.clear()
	_output_ports.clear()
	for i in range(_cached_conns.size()):
		var conn: Dictionary = _cached_conns[i]
		if not is_instance_valid(conn.from_building) or not is_instance_valid(conn.to_building):
			continue
		var from_id: int = conn.from_building.get_instance_id()
		var to_id: int = conn.to_building.get_instance_id()
		conn["from_bid"] = from_id  # Pre-computed for safe C++ access (avoids raw Object* cast)
		if not _conn_from.has(from_id):
			_conn_from[from_id] = []
		_conn_from[from_id].append(i)
		if not _conn_to.has(to_id):
			_conn_to[to_id] = []
		_conn_to[to_id].append(i)
		if not _output_ports.has(from_id):
			_output_ports[from_id] = {}
		_output_ports[from_id][conn.from_port] = i
	_conn_cache_dirty = false
	# Build delivery metadata for C++ DeliveryEngine
	_rebuild_delivery_meta()
	# Build SimKernel metadata
	if _sim_kernel:
		_rebuild_sim_kernel_meta()


func _rebuild_delivery_meta() -> void:
	var count: int = _cached_conns.size()
	_conn_target_types.resize(count)
	_conn_target_filters.resize(count)
	_conn_target_bids.resize(count)
	_target_ports.clear()
	for i in range(count):
		var conn: Dictionary = _cached_conns[i]
		var target: Node2D = conn.to_building
		var bid: int = target.get_instance_id()
		_conn_target_bids[i] = bid
		var def = target.definition if is_instance_valid(target) else null
		if def == null:
			_conn_target_types[i] = 0
			_conn_target_filters[i] = 0
			continue
		if def.processor != null and def.processor.rule == "trash":
			_conn_target_types[i] = 6
			_conn_target_filters[i] = 0
		elif def.dual_input != null:
			_conn_target_types[i] = 7
			_conn_target_filters[i] = 0
		elif def.classifier != null:
			_conn_target_types[i] = 1
			_conn_target_filters[i] = target.classifier_filter_content
			if not _target_ports.has(bid):
				_target_ports[bid] = def.output_ports.duplicate()
		elif def.scanner != null:
			_conn_target_types[i] = 8  # BTYPE_SCANNER
			_conn_target_filters[i] = target.scanner_filter_sub_type  # packed content*4+sub_type
			if not _target_ports.has(bid):
				_target_ports[bid] = def.output_ports.duplicate()
		elif def.processor != null and def.processor.rule == "separator":
			if target.separator_mode == "state":
				_conn_target_types[i] = 2
			else:
				_conn_target_types[i] = 3
			_conn_target_filters[i] = target.separator_filter_value
			if not _target_ports.has(bid):
				_target_ports[bid] = def.output_ports.duplicate()
		elif def.splitter != null:
			_conn_target_types[i] = 4
			_conn_target_filters[i] = 0
			if not _target_ports.has(bid):
				_target_ports[bid] = def.output_ports.duplicate()
		elif def.merger != null:
			_conn_target_types[i] = 5
			_conn_target_filters[i] = 0
			if not _target_ports.has(bid):
				_target_ports[bid] = def.output_ports.duplicate()
		else:
			_conn_target_types[i] = 0
			_conn_target_filters[i] = 0


func _invalidate_conn_cache(_conn: Dictionary = {}) -> void:
	_conn_cache_dirty = true


func _rebuild_sim_kernel_meta() -> void:
	## Build metadata arrays for C++ SimKernel. Called on topology change.
	if not _sim_kernel or source_manager == null:
		return
	# --- Source port entries ---
	var source_entries: Array = []
	for source in source_manager.get_all_sources():
		var src_def: DataSourceDefinition = source.definition
		var src_id: int = source.get_instance_id()
		for port in source.output_ports:
			if not _output_ports.has(src_id) or not _output_ports[src_id].has(port):
				continue
			var inst_sw: Dictionary = source.instance_state_weights if not source.instance_state_weights.is_empty() else src_def.state_weights
			source_entries.append({
				"conn_idx": _output_ports[src_id][port],
				"gen_rate": int(src_def.generation_rate),
				"src_bid": src_id,
				"from_port": port,
				"src_id": src_id,
				"content_weights": src_def.content_weights,
				"state_weights": inst_sw,
				"enc_tier": src_def.encrypted_tier,
				"cor_tier": src_def.corrupted_tier,
				"sub_type_pool": src_def.sub_type_pool,
			})
	_sim_kernel.configure_sources(source_entries)

	# --- Building entries ---
	var building_entries: Array = []
	for b in _get_buildings():
		var def = b.definition
		if def == null:
			continue
		var bid: int = b.get_instance_id()
		var btype: int = 0  # BTYPE_NONE
		if def.processor != null and def.processor.rule == "trash":
			btype = 5  # BTYPE_TRASH
		elif def.dual_input != null:
			btype = 11  # BTYPE_INLINE (storageless cable rendezvous)
		elif def.producer != null:
			btype = 6  # BTYPE_PRODUCER
		elif def.classifier != null:
			btype = 1  # BTYPE_CLASSIFIER
		elif def.scanner != null:
			btype = 8  # BTYPE_SCANNER
		elif def.processor != null and def.processor.rule == "separator":
			btype = 2  # BTYPE_SEPARATOR
		elif def.splitter != null:
			btype = 3  # BTYPE_SPLITTER
		elif def.merger != null:
			btype = 4  # BTYPE_MERGER
		elif def.storage != null:
			# Pure storage (no processor) — forward only
			if def.processor == null and def.producer == null \
					and def.classifier == null and def.splitter == null and def.merger == null \
					and def.dual_input == null:
				btype = 9  # BTYPE_STORAGE
		var entry: Dictionary = {
			"bid": bid,
			"type": btype,
			"capacity": int(b.get_effective_value("capacity")) if def.storage else 0,
			"processing_rate": int(b.get_effective_value("processing_rate")) if def.storage else 1,
			"forward_rate": int(def.storage.forward_rate) if def.storage and def.storage.forward_rate > 0 else 0,
			"stored_data": b.stored_data,  # reference — C++ modifies in place
			"filter_value": b.classifier_filter_content if def.classifier else b.separator_filter_value,
			"separator_mode": 1 if (def.processor != null and def.processor.rule == "separator" and b.separator_mode == "content") else 0,
			"selected_tier": b.selected_tier,
		}
		# Producer fields
		if def.producer != null:
			var prod: ProducerComponent = def.producer
			entry["prod_input_key"] = DataEnums.pack_key(prod.input_content, prod.input_state)
			entry["prod_output_content"] = prod.output_content
			entry["prod_output_state"] = prod.output_state
			entry["prod_consume_amount"] = prod.consume_amount
			entry["prod_t2_extra_content"] = prod.tier2_extra_content if prod.tier2_extra_content >= 0 else -1
			entry["prod_t2_extra_amount"] = prod.tier2_extra_amount
			entry["prod_t3_extra_content"] = prod.tier3_extra_content if prod.tier3_extra_content >= 0 else -1
			entry["prod_t3_extra_amount"] = prod.tier3_extra_amount
		# DualInput fields
		if def.dual_input != null:
			var dual: DualInputComponent = def.dual_input
			entry["dual_fuel_matches"] = 1 if dual.fuel_matches_content else 0
			entry["dual_key_content"] = dual.key_content
			entry["dual_key_cost"] = dual.key_cost
			entry["dual_output_state"] = dual.output_state
			entry["dual_output_tag"] = dual.output_tag
			entry["dual_primary_states"] = PackedInt32Array(dual.primary_input_states)
			entry["dual_tier_key_costs"] = PackedInt32Array(dual.tier_key_costs)
			entry["dual_required_fuel_tags"] = PackedInt32Array(dual.required_fuel_tags)
		building_entries.append(entry)

	_sim_kernel.configure_buildings(building_entries)

	# --- Connection push metadata ---
	var conn_push_meta: Array = []
	for i in range(_cached_conns.size()):
		var conn: Dictionary = _cached_conns[i]
		var target: Node2D = conn.to_building
		var tdef = target.definition if is_instance_valid(target) else null
		var meta: Dictionary = {"target_bid": target.get_instance_id() if is_instance_valid(target) else 0}
		meta["is_ct"] = tdef != null and tdef.category == "terminal"
		# accepts_mask: 28-bit (7 content × 4 state) — cached per definition
		meta["accepts_mask"] = tdef.get_accepts_mask() if tdef != null else 0x0FFFFFFF
		# Routing/trash = unlimited accept (no capacity check)
		meta["unlimited_accept"] = tdef != null and (
			tdef.classifier != null or tdef.splitter != null or tdef.merger != null
			or (tdef.processor != null and (tdef.processor.rule == "separator" or tdef.processor.rule == "trash"))
			or tdef.dual_input != null)
		meta["capacity"] = int(target.get_effective_value("capacity")) if tdef != null and tdef.storage != null else 0
		conn_push_meta.append(meta)

	_sim_kernel.configure_graph(_conn_from, _conn_to, _output_ports, conn_push_meta)


func _process(delta: float) -> void:
	if is_paused or connection_manager == null:
		return
	var _t0: int = Time.get_ticks_usec()
	_rebuild_conn_cache()
	var _t1: int = Time.get_ticks_usec()
	PerfMonitor.sim_cache_us = _t1 - _t0

	_advance_transit(delta)
	var _t2: int = Time.get_ticks_usec()
	PerfMonitor.sim_transit_us = _t2 - _t1

	_deliver_arrived()
	var _t3: int = Time.get_ticks_usec()
	PerfMonitor.sim_deliver_us = _t3 - _t2
	PerfMonitor.frame_sim_us = _t3 - _t0

	# Update counts
	PerfMonitor.sim_connections = _cached_conns.size()
	var _item_count: int = 0
	for c in _cached_conns:
		if c.has("transit"):
			_item_count += c["transit"].size()
	PerfMonitor.sim_transit_items = _item_count


func set_speed(multiplier: int) -> void:
	# Valid speeds: 1, 2, 4, 8
	if multiplier not in [1, 2, 4, 8]:
		multiplier = 1
	speed_multiplier = multiplier
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


func _get_buildings() -> Array[Node]:
	if _building_cache_dirty:
		_building_cache.clear()
		for child in building_container.get_children():
			if child.has_method("is_active"):
				_building_cache.append(child)
		_building_cache_dirty = false
	return _building_cache


func _on_sim_tick() -> void:
	var _tick_t0: int = Time.get_ticks_usec()
	_rebuild_conn_cache()
	var buildings: Array[Node] = _get_buildings()
	_tick_count += 1
	if buildings.is_empty():
		tick_completed.emit(_tick_count)
		return
	# Reset work flags (filter out freed buildings mid-tick)
	for i in range(buildings.size() - 1, -1, -1):
		if not is_instance_valid(buildings[i]):
			buildings.remove_at(i)
			continue
		buildings[i].is_working = false
	# 1. Deliver arrived transit items to target buildings
	_deliver_arrived()
	# 2. Normal simulation: generate → forward → process
	if _sim_kernel:
		_run_sim_kernel_tick(buildings)
	else:
		_update_generation(buildings)
		_update_storage_forward(buildings)
		_update_processing(buildings)
	# Mark buildings with changed stored_data for redraw
	for b in buildings:
		if b.is_working:
			b.stored_data_dirty = true
	# 4. Status, stall tracking, visuals
	_update_status_reasons(buildings)
	_update_stall_tracking()
	_update_displays(buildings)
	PerfMonitor.sim_tick_us = Time.get_ticks_usec() - _tick_t0
	tick_completed.emit(_tick_count)


# --- TRANSIT SYSTEM ---
# Data travels along cables in real-time. Each connection dict stores a "transit" array.
# Transit item: {key, content, state, tier, tags, amount, t} where t goes from 0.0 (source) to 1.0 (destination).
# Items are ordered oldest-first: index 0 = closest to destination (highest t).

const TRANSIT_MIN_SPACING_GRIDS: float = 1.5  ## Minimum grid cells between transit items on a cable

func _advance_transit(delta: float) -> void:
	if _transit_sim:
		_transit_sim.advance_transit(_cached_conns, delta, speed_multiplier)
		return
	_advance_transit_gdscript(delta)


func _advance_transit_gdscript(delta: float) -> void:
	## GDScript fallback for transit advancement.
	for conn in _cached_conns:
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


func _run_sim_kernel_tick(buildings: Array[Node]) -> void:
	## C++ SimKernel handles: generation + storage forward + trash + inline rendezvous.
	## Processing for routing/producer/dual_input stays in GDScript for now.
	var result: Dictionary = _sim_kernel.run_tick(_cached_conns, _splitter_next_port, {})
	# Apply working building flags
	for bid in result.get("working", []):
		for b in buildings:
			if b.get_instance_id() == bid:
				b.is_working = true
				break
	# Apply CT pushes (deferred from C++ for purity check)
	for push in result.get("ct_pushes", []):
		var ci: int = int(push.conn_idx)
		var pkey: int = int(push.packed_key)
		var amt: int = int(push.amount)
		if ci < 0 or ci >= _cached_conns.size():
			continue
		var conn: Dictionary = _cached_conns[ci]
		var target: Node2D = conn.to_building
		# Port purity check
		if target.blocked_ports.has(conn.to_port):
			continue
		if target.definition.category == "terminal":
			var port: String = conn.to_port
			if not target.port_carried_types.has(port):
				target.port_carried_types[port] = {}
			var content: int = DataEnums.unpack_content(pkey)
			var state: int = DataEnums.unpack_state(pkey)
			var type_key: int = (content << 4) | state
			target.port_carried_types[port][type_key] = true
			if target.purity_checker.is_valid():
				var contaminated := false
				for tk in target.port_carried_types[port]:
					if not target.purity_checker.call(tk >> 4, tk & 0xF):
						contaminated = true
						break
				if contaminated:
					target.blocked_ports[port] = true
					continue
		if not conn.has("transit"):
			conn["transit"] = []
		conn["transit"].append({"key": pkey, "amount": amt, "t": 0.0})
	# Apply discoveries
	for disc in result.get("discoveries", []):
		_check_discovery(int(disc.content), int(disc.state))
	# Process sounds
	for snd in result.get("sounds", []):
		if sound_manager:
			sound_manager.play_process_event(str(snd))
	# Still run GDScript processing for buildings SimKernel doesn't handle
	_update_processing(buildings)


func _deliver_arrived() -> void:
	## Deliver transit items that reached destination (t >= 1.0).
	## C++ DeliveryEngine handles routing passthrough + trash.
	## GDScript handles inline rendezvous + regular storage delivery.
	if _delivery_engine:
		_deliver_arrived_cpp()
	else:
		_deliver_arrived_gdscript()
	# Storageless inline processing: match primary + secondary inputs on cables
	# (skipped when SimKernel handles it in run_tick)
	if not _sim_kernel:
		_process_inline_rendezvous()


func _deliver_arrived_cpp() -> void:
	# Update filter values (can change via Tab key without topology change)
	_update_delivery_filters()
	# C++ handles routing passthrough + trash in native iteration
	var result: Dictionary = _delivery_engine.deliver_arrived(
		_cached_conns, _conn_target_types, _conn_target_filters,
		_conn_target_bids, _target_ports, _output_ports, _splitter_next_port)
	# Mark working buildings
	for bid in result.get("working", []):
		for ci in _conn_to.get(bid, []):
			var target: Node2D = _cached_conns[ci].to_building
			if is_instance_valid(target):
				target.is_working = true
				break
	# Process remaining connections (inline + regular) in GDScript
	var remaining: Array = result.get("remaining", [])
	for ci in remaining:
		var conn: Dictionary = _cached_conns[ci]
		_deliver_conn_gdscript(conn)


func _update_delivery_filters() -> void:
	## Update filter values for classifier/separator (can change without topology change).
	for i in range(_cached_conns.size()):
		if not is_instance_valid(_cached_conns[i].to_building):
			continue
		var type: int = _conn_target_types[i]
		if type == 1:  # CLASSIFIER
			_conn_target_filters[i] = _cached_conns[i].to_building.classifier_filter_content
		elif type == 2 or type == 3:  # SEPARATOR
			_conn_target_filters[i] = _cached_conns[i].to_building.separator_filter_value


func _deliver_conn_gdscript(conn: Dictionary) -> void:
	## GDScript delivery for a single connection (inline + regular buildings).
	var transit: Array = conn.get("transit", [])
	if transit.is_empty():
		return
	var target: Node2D = conn.to_building
	if not is_instance_valid(target) or not target.has_method("can_accept_data"):
		transit.clear()
		return
	while not transit.is_empty() and transit[0].t >= 1.0:
		var item: Dictionary = transit[0]
		# Routing fallback (C++ failed — ports not connected)
		if _try_passthrough(target, item):
			transit.remove_at(0)
			continue
		if target.definition != null and (target.definition.classifier != null \
				or target.definition.splitter != null or target.definition.merger != null \
				or (target.definition.processor != null and target.definition.processor.rule == "separator")):
			if _get_passthrough_port(target, item) == "":
				break
		# Trash fallback
		if target.definition != null and target.definition.processor != null \
				and target.definition.processor.rule == "trash":
			transit.remove_at(0)
			target.is_working = true
			continue
		# Inline processor: leave in transit for rendezvous
		if _is_inline_processor(target):
			break
		# Reserve capacity for secondary input (keys/fuel)
		if not _dual_input_can_accept(target, item):
			break
		# Check capacity
		if not target.can_accept_data(1):
			break
		# Partial delivery
		var deliver: int = item.amount
		if not target.can_accept_data(deliver):
			if target.definition != null and target.definition.storage != null:
				var room: int = int(target.get_effective_value("capacity")) - target.get_total_stored()
				deliver = clampi(room, 1, item.amount)
			else:
				deliver = 1
		target.stored_data[item.key] = target.stored_data.get(item.key, 0) + deliver
		target.stored_data_dirty = true
		item.amount -= deliver
		if item.amount <= 0:
			transit.remove_at(0)
		else:
			break


func _deliver_arrived_gdscript() -> void:
	## Pure GDScript fallback for delivery (no C++ DLL).
	for conn in _cached_conns:
		_deliver_conn_gdscript(conn)


func _dual_input_can_accept(target: Node2D, item: Dictionary) -> bool:
	## For dual-input buildings (Decryptor, Encryptor, Recoverer), reserve capacity
	## for secondary input (keys/fuel). Primary data stops at 75% to prevent deadlock.
	if target.definition == null or target.definition.dual_input == null:
		return true  # Not a dual-input building — no restriction
	var dual: DualInputComponent = target.definition.dual_input
	var ikey: int = int(item.key)
	var is_secondary: bool
	if dual.fuel_matches_content:
		# Recoverer: fuel = Public state, tier 0
		is_secondary = (DataEnums.unpack_state(ikey) == DataEnums.DataState.PUBLIC and DataEnums.unpack_tier(ikey) == 0)
	else:
		# Decryptor/Encryptor: fuel = Key content type
		is_secondary = (DataEnums.unpack_content(ikey) == dual.key_content)
	if is_secondary:
		return true  # Secondary input always allowed up to full capacity
	var cap: int = int(target.get_effective_value("capacity"))
	var reserve: int = maxi(3, cap / 4)
	return target.get_total_stored() < cap - reserve


func _try_passthrough(building: Node2D, item: Dictionary) -> bool:
	## For routing buildings (Separator, Classifier, Splitter, Merger),
	## immediately forward the transit item to the correct output cable.
	## Preserves item identity — what goes in comes out with same key/content/state.
	## Returns true if item was forwarded, false to fall back to normal storage delivery.
	var output_port: String = _get_passthrough_port(building, item)
	if output_port == "":
		return false
	# Find output connection for this port (O(1) cache lookup)
	var bid: int = building.get_instance_id()
	if not _output_ports.has(bid) or not _output_ports[bid].has(output_port):
		return false
	var out_conn: Dictionary = _cached_conns[_output_ports[bid][output_port]]
	if _is_transit_stalled(out_conn):
		return false
	# Forward the transit item to output cable at t=0
	if not out_conn.has("transit"):
		out_conn["transit"] = []
	out_conn["transit"].append({"key": int(item.key), "amount": int(item.amount), "t": 0.0})
	building.is_working = true
	return true


func _get_passthrough_port(building: Node2D, item: Dictionary) -> String:
	## Determine output port for real-time pass-through routing.
	## Returns "" if building is not a routing type or required ports aren't connected.
	var def = building.definition
	if def == null:
		return ""
	var ikey: int = int(item.key)
	# Classifier: route by content
	if def.classifier != null:
		var ports: Array[String] = def.output_ports
		if ports.size() < 2:
			return ""
		if not _has_output_connection(building, ports[0]) or not _has_output_connection(building, ports[1]):
			return ""
		return ports[0] if DataEnums.unpack_content(ikey) == building.classifier_filter_content else ports[1]
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
			matches = (DataEnums.unpack_content(ikey) == building.separator_filter_value)
		else:
			matches = (DataEnums.unpack_state(ikey) == building.separator_filter_value)
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


func _process_inline_rendezvous() -> void:
	## Try rendezvous matching for all inline buildings with arrived transit items.
	var checked: Dictionary = {}
	for conn in _cached_conns:
		var target: Node2D = conn.to_building
		if not is_instance_valid(target) or checked.has(target):
			continue
		if not _is_inline_processor(target):
			continue
		checked[target] = true
		_try_rendezvous(target)


func _try_rendezvous(building: Node2D) -> void:
	## Match primary + secondary inputs on cables for an inline dual-input building.
	## Both must have items arrived (t>=1.0). If matched, consume both and push output.
	var dual: DualInputComponent = building.definition.dual_input
	var max_process: int = int(building.get_effective_value("processing_rate"))
	var processed: int = 0
	var bid: int = building.get_instance_id()
	var in_indices: Array = _conn_to.get(bid, [])

	for _attempt in range(max_process):
		var primary_conn: Dictionary = {}
		var secondary_conn: Dictionary = {}

		for ci in in_indices:
			var conn: Dictionary = _cached_conns[ci]
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
		var pkey: int = int(p_item.key)
		var tier: int = DataEnums.unpack_tier(pkey)
		var key_cost: int = dual.key_cost
		if tier > 0 and tier <= dual.tier_key_costs.size():
			key_cost = dual.tier_key_costs[tier - 1]
		if s_item.amount < key_cost:
			break

		# Push output to transit
		var out_tags: int = DataEnums.unpack_tags(pkey) | dual.output_tag
		var sent: int = _push_data_from(building, DataEnums.unpack_content(pkey), dual.output_state, 1, "", tier, out_tags)
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
	var ikey: int = int(item.key)
	if dual.fuel_matches_content:
		if DataEnums.unpack_state(ikey) == DataEnums.DataState.PUBLIC and DataEnums.unpack_tier(ikey) == 0:
			return false  # This is fuel, not primary
	else:
		if DataEnums.unpack_content(ikey) == dual.key_content:
			return false  # This is a Key, not primary
	if not dual.primary_input_states.is_empty() and DataEnums.unpack_state(ikey) not in dual.primary_input_states:
		return false
	return true


func _is_inline_secondary(dual: DualInputComponent, item: Dictionary) -> bool:
	## Check if transit item is secondary input (key/fuel) for inline processing.
	var ikey: int = int(item.key)
	if dual.fuel_matches_content:
		return DataEnums.unpack_state(ikey) == DataEnums.DataState.PUBLIC and DataEnums.unpack_tier(ikey) == 0
	else:
		return DataEnums.unpack_content(ikey) == dual.key_content


func _inline_secondary_matches(dual: DualInputComponent, primary: Dictionary, secondary: Dictionary) -> bool:
	## Verify that a specific secondary item matches the primary for processing.
	var pkey: int = int(primary.key)
	var skey: int = int(secondary.key)
	if dual.fuel_matches_content:
		# Recoverer: fuel must match primary content + required tags
		if DataEnums.unpack_content(skey) != DataEnums.unpack_content(pkey):
			return false
		var required_tags: int = 0
		var tier: int = DataEnums.unpack_tier(pkey)
		if tier > 0 and tier <= dual.required_fuel_tags.size():
			required_tags = dual.required_fuel_tags[tier - 1]
		return DataEnums.unpack_tags(skey) == required_tags
	else:
		# Decryptor/Encryptor: key tier must match data tier (min T1)
		var key_tier: int = maxi(DataEnums.unpack_tier(pkey), 1)
		return DataEnums.unpack_tier(skey) == key_tier


func _inline_input_status(building: Node2D, dual: DualInputComponent, check_primary: bool) -> int:
	## Returns 0=none, 1=in transit, 2=arrived (t>=1.0) for inline building inputs.
	var bid: int = building.get_instance_id()
	var best: int = 0
	var in_indices: Array = _conn_to.get(bid, [])
	for ci in in_indices:
		var conn: Dictionary = _cached_conns[ci]
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
	## Cached in connection dict — path never changes after placement.
	if conn.has("_cached_length_grids"):
		return conn["_cached_length_grids"]
	var path: Array = conn.path
	if path.size() < 2:
		conn["_cached_length_grids"] = 1.0
		return 1.0
	var total: float = 0.0
	for i in range(1, path.size()):
		var dx: float = absf(path[i].x - path[i - 1].x)
		var dy: float = absf(path[i].y - path[i - 1].y)
		total += dx + dy
	var result: float = maxf(total, 1.0)
	conn["_cached_length_grids"] = result
	return result


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
	if _cached_conns.is_empty():
		connection_stalled.clear()
		return

	# C++ SimKernel: unified Pass 1-4 in one call
	if _sim_kernel:
		var active_arr: PackedInt32Array = _build_active_array()
		connection_stalled = _sim_kernel.update_stalls(_cached_conns, active_arr, 3)
		return

	connection_stalled.clear()

	# Pass 1: Direct stalls — transit front item stuck OR target full
	for i in range(_cached_conns.size()):
		var conn: Dictionary = _cached_conns[i]
		var from_b: Node2D = conn.from_building
		var to_b: Node2D = conn.to_building
		if not is_instance_valid(from_b) or not is_instance_valid(to_b):
			connection_stalled[i] = true
			continue
		if from_b.has_method("is_active") and not from_b.is_active():
			continue
		if _is_transit_stalled(conn):
			connection_stalled[i] = true
			continue
		if to_b.has_method("can_accept_data") and not to_b.can_accept_data(1):
			connection_stalled[i] = true

	# Pass 2-4: Back-pressure propagation (C++ or GDScript fallback)
	if _stall_prop:
		connection_stalled = _stall_prop.propagate_stalls(connection_stalled, _conn_from, _conn_to, 3)
	else:
		for _pass in range(3):
			var newly_stalled: Dictionary = {}
			for bid in _conn_from:
				var out_indices: Array = _conn_from[bid]
				var all_blocked: bool = true
				for oi in out_indices:
					if not connection_stalled.has(oi) and not newly_stalled.has(oi):
						all_blocked = false
						break
				if all_blocked and _conn_to.has(bid):
					for ii in _conn_to[bid]:
						if not connection_stalled.has(ii):
							newly_stalled[ii] = true
			if newly_stalled.is_empty():
				break
			connection_stalled.merge(newly_stalled)


func _build_active_array() -> PackedInt32Array:
	## Build per-building-slot active flag array for C++ stall tracking.
	var arr: PackedInt32Array = PackedInt32Array()
	for b in _get_buildings():
		arr.append(1 if b.is_active() else 0)
	return arr


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


func _get_fixed_tier(state: int, enc_tier: int, cor_tier: int) -> int:
	match state:
		DataEnums.DataState.ENCRYPTED:
			return maxi(enc_tier, 1)
		DataEnums.DataState.CORRUPTED:
			return maxi(cor_tier, 1)
	return 0


func _roll_sub_type(content: int, src_def) -> int:
	## Pick a random sub-type from the source's pool that matches this content
	var pool: Array = src_def.sub_type_pool
	if pool.is_empty():
		return -1
	var matching: Array[int] = []
	for entry in pool:
		if int(entry.get("content", -1)) == content:
			matching.append(int(entry.get("sub_type", 0)))
	if matching.is_empty():
		return -1
	return matching[randi() % matching.size()]


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
func _push_data_from(source: Node2D, content: int, state: int, amount: int, from_port: String = "", tier: int = 0, tags: int = 0, sub_type: int = -1) -> int:
	var bid: int = source.get_instance_id()
	var targets: Array[Dictionary] = []
	if _conn_from.has(bid):
		for ci in _conn_from[bid]:
			var conn: Dictionary = _cached_conns[ci]
			if from_port == "" or conn.from_port == from_port:
				targets.append(conn)
	if targets.is_empty():
		return 0
	var packed_key: int = DataEnums.pack_key(content, state, tier, tags, sub_type)
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
			# Record this data type on the cable (packed int key: content<<4|state)
			if not target.port_carried_types.has(port):
				target.port_carried_types[port] = {}
			var type_key: int = (content << 4) | state
			target.port_carried_types[port][type_key] = true
			# Check purity: if ANY recorded type doesn't match gig → block
			if target.purity_checker.is_valid():
				var contaminated := false
				for tk in target.port_carried_types[port]:
					if not target.purity_checker.call(tk >> 4, tk & 0xF):
						contaminated = true
						break
				if contaminated:
					target.blocked_ports[port] = true
					print("[PortPurity] CT port '%s' blocked — cable carries non-matching data" % port)
					continue
		# Push to transit queue at t=0
		if not conn.has("transit"):
			conn["transit"] = []
		conn["transit"].append({"key": packed_key, "amount": to_send, "t": 0.0})
		amount -= to_send
		total_sent += to_send
	return total_sent


# --- DATA GENERATION (Sources) ---
func _update_generation(_buildings: Array[Node]) -> void:
	if source_manager == null or connection_manager == null:
		return
	for source in source_manager.get_all_sources():
		var src_def: DataSourceDefinition = source.definition
		var amount: int = int(src_def.generation_rate)
		var src_id: int = source.get_instance_id()
		# Each connected port generates independently at full rate
		for port in source.output_ports:
			if not _output_ports.has(src_id) or not _output_ports[src_id].has(port):
				continue
			for _i in range(amount):
				var content: int = _roll_content(src_def.content_weights)
				var sw: Dictionary = source.instance_state_weights if not source.instance_state_weights.is_empty() else src_def.state_weights
				var state: int = _roll_state(sw)
				var tier: int = _get_fixed_tier(state, src_def.encrypted_tier, src_def.corrupted_tier)
				var sub_type: int = _roll_sub_type(content, src_def)
				_check_discovery(content, state)
				_push_data_from(source, content, state, 1, port, tier, 0, sub_type)


# --- STORAGE FORWARD ---
func _update_storage_forward(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.definition.storage == null or not b.is_active():
			continue
		if b.definition.processor != null or b.definition.splitter != null or b.definition.merger != null \
				or b.definition.producer != null or b.definition.dual_input != null \
				or b.definition.classifier != null:
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
			var pushed: int = _push_data_from(b, DataEnums.unpack_content(key), DataEnums.unpack_state(key), mini(available, max_forward - sent), "", DataEnums.unpack_tier(key), DataEnums.unpack_tags(key))
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
		if b.definition.dual_input != null:
			var max_process: int = int(b.get_effective_value("processing_rate"))
			processed = _process_dual_input(b, max_process)
		elif b.definition.producer != null:
			var max_process: int = int(b.get_effective_value("processing_rate"))
			processed = _process_producer(b, max_process)
		elif b.definition.classifier != null:
			processed = _process_classifier(b, int(b.get_effective_value("processing_rate")))
		elif b.definition.scanner != null:
			processed = _process_scanner(b, int(b.definition.scanner.throughput_rate))
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
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data.get(key, 0)
		if available <= 0:
			continue
		var c: int = DataEnums.unpack_content(key)
		var to_process: int = mini(available, max_process - processed)
		var target_port: String = primary_port if c == filter_content else secondary_port
		var sent: int = _push_data_from(b, c, DataEnums.unpack_state(key), to_process, target_port, DataEnums.unpack_tier(key), DataEnums.unpack_tags(key), DataEnums.unpack_sub_type(key))
		if sent > 0:
			b.stored_data[key] -= sent
			processed += sent
	return processed


func _process_scanner(b: Node2D, max_process: int) -> int:
	var processed: int = 0
	var output_ports: Array[String] = b.definition.output_ports
	if output_ports.size() < 2:
		return 0
	var primary_port: String = output_ports[0]   # right — selected sub-type
	var secondary_port: String = output_ports[1]  # bottom — everything else
	if not _has_output_connection(b, primary_port) or not _has_output_connection(b, secondary_port):
		return 0
	var filter_pid: int = b.scanner_filter_sub_type  # packed: content*4 + sub_type
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data.get(key, 0)
		if available <= 0:
			continue
		var c: int = DataEnums.unpack_content(key)
		var st: int = DataEnums.unpack_sub_type(key)
		var data_pid: int = c * 4 + st if st >= 0 else -1
		var to_process: int = mini(available, max_process - processed)
		var target_port: String = primary_port if data_pid == filter_pid else secondary_port
		var sent: int = _push_data_from(b, DataEnums.unpack_content(key), DataEnums.unpack_state(key), to_process, target_port, DataEnums.unpack_tier(key), DataEnums.unpack_tags(key), st)
		if sent > 0:
			b.stored_data[key] -= sent
			processed += sent
	return processed


func _process_producer(b: Node2D, max_process: int) -> int:
	var prod: ProducerComponent = b.definition.producer
	var selected: int = b.selected_tier
	var input_key: int = DataEnums.pack_key(prod.input_content, prod.input_state)
	var available: int = b.stored_data.get(input_key, 0)
	if available <= 0:
		return 0
	var productions: int = mini(available / prod.consume_amount, max_process)
	if productions <= 0:
		return 0
	# Check tier-based extra content requirements
	if selected >= 2 and prod.tier2_extra_content >= 0:
		var extra2_key: int = DataEnums.pack_key(prod.tier2_extra_content, prod.input_state)
		var extra2_avail: int = b.stored_data.get(extra2_key, 0)
		productions = mini(productions, extra2_avail / prod.tier2_extra_amount)
	if selected >= 3 and prod.tier3_extra_content >= 0:
		var extra3_key: int = DataEnums.pack_key(prod.tier3_extra_content, prod.input_state)
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
		var extra2_key: int = DataEnums.pack_key(prod.tier2_extra_content, prod.input_state)
		b.stored_data[extra2_key] -= sent * prod.tier2_extra_amount
	if selected >= 3 and prod.tier3_extra_content >= 0:
		var extra3_key: int = DataEnums.pack_key(prod.tier3_extra_content, prod.input_state)
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
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data[key]
		if available <= 0:
			continue
		var p_content: int = DataEnums.unpack_content(key)
		var p_state: int = DataEnums.unpack_state(key)
		var p_tier: int = DataEnums.unpack_tier(key)
		var p_tags: int = DataEnums.unpack_tags(key)
		if p_content == dual.key_content:
			continue
		if not dual.primary_input_states.is_empty() and p_state not in dual.primary_input_states:
			continue
		# Match data tier to required key/kit tier
		var effective_tier: int = p_tier
		var out_state: int = dual.output_state
		var out_tier: int = p_tier
		# Match Key tier to data tier (min T1)
		var key_tier: int = maxi(effective_tier, 1)
		var key_key: int = DataEnums.pack_key(dual.key_content, DataEnums.DataState.PUBLIC, key_tier, 0)
		var keys_available: int = b.stored_data.get(key_key, 0) - fuel_consumed.get(key_key, 0)
		if keys_available <= 0:
			continue
		var actual_key_cost: int = dual.key_cost
		if effective_tier > 0 and effective_tier <= dual.tier_key_costs.size():
			actual_key_cost = dual.tier_key_costs[effective_tier - 1]
		var to_process: int = mini(available, max_process - processed)
		var keys_needed: int = to_process * actual_key_cost
		if keys_needed > keys_available:
			to_process = keys_available / actual_key_cost
		if to_process <= 0:
			continue
		var out_tags: int = p_tags | dual.output_tag
		var sent: int = _push_data_from(b, p_content, out_state, to_process, "", out_tier, out_tags)
		if sent > 0:
			b.stored_data[key] -= sent
			processed += sent
			fuel_consumed[key_key] = fuel_consumed.get(key_key, 0) + sent * actual_key_cost
			_spawn_floating_text(b, "+%d %s" % [sent, DataEnums.tags_label(out_tags)], Color("#44ff88"))
			if sound_manager:
				sound_manager.play_process_event(b.definition.visual_type)
			print("[DualInput] %s: %d MB → %s (-%d T%d Key)" % [
				b.definition.building_name, sent,
				DataEnums.data_label(p_content, out_state, out_tier, out_tags),
				sent * actual_key_cost, key_tier])
	return processed


func _process_dual_input_fuel_mode(b: Node2D, dual: DualInputComponent, max_process: int, fuel_consumed: Dictionary) -> int:
	# Recoverer: fuel must be same content, tier-based tags required
	var processed: int = 0
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data[key]
		if available <= 0:
			continue
		var p_content: int = DataEnums.unpack_content(key)
		var p_state: int = DataEnums.unpack_state(key)
		var p_tier: int = DataEnums.unpack_tier(key)
		var p_tags: int = DataEnums.unpack_tags(key)
		if not dual.primary_input_states.is_empty() and p_state not in dual.primary_input_states:
			continue
		var effective_tier: int = p_tier
		# Find fuel: same content, Public, tier 0, tags based on corrupted tier
		var required_tags: int = 0
		if effective_tier > 0 and effective_tier <= dual.required_fuel_tags.size():
			required_tags = dual.required_fuel_tags[effective_tier - 1]
		var fuel_key: int = DataEnums.pack_key(p_content, DataEnums.DataState.PUBLIC, 0, required_tags)
		var fuel_available: int = b.stored_data.get(fuel_key, 0) - fuel_consumed.get(fuel_key, 0)
		if fuel_available <= 0:
			continue
		var actual_fuel_cost: int = dual.key_cost
		if effective_tier > 0 and effective_tier <= dual.tier_key_costs.size():
			actual_fuel_cost = dual.tier_key_costs[effective_tier - 1]
		var to_process: int = mini(available, max_process - processed)
		var fuel_needed: int = to_process * actual_fuel_cost
		if fuel_needed > fuel_available:
			to_process = fuel_available / actual_fuel_cost
		if to_process <= 0:
			continue
		var out_tags: int = p_tags | dual.output_tag
		var sent: int = _push_data_from(b, p_content, dual.output_state, to_process, "", p_tier, out_tags)
		if sent > 0:
			b.stored_data[key] -= sent
			processed += sent
			fuel_consumed[fuel_key] = fuel_consumed.get(fuel_key, 0) + sent * actual_fuel_cost
			_spawn_floating_text(b, "+%d %s" % [sent, DataEnums.tags_label(out_tags)], Color("#44ff88"))
			if sound_manager:
				sound_manager.play_process_event(b.definition.visual_type)
			print("[DualInput] %s: %d MB → %s (-%d fuel)" % [
				b.definition.building_name, sent,
				DataEnums.data_label(p_content, dual.output_state, p_tier, out_tags),
				sent * actual_fuel_cost])
	return processed


func _process_separator(b: Node2D, proc: ProcessorComponent, max_process: int) -> int:
	var primary_port: String = b.definition.output_ports[0] if b.definition.output_ports.size() > 0 else ""
	var secondary_port: String = b.definition.output_ports[1] if b.definition.output_ports.size() > 1 else ""
	# Both output ports must have connections — forces player to route rejected data
	if primary_port == "" or secondary_port == "" or \
			not _has_output_connection(b, primary_port) or not _has_output_connection(b, secondary_port):
		return 0
	var processed: int = 0
	var mode: String = proc.separator_mode
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data.get(key, 0)
		if available <= 0:
			continue
		var c: int = DataEnums.unpack_content(key)
		var s: int = DataEnums.unpack_state(key)
		var to_process: int = mini(available, max_process - processed)
		# Route: matching value → primary (right), rest → secondary (bottom)
		var matches: bool
		if mode == "content":
			matches = (c == b.separator_filter_value)
		else:
			matches = (s == b.separator_filter_value)
		var target_port: String = primary_port if matches else secondary_port
		if target_port == "":
			continue
		var sent: int = _push_data_from(b, c, s, to_process, target_port, DataEnums.unpack_tier(key), DataEnums.unpack_tags(key))
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
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data.get(key, 0)
		if available <= 0:
			continue
		var c: int = DataEnums.unpack_content(key)
		var s: int = DataEnums.unpack_state(key)
		var t: int = DataEnums.unpack_tier(key)
		var tg: int = DataEnums.unpack_tags(key)
		var to_process: int = mini(available, max_process - processed)
		# Round-robin: distribute one at a time, alternating ports
		var sent_total: int = 0
		for _unit in range(to_process):
			var port: String = output_ports[next_idx]
			var sent: int = _push_data_from(b, c, s, 1, port, t, tg)
			if sent > 0:
				sent_total += 1
				next_idx = (next_idx + 1) % port_count
			else:
				# This port blocked — try next port once
				var alt_idx: int = (next_idx + 1) % port_count
				var alt_port: String = output_ports[alt_idx]
				var alt_sent: int = _push_data_from(b, c, s, 1, alt_port, t, tg)
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
	for key in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data.get(key, 0)
		if available <= 0:
			continue
		var to_process: int = mini(available, max_process - processed)
		var sent: int = _push_data_from(b, DataEnums.unpack_content(key), DataEnums.unpack_state(key), to_process, output_port, DataEnums.unpack_tier(key), DataEnums.unpack_tags(key))
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
	_building_cache_dirty = true
	_conn_cache_dirty = true


func _on_building_removed(_building: Node2D, _cell: Vector2i) -> void:
	_add_camera_trauma(0.1)
	_building_cache_dirty = true
	_conn_cache_dirty = true


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
		# Producer (Key Forge / Repair Lab)
		if b.definition.producer != null:
			var prod: ProducerComponent = b.definition.producer
			var input_key: int = DataEnums.pack_key(prod.input_content, prod.input_state)
			if b.stored_data.get(input_key, 0) <= 0:
				b.status_reason = "No %s data" % DataEnums.content_name(prod.input_content)
			else:
				var missing: String = ""
				if b.selected_tier >= 2 and prod.tier2_extra_content >= 0:
					var ek: int = DataEnums.pack_key(prod.tier2_extra_content, prod.input_state)
					if b.stored_data.get(ek, 0) <= 0:
						missing = DataEnums.content_name(prod.tier2_extra_content)
				if missing == "" and b.selected_tier >= 3 and prod.tier3_extra_content >= 0:
					var ek: int = DataEnums.pack_key(prod.tier3_extra_content, prod.input_state)
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
		var c: int = DataEnums.unpack_content(key)
		var s: int = DataEnums.unpack_state(key)
		if c == dual.key_content:
			continue
		if dual.fuel_matches_content and s == DataEnums.DataState.PUBLIC and DataEnums.unpack_tier(key) == 0:
			continue
		if not dual.primary_input_states.is_empty() and s not in dual.primary_input_states:
			continue
		return true
	return false


func _reason_has_keys(b: Node2D, dual: DualInputComponent) -> bool:
	for key in b.stored_data:
		if b.stored_data[key] <= 0:
			continue
		if DataEnums.unpack_content(key) == dual.key_content:
			return true
	return false


func _reason_has_fuel(b: Node2D, dual: DualInputComponent) -> bool:
	for key in b.stored_data:
		if b.stored_data[key] <= 0:
			continue
		if DataEnums.unpack_state(key) == DataEnums.DataState.PUBLIC and DataEnums.unpack_content(key) != dual.key_content:
			return true
	return false


# --- CONNECTION HELPERS ---

func _has_incoming_transit(building: Node2D) -> bool:
	## Returns true if any input cable has transit items heading toward this building.
	var bid: int = building.get_instance_id()
	if not _conn_to.has(bid):
		return false
	for ci in _conn_to[bid]:
		var conn: Dictionary = _cached_conns[ci]
		if conn.has("transit") and not conn["transit"].is_empty():
			return true
	return false


func _has_output_connection(building: Node2D, port: String) -> bool:
	var bid: int = building.get_instance_id()
	return _output_ports.has(bid) and _output_ports[bid].has(port)


func _all_outputs_connected(b: Node2D) -> bool:
	for port in b.definition.output_ports:
		if not _has_output_connection(b, port):
			return false
	return true
