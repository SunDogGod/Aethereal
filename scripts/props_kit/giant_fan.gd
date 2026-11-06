@tool
extends Node3D
## A giant slow fan set into a wall (the Blade Runner / Blame! ventilation ring): a concrete
## ring housing with an iron rim, a dark duct going back into the wall, five fat blades that
## turn slowly while the game runs, a grille of fat bars across the front, and (with Lit on) a
## glowing disc and an OmniLight behind the blades. Real-time shadows are off, so the blades
## can't block the light by themselves: the light pulses once per blade pass instead, and the
## blades read as dark silhouettes crossing the lit disc.
## Origin at the centre of the ring, on the wall's face; the housing is a drum `depth` deep
## standing proud of the wall along +Z, the blades and grille at its mouth, the glow at its back.
## (To sink it flush, move the node `depth` into the wall and leave a hole in the wall.)
## Turn the node to face the street. Solid adds one box round the drum for a fan at floor level.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const CONCRETE := preload("res://materials/kitb_concrete.tres")
const IRON := preload("res://materials/kitb_iron.tres")
const BLADE := preload("res://materials/kitb_blade.tres")
const VOID := preload("res://materials/black_sand_void.tres")
const BACKLIGHT := preload("res://materials/kitb_backlight.tres")

@export var radius := 3.0:
	set(value):
		radius = maxf(value, 0.5)
		_rebuild()
@export_range(3, 9) var blade_count := 5:
	set(value):
		blade_count = value
		_rebuild()
## Radians per second (0.5 is a slow, heavy turn; negative turns the other way).
@export var speed := 0.5
## How deep the duct goes back into the wall.
@export var depth := 1.5:
	set(value):
		depth = maxf(value, 0.4)
		_rebuild()
@export var lit := true:
	set(value):
		lit = value
		_rebuild()
## The backlight's colour: sodium orange by default, the one hot note of the place.
@export var color := Color(1.0, 0.62, 0.25):
	set(value):
		color = value
		_rebuild()
@export var light_energy := 1.6:
	set(value):
		light_energy = value
		_rebuild()
@export var grille := true:
	set(value):
		grille = value
		_rebuild()
## A box over the grille, for a fan the player can walk up to.
@export var solid := false:
	set(value):
		solid = value
		_rebuild()

var _mesh := MeshInstance3D.new()
var _blades := MeshInstance3D.new()
var _light := OmniLight3D.new()
var _body: StaticBody3D
var _angle := 0.0
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	add_child(_blades, false, INTERNAL_MODE_FRONT)
	add_child(_light, false, INTERNAL_MODE_FRONT)
	_light.shadow_enabled = false
	_rebuild()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	var pm := PropMesh.new()
	var r := radius
	var d := depth
	var facing := Basis(Vector3.RIGHT, PI * 0.5)  # a cylinder's Y turned to run along Z
	# The drum: a concrete shell standing proud of the wall, 16 slabs outside and 16 inside (a
	# cylinder would close the mouth with its end cap and only show its outside), a dark back
	# plate against the wall, the mouth at z = depth.
	for k in 16:
		var a := TAU * (k + 0.5) / 16.0
		var spin := Basis(Vector3.BACK, a)
		var out := Vector3(cos(a), sin(a), 0)
		pm.box(CONCRETE, Vector3(0.08, 2.0 * r * sin(PI / 16.0) * 1.08, d), Transform3D(spin, out * (r + 0.04) + Vector3(0, 0, d * 0.5)))
		pm.box(CONCRETE, Vector3(0.12, 2.0 * (r + 0.5) * sin(PI / 16.0) * 1.08, d), Transform3D(spin, out * (r + 0.5) + Vector3(0, 0, d * 0.5)))
	pm.cyl(VOID, r * 0.99, r * 0.99, 0.05, Transform3D(facing, Vector3(0, 0, 0.03)), 16)
	# The mouth: a concrete collar and an iron rim ring with bolt bosses.
	pm.ring(CONCRETE, r, r + 0.6, Transform3D(facing, Vector3(0, 0, d - 0.1)), 20, 6)
	pm.ring(IRON, r + 0.05, r + 0.38, Transform3D(facing, Vector3(0, 0, d + 0.1)), 20, 4)
	for k in 8:
		var a := TAU * k / 8.0
		pm.box(IRON, Vector3(0.24, 0.24, 0.14), Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a), sin(a), 0) * (r + 0.45) + Vector3(0, 0, d + 0.08)))
	if grille:
		_grille(pm, r, d + 0.18)
	if lit:
		var glow: ShaderMaterial = BACKLIGHT.duplicate()
		glow.set_shader_parameter("emission_color", color)
		glow.set_shader_parameter("albedo_color", color)
		pm.cyl(glow, r * 0.84, r * 0.84, 0.05, Transform3D(facing, Vector3(0, 0, 0.08)), 16)
	_mesh.mesh = pm.commit()
	_blades.mesh = _blade_mesh(r)
	_blades.position = Vector3(0, 0, d - 0.55)
	_light.visible = lit
	_light.light_color = color
	_light.light_energy = light_energy
	_light.omni_range = r * 4.0
	_light.position = Vector3(0, 0, d * 0.4)
	if is_inside_tree():
		_collide()


