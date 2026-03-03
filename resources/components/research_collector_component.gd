class_name ResearchCollectorComponent
extends Resource

@export var collection_rate: float = 5.0  ## MB/s research data consumed
@export var accepted_types: Array[String] = ["research"]
@export var research_per_mb: float = 1.0  ## Research points per MB consumed
