extends SceneTree
# The structure kit's self-test (headless): makes one of each prop in scripts/props_kit/
# (giant_fan, rooftop_kit, every megastructure_kit kind, both rubble kinds, stain_strips),
# waits two frames, and checks that each built a mesh with PS1 materials only, got collision
# where it should (and not where it shouldn't), that a seed repeats and another seed differs,
# and that the fan turns and pulses its light while the game runs.
# Run: godot --headless --path . -s tests/kit/test_kit_structure.gd   -> ends with PASS or FAIL.

const KIT := "res://scripts/props_kit/"
const MEGA_KINDS := ["Buttress", "Arch", "Shaft", "Setback", "Walkway", "Chains", "Gantry"]
var failures: PackedStringArray = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var props := {}
	props["Fan"] = load(KIT + "giant_fan.gd").new()
	props["FanSolid"] = load(KIT + "giant_fan.gd").new()
	props["FanSolid"].solid = true
	props["FanSolid"].lit = false
	props["Roof"] = load(KIT + "rooftop_kit.gd").new()
	props["RoofSolid"] = load(KIT + "rooftop_kit.gd").new()
	props["RoofSolid"].solid = true
	props["RoofSolid"].random_seed = 5
	for i in MEGA_KINDS.size():
		var m: Node3D = load(KIT + "megastructure_kit.gd").new()
		m.kind = i
		props["Mega" + MEGA_KINDS[i]] = m
	props["Rubble"] = load(KIT + "rubble.gd").new()
	props["RubbleWalkway"] = load(KIT + "rubble.gd").new()
	props["RubbleWalkway"].kind = 1
	props["RubbleWalkway"].drop = 4.0
	props["Stains"] = load(KIT + "stain_strips.gd").new()
	for n in props:
		var p: Node3D = props[n]
		p.name = n
		world.add_child(p)
	for i in 2:
		await process_frame
	for n in props:
		_check_built(n, props[n])
	# Collision only where asked for.
	_expect(_shapes(props["Fan"]) == 0, "Fan: collision without Solid")
	_expect(_shapes(props["FanSolid"]) == 1, "FanSolid: expected one box, got %d" % _shapes(props["FanSolid"]))
	_expect(_shapes(props["Roof"]) == 0, "Roof: collision without Solid")
	_expect(_shapes(props["RoofSolid"]) >= 5, "RoofSolid: expected boxes for the pieces and rails, got %d" % _shapes(props["RoofSolid"]))
	for k in MEGA_KINDS:
		var want_none: bool = (k == "Chains")
		var got := _shapes(props["Mega" + k])
		_expect((got == 0) == want_none, "Mega%s: %d collision shapes" % [k, got])
	_expect(_shapes(props["Rubble"]) == 2, "Rubble: expected two low boxes, got %d" % _shapes(props["Rubble"]))
	_expect(_shapes(props["RubbleWalkway"]) == 2, "RubbleWalkway: expected the slab and the heap, got %d" % _shapes(props["RubbleWalkway"]))
	_expect(_shapes(props["Stains"]) == 0, "Stains: collision on a stain")
	# Shapes: the shaft reaches up, the chains hang down, the walkway reaches out, stains hang.
	_expect(props["MegaShaft"]._mesh.mesh.get_aabb().end.y >= 20.0, "MegaShaft: does not rise 20 m")
	_expect(props["MegaChains"]._mesh.mesh.get_aabb().position.y <= -19.0, "MegaChains: do not hang 20 m")
	_expect(props["MegaWalkway"]._mesh.mesh.get_aabb().end.z >= 12.0, "MegaWalkway: does not reach 12 m out")
	_expect(props["MegaGantry"]._mesh.mesh.get_aabb().size.x >= 12.0, "MegaGantry: not 12 m long")
	var st: AABB = props["Stains"]._mesh.mesh.get_aabb()
	_expect(st.end.y <= 0.001 and st.position.y < -0.5 and st.end.z < 0.03, "Stains: not thin strips hanging below the origin: %s" % st)
	_expect(props["Stains"].strip_count >= 4, "Stains: only %d strips over 6 m" % props["Stains"].strip_count)
	_expect(props["Roof"].piece_count >= 3, "Roof: only %d pieces at density 0.6" % props["Roof"].piece_count)
	# Seeds: the same seed builds the same roof; another seed a different one.
	var roof2: Node3D = load(KIT + "rooftop_kit.gd").new()
	world.add_child(roof2)
	_expect(_verts(roof2) == _verts(props["Roof"]), "Roof: the same seed built a different roof")
	roof2.random_seed = 9
	_expect(_verts(roof2) != _verts(props["Roof"]) or roof2._mesh.mesh.get_aabb() != props["Roof"]._mesh.mesh.get_aabb(), "Roof: seed 9 built the same roof as seed 1")
	var rubble2: Node3D = load(KIT + "rubble.gd").new()
	world.add_child(rubble2)
	var same: bool = rubble2._mesh.mesh.get_aabb() == props["Rubble"]._mesh.mesh.get_aabb()
	rubble2.random_seed = 3
	_expect(same and rubble2._mesh.mesh.get_aabb() != props["Rubble"]._mesh.mesh.get_aabb(), "Rubble: seeds do not repeat and differ")
	# The fan turns and its light pulses while the game runs.
	var fan: Node3D = props["Fan"]
	var angle_before: float = fan._blades.rotation.z
	var energies := {}
	for i in 40:
		await process_frame
		energies[snappedf(fan._light.light_energy, 0.01)] = true
	_expect(fan._blades.rotation.z != angle_before, "Fan: the blades do not turn")
	_expect(energies.size() > 3, "Fan: the backlight does not pulse (%d distinct energies)" % energies.size())
	_expect(fan._light.light_color == fan.color, "Fan: the light is not the fan's colour")
	_expect(not props["FanSolid"]._light.visible, "FanSolid: an unlit fan still shows its light")
	# Settings rebuild: a bigger fan, a longer walkway.
	var wide: float = fan._mesh.mesh.get_aabb().size.x
	fan.radius = 5.0
	_expect(fan._mesh.mesh.get_aabb().size.x > wide, "Fan: a bigger radius did not widen the housing")
	if failures.is_empty():
		print("PASS structure kit: %d props built, collided, seeded and animated" % props.size())
		quit(0)
	else:
		for f in failures:
			print("FAIL ", f)
		print("FAIL structure kit: %d problems" % failures.size())
		quit(1)


func _check_built(n: String, p: Node3D) -> void:
	var meshes := 0
	for c in p.get_children(true):
		if c is MeshInstance3D and c.mesh and c.mesh.get_surface_count() > 0:
			meshes += 1
			_expect(c.mesh.get_aabb().size.length() > 0.1, "%s: the mesh has no size" % n)
			for i in c.mesh.get_surface_count():
				var m: Material = c.mesh.surface_get_material(i)
				_expect(m is ShaderMaterial and (m as ShaderMaterial).shader != null, "%s: surface %d has no PS1 material" % [n, i])
	_expect(meshes == (2 if n.begins_with("Fan") else 1), "%s: expected %d built meshes, got %d" % [n, 2 if n.begins_with("Fan") else 1, meshes])


func _shapes(p: Node3D) -> int:
	var count := 0
	for c in p.get_children(true):
		if c is StaticBody3D:
			for s in c.get_children():
				if s is CollisionShape3D and s.shape:
					count += 1
	return count


func _verts(p: Node3D) -> int:
	var m: Mesh = p._mesh.mesh
	var total := 0
	for i in m.get_surface_count():
		total += m.surface_get_array_len(i)
	return total


func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
