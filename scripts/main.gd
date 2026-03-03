extends Node2D

@onready var grid_system: Node2D = $GridSystem
@onready var building_manager: Node = $BuildingManager
@onready var building_panel: PanelContainer = $UILayer/BuildingPanel
@onready var camera: Camera2D = $GameCamera
@onready var ui_layer: CanvasLayer = $UILayer

var _tooltip_scene: PackedScene = preload("res://scenes/ui/building_tooltip.tscn")
var _tooltip: PanelContainer = null


func _ready() -> void:
	building_panel.building_selected.connect(building_manager.start_placement)

	# Setup tooltip
	_tooltip = _tooltip_scene.instantiate()
	ui_layer.add_child(_tooltip)
	building_manager.building_hovered.connect(_tooltip.show_for_building)
	building_manager.building_unhovered.connect(_tooltip.hide_tooltip)

	# Center camera on grid
	camera.position = Vector2(
		grid_system.GRID_WIDTH * grid_system.TILE_SIZE / 2.0,
		grid_system.GRID_HEIGHT * grid_system.TILE_SIZE / 2.0
	)

	print("[Main] SYS_ADMIN initialized")
