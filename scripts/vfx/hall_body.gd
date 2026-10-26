@tool
extends StaticBody3D
## A villager's body, wrapped in a sheet and tied, laid on the hall floor to wait for the fire.
## Shown restrained on purpose: a shroud with rope bindings, no face, no wounds. The body lies
## along its local Z axis (head toward -Z), origin on the floor. It is solid (a low box), so
## nobody walks through it; when the story hides it ([hide Body2]: thrown on the fire) its
## collision switches off too, and the bonfire (hall_bonfire.gd) flares and the cube pulses.
## The same shape, charred, is drawn into the bonfire's own mesh by add_to().

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	shroud = preload("res://materials/hall_shroud.tres"),
	soiled = preload("res://materials/hall_shroud_soiled.tres"),
	rope = preload("res://materials/hall_rope.tres"),
	charred = preload("res://materials/hall_charred.tres"),
}

## Hidden by the story after the level settled: the bonfire listens and flares.
signal thrown(body: Node3D)

## Metres from head to feet.
@export var length := 1.7:
	set(value):
		length = value
		_rebuild()
## A dirtier sheet.
@export var soiled := false:
	set(value):
		soiled = value
		_rebuild()
## Changes the small bends and the knots, so two bodies don't look identical.
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()

var _mesh := MeshInstance3D.new()
var _shape := CollisionShape3D.new()
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)
var _settled := false


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	add_child(_shape, false, INTERNAL_MODE_FRONT)
	_mesh.layers = 1
	_rebuild()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()
	# A saved game replays [hide BodyN] as the level loads: that is not a throw.
	get_tree().create_timer(1.0, false).timeout.connect(func() -> void: _settled = true)


func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	var pm := PropMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4073 * (variant + 1)
	add_to(pm, Transform3D.IDENTITY, length, M.soiled if soiled else M.shroud, M.rope, rng)
	_mesh.mesh = pm.commit()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.3, length)
	_shape.shape = box
	_shape.position = Vector3(0, 0.15, 0)


func _on_visibility_changed() -> void:
	var shown := is_visible_in_tree()
	_shape.set_deferred("disabled", not shown)
	if not shown and _settled:
		thrown.emit(self)


## Draws one wrapped body into `pm` at `xf` (local Z = head to feet, origin on the floor).
## `rope` may be null (burnt through). Used by the bonfire for the bodies already on the fire.
static func add_to(pm: PropMesh, xf: Transform3D, body_len: float, cloth: Material, rope: Material,
		rng: RandomNumberGenerator) -> void:
	var bend := rng.randf_range(-0.1, 0.1)
	var flat := Basis.from_scale(Vector3(1.0, 0.62, 1.0))
	# The wrapped trunk and legs: one tapered roll from the shoulders to the ankles.
	var z0 := -0.3 * body_len
	var z1 := 0.42 * body_len
	var roll := Basis(Vector3.UP, bend) * flat * Basis(Vector3.RIGHT, PI / 2)  # its Y axis runs to the feet
	pm.cyl(cloth, 0.12, 0.21, z1 - z0, xf * Transform3D(roll, Vector3(0, 0.13, (z0 + z1) * 0.5)), 10)
	# Rounded parts over it: [along (fraction), half width, half height, length].
	var parts := [
		[-0.43, 0.115, 0.105, 0.2],   # head
		[-0.36, 0.1, 0.085, 0.14],    # neck
		[-0.27, 0.225, 0.14, 0.3],    # shoulders
		[0.02, 0.2, 0.13, 0.4],       # hips
		[0.43, 0.12, 0.085, 0.16],    # feet
	]
	for p: Array in parts:
		var along: float = p[0]
		var c := Vector3(bend * along, p[2], along * body_len)
		var s := Vector3(p[1] * 2.0, p[2] * 2.0, p[3] * body_len / 1.7)
		var turn := Basis(Vector3.UP, rng.randf_range(-0.05, 0.05) + bend)
		pm.sphere(cloth, 0.5, 1.0, xf * Transform3D(turn * Basis.from_scale(s), c), 10, 5)
	# The sheet's loose end past the feet.
	pm.box(cloth, Vector3(0.2, 0.03, 0.16), xf * Transform3D(Basis(Vector3.UP, 0.2 + bend), Vector3(bend * 0.5, 0.03, 0.52 * body_len)))
	if rope == null:
		return  # burnt through
	# Bindings round the chest, the knees and the ankles.
	var ties := [[-0.2, 0.225, 0.14], [0.2, 0.17, 0.115], [0.37, 0.135, 0.09]]
	for t: Array in ties:
		var along: float = t[0]
		var c := Vector3(bend * along, t[2], along * body_len)
		var band := Basis(Vector3.UP, bend) * Basis.from_scale(Vector3(t[1] * 1.05, t[2] * 1.05, 1.0)) * Basis(Vector3.RIGHT, PI / 2)
		pm.ring(rope, 0.97, 1.03, xf * Transform3D(band, c), 10, 4)
