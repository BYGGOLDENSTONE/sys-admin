extends Node

signal building_placed(building: Node2D, cell: Vector2i)
signal building_removed(building: Node2D, cell: Vector2i)
signal building_hovered(building: Node2D)
signal building_unhovered()
signal building_selected(building: Node2D)
signal building_deselected()
signal source_hovered(source: Node2D)
signal source_unhovered()
signal source_selected(source: Node2D)
signal building_state_changed()

enum State { IDLE, PLACING, CONNECTING, MOVING, BOX_SELECTING, COPYING }

@onready var grid_system: Node2D = $"../GridSystem"
@onready var building_container: Node2D = $"../BuildingContainer"
@onready var ghost_preview: Node2D = $"../GhostPreview"

var connection_manager: Node = null
var connection_layer: Node2D = null
var undo_manager: Node = null
var source_manager: Node = null

var _building_scene: PackedScene = preload("res://scenes/building.tscn")
var _state: State = State.IDLE
var _current_definition: BuildingDefinition = null
var _ghost_cell: Vector2i = Vector2i.ZERO
var _can_place_here: bool = false
var _hovered_building: Node2D = null
var _hovered_source: Node2D = null
var _selected_building: Node2D = null

# Connecting state
var _connecting_from_building: Node2D = null
var _connecting_from_port: String = ""
var _connecting_reversed: bool = false  ## True when cable started from input port
var _cable_path: Array[Vector2i] = []  ## Vertex-based path built manually
var _start_vertices: Array[Vector2i] = []  ## Two possible starting vertices near port
var _start_initialized: bool = false
var _last_mouse_vertex: Vector2i = Vector2i(-9999, -9999)  ## Track mouse grid position

# Moving state
var _moving_building: Node2D = null
var _moving_original_cell: Vector2i = Vector2i.ZERO

# Box selection state
var _box_start_world: Vector2 = Vector2.ZERO
var _box_end_world: Vector2 = Vector2.ZERO
var _selected_buildings: Array[Node2D] = []
var _selected_connections: Array[Dictionary] = []  ## {from_cell, from_port, to_cell, to_port, path}

# Copy/paste state
var _copy_buffer: Array[Dictionary] = []  ## [{definition, offset, direction, mirror_h, mirror_v, ...}]
var _copy_connections: Array[Dictionary] = []  ## [{from_offset, from_port, to_offset, to_port, path_offsets}]
var _copy_anchor: Vector2i = Vector2i.ZERO  ## Anchor cell for paste preview

# Uplink paired placement state
var _uplink_pending_input: Node2D = null  ## First uplink placed, awaiting partner
var _uplink_output_def: BuildingDefinition = null  ## Cached definition for output uplink
var _uplink_removing: bool = false  ## Guard against recursive partner removal

# Exempt cells for cable routing (cells near port exit vertices)
var _cable_exempt_cells: Dictionary = {}

const VALID_COLOR := Color(0, 1, 0.5, 0.4)
const INVALID_COLOR := Color(1, 0.2, 0.2, 0.4)
const TILE_SIZE: int = 64


func start_placement(def: BuildingDefinition) -> void:
	_cancel_connecting()
	_deselect_building()
	_clear_cable_hover()
	_current_definition = def
	_state = State.PLACING
	ghost_preview.visible = true
	ghost_preview._is_ghost = true
	ghost_preview.setup(def, Vector2i.ZERO)
	# Clear hover when entering placement mode
	if _hovered_building != null:
		_hovered_building = null
		building_unhovered.emit()
	print("[BuildingManager] Placement started — building: %s" % def.building_name)


func cancel_placement() -> void:
	if _state != State.PLACING:
		return
	# Uplink pair: if we're waiting for second placement, remove the first one too
	if _uplink_pending_input != null and is_instance_valid(_uplink_pending_input):
		_remove_building(_uplink_pending_input)
		_uplink_pending_input = null
	_state = State.IDLE
	_current_definition = null
	ghost_preview.visible = false
	print("[BuildingManager] Placement cancelled")


func _cancel_connecting() -> void:
	if _state != State.CONNECTING:
		return
	_state = State.IDLE
	_connecting_from_building = null
	_connecting_from_port = ""
	_connecting_reversed = false
	_cable_path.clear()
	_start_vertices.clear()
	_start_initialized = false
	_last_mouse_vertex = Vector2i(-9999, -9999)
	_cable_exempt_cells.clear()
	if connection_layer:
		connection_layer.preview_active = false
		connection_layer.preview_blocked = false
	print("[BuildingManager] Connection cancelled")


func _unhandled_input(event: InputEvent) -> void:
	match _state:
		State.IDLE:
			_handle_idle_input(event)
		State.PLACING:
			_handle_placing_input(event)
		State.CONNECTING:
			_handle_connecting_input(event)
		State.MOVING:
			_handle_moving_input(event)
		State.BOX_SELECTING:
			_handle_box_selecting_input(event)
		State.COPYING:
			_handle_copying_input(event)


func _process(_delta: float) -> void:
	if _state == State.PLACING:
		_update_ghost_position()
	elif _state == State.IDLE:
		_update_hover()
		_update_cable_hover()
	elif _state == State.CONNECTING:
		_update_manual_routing()
	elif _state == State.MOVING:
		_update_move_preview()
	elif _state == State.BOX_SELECTING:
		_box_end_world = _get_world_mouse_position()
		_update_selection_overlay()
	elif _state == State.COPYING:
		_update_copy_preview()


