extends Node3D
## Lights in a dream: each child (a small glowing sphere) drifts slowly around where it was
## placed. Only moves while shown (the dream set is hidden the rest of the time, so it costs
## nothing then).

@export var drift := 0.3   ## metres each one wanders from its place
@export var speed := 0.35  ## how fast they wander

var _home: Array[Vector3] = []
var _time := 0.0


func _ready() -> void:
	for child in get_children():
		_home.append((child as Node3D).position if child is Node3D else Vector3.ZERO)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta * speed
	var i := 0
	for child in get_children():
		if child is Node3D and i < _home.size():
			var k := float(i) * 2.17
			(child as Node3D).position = _home[i] + Vector3(
					sin(_time + k) * drift,
					sin(_time * 0.7 + k * 1.3) * drift * 0.5,
					cos(_time * 0.8 + k * 0.6) * drift)
		i += 1
