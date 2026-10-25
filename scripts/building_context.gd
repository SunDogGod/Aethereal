extends RefCounted
## What stands around a BUILDING block, so building_faces.gd can put doors and windows only where
## a real building would have them. It reads the solid Blocks of the same scene (physics layer 1,
## at least 25 cm thick and not Trim, so rails, pipes, signs and TV panels don't count) as boxes,
## with plain maths: no physics queries, so it works the same in the editor and in the game.
##   - blocked_run(): is something solid within 1.5 m in front of a window? (a neighbour pressed
##     against the face, a slab or walkway cutting across it) -> plain wall there.
##   - can_enter(): is there floor right at a door's foot, and room to stand? -> a door may go here.
##   - street(): the lowest floor that runs along a face partway up it (a courtyard against a
##     foundation wall) -> the ground floor goes at that height.
## The list of boxes is gathered once per frame per scene and shared by every building in it.
## Moving a neighbour in the editor doesn't rebuild a building: nudge the building, or reopen the
## scene, to refresh its doors and windows. (The game always builds them fresh.)

const MIN_THICK := 0.25  # thinner blocks (rails, signs, panels) don't hide windows or make floors
const CLEAR := 1.5  # metres in front of a window that must be free
enum { BLOCKED = -1, NO_FLOOR, ROOF, STREET }  # what floor checks find

static var _frame := -1
static var _root_id := 0
static var _boxes: Array[AABB] = []
static var _owners: Array = []  # the Block each box came from
static var _flat: Array[bool] = []  # axis-aligned (can be a floor); ramps and tilted things can't
static var _inv: Array[Transform3D] = []  # world -> block space, for tilted blocks
static var _half: Array[Vector3] = []  # half the block's size

var _near: Array[int] = []  # indices of boxes near this building (filtered once)
# The face being built: the block's transform, the face's bottom-left corner and axes (local).
var _xf: Transform3D
var _o: Vector3
var _u: Vector3
var _nw: Vector3  # the face's outward normal, in the world


func _init(block) -> void:
	_xf = block.global_transform
	_gather(block)
	var mine := world_box(block).grow(4.0)
	for i in _boxes.size():
		if _owners[i] != block and _boxes[i].intersects(mine):
			_near.append(i)