func _handle_idle_input(event: InputEvent) -> void:
	# E key: cycle filter on selected building (Classifier/Separator)
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if _selected_building != null:
			_cycle_building_filter(_selected_building)
		return
	# R key: rotate selected building
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if _selected_building != null:
			_rotate_selected_building()
		return
	# T key: mirror selected building (T=horizontal, Shift+T=vertical)
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if _selected_building != null:
			if event.shift_pressed:
				_mirror_selected_building_v()
			else:
				_mirror_selected_building()
		return
	# C key: copy selected building(s)
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		if not _selected_buildings.is_empty():
			_copy_selection()
		elif _selected_building != null:
			_copy_single_building(_selected_building)
		return
	# Delete key: delete selected building(s)
	if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		if not _selected_buildings.is_empty():
			_delete_selected_buildings()
		elif _selected_building != null:
			_remove_building(_selected_building)
		return
	if not (event is InputEventMouseButton and event.pressed):
		return

	var world_pos := _get_world_mouse_position()

	if event.button_index == MOUSE_BUTTON_LEFT:
		# Shift+click: start box selection
		if Input.is_key_pressed(KEY_SHIFT):
			_start_box_selection(world_pos)
			return
		# Ctrl+click on building: start moving
		if Input.is_key_pressed(KEY_CTRL):
			var cell: Vector2i = grid_system.world_to_grid(world_pos)
			var building: Node = grid_system.get_building_at(cell)
			if building != null:
				_start_moving(building)
				return

		# Check if clicking on an output port
		var port_info := _find_port_at(world_pos, true)
		if not port_info.is_empty():
			_start_connecting(port_info.building, port_info.side, false)
			return
		# Check if clicking on an input port (reversed cable drawing)
		var input_port_info := _find_port_at(world_pos, false)
		if not input_port_info.is_empty():
			_start_connecting(input_port_info.building, input_port_info.side, true)
			return

		# Click on building or source: select it
		var cell: Vector2i = grid_system.world_to_grid(world_pos)
		var clicked: Node = grid_system.get_building_at(cell)
		if clicked != null:
			_select_building(clicked)
		else:
			# Check if clicking on a source
			var clicked_source: Node2D = grid_system.get_source_at(cell) if grid_system.has_method("get_source_at") else null
			if clicked_source != null:
				_deselect_building()
				source_selected.emit(clicked_source)
			else:
				_deselect_building()
				_clear_box_selection()
				_update_selection_overlay()

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Try to delete a cable first
		if connection_manager and connection_manager.get_connection_at_point(world_pos) >= 0:
			var idx: int = connection_manager.get_connection_at_point(world_pos)
			var conns: Array[Dictionary] = connection_manager.get_connections()
			if idx >= 0 and idx < conns.size():
				var conn: Dictionary = conns[idx]
				# Cable removal flash
				if connection_layer:
					connection_layer.play_removal_flash(
						connection_layer._build_polyline(conn),
						Color(1.0, 0.3, 0.3))
				if undo_manager and not undo_manager.is_undoing:
					undo_manager.push_command({
						type = "remove_connection",
						from_cell = conn.from_building.grid_cell,
						from_port = conn.from_port,
						to_cell = conn.to_building.grid_cell,
						to_port = conn.to_port,
						path = conn.path.duplicate(),
					})
			connection_manager.remove_connection(idx)
			return
		# Otherwise try to delete a building
		var cell: Vector2i = grid_system.world_to_grid(world_pos)
		var building: Node = grid_system.get_building_at(cell)
		if building != null:
			_remove_building(building)


func _handle_placing_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		ghost_preview.direction = (ghost_preview.direction + 1) % 4
		ghost_preview.queue_redraw()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if event.shift_pressed:
			ghost_preview.mirror_v = not ghost_preview.mirror_v
		else:
			ghost_preview.mirror_h = not ghost_preview.mirror_h
		ghost_preview.queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _can_place_here:
			_place_building()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_placement()


func _handle_connecting_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var world_pos := _get_world_mouse_position()
			if _connecting_reversed:
				# Started from input — look for output port to complete
				var port_info := _find_port_at(world_pos, true)
				if not port_info.is_empty():
					_complete_connection_reversed(port_info.building, port_info.side)
			else:
				# Started from output — look for input port to complete
				var port_info := _find_port_at(world_pos, false)
				if not port_info.is_empty():
					_complete_connection(port_info.building, port_info.side)
			# Don't cancel on empty left click — cable follows mouse movement
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_connecting()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_connecting()


func _start_connecting(building: Node2D, port_side: String, reversed: bool = false) -> void:
	_connecting_from_building = building
	_connecting_from_port = port_side
	_connecting_reversed = reversed
	_cable_path.clear()
	_start_initialized = false
	# Get the two possible starting vertices near the port
	_start_vertices = connection_manager.get_port_exit_vertices(building, port_side)
	# Compute exempt cells around exit vertices (so cable can leave port area)
	_cable_exempt_cells = _compute_port_exempt_cells(building, port_side)
	_state = State.CONNECTING
	# Clear hover
	if _hovered_building != null:
		_hovered_building = null
		building_unhovered.emit()
	var from_name: String = building.definition.building_name if building.definition is BuildingDefinition else building.definition.source_name
	var dir_label: String = " (from input)" if reversed else ""
	print("[BuildingManager] Connecting from %s.%s%s" % [from_name, port_side, dir_label])


func _complete_connection(to_building: Node2D, to_port: String) -> void:
	if connection_manager == null or _cable_path.size() < 2:
		_cancel_connecting()
		return
	# Find closest exit vertex
	var target_verts: Array[Vector2i] = connection_manager.get_port_exit_vertices(to_building, to_port)
	if target_verts.is_empty():
		_cancel_connecting()
		return
	# Combine exempt cells: FROM building + TO building port areas
	var combined_exempt: Dictionary = _cable_exempt_cells.duplicate()
	var to_exempt: Dictionary = _compute_port_exempt_cells(to_building, to_port)
	for cell in to_exempt:
		combined_exempt[cell] = true
	# TRUNCATE: if cable already passed through a target exit vertex, cut back to it
	for tv in target_verts:
		var idx: int = _cable_path.find(tv)
		if idx >= 1:  # skip index 0 (that's the FROM building's exit)
			_cable_path.resize(idx + 1)
			break
	var last_v: Vector2i = _cable_path[_cable_path.size() - 1]
	# Check if we already reached a target vertex after truncation
	if not (last_v in target_verts):
		var best: Vector2i = target_verts[0]
		var best_dist: int = absi(last_v.x - best.x) + absi(last_v.y - best.y)
		for tv in target_verts:
			var d: int = absi(last_v.x - tv.x) + absi(last_v.y - tv.y)
			if d < best_dist:
				best_dist = d
				best = tv
		# Snap: extend up to 3 steps to reach exit vertex with exempt cells
		if best_dist <= 3:
			var snap_path: Array[Vector2i] = _find_snap_path(last_v, best, combined_exempt, 3)
			if not snap_path.is_empty():
				for sv in snap_path:
					_cable_path.append(sv)
		# Verify cable reached an exit vertex
		last_v = _cable_path[_cable_path.size() - 1]
		if not (last_v in target_verts):
			# Try other exit vertices too
			for tv in target_verts:
				if tv == last_v:
					continue
				var td: int = absi(last_v.x - tv.x) + absi(last_v.y - tv.y)
				if td <= 3:
					var snap_path2: Array[Vector2i] = _find_snap_path(last_v, tv, combined_exempt, 3)
					if not snap_path2.is_empty():
						for sv in snap_path2:
							_cable_path.append(sv)
						break
	last_v = _cable_path[_cable_path.size() - 1]
	if not (last_v in target_verts):
		print("[BuildingManager] Cable must reach port — path end %s, targets %s" % [last_v, target_verts])
		_cancel_connecting()
		return
	# Validate the path with combined exempt cells
	if _cable_path.size() < 2 or not connection_manager.is_path_valid(_cable_path, combined_exempt):
		print("[BuildingManager] Cannot route cable — path invalid")
		_cancel_connecting()
		return
	var added: bool = connection_manager.add_connection(
		_connecting_from_building, _connecting_from_port, to_building, to_port, _cable_path
	)
	if added and undo_manager and not undo_manager.is_undoing:
		undo_manager.push_command({
			type = "add_connection",
			from_cell = _connecting_from_building.grid_cell,
			from_port = _connecting_from_port,
			to_cell = to_building.grid_cell,
			to_port = to_port,
			path = _cable_path.duplicate(),
		})
	_state = State.IDLE
	_connecting_from_building = null
	_connecting_from_port = ""
	_cable_path.clear()
	_start_vertices.clear()
	_start_initialized = false
	_last_mouse_vertex = Vector2i(-9999, -9999)
	_cable_exempt_cells.clear()
	if connection_layer:
		connection_layer.preview_active = false
		connection_layer.play_connection_flash(to_building)
	# Camera shake feedback on cable connection
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.08)


