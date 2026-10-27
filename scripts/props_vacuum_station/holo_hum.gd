extends AudioStreamPlayer3D
## A sound that follows its own `visible` switch, so a dialogue scene can wake it with [show Name]
## (and [hide Name] silences it). The station AI's hum starts hidden and silent; the_ai shows it
## when the emitter wakes, and StoryReplay's [show] brings it back on Continue.
## Only this node's own switch counts: a world zone hiding the whole level doesn't stop it.

var _on := false


func _ready() -> void:
	_on = visible
	if _on and not playing:
		play()


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED or not is_node_ready() or visible == _on:
		return
	_on = visible
	if _on:
		play()
	else:
		stop()
