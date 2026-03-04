class_name BuildingDefinition
extends Resource

@export var building_name: String = ""
@export_multiline var description: String = ""
@export var grid_size: Vector2i = Vector2i(2, 2)
@export var color: Color = Color.CYAN
@export var category: String = ""
@export var base_cost: int = 100
@export var visual_type: String = "default"
@export var output_ports: Array[String] = []
@export var input_ports: Array[String] = []

@export_group("Components")
@export var generator: GeneratorComponent
@export var storage: StorageComponent
@export var seller: SellerComponent
@export var processor: ProcessorComponent
@export var research_collector: ResearchCollectorComponent
@export var upgrade: UpgradeComponent


func get_storage_capacity() -> int:
	if storage:
		return storage.capacity
	return 0
