class_name GeneratorComponent
extends Resource

@export var generation_rate: float = 5.0  ## MB/s produced
@export var data_weights: Dictionary = {}  ## {"clean": 0.3, "corrupted": 0.25, ...}
