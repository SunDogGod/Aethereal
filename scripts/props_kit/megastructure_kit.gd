@tool
extends Node3D
## Big non-box silhouettes for the megastructure, picked from Kind: a buttress (a slanted brace
## from high on a wall down to the floor), an arch, a round shaft that rises out of sight into
## the fog, a stepped setback slab, a cantilevered walkway stub broken at its end, a bundle of
## chains hanging from a ceiling, a lattice gantry crossing a gap. The shapes themselves are in
## megastructure_shapes.gd. The wall a piece hangs off is behind the origin (-Z); pieces reach
## out along +Z; the shaft stands on the origin; the chains hang from it. Length is the reach
## (buttress foot, arch span, walkway, gantry); Height the rise (buttress, arch piers, shaft,
## setback, chain hang); Radius the thickness (brace width, shaft radius, step run, half the
## walkway or gantry width, chain spread). With Solid on, the parts you could walk into get a
## box (the shaft a cylinder), built when the game runs, never saved in the scene.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const Shapes := preload("res://scripts/props_kit/megastructure_shapes.gd")

@export_enum("Buttress", "Arch", "Shaft", "Setback", "Walkway stub", "Chain bundle", "Gantry") var kind := 0:
	set(value):
		kind = value
		_rebuild()
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()
@export var length := 12.0:
	set(value):
		length = maxf(value, 1.0)
		_rebuild()
@export var height := 20.0:
	set(value):
		height = maxf(value, 1.0)
		_rebuild()
@export var radius := 1.5:
	set(value):
		radius = maxf(value, 0.2)
		_rebuild()
## The concrete of the piece; its iron parts (straps, rails, chains, trusses) stay iron.
@export var material: Material = preload("res://materials/kitb_concrete.tres"):
	set(value):
		material = value
		_rebuild()
@export var solid := true:
	set(value):
		solid = value
		_rebuild()
## Not drawn beyond this many metres (0 = always drawn).
@export var draw_distance := 0.0:
	set(value):
		draw_distance = value
		_mesh.visibility_range_end = maxf(value, 0.0)

var _mesh := MeshInstance3D.new()
var _body: StaticBody3D
var _boxes: Array = []  # [size, Transform3D] (and "cyl" for the shaft) for the collision
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _ready() -> void:
	_collide()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	_mesh.visibility_range_end = maxf(draw_distance, 0.0)
	_boxes.clear()
	if material == null:
		_mesh.mesh = null
		return
	var pm := PropMesh.new()
	match kind:
		0: Shapes.buttress(pm, material, length, height, radius, variant, _boxes)
		1: Shapes.arch(pm, material, length, height, radius, _boxes)
		2: Shapes.shaft(pm, material, height, radius, variant, _boxes)
		3: Shapes.setback(pm, material, length, height, radius, variant, _boxes)
		4: Shapes.walkway(pm, material, length, radius, _boxes)
		5: Shapes.chains(pm, height, radius, variant)
		6: Shapes.gantry(pm, length, radius, _boxes)
	_mesh.mesh = pm.commit()
	if is_inside_tree():
		_collide()


## One StaticBody3D (layer 1, like the Blocks) with a shape per solid part.
func _collide() -> void:
	if _body:
		_body.queue_free()
		_body = null
	if not solid or _boxes.is_empty():
		return
	_body = StaticBody3D.new()
	add_child(_body, false, INTERNAL_MODE_FRONT)
	for pair in _boxes:
		var col := CollisionShape3D.new()
		if pair.size() > 2:
			var cyl := CylinderShape3D.new()
			cyl.radius = pair[0].x * 0.5
			cyl.height = pair[0].y
			col.shape = cyl
		else:
			var box := BoxShape3D.new()
			box.size = pair[0]
			col.shape = box
		col.transform = pair[1]
		_body.add_child(col)
