class_name DataSourceDefinition
extends Resource

@export var source_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color.CYAN
@export var content_weights: Dictionary = {}  ## {ContentType: weight} probability distribution
@export var state_weights: Dictionary = {}    ## {DataState: weight} probability distribution
@export var bandwidth: float = 5.0            ## Max MB/s this source can provide
@export var cell_count_range: Vector2i = Vector2i(8, 12)  ## Min/max cells for organic shape
@export var difficulty: String = "easy"  ## easy, medium, hard, endgame
@export var encrypted_max_tier: int = 1  ## Max tier for Encrypted state (T1-T4)
@export var corrupted_max_tier: int = 1  ## Max tier for Corrupted state (T1-T4)