## Fat bars across the mouth: uprights every ~r/2.2, one cross bar, all set into the rim.
func _grille(pm: PropMesh, r: float, z: float) -> void:
	var n := maxi(2, int(r / 1.1))
	for i in range(-n, n + 1):
		var x := r * i / (n + 0.5)
		var half := sqrt(maxf(r * r - x * x, 0.0))
		pm.box(IRON, Vector3(0.14, half * 2.0 + 0.2, 0.1), Transform3D(Basis(), Vector3(x, 0, z)))
	pm.box(IRON, Vector3(r * 2.0 + 0.2, 0.16, 0.1), Transform3D(Basis(), Vector3(0, 0, z)))


## The hub and the blades, their own mesh so they can turn: each blade a fat box pitched 0.5
## rad, with a short stubby root block so the blades read as cast, not cut from sheet.
func _blade_mesh(r: float) -> ArrayMesh:
	var pm := PropMesh.new()
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	pm.cyl(IRON, r * 0.2, r * 0.2, 0.7, Transform3D(facing, Vector3.ZERO), 10)
	pm.cyl(IRON, r * 0.1, r * 0.2, 0.25, Transform3D(facing, Vector3(0, 0, 0.45)), 10)
	for i in blade_count:
		var a := TAU * i / blade_count
		var spin := Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, 0.5)
		pm.box(BLADE, Vector3(r * 0.76, r * 0.34, 0.09), Transform3D(spin, Basis(Vector3.BACK, a) * Vector3(r * 0.56, 0, 0)))
		pm.box(BLADE, Vector3(r * 0.2, r * 0.18, 0.16), Transform3D(spin, Basis(Vector3.BACK, a) * Vector3(r * 0.24, 0, 0)))
	return pm.commit()


func _ready() -> void:
	_collide()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_angle = fmod(_angle + speed * delta, TAU)
	_blades.rotation = Vector3(0, 0, _angle)
	if lit:
		# No shadows, so the blades can't cut the light: it dips once per blade pass instead.
		var pulse := 0.5 + 0.5 * cos(_angle * blade_count)
		_light.light_energy = light_energy * (0.55 + 0.45 * pulse)


func _collide() -> void:
	if _body:
		_body.queue_free()
		_body = null
	if not solid:
		return
	_body = StaticBody3D.new()
	add_child(_body, false, INTERNAL_MODE_FRONT)
	var shape := BoxShape3D.new()
	shape.size = Vector3(radius * 2.0 + 1.2, radius * 2.0 + 1.2, depth + 0.3)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0, depth * 0.5 + 0.1)
	_body.add_child(col)
