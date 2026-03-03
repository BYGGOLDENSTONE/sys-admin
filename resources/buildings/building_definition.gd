class_name BuildingDefinition
extends Resource

@export var building_name: String = ""
@export_multiline var description: String = ""
@export var grid_size: Vector2i = Vector2i(2, 2)
@export var color: Color = Color.CYAN
@export var category: String = ""
@export var base_cost: int = 100
@export var visual_type: String = "default"
@export var zone_radius: float = 0.0
@export var output_ports: Array[String] = []
@export var input_ports: Array[String] = []

@export_group("Mechanics")
@export var building_type: String = "passive"
## Values: "generator", "storage", "seller", "power", "coolant", "passive"
@export var generation_rate: float = 0.0  ## MB/s produced (Uplink)
@export var storage_capacity: int = 0  ## MB max storage
@export var sell_rate: float = 0.0  ## MB/s consumed (Data Broker)
@export var credits_per_mb: float = 0.0  ## Credits earned per MB sold
@export var power_output: float = 0.0  ## Watts provided in zone (Power Cell)
@export var cooling_rate: float = 0.0  ## C/s reduced in zone (Coolant Rig)
@export var heat_generation: float = 0.0  ## C/s produced while active
@export var max_heat: float = 100.0  ## C at which building overheats
@export var data_weights: Dictionary = {}  ## {"clean": 0.3, "corrupted": 0.25, ...}
