class_name BuildingDefinition
extends Resource

@export var building_name: String = ""
@export_multiline var description: String = ""
@export var grid_size: Vector2i = Vector2i(2, 2)
@export var color: Color = Color.CYAN
@export var category: String = ""
@export var visual_type: String = "default"
@export var is_placeable: bool = true
@export var output_ports: Array[String] = []
@export var input_ports: Array[String] = []

@export_group("Components")
@export var storage: StorageComponent
@export var processor: ProcessorComponent
@export var classifier: ClassifierComponent
@export var producer: ProducerComponent
@export var dual_input: DualInputComponent
@export var splitter: SplitterComponent
@export var merger: MergerComponent
@export var compiler: CompilerComponent
@export var upgrade: UpgradeComponent


func get_storage_capacity() -> int:
	if storage:
		return storage.capacity
	return 0


func accepts_data(content: int, state: int) -> bool:
	## Check if this building can accept data with given content+state
	if compiler:
		# Compiler accepts any data for packaging
		return true
	if dual_input:
		# Dual input accepts: primary data (matching states) OR fuel/keys
		if dual_input.fuel_matches_content:
			# Recoverer: accept Corrupted data OR Public data (as fuel)
			if state == DataEnums.DataState.PUBLIC:
				return true
			if not dual_input.primary_input_states.is_empty():
				return state in dual_input.primary_input_states
			return true
		if content == dual_input.key_content:
			return true
		if not dual_input.primary_input_states.is_empty():
			return state in dual_input.primary_input_states
		return true
	if producer:
		if state != producer.input_state:
			return false
		if content == producer.input_content:
			return true
		if producer.tier2_extra_content >= 0 and content == producer.tier2_extra_content:
			return true
		if producer.tier3_extra_content >= 0 and content == producer.tier3_extra_content:
			return true
		return false
	if processor and not processor.input_states.is_empty():
		return state in processor.input_states
	return true
