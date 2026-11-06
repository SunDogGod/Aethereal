extends SceneTree
# The Horus arc's landmark props (scripts/props_horus/): each one is made, given two frames,
# and checked: a mesh with surfaces, a collision body where it should be solid, the named
# children a scene relies on (Spray, BarrierWall, BedMark, Beam, Flame, the lights), and the
# things that move while the game runs (the beam nods, the water drifts, the spray can start).
# Run headless: godot --headless --path . -s tests/horus/test_props.gd

const DIR := "res://scripts/props_horus/"
var _fails := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	await _check_pipe(world)
	await _check_simple(world, "pump_house.gd", {}, ["DoorLamp"])
	await _check_derrick(world)
	await _check_simple(world, "condenser_frame.gd", {}, [])
	await _check_shack(world)
	await _check_obelisk(world)
	await _check_simple(world, "pyramid.gd", {}, [])
	await _check_lake(world)
	await _check_simple(world, "causeway_gate.gd", {}, ["TorchL", "TorchR", "Flames"])
	await _check_simple(world, "causeway_gate.gd", {"lit": false}, ["Flames"])
	await _check_simple(world, "derrick.gd", {"lit": false}, ["Beam", "Flame"])
	await _check_simple(world, "obelisk.gd", {"lit": false}, ["BarrierWall"])
	await _check_simple(world, "condenser_frame.gd", {"rows": 1, "per_row": 1, "variant": 3}, [])
	await _check_simple(world, "pump_house.gd", {"variant": 1}, [])
	print("PASS horus props" if _fails == 0 else "FAIL horus props: %d problems" % _fails)
	quit(0 if _fails == 0 else 1)


func _make(parent: Node, script: String, settings: Dictionary) -> Node3D:
	var n: Node3D = load(DIR + script).new()
	for k in settings:
		n.set(k, settings[k])
	parent.add_child(n)
	await process_frame
	await process_frame
	return n


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: ", what)


## Mesh surfaces, a collision body when solid, the named children, and no script errors.
func _basic(n: Node3D, script: String, want_body: bool, children: Array) -> void:
	var mesh: ArrayMesh = n._mesh.mesh
	_ok(mesh != null and mesh.get_surface_count() > 0, script + ": no mesh")
	if mesh:
		var verts := 0
		for i in mesh.get_surface_count():
			verts += mesh.surface_get_array_len(i)
		_ok(verts > 24, script + ": too few vertices (%d)" % verts)
		print("  %s: %d surfaces, %d vertices" % [script, mesh.get_surface_count(), verts])
	var body := _body(n)
	_ok((body != null) == want_body, script + ": collision body %s" % ("missing" if want_body else "present when not solid"))
	if body:
		_ok(body.get_child_count() > 0, script + ": body has no shapes")
		_ok(body.collision_layer & 1, script + ": body not on layer 1")
	for c in children:
		_ok(n.get_node_or_null(c) != null, script + ": child %s missing" % c)


func _body(n: Node) -> StaticBody3D:
	for c in n.get_children(true):
		if c is StaticBody3D:
			return c
	return null


func _check_simple(world: Node, script: String, settings: Dictionary, children: Array) -> void:
	var n := await _make(world, script, settings)
	_basic(n, script, true, children)
	n.queue_free()


func _check_pipe(world: Node) -> void:
	var pts := PackedVector3Array([Vector3(0, 6, 0), Vector3(0, 6, 60), Vector3(20, 7, 110)])
	var whole := await _make(world, "construct_pipe.gd", {"points": pts})
	_basic(whole, "construct_pipe.gd", true, ["Spray"])
	var spray: GPUParticles3D = whole.get_node("Spray")
	_ok(not spray.emitting, "construct_pipe.gd: spray emitting on a whole pipe")
	whole.queue_free()
	var broken := await _make(world, "construct_pipe.gd", {"points": pts, "broken": true, "break_at": 40.0})
	_basic(broken, "construct_pipe.gd (broken)", true, ["Spray"])
	var body := _body(broken)
	_ok(body.get_child_count() >= 6, "construct_pipe.gd (broken): too few collision shapes")
	spray = broken.get_node("Spray")
	_ok(spray.position.z > 35.0 and spray.position.z < 45.0, "construct_pipe.gd: spray not at the tear (%s)" % spray.position)
	spray.emitting = true
	await process_frame
	_ok(spray.emitting, "construct_pipe.gd: spray would not start")
	broken.queue_free()


