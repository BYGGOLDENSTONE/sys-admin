class_name GigRequirement
extends Resource

@export var content: int = 0   ## DataEnums.ContentType
@export var state: int = 0     ## DataEnums.DataState (-1 = any)
@export var tags: int = 0      ## DataEnums.ProcessingTag bitmask (0 = no tag requirement)
@export var min_tier: int = 0  ## Minimum source tier required (0 = any)
@export var amount: int = 10
@export var label: String = "" ## Display label e.g. "Standard Public"
@export var packet_key: String = "" ## If set, matches packet deliveries instead of individual data
