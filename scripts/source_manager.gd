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

	# Generate per-instance state weight variation (content stays fixed)
	source.instance_state_weights = _randomize_state_weights(def.state_weights, _rng_seed)

	source_container.add_child(source)

	grid_system.occupy_source(source.cells, source)
	_sources.append(source)
	source_placed.emit(source)
	print("[SourceManager] Source placed — %s at (%d,%d), %dx%d" % [
		def.source_name, origin.x, origin.y, def.grid_size.x, def.grid_size.y])
	return source


## Randomize state weights with significant variation per instance.
## Content weights stay fixed — only state distribution varies.
func _randomize_state_weights(base_weights: Dictionary, seed_val: int) -> Dictionary:
	if base_weights.size() <= 1:
		return base_weights.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val >= 0 else randi()
	var result: Dictionary = {}
	var total: float = 0.0
	for key in base_weights:
		# Log-uniform multiplier: exp(-1.6)≈0.2 to exp(1.6)≈5.0
		var mult: float = exp(rng.randf_range(-1.6, 1.6))
		var val: float = base_weights[key] * mult
		result[key] = val
		total += val
	# Normalize to sum to 1.0
	if total > 0.0:
		for key in result:
			result[key] = snapped(result[key] / total, 0.01)
	return result


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
