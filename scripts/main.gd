extends Node2D

@onready var grid_system: Node2D = $GridSystem
@onready var building_manager: Node = $BuildingManager
@onready var building_panel: PanelContainer = $UILayer/BuildingPanel
@onready var camera: Camera2D = $GameCamera


func _ready() -> void:
	building_panel.building_selected.connect(building_manager.start_placement)

	# Center camera on grid
	camera.position = Vector2(
		grid_system.GRID_WIDTH * grid_system.TILE_SIZE / 2.0,
		grid_system.GRID_HEIGHT * grid_system.TILE_SIZE / 2.0
	)

	print("[Main] SYS_ADMIN initialized")
