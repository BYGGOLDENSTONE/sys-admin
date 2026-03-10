extends Node2D

@onready var grid_system: Node2D = $GridSystem
@onready var building_manager: Node = $BuildingManager
@onready var building_panel: PanelContainer = $UILayer/BuildingPanel
@onready var camera: Camera2D = $GameCamera
@onready var ui_layer: CanvasLayer = $UILayer
@onready var connection_manager: Node = $ConnectionManager
@onready var connection_layer: Node2D = $ConnectionLayer
@onready var simulation_manager = $SimulationManager
@onready var source_manager: Node = $SourceManager
@onready var source_container: Node2D = $SourceContainer

var _tooltip_scene: PackedScene = preload("res://scenes/ui/building_tooltip.tscn")
var _MapGeneratorScript = preload("res://scripts/map_generator.gd")
var _tooltip: PanelContainer = null
var _upgrade_panel: PanelContainer = null
var _undo_manager: Node = null
var _fog_layer: Node2D = null
var _map_generator: RefCounted = null
var _current_seed: int = 0
var _dev_mode: bool = false
var _top_bar: PanelContainer = null
var _minimap: Control = null
var _shortcut_hints: Label = null
var _sound_manager: Node = null
var _gig_manager: Node = null
var _contract_terminal: Node2D = null


func _ready() -> void:
	building_panel.building_selected.connect(building_manager.start_placement)

	# Setup tooltip
	_tooltip = _tooltip_scene.instantiate()
	ui_layer.add_child(_tooltip)
	building_manager.building_hovered.connect(_tooltip.show_for_building)
	building_manager.building_unhovered.connect(_tooltip.hide_tooltip)
	building_manager.source_hovered.connect(_tooltip.show_for_source)
	building_manager.source_unhovered.connect(_tooltip.hide_tooltip)

	# Wire up connection system
	connection_manager.grid_system = grid_system
	building_manager.connection_manager = connection_manager
	building_manager.connection_layer = connection_layer
	connection_layer.connection_manager = connection_manager
	connection_layer.simulation_manager = simulation_manager

	# Auto-remove connections when building is removed
	building_manager.building_removed.connect(connection_manager.remove_connections_for)

	# Wire up simulation
	simulation_manager.connection_manager = connection_manager
	simulation_manager.building_container = $BuildingContainer
	building_manager.building_placed.connect(simulation_manager._on_building_placed)
	building_manager.building_removed.connect(simulation_manager._on_building_removed)
	simulation_manager.content_discovered.connect(_on_content_discovered)
	simulation_manager.state_discovered.connect(_on_state_discovered)

	# Setup upgrade panel
	var UpgradePanelScript = preload("res://scripts/ui/upgrade_panel.gd")
	_upgrade_panel = PanelContainer.new()
	_upgrade_panel.set_script(UpgradePanelScript)
	_upgrade_panel.anchors_preset = Control.PRESET_BOTTOM_LEFT
	_upgrade_panel.offset_left = 200.0
	_upgrade_panel.offset_bottom = -10.0
	_upgrade_panel.offset_top = -10.0
	_upgrade_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui_layer.add_child(_upgrade_panel)
	_upgrade_panel.setup(simulation_manager)
	building_manager.building_selected.connect(_upgrade_panel.show_for_building)
	building_manager.building_deselected.connect(_upgrade_panel.hide_panel)

	# Setup gig manager
	_setup_gig_manager()

	# Setup top bar
	_setup_top_bar()

	# Wire up speed control
	simulation_manager.speed_changed.connect(_on_speed_changed)
	_top_bar.update_speed(1, false)

	# Setup undo manager
	var UndoManagerScript = preload("res://scripts/undo_manager.gd")
	_undo_manager = Node.new()
	_undo_manager.set_script(UndoManagerScript)
	_undo_manager.name = "UndoManager"
	add_child(_undo_manager)
	_undo_manager.building_manager = building_manager
	_undo_manager.connection_manager = connection_manager
	_undo_manager.grid_system = grid_system
	_undo_manager.source_manager = source_manager
	building_manager.undo_manager = _undo_manager

	# Wire up source manager
	source_manager.grid_system = grid_system
	source_manager.source_container = source_container
	building_manager.source_manager = source_manager
	building_manager.building_placed.connect(source_manager.on_building_placed)
	building_manager.building_removed.connect(source_manager.on_building_removed)
	source_manager.source_discovered.connect(_on_source_discovered)

	# Seed-based procedural map generation
	_current_seed = _get_seed_from_args()
	_map_generator = _MapGeneratorScript.new()
	_map_generator.generate_map(_current_seed, source_manager)

	# Setup fog of war layer (above sources, below buildings)
	_setup_fog_layer()

	# Place Contract Terminal at map center
	_place_contract_terminal()

	# Center camera on map center
	camera.position = Vector2(256 * 64 + 64, 256 * 64 + 64)

	# Update seed in top bar
	_top_bar.update_seed(_current_seed)

	# Setup minimap
	_setup_minimap()

	# Setup shortcut hints
	_setup_shortcut_hints()

	# Setup sound manager
	_setup_sound_manager()

	# Pass post-process material to camera for chromatic aberration
	var post_rect: ColorRect = $PostProcessLayer/PostProcessRect
	camera.set_post_material(post_rect.material as ShaderMaterial)

	print("[Main] SYS_ADMIN initialized")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.ctrl_pressed:
		match event.keycode:
			KEY_Z:
				_undo_manager.undo()
			KEY_Y:
				_undo_manager.redo()
		return
	match event.keycode:
		KEY_SPACE:
			simulation_manager.toggle_pause()
		KEY_1:
			simulation_manager.set_speed(1)
		KEY_2:
			simulation_manager.set_speed(2)
		KEY_3:
			simulation_manager.set_speed(3)
		KEY_F9:
			_toggle_dev_mode()
		KEY_H:
			_toggle_shortcut_hints()


