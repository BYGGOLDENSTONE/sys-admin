class_name GeneratorComponent
extends Resource

@export var generation_rate: float = 5.0  ## MB/s produced
@export var content_weights: Dictionary = {}  ## {0: 0.30, 1: 0.15, ...} ContentType → weight
@export var state_weights: Dictionary = {}  ## {0: 0.30, 1: 0.25, ...} DataState → weight
