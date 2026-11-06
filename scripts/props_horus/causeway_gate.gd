@tool
extends "res://scripts/props_horus/horus_prop.gd"
## A stone causeway across Temek's lake, Length metres along local Z, with a gatehouse in the
## middle: two stepped pylons, a lintel and cornice over them, carved blocks on their faces,
## and a torch on each pylon's inner face (the child OmniLights `TorchL` and `TorchR`, flames in
## the child mesh `Flames`; both flicker while the game runs when Lit). The passage between the
## pylons is 4 m wide, the deck flat at the origin's height: no steps anywhere.

@export var length := 36.0:
	set(value):
		length = value
		_rebuild()
@export var width := 10.0:
	set(value):
		width = value
		_rebuild()
@export var lit := true:
	set(value):
		lit = value
		_rebuild()

const GAP := 2.0  # half the passage width
var _flames := MeshInstance3D.new()
var _time := 0.0


func _init() -> void:
	super()
	_flames.name = "Flames"
	add_child(_flames)


func _build() -> void:
	# The deck and its parapets, with a slab line every 6 m.
	_solid(M.stone, Vector3(width, 1.5, length), _at(0, -0.75, 0))
	for s: float in [-1.0, 1.0]:
		_solid(M.stone_dark, Vector3(0.6, 0.7, length), _at(s * (width * 0.5 - 0.3), 0.35, 0))
	var n := int(length / 6.0)
	for i in n:
		_pm.box(M.stone_dark, Vector3(width - 1.2, 0.03, 0.25), _at(0, 0.01, -length * 0.5 + 6.0 * (i + 0.5)))
	# Piers under the deck, so it reads as standing in the water.
	for i in n + 1:
		var z := -length * 0.5 + length * i / maxf(n, 1)
		for s: float in [-1.0, 1.0]:
			_pm.box(M.stone_dark, Vector3(1.6, 4.0, 1.6), _at(s * (width * 0.5 - 1.2), -3.0, z))
	_pylons()
	_torches()


## The pylons: three tiers each, the inner face kept straight at the passage, the outer
## stepping in; the lintel and cornice over them; carved blocks on the front and back faces.
func _pylons() -> void:
	var tiers := [Vector2(2.8, 3.4), Vector2(2.5, 3.1), Vector2(2.2, 2.8)]
	var tier_h := 3.0
	for s: float in [-1.0, 1.0]:
		for i in tiers.size():
			var t: Vector2 = tiers[i]
			var cx := s * (GAP + t.x * 0.5)
			_solid(M.stone, Vector3(t.x, tier_h, t.y), _at(cx, tier_h * (i + 0.5), 0))
			for f: float in [-1.0, 1.0]:  # fat carved blocks: a row of three per tier, each face
				for j in 3:
					_pm.box(M.hole, Vector3(0.45, 0.8, 0.08), _at(cx + (j - 1) * 0.65, tier_h * (i + 0.5) + 0.3, f * (t.y * 0.5 + 0.03)))
		_pm.box(M.stone_dark, Vector3(2.4, 0.5, 3.2), _at(s * (GAP + 1.2), tier_h * 3 + 0.25, 0))
	var span := (GAP + 2.8) * 2.0
	_solid(M.stone, Vector3(span, 1.6, 3.0), _at(0, tier_h * 3 + 1.3, 0))
	_solid(M.stone_dark, Vector3(span + 0.8, 0.6, 3.8), _at(0, tier_h * 3 + 2.4, 0))
	_pm.box(M.hole, Vector3(GAP * 2.0 - 0.4, 0.9, 0.08), _at(0, tier_h * 3 + 1.3, 1.53))  # the lintel's inscription
	_pm.box(M.hole, Vector3(GAP * 2.0 - 0.4, 0.9, 0.08), _at(0, tier_h * 3 + 1.3, -1.53))
	# Short wing walls off the pylons' outer faces, to the parapets.
	for s: float in [-1.0, 1.0]:
		_solid(M.stone_dark, Vector3(width * 0.5 - GAP - 2.8 + 0.4, 2.0, 1.2), _at(s * (width * 0.5 - (width * 0.5 - GAP - 2.8) * 0.5), 1.0, 0))


## A torch on each pylon's inner face: an iron bracket, a stone bowl, a flame (its own mesh
## so it can flicker) and its light. Dead torches when not Lit.
func _torches() -> void:
	var fm := PropMesh.new()
	for s: float in [-1.0, 1.0]:
		var p := Vector3(s * (GAP - 0.55), 3.6, 0)
		_pm.stick(M.iron_dark, Vector3(s * (GAP + 0.3), 2.9, 0), p + Vector3(0, -0.3, 0), 0.1)
		_pm.cyl(M.stone_dark, 0.45, 0.28, 0.5, _at(p.x, p.y, p.z), 8)
		_pm.cyl(M.hole, 0.38, 0.38, 0.05, _at(p.x, p.y + 0.25, p.z), 8)
		var lname := "TorchL" if s < 0 else "TorchR"
		var old := get_node_or_null(lname)
		if old:
			old.free()
		if lit:
			fm.sphere(M.flame, 0.4, 0.6, _at(p.x, p.y + 0.5, p.z), 6, 3)
			fm.cyl(M.flame, 0.0, 0.34, 1.5, _at(p.x, p.y + 1.3, p.z), 6)
			_light(lname, p + Vector3(-s * 0.4, 1.2, 0), Color(1.0, 0.65, 0.3), 1.6, 12.0)
	_flames.mesh = fm.commit()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not lit:
		return
	_time += delta
	var f := flicker(_time, 3.0 + variant)
	_flames.scale = Vector3(1.0, f, 1.0)
	for pair: Array in [["TorchL", 0.0], ["TorchR", 2.1]]:
		var l := get_node_or_null(pair[0]) as OmniLight3D
		if l:
			l.light_energy = 1.6 * (0.75 + 0.25 * flicker(_time, pair[1]))