func _complete_connection_reversed(output_building: Node2D, output_port: String) -> void:
	## Complete a cable that was started from an INPUT port.
	## The visual path goes input→output, but the connection is stored output→input.
	if connection_manager == null or _cable_path.size() < 2:
		_cancel_connecting()
		return
	# Target is the output port we just clicked
	var target_verts: Array[Vector2i] = connection_manager.get_port_exit_vertices(output_building, output_port)
	if target_verts.is_empty():
		_cancel_connecting()
		return
	# Combine exempt cells
	var combined_exempt: Dictionary = _cable_exempt_cells.duplicate()
	var to_exempt: Dictionary = _compute_port_exempt_cells(output_building, output_port)
	for cell in to_exempt:
		combined_exempt[cell] = true
	# Truncate + snap (same logic as forward connection)
	for tv in target_verts:
		var idx: int = _cable_path.find(tv)
		if idx >= 1:
			_cable_path.resize(idx + 1)
			break
	var last_v: Vector2i = _cable_path[_cable_path.size() - 1]
	if not (last_v in target_verts):
		var best: Vector2i = target_verts[0]
		var best_dist: int = absi(last_v.x - best.x) + absi(last_v.y - best.y)
		for tv in target_verts:
			var d: int = absi(last_v.x - tv.x) + absi(last_v.y - tv.y)
			if d < best_dist:
				best_dist = d
				best = tv
		if best_dist <= 3:
			var snap_path: Array[Vector2i] = _find_snap_path(last_v, best, combined_exempt, 3)
			if not snap_path.is_empty():
				for sv in snap_path:
					_cable_path.append(sv)
		last_v = _cable_path[_cable_path.size() - 1]
		if not (last_v in target_verts):
			for tv in target_verts:
				if tv == last_v:
					continue
				var td: int = absi(last_v.x - tv.x) + absi(last_v.y - tv.y)
				if td <= 3:
					var snap_path2: Array[Vector2i] = _find_snap_path(last_v, tv, combined_exempt, 3)
					if not snap_path2.is_empty():
						for sv in snap_path2:
							_cable_path.append(sv)
						break
	last_v = _cable_path[_cable_path.size() - 1]
	if not (last_v in target_verts):
		print("[BuildingManager] Cable must reach port — path end %s, targets %s" % [last_v, target_verts])
		_cancel_connecting()
		return
	# Validate path
	if _cable_path.size() < 2 or not connection_manager.is_path_valid(_cable_path, combined_exempt):
		print("[BuildingManager] Cannot route cable — path invalid")
		_cancel_connecting()
		return
	# REVERSE: connection is stored as output→input, path is reversed
	var reversed_path: Array[Vector2i] = []
	for i in range(_cable_path.size() - 1, -1, -1):
		reversed_path.append(_cable_path[i])
	# output_building.output_port → _connecting_from_building._connecting_from_port
	var added: bool = connection_manager.add_connection(
		output_building, output_port, _connecting_from_building, _connecting_from_port, reversed_path
	)
	if added and undo_manager and not undo_manager.is_undoing:
		undo_manager.push_command({
			type = "add_connection",
			from_cell = output_building.grid_cell,
			from_port = output_port,
			to_cell = _connecting_from_building.grid_cell,
			to_port = _connecting_from_port,
			path = reversed_path.duplicate(),
		})
	var input_building: Node2D = _connecting_from_building
	_state = State.IDLE
	_connecting_from_building = null
	_connecting_from_port = ""
	_connecting_reversed = false
	_cable_path.clear()
	_start_vertices.clear()
	_start_initialized = false
	_last_mouse_vertex = Vector2i(-9999, -9999)
	_cable_exempt_cells.clear()
	if connection_layer:
		connection_layer.preview_active = false
		connection_layer.play_connection_flash(input_building if input_building else output_building)
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.08)


func _update_manual_routing() -> void:
	if connection_layer == null or _connecting_from_building == null or connection_manager == null:
		return
	var mouse_pos := _get_world_mouse_position()
	var mouse_vertex: Vector2i = grid_system.world_to_vertex(mouse_pos)
	var from_pos: Vector2 = _connecting_from_building.get_port_world_position(_connecting_from_port)

	# Initialize starting vertex based on which is closer to mouse
	if not _start_initialized:
		_cable_path.clear()
		if _start_vertices.size() >= 2:
			var d0: float = mouse_pos.distance_to(grid_system.vertex_to_world(_start_vertices[0]))
			var d1: float = mouse_pos.distance_to(grid_system.vertex_to_world(_start_vertices[1]))
			var chosen: Vector2i = _start_vertices[0] if d0 <= d1 else _start_vertices[1]
			_cable_path.append(chosen)
		elif _start_vertices.size() == 1:
			_cable_path.append(_start_vertices[0])
		_start_initialized = true
		_last_mouse_vertex = mouse_vertex

	if _cable_path.is_empty():
		return

	# Only process path changes when mouse moves to a new grid vertex
	if mouse_vertex != _last_mouse_vertex:
		var old_vertex := _last_mouse_vertex
		_last_mouse_vertex = mouse_vertex
		_process_vertex_movement(old_vertex, mouse_vertex)

	# Always update preview (smooth cursor tracking for render)
	var valid: bool = _cable_path.size() >= 2 and connection_manager.is_path_valid(_cable_path, _cable_exempt_cells)
	# Check if cable is stuck (can't reach mouse vertex)
	var last_v: Vector2i = _cable_path[_cable_path.size() - 1] if not _cable_path.is_empty() else mouse_vertex
	var is_blocked: bool = mouse_vertex != last_v
	connection_layer.preview_path = _cable_path
	connection_layer.preview_valid = valid
	connection_layer.preview_blocked = is_blocked
	connection_layer.preview_from_pos = from_pos
	connection_layer.preview_from_port = _connecting_from_building._get_physical_side(_connecting_from_port)
	connection_layer.preview_to_pos = mouse_pos
	connection_layer.preview_active = true


