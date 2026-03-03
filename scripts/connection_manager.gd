extends Node

signal connection_added(connection: Dictionary)
signal connection_removed(connection: Dictionary)

var connections: Array[Dictionary] = []


func add_connection(from_building: Node2D, from_port: String, to_building: Node2D, to_port: String) -> bool:
	if has_connection(from_building, from_port, to_building, to_port):
		return false
	# Don't allow connecting a building to itself
	if from_building == to_building:
		return false
	# Don't allow duplicate connections to the same input port
	for conn in connections:
		if conn.to_building == to_building and conn.to_port == to_port:
			return false
	# Don't allow duplicate connections from the same output port
	for conn in connections:
		if conn.from_building == from_building and conn.from_port == from_port:
			return false
	var conn := {
		"from_building": from_building,
		"from_port": from_port,
		"to_building": to_building,
		"to_port": to_port,
	}
	connections.append(conn)
	connection_added.emit(conn)
	print("[Connection] Added — %s.%s → %s.%s" % [
		from_building.definition.building_name, from_port,
		to_building.definition.building_name, to_port
	])
	return true


func remove_connection(index: int) -> void:
	if index < 0 or index >= connections.size():
		return
	var conn: Dictionary = connections[index]
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


func get_connection_at_point(world_pos: Vector2, threshold: float = 10.0) -> int:
	var closest_index: int = -1
	var closest_dist: float = threshold
	for i in range(connections.size()):
		var conn: Dictionary = connections[i]
		var from_pos: Vector2 = conn.from_building.get_port_world_position(conn.from_port)
		var to_pos: Vector2 = conn.to_building.get_port_world_position(conn.to_port)
		var dist := _point_to_bezier_distance(world_pos, from_pos, to_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_index = i
	return closest_index


func _point_to_bezier_distance(point: Vector2, from_pos: Vector2, to_pos: Vector2) -> float:
	var min_dist: float = INF
	var dx: float = absf(to_pos.x - from_pos.x) * 0.4
	var cp1 := from_pos + Vector2(dx, 0)
	var cp2 := to_pos - Vector2(dx, 0)
	var steps: int = 20
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var bezier_point := _cubic_bezier(from_pos, cp1, cp2, to_pos, t)
		var dist := point.distance_to(bezier_point)
		if dist < min_dist:
			min_dist = dist
	return min_dist


func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
