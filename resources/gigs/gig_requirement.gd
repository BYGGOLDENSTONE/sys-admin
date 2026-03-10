class_name GigRequirement
extends Resource

@export var content: int = 0   ## DataEnums.ContentType
@export var state: int = 0     ## DataEnums.DataState (-1 = any)
@export var amount: int = 10
@export var label: String = "" ## Display label e.g. "Standard Public"
