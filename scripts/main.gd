extends Node2D

@onready var grid_system: Node2D = $GridSystem
@onready var building_manager: Node = $BuildingManager
@onready var building_panel: PanelContainer = $UILayer/BuildingPanel
@onready var camera: Camera2D = $GameCamera
@onready var ui_layer: CanvasLayer = $UILayer
@onready var connection_manager: Node = $ConnectionManager
@onready var connection_layer: Node2D = $ConnectionLayer
@onready var simulation_manager = $SimulationManager
@onready var tech_tree_panel: PanelContainer = $UILayer/TechTreePanel
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

	# Setup tech tree
	tech_tree_panel.setup(simulation_manager, building_panel)
	building_panel._tech_tree = tech_tree_panel
	tech_tree_panel.building_unlocked.connect(_on_building_unlocked)

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
	building_manager.building_placed.connect(source_manager.on_building_placed)
	building_manager.building_removed.connect(source_manager.on_building_removed)
	source_manager.source_discovered.connect(_on_source_discovered)

	# Seed-based procedural map generation
	_current_seed = _get_seed_from_args()
	_map_generator = _MapGeneratorScript.new()
	_map_generator.generate_map(_current_seed, source_manager)

	# Setup fog of war layer (above sources, below buildings)
	_setup_fog_layer()

	# Center camera on map center
	camera.position = Vector2(256 * 64 + 64, 256 * 64 + 64)

	# Update seed in top bar
	_top_bar.update_seed(_current_seed)

	# Setup minimap
	_setup_minimap()

	# Setup shortcut hints
	_setup_shortcut_hints()

	# Wire up testing systems (optional — skip if nodes not present)
	_setup_testing_systems()

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
	ui_layer.add_child(_minimap)


func _setup_shortcut_hints() -> void:
	_shortcut_hints = Label.new()
	_shortcut_hints.text = "Space: Duraklat  |  1/2/3: Hiz  |  Ctrl+Z/Y: Geri Al  |  T: Teknoloji  |  H: Gizle"
	_shortcut_hints.add_theme_font_size_override("font_size", 13)
	_shortcut_hints.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8, 0.7))
	_shortcut_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shortcut_hints.anchors_preset = Control.PRESET_BOTTOM_WIDE
	_shortcut_hints.offset_bottom = -12.0
	_shortcut_hints.offset_top = -32.0
	_shortcut_hints.offset_left = 200.0
	_shortcut_hints.offset_right = -230.0
	_shortcut_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_shortcut_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_shortcut_hints)
	# Auto-fade after 8 seconds
	var tween := create_tween()
	tween.tween_property(_shortcut_hints, "modulate:a", 0.0, 1.5).set_delay(8.0)


func _toggle_shortcut_hints() -> void:
	if _shortcut_hints.modulate.a < 0.1:
		_shortcut_hints.modulate.a = 1.0
		var tween := create_tween()
		tween.tween_property(_shortcut_hints, "modulate:a", 0.0, 1.5).set_delay(8.0)
	else:
		_shortcut_hints.modulate.a = 0.0


func _setup_testing_systems() -> void:
	var data_collector: Node = get_node_or_null("DataCollector")
	if data_collector:
		data_collector.simulation_manager = simulation_manager
		data_collector.building_container = $BuildingContainer
		data_collector.connection_manager = connection_manager
		simulation_manager.tick_completed.connect(data_collector._on_tick_completed)

	var auto_play: Node = get_node_or_null("AutoPlayManager")
	if auto_play:
		auto_play.building_manager = building_manager
		auto_play.connection_manager = connection_manager
		auto_play.simulation_manager = simulation_manager
		auto_play.data_collector = data_collector
		auto_play.source_manager = source_manager
		simulation_manager.tick_completed.connect(auto_play._on_tick_completed)
		auto_play.scenario_finished.connect(_on_scenario_finished)

	# Headless CLI: --scenario=res://path/to/scenario.json
	_check_autoplay_args(auto_play, data_collector)


func _check_autoplay_args(auto_play: Node, data_collector: Node) -> void:
	if auto_play == null:
		return
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--scenario="):
			var path: String = arg.substr(11)
			print("[Main] Headless scenario: %s" % path)
			if data_collector:
				data_collector.start_collecting(1)
			auto_play.run_scenario_from_file(path)
			return


func _on_scenario_finished(scenario_name: String, success: bool) -> void:
	var data_collector: Node = get_node_or_null("DataCollector")
	if data_collector and data_collector._is_collecting:
		data_collector.stop_collecting()
		data_collector.save_to_file(scenario_name)
	# Quit only if running headless
	if DisplayServer.get_name() == "headless":
		print("[Main] Headless done — %s: %s" % [scenario_name, "PASSED" if success else "FAILED"])
		get_tree().quit(0 if success else 1)
	else:
		print("[Main] Scenario done — %s: %s (oyun devam ediyor)" % [scenario_name, "PASSED" if success else "FAILED"])



func _on_speed_changed(multiplier: int, paused: bool) -> void:
	_top_bar.update_speed(multiplier, paused)


func _on_building_unlocked(building_name: String) -> void:
	print("[Main] Yapi acildi: %s" % building_name)


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
	notif.text = "[ %s KESFEDILDI ]" % display_name
	notif.add_theme_font_size_override("font_size", 20)
	notif.add_theme_color_override("font_color", color)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.anchors_preset = Control.PRESET_CENTER_TOP
	notif.position.y = 80
	ui_layer.add_child(notif)

	var tween := create_tween()
	tween.tween_property(notif, "modulate:a", 0.0, 1.0).set_delay(2.0)
	tween.tween_callback(notif.queue_free)


func _on_source_discovered(source: Node2D) -> void:
	var def = source.definition
	_show_discovery_notification(def.source_name, def.color)


func _toggle_dev_mode() -> void:
	_dev_mode = not _dev_mode
	source_manager.set_dev_mode(_dev_mode)
	_top_bar.set_dev_visible(_dev_mode)
	_fog_layer.visible = not _dev_mode
	print("[Main] Dev mode: %s" % ("ON" if _dev_mode else "OFF"))
