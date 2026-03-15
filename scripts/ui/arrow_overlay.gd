extends Control

## Minimal drawing proxy for GuidedTutorial.
## Calls guided_tutorial.draw_arrows(self) during _draw(),
## so draw commands execute in the correct CanvasItem context.

var guided_tutorial = null

func _draw():
	if guided_tutorial and guided_tutorial.has_method("draw_arrows"):
		guided_tutorial.draw_arrows(self)
