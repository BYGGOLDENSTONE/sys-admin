extends Node

signal credits_changed(new_total: float)
signal research_changed(new_total: float)
signal patch_data_changed(new_total: float)
signal tick_completed(tick_count: int)
signal data_type_discovered(data_type: String)
signal malware_damage_detected(building: Node2D)

const TILE_SIZE: int = 64
const NATURAL_COOLING: float = 0.1
const OVERHEAT_RECOVERY_RATIO: float = 0.8
const POWER_CELL_HEAT_PER_TILE: float = 0.04  ## C/s per powered tile (2x2 building = 4 tiles ≈ 0.16)
const MALWARE_HEAT_PER_MB: float = 0.3  ## Extra heat per MB of malware stored

var total_credits: float = 0.0
var total_research: float = 0.0
var total_patch_data: float = 0.0
var total_neutralized: int = 0
var _tick_count: int = 0
var _malware_warning_shown: bool = false
var discovered_types: Dictionary = {"clean": true, "corrupted": false, "encrypted": false, "malware": false, "research": false}
var connection_manager: Node = null
var building_container: Node2D = null
var grid_system: Node2D = null
var connection_layer: Node2D = null

@onready var _sim_timer: Timer = $SimTimer


func _ready() -> void:
	_sim_timer.timeout.connect(_on_sim_tick)
	print("[Simulation] Manager initialized — tick: %.1fs" % _sim_timer.wait_time)


func _on_sim_tick() -> void:
	var buildings: Array[Node] = []
	for child in building_container.get_children():
		if child.has_method("is_active"):
			buildings.append(child)
	if buildings.is_empty():
		return
	# Reset work flags
	for b in buildings:
		b.is_working = false
	_update_power(buildings)
	_update_generation(buildings)
	_update_storage_forward(buildings)
	_update_processing(buildings)
	_update_research(buildings)
	_update_selling(buildings)
	_update_heat(buildings)
	_update_displays(buildings)
	_tick_count += 1
	tick_completed.emit(_tick_count)


# --- ZONE HELPERS (grid-aligned square) ---
# Target must be FULLY inside zone (all tiles of target within zone bounds)
func _is_in_zone(source: Node2D, target: Node2D) -> bool:
	var zone_radius: float = source.get_effective_value("zone_radius")
	if zone_radius <= 0.0:
		return false
	var tile_range: int = int(zone_radius / TILE_SIZE)
	var src_cell: Vector2i = source.grid_cell
	var src_size: Vector2i = source.definition.grid_size
	var tgt_cell: Vector2i = target.grid_cell
	var tgt_size: Vector2i = target.definition.grid_size
	# Zone extends tile_range tiles from building edges
	var zone_left: int = src_cell.x - tile_range
	var zone_top: int = src_cell.y - tile_range
	var zone_right: int = src_cell.x + src_size.x + tile_range - 1
	var zone_bottom: int = src_cell.y + src_size.y + tile_range - 1
	# All 4 corners of target must be inside zone
	var tgt_right: int = tgt_cell.x + tgt_size.x - 1
	var tgt_bottom: int = tgt_cell.y + tgt_size.y - 1
	return tgt_cell.x >= zone_left and tgt_right <= zone_right \
		and tgt_cell.y >= zone_top and tgt_bottom <= zone_bottom


# --- TILE-BASED ZONE CHECK ---
# Checks if a single tile is within a source building's zone
func _is_tile_in_zone(source: Node2D, tile: Vector2i) -> bool:
	var zone_radius: float = source.get_effective_value("zone_radius")
	if zone_radius <= 0.0:
		return false
	var tile_range: int = int(zone_radius / TILE_SIZE)
	var src_cell: Vector2i = source.grid_cell
	var src_size: Vector2i = source.definition.grid_size
	var zone_left: int = src_cell.x - tile_range
	var zone_top: int = src_cell.y - tile_range
	var zone_right: int = src_cell.x + src_size.x + tile_range - 1
	var zone_bottom: int = src_cell.y + src_size.y + tile_range - 1
	return tile.x >= zone_left and tile.x <= zone_right \
		and tile.y >= zone_top and tile.y <= zone_bottom


# --- POWER ZONE (tile-based) ---
func _update_power(buildings: Array[Node]) -> void:
	var power_cells: Array[Node] = []
	for b in buildings:
		if b.definition.power_provider != null:
			power_cells.append(b)

	for b in buildings:
		if b.definition.is_infrastructure():
			b.has_power = true
			continue
		var was_powered: bool = b.has_power
		b.has_power = _check_all_tiles_covered(b, power_cells)
		if was_powered != b.has_power:
			print("[Power] %s — %s" % [b.definition.building_name, "powered" if b.has_power else "no power"])


