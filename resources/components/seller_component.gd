class_name SellerComponent
extends Resource

@export var sell_rate: float = 3.0  ## MB/s consumed
@export var credits_per_mb: float = 1.0  ## Base credits earned per MB sold
@export var accepted_states: Array[int] = [0]  ## DataState values accepted (default: CLEAN)
@export var content_price_multipliers: Dictionary = {}  ## {ContentType: multiplier} e.g. {0:1.0, 1:5.0}
