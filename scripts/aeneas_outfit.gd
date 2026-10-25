@tool
extends Node3D
## Aeneas's outfit switches, on the root of his model (scenes/characters/aeneas_model.tscn).
## In a level, select Player > Model and tick or untick them in the Inspector; to change him
## everywhere, do it in scenes/player.tscn. The first arc has the poncho on; a later arc can
## switch it off and he wears the jacket underneath.
## (The model scene is rebuilt by tools/blender/make_wrapper.gd, which puts this script back on.)

@export var poncho := true:  ## the travel poncho with its hood down (and the rifle sling over it)
	set(value):
		poncho = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return
	var mesh := find_child("Poncho", true, false) as Node3D
	if mesh:
		mesh.visible = poncho
