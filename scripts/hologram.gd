extends Node3D
## A flickering hologram: fades in and out at random and drifts up and down a little.

@export var flicker := 0.35  ## how much it flickers (0 = steady)

var _base_y := 0.0
var _time := 0.0


func _ready() -> void:
	_base_y = position.y
	randomize()


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 1.3) * 0.06
	var on := 1.0 - flicker * (0.5 + 0.5 * sin(_time * 23.0) * sin(_time * 7.1))
	if randf() < 0.02 * flicker:
		on = 0.15
	for child in get_children():
		if child is MeshInstance3D:
			child.transparency = clampf(1.0 - on, 0.0, 0.9)
