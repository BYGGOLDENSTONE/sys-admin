extends Node

signal source_placed(source: Node2D)

var grid_system: Node2D = null
var source_container: Node2D = null
var dev_mode: bool = false

var _source_scene: PackedScene = preload("res://scenes/data_source.tscn")
var _sources: Array[Node2D] = []


func place_source(def: DataSourceDefinition, origin: Vector2i, _rng_seed: int = -1, _force_discovered: bool = false) -> Node2D:
	var source: Node2D = _source_scene.instantiate()
	source.setup(def, origin)
	source.position = grid_system.grid_to_world(origin)
	source.dev_mode = dev_mode

	source_container.add_child(source)

	grid_system.occupy_source(source.cells, source)
	_sources.append(source)
	source_placed.emit(source)
	print("[SourceManager] Source placed — %s at (%d,%d), %dx%d" % [
		def.source_name, origin.x, origin.y, def.grid_size.x, def.grid_size.y])
	return source


func on_building_removed(_building: Node2D, _cell: Vector2i) -> void:
	pass  # No action needed


func set_dev_mode(enabled: bool) -> void:
	dev_mode = enabled
	for source in _sources:
		source.dev_mode = enabled


func get_all_sources() -> Array[Node2D]:
	return _sources


func clear_all_sources() -> void:
	for source in _sources:
		if is_instance_valid(source):
			grid_system.free_source_cells(source.cells)
			source.queue_free()
	_sources.clear()
	print("[SourceManager] All sources cleared")