func _process_vertex_movement(old_vertex: Vector2i, new_vertex: Vector2i) -> void:
	## Process mouse movement from one grid vertex to another.
	## Interpolates through intermediate vertices for fast mouse movement.
	var steps := _interpolate_vertices(old_vertex, new_vertex)
	for v in steps:
		if _cable_path.is_empty():
			break
		var last_v: Vector2i = _cable_path[_cable_path.size() - 1]

		# Backtrack: if vertex exists earlier in path, truncate to it
		var back_idx: int = _cable_path.find(v)
		if back_idx >= 0 and back_idx < _cable_path.size() - 1:
			_cable_path.resize(back_idx + 1)
			continue

		# Extend: only if adjacent to path end (Manhattan distance == 1)
		var diff: Vector2i = v - last_v
		if absi(diff.x) + absi(diff.y) == 1:
			if _can_extend_to(last_v, v):
				_cable_path.append(v)


func _interpolate_vertices(from_v: Vector2i, to_v: Vector2i) -> Array[Vector2i]:
	## Generate step-by-step vertex path between two vertices (Manhattan walk).
	## Used to fill in skipped vertices when mouse moves fast.
	var result: Array[Vector2i] = []
	var total_dist: int = absi(to_v.x - from_v.x) + absi(to_v.y - from_v.y)
	if total_dist > 30:
		# Mouse jumped too far — just return target
		result.append(to_v)
		return result
	var current := from_v
	for _i in range(total_dist):
		var remaining: Vector2i = to_v - current
		if remaining == Vector2i.ZERO:
			break
		var step: Vector2i
		if remaining.x == 0:
			step = Vector2i(0, signi(remaining.y))
		elif remaining.y == 0:
			step = Vector2i(signi(remaining.x), 0)
		else:
			# Diagonal: prefer axis with greater remaining distance
			if absi(remaining.x) >= absi(remaining.y):
				step = Vector2i(signi(remaining.x), 0)
			else:
				step = Vector2i(0, signi(remaining.y))
		current = current + step
		result.append(current)
	return result


func _can_extend_to(from_v: Vector2i, to_v: Vector2i, exempt_override: Dictionary = {}) -> bool:
	if to_v in _cable_path:
		return false  # prevent loops
	var exempt: Dictionary = exempt_override if not exempt_override.is_empty() else _cable_exempt_cells
	if not grid_system.can_place_cable_edge(from_v, to_v, exempt):
		return false
	# Check diagonal corner if this creates a turn
	if _cable_path.size() >= 2:
		var prev_v: Vector2i = _cable_path[_cable_path.size() - 2]
		if grid_system.is_turn_corner_occupied(from_v, prev_v, to_v, exempt):
			return false
	return true


func _find_snap_path(from_v: Vector2i, to_v: Vector2i, exempt: Dictionary, max_steps: int) -> Array[Vector2i]:
	## BFS to find a short path from from_v to to_v (up to max_steps).
	## Returns the path vertices (excluding from_v), or empty if no path found.
	if from_v == to_v:
		return []
	var dist: int = absi(to_v.x - from_v.x) + absi(to_v.y - from_v.y)
	if dist > max_steps:
		return []
	# Simple BFS
	var queue: Array[Array] = [[from_v, [] as Array[Vector2i]]]
	var visited: Dictionary = {from_v: true}
	var directions: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while not queue.is_empty():
		var current: Array = queue.pop_front()
		var pos: Vector2i = current[0]
		var path: Array[Vector2i] = current[1]
		if path.size() >= max_steps:
			continue
		for dir in directions:
			var next: Vector2i = pos + dir
			if visited.has(next):
				continue
			if next in _cable_path and next != to_v:
				continue  # don't cross existing path (except target)
			if not grid_system.can_place_cable_edge(pos, next, exempt):
				continue
			var new_path: Array[Vector2i] = path.duplicate()
			new_path.append(next)
			if next == to_v:
				return new_path
			visited[next] = true
			queue.append([next, new_path])
	return []


func _compute_port_exempt_cells(building: Node2D, port_side: String) -> Dictionary:
	## Returns cells around exit vertices that should be exempt from blocking.
	## This allows cables to leave/reach port areas even when adjacent to sources/buildings.
	var exempt: Dictionary = {}
	var verts: Array[Vector2i] = connection_manager.get_port_exit_vertices(building, port_side)
	for v in verts:
		# The 4 cells sharing this vertex
		exempt[Vector2i(v.x - 1, v.y - 1)] = true
		exempt[Vector2i(v.x, v.y - 1)] = true
		exempt[Vector2i(v.x - 1, v.y)] = true
		exempt[Vector2i(v.x, v.y)] = true
	return exempt



func _find_port_at(world_pos: Vector2, output_only: bool) -> Dictionary:
	# Check building ports
	for building in building_container.get_children():
		if not building.has_method("get_port_at"):
			continue
		var local_pos: Vector2 = world_pos - building.global_position
		var port: Dictionary = building.get_port_at(local_pos)
		if port.is_empty():
			continue
		if output_only and not port.is_output:
			continue
		if not output_only and port.is_output:
			continue
		return {"building": building, "side": port.side, "is_output": port.is_output}
	# Check source ports (outputs for cable start, FIRE inputs for cable end)
	if source_manager:
		for source in source_manager.get_all_sources():
			var local_pos: Vector2 = world_pos - source.global_position
			if output_only:
				# Source output ports
				var port: Dictionary = source.get_port_at(local_pos)
				if not port.is_empty() and port.is_output:
					return {"building": source, "side": port.side, "is_output": true}
			else:
				# FIRE input ports — check directly to avoid overlap with output ports
				for fire_port in source.fire_input_ports:
					var pos: Vector2 = source.get_port_local_position(fire_port)
					if local_pos.distance_to(pos) <= source.PORT_HIT_RADIUS:
						return {"building": source, "side": fire_port, "is_output": false, "is_fire": true}
	return {}


