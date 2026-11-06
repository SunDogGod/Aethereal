@tool
extends "res://scripts/props_horus/horus_prop.gd"
## The pump station where the Construct pipe leaves the rock: a squat concrete block with an
## iron cornice, a door that never opens (facing +Z), two valve wheels on stub pipes by the door,
## a tall stack, a grated gantry along the roof's front edge with a ladder cage down to the sand,
## warning stripes round the stack's foot and over the door, a lamp over the door (the child
## OmniLight `DoorLamp`). The big pipe leaves through the back wall (-Z) at Pipe Height, 6 m
## out: start a construct_pipe.gd's points there. Origin on the sand, under the middle.

## The block's footprint (x, z) and height.
@export var size := Vector3(12.0, 8.0, 10.0):
	set(value):
		size = value
		_rebuild()
## The big pipe's centre height where it leaves the back wall.
@export var pipe_height := 5.0:
	set(value):
		pipe_height = value
		_rebuild()
@export var stack_height := 18.0:
	set(value):
		stack_height = value
		_rebuild()


func _build() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_solid(M.concrete, Vector3(w, h, d), _at(0, h * 0.5, 0))
	_pm.box(M.concrete, Vector3(w + 1.0, 1.0, d + 1.0), _at(0, 0.4, 0))  # a wide plinth, half in the sand
	_boxes.append([Vector3(w + 1.0, 1.0, d + 1.0), _at(0, 0.4, 0)])
	_pm.box(M.iron_dark, Vector3(w + 0.4, 0.5, d + 0.4), _at(0, h - 0.25, 0))  # the iron cornice
	# The annex on +X: lower, with a louvred vent and stripes down its corner.
	var aw := w * 0.45
	_solid(M.concrete, Vector3(aw, h * 0.55, d * 0.6), _at(w * 0.5 + aw * 0.5, h * 0.275, 0))
	_pm.box(M.iron_dark, Vector3(aw + 0.3, 0.35, d * 0.6 + 0.3), _at(w * 0.5 + aw * 0.5, h * 0.55 - 0.17, 0))
	for k in 4:
		_pm.box(M.iron_dark, Vector3(0.1, 0.25, 1.6), _at(w * 0.5 + aw + 0.03, h * 0.3 + k * 0.4, 0))
	_pm.box(M.stripes, Vector3(0.3, h * 0.55, 0.3), _at(w * 0.5 + aw - 0.05, h * 0.275, d * 0.3 - 0.05))
	_door()
	_valves()
	_stack()
	_gantry()
	# The big pipe out of the back wall, a flange, a saddle block under it.
	var r := 2.0
	var pz := -d * 0.5
	_pm.cyl(M.iron, r, r, 6.0, PropMesh.along(Vector3(0, pipe_height, pz + 0.5), Vector3(0, pipe_height, pz - 6.0)), 12, 2)
	_boxes.append([Vector3(r * 1.8, r * 1.8, 6.0), _at(0, pipe_height, pz - 2.75)])
	_pm.cyl(M.iron_dark, r * 1.15, r * 1.15, 0.5, PropMesh.along(Vector3(0, pipe_height, pz - 0.2), Vector3(0, pipe_height, pz - 0.7)), 12)
	_pm.cyl(M.iron_dark, r * 1.12, r * 1.12, 0.4, PropMesh.along(Vector3(0, pipe_height, pz - 5.0), Vector3(0, pipe_height, pz - 5.4)), 12)
	_solid(M.concrete, Vector3(3.0, pipe_height - r * 0.6, 1.5), _at(0, (pipe_height - r * 0.6) * 0.5, pz - 4.5))
	# A big valve on top of the pipe: a spindle and a wheel.
	_pm.cyl(M.iron_dark, 0.25, 0.25, 1.2, _at(0, pipe_height + r + 0.5, pz - 3.0), 8)
	_pm.ring(M.metal, 0.08, 0.9, _at(0, pipe_height + r + 1.1, pz - 3.0), 12, 4)
	_light("DoorLamp", Vector3(0, 3.4, d * 0.5 + 0.8), Color(1.0, 0.78, 0.5), 1.4, 9.0)


## The door in the front wall: a dark recess, a timber frame, stripes over it, a lamp housing.
func _door() -> void:
	var z := size.z * 0.5
	_pm.box(M.hole, Vector3(1.3, 2.4, 0.1), _at(0, 1.2, z + 0.02))
	for s: float in [-1.0, 1.0]:
		_pm.box(M.timber, Vector3(0.2, 2.6, 0.25), _at(s * 0.75, 1.3, z + 0.08))
	_pm.box(M.timber, Vector3(1.7, 0.25, 0.25), _at(0, 2.7, z + 0.08))
	_pm.box(M.stripes, Vector3(2.4, 0.4, 0.08), _at(0, 3.05, z + 0.04))
	_pm.box(M.iron_dark, Vector3(0.6, 0.3, 0.5), _at(0, 3.5, z + 0.25))
	_pm.box(M.lamp, Vector3(0.5, 0.12, 0.4), _at(0, 3.32, z + 0.25))
	# Rivet plates either side of the door, and a drip of rust under the lamp.
	for s: float in [-1.0, 1.0]:
		_pm.box(M.iron_dark, Vector3(1.2, 1.6, 0.06), _at(s * 2.6, 1.6, z + 0.03))