## A Block's world-space bounding box.
static func world_box(b: Node3D) -> AABB:
	var xf: Transform3D = b.global_transform
	var h: Vector3 = b.size * 0.5
	var a := AABB(xf.origin, Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				a = a.expand(xf * Vector3(h.x * sx, h.y * sy, h.z * sz))
	return a


## Points the checks at one face: its bottom-left corner, the axis along it, its normal (local).
func set_face(origin: Vector3, u_axis: Vector3, n: Vector3) -> void:
	_o = origin
	_u = u_axis
	_nw = (_xf.basis * n).normalized()


## A point on the current face, u metres along and y metres up from its bottom-left corner.
func world(u: float, y: float) -> Vector3:
	return _xf * (_o + _u * u + Vector3.UP * y)


## The storeys (0..count-1) of one bay's run of windows whose glass has something solid within
## 1.5 m in front of it. The glass sits 0.3..0.86 of the way up a storey, 0.2..0.8 across the bay.
func blocked_run(x: float, bay: float, ya: float, count: int, storey_h: float) -> Array[int]:
	var out: Array[int] = []
	var a := world(x, ya)
	var b := world(x + bay, ya + count * storey_h)
	var slab := AABB(a, Vector3.ZERO).expand(b).expand(a + _nw * CLEAR).expand(b + _nw * CLEAR)
	var list := _touching(slab.grow(0.05))
	if list.is_empty():
		return out
	for k in count:
		var y := ya + k * storey_h
		for f: Vector2 in [Vector2(0.5, 0.58), Vector2(0.25, 0.35), Vector2(0.75, 0.35), Vector2(0.25, 0.82), Vector2(0.75, 0.82)]:
			if _hits(list, world(x + bay * f.x, y + storey_h * f.y), CLEAR):
				out.append(k)
				break
	return out


## A door at u = x on a ground floor at height y0: the floor right at its foot (NO_FLOOR, ROOF of
## another building, or STREET), or BLOCKED when something solid stands within a metre of it
## between knee and head height.
func can_enter(x: float, y0: float) -> int:
	var fl := floor_at(world(x, y0) + _nw * 0.7)
	if fl == NO_FLOOR:
		return fl
	for up: float in [0.5, 1.6]:
		if _hits(_near, world(x, y0 + up), 1.1):
			return BLOCKED
	return fl


## True when at least one bay of a ground floor at y0 has floor in front to step onto.
func any_floor(bays: int, margin: float, bay: float, y0: float) -> bool:
	for i in bays:
		if floor_at(world(margin + (i + 0.5) * bay, y0) + _nw * 0.7) != NO_FLOOR:
			return true
	return false


## What floor is right under `p` (a flat solid with its top within a hand's width of `p.y`):
## NO_FLOOR, ROOF (the top of another building block, or a ledge under 40 m2: a door may open
## onto it, a shop won't) or STREET (a pavement, deck or walkway).
func floor_at(p: Vector3) -> int:
	var found := NO_FLOOR
	for i in _near:
		var box: AABB = _boxes[i]
		if not _flat[i]:
			continue
		if absf(box.end.y - p.y) <= 0.15 and p.x > box.position.x and p.x < box.end.x \
				and p.z > box.position.z and p.z < box.end.z:
			var small := box.size.x * box.size.z < 40.0
			found = maxi(found, ROOF if _owners[i].style == 1 or small else STREET)
	return found


## The lowest floor height (metres up the current face) that runs at least 3 m along it, reaches
## at least 1.5 m out from it and sits more than 0.5 m above its bottom and 4 m below its top.
## NAN when there is none.
func street(w: float, ht: float) -> float:
	var o := world(0.0, 0.0)
	var u := (_xf.basis * _u).normalized()
	var best := NAN
	var plane := _nw.dot(o)
	for i in _near:
		if not _flat[i]:
			continue
		var box: AABB = _boxes[i]
		var top := box.end.y
		if top < o.y + 0.5 or top > o.y + ht - 4.0:
			continue
		var s := _span(box, _nw)  # how far the box reaches out of the face plane
		if s.x - plane > 0.3 or s.y - plane < 1.5:
			continue
		var t := _span(box, u)
		var along := minf(t.y - u.dot(o), w) - maxf(t.x - u.dot(o), 0.0)
		if along < 3.0:
			continue
		if is_nan(best) or top < best:
			best = top
	return best - o.y


## True when a segment from `p` straight out of the face for `dist` metres hits one of `list`.
func _hits(list: Array[int], p: Vector3, dist: float) -> bool:
	var a := p + _nw * 0.02
	var b := p + _nw * dist
	for i in list:
		if not _boxes[i].intersects_segment(a, b):
			continue
		if _flat[i]:
			return true
		# A tilted block (a ramp): test against its real box, not the box around it.
		var inv: Transform3D = _inv[i]
		if AABB(-_half[i], _half[i] * 2.0).intersects_segment(inv * a, inv * b):
			return true
	return false


## The boxes (indices) that touch `box`: a quick first pass before the finer tests.
func _touching(box: AABB) -> Array[int]:
	var out: Array[int] = []
	for i in _near:
		if _boxes[i].intersects(box):
			out.append(i)
	return out


## The box's extent along an axis (a unit X or Z vector, either sign): (min, max) of dot(axis, p).
static func _span(box: AABB, axis: Vector3) -> Vector2:
	var a := axis.dot(box.position)
	var b := axis.dot(box.end)
	return Vector2(minf(a, b), maxf(a, b))


## Gathers the solid Blocks of the block's scene once per frame.
static func _gather(block) -> void:
	var root: Node = block
	while root.owner != null:
		root = root.owner
	if root == block and block.is_inside_tree():
		root = block.get_tree().root
	var frame := Engine.get_process_frames()
	if frame == _frame and root.get_instance_id() == _root_id:
		return
	_frame = frame
	_root_id = root.get_instance_id()
	_boxes.clear()
	_owners.clear()
	_flat.clear()
	_inv.clear()
	_half.clear()
	for b in root.find_children("*", "StaticBody3D", true, false):
		if not b.has_method("set_runtime_material") or not b.is_inside_tree() or (b.collision_layer & 1) == 0:
			continue
		if b.trim or b.size.x < MIN_THICK or b.size.y < MIN_THICK or b.size.z < MIN_THICK:
			continue
		_boxes.append(world_box(b))
		_owners.append(b)
		var xf: Transform3D = b.global_transform
		var basis := xf.basis.orthonormalized()
		var square := true  # every axis along a world axis: the bounding box is the block itself
		for axis in [basis.x, basis.y, basis.z]:
			square = square and maxf(absf(axis.x), maxf(absf(axis.y), absf(axis.z))) > 0.999
		_flat.append(square)
		_inv.append(xf.affine_inverse())
		_half.append(b.size * 0.5)
