extends Node2D

@onready var grid_system: Node2D = $GridSystem
@onready var building_manager: Node = $BuildingManager
@onready var building_panel: PanelContainer = $UILayer/BuildingPanel
@onready var camera: Camera2D = $GameCamera
@onready var ui_layer: CanvasLayer = $UILayer
@onready var connection_manager: Node = $ConnectionManager
@onready var connection_layer: Node2D = $ConnectionLayer
@onready var simulation_manager = $SimulationManager
@onready var credits_label: Label = $UILayer/CreditsLabel
@onready var research_label: Label = $UILayer/ResearchLabel
@onready var patch_data_label: Label = $UILayer/PatchDataLabel
@onready var tech_tree_panel: PanelContainer = $UILayer/TechTreePanel

@onready var source_manager: Node = $SourceManager
@onready var source_container: Node2D = $SourceContainer
@onready var speed_label: Label = $UILayer/SpeedLabel

var _tooltip_scene: PackedScene = preload("res://scenes/ui/building_tooltip.tscn")
var _tooltip: PanelContainer = null
var _upgrade_panel: PanelContainer = null
var _undo_manager: Node = null

var _isp_backbone_def: DataSourceDefinition = preload("res://resources/sources/isp_backbone.tres")
var _corporate_server_def: DataSourceDefinition = preload("res://resources/sources/corporate_server.tres")
var _dark_web_node_def: DataSourceDefinition = preload("res://resources/sources/dark_web_node.tres")


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
	simulation_manager.credits_changed.connect(_on_credits_changed)
	simulation_manager.research_changed.connect(_on_research_changed)
	simulation_manager.patch_data_changed.connect(_on_patch_data_changed)
	simulation_manager.content_discovered.connect(_on_content_discovered)
	simulation_manager.state_discovered.connect(_on_state_discovered)

	# Setup upgrade panel
	var UpgradePanelScript = preload("res://scripts/ui/upgrade_panel.gd")
	_upgrade_panel = PanelContainer.new()
	_upgrade_panel.set_script(UpgradePanelScript)
	_upgrade_panel.anchors_preset = Control.PRESET_BOTTOM_LEFT
	_upgrade_panel.offset_left = 240.0
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

	# Wire up speed control
	simulation_manager.speed_changed.connect(_on_speed_changed)
	_update_speed_label(1, false)

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

	# Place starting data sources
	_place_initial_sources()

	# Center camera on ISP Backbone (first source)
	camera.position = Vector2(128 * 64 + 64, 128 * 64 + 64)

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


func _place_initial_sources() -> void:
	# ISP Backbone — center of map, easy starting source
	source_manager.place_source(_isp_backbone_def, Vector2i(126, 126), 42)
	# Corporate Server — northeast, medium difficulty
	source_manager.place_source(_corporate_server_def, Vector2i(158, 98), 123)
	# Dark Web Node — southwest, hard
	source_manager.place_source(_dark_web_node_def, Vector2i(88, 168), 777)


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


func _on_credits_changed(new_total: float) -> void:
	credits_label.text = "Credits: %d" % int(new_total)


func _on_research_changed(new_total: float) -> void:
	research_label.text = "Research: %d" % int(new_total)


func _on_patch_data_changed(new_total: float) -> void:
	patch_data_label.text = "Patch Data: %d" % int(new_total)


func _on_speed_changed(multiplier: int, paused: bool) -> void:
	_update_speed_label(multiplier, paused)


func _update_speed_label(multiplier: int, paused: bool) -> void:
	if paused:
		speed_label.text = "|| DURAKLAT"
		speed_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	else:
		var arrows: String = ">".repeat(multiplier)
		speed_label.text = "%s %dx" % [arrows, multiplier]
		speed_label.add_theme_color_override("font_color", Color(0, 1, 0.53, 1))


func _on_building_unlocked(building_name: String) -> void:
	print("[Main] Yapı açıldı: %s" % building_name)


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
	notif.text = "[ %s KEŞFEDİLDİ ]" % display_name
	notif.add_theme_font_size_override("font_size", 20)
	notif.add_theme_color_override("font_color", color)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.anchors_preset = Control.PRESET_CENTER_TOP
	notif.position.y = 80
	ui_layer.add_child(notif)

	var tween := create_tween()
	tween.tween_property(notif, "modulate:a", 0.0, 1.0).set_delay(2.0)
	tween.tween_callback(notif.queue_free)


