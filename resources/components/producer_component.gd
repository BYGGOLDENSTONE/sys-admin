class_name ProducerComponent
extends Resource

@export var consume_amount: int = 5  ## MB of input consumed per production
@export var input_content: int = 4  ## ContentType accepted (default: Research)
@export var input_state: int = 0  ## DataState accepted (default: Clean)
@export var output_content: int = 6  ## ContentType produced (default: Key)
@export var output_state: int = 0  ## DataState produced (default: Clean)
@export var processing_rate: float = 2.0  ## Max productions per tick
