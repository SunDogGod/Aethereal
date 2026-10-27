@tool
extends Node3D
## One figure of the Massacre memory (the courtyard crowd, the elder, the raiders): a person in a
## robe, made of simple shapes. No faces: it is a four-year-old's fragment of a memory, seen
## through the haze. A stand-in until the village has real character models.
##   Villager: robe, sash, sleeves, hair or a straw hat (Variant picks colours and headwear).
##   Child: the same, smaller, with a bigger head.
##   Elder: pale robe, white hair, a slight stoop and a staff.
##   Raider: a long black coat and hood, an iron blade held low.
## Origin on the floor, facing +Z. Drawn on render layer 2 (characters: the blob shadow skips it).
## Purely visual: no collision. Identical figures share one mesh while the game runs.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	skin = preload("res://materials/massacre_skin.tres"), hair = preload("res://materials/massacre_fur_black.tres"),
	white = preload("res://materials/massacre_fur_white.tres"), straw = preload("res://materials/massacre_straw.tres"),
	timber = preload("res://materials/massacre_timber.tres"), iron = preload("res://materials/massacre_iron.tres"),
	coat = preload("res://materials/black_cube.tres"),
	indigo = preload("res://materials/massacre_cloth_indigo.tres"), red = preload("res://materials/massacre_cloth_red.tres"),
	ochre = preload("res://materials/massacre_cloth_ochre.tres"), linen = preload("res://materials/massacre_cloth_white.tres"),
}

@export_enum("Villager", "Child", "Elder", "Raider") var kind := 0:
	set(value):
		kind = value
		_rebuild()
## Changes the colours and the headwear, so the crowd isn't all one person.
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()
## Standing height in metres (0 = the kind's usual height).
@export var height := 0.0:
	set(value):
		height = value
		_rebuild()

var pm: PropMesh
var s := 1.0  # this figure's scale against a 1.75 m adult
var _mesh := MeshInstance3D.new()
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	_mesh.layers = 2
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


## Every setting calls this: the mesh is built once, when the figure is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	var usual: Array[float] = [1.75, 1.1, 1.6, 1.85]
	var tall: float = height if height > 0.0 else usual[clampi(kind, 0, 3)]
	var key := [&"crowd_figure", kind, variant % 8, snappedf(tall, 0.01)]
	var mesh := MeshBuild.shared(key)
	if mesh == null:
		s = tall / 1.75
		pm = PropMesh.new()
		match kind:
			1: _person(1.35)
			2: _elder()
			3: _raider()
			_: _person(1.0)
		mesh = pm.commit()
		pm = null
		MeshBuild.share(key, mesh)
	_mesh.mesh = mesh


func _cloth(k: int) -> Material:
	return [M.indigo, M.red, M.ochre, M.linen][posmod(k, 4)]


# Shapes in a 1.75 m adult's measurements, scaled by `s`.
func _c(mat: Material, r_top: float, r_bottom: float, h: float, at: Vector3, sides := 8) -> void:
	pm.cyl(mat, r_top * s, r_bottom * s, h * s, Transform3D(Basis(), at * s), sides)


func _ball(mat: Material, r: float, h: float, at: Vector3, sides := 8, rings := 4) -> void:
	pm.sphere(mat, r * s, h * s, Transform3D(Basis(), at * s), sides, rings)


func _stick(mat: Material, a: Vector3, b: Vector3, thick: float) -> void:
	pm.stick(mat, a * s, b * s, thick * s)


func _box(mat: Material, size: Vector3, at: Vector3, b := Basis()) -> void:
	pm.box(mat, size * s, Transform3D(b, at * s))


