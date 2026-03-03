extends Node

signal credits_changed(new_total: float)

const TILE_SIZE: int = 64
const NATURAL_COOLING: float = 0.1
const OVERHEAT_RECOVERY_RATIO: float = 0.8
const POWER_CELL_HEAT_PER_BUILDING: float = 0.15  ## C/s per powered building

var total_credits: float = 0.0
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
	_update_selling(buildings)
	_update_heat(buildings)
	_update_displays(buildings)


# --- ZONE HELPERS (grid-aligned square) ---
# Target must be FULLY inside zone (all tiles of target within zone bounds)
func _is_in_zone(source: Node2D, target: Node2D) -> bool:
	var tile_range: int = int(source.definition.zone_radius / TILE_SIZE)
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


# --- POWER ZONE ---
func _update_power(buildings: Array[Node]) -> void:
	var power_cells: Array[Node] = []
	for b in buildings:
		if b.definition.building_type == "power":
			power_cells.append(b)

	for b in buildings:
		if b.definition.building_type in ["power", "coolant"]:
			b.has_power = true
			continue
		var was_powered: bool = b.has_power
		b.has_power = false
		for pc in power_cells:
			if _is_in_zone(pc, b):
				b.has_power = true
				break
		if was_powered != b.has_power:
			print("[Power] %s — %s" % [b.definition.building_name, "powered" if b.has_power else "no power"])


# --- DATA GENERATION (Uplink) ---
func _update_generation(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.definition.building_type != "generator" or not b.is_active():
			continue
		var amount: int = int(b.definition.generation_rate)
		var total_pushed: int = 0
		for i in range(amount):
			var data_type: String = _roll_data_type(b.definition.data_weights)
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


func _push_data_from(source: Node2D, data_type: String, amount: int) -> int:
	var conns: Array[Dictionary] = connection_manager.get_connections()
	var targets: Array[Dictionary] = []
	for conn in conns:
		if conn.from_building == source:
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
		if target.can_accept_data(to_send):
			target.stored_data[data_type] += to_send
			amount -= to_send
			total_sent += to_send
	return total_sent


# --- STORAGE FORWARD ---
func _update_storage_forward(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.definition.building_type != "storage" or not b.is_active():
			continue
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
		# Send up to generation_rate or all stored data (whichever is less)
		var max_forward: int = maxi(1, int(b.definition.generation_rate)) if b.definition.generation_rate > 0 else b.get_total_stored()
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


# --- SELLING (Data Broker) ---
func _update_selling(buildings: Array[Node]) -> void:
	for b in buildings:
		if b.definition.building_type != "seller" or not b.is_active():
			continue
		var to_sell: int = int(b.definition.sell_rate)
		var sold: int = 0
		# Sell clean data from own buffer
		var clean_available: int = b.stored_data.get("clean", 0)
		if clean_available > 0:
			var sell_amount: int = mini(clean_available, to_sell - sold)
			b.stored_data["clean"] -= sell_amount
			sold += sell_amount
		if sold > 0:
			b.is_working = true
			var earned: float = sold * b.definition.credits_per_mb
			total_credits += earned
			credits_changed.emit(total_credits)


# --- HEAT ---
func _update_heat(buildings: Array[Node]) -> void:
	# Phase 1: Generate heat for active buildings
	for b in buildings:
		if b.definition.building_type == "coolant":
			continue
		if b.definition.building_type == "power":
			# Power Cell heats up based on how many buildings it powers
			var powered_count: int = 0
			for other in buildings:
				if other == b or other.definition.building_type in ["power", "coolant"]:
					continue
				if _is_in_zone(b, other):
					powered_count += 1
			b.current_heat += powered_count * POWER_CELL_HEAT_PER_BUILDING
			continue
		if not b.is_active() or not b.is_working:
			continue
		b.current_heat += b.definition.heat_generation

	# Phase 2: Coolant Rig zone cooling
	for b in buildings:
		if b.definition.building_type != "coolant":
			continue
		for target in buildings:
			if target == b:
				continue
			if _is_in_zone(b, target):
				target.current_heat -= b.definition.cooling_rate

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


# --- BUILDING EVENTS ---
func _on_building_placed(_building: Node2D, _cell: Vector2i) -> void:
	pass


func _on_building_removed(_building: Node2D, _cell: Vector2i) -> void:
	pass
