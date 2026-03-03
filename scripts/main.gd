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

	# Center camera on grid
	camera.position = Vector2(
		grid_system.GRID_WIDTH * grid_system.TILE_SIZE / 2.0,
		grid_system.GRID_HEIGHT * grid_system.TILE_SIZE / 2.0
	)

	print("[Main] SYS_ADMIN initialized")


func _on_credits_changed(new_total: float) -> void:
	credits_label.text = "Credits: %d" % int(new_total)
