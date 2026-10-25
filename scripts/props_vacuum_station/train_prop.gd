@tool
extends "res://scripts/props_vacuum_station/station_prop_base.gd"
## The waystation train's running gear and track, picked from Kind. Origin on the track bed
## (the trench floor), centred between the rails, facing +Z. The rails are 6 m apart (x = -3 and
## +3) and their tops sit 0.22 m up; the car's floor slab starts 0.92 m up, so nothing here
## reaches above 0.9 m except the Signal and the lamps on a Front end.
##   Bogie: a four-wheel truck (two axles, side frames, springs, a bolster) under the car.
##   Front end: the car's end gear: a striped buffer beam, a coupler, two side buffers, brake
##     hoses, head and tail lamps and grab rails on the end wall (origin on the end wall's face).
##   Buffer stop: the heavy steel stop at the end of the line.
##   Signal: a mast by the tunnel mouth, its top lamp lit (line clear), the red one dead.
##   Underframe: equipment cases and tanks between the bogies.
##   Door leaf: the car's sliding side door, slid open along the hull (origin at its foot).
##   Sleepers: concrete sleepers every 0.9 m along -Z for `length` metres, with rail chairs.

const M := {
	metal = preload("res://materials/metal_worn.tres"), dark = preload("res://materials/rubber.tres"),
	rust = preload("res://materials/pipe_rust.tres"), hull = preload("res://materials/vacuum_station_hull_worn.tres"),
	concrete = preload("res://materials/concrete_dark_worn.tres"), yellow = preload("res://materials/paint_yellow.tres"),
	amber = preload("res://materials/vacuum_station_amber.tres"), red = preload("res://materials/vacuum_station_red.tres"),
	guide = preload("res://materials/vacuum_station_guide.tres"), glass = preload("res://materials/vacuum_station_glass.tres"),
	off = preload("res://materials/vacuum_station_screen_dead.tres"),
}
const RAIL_X := 3.0
const RAIL_TOP := 0.22

@export_enum("Bogie", "Front end", "Buffer stop", "Signal", "Underframe", "Door leaf", "Sleepers") var kind := 0:
	set(value):
		kind = value
		_rebuild()
## Sleepers: how far the run goes (metres along -Z).
@export var length := 10.0:
	set(value):
		length = value
		_rebuild()


func _build() -> void:
	match kind:
		0: _bogie()
		1: _front_end()
		2: _buffer_stop()
		3: _signal()
		4: _underframe()
		5: _door_leaf()
		6: _sleepers()


## A cylinder lying along X (axles, wheels) or Z (couplers, buffers).
func _cyl_x(mat: Material, r: float, len_x: float, c: Vector3, sides := 10) -> void:
	pm.cyl(mat, r, r, len_x, Transform3D(Basis(Vector3.BACK, PI * 0.5), c), sides)


func _cyl_z(mat: Material, r: float, len_z: float, c: Vector3, sides := 10) -> void:
	pm.cyl(mat, r, r, len_z, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c), sides)


## Two axles 1.8 m apart, wheels standing on the rails, side frames outside the wheels with axle
## boxes and coil springs, a bolster across the middle carrying the car.
func _bogie() -> void:
	var r := 0.34
	var cy := RAIL_TOP + r
	for z in [-0.9, 0.9]:
		_cyl_x(M.metal, 0.07, RAIL_X * 2.0 + 0.2, Vector3(0, cy, z), 8)  # axle
		for s in [-1.0, 1.0]:
			_cyl_x(M.rust, r, 0.12, Vector3(s * RAIL_X, cy, z), 12)  # wheel
			_cyl_x(M.dark, r * 0.55, 0.14, Vector3(s * RAIL_X, cy, z), 8)  # hub
			span(M.metal, Vector3(s * 3.32 - 0.15, cy - 0.15, z - 0.17), Vector3(s * 3.32 + 0.15, cy + 0.15, z + 0.17))  # axle box
			pm.cyl(M.rust, 0.09, 0.09, 0.14, at(s * 3.32, cy + 0.22, z), 8)  # spring
			var shoe: float = z - signf(z) * (r + 0.06)  # on the wheel's inner side
			span(M.dark, Vector3(s * RAIL_X - 0.08, cy - 0.12, shoe - 0.05), Vector3(s * RAIL_X + 0.08, cy + 0.12, shoe + 0.05))  # brake shoe
	for s in [-1.0, 1.0]:
		span(M.metal, Vector3(s * 3.32 - 0.09, cy + 0.29, -1.45), Vector3(s * 3.32 + 0.09, cy + 0.33, 1.45))  # side frame top
		span(M.metal, Vector3(s * 3.32 - 0.07, cy - 0.2, -0.55), Vector3(s * 3.32 + 0.07, cy + 0.29, 0.55))  # frame web
	span(M.metal, Vector3(-3.4, 0.74, -0.25), Vector3(3.4, 0.88, 0.25))  # bolster
	span(M.dark, Vector3(-0.35, 0.74, -0.35), Vector3(0.35, 0.9, 0.35))  # centre pivot
	fp(Vector3.ZERO, Vector3.ZERO)


