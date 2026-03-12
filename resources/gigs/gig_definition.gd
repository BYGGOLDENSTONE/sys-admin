class_name GigDefinition
extends Resource

@export var gig_name: String = ""
@export_multiline var description: String = ""
@export var order_index: int = 0
@export var is_tutorial: bool = true
@export var prerequisite_gigs: Array[int] = []  ## order_indices that must complete before activation
@export var requirements: Array[Resource] = []
@export var reward_buildings: Array[String] = []
