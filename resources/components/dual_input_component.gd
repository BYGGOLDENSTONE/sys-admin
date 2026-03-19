class_name DualInputComponent
extends Resource

@export var processing_rate: float = 4.0  ## MB/s (base rate for tier 1)
@export var speed_by_tier: Array[float] = [1.0, 0.5]  ## Speed multiplier per tier [T1, T2] — higher tier = slower
@export var primary_input_states: Array[int] = []  ## Accepted states for main input (e.g. ENCRYPTED)
@export var key_content: int = 6  ## ContentType used as key (default: KEY)
@export var key_cost: int = 1  ## Keys consumed per data unit (base / T1)
@export var tier_key_costs: Array[int] = [1, 1, 1, 1]  ## Key cost per tier: [T1, T2, T3, T4]
@export var output_state: int = 0  ## Output DataState (default: Public)
@export var output_tag: int = 1  ## ProcessingTag to add (1=DECRYPTED, 2=RECOVERED, 4=ENCRYPTED)
@export var fuel_matches_content: bool = false  ## If true, fuel must be same content as data (Recoverer mode)
@export var required_fuel_tags: Array[int] = []  ## Per-tier required fuel tags: [T1_tags, T2_tags, T3_tags, T4_tags]
@export var success_rate_by_tier: Array[float] = []  ## Per-tier success chance [T1, T2, T3, T4]. Empty = always succeed.
@export var consumes_on_fail: bool = true  ## If true, key/fuel consumed even on failure
