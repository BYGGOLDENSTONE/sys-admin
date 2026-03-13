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
@export var difficulty: String = "easy"  ## easy, medium, hard, endgame
@export var encrypted_max_tier: int = 1  ## Max tier for Encrypted state (T1-T4)
@export var corrupted_max_tier: int = 1  ## Max tier for Corrupted state (T1-T4)
