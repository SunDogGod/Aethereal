@tool
extends "res://scripts/props_massacre/village_prop_base.gd"
## What turns an estate's plain house Block into a village house: a dark stone footing, timber
## posts and a beam band on the plaster, a gable roof of round terracotta tiles (roof_kit.gd), a
## raised plank veranda (engawa) along the front under a lean-to eave, lattice paper windows and
## a sliding door left a hand open with warm light behind it, a noren curtain, red paper lanterns
## on the veranda posts, small barred windows on the other walls.
## Origin = the house Block's centre at floor level; House size = that Block's size; the front (the
## courtyard side) faces +Z. Solid: the veranda deck (0.4 m, not a step you can climb).
## Great: the Great Estate's hall, with a gabled entrance porch over the door.

const Roof := preload("res://scripts/props_massacre/roof_kit.gd")
const DECK_H := 0.4
const DECK_D := 1.5

@export var house_size := Vector3(14, 3.8, 6.4):
	set(value):
		house_size = value
		_rebuild()
@export var great := false:
	set(value):
		great = value
		_rebuild()
## Metres of veranda left off at its left (-X) or right (+X) end, to keep a gate beside the house clear.
@export var trim_left := 0.0:
	set(value):
		trim_left = value
		_rebuild()
@export var trim_right := 0.0:
	set(value):
		trim_right = value
		_rebuild()


func _build() -> void:
	var w := house_size.x
	var h := house_size.y
	var d := house_size.z
	var fz := d * 0.5
	var mats := {roof = M.clay, ridge = M.ridge, timber = M.timber, gable = M.plaster}
	# The footing, the posts and the beam band, each a little proud of the plaster.
	for sz: float in [-1.0, 1.0]:
		pm.box(M.stone, Vector3(w + 0.16, 0.45, 0.14), at(0, 0.225, sz * (fz + 0.04)))
		pm.box(M.timber, Vector3(w + 0.2, 0.22, 0.16), at(0, h - 0.13, sz * (fz + 0.05)))
	for sx: float in [-1.0, 1.0]:
		pm.box(M.stone, Vector3(0.14, 0.45, d + 0.16), at(sx * (w * 0.5 + 0.04), 0.225, 0))
		pm.box(M.timber, Vector3(0.16, 0.22, d + 0.2), at(sx * (w * 0.5 + 0.05), h - 0.13, 0))
		for sz: float in [-1.0, 1.0]:
			pm.box(M.timber, Vector3(0.3, h, 0.3), at(sx * (w * 0.5 - 0.05), h * 0.5, sz * (fz - 0.05)))
	pm.box(M.timber, Vector3(w + 0.1, 0.12, 0.1), at(0, 0.98 if not great else 1.2, -fz - 0.03))  # a rail across the back
	var bays := maxi(3, int(round(w / 3.0)))
	if bays % 2 == 0:
		bays += 1  # odd, so the door sits in the middle bay, not on a post
	for i in range(1, bays):
		var x := -w * 0.5 + i * w / bays
		for sz: float in [-1.0, 1.0]:
			pm.box(M.timber, Vector3(0.2, h - 0.3, 0.12), at(x, (h - 0.3) * 0.5 + 0.1, sz * (fz + 0.04)))
	_front(w, h, fz, bays)
	_back(w, h, fz, bays)
	# The roof: the front slope reaches over the veranda.
	var ridge_y := Roof.gable(pm, mats, Transform3D(), w, d, h, 26.0 if not great else 30.0, Vector2(DECK_D + 0.5, 0.9), 0.6)
	if great:
		_porch(h, fz, mats)
	_veranda(w, h, fz, bays)
	set_meta("ridge_y", ridge_y)


