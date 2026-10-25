@tool
extends "res://scripts/props_vacuum_station/station_prop_base.gd"
## Station furniture, picked from Kind: consoles, ticket gates, benches, barriers, bollards,
## crates, a maintenance cart, a cable spool, lockers. Origin on the floor, facing +Z (a wall,
## if any, is behind at -Z). Screens are separate thin Blocks (console_screen.gd) placed on the
## front: a Desk console's screen centre is (0, 1.22, -0.25), a Kiosk's (0, 1.35, 0.2).

const M := {
	metal = preload("res://materials/metal_worn.tres"), dark = preload("res://materials/rubber.tres"),
	hull = preload("res://materials/vacuum_station_hull_worn.tres"), wall = preload("res://materials/vacuum_station_wall_worn.tres"),
	glass = preload("res://materials/vacuum_station_screen_dead.tres"), red = preload("res://materials/vacuum_station_red.tres"),
	guide = preload("res://materials/vacuum_station_guide.tres"), stripes = preload("res://materials/trim_stripes_worn.tres"),
	rail = preload("res://materials/trim_rail_worn.tres"), teal = preload("res://materials/paint_teal.tres"),
	yellow = preload("res://materials/paint_yellow.tres"), wood = preload("res://materials/wood.tres"),
	off = preload("res://materials/ceiling_panel_off.tres"), vent = preload("res://materials/vacuum_station_vent.tres"),
}

@export_enum("Desk console", "Kiosk", "Ticket gate", "Bench", "Barrier", "Bollard", "Crate", "Cart",
		"Cable spool", "Locker bank") var kind := 0:
	set(value):
		kind = value
		_rebuild()


func _build() -> void:
	match kind:
		0: _desk()
		1: _kiosk()
		2: _gate()
		3: _bench()
		4: _barrier()
		5: _bollard()
		6: _crate()
		7: _cart()
		8: _spool()
		9: _lockers()


## A low operator's desk with an upright screen panel at the back and a slanted key deck.
func _desk() -> void:
	span(M.metal, Vector3(-0.8, 0, -0.35), Vector3(0.8, 0.82, 0.3))
	span(M.dark, Vector3(-0.82, 0, 0.18), Vector3(0.82, 0.08, 0.32))  # kick plinth
	span(M.hull, Vector3(-0.84, 0.82, -0.37), Vector3(0.84, 0.88, 0.34))  # top
	pm.box(M.dark, Vector3(1.2, 0.04, 0.3), at(0, 0.92, 0.1, Basis(Vector3.RIGHT, 0.25)))  # key deck
	span(M.metal, Vector3(-0.8, 0.88, -0.35), Vector3(0.8, 1.62, -0.27))  # screen panel
	span(M.hull, Vector3(-0.82, 1.62, -0.37), Vector3(0.82, 1.68, -0.25))
	pm.box(M.red if variant % 2 == 0 else M.off, Vector3(0.05, 0.03, 0.03), at(0.62, 0.93, 0.2))
	fp(Vector3(1.68, 1.68, 0.71), Vector3(0, 0.84, -0.015))


## An upright information pillar with a screen on its front and a slim hood over it.
func _kiosk() -> void:
	span(M.dark, Vector3(-0.38, 0, -0.22), Vector3(0.38, 0.12, 0.22))
	span(M.hull, Vector3(-0.34, 0.12, -0.19), Vector3(0.34, 1.95, 0.19))
	span(M.metal, Vector3(-0.36, 1.95, -0.21), Vector3(0.36, 2.05, 0.21))
	span(M.metal, Vector3(-0.33, 1.68, 0.19), Vector3(0.33, 1.74, 0.3))  # hood
	span(M.metal, Vector3(-0.3, 0.98, 0.19), Vector3(0.3, 1.02, 0.25))  # sill
	face(M.vent, Vector2(0.44, 0.3), at(0, 0.45, 0.21))
	fp(Vector3(0.76, 2.05, 0.44), Vector3(0, 1.025, 0))


