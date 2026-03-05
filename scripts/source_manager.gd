extends Node

signal source_placed(source: Node2D)
signal source_discovered(source: Node2D)
signal uplink_linked(uplink: Node2D, source: Node2D)
signal uplink_unlinked(uplink: Node2D)

const REVEAL_RADIUS: int = 20  ## Manhattan distance from building to source origin

var grid_system: Node2D = null
var source_container: Node2D = null
var dev_mode: bool = false

var _source_scene: PackedScene = preload("res://scenes/data_source.tscn")
var _sources: Array[Node2D] = []
var _uplink_source_map: Dictionary = {}  ## uplink Node2D → source Node2D


func place_source(def: DataSourceDefinition, origin: Vector2i, rng_seed: int = -1) -> Node2D:
	var shape: Array[Vector2i] = _generate_organic_shape(origin, def.cell_count_range, rng_seed)
	if shape.is_empty():
		push_warning("[SourceManager] Failed to generate shape for %s at (%d,%d)" % [def.source_name, origin.x, origin.y])
		return null

	var source: Node2D = _source_scene.instantiate()
	source.setup(def, origin, shape)
	source.position = grid_system.grid_to_world(origin)

	# Ring 0 sources auto-discovered, others start hidden
	source.discovered = (def.ring_index == 0)
	source.dev_mode = dev_mode

	source_container.add_child(source)

	grid_system.occupy_source(shape, source)
	_sources.append(source)
	source_placed.emit(source)
	print("[SourceManager] Source placed — %s at (%d,%d), %d cells, discovered: %s" % [
		def.source_name, origin.x, origin.y, shape.size(), str(source.discovered)])
	return source


func get_source_near(building_cell: Vector2i, building_size: Vector2i) -> Node2D:
	## Check 1-tile border around building for any source cell
	for bx in range(building_cell.x - 1, building_cell.x + building_size.x + 1):
		for by in range(building_cell.y - 1, building_cell.y + building_size.y + 1):
			# Skip the building's own cells
			if bx >= building_cell.x and bx < building_cell.x + building_size.x \
				and by >= building_cell.y and by < building_cell.y + building_size.y:
				continue
			var source: Node = grid_system.get_source_at(Vector2i(bx, by))
			if source != null:
				return source
	return null


func link_uplink_to_source(uplink: Node2D, source: Node2D) -> void:
	uplink.linked_source = source
	uplink.runtime_content_weights = source.definition.content_weights.duplicate()
	uplink.runtime_state_weights = source.definition.state_weights.duplicate()
	_uplink_source_map[uplink] = source
	source._linked_uplinks += 1
	uplink_linked.emit(uplink, source)
	print("[SourceManager] Uplink linked to %s" % source.definition.source_name)


func unlink_uplink(uplink: Node2D) -> void:
	if _uplink_source_map.has(uplink):
		var source: Node2D = _uplink_source_map[uplink]
		source._linked_uplinks -= 1
		_uplink_source_map.erase(uplink)
		uplink_unlinked.emit(uplink)
		print("[SourceManager] Uplink unlinked from %s" % source.definition.source_name)
	uplink.linked_source = null
	uplink.runtime_content_weights = {}
	uplink.runtime_state_weights = {}


func on_building_placed(building: Node2D, _cell: Vector2i) -> void:
	if building.definition == null:
		return
	# Any building can trigger source discovery
	check_discovery_near(building.grid_cell, building.definition.grid_size)
	# Uplink auto-link (only to discovered sources)
	if building.definition.generator == null:
		return
	var source: Node2D = get_source_near(building.grid_cell, building.definition.grid_size)
	if source != null and source.discovered:
		link_uplink_to_source(building, source)


func on_building_removed(building: Node2D, _cell: Vector2i) -> void:
	if _uplink_source_map.has(building):
		unlink_uplink(building)


func check_discovery_near(building_cell: Vector2i, building_size: Vector2i) -> void:
	var b_center := Vector2(
		building_cell.x + building_size.x / 2.0,
		building_cell.y + building_size.y / 2.0
	)
	for source in _sources:
		if source.discovered:
			continue
		var s_origin := Vector2(source.grid_cell.x, source.grid_cell.y)
		var dist: int = int(abs(b_center.x - s_origin.x) + abs(b_center.y - s_origin.y))
		if dist <= REVEAL_RADIUS:
			reveal_source(source)


func reveal_source(source: Node2D) -> void:
	if source.discovered:
		return
	source.reveal()
	source_discovered.emit(source)
	print("[SourceManager] Source discovered — %s" % source.definition.source_name)
	# Auto-link any nearby unlinked Uplinks
	_auto_link_uplinks_near(source)


func _auto_link_uplinks_near(source: Node2D) -> void:
	var checked: Dictionary = {}
	for cell in source.cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var neighbor := Vector2i(cell.x + dx, cell.y + dy)
				if checked.has(neighbor):
					continue
				checked[neighbor] = true
				var building: Node = grid_system.get_building_at(neighbor)
				if building == null or not is_instance_valid(building):
					continue
				if building.definition == null or building.definition.generator == null:
					continue
				if _uplink_source_map.has(building):
					continue
				var nearby: Node2D = get_source_near(building.grid_cell, building.definition.grid_size)
				if nearby == source:
					link_uplink_to_source(building, source)


func set_dev_mode(enabled: bool) -> void:
	dev_mode = enabled
	for source in _sources:
		source.dev_mode = enabled


func get_all_sources() -> Array[Node2D]:
	return _sources


func get_discovered_sources() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for source in _sources:
		if source.discovered:
			result.append(source)
	return result


func get_source_for_uplink(uplink: Node2D) -> Node2D:
	return _uplink_source_map.get(uplink, null)


func clear_all_sources() -> void:
	for source in _sources:
		if is_instance_valid(source):
			grid_system.free_source_cells(source.cells)
			source.queue_free()
	_sources.clear()
	_uplink_source_map.clear()
	print("[SourceManager] All sources cleared")


## --- ORGANIC SHAPE GENERATION ---

func _generate_organic_shape(origin: Vector2i, count_range: Vector2i, rng_seed: int = -1) -> Array[Vector2i]:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	var target_count: int = rng.randi_range(count_range.x, count_range.y)
	var shape: Array[Vector2i] = []
	var visited: Dictionary = {}

	# Start from origin
	shape.append(origin)
	visited[origin] = true

	# Grow organically using random flood-fill
	var frontier: Array[Vector2i] = _get_neighbors(origin)
	# Shuffle using local rng for deterministic results with seed
	for i in range(frontier.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = frontier[i]
		frontier[i] = frontier[j]
		frontier[j] = tmp

	while shape.size() < target_count and not frontier.is_empty():
		# Pick a random frontier cell (weighted toward cells with more neighbors in shape)
		var best_idx: int = rng.randi_range(0, mini(frontier.size() - 1, 2))
		var cell: Vector2i = frontier[best_idx]
		frontier.remove_at(best_idx)

		if visited.has(cell):
			continue
		visited[cell] = true

		# Check grid bounds
		if cell.x < 0 or cell.x >= grid_system.GRID_WIDTH or cell.y < 0 or cell.y >= grid_system.GRID_HEIGHT:
			continue

		# Check not already occupied by building or another source
		if grid_system.get_building_at(cell) != null or grid_system.get_source_at(cell) != null:
			continue

		shape.append(cell)

		# Add new neighbors to frontier
		for neighbor in _get_neighbors(cell):
			if not visited.has(neighbor):
				# Insert at random position for organic feel
				frontier.insert(rng.randi_range(0, frontier.size()), neighbor)

	return shape


func _get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1),
	]
