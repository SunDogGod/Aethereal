@tool
extends Node3D
## The captors' lamp and cult mark: a ring of iron segments with one glowing eye in the middle
## (a lit lens, two dark lids, a dark iris with a hot pupil, all fat strokes), and a warm sodium
## OmniLight at the eye. Pick where it hangs with `mount`: a street post standing on the node
## (origin at the foot), a stalk hanging from a ceiling (origin on the ceiling), or a bracket on
## a wall (origin on the wall, the ring hangs in front along +Z). The ring faces +Z and -Z: turn
## the node to face the street. The eye and the halo studs take the light's colour, and can
## flicker. No collision (a post is thin; put a Block round it if people must not walk through).

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const Flicker := preload("res://scripts/props_kit/kit_flicker.gd")
const IRON := preload("res://materials/kit_iron.tres")
const IRIS := preload("res://materials/kit_iris.tres")
const EYE := preload("res://materials/kit_eye.tres")
const SEGMENTS := 12

@export_enum("Post", "Ceiling", "Wall") var mount := 0:
	set(value):
		mount = value
		_rebuild()
@export var ring_radius := 0.6:
	set(value):
		ring_radius = maxf(value, 0.2)
		_rebuild()
## Post: how tall the post is. Ceiling and Wall: how far below the origin the ring's top hangs.
@export var height := 4.0:
	set(value):
		height = maxf(value, 0.0)
		_rebuild()
## Sodium orange by default; the eye glows in the same colour.
@export var color := Color(1.0, 0.62, 0.25):
	set(value):
		color = value
		_rebuild()
@export var light_energy := 1.2:
	set(value):
		light_energy = value
		_rebuild()
@export var light_range := 9.0:
	set(value):
		light_range = value
		_rebuild()
## How hard the eye and the halo studs glow.
@export_range(0.0, 4.0) var eye_glow := 2.2:
	set(value):
		eye_glow = value
		_rebuild()
@export_enum("None", "Steady", "Failing tube", "Dying bulb") var flicker := 0
## 0 = a different flicker every run; any other number repeats the same one.
@export var random_seed := 0

var _mesh := MeshInstance3D.new()
var _light := OmniLight3D.new()
var _eye_mat: ShaderMaterial
var _flicker: RefCounted
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	add_child(_light, false, INTERNAL_MODE_FRONT)
	_light.shadow_enabled = false
	_rebuild()


func _ready() -> void:
	if not Engine.is_editor_hint() and flicker > 0:
		_flicker = Flicker.new(flicker, random_seed)


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	_eye_mat = EYE.duplicate()
	_eye_mat.set_shader_parameter("albedo_color", color.lerp(Color.WHITE, 0.5))
	_eye_mat.set_shader_parameter("emission_color", color)
	_eye_mat.set_shader_parameter("emission_energy", eye_glow)
	var pm := PropMesh.new()
	var c := _mount(pm)
	_ring(pm, c)
	_eye(pm, c)
	_mesh.mesh = pm.commit()
	_light.position = c + Vector3(0, 0, 0.1)
	_light.light_color = color
	_light.light_energy = light_energy
	_light.omni_range = light_range


## The post, stalk or bracket; returns where the ring's centre goes.
func _mount(pm: PropMesh) -> Vector3:
	var r := ring_radius
	match mount:
		1:  # a stalk from the ceiling
			pm.box(IRON, Vector3(0.3, 0.04, 0.3), Transform3D(Basis(), Vector3(0, -0.02, 0)))
			pm.stick(IRON, Vector3(0, -0.04, 0), Vector3(0, -height, 0), 0.05)
			return Vector3(0, -height - r, 0)
		2:  # a bracket out from a wall, then a drop
			pm.box(IRON, Vector3(0.3, 0.3, 0.04), Transform3D(Basis(), Vector3(0, 0, 0.02)))
			pm.stick(IRON, Vector3(0, 0, 0.02), Vector3(0, 0, 0.5), 0.05)
			pm.stick(IRON, Vector3(0, 0, 0.5), Vector3(0, -height, 0.5), 0.05)
			return Vector3(0, -height - r, 0.5)
	# a street post
	pm.box(IRON, Vector3(0.36, 0.06, 0.36), Transform3D(Basis(), Vector3(0, 0.03, 0)))
	pm.cyl(IRON, 0.05, 0.07, height, Transform3D(Basis(), Vector3(0, height * 0.5, 0)), 8)
	pm.ring(IRON, 0.02, 0.09, Transform3D(Basis(), Vector3(0, height - 0.05, 0)), 10, 4)
	pm.stick(IRON, Vector3(0, height, 0), Vector3(0, height + 0.15, 0), 0.05)
	return Vector3(0, height + 0.15 + r, 0)


## The halo: iron segments round the eye, each with a glowing stud on its inner face, and a
## crossbar through the middle that carries the eye.
func _ring(pm: PropMesh, c: Vector3) -> void:
	var r := ring_radius
	var seg := 2.0 * r * sin(PI / SEGMENTS) * 1.08
	for i in SEGMENTS:
		var ang := TAU * i / SEGMENTS
		var turn := Basis(Vector3(0, 0, 1), ang + PI * 0.5)
		var out := Vector3(cos(ang), sin(ang), 0)
		pm.box(IRON, Vector3(seg, 0.11, 0.08), Transform3D(turn, c + out * r))
		pm.box(_eye_mat, Vector3(seg * 0.55, 0.035, 0.1), Transform3D(turn, c + out * (r - 0.075)))
	pm.box(IRON, Vector3(r * 2.0 - 0.06, 0.06, 0.05), Transform3D(Basis(), c + Vector3(0, 0, -0.01)))
	pm.stick(IRON, c + Vector3(0, r * 0.42, 0), c + Vector3(0, r - 0.05, 0), 0.05)


## The eye: a lit lens, dark lids above and below (an almond), a dark iris, a hot pupil.
func _eye(pm: PropMesh, c: Vector3) -> void:
	var lr := ring_radius * 0.42
	var face := Basis(Vector3.RIGHT, PI * 0.5)  # a cylinder standing along Z
	pm.cyl(_eye_mat, lr, lr, 0.07, Transform3D(face, c), 12)
	pm.box(IRIS, Vector3(lr * 2.0, lr * 0.6, 0.09), Transform3D(Basis(), c + Vector3(0, lr * 0.8, 0)))
	pm.box(IRIS, Vector3(lr * 2.0, lr * 0.5, 0.09), Transform3D(Basis(), c + Vector3(0, -lr * 0.85, 0)))
	pm.cyl(IRIS, lr * 0.42, lr * 0.42, 0.09, Transform3D(face, c), 10)
	pm.cyl(_eye_mat, lr * 0.15, lr * 0.15, 0.11, Transform3D(face, c), 8)


func _process(delta: float) -> void:
	if _flicker:
		Flicker.drive(_light, light_energy, _eye_mat, eye_glow, _flicker.level(delta))