## Two stub pipes out of the front wall with valve wheels on top, one wheel missing in variant 1.
func _valves() -> void:
	var z := size.z * 0.5
	for i in 2:
		var x := -size.x * 0.5 + 2.2 + i * 1.8
		_pm.cyl(M.iron, 0.35, 0.35, 2.2, PropMesh.along(Vector3(x, 1.4, z - 0.2), Vector3(x, 1.4, z + 2.0)), 10)
		_boxes.append([Vector3(0.8, 0.8, 2.2), _at(x, 1.4, z + 0.9)])
		_pm.cyl(M.iron_dark, 0.42, 0.42, 0.25, PropMesh.along(Vector3(x, 1.4, z + 1.9), Vector3(x, 1.4, z + 2.15)), 10)
		_pm.cyl(M.iron_dark, 0.4, 0.5, 0.6, _at(x, 1.9, z + 1.0), 8)
		_pm.cyl(M.metal, 0.08, 0.08, 0.7, _at(x, 2.4, z + 1.0), 6)
		if not (variant % 2 == 1 and i == 1):
			_pm.ring(M.metal, 0.06, 0.45, _at(x, 2.7, z + 1.0), 10, 4)
			for k in 3:
				_pm.box(M.metal, Vector3(0.8, 0.05, 0.05), _yaw(k * PI / 3.0, x, 2.7, z + 1.0))


## The stack: a tall iron drum off the roof, bands, a striped foot, a cap, soot at the top.
func _stack() -> void:
	var x := size.x * 0.25
	var z := -size.z * 0.15
	var r := 1.1
	_pm.cyl(M.iron_dark, r, r * 1.1, stack_height - size.y, _at(x, (stack_height + size.y) * 0.5, z), 12, 3)
	_boxes.append([Vector3(r * 2.0, stack_height - size.y, r * 2.0), _at(x, (stack_height + size.y) * 0.5, z)])
	_pm.cyl(M.stripes, r * 1.2, r * 1.3, 0.8, _at(x, size.y + 0.4, z), 12)
	for y: float in [0.4, 0.7]:
		_pm.cyl(M.iron, r * 1.06, r * 1.06, 0.3, _at(x, size.y + (stack_height - size.y) * y, z), 12)
	_pm.cyl(M.hole, r * 1.15, r * 1.15, 0.25, _at(x, stack_height - 0.1, z), 12)
	_pm.cyl(M.iron_dark, r * 1.25, r * 1.25, 0.4, _at(x, stack_height - 0.4, z), 12)
	# Guy wires to the roof corners.
	for s: Vector3 in [Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		var foot := Vector3(x, size.y, z) + s * Vector3(size.x * 0.4, 0, size.z * 0.35)
		_pm.stick(M.metal, Vector3(x, stack_height * 0.8, z), foot, 0.05)


## The gantry: a grated walkway along the front of the roof with rails, a ladder cage down the
## +X corner to the sand, a lamp housing at the stack end.
func _gantry() -> void:
	var y := size.y + 0.1
	var z := size.z * 0.5 - 0.6
	var w := size.x
	_pm.box(M.grating, Vector3(w, 0.08, 1.2), _at(0, y, z))
	_pm.box(M.iron_dark, Vector3(w, 0.2, 0.15), _at(0, y - 0.05, z + 0.6))
	var n := int(w / 2.0)
	for i in n + 1:
		var x := -w * 0.5 + w * i / maxf(n, 1)
		_pm.box(M.iron_dark, Vector3(0.08, 1.1, 0.08), _at(x, y + 0.55, z + 0.55))
	for ry: float in [0.5, 1.05]:
		_pm.box(M.iron_dark, Vector3(w, 0.06, 0.06), _at(0, y + ry, z + 0.55))
	# The ladder cage down the +X front corner.
	var lx := w * 0.5 + 0.5
	var lz := z
	for s: float in [-0.3, 0.3]:
		_pm.box(M.iron_dark, Vector3(0.08, size.y + 1.0, 0.08), _at(lx, size.y * 0.5 + 0.4, lz + s))
	var rungs := int(size.y / 0.35)
	for k in rungs:
		_pm.box(M.iron_dark, Vector3(0.06, 0.06, 0.7), _at(lx, 0.5 + k * 0.35, lz))
	var hoops := int((size.y - 2.5) / 1.2)
	for k in hoops:
		_pm.ring(M.iron_dark, 0.04, 0.7, _at(lx + 0.1, 2.8 + k * 1.2, lz), 10, 4)
	_boxes.append([Vector3(1.2, size.y, 1.2), _at(lx + 0.1, size.y * 0.5, lz)])