func _update_ghost_position() -> void:
	var world_pos := _get_world_mouse_position()
	_ghost_cell = grid_system.world_to_grid(world_pos)
	ghost_preview.position = grid_system.grid_to_world(_ghost_cell)
	ghost_preview.grid_cell = _ghost_cell
	_can_place_here = grid_system.can_place(_ghost_cell, _current_definition.grid_size)
	ghost_preview.modulate = VALID_COLOR if _can_place_here else INVALID_COLOR


func _update_hover() -> void:
	var world_pos := _get_world_mouse_position()
	var cell: Vector2i = grid_system.world_to_grid(world_pos)
	var building: Node2D = grid_system.get_building_at(cell)

	if building != _hovered_building:
		_hovered_building = building
		if building != null:
			building_hovered.emit(building)
		else:
			building_unhovered.emit()

	# Source hover (when not hovering a building)
	if building == null:
		var source: Node2D = grid_system.get_source_at(cell)
		if source != _hovered_source:
			_hovered_source = source
			if source != null:
				source_hovered.emit(source)
			else:
				source_unhovered.emit()
	elif _hovered_source != null:
		_hovered_source = null
		source_unhovered.emit()


func _update_cable_hover() -> void:
	if connection_layer == null or connection_manager == null:
		return
	var world_pos := _get_world_mouse_position()
	var idx: int = connection_manager.get_connection_at_point(world_pos)
	connection_layer.hovered_cable_index = idx


func _clear_cable_hover() -> void:
	if connection_layer:
		connection_layer.hovered_cable_index = -1


func _place_building() -> void:
	var building: Node2D = _building_scene.instantiate()
	building.setup(_current_definition, _ghost_cell, ghost_preview.direction, ghost_preview.mirror_h, ghost_preview.mirror_v)
	building.position = grid_system.grid_to_world(_ghost_cell)
	building_container.add_child(building)
	grid_system.occupy(_ghost_cell, _current_definition.grid_size, building)
	building_placed.emit(building, _ghost_cell)
	if undo_manager and not undo_manager.is_undoing:
		undo_manager.push_command({type = "place", definition = _current_definition, cell = _ghost_cell, direction = ghost_preview.direction, mirror_h = ghost_preview.mirror_h, mirror_v = ghost_preview.mirror_v})
	print("[BuildingManager] Building placed — %s at (%d,%d)" % [
		_current_definition.building_name, _ghost_cell.x, _ghost_cell.y
	])
	# Uplink paired placement: after placing Input, auto-start Output placement
	if _current_definition.uplink_partner_name != "" and _uplink_pending_input == null:
		_uplink_pending_input = building
		if _uplink_output_def == null:
			_uplink_output_def = load("res://resources/buildings/%s.tres" % _current_definition.uplink_partner_name.to_lower().replace(" ", "_"))
		_current_definition = _uplink_output_def
		ghost_preview.setup(_uplink_output_def, Vector2i.ZERO)
		ghost_preview.direction = 0
		ghost_preview.mirror_h = false
		ghost_preview.mirror_v = false
		print("[BuildingManager] Uplink pair — place Output partner")
		return  # Stay in PLACING state for partner
	# Uplink: second placed — link partners
	if _uplink_pending_input != null:
		building.uplink_partner = _uplink_pending_input
		_uplink_pending_input.uplink_partner = building
		print("[BuildingManager] Uplink pair linked — (%d,%d) <-> (%d,%d)" % [
			_uplink_pending_input.grid_cell.x, _uplink_pending_input.grid_cell.y,
			building.grid_cell.x, building.grid_cell.y
		])
		_uplink_pending_input = null
	# Single placement unless Shift is held
	if not Input.is_key_pressed(KEY_SHIFT):
		cancel_placement()




func _remove_building(building: Node2D) -> void:
	if not building.definition.is_placeable:
		return  # Contract Terminal cannot be deleted
	# Uplink pair: delete partner too (guard prevents infinite recursion)
	if building.uplink_partner != null and is_instance_valid(building.uplink_partner) and not _uplink_removing:
		_uplink_removing = true
		var partner: Node2D = building.uplink_partner
		building.uplink_partner = null
		partner.uplink_partner = null
		_remove_building(partner)
		_uplink_removing = false
	var cell: Vector2i = building.grid_cell
	var def: BuildingDefinition = building.definition
	# Capture connections before removal for undo
	if undo_manager and not undo_manager.is_undoing:
		var saved_conns: Array[Dictionary] = undo_manager.get_connections_for_building(building)
		var uplink_cell := Vector2i(-1, -1)
		if building.uplink_partner != null and is_instance_valid(building.uplink_partner):
			uplink_cell = building.uplink_partner.grid_cell
		undo_manager.push_command({
			type = "remove",
			definition = def,
			cell = cell,
			direction = building.direction,
			mirror_h = building.mirror_h,
			mirror_v = building.mirror_v,
			upgrade_level = building.upgrade_level,
			classifier_filter_content = building.classifier_filter_content,
			separator_mode = building.separator_mode,
			separator_filter_value = building.separator_filter_value,
			selected_tier = building.selected_tier,
			connections = saved_conns,
			uplink_partner_cell = uplink_cell,
		})
	grid_system.free_cells(cell, def.grid_size)
	building_removed.emit(building, cell)
	# Cancel connection if FROM building is being removed
	if building == _connecting_from_building:
		_cancel_connecting()
	# Clean up move state if moving building is removed (e.g. during load/undo)
	if building == _moving_building:
		ghost_preview.visible = false
		_moving_building = null
		_state = State.IDLE
	# Clear hover/selection if removed building was hovered/selected
	if building == _hovered_building:
		_hovered_building = null
		building_unhovered.emit()
	if building == _selected_building:
		_deselect_building()
	print("[BuildingManager] Building removed — %s at (%d,%d)" % [
		def.building_name, cell.x, cell.y
	])
	# Animated removal — skip animation during undo to prevent zombie node crashes
	if undo_manager and undo_manager.is_undoing:
		building.queue_free()
	elif building.has_method("play_remove_animation"):
		building.play_remove_animation()
	else:
		building.queue_free()


## --- SELECTION ---

func _select_building(building: Node2D) -> void:
	if building == _selected_building:
		return
	_deselect_building()
	_clear_box_selection()
	_update_selection_overlay()
	_selected_building = building
	building.is_selected = true
	building_selected.emit(building)


func _deselect_building() -> void:
	if _selected_building == null:
		return
	_selected_building.is_selected = false
	_selected_building = null
	building_deselected.emit()


