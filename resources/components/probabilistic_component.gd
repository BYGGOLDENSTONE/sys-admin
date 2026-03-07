class_name ProbabilisticComponent
extends Resource

@export var processing_rate: float = 4.0  ## MB/s
@export var success_rate: float = 0.7  ## 0.0-1.0 probability of successful recovery
@export var input_states: Array[int] = []  ## Accepted DataState values (empty = all)
@export var output_state: int = 0  ## Successful output state (default: Clean)
@export var residue_port: String = "bottom"  ## Port for failed/residue output
