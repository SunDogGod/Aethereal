@tool
extends Node3D
## A neon sign: a dark box with a strip of glowing glyphs in ONE colour, and an OmniLight in the
## same colour that tints the wall round it. The glyphs are an invented alphabet of twelve fat
## shapes (each a few thick strokes on a 3 x 5 grid); `text` picks one shape per letter, so the
## same word always looks the same and no real word is ever readable. The origin is on the wall,
## at the middle of the sign's back; the glyphs face +Z. For a blade sign standing out from a
## wall, turn `double_sided` on, give it a `bracket` and turn the node 90 degrees.
## Flicker makes the glyphs and the light stutter together. No collision.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const Flicker := preload("res://scripts/props_kit/kit_flicker.gd")
const IRON := preload("res://materials/kit_iron.tres")
const NEON := preload("res://materials/kit_neon.tres")
# Each glyph: strokes as [column, row, columns wide, rows tall] on a 3-wide, 5-tall grid (row 0 at the top).
const GLYPHS := [
	[[0, 0, 1, 5], [2, 0, 1, 5], [0, 0, 3, 1]],                       # gate
	[[0, 0, 3, 1], [2, 0, 1, 3], [0, 2, 3, 1]],                       # hook
	[[0, 0, 1, 4], [2, 0, 1, 4], [0, 3, 3, 1], [1, 3, 1, 2]],         # little yus
	[[0, 0, 1, 5], [0, 2, 3, 1], [2, 2, 1, 3]],                       # ladder
	[[0, 0, 3, 1], [0, 4, 3, 1], [1, 1, 1, 3]],                       # beam
	[[1, 0, 1, 5], [0, 0, 1, 2], [2, 0, 1, 2]],                       # fork
	[[0, 0, 2, 1], [1, 0, 1, 3], [1, 2, 2, 1], [2, 2, 1, 3]],         # step
	[[0, 0, 3, 1], [0, 0, 1, 5], [2, 0, 1, 3]],                       # arch
	[[0, 0, 3, 1], [2, 1, 1, 1], [0, 2, 3, 1], [0, 3, 1, 1], [0, 4, 3, 1]],  # zig
	[[0, 0, 1, 1], [2, 0, 1, 1], [0, 2, 3, 1], [1, 3, 1, 2]],         # horns
	[[1, 0, 1, 1], [0, 1, 3, 1], [0, 2, 1, 3], [2, 2, 1, 3]],         # tent
	[[0, 0, 1, 3], [2, 0, 1, 3], [0, 2, 3, 1], [1, 2, 1, 3], [0, 4, 3, 1]],  # big yus
]

@export var text := "AETHER":
	set(value):
		text = value
		_rebuild()
## One colour per sign (the rule): the glyphs, the border and the light all use it.
@export var tint := Color(1.0, 0.25, 0.65):
	set(value):
		tint = value
		_rebuild()
@export var glyph_height := 0.4:
	set(value):
		glyph_height = maxf(value, 0.1)
		_rebuild()
@export var depth := 0.12:
	set(value):
		depth = maxf(value, 0.03)
		_rebuild()
## A dim strip of the same colour round the edge of the face.
@export var border := true:
	set(value):
		border = value
		_rebuild()
## Glyphs on both faces (a blade sign); the box is then centred on the origin.
@export var double_sided := false:
	set(value):
		double_sided = value
		_rebuild()
## Metres of iron arm from the sign's left edge to the wall (0 = none).
@export var bracket := 0.0:
	set(value):
		bracket = maxf(value, 0.0)
		_rebuild()
@export_range(0.0, 4.0) var glow := 2.0:
	set(value):
		glow = value
		_rebuild()
@export var light_energy := 1.0:
	set(value):
		light_energy = value
		_rebuild()
@export var light_range := 5.0:
	set(value):
		light_range = value
		_rebuild()
@export_enum("None", "Steady", "Failing tube", "Dying bulb") var flicker := 0
## 0 = a different flicker every run; any other number repeats the same one.
@export var random_seed := 0

