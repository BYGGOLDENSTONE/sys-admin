class_name DualInputComponent
extends Resource

@export var processing_rate: float = 4.0  ## MB/s
@export var primary_input_states: Array[int] = []  ## Accepted states for main input (e.g. ENCRYPTED)
@export var key_content: int = 6  ## ContentType used as key (default: KEY)
@export var key_cost: int = 1  ## Keys consumed per data unit
@export var output_state: int = 0  ## Output DataState (default: Clean)
