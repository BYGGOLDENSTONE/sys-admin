class_name DataSourceDefinition
extends Resource

@export var source_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color.CYAN
@export var content_weights: Dictionary = {}  ## {ContentType: weight} probability distribution
@export var state_weights: Dictionary = {}    ## {DataState: weight} probability distribution
@export var bandwidth: float = 5.0            ## Max MB/s this source can provide
@export var cell_count_range: Vector2i = Vector2i(8, 12)  ## Min/max cells for organic shape
