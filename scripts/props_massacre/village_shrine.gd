@tool
extends "res://scripts/props_massacre/village_prop_base.gd"
## The village shrine's pieces, picked from Kind. Origin on the ground, facing +Z.
##   Shrine: a small timber shrine house (hokora) on a stone plinth, a tiled roof, a rope with
##     paper streamers across its front, an offering box, candles, rice cakes and a cup of sake.
##     Solid (the plinth).
##   Torii: a vermilion gate; Width = the opening. Walk-through.
##   Jizo row: three small stone figures with red bibs and caps, Width long. Walk-through.

const Roof := preload("res://scripts/props_massacre/roof_kit.gd")
const VERMILION := preload("res://materials/massacre_vermilion.tres")

@export_enum("Shrine", "Torii", "Jizo row") var kind := 0:
	set(value):
		kind = value
		_rebuild()
@export var width := 2.6:
	set(value):
		width = value
		_rebuild()


func _build() -> void:
	match kind:
		0: _shrine()
		1: _torii()
		2: _jizo()


func _shrine() -> void:
	pm.box(M.stone, Vector3(2.0, 0.5, 1.7), at(0, 0.25, 0))
	pm.box(M.stone, Vector3(1.3, 0.25, 0.5), at(0, 0.125, 1.05))  # the step
	pm.box(M.moss, Vector3(2.04, 0.06, 1.74), at(0, 0.03, 0))
	var y0 := 0.5
	pm.box(M.plank, Vector3(1.3, 0.1, 1.1), at(0, y0 + 0.05, -0.1))
	pm.box(M.timber, Vector3(1.1, 0.95, 0.8), at(0, y0 + 0.6, -0.2))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pm.box(M.timber, Vector3(0.1, 1.15, 0.1), at(sx * 0.6, y0 + 0.62, -0.1 + sz * 0.5))
	pm.box(M.lit, Vector3(0.7, 0.6, 0.02), at(0, y0 + 0.55, 0.21))  # the lit doors
	for k in 4:
		pm.box(M.timber, Vector3(0.025, 0.6, 0.03), at(-0.26 + k * 0.175, y0 + 0.55, 0.23))
	Roof.gable(pm, {roof = M.clay, ridge = M.ridge, timber = M.timber, gable = M.timber}, Transform3D(Basis(), Vector3(0, 0, -0.1)),
			1.3, 1.1, y0 + 1.2, 30.0, Vector2(0.45, 0.35), 0.25)
	# The rope and its streamers.
	var prev := Vector3(-0.62, y0 + 1.1, 0.42)
	for k in range(1, 7):
		var t := k / 6.0
		var p := Vector3(-0.62 + 1.24 * t, y0 + 1.1 - 0.12 * 4.0 * t * (1.0 - t), 0.42)
		pm.stick(M.straw, prev, p, 0.06)
		prev = p
	for k in 4:
		var x := -0.42 + k * 0.28
		pm.box(M.linen, Vector3(0.06, 0.24, 0.01), at(x, y0 + 0.88, 0.45, Basis(Vector3.FORWARD, 0.15 * (k % 2 * 2 - 1))))
	# The offering box, candles, rice cakes, a cup.
	pm.box(M.timber, Vector3(0.7, 0.35, 0.35), at(0, 0.67, 0.62))
	for k in 5:
		pm.box(M.dark, Vector3(0.6, 0.015, 0.03), at(0, 0.85, 0.5 + k * 0.06))
	for sx: float in [-1.0, 1.0]:
		pm.cyl(M.brass, 0.05, 0.07, 0.1, at(sx * 0.55, 0.55, 0.55), 6)
		pm.cyl(M.linen, 0.025, 0.025, 0.16, at(sx * 0.55, 0.68, 0.55), 6)
		pm.sphere(M.candle, 0.025, 0.05, at(sx * 0.55, 0.78, 0.55), 4, 2)
	pm.cyl(M.plank, 0.12, 0.1, 0.05, at(-0.3, 0.86, -0.0 + 0.32), 8)
	for k in 3:
		pm.sphere(M.linen, 0.06, 0.06, at(-0.3, 0.92 + k * 0.045, 0.32), 6, 2)
	pm.cyl(M.ceramic, 0.04, 0.03, 0.06, at(0.3, 0.88, 0.32), 6)
	fp(Vector3(2.0, 0.5, 1.7), Vector3(0, 0.25, 0))


func _torii() -> void:
	var hw := width * 0.5 + 0.15
	var h := 3.3
	for sx: float in [-1.0, 1.0]:
		pm.cyl(VERMILION, 0.15, 0.17, h, at(sx * hw, h * 0.5, 0), 8)
		pm.cyl(M.iron, 0.2, 0.2, 0.3, at(sx * hw, 0.15, 0), 8)
	pm.box(VERMILION, Vector3(width + 1.0, 0.18, 0.22), at(0, h - 0.6, 0))  # nuki
	pm.box(VERMILION, Vector3(0.2, 0.42, 0.18), at(0, h - 0.3, 0))  # the post between
	pm.box(VERMILION, Vector3(width + 1.6, 0.22, 0.32), at(0, h + 0.02, 0))  # kasagi
	pm.box(M.iron, Vector3(width + 1.9, 0.16, 0.38), at(0, h + 0.2, 0))
	for sx: float in [-1.0, 1.0]:
		pm.box(M.iron, Vector3(0.3, 0.14, 0.38), at(sx * (width * 0.5 + 1.0), h + 0.3, 0, Basis(Vector3.FORWARD, sx * -0.3)))


func _jizo() -> void:
	var n := 3
	for i in n:
		var x := -width * 0.5 + (i + 0.5) * width / n
		pm.box(M.stone, Vector3(0.36, 0.12, 0.3), at(x, 0.06, 0))
		pm.cyl(M.moss if i == 1 else M.stone, 0.12, 0.15, 0.4, at(x, 0.32, 0), 7)
		pm.sphere(M.stone, 0.1, 0.19, at(x, 0.6, 0), 7, 3)
		pm.cyl(M.red, 0.04, 0.17, 0.16, at(x, 0.44, 0.02), 7)  # the bib
		pm.cyl(M.red, 0.1, 0.11, 0.05, at(x, 0.69, 0), 7)  # the cap
		pm.cyl(M.ceramic, 0.04, 0.03, 0.05, at(x, 0.035, 0.2), 6)
		pm.box(M.ochre if i % 2 else M.blossom, Vector3(0.06, 0.12, 0.04), at(x + 0.12, 0.18, 0.12))