var _mesh := MeshInstance3D.new()
var _light := OmniLight3D.new()
var _neon: ShaderMaterial
var _dim: ShaderMaterial
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
	_neon = NEON.duplicate()
	_neon.set_shader_parameter("albedo_color", tint.lerp(Color.WHITE, 0.4))
	_neon.set_shader_parameter("emission_color", tint)
	_neon.set_shader_parameter("emission_energy", glow)
	_dim = NEON.duplicate()
	_dim.set_shader_parameter("albedo_color", tint.darkened(0.5))
	_dim.set_shader_parameter("emission_color", tint)
	_dim.set_shader_parameter("emission_energy", glow * 0.35)
	var cell := glyph_height / 5.0
	var cols := _columns()
	var w := (cols + 3.0) * cell
	var h := (5.0 + 3.0) * cell
	var back := 0.0 if double_sided else depth * 0.5
	var pm := PropMesh.new()
	pm.box(IRON, Vector3(w, h, depth), Transform3D(Basis(), Vector3(0, 0, back)))
	_face(pm, cols, cell, w, h, back + depth * 0.5, 1.0)
	if double_sided:
		_face(pm, cols, cell, w, h, back - depth * 0.5, -1.0)
	if bracket > 0.0:
		var x := -w * 0.5
		for y: float in [h * 0.35, -h * 0.35]:
			pm.stick(IRON, Vector3(x, y, back), Vector3(x - bracket, y, back), 0.04)
		pm.box(IRON, Vector3(0.04, h * 0.9, 0.2), Transform3D(Basis(), Vector3(x - bracket, 0, back)))
	_mesh.mesh = pm.commit()
	_light.position = Vector3(0, 0, back if double_sided else depth + 0.5)
	_light.light_color = tint
	_light.light_energy = light_energy
	_light.omni_range = light_range


## Grid columns the text takes: 3 per glyph, 1 between, 2 for a space.
func _columns() -> int:
	var n := 0
	for ch in text:
		n += 2 if ch == " " else 4
	return maxi(n - 1, 1)


## The glyph strip and border on one face at z = `z`, read left to right from `side` (+1 front).
func _face(pm: PropMesh, cols: int, cell: float, w: float, h: float, z: float, side: float) -> void:
	var x := -cols * cell * 0.5
	for ch in text:
		if ch == " ":
			x += 2.0 * cell
			continue
		var glyph: Array = GLYPHS[(ch.unicode_at(0) + 5) % GLYPHS.size()]
		for s: Array in glyph:
			var sx: float = x + (s[0] + s[2] * 0.5) * cell
			var sy: float = (2.5 - s[1] - s[3] * 0.5) * cell
			pm.box(_neon, Vector3(s[2] * cell, s[3] * cell, 0.04), Transform3D(Basis(), Vector3(sx * side, sy, z + side * 0.02)))
		x += 4.0 * cell
	if border:
		var t := 0.025
		var zb := z + side * 0.015
		pm.box(_dim, Vector3(w - 0.08, t, 0.03), Transform3D(Basis(), Vector3(0, h * 0.5 - 0.04, zb)))
		pm.box(_dim, Vector3(w - 0.08, t, 0.03), Transform3D(Basis(), Vector3(0, -h * 0.5 + 0.04, zb)))
		pm.box(_dim, Vector3(t, h - 0.08, 0.03), Transform3D(Basis(), Vector3(w * 0.5 - 0.04, 0, zb)))
		pm.box(_dim, Vector3(t, h - 0.08, 0.03), Transform3D(Basis(), Vector3(-w * 0.5 + 0.04, 0, zb)))


func _process(delta: float) -> void:
	if _flicker:
		var lvl: float = _flicker.level(delta)
		Flicker.drive(_light, light_energy, _neon, glow, lvl)
		Flicker.drive(null, 0.0, _dim, glow * 0.35, lvl)
