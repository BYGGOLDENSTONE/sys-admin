extends Node

signal connection_added(connection: Dictionary)
signal connection_removed(connection: Dictionary)

var connections: Array[Dictionary] = []
var grid_system: Node2D = null

const TILE_SIZE: int = 64


func add_connection(from_building: Node2D, from_port: String, to_building: Node2D, to_port: String, path: Array[Vector2i]) -> bool:
	if from_building == to_building:
		return false
	if path.size() < 2:
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
	# Occupy edges between consecutive vertices
	for i in range(path.size() - 1):
		grid_system.occupy_cable_edge(path[i], path[i + 1])
	connection_added.emit(conn)
	print("[Connection] Added — %s.%s → %s.%s (%d vertices)" % [
		from_building.definition.building_name, from_port,
		to_building.definition.building_name, to_port,
		path.size()
	])
	return true


func remove_connection(index: int) -> void:
	if index < 0 or index >= connections.size():
		return
	var conn: Dictionary = connections[index]
	var path: Array = conn.path
	for i in range(path.size() - 1):
		grid_system.free_cable_edge(path[i], path[i + 1])
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
			var path: Array = conn.path
			for j in range(path.size() - 1):
				grid_system.free_cable_edge(path[j], path[j + 1])
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
	var edge: Array = grid_system.get_cable_edge_at_point(world_pos)
	if edge.is_empty():
		return -1
	var ev1: Vector2i = edge[0]
	var ev2: Vector2i = edge[1]
	for i in range(connections.size()):
		var path: Array = connections[i].path
		for j in range(path.size() - 1):
			var pv1: Vector2i = path[j]
			var pv2: Vector2i = path[j + 1]
			# Check if this edge matches (order-independent)
			if (pv1 == ev1 and pv2 == ev2) or (pv1 == ev2 and pv2 == ev1):
				return i
	return -1


# --- PORT EXIT VERTICES ---

func get_port_exit_vertices(building: Node2D, port_side: String) -> Array[Vector2i]:
	## Returns grid vertices ONE cell away from building boundary, aligned with port.
	## Supports rotation (via building._get_physical_side) and indexed ports (left_0, left_1).
	var bx: int = building.grid_cell.x
	var by: int = building.grid_cell.y
	var sw: int = building.definition.grid_size.x
	var sh: int = building.definition.grid_size.y

	# Get physical side accounting for rotation
	var physical: String = building._get_physical_side(port_side)
	var base_side: String
	var us_pos: int = physical.find("_")
	if us_pos >= 0:
		base_side = physical.substr(0, us_pos)
	else:
		base_side = physical

	# Get port local pixel position (already accounts for rotation + indexing)
	var local_pos: Vector2 = building.get_port_local_position(port_side)

	match base_side:
		"right":
			var vx: int = bx + sw + 1
			var cell_y: float = local_pos.y / float(TILE_SIZE)
			var vy: int = roundi(cell_y)
			if absf(cell_y - float(vy)) < 0.01:
				return [Vector2i(vx, by + vy)]
			else:
				return [Vector2i(vx, by + floori(cell_y)), Vector2i(vx, by + floori(cell_y) + 1)]
		"left":
			var vx: int = bx - 1
			var cell_y: float = local_pos.y / float(TILE_SIZE)
			var vy: int = roundi(cell_y)
			if absf(cell_y - float(vy)) < 0.01:
				return [Vector2i(vx, by + vy)]
			else:
				return [Vector2i(vx, by + floori(cell_y)), Vector2i(vx, by + floori(cell_y) + 1)]
		"top":
			var vy: int = by - 1
			var cell_x: float = local_pos.x / float(TILE_SIZE)
			var vx: int = roundi(cell_x)
			if absf(cell_x - float(vx)) < 0.01:
				return [Vector2i(bx + vx, vy)]
			else:
				return [Vector2i(bx + floori(cell_x), vy), Vector2i(bx + floori(cell_x) + 1, vy)]
		"bottom":
			var vy: int = by + sh + 1
			var cell_x: float = local_pos.x / float(TILE_SIZE)
			var vx: int = roundi(cell_x)
			if absf(cell_x - float(vx)) < 0.01:
				return [Vector2i(bx + vx, vy)]
			else:
				return [Vector2i(bx + floori(cell_x), vy), Vector2i(bx + floori(cell_x) + 1, vy)]

	return [Vector2i(bx + sw + 1, by + sh / 2)]


func get_port_world_pos(building: Node2D, port_side: String) -> Vector2:
	## Returns the pixel position of the port (midpoint of building edge).
	return building.get_port_world_position(port_side)


# --- PATH VALIDATION ---

func is_path_valid(path: Array[Vector2i], exempt_cells: Dictionary = {}) -> bool:
	if path.size() < 2:
		return false
	for i in range(path.size() - 1):
		if not grid_system.can_place_cable_edge(path[i], path[i + 1], exempt_cells):
			return false
	# Check diagonal corners at every turn vertex
	for i in range(1, path.size() - 1):
		if grid_system.is_turn_corner_occupied(path[i], path[i - 1], path[i + 1], exempt_cells):
			return false
	return true
