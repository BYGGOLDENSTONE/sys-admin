class_name SellerComponent
extends Resource

@export var sell_rate: float = 3.0  ## MB/s consumed
@export var credits_per_mb: float = 1.0  ## Credits earned per MB sold
@export var accepted_types: Array[String] = ["clean"]
