extends Control
## Build Mode's lines over the 3D view, drawn flat on the screen (a 2D overlay, so nothing is
## added to the level's 3D world): an amber box around the selection, seen through walls (red
## when the story needs it), and small diamonds on the things you can't otherwise see (lamps
## yellow, sounds blue, zones and story cameras red, decals green, particles white), so they can
## be clicked. A marker behind a wall isn't drawn (one physics ray each, a few times a second).

const Pick := preload("res://scripts/dev/build_pick.gd")
const SELECT := Color(1.0, 0.76, 0.4)
const LOCKED := Color(1.0, 0.35, 0.3)
const MARK_RANGE := 30.0  ## markers further from the camera than this aren't drawn
const MARK_SIZE := 0.16   ## half size of a marker diamond, metres
## The size given to a thing with no mesh at all (a lamp, a sound, a zone).
const NOTHING := AABB(Vector3(-0.35, -0.35, -0.35), Vector3(0.7, 0.7, 0.7))

var camera: Camera3D
var _box: Array = []      # the selection's 12 edges in world space
var _box_colour := SELECT
var _marks: Array = []    # [world position, colour]
var _proxies: Array[Node3D] = []  # every invisible thing in the level (refreshed every 2 s)
var _proxy_root: Node
var _proxy_at := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()  # the camera moves every frame


## The box around `node` (null clears it). Red when it is a story node.
func show_selection(node: Node3D, locked := false) -> void:
	_box.clear()
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	var xf := node.global_transform
	for e: Array in _edges(bounds_of(node).grow(0.03)):
		_box.append([xf * (e[0] as Vector3), xf * (e[1] as Vector3)])
	_box_colour = LOCKED if locked else SELECT


## Finds the invisible things near the camera under `root` that a camera ray can reach.
func show_markers(root: Node, eye: Vector3) -> void:
	_marks.clear()
	if root == null or camera == null:
		return
	var now := Time.get_ticks_msec()
	if root != _proxy_root or now - _proxy_at > 2000:  # the whole tree is walked every 2 s only
		_collect(root)
		_proxy_root = root
		_proxy_at = now
	var space := camera.get_world_3d().direct_space_state
	for n: Node3D in _proxies:
		if not is_instance_valid(n) or not n.is_visible_in_tree():
			continue
		var at := n.global_position
		if at.distance_to(eye) < MARK_RANGE and _seen(space, eye, at):
			_marks.append([at, _colour(n)])


func _collect(root: Node) -> void:
	_proxies.clear()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D and not (n as Node3D).visible or n.is_in_group("player"):
			continue
		if Pick.is_proxy(n):
			_proxies.append(n)
		for child in n.get_children():
			stack.append(child)


func _draw() -> void:
	if camera == null:
		return
	for e: Array in _box:
		_line3(e[0], e[1], _box_colour, 1.5)
	var r := MARK_SIZE
	for m: Array in _marks:
		var at: Vector3 = m[0]
		for t: Vector3 in [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]:
			for tip: Vector3 in [Vector3(0, r, 0), Vector3(0, -r, 0)]:
				_line3(at + t, at + tip, m[1], 1.0)


## A 3D line on the screen (clipped at the camera's near plane).
func _line3(a: Vector3, b: Vector3, colour: Color, width: float) -> void:
	var near := camera.global_position - camera.global_basis.z * (camera.near + 0.01)
	var plane := Plane(-camera.global_basis.z, near)
	var a_in := plane.is_point_over(a)
	var b_in := plane.is_point_over(b)
	if not a_in and not b_in:
		return
	if a_in != b_in:  # one end is behind the camera: cut the line where it crosses
		var cut: Variant = plane.intersects_segment(a, b)
		if cut == null:
			return
		if a_in:
			b = cut
		else:
			a = cut
	draw_line(camera.unproject_position(a), camera.unproject_position(b), colour, width)


func _seen(space: PhysicsDirectSpaceState3D, eye: Vector3, at: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(eye, at, 1)
	var hit := space.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).distance_to(at) < 0.6


## The node's size: every mesh inside it, in its own space (a small box when it has none).
static func bounds_of(node: Node3D) -> AABB:
	var inv := node.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is VisualInstance3D and not n is Light3D and (n as Node3D).visible:
			var aabb := (n as VisualInstance3D).get_aabb()
			if aabb.size != Vector3.ZERO:
				var local := (inv * (n as Node3D).global_transform) * aabb
				box = local if first else box.merge(local)
				first = false
		for child in n.get_children(true):
			stack.append(child)
	return NOTHING if first else box


static func _colour(n: Node) -> Color:
	if n is Light3D:
		return Color(1.0, 0.9, 0.3)
	if n is AudioStreamPlayer3D:
		return Color(0.4, 0.7, 1.0)
	if n is Area3D or n is Camera3D:
		return Color(1.0, 0.4, 0.4)
	if n is Decal:
		return Color(0.5, 1.0, 0.5)
	return Color(0.9, 0.9, 0.9)


static func _edges(b: AABB) -> Array:
	var p := b.position
	var s := b.size
	var c := []
	for i in 8:
		c.append(p + Vector3(s.x * (i & 1), s.y * ((i >> 1) & 1), s.z * ((i >> 2) & 1)))
	var out := []
	for pair: Array in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		out.append([c[pair[0]], c[pair[1]]])
	return out
