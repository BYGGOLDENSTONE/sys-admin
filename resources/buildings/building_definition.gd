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

@export_group("Heat")
@export var heat_generation: float = 0.0  ## C/s produced while active
@export var max_heat: float = 100.0  ## C at which building overheats

@export_group("Components")
@export var generator: GeneratorComponent
@export var storage: StorageComponent
@export var seller: SellerComponent
@export var power_provider: PowerProviderComponent
@export var coolant: CoolantComponent
@export var processor: ProcessorComponent
@export var research_collector: ResearchCollectorComponent


func get_zone_radius() -> float:
	if power_provider:
		return power_provider.zone_radius
	if coolant:
		return coolant.zone_radius
	return 0.0


func is_infrastructure() -> bool:
	return power_provider != null or coolant != null


func get_storage_capacity() -> int:
	if storage:
		return storage.capacity
	return 0
