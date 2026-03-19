class_name DataSourceDefinition
extends Resource

@export var source_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color.CYAN
@export var content_weights: Dictionary = {}  ## {ContentType: weight} probability distribution
@export var state_weights: Dictionary = {}    ## {DataState: weight} probability distribution
@export var bandwidth: float = 5.0            ## MB/s per connected output port
@export var generation_rate: float = 5.0      ## Data units per tick per connected port
@export var grid_size: Vector2i = Vector2i(2, 2)  ## Rectangular footprint (width, height)
@export var output_port_count: int = 0  ## 0 = auto from grid_size, >0 = fixed count (distributed across edges, excluding FIRE side)
@export var difficulty: String = "easy"  ## easy, medium, hard, endgame
@export var encrypted_tier: int = 0  ## Fixed tier: 0=none, 1=4-bit, 2=16-bit
@export var corrupted_tier: int = 0  ## Fixed tier: 0=none, 1=Minor-Glitched, 2=Major-Glitched
@export var sub_type_pool: Array[Dictionary] = []  ## [{content: int, sub_type: int}] — which sub-types this source produces

## FIRE (Forced Isolation & Restriction Enforcer)
@export var fire_type: String = "none"  ## "none" / "threshold" / "regen"
@export var fire_requirements: Array[Dictionary] = []  ## [{sub_type: int, amount: int}] — sub_type = content*4+offset
@export var fire_regen_rate: float = 0.0  ## MB/s — only for "regen" type, how fast FIRE regenerates when feed stops
