extends Node

signal source_placed(source: Node2D)
signal uplink_linked(uplink: Node2D, source: Node2D)
signal uplink_unlinked(uplink: Node2D)

var grid_system: Node2D = null
var source_container: Node2D = null

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
	source_container.add_child(source)

	grid_system.occupy_source(shape, source)
	_sources.append(source)
	source_placed.emit(source)
	print("[SourceManager] Source placed — %s at (%d,%d), %d cells" % [def.source_name, origin.x, origin.y, shape.size()])
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
	if building.definition == null or building.definition.generator == null:
		return
	var source: Node2D = get_source_near(building.grid_cell, building.definition.grid_size)
	if source != null:
		link_uplink_to_source(building, source)


func on_building_removed(building: Node2D, _cell: Vector2i) -> void:
	if _uplink_source_map.has(building):
		unlink_uplink(building)


func get_all_sources() -> Array[Node2D]:
	return _sources


func get_source_for_uplink(uplink: Node2D) -> Node2D:
	return _uplink_source_map.get(uplink, null)


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
	frontier.shuffle()

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
