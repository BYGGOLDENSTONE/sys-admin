extends Node

signal source_placed(source: Node2D)
signal source_discovered(source: Node2D)

const REVEAL_RADIUS: int = 20  ## Manhattan distance from building to source origin

var grid_system: Node2D = null
var source_container: Node2D = null
var dev_mode: bool = false

var _source_scene: PackedScene = preload("res://scenes/data_source.tscn")
var _sources: Array[Node2D] = []


func place_source(def: DataSourceDefinition, origin: Vector2i, _rng_seed: int = -1, force_discovered: bool = false) -> Node2D:
	var source: Node2D = _source_scene.instantiate()
	source.setup(def, origin)
	source.position = grid_system.grid_to_world(origin)

	# Easy sources auto-discovered; tutorial guarantees forced visible
	source.discovered = (def.difficulty == "easy") or force_discovered
	source.dev_mode = dev_mode

	source_container.add_child(source)

	grid_system.occupy_source(source.cells, source)
	_sources.append(source)
	source_placed.emit(source)
	print("[SourceManager] Source placed — %s at (%d,%d), %dx%d, discovered: %s" % [
		def.source_name, origin.x, origin.y, def.grid_size.x, def.grid_size.y, str(source.discovered)])
	return source


func on_building_placed(building: Node2D, _cell: Vector2i) -> void:
	if building.definition == null:
		return
	# Any building can trigger source discovery
	check_discovery_near(building.grid_cell, building.definition.grid_size)


func on_building_removed(_building: Node2D, _cell: Vector2i) -> void:
	pass  # No action needed (Uplink linking removed)


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


func reveal_hard_sources_near_spawn(center: Vector2i, radius: int) -> void:
	## "See but can't process" hook — reveal hard/endgame sources near spawn
	for source in _sources:
		if source.discovered:
			continue
		if source.definition.difficulty != "hard" and source.definition.difficulty != "endgame":
			continue
		var dist: int = abs(source.grid_cell.x - center.x) + abs(source.grid_cell.y - center.y)
		if dist <= radius:
			source.discovered = true
			print("[SourceManager] Hard source pre-revealed near spawn — %s" % source.definition.source_name)


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


func clear_all_sources() -> void:
	for source in _sources:
		if is_instance_valid(source):
			grid_system.free_source_cells(source.cells)
			source.queue_free()
	_sources.clear()
	print("[SourceManager] All sources cleared")
