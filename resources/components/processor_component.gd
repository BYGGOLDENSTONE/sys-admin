class_name ProcessorComponent
extends Resource

@export var processing_rate: float = 3.0  ## MB/s
@export var input_types: Array[String] = []  ## Accepted input types
@export var output_type: String = ""  ## What it produces
@export var rule: String = ""  ## Processing rule identifier
@export var efficiency: float = 1.0  ## 0.0-1.0 output ratio (1.0 = no loss)