## A ticket gate cabinet, long along Z (people walked past it along Z). Its paddles are folded
## away; a status lamp and a reader plate on top.
func _gate() -> void:
	span(M.hull, Vector3(-0.15, 0.08, -0.8), Vector3(0.15, 1.0, 0.8))
	span(M.dark, Vector3(-0.16, 0, -0.81), Vector3(0.16, 0.08, 0.81))
	span(M.metal, Vector3(-0.17, 1.0, -0.82), Vector3(0.17, 1.05, 0.82))
	span(M.glass, Vector3(-0.1, 1.05, 0.25), Vector3(0.1, 1.08, 0.55))  # reader
	for s in [-1.0, 1.0]:
		span(M.dark, Vector3(s * 0.15, 0.55, -0.12), Vector3(s * 0.19, 0.85, 0.12))  # paddle stubs
	var lamp: Material = M.red if variant % 3 == 1 else M.off
	span(lamp, Vector3(-0.06, 1.05, 0.62), Vector3(0.06, 1.1, 0.74))
	span(M.stripes, Vector3(-0.155, 0.1, 0.795), Vector3(0.155, 0.4, 0.82))
	fp(Vector3(0.34, 1.1, 1.64), Vector3(0, 0.55, 0))


## A waiting bench: one long slab on two plinths, a low back.
func _bench() -> void:
	for x in [-0.85, 0.85]:
		span(M.metal, Vector3(x - 0.15, 0, -0.2), Vector3(x + 0.15, 0.42, 0.2))
	span(M.hull, Vector3(-1.1, 0.42, -0.25), Vector3(1.1, 0.5, 0.25))
	span(M.hull, Vector3(-1.1, 0.5, -0.25), Vector3(1.1, 0.92, -0.19))
	span(M.metal, Vector3(-1.12, 0.92, -0.27), Vector3(1.12, 0.96, -0.17))
	fp(Vector3(2.24, 0.96, 0.52), Vector3(0, 0.48, -0.01))


## A 4 m safety barrier along X: posts on feet, two rails, a striped board.
func _barrier() -> void:
	for x in [-1.9, 0.0, 1.9]:
		span(M.metal, Vector3(x - 0.06, 0, -0.06), Vector3(x + 0.06, 1.1, 0.06))
		span(M.dark, Vector3(x - 0.18, 0, -0.18), Vector3(x + 0.18, 0.04, 0.18))
	span(M.rail, Vector3(-2.0, 1.04, -0.05), Vector3(2.0, 1.12, 0.05))
	span(M.rail, Vector3(-2.0, 0.5, -0.04), Vector3(2.0, 0.56, 0.04))
	span(M.stripes, Vector3(-1.84, 0.66, 0.06), Vector3(1.84, 0.94, 0.09))
	span(M.stripes, Vector3(-1.84, 0.66, -0.09), Vector3(1.84, 0.94, -0.06))
	fp(Vector3(4.0, 1.12, 0.36), Vector3(0, 0.56, 0))


## A short post with a glowing band (variant 1: the band is dead).
func _bollard() -> void:
	pm.cyl(M.metal, 0.12, 0.13, 0.9, at(0, 0.45, 0), 8)
	pm.cyl(M.guide if variant % 2 == 0 else M.off, 0.135, 0.135, 0.08, at(0, 0.74, 0), 8)
	pm.cyl(M.hull, 0.14, 0.12, 0.06, at(0, 0.93, 0), 8)
	fp(Vector3(0.28, 0.96, 0.28), Vector3(0, 0.48, 0))


