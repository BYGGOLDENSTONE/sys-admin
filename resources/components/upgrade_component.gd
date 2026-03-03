class_name UpgradeComponent
extends Resource

@export var max_level: int = 3
@export var costs: Array[int] = [10, 25, 50]  ## Patch Data cost per level
@export var stat_label: String = ""  ## Display name: "Verimlilik", "Hız", "Kapasite"
@export var stat_target: String = ""  ## Target: "efficiency", "processing_rate", "capacity", "zone_radius", "cooling_rate"
@export var level_values: Array[float] = []  ## Value at each upgrade level (1, 2, 3...)
