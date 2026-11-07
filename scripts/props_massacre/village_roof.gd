@tool
extends "res://scripts/props_massacre/village_prop_base.gd"
## A village roof on its own, for a house built from Blocks that Aeneas can walk into (the family
## house in the Massacre): the gable of round terracotta tiles from roof_kit.gd, its plaster gable
## ends, and a dark plank ceiling closing the room under it. The ridge runs along local X.
## Origin at the wall top, in the middle; Length (x) by Depth (z) are the walls' outside size.
## Walk-through: it is all above head height.

const Roof := preload("res://scripts/props_massacre/roof_kit.gd")

@export var length := 10.0:
	set(value):
		length = value
		_rebuild()
@export var depth := 8.0:
	set(value):
		depth = value
		_rebuild()
@export var pitch := 28.0:
	set(value):
		pitch = value
		_rebuild()


func _build() -> void:
	var mats := {roof = M.clay, ridge = M.ridge, timber = M.timber, gable = M.plaster}
	Roof.gable(pm, mats, Transform3D(), length, depth, 0.0, pitch, Vector2(0.8, 0.8), 0.4)
	pm.box(M.timber, Vector3(length - 0.1, 0.1, depth - 0.1), at(0, -0.05, 0))  # the ceiling
	for k in int(length / 2.0):  # beams under it
		pm.box(M.timber, Vector3(0.16, 0.18, depth - 0.2), at(-length * 0.5 + 1.0 + k * 2.0, -0.19, 0))