## The courtyard front: lattice windows in the bays, the door in the middle bay.
func _front(w: float, h: float, fz: float, bays: int) -> void:
	var z := fz + 0.03
	var door_w := 1.8 if not great else 2.6
	var door_h := 2.2 if not great else 2.8
	var y0 := DECK_H
	# The door: two paper-and-timber leaves, one slid aside; warm light in the gap.
	pm.box(M.timber, Vector3(door_w + 0.3, door_h + 0.2, 0.08), at(0, y0 + (door_h + 0.2) * 0.5, z))
	pm.box(M.lit, Vector3(door_w * 0.35, door_h - 0.1, 0.06), at(-door_w * 0.25, y0 + door_h * 0.5, z + 0.03))
	for lx: float in [door_w * 0.05, door_w * 0.3]:
		pm.box(M.paper, Vector3(door_w * 0.45, door_h - 0.25, 0.04), at(lx, y0 + door_h * 0.5, z + 0.07 + lx * 0.02))
		_lattice(Vector3(lx, y0 + door_h * 0.5, z + 0.1 + lx * 0.02), Vector2(door_w * 0.45, door_h - 0.25), 4, 6)
	# The noren over the door: three indigo panels with a dark rod.
	pm.box(M.timber, Vector3(door_w + 0.2, 0.05, 0.05), at(0, y0 + door_h + 0.02, z + 0.2))
	var cloth: Material = M.indigo if variant % 2 == 0 else M.red
	for i in 3:
		pm.box(cloth, Vector3(door_w / 3.0 - 0.05, 0.75, 0.025), at((i - 1) * door_w / 3.0, y0 + door_h - 0.37, z + 0.22))
	# Windows: one per bay that isn't the door's.
	for i in bays:
		var cx := -w * 0.5 + (i + 0.5) * w / bays
		if absf(cx) < door_w * 0.5 + 0.9:
			continue
		var ww := minf(w / bays - 1.0, 1.8)
		var wy := y0 + 1.15 if not great else y0 + 1.5
		pm.box(M.timber, Vector3(ww + 0.22, 1.15, 0.07), at(cx, wy, z))
		pm.box(M.paper, Vector3(ww, 0.95, 0.05), at(cx, wy, z + 0.03))
		_lattice(Vector3(cx, wy, z + 0.06), Vector2(ww, 0.95), int(ww / 0.3), 3)


## The back and the gable ends: small windows with iron bars, a vent under each gable.
func _back(w: float, h: float, fz: float, bays: int) -> void:
	for i in bays:
		if i % 2 == 1:
			continue
		var cx := -w * 0.5 + (i + 0.5) * w / bays
		var z := -fz - 0.03
		pm.box(M.timber, Vector3(0.9, 0.7, 0.07), at(cx, 1.9, z))
		pm.box(M.dark, Vector3(0.7, 0.5, 0.05), at(cx, 1.9, z - 0.02))
		for k in 4:
			pm.box(M.iron, Vector3(0.03, 0.62, 0.03), at(cx - 0.27 + k * 0.18, 1.9, z - 0.08))
		pm.box(M.stone, Vector3(1.0, 0.07, 0.16), at(cx, 1.53, z - 0.05))
	for sx: float in [-1.0, 1.0]:
		var x := sx * (w * 0.5 + 0.03)
		pm.box(M.timber, Vector3(0.07, 0.6, 0.9), at(x, h + 0.5, 0))
		for k in 4:
			pm.box(M.timber, Vector3(0.04, 0.5, 0.05), at(x + sx * 0.03, h + 0.5, -0.3 + k * 0.2))


## A grid of thin timber bars over a paper panel (size), centred at c, facing +Z.
func _lattice(c: Vector3, s: Vector2, cols: int, rows: int) -> void:
	for i in range(1, cols):
		pm.box(M.timber, Vector3(0.03, s.y, 0.03), at(c.x - s.x * 0.5 + i * s.x / cols, c.y, c.z))
	for j in range(1, rows):
		pm.box(M.timber, Vector3(s.x, 0.03, 0.03), at(c.x, c.y - s.y * 0.5 + j * s.y / rows, c.z))


