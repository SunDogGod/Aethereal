@tool
extends "res://scripts/props_horus/horus_prop.gd"
## The farmer's shack, half dug into a dune: corrugated iron plates on a timber frame, a shed
## roof weighed down with stones, the back and sides heaped over with sand. The door (facing
## +Z, 1.2 m wide, 2.2 m tall, a timber frame, no door in it) is reached down a ramp of sand:
## the floor is the origin, the dune outside stands Apron Rise higher, so sink the node that
## much into the dune. Inside: a bed (the child Marker3D `BedMark` is where Aeneas lies down),
## a table, a hatch in the floor to the underground garden (closed: a dark square and its lid),
## a lamp hanging from the roof (the child OmniLight `Lamp`). Walkable inside, no steps.

## The inside, wall to wall (x, z).
@export var inner := Vector2(6.0, 5.0):
	set(value):
		inner = value
		_rebuild()
## How much higher than the floor the sand outside the door is: the ramp climbs this.
@export var apron_rise := 0.5:
	set(value):
		apron_rise = value
		_rebuild()

var _bed_mark := Marker3D.new()
const WALL := 0.15
const H := 2.5  # the ceiling


func _init() -> void:
	super()
	_bed_mark.name = "BedMark"
	add_child(_bed_mark)


func _build() -> void:
	var w := inner.x
	var d := inner.y
	var door_x := 1.0
	_solid(M.stone_dark, Vector3(w + 0.6, 0.3, d + 0.6), _at(0, -0.15, 0))  # the floor slab
	_walls(w, d, door_x)
	_roof(w, d)
	_heaps(w, d)
	_apron(door_x, d)
	_inside(w, d)
	_light("Lamp", Vector3(0.3, 1.9, 0.2), Color(1.0, 0.8, 0.55), 1.1, 7.0)


## The walls: plates with vertical corrugation ribs outside, the front one split round the door.
func _walls(w: float, d: float, door_x: float) -> void:
	var hx := w * 0.5 + WALL * 0.5
	var hz := d * 0.5 + WALL * 0.5
	_solid(M.iron, Vector3(w + WALL * 2.0, H, WALL), _at(0, H * 0.5, -hz))
	for s: float in [-1.0, 1.0]:
		_solid(M.iron, Vector3(WALL, H, d), _at(s * hx, H * 0.5, 0))
	# The front: left of the door, right of it, and over it.
	var l0 := -hx - WALL * 0.5
	var l1 := door_x - 0.75
	var r0 := door_x + 0.75
	var r1 := hx + WALL * 0.5
	_solid(M.iron, Vector3(l1 - l0, H, WALL), _at((l0 + l1) * 0.5, H * 0.5, hz))
	_solid(M.iron, Vector3(r1 - r0, H, WALL), _at((r0 + r1) * 0.5, H * 0.5, hz))
	_solid(M.iron, Vector3(1.5, H - 2.3, WALL), _at(door_x, (H + 2.3) * 0.5, hz))
	# The timber door frame: posts and a lintel, their inner faces 1.2 m apart, 2.2 m up.
	for s: float in [-1.0, 1.0]:
		_solid(M.timber, Vector3(0.15, 2.3, 0.3), _at(door_x + s * 0.675, 1.15, hz))
	_solid(M.timber, Vector3(1.5, 0.15, 0.3), _at(door_x, 2.275, hz))
	# Corrugation ribs on the front and the front half of each side (the rest is under sand).
	var x := -w * 0.5 + 0.3
	while x < w * 0.5:
		if absf(x - door_x) > 0.9:
			_pm.box(M.iron_dark, Vector3(0.07, H - 0.2, 0.06), _at(x, H * 0.5, hz + WALL * 0.5 + 0.02))
		x += 0.45
	for s: float in [-1.0, 1.0]:
		var z := d * 0.5 - 0.2
		while z > 0.0:
			_pm.box(M.iron_dark, Vector3(0.06, H - 0.2, 0.07), _at(s * (hx + WALL * 0.5 + 0.02), H * 0.5, z))
			z -= 0.45
	# A small window beside the door, boarded.
	_pm.box(M.hole, Vector3(0.8, 0.6, 0.06), _at(door_x - 2.2, 1.6, hz + WALL * 0.5 + 0.01))
	for k in 2:
		_pm.box(M.timber, Vector3(0.9, 0.12, 0.08), _at(door_x - 2.2, 1.45 + k * 0.3, hz + WALL * 0.5 + 0.05))


## A flat roof (walkable from the dune behind) under a skin of corrugated sheets that slump a
## little toward the back, stones on them, a stove pipe through.
func _roof(w: float, d: float) -> void:
	var over := 0.7
	_solid(M.iron_dark, Vector3(w + 0.8, 0.12, d + over + 0.4), _at(0, H + 0.06, (over - 0.4) * 0.5))
	var tilt := Transform3D(Basis(Vector3.RIGHT, 0.05), Vector3(0, H + 0.25, (over - 0.4) * 0.5))
	_pm.box(M.iron, Vector3(w + 1.0, 0.08, d + over + 0.6), tilt)
	var x := -w * 0.5 - 0.2
	while x < w * 0.5 + 0.3:
		_pm.box(M.iron_dark, Vector3(0.07, 0.07, d + over + 0.5), tilt * _at(x, 0.06, 0))
		x += 0.45
	for k in 5:
		var p := Vector3(_r.randf_range(-w * 0.45, w * 0.45), 0.2, _r.randf_range(-d * 0.4, d * 0.5))
		_ball(M.stone_dark, Vector3(_r.randf_range(0.2, 0.35), 0.16, _r.randf_range(0.2, 0.3)), tilt * Transform3D(Basis(Vector3.UP, _r.randf() * TAU), p), 6, 3)
	_pm.cyl(M.iron_dark, 0.14, 0.14, 1.4, _at(-w * 0.3, H + 0.8, -d * 0.2), 8)
	_pm.cyl(M.iron_dark, 0.24, 0.24, 0.12, _at(-w * 0.3, H + 1.45, -d * 0.2), 8)


