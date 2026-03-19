class_name ProcessorComponent
extends Resource

@export var processing_rate: float = 3.0  ## MB/s
@export var base_throughput: float = 10.0  ## Base throughput for separator (divided by state variety)
@export var input_states: Array[int] = []  ## Accepted DataState values (empty = all)
@export var output_state: int = -1  ## Output DataState (-1 = no change / destroy)
@export var rule: String = ""  ## Processing rule identifier
@export var efficiency: float = 1.0  ## 0.0-1.0 output ratio (1.0 = no loss)
@export var separator_mode: String = "state"  ## For separator: "state" or "content"
