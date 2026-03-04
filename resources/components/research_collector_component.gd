class_name ResearchCollectorComponent
extends Resource

@export var collection_rate: float = 5.0  ## MB/s research data consumed
@export var accepted_content: Array[int] = [4]  ## ContentType values (default: RESEARCH)
@export var accepted_states: Array[int] = [0]  ## DataState values (default: CLEAN)
@export var research_per_mb: float = 1.0  ## Research points per MB consumed
