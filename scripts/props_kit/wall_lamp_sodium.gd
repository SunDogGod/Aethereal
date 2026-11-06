@tool
extends Node3D
## A plain caged bulkhead lamp: an iron plate on the wall, a stubby warm glass bulb under a cage
## of four bars, and a sodium-orange OmniLight that pools on the wall and floor. The origin is on
## the surface it is bolted to; with `mount` Wall the lamp sticks out along +Z (turn the node to
## face the room), with Ceiling it hangs straight down. The bulb and the light flicker together
## if you ask. No collision (it is small).

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const Flicker := preload("res://scripts/props_kit/kit_flicker.gd")
const IRON := preload("res://materials/kit_iron.tres")
const GLASS := preload("res://materials/kit_sodium_glass.tres")

@export_enum("Wall", "Ceiling") var mount := 0:
	set(value):
		mount = value
		_rebuild()
## Sodium orange by default.
@export var color := Color(1.0, 0.62, 0.25):
	set(value):
		color = value
		_rebuild()
@export var light_energy := 2.0:
	set(value):
		light_energy = value
		_rebuild()
@export var light_range := 7.0:
	set(value):
		light_range = value
		_rebuild()
## 1 is a hand-sized lamp; 1.4 (the default) a bulkhead you notice; 2.5 a big industrial one.
@export_range(0.5, 3.0) var scale_factor := 1.4:
	set(value):
		scale_factor = value
		_rebuild()
@export var cage := true:
	set(value):
		cage = value
		_rebuild()
@export_range(0.0, 4.0) var glow := 1.8:
	set(value):
		glow = value
		_rebuild()
@export_enum("None", "Steady", "Failing tube", "Dying bulb") var flicker := 0
## 0 = a different flicker every run; any other number repeats the same one.
@export var random_seed := 0

var _mesh := MeshInstance3D.new()
var _light := OmniLight3D.new()
var _glass: ShaderMaterial
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
	_glass = GLASS.duplicate()
	_glass.set_shader_parameter("albedo_color", color.lerp(Color.WHITE, 0.6))
	_glass.set_shader_parameter("emission_color", color)
	_glass.set_shader_parameter("emission_energy", glow)
	# Built sticking out along +Z, then turned to hang down for a ceiling.
	var frame := Basis(Vector3.RIGHT, PI * 0.5) if mount == 1 else Basis()
	var k := scale_factor
	var pm := PropMesh.new()
	pm.box(IRON, Vector3(0.3, 0.3, 0.04) * k, _at(frame, Vector3(0, 0, 0.02) * k))
	var along := Basis(Vector3.RIGHT, PI * 0.5)  # a cylinder standing along Z
	pm.cyl(IRON, 0.1 * k, 0.12 * k, 0.06 * k, _at(frame, Vector3(0, 0, 0.07) * k, along), 8)
	pm.cyl(_glass, 0.09 * k, 0.1 * k, 0.16 * k, _at(frame, Vector3(0, 0, 0.18) * k, along), 8)
	pm.sphere(_glass, 0.09 * k, 0.18 * k, _at(frame, Vector3(0, 0, 0.26) * k), 8, 4)
	if cage:
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				var a := frame * (Vector3(sx * 0.12, sy * 0.12, 0.04) * k)
				var b := frame * (Vector3(sx * 0.07, sy * 0.07, 0.33) * k)
				pm.stick(IRON, a, b, 0.018 * k)
		pm.ring(IRON, 0.085 * k, 0.11 * k, _at(frame, Vector3(0, 0, 0.33) * k, along), 10, 4)  # a thin hoop, not a lid
	_mesh.mesh = pm.commit()
	_light.position = frame * (Vector3(0, 0, 0.4) * k)
	_light.light_color = color
	_light.light_energy = light_energy
	_light.omni_range = light_range


func _at(frame: Basis, p: Vector3, turn := Basis()) -> Transform3D:
	return Transform3D(frame * turn, frame * p)


func _process(delta: float) -> void:
	if _flicker:
		Flicker.drive(_light, light_energy, _glass, glow, _flicker.level(delta))
