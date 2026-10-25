@tool
extends "res://scripts/props_vacuum_station/station_prop_base.gd"
## Station fixtures, picked from Kind: lamp posts, wall lamps, the dressing round a column, signs,
## departure boards, vents, grates, fallen debris, the dead drone's parts, an invisible Collider
## (a box that only blocks, for visual-only things like the tube shells) and rows of floor Light dots. Origin on the floor
## (or, for wall things, on the wall at the fixture's height), facing +Z.
## Lamp posts and wall lamps: variant 0 = lit panel, 1 = dead panel (use 1 under a separate glowing
## Block when a flicker_light should dim it). Signs: variant = pictogram (0 arrow right, 1 ahead,
## 2-4 tube one/two/three, 5 capsule, 6 hazard, 7 way out). Boards: variant 0 lit row, 1 dead.

const M := {
	metal = preload("res://materials/metal_worn.tres"), dark = preload("res://materials/rubber.tres"),
	hull = preload("res://materials/vacuum_station_hull_worn.tres"), wall = preload("res://materials/vacuum_station_wall_worn.tres"),
	lamp = preload("res://materials/vacuum_station_lamp.tres"), off = preload("res://materials/ceiling_panel_off.tres"),
	guide = preload("res://materials/vacuum_station_guide.tres"), concrete = preload("res://materials/concrete_dark_worn.tres"),
	pipe = preload("res://materials/pipe_round.tres"), vent = preload("res://materials/vacuum_station_vent.tres"),
	grating = preload("res://materials/grating.tres"), board = preload("res://materials/vacuum_station_board.tres"),
	board_dead = preload("res://materials/vacuum_station_board_dead.tres"), red = preload("res://materials/vacuum_station_red.tres"),
	rail = preload("res://materials/trim_rail_worn.tres"), glass = preload("res://materials/vacuum_station_screen_dead.tres"),
	panel = preload("res://materials/precursor_panel.tres"),
}
const SIGNS := ["arrow_right", "ahead", "tube1", "tube2", "tube3", "capsule", "hazard", "exit"]

@export_enum("Lamp post", "Wall lamp", "Column dressing", "Sign post", "Wall sign", "Board", "Wall vent",
		"Floor grate", "Debris", "Drone parts", "Collider", "Light dots", "Clock") var kind := 0:
	set(value):
		kind = value
		_rebuild()
## Signs and boards: the plate's width in metres.
@export var plate_size := 0.6:
	set(value):
		plate_size = value
		_rebuild()
## Collider: the size of the invisible box (it stands on the origin).
@export var box_size := Vector3(1, 1, 1):
	set(value):
		box_size = value
		_rebuild()
## Light dots: how many, `plate_size` metres apart, running along -Z from the origin.
@export var count := 8:
	set(value):
		count = value
		_rebuild()


func _build() -> void:
	match kind:
		0: _lamp_post()
		1: _wall_lamp()
		2: _column()
		3: _sign_post()
		4: _wall_sign()
		5: _board()
		6: _wall_vent()
		7: _grate()
		8: _debris()
		9: _drone()
		10: fp(box_size, Vector3(0, box_size.y * 0.5, 0))  # no mesh: an invisible wall
		11: _dots()
		12: _clock()


func _glow() -> Material:
	return M.lamp if variant % 2 == 0 else M.off


func _sign_mat() -> Material:
	return load("res://materials/vacuum_station_sign_%s.tres" % SIGNS[posmod(variant, SIGNS.size())])


## A 6 m light standard: plinth, post, an arm reaching +Z, a housing with its panel underneath.
func _lamp_post() -> void:
	span(M.concrete, Vector3(-0.3, 0, -0.3), Vector3(0.3, 0.35, 0.3))
	pm.cyl(M.metal, 0.09, 0.11, 5.6, at(0, 0.35 + 2.8, 0), 8, 2)
	span(M.metal, Vector3(-0.07, 5.8, -0.12), Vector3(0.07, 5.92, 1.05))
	span(M.hull, Vector3(-0.3, 5.74, 0.75), Vector3(0.3, 5.86, 1.35))
	span(_glow(), Vector3(-0.24, 5.71, 0.81), Vector3(0.24, 5.74, 1.29))
	fp(Vector3(0.6, 2.4, 0.6), Vector3(0, 1.2, 0))


## A slim upright light bar on a wall, its back plate flush.
func _wall_lamp() -> void:
	span(M.metal, Vector3(-0.12, -0.7, 0), Vector3(0.12, 0.7, 0.05))
	span(_glow(), Vector3(-0.06, -0.6, 0.05), Vector3(0.06, 0.6, 0.11))
	span(M.metal, Vector3(-0.1, 0.6, 0.05), Vector3(0.1, 0.66, 0.14))
	fp(Vector3.ZERO, Vector3.ZERO)


