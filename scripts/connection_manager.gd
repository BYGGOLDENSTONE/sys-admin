extends Node

signal connection_added(connection: Dictionary)
signal connection_removed(connection: Dictionary)

var connections: Array[Dictionary] = []
var grid_system: Node2D = null

const TILE_SIZE: int = 64


func add_connection(from_building: Node2D, from_port: String, to_building: Node2D, to_port: String, path: Array[Vector2i]) -> bool:
	if from_building == to_building:
		return false
	if path.is_empty():
		return false
	for conn in connections:
		if conn.to_building == to_building and conn.to_port == to_port:
			return false
	for conn in connections:
		if conn.from_building == from_building and conn.from_port == from_port:
			return false
	var conn := {
		"from_building": from_building,
		"from_port": from_port,
		"to_building": to_building,
		"to_port": to_port,
		"path": path.duplicate(),
	}
	connections.append(conn)
	for cell in path:
		grid_system.occupy_cable(cell)
	connection_added.emit(conn)
	print("[Connection] Added — %s.%s → %s.%s (%d segments)" % [
		from_building.definition.building_name, from_port,
		to_building.definition.building_name, to_port,
		path.size()
	])
	return true


func remove_connection(index: int) -> void:
	if index < 0 or index >= connections.size():
		return
	var conn: Dictionary = connections[index]
	for cell in conn.path:
		grid_system.free_cable(cell)
	connections.remove_at(index)
	connection_removed.emit(conn)
	print("[Connection] Removed — %s.%s → %s.%s" % [
		conn.from_building.definition.building_name, conn.from_port,
		conn.to_building.definition.building_name, conn.to_port
	])


func remove_connections_for(building: Node2D, _cell: Vector2i) -> void:
	var i: int = connections.size() - 1
	while i >= 0:
		var conn: Dictionary = connections[i]
		if conn.from_building == building or conn.to_building == building:
			for cell in conn.path:
				grid_system.free_cable(cell)
			var removed := conn.duplicate()
			connections.remove_at(i)
			connection_removed.emit(removed)
		i -= 1


func get_connections() -> Array[Dictionary]:
	return connections


func has_connection(from_building: Node2D, from_port: String, to_building: Node2D, to_port: String) -> bool:
	for conn in connections:
		if conn.from_building == from_building and conn.from_port == from_port \
				and conn.to_building == to_building and conn.to_port == to_port:
			return true
	return false


func get_connection_at_point(world_pos: Vector2) -> int:
	if grid_system == null:
		return -1
	var cell: Vector2i = grid_system.world_to_grid(world_pos)
	if not grid_system.has_cable_at(cell):
		return -1
	for i in range(connections.size()):
		if cell in connections[i].path:
			return i
	return -1


# --- PORT EXIT CELL ---

func get_port_exit_cell(building: Node2D, port_side: String) -> Vector2i:
	var bx: int = building.grid_cell.x
	var by: int = building.grid_cell.y
	var sw: int = building.definition.grid_size.x
	var sh: int = building.definition.grid_size.y
	match port_side:
		"right":
			return Vector2i(bx + sw, by + sh / 2)
		"left":
			return Vector2i(bx - 1, by + sh / 2)
		"top":
			return Vector2i(bx + sw / 2, by - 1)
		"bottom":
			return Vector2i(bx + sw / 2, by + sh)
	return Vector2i(bx + sw, by)


# --- PATHFINDING (L-SHAPED) ---

func calculate_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return [from] if grid_system.can_place_cable(from) else []
	var h_path: Array[Vector2i] = _l_path_horizontal_first(from, to)
	if _is_path_valid(h_path):
		return h_path
	var v_path: Array[Vector2i] = _l_path_vertical_first(from, to)
	if _is_path_valid(v_path):
		return v_path
	return []


func calculate_preview_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return [from]
	var h_path: Array[Vector2i] = _l_path_horizontal_first(from, to)
	if _is_path_valid(h_path):
		return h_path
	var v_path: Array[Vector2i] = _l_path_vertical_first(from, to)
	if _is_path_valid(v_path):
		return v_path
	return h_path


func _l_path_horizontal_first(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [from]
	var cx: int = from.x
	var cy: int = from.y
	var x_dir: int = 1 if to.x > from.x else -1 if to.x < from.x else 0
	var y_dir: int = 1 if to.y > from.y else -1 if to.y < from.y else 0
	while cx != to.x:
		cx += x_dir
		path.append(Vector2i(cx, cy))
	while cy != to.y:
		cy += y_dir
		path.append(Vector2i(cx, cy))
	return path


func _l_path_vertical_first(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [from]
	var cx: int = from.x
	var cy: int = from.y
	var x_dir: int = 1 if to.x > from.x else -1 if to.x < from.x else 0
	var y_dir: int = 1 if to.y > from.y else -1 if to.y < from.y else 0
	while cy != to.y:
		cy += y_dir
		path.append(Vector2i(cx, cy))
	while cx != to.x:
		cx += x_dir
		path.append(Vector2i(cx, cy))
	return path


func _is_path_valid(path: Array[Vector2i]) -> bool:
	for cell in path:
		if not grid_system.can_place_cable(cell):
			return false
	return true
