extends Node

var building_manager: Node = null
var connection_manager: Node = null
var grid_system: Node2D = null
var source_manager: Node = null

var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
const MAX_COMMANDS: int = 50
var is_undoing: bool = false


func push_command(cmd: Dictionary) -> void:
	if is_undoing:
		return
	_undo_stack.append(cmd)
	_redo_stack.clear()
	if _undo_stack.size() > MAX_COMMANDS:
		_undo_stack.pop_front()


func undo() -> void:
	if _undo_stack.is_empty():
		return
	is_undoing = true
	var cmd: Dictionary = _undo_stack.pop_back()
	_execute_reverse(cmd)
	_redo_stack.append(cmd)
	is_undoing = false
	print("[Undo] %s undone" % cmd.type)


func redo() -> void:
	if _redo_stack.is_empty():
		return
	is_undoing = true
	var cmd: Dictionary = _redo_stack.pop_back()
	_execute_forward(cmd)
	_undo_stack.append(cmd)
	is_undoing = false
	print("[Redo] %s redone" % cmd.type)


func _execute_reverse(cmd: Dictionary) -> void:
	match cmd.type:
		"place":
			building_manager.remove_building_at(cmd.cell)
		"remove":
			_restore_building(cmd)
		"add_connection":
			_remove_connection_by_cells(cmd.from_cell, cmd.from_port, cmd.to_cell, cmd.to_port)
		"remove_connection":
			_add_connection_by_cells(cmd.from_cell, cmd.from_port, cmd.to_cell, cmd.to_port, cmd.get("path", []))
		"move":
			_move_building(cmd.new_cell, cmd.old_cell, cmd.definition)
			# Restore cables that existed before the original move
			for conn_data in cmd.get("connections", []):
				_add_connection_by_cells(conn_data.from_cell, conn_data.from_port, conn_data.to_cell, conn_data.to_port, conn_data.get("path", []))
		"rotate":
			_set_building_direction(cmd.cell, cmd.old_direction)
			for conn_data in cmd.get("connections", []):
				_add_connection_by_cells(conn_data.from_cell, conn_data.from_port, conn_data.to_cell, conn_data.to_port, conn_data.get("path", []))
		"mirror":
			_set_building_mirror(cmd.cell, cmd.old_mirror_h)
			for conn_data in cmd.get("connections", []):
				_add_connection_by_cells(conn_data.from_cell, conn_data.from_port, conn_data.to_cell, conn_data.to_port, conn_data.get("path", []))


func _execute_forward(cmd: Dictionary) -> void:
	match cmd.type:
		"place":
			var b = building_manager.place_building_at(cmd.definition, cmd.cell)
			if b:
				b.direction = cmd.get("direction", 0)
				b.mirror_h = cmd.get("mirror_h", false)
				b.queue_redraw()
		"remove":
			building_manager.remove_building_at(cmd.cell)
		"add_connection":
			_add_connection_by_cells(cmd.from_cell, cmd.from_port, cmd.to_cell, cmd.to_port, cmd.get("path", []))
		"remove_connection":
			_remove_connection_by_cells(cmd.from_cell, cmd.from_port, cmd.to_cell, cmd.to_port)
		"move":
			_move_building(cmd.old_cell, cmd.new_cell, cmd.definition)
		"rotate":
			_set_building_direction(cmd.cell, cmd.new_direction)
		"mirror":
			_set_building_mirror(cmd.cell, cmd.new_mirror_h)


func _restore_building(cmd: Dictionary) -> void:
	var building: Node2D = building_manager.place_building_at(cmd.definition, cmd.cell)
	if building == null:
		return
	building.direction = cmd.get("direction", 0)
	building.mirror_h = cmd.get("mirror_h", false)
	building.upgrade_level = cmd.get("upgrade_level", 0)
	building.classifier_filter_content = cmd.get("classifier_filter_content", 0)
	building.separator_mode = cmd.get("separator_mode", "state")
	building.separator_filter_value = cmd.get("separator_filter_value", 0)
	building.selected_tier = cmd.get("selected_tier", 1)
	building.queue_redraw()
	# Restore connections (path is stored as vertex array)
	for conn_data in cmd.get("connections", []):
		_add_connection_by_cells(conn_data.from_cell, conn_data.from_port, conn_data.to_cell, conn_data.to_port, conn_data.get("path", []))


func _add_connection_by_cells(from_cell: Vector2i, from_port: String, to_cell: Vector2i, to_port: String, path: Array[Vector2i] = []) -> void:
	var from_building: Node2D = grid_system.get_building_at(from_cell)
	if from_building == null:
		from_building = grid_system.get_source_at(from_cell)
	var to_building: Node2D = grid_system.get_building_at(to_cell)
	if to_building == null:
		to_building = grid_system.get_source_at(to_cell)
	if from_building and to_building:
		# Use stored path directly — no recalculation needed
		if not path.is_empty():
			connection_manager.add_connection(from_building, from_port, to_building, to_port, path)
		else:
			push_warning("[Undo] No path stored for connection %s.%s → %s.%s" % [from_cell, from_port, to_cell, to_port])


func _remove_connection_by_cells(from_cell: Vector2i, from_port: String, to_cell: Vector2i, to_port: String) -> void:
	var conns: Array[Dictionary] = connection_manager.get_connections()
	for i in range(conns.size()):
		var conn: Dictionary = conns[i]
		if conn.from_building.grid_cell == from_cell and conn.from_port == from_port \
				and conn.to_building.grid_cell == to_cell and conn.to_port == to_port:
			connection_manager.remove_connection(i)
			return


func _move_building(from_cell: Vector2i, to_cell: Vector2i, definition: BuildingDefinition) -> void:
	var building: Node2D = grid_system.get_building_at(from_cell)
	if building == null:
		return
	# Remove cables at current position — paths will be invalid after move
	connection_manager.remove_connections_for(building, from_cell)
	grid_system.free_cells(from_cell, definition.grid_size)
	if not grid_system.can_place(to_cell, definition.grid_size):
		grid_system.occupy(from_cell, definition.grid_size, building)
		return
	grid_system.occupy(to_cell, definition.grid_size, building)
	building.grid_cell = to_cell
	building.position = grid_system.grid_to_world(to_cell)


func _set_building_direction(cell: Vector2i, dir: int) -> void:
	var building: Node2D = grid_system.get_building_at(cell)
	if building == null:
		return
	connection_manager.remove_connections_for(building, cell)
	building.direction = dir
	building.queue_redraw()


func _set_building_mirror(cell: Vector2i, mirrored: bool) -> void:
	var building: Node2D = grid_system.get_building_at(cell)
	if building == null:
		return
	connection_manager.remove_connections_for(building, cell)
	building.mirror_h = mirrored
	building.queue_redraw()


func get_connections_for_building(building: Node2D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for conn in connection_manager.get_connections():
		if conn.from_building == building or conn.to_building == building:
			result.append({
				"from_cell": conn.from_building.grid_cell,
				"from_port": conn.from_port,
				"to_cell": conn.to_building.grid_cell,
				"to_port": conn.to_port,
				"path": conn.path.duplicate(),
			})
	return result