func _get_seed_from_args() -> int:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--seed="):
			return int(arg.substr(7))
	return randi()


func _setup_top_bar() -> void:
	var TopBarScript = preload("res://scripts/ui/top_bar.gd")
	_top_bar = PanelContainer.new()
	_top_bar.set_script(TopBarScript)
	_top_bar.anchors_preset = Control.PRESET_TOP_WIDE
	_top_bar.offset_right = -224.0  # Leave space for building panel
	ui_layer.add_child(_top_bar)


func _setup_fog_layer() -> void:
	var FogLayerScript = preload("res://scripts/fog_layer.gd")
	_fog_layer = Node2D.new()
	_fog_layer.set_script(FogLayerScript)
	_fog_layer.name = "FogLayer"
	add_child(_fog_layer)
	# Position after SourceContainer (index 1) so fog covers grid+sources but not buildings/cables
	move_child(_fog_layer, 2)
	building_manager.building_placed.connect(_fog_layer.explore_around_building)


func _setup_minimap() -> void:
	var MinimapScript = preload("res://scripts/ui/minimap.gd")
	_minimap = Control.new()
	_minimap.set_script(MinimapScript)
	_minimap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_minimap.offset_left = 10.0
	_minimap.offset_right = 190.0
	_minimap.offset_top = -190.0
	_minimap.offset_bottom = -10.0
	_minimap.source_manager = source_manager
	_minimap.building_container = $BuildingContainer
	_minimap.camera_ref = camera
	_minimap.connection_manager = connection_manager
	ui_layer.add_child(_minimap)


func _setup_shortcut_hints() -> void:
	_shortcut_hints = Label.new()
	_shortcut_hints.text = "SPACE Pause  //  1/2/3 Speed  //  Ctrl+Z Undo  //  H Hide"
	_shortcut_hints.add_theme_font_size_override("font_size", 12)
	_shortcut_hints.add_theme_color_override("font_color", Color(0.4, 0.6, 0.7, 0.6))
	_shortcut_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shortcut_hints.anchors_preset = Control.PRESET_BOTTOM_WIDE
	_shortcut_hints.offset_bottom = -10.0
	_shortcut_hints.offset_top = -30.0
	_shortcut_hints.offset_left = 200.0
	_shortcut_hints.offset_right = -230.0
	_shortcut_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_shortcut_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_shortcut_hints)
	# Fade in then auto-fade after 6 seconds
	_shortcut_hints.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_shortcut_hints, "modulate:a", 1.0, 0.5).set_delay(0.5)
	tween.tween_property(_shortcut_hints, "modulate:a", 0.0, 1.5).set_delay(6.0)


