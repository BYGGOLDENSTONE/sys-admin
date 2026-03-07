class_name CompilerRecipe
extends Resource

@export var recipe_name: String = ""
@export var input_a_content: int = 0  ## ContentType for input A (left port)
@export var input_b_content: int = 0  ## ContentType for input B (top port)
@export var output_refined: int = 0   ## RefinedType produced
@export var input_a_cost: int = 1     ## MB of input A consumed per craft
@export var input_b_cost: int = 1     ## MB of input B consumed per craft
