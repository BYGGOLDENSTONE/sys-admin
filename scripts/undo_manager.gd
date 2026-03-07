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
	print("[Undo] %s geri alındı" % cmd.type)


func redo() -> void:
	if _redo_stack.is_empty():
		return
	is_undoing = true
	var cmd: Dictionary = _redo_stack.pop_back()
	_execute_forward(cmd)
	_undo_stack.append(cmd)
	is_undoing = false
	print("[Redo] %s tekrarlandı" % cmd.type)


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


func _execute_forward(cmd: Dictionary) -> void:
	match cmd.type:
		"place":
			building_manager.place_building_at(cmd.definition, cmd.cell)
		"remove":
			building_manager.remove_building_at(cmd.cell)
		"add_connection":
			_add_connection_by_cells(cmd.from_cell, cmd.from_port, cmd.to_cell, cmd.to_port, cmd.get("path", []))
		"remove_connection":
			_remove_connection_by_cells(cmd.from_cell, cmd.from_port, cmd.to_cell, cmd.to_port)
		"move":
			_move_building(cmd.old_cell, cmd.new_cell, cmd.definition)


func _restore_building(cmd: Dictionary) -> void:
	var building: Node2D = building_manager.place_building_at(cmd.definition, cmd.cell)
	if building == null:
		return
	building.upgrade_level = cmd.get("upgrade_level", 0)
	# Restore connections
	for conn_data in cmd.get("connections", []):
		_add_connection_by_cells(conn_data.from_cell, conn_data.from_port, conn_data.to_cell, conn_data.to_port, conn_data.get("path", []))


func _add_connection_by_cells(from_cell: Vector2i, from_port: String, to_cell: Vector2i, to_port: String, path: Array[Vector2i] = []) -> void:
	var from_building: Node2D = grid_system.get_building_at(from_cell)
	var to_building: Node2D = grid_system.get_building_at(to_cell)
	if from_building and to_building:
		if path.is_empty():
			var start: Vector2i = connection_manager.get_port_exit_cell(from_building, from_port)
			var end: Vector2i = connection_manager.get_port_exit_cell(to_building, to_port)
			path = connection_manager.calculate_path(start, end)
		connection_manager.add_connection(from_building, from_port, to_building, to_port, path)


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
	grid_system.free_cells(from_cell, definition.grid_size)
	if not grid_system.can_place(to_cell, definition.grid_size):
		grid_system.occupy(from_cell, definition.grid_size, building)
		return
	grid_system.occupy(to_cell, definition.grid_size, building)
	building.grid_cell = to_cell
	building.position = grid_system.grid_to_world(to_cell)
	# Re-check source link for Uplinks
	if building.definition.generator != null:
		source_manager.on_building_removed(building, from_cell)
		source_manager.on_building_placed(building, to_cell)


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
