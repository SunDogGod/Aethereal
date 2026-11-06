@tool
extends Node3D
## Rooftop clutter scattered by rule from a seed, so a skyline of flat boxes stops being a bar
## chart: water tanks on legs, antenna masts with guy lines, banks of AC units, vent hoods, one
## stair head box in a corner, and a parapet railing round the edge. Origin at the centre of a
## flat roof, on its surface; Size is the roof's x and z. The roof is split into 3 m cells, and
## Density is the share of cells that get something. Change Random Seed until you like the roof.
## With Solid on, each piece gets a box so the player can't walk through it (only needed on
## roofs he can reach). Everything is one mesh, built once (mesh_build.gd).

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const Pieces := preload("res://scripts/props_kit/rooftop_pieces.gd")
const CELL := 3.0

@export var size := Vector2(12, 10):
	set(value):
		size = Vector2(maxf(value.x, 3.0), maxf(value.y, 3.0))
		_rebuild()
@export var random_seed := 1:
	set(value):
		random_seed = value
		_rebuild()
@export_range(0.0, 1.0) var density := 0.6:
	set(value):
		density = value
		_rebuild()
@export var railing := true:
	set(value):
		railing = value
		_rebuild()
@export var stair_head := true:
	set(value):
		stair_head = value
		_rebuild()
@export var solid := false:
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
var _boxes: Array = []  # [size, Transform3D] pairs for the collision
var piece_count := 0  # how many things were scattered (for checks)
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
	var pm := PropMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	_boxes.clear()
	piece_count = 0
	var inset := 1.2  # keep clear of the railing
	var nx := maxi(1, int((size.x - inset * 2.0) / CELL))
	var nz := maxi(1, int((size.y - inset * 2.0) / CELL))
	var cw := (size.x - inset * 2.0) / nx
	var cd := (size.y - inset * 2.0) / nz
	var stair_cell := Vector2i(-1, -1)
	if stair_head:
		# In a corner, its door facing into the roof.
		stair_cell = Vector2i(rng.randi_range(0, 1) * (nx - 1), rng.randi_range(0, 1) * (nz - 1))
		var c := _cell_centre(stair_cell, nx, nz, cw, cd)
		var turn := atan2(-c.x, -c.z)  # the door (+Z face) looks toward the roof's middle
		Pieces.stair_head(pm, c, snappedf(turn, PI * 0.5), _boxes)
		piece_count += 1
	for ix in nx:
		for iz in nz:
			if Vector2i(ix, iz) == stair_cell or rng.randf() > density:
				continue
			var c := _cell_centre(Vector2i(ix, iz), nx, nz, cw, cd)
			c += Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3)) * minf(cw, cd) / CELL
			var pick := rng.randf()
			if pick < 0.3:
				Pieces.tank(pm, rng, c, _boxes)
			elif pick < 0.55:
				Pieces.mast(pm, rng, c, size)
			elif pick < 0.85:
				Pieces.ac_bank(pm, rng, c, rng.randi_range(0, 1) * PI * 0.5, _boxes)
			else:
				Pieces.vent(pm, rng, c, _boxes)
			piece_count += 1
	if railing:
		Pieces.railing(pm, size, _boxes)
	_mesh.mesh = pm.commit()
	if is_inside_tree():
		_collide()


func _cell_centre(cell: Vector2i, nx: int, nz: int, cw: float, cd: float) -> Vector3:
	return Vector3((cell.x - (nx - 1) * 0.5) * cw, 0.0, (cell.y - (nz - 1) * 0.5) * cd)


## One StaticBody3D (layer 1, like the Blocks) with a box per piece, when Solid is on.
func _collide() -> void:
	if _body:
		_body.queue_free()
		_body = null
	if not solid or _boxes.is_empty():
		return
	_body = StaticBody3D.new()
	add_child(_body, false, INTERNAL_MODE_FRONT)
	for pair in _boxes:
		var shape := BoxShape3D.new()
		shape.size = pair[0]
		var col := CollisionShape3D.new()
		col.shape = shape
		col.transform = pair[1]
		_body.add_child(col)