func _cycle_building_filter(building: Node2D) -> void:
	var def: BuildingDefinition = building.definition
	if def.classifier:
		# Cycle through data content types (0-5, skip KEY=6)
		building.classifier_filter_content = (building.classifier_filter_content + 1) % 6
		print("[BuildingManager] Classifier filter → %s" % DataEnums.content_name(building.classifier_filter_content))
	elif def.scanner:
		# Cycle through sub-types based on upstream cable's content
		var pids: Array[int] = []
		var upstream_contents: Array[int] = []
		if connection_manager:
			for conn in connection_manager.get_connections():
				if conn.to_building == building and conn.to_port == "left":
					var from_b: Node2D = conn.from_building
					if not "stored_data" in from_b:
						# Data source — use content_weights instead
						if from_b.has_method("has_fire") and from_b.definition:
							for content_id in from_b.definition.content_weights:
								if from_b.definition.content_weights[content_id] > 0.0:
									if int(content_id) not in upstream_contents:
										upstream_contents.append(int(content_id))
						break
					for key in from_b.stored_data:
						if from_b.stored_data[key] <= 0:
							continue
						var c: int = DataEnums.unpack_content(key)
						if c not in upstream_contents:
							upstream_contents.append(c)
					break
		upstream_contents.sort()
		for c in upstream_contents:
			for st in range(DataEnums.sub_type_count(c)):
				pids.append(c * 4 + st)
		if pids.is_empty():
			# No upstream data — cycle all 24
			building.scanner_filter_sub_type = (building.scanner_filter_sub_type + 1) % 24
		else:
			var idx: int = pids.find(building.scanner_filter_sub_type)
			building.scanner_filter_sub_type = pids[(idx + 1) % pids.size()]
		var fc: int = building.scanner_filter_sub_type / 4
		var fst: int = building.scanner_filter_sub_type % 4
		var label: String = DataEnums.sub_type_name(fc, fst)
		if label == "":
			label = "pid %d" % building.scanner_filter_sub_type
		print("[BuildingManager] Scanner filter → %s" % label)
	elif def.processor and def.processor.rule == "separator":
		if building.separator_mode == "state":
			# Cycle: PUBLIC(0) → ENCRYPTED(1) → CORRUPTED(2), skip MALWARE(3) & ENC_COR(4)
			var state_cycle: Array[int] = [0, 1, 2]
			var idx: int = state_cycle.find(building.separator_filter_value)
			building.separator_filter_value = state_cycle[(idx + 1) % state_cycle.size()]
			print("[BuildingManager] Separator filter → %s" % DataEnums.state_name(building.separator_filter_value))
		else:
			building.separator_filter_value = (building.separator_filter_value + 1) % 6
			print("[BuildingManager] Separator filter → %s" % DataEnums.content_name(building.separator_filter_value))
	elif def.producer and def.producer.max_tier > 1:
		# Cycle through Key tiers (1 to max_tier)
		building.selected_tier = (building.selected_tier % def.producer.max_tier) + 1
		var label: String = DataEnums.tier_name(building.selected_tier, DataEnums.DataState.ENCRYPTED) + " Key"
		print("[BuildingManager] %s tier → %s" % [def.building_name, label])
	building_state_changed.emit()


func _rotate_selected_building() -> void:
	var building: Node2D = _selected_building
	if not building.definition.is_placeable:
		return  # Don't rotate non-placeable buildings (Contract Terminal)
	var old_dir: int = building.direction
	var new_dir: int = (old_dir + 1) % 4
	# Save connections before rotation (paths become invalid when ports move)
	var saved_conns: Array[Dictionary] = []
	if undo_manager:
		saved_conns = undo_manager.get_connections_for_building(building)
	# Remove connections
	if connection_manager:
		connection_manager.remove_connections_for(building, building.grid_cell)
	# Apply rotation
	building.direction = new_dir
	building.queue_redraw()
	# Push undo
	if undo_manager and not undo_manager.is_undoing:
		undo_manager.push_command({
			type = "rotate",
			cell = building.grid_cell,
			old_direction = old_dir,
			new_direction = new_dir,
			connections = saved_conns,
		})
	print("[BuildingManager] Rotated — %s direction %d" % [building.definition.building_name, new_dir])


func _mirror_selected_building() -> void:
	var building: Node2D = _selected_building
	if not building.definition.is_placeable:
		return  # Don't mirror non-placeable buildings (Contract Terminal)
	var old_mirror: bool = building.mirror_h
	var new_mirror: bool = not old_mirror
	# Save connections before mirror (paths become invalid when ports move)
	var saved_conns: Array[Dictionary] = []
	if undo_manager:
		saved_conns = undo_manager.get_connections_for_building(building)
	# Remove connections
	if connection_manager:
		connection_manager.remove_connections_for(building, building.grid_cell)
	# Apply mirror
	building.mirror_h = new_mirror
	building.queue_redraw()
	# Push undo
	if undo_manager and not undo_manager.is_undoing:
		undo_manager.push_command({
			type = "mirror",
			cell = building.grid_cell,
			old_mirror_h = old_mirror,
			new_mirror_h = new_mirror,
			connections = saved_conns,
		})
	print("[BuildingManager] Mirrored — %s mirror_h=%s" % [building.definition.building_name, str(new_mirror)])


func _mirror_selected_building_v() -> void:
	var building: Node2D = _selected_building
	if not building.definition.is_placeable:
		return
	var old_mirror: bool = building.mirror_v
	var new_mirror: bool = not old_mirror
	var saved_conns: Array[Dictionary] = []
	if undo_manager:
		saved_conns = undo_manager.get_connections_for_building(building)
	if connection_manager:
		connection_manager.remove_connections_for(building, building.grid_cell)
	building.mirror_v = new_mirror
	building.queue_redraw()
	if undo_manager and not undo_manager.is_undoing:
		undo_manager.push_command({
			type = "mirror_v",
			cell = building.grid_cell,
			old_mirror_v = old_mirror,
			new_mirror_v = new_mirror,
			connections = saved_conns,
		})
	print("[BuildingManager] Mirrored — %s mirror_v=%s" % [building.definition.building_name, str(new_mirror)])


## Programmatic API (AutoPlayManager ve test sistemleri icin)

func place_building_at(def: BuildingDefinition, cell: Vector2i) -> Node2D:
	if not grid_system.can_place(cell, def.grid_size):
		push_warning("[BuildingManager] Cannot place %s at (%d,%d) — blocked" % [def.building_name, cell.x, cell.y])
		return null
	var building: Node2D = _building_scene.instantiate()
	building.setup(def, cell)
	building.position = grid_system.grid_to_world(cell)
	building_container.add_child(building)
	grid_system.occupy(cell, def.grid_size, building)
	building_placed.emit(building, cell)
	print("[BuildingManager] API placed — %s at (%d,%d)" % [def.building_name, cell.x, cell.y])
	return building