## Round a 2 x 2 m column: a plinth, a light band at 3.2 m (variant 1: dead), a conduit up the
## front face, a kick strip. The column itself stays a plain Block.
func _column() -> void:
	span(M.concrete, Vector3(-1.2, 0, -1.2), Vector3(1.2, 0.9, 1.2))
	span(M.hull, Vector3(-1.22, 0.9, -1.22), Vector3(1.22, 0.98, 1.22))
	span(M.guide if variant % 2 == 0 else M.off, Vector3(-1.04, 3.1, -1.04), Vector3(1.04, 3.26, 1.04))
	span(M.metal, Vector3(-1.06, 3.04, -1.06), Vector3(1.06, 3.1, 1.06))
	span(M.metal, Vector3(-1.06, 3.26, -1.06), Vector3(1.06, 3.32, 1.06))
	pm.cyl(M.pipe, 0.07, 0.07, 9.0, at(0.6, 0.98 + 4.5, 1.09), 8, 3)
	for y in [2.0, 5.0, 8.0]:
		span(M.rail, Vector3(0.5, y, 1.0), Vector3(0.7, y + 0.06, 1.18))
	fp(Vector3(2.4, 0.98, 2.4), Vector3(0, 0.49, 0))


## Flush floor lights in a row (1.2 cm), the way to go: variant 1 = every third one dead.
func _dots() -> void:
	for i in count:
		var dead := variant == 1 and i % 3 == 2
		span(M.off if dead else M.guide, Vector3(-0.13, 0, -i * plate_size - 0.13), Vector3(0.13, 0.012, -i * plate_size + 0.13))
	fp(Vector3.ZERO, Vector3.ZERO)


## A big station clock on a wall (origin on the wall at its centre, `plate_size` = diameter), its
## hands stopped long ago.
func _clock() -> void:
	var r := plate_size * 0.5
	var face_on := Basis(Vector3.RIGHT, PI * 0.5)  # cylinder axis Y -> Z
	pm.cyl(M.metal, r + 0.08, r + 0.08, 0.12, Transform3D(face_on, Vector3(0, 0, 0.06)), 24)
	pm.cyl(M.hull, r, r, 0.04, Transform3D(face_on, Vector3(0, 0, 0.14)), 24)
	for i in 12:
		var a := TAU * i / 12.0
		var d := Vector3(sin(a), cos(a), 0)
		var long := 0.16 if i % 3 == 0 else 0.08
		pm.box(M.dark, Vector3(0.05, r * long * 2.0, 0.02), Transform3D(Basis(Vector3.BACK, -a), d * r * (0.86 - long * 0.5) + Vector3(0, 0, 0.17)))
	for h in [[(4.0 + 52.0 / 60.0) / 12.0, 0.5, 0.07], [52.0 / 60.0, 0.78, 0.05]]:  # stopped at 4:52
		var a: float = TAU * h[0]
		var d := Vector3(sin(a), cos(a), 0)
		pm.box(M.dark, Vector3(h[2], r * h[1], 0.02), Transform3D(Basis(Vector3.BACK, -a), d * r * h[1] * 0.4 + Vector3(0, 0, 0.19)))
	pm.cyl(M.dark, 0.06, 0.06, 0.04, Transform3D(face_on, Vector3(0, 0, 0.2)), 8)
	fp(Vector3.ZERO, Vector3.ZERO)


## A free-standing sign: a post and a pictogram plate at 2.2-2.8 m.
func _sign_post() -> void:
	span(M.concrete, Vector3(-0.15, 0, -0.15), Vector3(0.15, 0.1, 0.15))
	span(M.metal, Vector3(-0.05, 0.1, -0.05), Vector3(0.05, 2.2, 0.05))
	var s := plate_size
	span(M.metal, Vector3(-s * 0.5 - 0.03, 2.17, -0.06), Vector3(s * 0.5 + 0.03, 2.23 + s, -0.04))
	span(M.metal, Vector3(-s * 0.5, 2.2, -0.04), Vector3(s * 0.5, 2.2 + s, 0.0))
	face(_sign_mat(), Vector2(s, s), at(0, 2.2 + s * 0.5, 0.02))
	fp(Vector3(0.3, 2.2, 0.3), Vector3(0, 1.1, 0))


## A pictogram plate on a wall (origin on the wall plane at the plate's centre).
func _wall_sign() -> void:
	var s := plate_size
	span(M.metal, Vector3(-s * 0.5 - 0.04, -s * 0.5 - 0.04, 0), Vector3(s * 0.5 + 0.04, s * 0.5 + 0.04, 0.04))
	face(_sign_mat(), Vector2(s, s), at(0, 0, 0.06))
	fp(Vector3.ZERO, Vector3.ZERO)