# Returns true if ANY tile of target is within source's zone
func _has_any_tile_in_zone(source: Node2D, target: Node2D) -> bool:
	var cell: Vector2i = target.grid_cell
	var size: Vector2i = target.definition.grid_size
	for ty in range(cell.y, cell.y + size.y):
		for tx in range(cell.x, cell.x + size.x):
			if _is_tile_in_zone(source, Vector2i(tx, ty)):
				return true
	return false


# Every tile of the building must be covered by at least one zone source
func _check_all_tiles_covered(b: Node2D, zone_sources: Array[Node]) -> bool:
	var cell: Vector2i = b.grid_cell
	var size: Vector2i = b.definition.grid_size
	for ty in range(cell.y, cell.y + size.y):
		for tx in range(cell.x, cell.x + size.x):
			var tile := Vector2i(tx, ty)
			var tile_covered: bool = false
			for src in zone_sources:
				if _is_tile_in_zone(src, tile):
					tile_covered = true
					break
			if not tile_covered:
				return false
	return true


# --- DATA GENERATION (Uplink) ---
func _update_generation(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.definition.generator == null or not b.is_active():
			continue
		var gen: GeneratorComponent = b.definition.generator
		var amount: int = int(gen.generation_rate)
		var total_pushed: int = 0
		for i in range(amount):
			var data_type: String = _roll_data_type(gen.data_weights)
			total_pushed += _push_data_from(b, data_type, 1)
		if total_pushed > 0:
			b.is_working = true


func _roll_data_type(weights: Dictionary) -> String:
	if weights.is_empty():
		return "clean"
	var roll: float = randf()
	var cumulative: float = 0.0
	for dtype in weights:
		cumulative += weights[dtype]
		if roll <= cumulative:
			return dtype
	return "clean"


func _push_data_from(source: Node2D, data_type: String, amount: int, from_port: String = "") -> int:
	var conns: Array[Dictionary] = connection_manager.get_connections()
	var targets: Array[Dictionary] = []
	for conn in conns:
		if conn.from_building == source:
			if from_port == "" or conn.from_port == from_port:
				targets.append(conn)
	if targets.is_empty():
		return 0
	# Distribute evenly among connected targets
	var per_target: int = maxi(1, amount / targets.size())
	var total_sent: int = 0
	for conn in targets:
		var target: Node2D = conn.to_building
		if not target.has_method("can_accept_data"):
			continue
		var to_send: int = mini(per_target, amount)
		if to_send <= 0:
			break
		if not target.accepts_data_type(data_type):
			continue
		if target.can_accept_data(to_send):
			target.stored_data[data_type] += to_send
			amount -= to_send
			total_sent += to_send
	return total_sent


# --- STORAGE FORWARD ---
func _update_storage_forward(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.definition.storage == null or not b.is_active():
			continue
		if b.definition.processor != null:
			continue  # Processor buildings handle their own output
		if b.get_total_stored() <= 0:
			continue
		# Forward stored data to connected buildings
		var conns: Array[Dictionary] = connection_manager.get_connections()
		var targets: Array[Dictionary] = []
		for conn in conns:
			if conn.from_building == b:
				targets.append(conn)
		if targets.is_empty():
			continue
		# Send up to forward_rate or all stored data (whichever is less)
		var stor: StorageComponent = b.definition.storage
		var max_forward: int = int(stor.forward_rate) if stor.forward_rate > 0 else b.get_total_stored()
		max_forward = maxi(1, max_forward)
		var sent: int = 0
		for dtype in b.stored_data:
			if sent >= max_forward:
				break
			var available: int = b.stored_data[dtype]
			if available <= 0:
				continue
			for conn in targets:
				if sent >= max_forward:
					break
				var target: Node2D = conn.to_building
				if not target.has_method("can_accept_data"):
					continue
				var to_send: int = mini(available, max_forward - sent)
				if target.can_accept_data(to_send):
					target.stored_data[dtype] += to_send
					b.stored_data[dtype] -= to_send
					sent += to_send
					available -= to_send
		if sent > 0:
			b.is_working = true


# --- PROCESSING (Separator, Compressor) ---
func _update_processing(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.definition.processor == null or not b.is_active():
			continue
		if b.get_total_stored() <= 0:
			continue
		var proc: ProcessorComponent = b.definition.processor
		var max_process: int = int(b.get_effective_value("processing_rate"))
		var processed: int = 0
		match proc.rule:
			"separator":
				processed = _process_separator(b, proc, max_process)
			"compressor":
				processed = _process_compressor(b, proc, max_process)
			"decryptor":
				processed = _process_decryptor(b, proc, max_process)
			"recoverer":
				processed = _process_recoverer(b, proc, max_process)
			"quarantine":
				processed = _process_quarantine(b, proc, max_process)
		if processed > 0:
			b.is_working = true
		# Clear processor buffer — unsent data is discarded (no accumulation)
		for dtype in b.stored_data:
			b.stored_data[dtype] = 0


func _process_separator(b: Node2D, _proc: ProcessorComponent, max_process: int) -> int:
	var eff: float = b.get_effective_value("efficiency")
	var primary_port: String = b.definition.output_ports[0] if b.definition.output_ports.size() > 0 else ""
	var secondary_port: String = b.definition.output_ports[1] if b.definition.output_ports.size() > 1 else ""
	var processed: int = 0
	for dtype in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data[dtype]
		if available <= 0:
			continue
		var to_process: int = mini(available, max_process - processed)
		var output_amount: int = maxi(1, roundi(to_process * eff))
		# Route by filter: matching type → primary port, rest → secondary port
		var target_port: String = primary_port if dtype == b.separator_filter else secondary_port
		if target_port == "":
			continue
		var sent: int = _push_data_from(b, dtype, output_amount, target_port)
		if sent > 0:
			b.stored_data[dtype] -= to_process
			processed += to_process
			# Discovery: first time separating a non-clean type
			if not discovered_types.get(dtype, false):
				discovered_types[dtype] = true
				data_type_discovered.emit(dtype)
				print("[Discovery] Yeni veri tipi keşfedildi: %s" % dtype)
	return processed


func _process_compressor(b: Node2D, _proc: ProcessorComponent, max_process: int) -> int:
	var eff: float = b.get_effective_value("efficiency")
	var processed: int = 0
	for dtype in b.stored_data:
		if processed >= max_process:
			break
		var available: int = b.stored_data[dtype]
		if available <= 0:
			continue
		var to_process: int = mini(available, max_process - processed)
		var output_amount: int = maxi(1, roundi(to_process * eff))
		var sent: int = _push_data_from(b, dtype, output_amount)
		if sent > 0:
			b.stored_data[dtype] -= to_process
			processed += to_process
	return processed


func _process_decryptor(b: Node2D, proc: ProcessorComponent, max_process: int) -> int:
	var eff: float = b.get_effective_value("efficiency")
	var processed: int = 0
	for dtype in proc.input_types:
		if processed >= max_process:
			break
		var available: int = b.stored_data.get(dtype, 0)
		if available <= 0:
			continue
		var to_process: int = mini(available, max_process - processed)
		var output_amount: int = maxi(1, roundi(to_process * eff))
		var sent: int = _push_data_from(b, "research", output_amount)
		if sent > 0:
			b.stored_data[dtype] -= to_process
			processed += to_process
			# Discovery: first time producing research data
			if not discovered_types.get("research", false):
				discovered_types["research"] = true
				data_type_discovered.emit("research")
				print("[Discovery] Yeni veri tipi keşfedildi: research")
	return processed


func _process_recoverer(b: Node2D, proc: ProcessorComponent, max_process: int) -> int:
	var eff: float = b.get_effective_value("efficiency")
	var processed: int = 0
	for dtype in proc.input_types:
		if processed >= max_process:
			break
		var available: int = b.stored_data.get(dtype, 0)
		if available <= 0:
			continue
		var to_process: int = mini(available, max_process - processed)
		var output_amount: int = maxi(1, roundi(to_process * eff))
		b.stored_data[dtype] -= to_process
		processed += to_process
		total_patch_data += output_amount
		patch_data_changed.emit(total_patch_data)
		print("[Recoverer] Processed %d corrupted → %d Patch Data" % [to_process, output_amount])
	return processed


func _process_quarantine(b: Node2D, proc: ProcessorComponent, max_process: int) -> int:
	var processed: int = 0
	for dtype in proc.input_types:
		if processed >= max_process:
			break
		var available: int = b.stored_data.get(dtype, 0)
		if available <= 0:
			continue
		var to_process: int = mini(available, max_process - processed)
		b.stored_data[dtype] -= to_process
		processed += to_process
		total_neutralized += to_process
		print("[Quarantine] Neutralized %d MB malware (total: %d)" % [to_process, total_neutralized])
	return processed


# --- RESEARCH COLLECTION (Research Lab) ---
func _update_research(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.definition.research_collector == null or not b.is_active():
			continue
		var rc: ResearchCollectorComponent = b.definition.research_collector
		var to_collect: int = int(rc.collection_rate)
		var collected: int = 0
		for accepted_type in rc.accepted_types:
			if collected >= to_collect:
				break
			var available: int = b.stored_data.get(accepted_type, 0)
			if available > 0:
				var collect_amount: int = mini(available, to_collect - collected)
				b.stored_data[accepted_type] -= collect_amount
				collected += collect_amount
		if collected > 0:
			b.is_working = true
			var earned: float = collected * rc.research_per_mb
			total_research += earned
			research_changed.emit(total_research)


# --- SELLING (Data Broker) ---
func _update_selling(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.definition.seller == null or not b.is_active():
			continue
		var sell: SellerComponent = b.definition.seller
		var to_sell: int = int(sell.sell_rate)
		var sold: int = 0
		# Sell accepted types from own buffer
		for accepted_type in sell.accepted_types:
			if sold >= to_sell:
				break
			var available: int = b.stored_data.get(accepted_type, 0)
			if available > 0:
				var sell_amount: int = mini(available, to_sell - sold)
				b.stored_data[accepted_type] -= sell_amount
				sold += sell_amount
		if sold > 0:
			b.is_working = true
			var earned: float = sold * sell.credits_per_mb
			total_credits += earned
			credits_changed.emit(total_credits)


# Count tiles occupied by working non-infrastructure buildings within a source's zone
func _count_working_tiles_in_zone(source: Node2D, buildings: Array[Node]) -> int:
	var tile_range: int = int(source.get_effective_value("zone_radius") / TILE_SIZE)
	var src_cell: Vector2i = source.grid_cell
	var src_size: Vector2i = source.definition.grid_size
	var zone_left: int = src_cell.x - tile_range
	var zone_top: int = src_cell.y - tile_range
	var zone_right: int = src_cell.x + src_size.x + tile_range - 1
	var zone_bottom: int = src_cell.y + src_size.y + tile_range - 1
	var count: int = 0
	for other in buildings:
		if other == source or other.definition.is_infrastructure():
			continue
		if not other.is_active() or not other.is_working:
			continue
		var o_cell: Vector2i = other.grid_cell
		var o_size: Vector2i = other.definition.grid_size
		for ty in range(o_cell.y, o_cell.y + o_size.y):
			for tx in range(o_cell.x, o_cell.x + o_size.x):
				if tx >= zone_left and tx <= zone_right and ty >= zone_top and ty <= zone_bottom:
					count += 1
	return count


# --- HEAT ---
func _update_heat(buildings: Array[Node]) -> void:
	# Phase 1: Generate heat for active buildings
	for b in buildings:
		if b.definition.coolant != null:
			continue
		if b.definition.power_provider != null:
			# Power Cell heats up based on how many tiles with working buildings are in its zone
			var working_tiles: int = _count_working_tiles_in_zone(b, buildings)
			b.current_heat += working_tiles * POWER_CELL_HEAT_PER_TILE
			continue
		if not b.is_active() or not b.is_working:
			continue
		b.current_heat += b.definition.heat_generation

	# Phase 1.5: Malware extra heat — buildings holding malware get extra heat
	for b in buildings:
		if b.definition.processor != null and b.definition.processor.rule == "quarantine":
			continue  # Quarantine is designed to hold malware safely
		var malware_count: int = b.stored_data.get("malware", 0)
		if malware_count > 0:
			b.current_heat += malware_count * MALWARE_HEAT_PER_MB
			if not _malware_warning_shown:
				_malware_warning_shown = true
				malware_damage_detected.emit(b)
				print("[Malware] WARNING: %s holding %d MB malware (+%.1f °C/s)" % [b.definition.building_name, malware_count, malware_count * MALWARE_HEAT_PER_MB])

	# Phase 2: Coolant Rig zone cooling (tile-based: combined coolant zones)
	var coolant_rigs: Array[Node] = []
	for b in buildings:
		if b.definition.coolant != null:
			coolant_rigs.append(b)
	if not coolant_rigs.is_empty():
		for target in buildings:
			if target.definition.coolant != null:
				continue
			if not _check_all_tiles_covered(target, coolant_rigs):
				continue
			# All tiles covered — apply cooling from each rig that touches this building
			for rig in coolant_rigs:
				if _has_any_tile_in_zone(rig, target):
					target.current_heat -= rig.get_effective_value("cooling_rate")

	# Phase 3: Natural cooling (only idle buildings) + clamping + overheat check
	for b in buildings:
		if not b.is_working:
			b.current_heat -= NATURAL_COOLING
		b.current_heat = clampf(b.current_heat, 0.0, b.definition.max_heat)
		if b.current_heat >= b.definition.max_heat:
			if not b.is_overheated:
				print("[Heat] %s OVERHEATED" % b.definition.building_name)
			b.is_overheated = true
		elif b.is_overheated and b.current_heat <= b.definition.max_heat * OVERHEAT_RECOVERY_RATIO:
			b.is_overheated = false
			print("[Heat] %s recovered from overheat" % b.definition.building_name)


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
	var cost: int = upg.costs[building.upgrade_level] if building.upgrade_level < upg.costs.size() else 0
	if total_patch_data < cost:
		return false
	total_patch_data -= cost
	patch_data_changed.emit(total_patch_data)
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
