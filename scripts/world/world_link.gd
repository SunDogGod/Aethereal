class_name WorldLink
extends Node3D
## A walkway between two zones of the big world (the service stair from the town's hall down to
## Black Sand, the road tunnel from Black Sand to the station). Its pieces are built in world
## coordinates. While Aeneas is inside `box`, both zones are shown and their fog, light and music
## blend from zone A to zone B along the line from the marker Blend/A to Blend/B.
## The levels it joins are not edited: the link lists the pieces of each level it replaces
## (an end wall, a barrier) and brings its own. Children of InA / InB move into that zone's level
## when the world starts, so they show and hide with it (a doorway, a gangway, a wall with a hole).

@export var zone_a: NodePath   ## a WorldZone
@export var zone_b: NodePath
@export var box := AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))  ## in this node's coordinates
@export var replaces_in_a := PackedStringArray()  ## paths in zone A's level, removed in the world
@export var replaces_in_b := PackedStringArray()
@export var show_within := 25.0  ## metres: the walkway is drawn (and solid) once Aeneas is this close to its box

var a: WorldZone
var b: WorldZone
var _from := Vector3.ZERO  # Blend/A and Blend/B in world coordinates
var _to := Vector3.ZERO


## Called once, before anything enters the tree.
func prepare(world: World) -> void:
	a = get_node(zone_a) as WorldZone
	b = get_node(zone_b) as WorldZone
	_from = World.xf_in(world, get_node("Blend/A") as Node3D).origin
	_to = World.xf_in(world, get_node("Blend/B") as Node3D).origin
	for path in replaces_in_a:
		World.drop(a.level.get_node_or_null(path))
	for path in replaces_in_b:
		World.drop(b.level.get_node_or_null(path))
	_move_into(world, get_node_or_null("InA"), a)
	_move_into(world, get_node_or_null("InB"), b)


func has_point(world_point: Vector3) -> bool:
	return box.has_point(transform.affine_inverse() * world_point)


## 0 at Blend/A (all zone A), 1 at Blend/B (all zone B).
func progress(world_point: Vector3) -> float:
	var line := _to - _from
	return clampf((world_point - _from).dot(line) / maxf(line.length_squared(), 0.001), 0.0, 1.0)


func _move_into(world: World, group: Node3D, zone: WorldZone) -> void:
	if group == null:
		return
	var level_xf := World.xf_in(world, zone.level)
	for child in group.get_children():
		var piece := child as Node3D
		var at := World.xf_in(world, piece)
		World.unown(piece)
		group.remove_child(piece)
		zone.level.add_child(piece)
		piece.transform = level_xf.affine_inverse() * at
	group.free()


## True when a point is within `show_within` metres of the box (or inside it).
func is_near(world_point: Vector3) -> bool:
	return box.grow(show_within).has_point(transform.affine_inverse() * world_point)