## A ribbed cargo container; variant 2 stacks a smaller one on top.
func _crate() -> void:
	var paint: Material = [M.metal, M.teal, M.hull][posmod(variant, 3)]
	span(paint, Vector3(-0.6, 0, -0.45), Vector3(0.6, 0.95, 0.45))
	for x in [-0.45, 0.0, 0.45]:
		span(M.metal, Vector3(x - 0.04, 0.05, 0.45), Vector3(x + 0.04, 0.9, 0.48))
	span(M.dark, Vector3(-0.62, 0, -0.47), Vector3(0.62, 0.06, 0.47))
	var h := 0.95
	if posmod(variant, 3) == 2:
		pm.box(M.teal, Vector3(0.8, 0.6, 0.7), at(0.1, 1.25, 0.0, Basis(Vector3.UP, 0.25)))
		h = 1.55
	fp(Vector3(1.24, h, 0.94), Vector3(0, h * 0.5, 0))


## A maintenance cart: a deck on small wheels, a handle, a toolbox and a coiled hose.
func _cart() -> void:
	span(M.yellow, Vector3(-0.7, 0.38, -0.35), Vector3(0.7, 0.46, 0.35))
	for x in [-0.55, 0.55]:
		for z in [-0.28, 0.28]:
			pm.cyl(M.dark, 0.1, 0.1, 0.06, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.1, z)), 8)
			pm.stick(M.metal, Vector3(x, 0.12, z), Vector3(x, 0.4, z), 0.04)
	pm.stick(M.metal, Vector3(-0.7, 0.46, -0.3), Vector3(-0.75, 1.0, -0.3), 0.04)
	pm.stick(M.metal, Vector3(-0.7, 0.46, 0.3), Vector3(-0.75, 1.0, 0.3), 0.04)
	pm.stick(M.metal, Vector3(-0.75, 1.0, -0.32), Vector3(-0.75, 1.0, 0.32), 0.04)
	span(M.red, Vector3(-0.2, 0.46, -0.2), Vector3(0.35, 0.68, 0.12))
	pm.ring(M.dark, 0.14, 0.24, at(0.45, 0.5, 0.15), 10, 4)
	fp(Vector3(1.5, 1.02, 0.74), Vector3(-0.03, 0.51, 0))


## A cable spool on its side (axis along X), cable wound on it.
func _spool() -> void:
	var side := Basis(Vector3.FORWARD, PI * 0.5)
	for x in [-0.35, 0.35]:
		pm.cyl(M.wood, 0.5, 0.5, 0.06, Transform3D(side, Vector3(x, 0.5, 0)), 12)
	pm.cyl(M.dark, 0.38, 0.38, 0.64, Transform3D(side, Vector3(0, 0.5, 0)), 12)
	pm.stick(M.dark, Vector3(0.1, 0.12, 0.36), Vector3(0.9, 0.03, 0.9), 0.05)  # the free end
	fp(Vector3(0.8, 1.0, 1.0), Vector3(0, 0.5, 0))


## Three lockers against a wall, one door left ajar.
func _lockers() -> void:
	span(M.metal, Vector3(-0.9, 0.05, -0.25), Vector3(0.9, 1.9, 0.25))
	span(M.dark, Vector3(-0.9, 0, -0.25), Vector3(0.9, 0.05, 0.22))
	for i in 3:
		var x := -0.6 + i * 0.6
		span(M.dark, Vector3(x + 0.28, 0.08, 0.25), Vector3(x + 0.3, 1.86, 0.27))  # gap between doors
		face(M.vent, Vector2(0.4, 0.2), at(x, 1.65, 0.27))
		span(M.rail, Vector3(x + 0.2, 0.95, 0.25), Vector3(x + 0.23, 1.15, 0.29))
	span(M.dark, Vector3(0.32, 0.1, 0.25), Vector3(0.88, 1.84, 0.27))  # the dark inside of the open one
	pm.box(M.metal, Vector3(0.56, 1.76, 0.03), Transform3D(Basis(Vector3.UP, 0.6), Vector3(0.67, 0.97, 0.43)))
	fp(Vector3(1.8, 1.9, 0.5), Vector3(0, 0.95, 0))