func _check_derrick(world: Node) -> void:
	var n := await _make(world, "derrick.gd", {})
	_basic(n, "derrick.gd", true, ["Beam", "Flame", "FlareLight"])
	var beam: MeshInstance3D = n.get_node("Beam")
	var flame: MeshInstance3D = n.get_node("Flame")
	_ok(beam.mesh != null and beam.mesh.get_surface_count() > 0, "derrick.gd: beam has no mesh")
	_ok(flame.mesh != null and flame.mesh.get_surface_count() > 0, "derrick.gd: lit flame has no mesh")
	var before := beam.rotation.z
	for i in 20:
		await process_frame
	_ok(not is_equal_approx(before, beam.rotation.z) or absf(beam.rotation.z) > 0.001, "derrick.gd: beam does not nod")
	n.queue_free()
	var dead := await _make(world, "derrick.gd", {"lit": false})
	_ok(dead.get_node_or_null("FlareLight") == null, "derrick.gd: dead derrick keeps its flare light")
	_ok((dead.get_node("Flame") as MeshInstance3D).mesh.get_surface_count() == 0, "derrick.gd: dead derrick has a flame")
	dead.queue_free()


func _check_shack(world: Node) -> void:
	var n := await _make(world, "desert_shack.gd", {})
	_basic(n, "desert_shack.gd", true, ["BedMark", "Lamp"])
	var mark: Marker3D = n.get_node("BedMark")
	_ok(mark.position.y > 0.3 and mark.position.y < 1.0, "desert_shack.gd: BedMark not at bed height (%s)" % mark.position)
	# The door is open: a ray from outside, 1 m up, through the doorway, hits nothing inside the frame.
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var door := Vector3(1.0, 1.0, n.inner.y * 0.5)
	var q := PhysicsRayQueryParameters3D.create(door + Vector3(0, 0, 2.0), door - Vector3(0, 0, 2.0))
	var hit: Dictionary = space.intersect_ray(q)
	_ok(hit.is_empty(), "desert_shack.gd: the doorway is blocked at %s" % (hit.get("position", "?")))
	q = PhysicsRayQueryParameters3D.create(door + Vector3(0, 1.5, 2.0), door + Vector3(0, 1.5, -2.0))
	hit = space.intersect_ray(q)
	_ok(not hit.is_empty(), "desert_shack.gd: nothing over the door (the lintel should be there)")
	q = PhysicsRayQueryParameters3D.create(Vector3(-1.0, 1.0, 0.0), Vector3(-1.0, -1.0, 0.0))
	hit = space.intersect_ray(q)
	_ok(not hit.is_empty() and absf(hit.position.y) < 0.02, "desert_shack.gd: no floor at the origin's height")
	n.queue_free()


func _check_obelisk(world: Node) -> void:
	var n := await _make(world, "obelisk.gd", {})
	_basic(n, "obelisk.gd", true, ["BarrierWall", "EdgeLight"])
	var wall: Node3D = n.get_node("BarrierWall")
	_ok(wall.get_child_count() == 2, "obelisk.gd: barrier should be two panels")
	for p in wall.get_children():
		_ok((p as MeshInstance3D).material_override != null, "obelisk.gd: barrier panel has no material")
	_ok(wall.visible, "obelisk.gd: barrier hidden while lit")
	wall.visible = false
	n.lit = false
	await process_frame
	_ok(n.get_node_or_null("EdgeLight") == null, "obelisk.gd: unlit obelisk keeps its edge light")
	# The plinth top is reachable up the ramp: a ray down at the ramp's middle finds a slope.
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(0, 5, 11.0), Vector3(0, -2, 11.0))
	var hit: Dictionary = space.intersect_ray(q)
	_ok(not hit.is_empty() and hit.position.y > 0.2 and hit.position.y < 1.8, "obelisk.gd: no ramp at z=11 (%s)" % hit.get("position", "none"))
	n.queue_free()


func _check_lake(world: Node) -> void:
	var n := await _make(world, "lake.gd", {})
	_basic(n, "lake.gd", false, [])
	for i in 10:
		await process_frame
	var mat: ShaderMaterial = n._water_mat
	_ok(mat != null, "lake.gd: no runtime water material")
	if mat:
		var off: Vector2 = mat.get_shader_parameter("uv_offset")
		_ok(off.length() > 0.0, "lake.gd: the water does not drift")
	n.queue_free()
	var wade := await _make(world, "lake.gd", {"solid": true})
	_basic(wade, "lake.gd (solid)", true, [])
	wade.queue_free()
