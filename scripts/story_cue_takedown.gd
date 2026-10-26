extends "res://scripts/story_trigger.gd"
## A story trigger that plays its scene the first time Aeneas is offered a paired takedown
## (the prompt "Isabella binds the other"), wherever that is: the first sight of her ink.
## It has no zone; leave Monitoring off. Saving treats it like any trigger (by its scene's name).

var _takedown: Node


func _ready() -> void:
	_listen()


func _physics_process(_delta: float) -> void:
	if _done:
		set_physics_process(false)
		return
	if _takedown == null:
		var player := get_tree().get_first_node_in_group("player")
		_takedown = player.get_node_or_null("Takedown") if player else null
		if _takedown and _takedown.has_signal("prompt_changed"):
			_takedown.prompt_changed.connect(_on_prompt)


func _on_prompt(text: String) -> void:
	if not _done and "Isabella" in text:  # player_takedown.gd's paired prompt
		_play()