## The car's end gear, origin on the end wall's outer face (z = 0) at track level.
func _front_end() -> void:
	span(M.metal, Vector3(-4.95, 0.42, 0), Vector3(4.95, 0.92, 0.22))  # buffer beam
	for i in 16:  # warning chevrons as alternate yellow and black panels on its face
		var x0 := -4.8 + i * 0.6
		span(M.yellow if i % 2 == 0 else M.dark, Vector3(x0, 0.47, 0.22), Vector3(x0 + 0.6, 0.87, 0.24))
	_cyl_z(M.metal, 0.11, 0.9, Vector3(0, 0.66, 0.67), 8)  # coupler shank
	span(M.rust, Vector3(-0.3, 0.5, 1.1), Vector3(0.3, 0.82, 1.38))  # knuckle head
	span(M.rust, Vector3(0.12, 0.5, 1.38), Vector3(0.3, 0.82, 1.5))  # knuckle
	for s in [-1.0, 1.0]:
		_cyl_z(M.metal, 0.15, 0.42, Vector3(s * 3.7, 0.68, 0.43), 8)  # side buffer housing
		_cyl_z(M.rust, 0.27, 0.07, Vector3(s * 3.7, 0.68, 0.68), 10)  # pad
		# Brake hoses: down from the beam, sagging, the end hooked up on the beam.
		pm.stick(M.dark, Vector3(s * 1.1, 0.5, 0.26), Vector3(s * 1.15, 0.28, 0.4), 0.07)
		pm.stick(M.dark, Vector3(s * 1.15, 0.28, 0.4), Vector3(s * 1.4, 0.45, 0.32), 0.07)
		# Head lamps (the left one still glows), tail lamps, grab rails up the corners.
		span(M.metal, Vector3(s * 3.6 - 0.3, 1.55, 0), Vector3(s * 3.6 + 0.3, 1.95, 0.14))
		span(M.amber if s < 0.0 else M.glass, Vector3(s * 3.6 - 0.22, 1.61, 0.14), Vector3(s * 3.6 + 0.22, 1.89, 0.17))
		span(M.metal, Vector3(s * 4.45 - 0.13, 1.6, 0), Vector3(s * 4.45 + 0.13, 1.9, 0.1))
		span(M.red if s > 0.0 else M.off, Vector3(s * 4.45 - 0.09, 1.65, 0.1), Vector3(s * 4.45 + 0.09, 1.85, 0.12))
		pm.stick(M.metal, Vector3(s * 4.78, 2.3, 0.14), Vector3(s * 4.78, 3.8, 0.14), 0.05)
		for y in [2.3, 3.8]:
			pm.stick(M.metal, Vector3(s * 4.78, y, 0.0), Vector3(s * 4.78, y, 0.14), 0.04)
	fp(Vector3(9.9, 0.92, 1.5), Vector3(0, 0.46, 0.75))