func _toggle_shortcut_hints() -> void:
	if _shortcut_hints.modulate.a < 0.1:
		_shortcut_hints.modulate.a = 1.0
		var tween := create_tween()
		tween.tween_property(_shortcut_hints, "modulate:a", 0.0, 1.5).set_delay(8.0)
	else:
		_shortcut_hints.modulate.a = 0.0




func _on_speed_changed(multiplier: int, paused: bool) -> void:
	_top_bar.update_speed(multiplier, paused)


func _setup_gig_manager() -> void:
	var GigManagerScript = preload("res://scripts/gig_manager.gd")
	_gig_manager = Node.new()
	_gig_manager.set_script(GigManagerScript)
	_gig_manager.name = "GigManager"
	_gig_manager.building_container = $BuildingContainer
	add_child(_gig_manager)
	# Wire to building panel
	building_panel._gig_manager = _gig_manager
	building_panel.refresh_buttons()
	# Wire unlock signals
	_gig_manager.building_unlocked.connect(_on_building_unlocked)
	_gig_manager.gig_completed.connect(_on_gig_completed)
	_gig_manager.gig_activated.connect(_on_gig_activated)
	# Process deliveries after each simulation tick
	simulation_manager.tick_completed.connect(_on_tick_for_gig)
	# Initialize after signals are connected
	_gig_manager.initialize()


func _place_contract_terminal() -> void:
	var terminal_def := load("res://resources/buildings/contract_terminal.tres") as BuildingDefinition
	if terminal_def == null:
		push_error("[Main] Cannot load Contract Terminal definition")
		return
	# Try center first, then spiral outward to find clear spot
	var center := Vector2i(256, 256)
	var cell := _find_clear_cell(center, terminal_def.grid_size)
	_contract_terminal = building_manager.place_building_at(terminal_def, cell, true)
	if _contract_terminal != null and _gig_manager != null:
		_gig_manager.set_contract_terminal(_contract_terminal)
		print("[Main] Contract Terminal placed at (%d,%d)" % [cell.x, cell.y])
	else:
		push_error("[Main] Failed to place Contract Terminal")


func _find_clear_cell(center: Vector2i, building_size: Vector2i) -> Vector2i:
	## Spiral search for a clear cell near center
	if grid_system.can_place(center, building_size):
		return center
	for radius in range(1, 20):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue  # Only check perimeter
				var cell := center + Vector2i(dx, dy)
				if grid_system.can_place(cell, building_size):
					return cell
	return center  # Fallback


func _on_tick_for_gig(_tick_count: int) -> void:
	if _gig_manager:
		_gig_manager.process_deliveries()


func _on_gig_completed(gig) -> void:
	_show_gig_notification("GIG COMPLETE: %s" % gig.gig_name, Color("#44ff88"))
	if _sound_manager:
		_sound_manager.play_unlock()


func _on_gig_activated(gig) -> void:
	_show_gig_notification("NEW GIG: %s" % gig.gig_name, Color("#00bbee"))
	building_panel.refresh_buttons()


func _show_gig_notification(text: String, color: Color) -> void:
	var notif := Label.new()
	notif.text = ">> %s <<" % text
	notif.add_theme_font_size_override("font_size", 20)
	notif.add_theme_color_override("font_color", color)
	notif.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	notif.add_theme_constant_override("outline_size", 4)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.anchors_preset = Control.PRESET_CENTER_TOP
	notif.position.y = 120
	notif.modulate = Color(1, 1, 1, 0)
	notif.scale = Vector2(0.7, 0.7)
	notif.pivot_offset = Vector2(notif.size.x / 2.0, notif.size.y / 2.0)
	ui_layer.add_child(notif)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(notif, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "position:y", 105.0, 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "modulate:a", 0.0, 0.8).set_delay(2.0)
	tween.chain().tween_callback(notif.queue_free)
	if camera.has_method("add_trauma"):
		camera.add_trauma(0.15)