func remove_building_at(cell: Vector2i) -> bool:
	var building: Node = grid_system.get_building_at(cell)
	if building == null:
		push_warning("[BuildingManager] No building at (%d,%d)" % [cell.x, cell.y])
		return false
	_remove_building(building)
	return true


## --- MOVING ---

func _start_moving(building: Node2D) -> void:
	if not building.definition.is_placeable:
		return  # Contract Terminal cannot be moved
	_moving_building = building
	_moving_original_cell = building.grid_cell
	_state = State.MOVING
	# Free original cells so ghost can check placement
	grid_system.free_cells(_moving_original_cell, building.definition.grid_size)
	# Setup ghost preview with same definition
	ghost_preview.visible = true
	ghost_preview._is_ghost = true
	ghost_preview.setup(building.definition, Vector2i.ZERO, building.direction, building.mirror_h)
	# Hide the actual building while moving
	_moving_building.visible = false
	# Clear hover
	if _hovered_building != null:
		_hovered_building = null
		building_unhovered.emit()
	print("[BuildingManager] Moving started — %s from (%d,%d)" % [
		building.definition.building_name, _moving_original_cell.x, _moving_original_cell.y
	])


func _handle_moving_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _can_place_here:
			_complete_move()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_moving()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_moving()


func _update_move_preview() -> void:
	var world_pos := _get_world_mouse_position()
	_ghost_cell = grid_system.world_to_grid(world_pos)
	ghost_preview.position = grid_system.grid_to_world(_ghost_cell)
	ghost_preview.grid_cell = _ghost_cell
	_can_place_here = grid_system.can_place(_ghost_cell, _moving_building.definition.grid_size)
	ghost_preview.modulate = VALID_COLOR if _can_place_here else INVALID_COLOR


func _complete_move() -> void:
	var def: BuildingDefinition = _moving_building.definition
	var old_cell: Vector2i = _moving_original_cell
	var building: Node2D = _moving_building
	# Capture cables BEFORE removing (building.grid_cell still = old_cell)
	var saved_conns: Array[Dictionary] = []
	if undo_manager:
		saved_conns = undo_manager.get_connections_for_building(building)
	# Remove cables — paths reference old position and are now invalid
	if connection_manager:
		connection_manager.remove_connections_for(building, old_cell)
	# Occupy new cells
	grid_system.occupy(_ghost_cell, def.grid_size, building)
	building.grid_cell = _ghost_cell
	building.position = grid_system.grid_to_world(_ghost_cell)
	building.visible = true
	ghost_preview.visible = false
	if undo_manager and not undo_manager.is_undoing:
		undo_manager.push_command({
			type = "move",
			definition = def,
			old_cell = old_cell,
			new_cell = _ghost_cell,
			connections = saved_conns,
		})
	print("[BuildingManager] Building moved — %s to (%d,%d)" % [
		def.building_name, _ghost_cell.x, _ghost_cell.y
	])
	_moving_building = null
	_state = State.IDLE


func _cancel_moving() -> void:
	# Restore original cells
	var def: BuildingDefinition = _moving_building.definition
	grid_system.occupy(_moving_original_cell, def.grid_size, _moving_building)
	_moving_building.visible = true
	ghost_preview.visible = false
	_moving_building = null
	_state = State.IDLE
	print("[BuildingManager] Move cancelled")


func _get_world_mouse_position() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()


## --- BOX SELECTION ---

func _start_box_selection(world_pos: Vector2) -> void:
	_box_start_world = world_pos
	_box_end_world = world_pos
	_deselect_building()
	_clear_box_selection()
	_state = State.BOX_SELECTING
	print("[BuildingManager] Box selection started")


func _handle_box_selecting_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Complete box selection
			_complete_box_selection()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_box_selection()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_complete_box_selection()


func _complete_box_selection() -> void:
	var min_world := Vector2(minf(_box_start_world.x, _box_end_world.x), minf(_box_start_world.y, _box_end_world.y))
	var max_world := Vector2(maxf(_box_start_world.x, _box_end_world.x), maxf(_box_start_world.y, _box_end_world.y))
	var min_cell: Vector2i = grid_system.world_to_grid(min_world)
	var max_cell: Vector2i = grid_system.world_to_grid(max_world)
	# Find all buildings within the box
	_selected_buildings.clear()
	var selected_set: Dictionary = {}  # building → true for fast lookup
	for building in building_container.get_children():
		if not building.has_method("is_active"):
			continue
		var cell: Vector2i = building.grid_cell
		var bsize: Vector2i = building.definition.grid_size
		# Check if building overlaps with box
		if cell.x + bsize.x > min_cell.x and cell.x <= max_cell.x \
				and cell.y + bsize.y > min_cell.y and cell.y <= max_cell.y:
			_selected_buildings.append(building)
			selected_set[building] = true
			building.is_selected = true
	# Find connections between selected buildings
	_selected_connections.clear()
	if connection_manager:
		for conn in connection_manager.get_connections():
			if not is_instance_valid(conn.from_building) or not is_instance_valid(conn.to_building):
				continue
			if selected_set.has(conn.from_building) and selected_set.has(conn.to_building):
				_selected_connections.append({
					"from_cell": conn.from_building.grid_cell,
					"from_port": conn.from_port,
					"to_cell": conn.to_building.grid_cell,
					"to_port": conn.to_port,
					"path": conn.path.duplicate(),
				})
	_state = State.IDLE
	_update_selection_overlay()
	print("[BuildingManager] Box selected — %d buildings, %d cables" % [_selected_buildings.size(), _selected_connections.size()])


func _cancel_box_selection() -> void:
	_clear_box_selection()
	_state = State.IDLE
	_update_selection_overlay()
	print("[BuildingManager] Box selection cancelled")


func _clear_box_selection() -> void:
	for b in _selected_buildings:
		if is_instance_valid(b):
			b.is_selected = false
	_selected_buildings.clear()
	_selected_connections.clear()


func _delete_selected_buildings() -> void:
	var buildings_copy: Array[Node2D] = _selected_buildings.duplicate()
	_clear_box_selection()
	var count: int = 0
	for building in buildings_copy:
		if is_instance_valid(building) and building.definition.is_placeable:
			_remove_building(building)
			count += 1
	print("[BuildingManager] Deleted %d buildings" % count)


func _update_selection_overlay() -> void:
	if connection_layer == null:
		return
	if _state == State.BOX_SELECTING:
		connection_layer.box_select_start = _box_start_world
		connection_layer.box_select_end = _box_end_world
		connection_layer.box_select_active = true
	else:
		connection_layer.box_select_active = false
	connection_layer.selected_buildings = _selected_buildings
	connection_layer.queue_redraw()


