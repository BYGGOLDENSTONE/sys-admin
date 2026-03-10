class_name ProducerComponent
extends Resource

@export var consume_amount: int = 5  ## MB of input consumed per production
@export var input_content: int = 4  ## ContentType accepted (default: Research)
@export var input_state: int = 0  ## DataState accepted (default: Public)
@export var output_content: int = 6  ## ContentType produced (default: Key)
@export var output_state: int = 0  ## DataState produced (default: Public)
@export var processing_rate: float = 2.0  ## Max productions per tick
@export var max_tier: int = 1  ## Max tier producible (1=T1 only, 3=T1-T3)
@export var tier2_extra_content: int = -1  ## Additional content needed for T2 Key (-1=none)
@export var tier2_extra_amount: int = 0  ## MB of extra content consumed for T2
@export var tier3_extra_content: int = -1  ## Additional content needed for T3 Key (-1=none)
@export var tier3_extra_amount: int = 0  ## MB of extra content consumed for T3