## A departure board on a wall or column (origin on the mounting face at the board's centre):
## a housing, the board face, a hood, mounting arms. Its height is half its width.
func _board() -> void:
	var w := plate_size
	var h := w * 0.5
	span(M.metal, Vector3(-w * 0.5 - 0.1, -h * 0.5 - 0.1, 0.2), Vector3(w * 0.5 + 0.1, h * 0.5 + 0.1, 0.38))
	face(M.board if variant % 2 == 0 else M.board_dead, Vector2(w, h), at(0, 0, 0.4))
	span(M.metal, Vector3(-w * 0.5 - 0.12, h * 0.5 + 0.1, 0.18), Vector3(w * 0.5 + 0.12, h * 0.5 + 0.16, 0.58))
	for x in [-w * 0.3, w * 0.3]:
		span(M.metal, Vector3(x - 0.06, -0.06, 0), Vector3(x + 0.06, 0.06, 0.2))
	fp(Vector3.ZERO, Vector3.ZERO)


## A wall grille (origin on the wall at its centre), 0.9 x 0.5 m.
func _wall_vent() -> void:
	span(M.metal, Vector3(-0.5, -0.3, 0), Vector3(0.5, 0.3, 0.04))
	face(M.vent, Vector2(0.9, 0.5), at(0, 0, 0.06))
	fp(Vector3.ZERO, Vector3.ZERO)


## A floor grate, flush (2 cm), with a frame.
func _grate() -> void:
	span(M.metal, Vector3(-0.6, 0, -0.6), Vector3(0.6, 0.015, 0.6))
	span(M.grating, Vector3(-0.5, 0.015, -0.5), Vector3(0.5, 0.02, 0.5))
	fp(Vector3.ZERO, Vector3.ZERO)


## Pieces of a fallen ceiling panel: flat shards and two that landed on edge, all low.
func _debris() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 4100 + variant
	for i in 7:
		var p := Vector3(r.randf_range(-1.6, 1.6), 0, r.randf_range(-1.2, 1.2))
		var s := Vector3(r.randf_range(0.25, 0.8), 0.04, r.randf_range(0.2, 0.6))
		var b := Basis(Vector3.UP, r.randf_range(0, TAU)) * Basis(Vector3.RIGHT, r.randf_range(-0.08, 0.08))
		pm.box(M.panel, s, Transform3D(b, p + Vector3(0, 0.03, 0)))
	pm.box(M.panel, Vector3(0.9, 0.05, 0.5), at(0.6, 0.2, -0.5, Basis(Vector3.UP, 0.7) * Basis(Vector3.FORWARD, 0.45)))
	pm.box(M.metal, Vector3(0.06, 0.06, 1.4), at(-0.7, 0.04, 0.6, Basis(Vector3.UP, 1.1)))  # a bent frame bar
	fp(Vector3.ZERO, Vector3.ZERO)


## The maintenance drone's detail round its 3 x 1.6 x 3 m body Block (origin under the body's
## centre): treads, a sensor head leaning forward (+Z), panel seams, a socket where the arm tore
## off (+X), an antenna bent over. The eye is a separate glowing Block (it pulses, faintly).
func _drone() -> void:
	for x in [-1.72, 1.72]:
		span(M.dark, Vector3(x - 0.24, 0, -1.65), Vector3(x + 0.24, 0.62, 1.65))
		for z in [-1.2, -0.4, 0.4, 1.2]:
			pm.cyl(M.metal, 0.22, 0.22, 0.5, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, 0.3, z)), 8)
	var lean := Basis(Vector3.RIGHT, 0.35)
	pm.box(M.hull, Vector3(1.3, 0.7, 1.1), Transform3D(lean, Vector3(0, 1.95, 0.55)))
	pm.box(M.glass, Vector3(1.0, 0.3, 0.06), Transform3D(lean, Vector3(0, 2.0, 0.55) + lean * Vector3(0, 0, 0.56)))
	pm.stick(M.metal, Vector3(-0.4, 1.6, -0.9), Vector3(-0.4, 2.6, -1.0), 0.05)
	pm.stick(M.metal, Vector3(-0.4, 2.6, -1.0), Vector3(0.3, 2.3, -1.6), 0.04)
	for y in [0.75, 1.25]:
		span(M.dark, Vector3(-1.52, y, -1.52), Vector3(1.52, y + 0.03, 1.52))  # seams
	pm.cyl(M.dark, 0.3, 0.3, 0.12, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(1.55, 0.95, -0.25)), 10)
	pm.stick(M.red, Vector3(1.58, 0.95, -0.25), Vector3(1.9, 0.6, 0.1), 0.03)  # a torn wire
	fp(Vector3.ZERO, Vector3.ZERO)