## The robed body every kind shares; `stoop` moves the shoulders and head forward (metres).
func _body(robe: Material, sash: Material, stoop := 0.0) -> void:
	_c(robe, 0.17, 0.25, 0.9, Vector3(0, 0.45, 0))                 # the robe's skirt
	_c(robe, 0.2, 0.17, 0.5, Vector3(0, 1.15, stoop * 0.5))         # chest
	_c(sash, 0.18, 0.18, 0.09, Vector3(0, 0.93, 0.0))              # the sash at the waist
	for sx: float in [-1.0, 1.0]:
		# The under-robe's collar, crossed at the chest.
		_box(M.linen, Vector3(0.035, 0.2, 0.02), Vector3(sx * 0.045, 1.27, 0.185 + stoop * 0.5), Basis(Vector3.FORWARD, sx * 0.45))
		_box(M.hair, Vector3(0.1, 0.06, 0.17), Vector3(sx * 0.08, 0.03, 0.1))  # feet under the hem
		var sh := Vector3(sx * 0.21, 1.37, stoop)
		var wrist := Vector3(sx * 0.25, 1.0, 0.08 + stoop)
		_stick(robe, sh, wrist, 0.1)                                          # the sleeve
		_c(robe, 0.05, 0.075, 0.12, wrist + Vector3(0, 0.02, 0), 6)           # its wide cuff
		_ball(M.skin, 0.045, 0.08, wrist + Vector3(0, -0.06, 0.01), 6, 3)     # the hand
	_ball(robe, 0.22, 0.14, Vector3(0, 1.38, stoop), 8, 3)          # shoulders
	_c(M.skin, 0.05, 0.055, 0.1, Vector3(0, 1.47, stoop))          # neck


func _head(at: Vector3, scale_head: float, hair: Material, style: int) -> void:
	var r := 0.105 * scale_head
	_ball(M.skin, r, r * 2.3, at, 8, 4)
	match style:
		0:  # cropped hair
			_ball(hair, r * 1.06, r * 1.9, at + Vector3(0, r * 0.25, -r * 0.12), 8, 4)
		1:  # hair tied in a bun
			_ball(hair, r * 1.06, r * 1.9, at + Vector3(0, r * 0.25, -r * 0.12), 8, 4)
			_ball(hair, r * 0.45, r * 0.8, at + Vector3(0, r * 0.9, -r * 0.65), 6, 3)
		2:  # a wide straw hat
			_ball(hair, r * 1.04, r * 1.8, at + Vector3(0, r * 0.2, -r * 0.1), 8, 4)
			_c(M.straw, 0.0, r * 2.6, r * 1.3, at + Vector3(0, r * 1.2, 0), 10)
		_:  # a cloth headscarf
			_ball(_cloth(variant + 3), r * 1.12, r * 2.0, at + Vector3(0, r * 0.2, -r * 0.18), 8, 4)


func _person(scale_head: float) -> void:
	var robe := _cloth(variant)
	_body(robe, _cloth(variant + 2))
	var neck_top := 1.52
	_head(Vector3(0, neck_top + 0.105 * scale_head, 0), scale_head, M.hair, (variant >> 1) % 4)


func _elder() -> void:
	var stoop := 0.07
	_body(M.linen if variant % 2 == 0 else M.indigo, M.ochre, stoop)
	_head(Vector3(0, 1.6, stoop + 0.03), 1.0, M.white, 1)
	_stick(M.timber, Vector3(0.32, 0.0, 0.2), Vector3(0.3, 1.45, 0.14), 0.04)  # the staff


func _raider() -> void:
	_c(M.coat, 0.19, 0.29, 1.05, Vector3(0, 0.525, 0))            # long coat, flared
	_c(M.coat, 0.23, 0.19, 0.45, Vector3(0, 1.25, 0))             # chest
	_c(M.iron, 0.2, 0.2, 0.07, Vector3(0, 1.04, 0))                # belt
	_box(M.iron, Vector3(0.3, 0.26, 0.06), Vector3(0, 1.27, 0.19))  # a breast plate
	_ball(M.coat, 0.26, 0.17, Vector3(0, 1.47, 0), 8, 3)          # shoulders
	for sx: float in [-1.0, 1.0]:
		_box(M.hair, Vector3(0.11, 0.08, 0.2), Vector3(sx * 0.1, 0.04, 0.08))  # boots
		var sh := Vector3(sx * 0.25, 1.45, 0)
		var wrist := Vector3(sx * 0.28, 1.05, 0.12)
		_stick(M.coat, sh, wrist, 0.11)
		_ball(M.hair, 0.05, 0.09, wrist + Vector3(0, -0.06, 0.01), 6, 3)       # gloves
	# The blade, held low and forward in the right hand.
	_stick(M.iron, Vector3(-0.28, 0.98, 0.16), Vector3(-0.3, 0.3, 0.7), 0.035)
	_box(M.iron, Vector3(0.12, 0.03, 0.05), Vector3(-0.28, 0.97, 0.17))
	# The hood, pulled forward over a face you never see.
	_ball(M.coat, 0.135, 0.3, Vector3(0, 1.68, -0.01), 8, 4)
	_c(M.coat, 0.0, 0.1, 0.14, Vector3(0, 1.84, -0.05), 6)
