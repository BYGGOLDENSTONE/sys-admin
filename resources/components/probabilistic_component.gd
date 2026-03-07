class_name ProbabilisticComponent
extends Resource

@export var processing_rate: float = 4.0  ## MB/s
@export var success_rate: float = 0.7  ## 0.0-1.0 base probability (fallback)
@export var tier_success_rates: Array[float] = [0.8, 0.6, 0.4, 0.2]  ## Success rate per tier: [T1, T2, T3, T4]
@export var input_states: Array[int] = []  ## Accepted DataState values (empty = all)
@export var output_state: int = 0  ## Successful output state (default: Clean)
@export var residue_port: String = "bottom"  ## Port for failed/residue output