func _on_building_unlocked(building_name: String) -> void:
	print("[Main] Building unlocked: %s" % building_name)
	_show_unlock_notification(building_name)
	if _sound_manager:
		_sound_manager.play_unlock()


func _show_unlock_notification(building_name: String) -> void:
	var notif := Label.new()
	notif.text = ">> %s UNLOCKED <<" % building_name.to_upper()
	notif.add_theme_font_size_override("font_size", 18)
	notif.add_theme_color_override("font_color", Color("#aa77ff"))
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.anchors_preset = Control.PRESET_CENTER_TOP
	notif.position.y = 110
	notif.modulate = Color(1, 1, 1, 0)
	notif.scale = Vector2(0.7, 0.7)
	notif.pivot_offset = Vector2(notif.size.x / 2.0, notif.size.y / 2.0)
	ui_layer.add_child(notif)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(notif, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "position:y", 95.0, 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "modulate:a", 0.0, 0.8).set_delay(2.0)
	tween.chain().tween_callback(notif.queue_free)



func _on_content_discovered(content: int) -> void:
	var display_name: String = DataEnums.content_name(content).to_upper() + " DATA"
	var color: Color = DataEnums.content_color(content)
	_show_discovery_notification(display_name, color)


func _on_state_discovered(state: int) -> void:
	var display_name: String = DataEnums.state_name(state).to_upper() + " STATE"
	var color: Color = DataEnums.state_color(state)
	_show_discovery_notification(display_name, color)


func _show_discovery_notification(display_name: String, color: Color) -> void:
	var notif := Label.new()
	notif.text = "[ %s DISCOVERED ]" % display_name
	notif.add_theme_font_size_override("font_size", 22)
	notif.add_theme_color_override("font_color", color)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.anchors_preset = Control.PRESET_CENTER_TOP
	notif.position.y = 80
	notif.modulate = Color(1, 1, 1, 0)
	notif.scale = Vector2(0.8, 0.8)
	notif.pivot_offset = Vector2(notif.size.x / 2.0, notif.size.y / 2.0)
	ui_layer.add_child(notif)

	# Pop-in + glow + float-up + fade-out
	var tween := create_tween().set_parallel(true)
	# Pop in
	tween.tween_property(notif, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Float up
	tween.tween_property(notif, "position:y", 60.0, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Fade out
	tween.tween_property(notif, "modulate:a", 0.0, 0.8).set_delay(2.2).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(notif.queue_free)

	# Camera shake + discovery sound
	if camera.has_method("add_trauma"):
		camera.add_trauma(0.12)
	if _sound_manager:
		_sound_manager.play_discovery()


func _on_source_discovered(source: Node2D) -> void:
	var def = source.definition
	_show_discovery_notification(def.source_name, def.color)


func _setup_sound_manager() -> void:
	var SoundManagerScript = preload("res://scripts/sound_manager.gd")
	_sound_manager = Node.new()
	_sound_manager.set_script(SoundManagerScript)
	_sound_manager.name = "SoundManager"
	add_child(_sound_manager)
	# Wire simulation sound
	simulation_manager.sound_manager = _sound_manager
	# Wire building events
	building_manager.building_placed.connect(_on_building_placed_sound)
	building_manager.building_removed.connect(_on_building_removed_sound)
	# Wire cable events
	connection_manager.connection_added.connect(_on_cable_connected_sound)
	connection_manager.connection_removed.connect(_on_cable_removed_sound)


func _on_building_placed_sound(_building: Node2D, _cell: Vector2i) -> void:
	_sound_manager.play_building_place()


func _on_building_removed_sound(_building: Node2D, _cell: Vector2i) -> void:
	_sound_manager.play_building_remove()


func _on_cable_connected_sound(_conn: Dictionary) -> void:
	_sound_manager.play_cable_connect()


func _on_cable_removed_sound(_conn: Dictionary) -> void:
	_sound_manager.play_cable_remove()


func _toggle_dev_mode() -> void:
	_dev_mode = not _dev_mode
	source_manager.set_dev_mode(_dev_mode)
	_top_bar.set_dev_visible(_dev_mode)
	_fog_layer.visible = not _dev_mode
	print("[Main] Dev mode: %s" % ("ON" if _dev_mode else "OFF"))