## --- COPY / PASTE ---

func _copy_single_building(building: Node2D) -> void:
	if not building.definition.is_placeable:
		return  # Contract Terminal cannot be copied
	_copy_buffer.clear()
	_copy_connections.clear()
	_copy_buffer.append({
		"definition": building.definition,
		"offset": Vector2i.ZERO,
		"direction": building.direction,
		"mirror_h": building.mirror_h,
		"mirror_v": building.mirror_v,
		"classifier_filter_content": building.classifier_filter_content,
		"separator_mode": building.separator_mode,
		"separator_filter_value": building.separator_filter_value,
		"selected_tier": building.selected_tier,
	})
	_start_paste_mode()
	print("[BuildingManager] Copied 1 building")


func _copy_selection() -> void:
	if _selected_buildings.is_empty():
		return
	_copy_buffer.clear()
	_copy_connections.clear()
	# Use first building as anchor
	var anchor_cell: Vector2i = _selected_buildings[0].grid_cell
	for building in _selected_buildings:
		if not is_instance_valid(building):
			continue
		if not building.definition.is_placeable:
			continue  # Skip Contract Terminal in multi-copy
		_copy_buffer.append({
			"definition": building.definition,
			"offset": building.grid_cell - anchor_cell,
			"direction": building.direction,
			"mirror_h": building.mirror_h,
			"mirror_v": building.mirror_v,
			"classifier_filter_content": building.classifier_filter_content,
			"separator_mode": building.separator_mode,
			"separator_filter_value": building.separator_filter_value,
			"selected_tier": building.selected_tier,
		})
	# Copy connections (store offsets relative to anchor)
	for conn in _selected_connections:
		var path_offsets: Array[Vector2i] = []
		for v in conn.path:
			path_offsets.append(v - anchor_cell)
		_copy_connections.append({
			"from_offset": conn.from_cell - anchor_cell,
			"from_port": conn.from_port,
			"to_offset": conn.to_cell - anchor_cell,
			"to_port": conn.to_port,
			"path_offsets": path_offsets,
		})
	_start_paste_mode()
	print("[BuildingManager] Copied %d buildings, %d cables" % [_copy_buffer.size(), _copy_connections.size()])


func _start_paste_mode() -> void:
	_clear_box_selection()
	_deselect_building()
	_state = State.COPYING
	# Show ghost for first building
	if not _copy_buffer.is_empty():
		var first := _copy_buffer[0]
		ghost_preview.visible = true
		ghost_preview._is_ghost = true
		ghost_preview.setup(first.definition, Vector2i.ZERO, first.direction, first.mirror_h, first.mirror_v)
	print("[BuildingManager] Paste mode — click to place, right-click to cancel")


func _handle_copying_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_paste_buildings()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_copying()


func _update_copy_preview() -> void:
	var world_pos := _get_world_mouse_position()
	_copy_anchor = grid_system.world_to_grid(world_pos)
	# Update ghost for visual feedback
	if ghost_preview.visible and not _copy_buffer.is_empty():
		ghost_preview.position = grid_system.grid_to_world(_copy_anchor)
		ghost_preview.grid_cell = _copy_anchor
		# Check if ALL buildings can be placed
		var can_place_all: bool = true
		for entry in _copy_buffer:
			var target_cell: Vector2i = _copy_anchor + entry.offset
			if not grid_system.can_place(target_cell, entry.definition.grid_size):
				can_place_all = false
				break
		ghost_preview.modulate = VALID_COLOR if can_place_all else INVALID_COLOR


func _paste_buildings() -> void:
	# Check all can be placed
	for entry in _copy_buffer:
		var target_cell: Vector2i = _copy_anchor + entry.offset
		if not grid_system.can_place(target_cell, entry.definition.grid_size):
			print("[BuildingManager] Cannot paste — blocked at (%d,%d)" % [target_cell.x, target_cell.y])
			return
	# Place all buildings
	var placed: Dictionary = {}  # offset → building (for connection restoration)
	for entry in _copy_buffer:
		var target_cell: Vector2i = _copy_anchor + entry.offset
		var building: Node2D = _building_scene.instantiate()
		building.setup(entry.definition, target_cell, entry.direction, entry.mirror_h, entry.mirror_v)
		building.position = grid_system.grid_to_world(target_cell)
		building_container.add_child(building)
		grid_system.occupy(target_cell, entry.definition.grid_size, building)
		building_placed.emit(building, target_cell)
		building.classifier_filter_content = entry.classifier_filter_content
		building.separator_mode = entry.separator_mode
		building.separator_filter_value = entry.separator_filter_value
		building.selected_tier = entry.selected_tier
		placed[entry.offset] = building
		if undo_manager and not undo_manager.is_undoing:
			undo_manager.push_command({
				type = "place",
				definition = entry.definition,
				cell = target_cell,
				direction = entry.direction,
				mirror_h = entry.mirror_h,
				mirror_v = entry.mirror_v,
			})
	# Restore connections
	for conn_data in _copy_connections:
		var from_cell: Vector2i = _copy_anchor + conn_data.from_offset
		var to_cell: Vector2i = _copy_anchor + conn_data.to_offset
		var abs_path: Array[Vector2i] = []
		for v in conn_data.path_offsets:
			abs_path.append(_copy_anchor + v)
		if connection_manager:
			var from_b: Node2D = grid_system.get_building_at(from_cell)
			var to_b: Node2D = grid_system.get_building_at(to_cell)
			if from_b == null:
				from_b = grid_system.get_source_at(from_cell)
			if to_b == null:
				to_b = grid_system.get_source_at(to_cell)
			if from_b and to_b and connection_manager.is_path_valid(abs_path, {}):
				var added: bool = connection_manager.add_connection(from_b, conn_data.from_port, to_b, conn_data.to_port, abs_path)
				if added and undo_manager and not undo_manager.is_undoing:
					undo_manager.push_command({
						type = "add_connection",
						from_cell = from_cell,
						from_port = conn_data.from_port,
						to_cell = to_cell,
						to_port = conn_data.to_port,
						path = abs_path.duplicate(),
					})
	print("[BuildingManager] Pasted %d buildings" % placed.size())
	# Stay in copy mode for multi-paste (right-click to exit)


func _cancel_copying() -> void:
	_state = State.IDLE
	_copy_buffer.clear()
	_copy_connections.clear()
	ghost_preview.visible = false
	_update_selection_overlay()
	print("[BuildingManager] Copy/paste cancelled")