## The veranda: a plank deck on stone feet, posts at its edge, red paper lanterns hung from the eave.
func _veranda(w: float, h: float, fz: float, bays: int) -> void:
	var z0 := fz + 0.02
	var z1 := fz + DECK_D
	var xa := -w * 0.5 - 0.25 + trim_left
	var xb := w * 0.5 + 0.25 - trim_right
	var mid := (xa + xb) * 0.5
	pm.box(M.plank, Vector3(xb - xa, 0.1, z1 - z0), at(mid, DECK_H - 0.05, (z0 + z1) * 0.5))
	pm.box(M.timber, Vector3(xb - xa, DECK_H - 0.1, 0.12), at(mid, (DECK_H - 0.1) * 0.5, z1 - 0.08))
	if trim_left > 0.0:
		pm.box(M.timber, Vector3(0.12, DECK_H - 0.1, z1 - z0), at(xa + 0.06, (DECK_H - 0.1) * 0.5, (z0 + z1) * 0.5))
	if trim_right > 0.0:
		pm.box(M.timber, Vector3(0.12, DECK_H - 0.1, z1 - z0), at(xb - 0.06, (DECK_H - 0.1) * 0.5, (z0 + z1) * 0.5))
	for i in int((xb - xa) / 0.25):
		pm.box(M.timber, Vector3(0.02, 0.012, z1 - z0 - 0.04), at(xa + i * 0.25 + 0.15, DECK_H + 0.003, (z0 + z1) * 0.5))
	# A step stone in front of the door (kutsunugi), shoes on it.
	pm.box(M.stone, Vector3(1.2, 0.22, 0.6), at(0, 0.11, z1 + 0.35))
	for k in 2:
		pm.box(M.dark if k == 0 else M.timber, Vector3(0.1, 0.05, 0.24), at(-0.25 + k * 0.2, 0.245, z1 + 0.32))
	var pitch := deg_to_rad(26.0 if not great else 30.0)
	var eave_y := h - DECK_D * tan(pitch) - 0.14  # under the roof's front slope
	var posts: Array[float] = []
	for i in bays + 1:
		var x := -w * 0.5 - 0.1 + i * (w + 0.2) / bays
		if x > xa + 0.3 and x < xb - 0.3:
			posts.append(x)
	posts.push_front(xa + 0.12)
	posts.append(xb - 0.12)
	for i in posts.size():
		var x: float = posts[i]
		pm.box(M.timber, Vector3(0.18, eave_y - DECK_H, 0.18), at(x, (eave_y + DECK_H) * 0.5, z1 - 0.12))
		if i > 0 and i < posts.size() - 1 and (i + variant) % 2 == 0:
			pm.box(M.timber, Vector3(0.02, 0.35, 0.02), at(x, eave_y - 0.35, z1 + 0.05))
			pm.cyl(M.red_paper, 0.17, 0.17, 0.42, at(x, eave_y - 0.75, z1 + 0.05), 8)
			pm.cyl(M.timber, 0.12, 0.12, 0.06, at(x, eave_y - 0.5, z1 + 0.05), 8)
			pm.cyl(M.timber, 0.12, 0.12, 0.06, at(x, eave_y - 1.0, z1 + 0.05), 8)
	pm.box(M.timber, Vector3(xb - xa, 0.18, 0.2), at(mid, eave_y, z1 - 0.12))
	fp(Vector3(xb - xa, DECK_H, DECK_D), Vector3(mid, DECK_H * 0.5, fz + DECK_D * 0.5))


## The Great Estate's entrance porch: a gable roof at right angles to the hall's, on four posts.
func _porch(h: float, fz: float, mats: Dictionary) -> void:
	var pw := 4.6
	var pd := DECK_D + 1.6
	var top := h - 0.9
	for sx: float in [-1.0, 1.0]:
		pm.box(M.timber, Vector3(0.26, top - DECK_H, 0.26), at(sx * pw * 0.5, (top + DECK_H) * 0.5, fz + 0.4))
		pm.box(M.timber, Vector3(0.26, top, 0.26), at(sx * pw * 0.5, top * 0.5, fz + pd))
		pm.box(M.stone, Vector3(0.4, 0.2, 0.4), at(sx * pw * 0.5, 0.1, fz + pd))
	pm.box(M.timber, Vector3(pw + 0.4, 0.26, 0.3), at(0, top - 0.1, fz + pd))
	var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, fz + pd * 0.5 + 0.3))
	Roof.gable(pm, {roof = M.clay, ridge = M.ridge, timber = M.timber, gable = M.timber}, xf, pd + 0.6, pw, top, 34.0,
			Vector2(0.6, 0.6), 0.4)
	# A plaque under the porch gable (no writing: the memory doesn't keep it).
	pm.box(M.timber, Vector3(1.4, 0.6, 0.06), at(0, top + 0.55, fz + pd + 0.62))
	pm.box(M.brass, Vector3(1.2, 0.44, 0.04), at(0, top + 0.55, fz + pd + 0.66))
