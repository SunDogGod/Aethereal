@tool
extends StaticBody3D
## The shared part of the Massacre's prop scripts (village_prop.gd, village_house.gd, ...): ONE
## mesh built from simple shapes (scripts/props/prop_mesh.gd), plus, with Solid on, a box
## collision around the prop's footprint so Aeneas bumps into it like a wall. A solid prop is
## never a step: it is taller than a step, or it is left walk-through.
## A walk-through prop (Solid off, or a Kind with no footprint) has no collision shape at all and
## its body is taken out of the physics world, so the many small things cost physics nothing
## (and a cat that breathes doesn't move a body every frame).
## Origin on the floor; a prop that stands against a wall has the wall behind it (-Z), facing +Z.
## The mesh and collision are made in code, so the Scene panel only shows the prop itself.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	timber = preload("res://materials/massacre_timber.tres"), plank = preload("res://materials/massacre_timber_light.tres"),
	ridge = preload("res://materials/massacre_tile_ridge.tres"),
	clay = preload("res://materials/terracotta.tres"), plaster = preload("res://materials/white_plaster.tres"),
	paper = preload("res://materials/massacre_paper.tres"), lit = preload("res://materials/massacre_paper_lit.tres"),
	red_paper = preload("res://materials/massacre_paper_red.tres"), stone = preload("res://materials/massacre_stone.tres"),
	moss = preload("res://materials/massacre_stone_moss.tres"), soil = preload("res://materials/massacre_soil.tres"),
	water = preload("res://materials/massacre_water.tres"), straw = preload("res://materials/massacre_straw.tres"),
	indigo = preload("res://materials/massacre_cloth_indigo.tres"), red = preload("res://materials/massacre_cloth_red.tres"),
	ochre = preload("res://materials/massacre_cloth_ochre.tres"), linen = preload("res://materials/massacre_cloth_white.tres"),
	iron = preload("res://materials/massacre_iron.tres"), leaf = preload("res://materials/leaf.tres"),
	leaf2 = preload("res://materials/massacre_leaf_light.tres"), blossom = preload("res://materials/massacre_blossom.tres"),
	fruit = preload("res://materials/massacre_fruit.tres"), coal = preload("res://materials/massacre_glow_coal.tres"),
	ceramic = preload("res://materials/ceramic.tres"), brass = preload("res://materials/brass.tres"),
	dark = preload("res://materials/black_cube.tres"), rope = preload("res://materials/massacre_straw.tres"),
	ginger = preload("res://materials/massacre_fur_ginger.tres"), black = preload("res://materials/massacre_fur_black.tres"),
	white = preload("res://materials/massacre_fur_white.tres"), bird = preload("res://materials/massacre_bird.tres"),
	candle = preload("res://materials/candle.tres"), metal = preload("res://materials/metal_worn.tres"),
	yellow = preload("res://materials/paint_yellow.tres"), teal = preload("res://materials/paint_teal.tres"),
}

## Changes colours and small details, so two of the same Kind don't look identical.
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()
## Off = walk-through (purely visual).
@export var solid := true:
	set(value):
		solid = value
		_rebuild()
## Not drawn beyond this many metres (0 = always drawn). It fades out over FADE metres there
## (dithered by the PS1 screen) instead of switching off at once.
@export var draw_distance := 0.0:
	set(value):
		draw_distance = value
		_mesh.visibility_range_end = maxf(value, 0.0)

const FADE := 8.0

## The prop's collision box in its own space (set by each Kind; read by the audit scripts).
var footprint := AABB()
var pm: PropMesh
var _mesh := MeshInstance3D.new()
var _shape: CollisionShape3D  # only while the prop is solid
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	_mesh.visibility_range_end_margin = FADE
	_mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _notification(what: int) -> void:
	# After the body's own handling, which puts every body into the world.
	if what == NOTIFICATION_ENTER_WORLD or what == NOTIFICATION_ENABLED:
		_set_in_physics(_shape != null)


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	pm = PropMesh.new()
	footprint = AABB()
	_build()
	_mesh.mesh = pm.commit()
	var walk_through := not solid or footprint.size == Vector3.ZERO
	if walk_through:
		if _shape:
			_shape.queue_free()
			_shape = null
	else:
		if _shape == null:
			_shape = CollisionShape3D.new()
			add_child(_shape, false, INTERNAL_MODE_FRONT)
		var box := BoxShape3D.new()
		box.size = footprint.size
		_shape.shape = box
		_shape.position = footprint.get_center()
	if is_inside_tree():
		_set_in_physics(not walk_through)


## A walk-through prop's body leaves the physics world (it has nothing to collide with);
## a solid one joins it. The node, its picking and its mesh are unchanged.
func _set_in_physics(on: bool) -> void:
	var space := get_world_3d().space if on and is_inside_tree() else RID()
	PhysicsServer3D.body_set_space(get_rid(), space)


## Each script fills `pm` with shapes here and sets `footprint` with fp().
func _build() -> void:
	pass


func fp(size: Vector3, center: Vector3) -> void:
	footprint = AABB(center - size * 0.5, size)


static func at(x: float, y: float, z: float, b := Basis()) -> Transform3D:
	return Transform3D(b, Vector3(x, y, z))


## A box between two corners (axis-aligned in the prop's space).
func span(mat: Material, a: Vector3, b: Vector3) -> void:
	pm.box(mat, (b - a).abs(), Transform3D(Basis(), (a + b) * 0.5))


## A box turned `yaw` radians about Y, centred at `c`.
func turned(mat: Material, size: Vector3, c: Vector3, yaw: float) -> void:
	pm.box(mat, size, Transform3D(Basis(Vector3.UP, yaw), c))


## A small deterministic random number in [0, 1) from the variant and a salt.
func rnd(salt: int) -> float:
	var h := hash(variant * 7919 + salt * 104729)
	return float(absi(h) % 10007) / 10007.0
