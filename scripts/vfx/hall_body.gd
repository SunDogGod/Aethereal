@tool
extends StaticBody3D
## A dead villager on the hall floor, waiting for the fire. Shown restrained on purpose: no faces,
## no wounds. Either wrapped in a sheet and tied (`clothed` off), or lying face down in their own
## clothes as they fell. The shape is hall_figure.gd's: head, trunk, arms and legs, so it reads as a
## person. The body lies along its local Z axis (head toward -Z), origin on the floor. It is solid
## (a low box), so nobody walks through it; when the story hides it ([hide Body2]: thrown on the
## fire) its collision switches off too, and the bonfire (hall_bonfire.gd) flares and the Black
## Cube takes the soul.

const HallFigure := preload("res://scripts/vfx/hall_figure.gd")
const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const SHADER := preload("res://shaders/ps1_surface.gdshader")
const M := {
	shroud = preload("res://materials/hall_shroud.tres"),
	soiled = preload("res://materials/hall_shroud_soiled.tres"),
	rope = preload("res://materials/hall_rope.tres"),
}
## Clothes for the villagers who are not wrapped yet: muted, worn colours.
const TUNICS := [Color(0.36, 0.31, 0.24), Color(0.24, 0.28, 0.34), Color(0.4, 0.22, 0.18), Color(0.3, 0.33, 0.24)]
const POSES := [
	{},                                                      # 0: laid straight
	{arm_r = 1, knee_l = 0.35, head_turn = 0.3},             # 1: fallen, one arm flung out
	{arm_l = 2, arm_r = 1, knee_r = 0.5, head_turn = -0.4},  # 2: sprawled
]

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
## Not wrapped yet: face down in their own clothes.
@export var clothed := false:
	set(value):
		clothed = value
		_rebuild()
## How they lie: 0 laid straight, 1 one arm flung out, 2 sprawled.
@export_range(0, 2) var pose := 0:
	set(value):
		pose = value
		_rebuild()
## Changes the small bends and the clothes, so two bodies don't look identical.
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()

static var _mats := {}  # colour -> a plain PS1 material, made once

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
	var look := {cloth = M.soiled if soiled else M.shroud, rope = M.rope}
	if clothed:
		look = {tunic = plain(TUNICS[variant % TUNICS.size()]), trousers = plain(Color(0.17, 0.15, 0.13)),
				skin = plain(Color(0.5, 0.39, 0.32)), hair = plain(Color(0.07, 0.055, 0.05))}
	HallFigure.add(pm, Transform3D.IDENTITY, length, look, POSES[clampi(pose, 0, POSES.size() - 1)], rng)
	_mesh.mesh = pm.commit()
	var box := BoxShape3D.new()
	# Taller than the body: a 0.3 m box is low enough for the navmesh to think fighters can step
	# onto it (they can't), so they would walk into it. 0.7 m is plainly an obstacle.
	box.size = Vector3(0.55 if pose == 0 else 0.8, 0.7, length)
	_shape.shape = box
	_shape.position = Vector3(0, 0.35, 0)


func _on_visibility_changed() -> void:
	var shown := is_visible_in_tree()
	_shape.set_deferred("disabled", not shown)
	# Only the story hiding this body ([hide BodyN]) is a throw. The world hiding the whole
	# town zone when Aeneas walks out hides it too, and that must not feed the fire.
	if not visible and _settled:
		thrown.emit(self)


## A plain PS1 material in one colour (shared between bodies).
static func plain(color: Color) -> ShaderMaterial:
	if not _mats.has(color):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("albedo_color", color)
		_mats[color] = m
	return _mats[color]
