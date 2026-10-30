extends Node3D
## A group that is shown by the story ([show Raiders]): while it is hidden, nothing inside it is
## solid. A hidden StaticBody3D still collides in Godot, so without this the burning cubes stood
## invisible in the village before the raiders came, and Aeneas walked into thin air.
## Put it on the group's root node; it follows that node's own `visible` flag.

var _layers := {}  # body -> its collision_layer while the group is shown


func _ready() -> void:
	for body in find_children("*", "CollisionObject3D", true, false):
		_layers[body] = body.collision_layer
	visibility_changed.connect(_sync)
	_sync()


func _sync() -> void:
	for body in _layers:
		if is_instance_valid(body):
			body.collision_layer = _layers[body] if visible else 0
