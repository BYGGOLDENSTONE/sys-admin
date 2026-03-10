class_name BuildingDefinition
extends Resource

@export var building_name: String = ""
@export_multiline var description: String = ""
@export var grid_size: Vector2i = Vector2i(2, 2)
@export var color: Color = Color.CYAN
@export var category: String = ""
@export var visual_type: String = "default"
@export var is_placeable: bool = true
@export var allows_cable_crossing: bool = false
@export var output_ports: Array[String] = []
@export var input_ports: Array[String] = []

@export_group("Components")
@export var generator: GeneratorComponent
@export var storage: StorageComponent
@export var processor: ProcessorComponent
@export var classifier: ClassifierComponent
@export var probabilistic: ProbabilisticComponent
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
		# Compiler only accepts Clean data (matching recipe inputs)
		return state == DataEnums.DataState.CLEAN
	if dual_input:
		# Dual input accepts: primary data (matching states) OR keys
		if content == dual_input.key_content:
			return true
		if not dual_input.primary_input_states.is_empty():
			return state in dual_input.primary_input_states
		return true
	if producer:
		return content == producer.input_content and state == producer.input_state
	if processor and not processor.input_states.is_empty():
		return state in processor.input_states
	if probabilistic and not probabilistic.input_states.is_empty():
		return state in probabilistic.input_states
	return true
