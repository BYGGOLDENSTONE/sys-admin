class_name DualInputComponent
extends Resource

@export var processing_rate: float = 4.0  ## MB/s
@export var primary_input_states: Array[int] = []  ## Accepted states for main input (e.g. ENCRYPTED)
@export var key_content: int = 6  ## ContentType used as key (default: KEY)
@export var key_cost: int = 1  ## Keys consumed per data unit (base / T1)
@export var tier_key_costs: Array[int] = [1, 2, 4, 8]  ## Key cost per tier: [T1, T2, T3, T4]
@export var output_state: int = 0  ## Output DataState (default: Public)
@export var output_tag: int = 1  ## ProcessingTag to add (1=DECRYPTED, 2=RECOVERED, 4=ENCRYPTED)
@export var fuel_matches_content: bool = false  ## If true, fuel must be same content as data (Recoverer mode)
