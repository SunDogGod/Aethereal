extends SceneTree
# The light kit's self-test (headless): makes one of each prop in scripts/props_kit/, waits two
# frames, and checks that every one built its mesh (or its balls), has its light where it should,
# and keeps running through a few frames of animation (motes sink, balls drift, lamps flicker).
# Run: godot --headless --path . -s tests/kit/test_kit_light.gd   -> ends with PASS or FAIL.

const KIT := "res://scripts/props_kit/"
var failures: PackedStringArray = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var props := {
		"LightShaft": load(KIT + "light_shaft.gd").new(),
		"DriftLights": load(KIT + "drift_lights.gd").new(),
		"HaloPost": load(KIT + "halo_lamp.gd").new(),
		"HaloCeiling": load(KIT + "halo_lamp.gd").new(),
		"HaloWall": load(KIT + "halo_lamp.gd").new(),
		"NeonSign": load(KIT + "neon_sign.gd").new(),
		"NeonBlade": load(KIT + "neon_sign.gd").new(),
		"WallLamp": load(KIT + "wall_lamp_sodium.gd").new(),
		"CeilingLamp": load(KIT + "wall_lamp_sodium.gd").new(),
	}
	props["HaloCeiling"].mount = 1
	props["HaloWall"].mount = 2
	props["HaloWall"].flicker = 3
	props["NeonBlade"].double_sided = true
	props["NeonBlade"].bracket = 0.4
	props["NeonBlade"].text = "AE  THER"
	props["NeonBlade"].flicker = 2
	props["CeilingLamp"].mount = 1
	props["CeilingLamp"].flicker = 1
	props["DriftLights"].random_seed = 7
	for n in props:
		var p: Node3D = props[n]
		p.name = n
		world.add_child(p)
	for i in 2:
		await process_frame
	for n in props:
		_check_built(n, props[n])
	# A few frames of animation must not throw, and the moving things must move.
	var drift: Node3D = props["DriftLights"]
	var before: Vector3 = drift._pos[0]
	var shaft: Node3D = props["LightShaft"]
	var mote_before: Vector4 = shaft._mote_data[0]
	for i in 30:
		await process_frame
	_expect(drift._pos[0] != before, "DriftLights: the balls do not move")
	_expect(shaft._mote_data[0] != mote_before, "LightShaft: the motes do not move")
	_expect(props["HaloWall"]._light.light_energy > 0.0, "HaloWall: the flickering light went to nothing")
	# Settings change the build: more glyphs = a wider sign; a taller post = a higher ring.
	var sign: Node3D = props["NeonSign"]
	var narrow: float = sign._mesh.mesh.get_aabb().size.x
	sign.text = "AETHER AETHER"
	_expect(sign._mesh.mesh.get_aabb().size.x > narrow, "NeonSign: longer text did not widen the sign")
	var post: Node3D = props["HaloPost"]
	var low: float = post._light.position.y
	post.height = 6.0
	_expect(post._light.position.y > low, "HaloPost: a taller post did not raise the eye")
	_expect(is_zero_approx(props["LightShaft"]._mesh.mesh.get_aabb().position.y + 8.0), "LightShaft: the cone does not hang 8 m down")
	if failures.is_empty():
		print("PASS light kit: %d props built, animated and resized" % props.size())
		quit(0)
	else:
		for f in failures:
			print("FAIL ", f)
		print("FAIL light kit: %d problems" % failures.size())
		quit(1)


func _check_built(n: String, p: Node3D) -> void:
	var meshes := 0
	var balls := 0
	var lights := 0
	for c in p.get_children(true):
		if c is MeshInstance3D and c.mesh and c.mesh.get_surface_count() > 0:
			meshes += 1
		if c is MultiMeshInstance3D and c.multimesh and c.multimesh.instance_count > 0 and c.multimesh.mesh:
			balls += 1
		if c is OmniLight3D:
			lights += 1
	match n:
		"LightShaft":
			_expect(meshes == 1 and balls == 1, "%s: cone %d, motes %d" % [n, meshes, balls])
		"DriftLights":
			_expect(balls == 1 and lights == 1, "%s: balls %d, lights %d" % [n, balls, lights])
		_:
			_expect(meshes == 1 and lights == 1, "%s: meshes %d, lights %d" % [n, meshes, lights])
	for c in p.get_children(true):
		if c is MeshInstance3D and c.mesh:
			_expect(c.mesh.get_aabb().size.length() > 0.1, "%s: the mesh has no size" % n)
	if n.begins_with("Halo") or n.begins_with("Neon") or n.ends_with("Lamp"):
		var mats := 0
		var m: Mesh = p._mesh.mesh
		for i in m.get_surface_count():
			if m.surface_get_material(i) is ShaderMaterial:
				mats += 1
		_expect(mats == m.get_surface_count() and mats >= 2, "%s: expected every surface to carry a PS1 material (%d of %d)" % [n, mats, m.get_surface_count()])


func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
