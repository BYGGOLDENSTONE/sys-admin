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
@onready var tech_tree_panel: PanelContainer = $UILayer/TechTreePanel

var _tooltip_scene: PackedScene = preload("res://scenes/ui/building_tooltip.tscn")
var _tooltip: PanelContainer = null


func _ready() -> void:
	building_panel.building_selected.connect(building_manager.start_placement)

	# Setup tooltip
	_tooltip = _tooltip_scene.instantiate()
	ui_layer.add_child(_tooltip)
	building_manager.building_hovered.connect(_tooltip.show_for_building)
	building_manager.building_unhovered.connect(_tooltip.hide_tooltip)

	# Wire up connection system
	building_manager.connection_manager = connection_manager
	building_manager.connection_layer = connection_layer
	connection_layer.connection_manager = connection_manager

	# Auto-remove connections when building is removed
	building_manager.building_removed.connect(connection_manager.remove_connections_for)

	# Wire up simulation
	simulation_manager.connection_manager = connection_manager
	simulation_manager.building_container = $BuildingContainer
	simulation_manager.grid_system = grid_system
	simulation_manager.connection_layer = connection_layer
	building_manager.building_placed.connect(simulation_manager._on_building_placed)
	building_manager.building_removed.connect(simulation_manager._on_building_removed)
	building_manager.simulation_manager = simulation_manager
	simulation_manager.credits_changed.connect(_on_credits_changed)
	simulation_manager.research_changed.connect(_on_research_changed)
	simulation_manager.data_type_discovered.connect(_on_data_type_discovered)

	# Setup tech tree
	tech_tree_panel.setup(simulation_manager, building_panel)
	building_panel._tech_tree = tech_tree_panel
	tech_tree_panel.building_unlocked.connect(_on_building_unlocked)

	# Center camera on grid
	camera.position = Vector2(
		grid_system.GRID_WIDTH * grid_system.TILE_SIZE / 2.0,
		grid_system.GRID_HEIGHT * grid_system.TILE_SIZE / 2.0
	)

	# Wire up testing systems (optional — skip if nodes not present)
	_setup_testing_systems()

	print("[Main] SYS_ADMIN initialized")


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


func _on_building_unlocked(building_name: String) -> void:
	print("[Main] Yapı açıldı: %s" % building_name)


func _on_data_type_discovered(data_type: String) -> void:
	var type_names: Dictionary = {
		"corrupted": "CORRUPTED DATA",
		"encrypted": "ENCRYPTED DATA",
		"malware": "MALWARE",
		"research": "RESEARCH DATA"
	}
	var type_colors: Dictionary = {
		"corrupted": Color(1.0, 0.53, 0.27),
		"encrypted": Color(0.27, 0.67, 1.0),
		"malware": Color(1.0, 0.27, 0.4),
		"research": Color(0.67, 0.53, 1.0)
	}
	var display_name: String = type_names.get(data_type, data_type.to_upper())
	var color: Color = type_colors.get(data_type, Color.WHITE)

	# Create floating discovery notification
	var notif := Label.new()
	notif.text = "[ %s KEŞFEDİLDİ ]" % display_name
	notif.add_theme_font_size_override("font_size", 20)
	notif.add_theme_color_override("font_color", color)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.anchors_preset = Control.PRESET_CENTER_TOP
	notif.position.y = 80
	ui_layer.add_child(notif)

	# Fade out and remove after 3 seconds
	var tween := create_tween()
	tween.tween_property(notif, "modulate:a", 0.0, 1.0).set_delay(2.0)
	tween.tween_callback(notif.queue_free)
