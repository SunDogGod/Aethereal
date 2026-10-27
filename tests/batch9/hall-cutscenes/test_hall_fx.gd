extends SceneTree
# Headless: the hall's new effects respond (bodies, pyre, the cube's take/give, glow, burst,
# crackle, sigil, memory fade). Prints HALL FX PASS/FAIL.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var level: Node = load("res://scenes/levels/empty_town.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var story := root.get_node_or_null("Story")
	await _frames(80)
	if story and story.has_method("stop"):
		story.stop()
	var fire: Node = level.get_node("Hall/Story/Bonfire")
	var aura: Node = level.get_node("Hall/Story/CubeAura")
	var captain: Node3D = level.get_node("CaptainFight/Captain")
	var player: Node3D = level.get_node("Player")
	check(aura.receiver_node() == captain, "the cube gives the bodies to the captain")
	var bodies := level.get_node("Hall/Story/Bodies")
	check(bodies.get_child_count() == 8, "eight waiting bodies (%d)" % bodies.get_child_count())
	var solid := 0
	for b in bodies.get_children():
		for c in b.get_children(true):
			if c is CollisionShape3D and not c.disabled and c.shape is BoxShape3D:
				solid += 1
	check(solid == 8, "each waiting body is solid (%d)" % solid)
	var mesh: MeshInstance3D = null
	for c in fire.get_children(true):
		if c is MeshInstance3D and c.mesh is ArrayMesh:
			mesh = c
	check(mesh != null and mesh.mesh.get_surface_count() >= 6, "the pyre has bodies on it (%d surfaces)" % (mesh.mesh.get_surface_count() if mesh else 0))
	# A body heaved on: hidden, the fire flares, the soul rises to the cube, then goes to the captain.
	var b2: Node3D = level.get_node("Hall/Story/Bodies/Body2")
	fire.throw_in(b2, 0.5)
	await _frames(40)
	check(not b2.visible, "throw_in hides the body")
	check(fire.get("_flare") > 0.3, "the fire flares")
	var streams := level.get_node("Hall/Story").get_children().filter(func(n: Node) -> bool: return n is HallStream)
	check(streams.size() == 1, "a stream rises from the fire to the cube")
	await _frames(90)
	check(aura.get("_pulse") > 0.2, "the cube flares when the soul arrives (%.2f)" % aura.get("_pulse"))
	var glowed := false
	for i in 160:
		await physics_frame
		glowed = glowed or captain.get_node_or_null("HallGlow") != null
		if glowed:
			break
	check(glowed, "the captain glows with it")
	await _frames(200)
	check(captain.get_node_or_null("HallGlow") == null, "the glow fades")
	check(level.get_node("Hall/Story").get_children().filter(func(n: Node) -> bool: return n is HallStream).is_empty(), "the streams free themselves")
	# Isabella's sigil: drawn by 2.3 s, a great sacrifice: the cube blazes and holds it.
	var circle: Node3D = level.get_node("InkCircle")
	circle.visible = true
	await _frames(70)
	check(circle.get("_done") > 0.0 and circle.get("_done") < 1.0, "the sigil is drawing at 1.2 s (%.2f)" % circle.get("_done"))
	await _frames(70)
	check(circle.get("_done") >= 1.0, "the sigil is drawn by 2.4 s")
	circle.release()
	await _frames(170)
	check(aura.get("_blaze") > 0.5, "her soul makes the cube blaze (%.2f)" % aura.get("_blaze"))
	check(absf((fire.get("_flame_mat") as ShaderMaterial).get_shader_parameter("lean").length()) > 0.5, "the fire bends toward the cube")
	var hall_light: OmniLight3D = aura.get("_hall_light")
	check(hall_light.light_energy > 2.0, "the hall lights up (%.1f)" % hall_light.light_energy)
	aura.give(player, 3.0)
	await _frames(100)
	var glow := player.get_node_or_null("HallGlow")
	check(glow != null and float(glow.get("strength")) >= 3.0, "the cube gives it to Aeneas: he glows")
	level.get_node("Hall/Story/HallFx").burst(player)
	await _frames(10)
	check(player.get_node_or_null("HallCrackle") != null, "the burst leaves a crackle on him")
	await _frames(200)
	check(player.get_node_or_null("HallGlow") == null, "the cube's glow is gone after the burst")
	check(player.get_node_or_null("HallCrackle") != null, "the crackle lasts a few seconds")
	await _frames(240)
	check(player.get_node_or_null("HallCrackle") == null, "the crackle ends when he is not erupting")
	level.get_node("Hall/Story/HallFx").spray(captain)
	var fade: CanvasLayer = level.get_node("Hall/Story/MemoryFade")
	fade.out(1.0)
	await _frames(80)
	var mat: ShaderMaterial = fade.get("_mat")
	check(mat.get_shader_parameter("black") >= 0.99, "MemoryFade.out goes to black")
	var crackle: AudioStreamPlayer3D = level.get_node("Hall/Story/Bonfire/Crackle")
	check(crackle.volume_db < -50.0, "the fire's sound goes with it")
	print("HALL FX %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit()