## Sand heaped over the back and the sides, up to the roof behind, lower toward the front.
func _heaps(w: float, d: float) -> void:
	var hz := d * 0.5 + WALL
	var hx := w * 0.5 + WALL
	_ball(M.sand, Vector3(w * 0.5 + 3.5, H + 0.9, 2.8), _at(0, -0.1, -hz - 2.8), 10, 5)
	for s: float in [-1.0, 1.0]:
		_ball(M.sand, Vector3(2.6, H * 0.8, d * 0.5 + 1.5), _at(s * (hx + 2.6), -0.2, -1.0), 10, 5)
		_ball(M.sand, Vector3(2.0, 1.4, 2.2), _at(s * (hx + 2.0), -0.1, d * 0.5 - 0.5), 8, 4)


## The ramp of sand down to the door: a slope from Apron Rise outside to the floor, with the
## cut's banks either side. It is solid (the one way in).
func _apron(door_x: float, d: float) -> void:
	var hz := d * 0.5 + WALL
	var run := maxf(apron_rise * 6.0, 2.5)
	var a := Vector3(door_x, -0.2, hz)
	var b := Vector3(door_x, apron_rise - 0.2, hz + run)
	_solid(M.sand, Vector3(2.6, a.distance_to(b) + 0.4, 0.4), PropMesh.along(a, b))
	for s: float in [-1.0, 1.0]:
		_ball(M.sand, Vector3(1.0, apron_rise + 0.5, run * 0.6), _at(door_x + s * 2.0, -0.1, hz + run * 0.5), 8, 4)


## The bed, the table and stool, the hatch, the hanging lamp, a shelf.
func _inside(w: float, d: float) -> void:
	var bx := -w * 0.5 + 0.55
	var bz := -d * 0.5 + 1.1
	_solid(M.timber, Vector3(0.95, 0.4, 2.0), _at(bx, 0.2, bz))
	_pm.box(M.cloth, Vector3(0.85, 0.18, 1.9), _at(bx, 0.48, bz))
	_pm.cyl(M.cloth, 0.14, 0.14, 0.8, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(bx, 0.64, bz - 0.75)), 6)
	_bed_mark.position = Vector3(bx, 0.6, bz)
	var tx := w * 0.5 - 1.2
	var tz := -d * 0.5 + 1.0
	_solid(M.timber, Vector3(1.2, 0.08, 0.7), _at(tx, 0.74, tz))
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.28, 0.28]:
			_pm.box(M.timber, Vector3(0.08, 0.72, 0.08), _at(tx + sx, 0.36, tz + sz))
	_boxes.append([Vector3(1.2, 0.74, 0.7), _at(tx, 0.37, tz)])
	_pm.cyl(M.timber, 0.2, 0.2, 0.45, _at(tx - 0.2, 0.22, tz + 0.9), 6)
	_boxes.append([Vector3(0.5, 0.45, 0.5), _at(tx - 0.2, 0.22, tz + 0.9)])
	_pm.cyl(M.stone_dark, 0.12, 0.1, 0.3, _at(tx + 0.3, 0.93, tz), 6)
	# The hatch: a dark square in the floor with a timber kerb, its lid leaning on the wall.
	var hx := 1.6
	var hzz := 0.6
	_pm.box(M.hole, Vector3(1.0, 0.03, 1.0), _at(hx, 0.01, hzz))
	for s: float in [-1.0, 1.0]:
		_pm.box(M.timber, Vector3(1.2, 0.08, 0.1), _at(hx, 0.04, hzz + s * 0.55))
		_pm.box(M.timber, Vector3(0.1, 0.08, 1.2), _at(hx + s * 0.55, 0.04, hzz))
	_pm.box(M.timber, Vector3(1.1, 0.06, 1.1), Transform3D(Basis(Vector3.RIGHT, -1.3), Vector3(hx + 0.6, 0.55, -d * 0.5 + 0.35)))
	# The lamp on a chain, and a shelf with jars on the right wall.
	_pm.stick(M.metal, Vector3(0.3, H, 0.2), Vector3(0.3, 2.05, 0.2), 0.03)
	_pm.box(M.iron_dark, Vector3(0.3, 0.12, 0.3), _at(0.3, 2.0, 0.2))
	_pm.box(M.lamp, Vector3(0.22, 0.2, 0.22), _at(0.3, 1.86, 0.2))
	_pm.box(M.timber, Vector3(0.3, 0.05, 2.0), _at(w * 0.5 - 0.15, 1.5, 0.4))
	for k in 4:
		_pm.cyl(M.stone_dark, 0.1, 0.09, 0.28, _at(w * 0.5 - 0.15, 1.66, -0.3 + k * 0.45), 6)