## The end of the line: rails' end sills, raking struts up to a striped beam with two buffers
## facing +Z (toward the car), a red lamp on top.
func _buffer_stop() -> void:
	for s in [-1.0, 1.0]:
		span(M.metal, Vector3(s * RAIL_X - 0.14, RAIL_TOP, -2.6), Vector3(s * RAIL_X + 0.14, RAIL_TOP + 0.24, -0.1))  # sill on the rail
		pm.stick(M.metal, Vector3(s * RAIL_X, RAIL_TOP + 0.2, -2.4), Vector3(s * RAIL_X, 0.92, -0.3), 0.2)  # raking strut
		span(M.metal, Vector3(s * RAIL_X - 0.12, RAIL_TOP, -0.45), Vector3(s * RAIL_X + 0.12, 1.08, -0.2))  # upright
		_cyl_z(M.metal, 0.16, 0.36, Vector3(s * 3.7, 0.72, 0.18), 8)  # buffer housing
		_cyl_z(M.rust, 0.28, 0.07, Vector3(s * 3.7, 0.72, 0.39), 10)  # pad
	span(M.metal, Vector3(-4.1, 0.48, -0.2), Vector3(4.1, 1.0, 0.0))  # beam
	for i in 13:
		var x0 := -3.9 + i * 0.6
		span(M.yellow if i % 2 == 0 else M.dark, Vector3(x0, 0.52, 0.0), Vector3(minf(x0 + 0.6, 3.9), 0.96, 0.02))
	span(M.metal, Vector3(-0.2, 1.0, -0.2), Vector3(0.2, 1.25, 0.0))
	span(M.red, Vector3(-0.15, 1.04, 0.0), Vector3(0.15, 1.21, 0.03))  # the stop lamp
	fp(Vector3(8.4, 1.25, 3.1), Vector3(0, 0.62, -1.15))


## A signal mast: plinth, pole, a head with two hooded lamps, the upper one lit.
func _signal() -> void:
	span(M.concrete, Vector3(-0.3, 0, -0.3), Vector3(0.3, 0.3, 0.3))
	pm.cyl(M.metal, 0.07, 0.08, 3.6, at(0, 2.1, 0), 8)
	span(M.dark, Vector3(-0.28, 3.6, -0.12), Vector3(0.28, 4.7, 0.16))  # head
	for l in [[4.38, M.guide], [3.92, M.off]]:
		span(l[1], Vector3(-0.13, l[0] - 0.13, 0.16), Vector3(0.13, l[0] + 0.13, 0.18))
		span(M.dark, Vector3(-0.17, l[0] + 0.13, 0.16), Vector3(0.17, l[0] + 0.17, 0.42))  # hood
	pm.stick(M.metal, Vector3(0, 0.3, -0.06), Vector3(0, 3.6, -0.06), 0.03)  # cable up the pole
	fp(Vector3(0.6, 2.2, 0.6), Vector3(0, 1.1, 0))


## Equipment slung under the car between the bogies: cases, a pair of tanks, cable trays.
func _underframe() -> void:
	span(M.dark, Vector3(-2.6, 0.82, -4.0), Vector3(2.6, 0.92, 4.0))  # floor stiffeners
	span(M.metal, Vector3(-2.4, 0.42, -3.6), Vector3(-0.6, 0.82, -1.2))
	span(M.metal, Vector3(0.6, 0.48, -3.2), Vector3(2.5, 0.82, -0.6))
	span(M.rust, Vector3(-2.2, 0.5, 0.4), Vector3(-0.9, 0.82, 3.4))
	_cyl_z(M.rust, 0.26, 3.0, Vector3(1.6, 0.56, 1.9), 10)  # tanks
	_cyl_z(M.rust, 0.22, 2.6, Vector3(0.9, 0.6, 1.9), 10)
	span(M.dark, Vector3(-0.15, 0.7, -4.0), Vector3(0.15, 0.82, 4.0))  # cable tray
	fp(Vector3.ZERO, Vector3.ZERO)


## The side door's leaf: hull-coloured, a tall window, a rubber edge, a recessed handle.
func _door_leaf() -> void:
	span(M.hull, Vector3(-0.8, 0, 0), Vector3(0.8, 2.6, 0.08))
	span(M.glass, Vector3(-0.35, 1.3, 0.08), Vector3(0.35, 2.3, 0.09))
	span(M.dark, Vector3(-0.84, 0, 0), Vector3(-0.8, 2.6, 0.1))
	span(M.metal, Vector3(0.55, 1.0, 0.08), Vector3(0.65, 1.4, 0.12))
	fp(Vector3.ZERO, Vector3.ZERO)


## Concrete sleepers every 0.9 m along -Z, each with two dark rail chairs.
func _sleepers() -> void:
	var n := maxi(1, int(length / 0.9))
	for i in n:
		var z := -0.45 - i * 0.9
		span(M.concrete, Vector3(-3.7, 0, z - 0.14), Vector3(3.7, 0.08, z + 0.14))
		for s in [-1.0, 1.0]:
			span(M.dark, Vector3(s * RAIL_X - 0.16, 0.08, z - 0.1), Vector3(s * RAIL_X + 0.16, 0.1, z + 0.1))
	fp(Vector3.ZERO, Vector3.ZERO)
