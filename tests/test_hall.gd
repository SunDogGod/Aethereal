extends SceneTree
# Headless test of the Empty Town's ending (the 2026-10-26 story): the Valentina scene and fight
# (her holder stays out of it), the capture (knife at Aeneas's throat, Isabella held), the hall,
# Isabella's break-out, her death and the circle, the eruption, the lieutenant, Valentina to the
# fire, the captain's two phases, the throat lift, Kael, and the hand-off to the Massacre.
# Env: HALL_WORLD=1 runs it inside scenes/world/world.tscn (world/test_hall_world.gd sets it).
# Env: HALL_DEATH=1 dies to the captain BEFORE half instead (test_hall_death.gd sets it).

var level: Node      # the town (the level, or its zone's instance in the world)
var player: Player
var combat: PlayerCombat
var story: Node
var box
var notes := {}      # things seen mid-scene


func _initialize() -> void:
	_run()


func _run() -> void:
	story = root.get_node("Story")
	var scene: Node
	if OS.get_environment("HALL_WORLD") == "1":
		World.pending_level = "res://scenes/levels/empty_town.tscn"
		scene = load(World.SCENE).instantiate()
	else:
		scene = load("res://scenes/levels/empty_town.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	level = scene.get_node("Zones/Town/EmptyTown") if scene is World else scene
	player = scene.get_node("Player")
	combat = player.get_node("Combat")
	await _frames(10)
	box = story.get("_box")  # made in Story's _ready, which has run by now
	await _skip()
	level.get_node("Figures/RoundUp").visible = false  # as if he had passed SneakStart on the way down

	# 1. The Valentina scene: she is dragged in, her holder takes her hostage, the fight starts.
	player.respawn_at(level.global_transform * Vector3(-7.5, 0.2, -7.8))
	await _frames(5)
	await _walk_to(level.global_transform * Vector3(-7.5, 0, -4.8))
	await _skip()
	await _frames(5)
	var vf = level.get_node("ValentinaFight")
	var dragger: Guard = level.get_node("HallFight/Dragger")
	var valentina: Node3D = level.get_node("Figures/Valentina")
	print("VALENTINA: fight active %s, guards %s; Valentina shown %s pose '%s'; holder shown %s, %s, pose '%s', %.2f m from her" % [
			vf.active, _states(vf), valentina.visible, _pose(valentina), dragger.visible,
			Guard.State.keys()[dragger.state], _pose(dragger), _flat(dragger.global_position, valentina.global_position)])

	# 2. Kill the courtyard agents: the capture plays at once (no walk to the door).
	for guard in vf.get_children():
		guard.take_hit(200.0, player.global_position)
		await _frames(3)
	await _frames(5)
	print("WON: fight won %s, capture playing %s, holder still %s" % [vf.won, story.playing, Guard.State.keys()[dragger.state]])
	await _skip()
	await _frames(5)
	var hf = level.get_node("HallFight")
	var lieutenant: Guard = level.get_node("LieutenantFight/Lieutenant")
	var captain: Guard = level.get_node("CaptainFight/Captain")
	var isabella: Node3D = level.get_node("Figures/IsabellaHall")
	var hall_mark: Vector3 = level.get_node("HallMark").global_position
	print("CAPTURED (mid-scene): %s" % notes.get("captured", "not seen"))
	print("HALL: Aeneas %.1f m from HallMark, erupting %s, hall fight active %s (%s)" % [
			_flat(player.global_position, hall_mark), combat.erupting, hf.active, _states(hf)])
	print("HALL: Isabella pose '%s' (collapse), her captor %s, guards %s/%s, ink circle shown %s, Body2 burned %s" % [
			_pose(isabella), Guard.State.keys()[level.get_node("Figures/IsabellaCaptor").state],
			Guard.State.keys()[level.get_node("Figures/HallGuard1").state], Guard.State.keys()[level.get_node("Figures/HallGuard2").state],
			level.get_node("InkCircle").visible, not level.get_node("Hall/Story/Bodies/Body2").visible])
	print("HALL: Valentina shown %s pose '%s'; lieutenant %s dormant %s, captain %s dormant %s; lieutenant back on his layer %s" % [
			level.get_node("Figures/ValentinaHall").visible, _pose(level.get_node("Figures/ValentinaHall")),
			Guard.State.keys()[lieutenant.state], lieutenant.dormant, Guard.State.keys()[captain.state], captain.dormant,
			lieutenant.collision_layer == 4])

	# 3. The eruption: slam until the hall's agents (and Valentina's holder) are down.
	var t := 0
	while hf.active and t < 2400:
		if t % 70 == 0:
			await _tap("attack")
		await physics_frame
		t += 1
	print("ERUPTION: agents %s after %.1f s; lieutenant %s, captain %s (spared)" % [_states(hf), t / 60.0,
			Guard.State.keys()[lieutenant.state], Guard.State.keys()[captain.state]])
	await _wait_story()
	await _skip()
	await _frames(5)
	var lf = level.get_node("LieutenantFight")
	print("LIEUTENANT: erupting %s, fight active %s, lieutenant %s %.0f hp" % [combat.erupting, lf.active,
			Guard.State.keys()[lieutenant.state], lieutenant.health])

	# 4. Kill the lieutenant: Valentina goes into the fire, the captain's fight starts.
	for i in 6:
		lieutenant.take_hit(22.0, player.global_position)
		await _frames(4)
	await _wait_story()
	await _skip()
	await _frames(5)
	var cf = level.get_node("CaptainFight")
	print("FIRE: lieutenant %s, Valentina hidden %s, captain fight active %s, captain %s %.0f hp, invulnerable %s" % [
			Guard.State.keys()[lieutenant.state], not level.get_node("Figures/ValentinaHall").visible, cf.active,
			Guard.State.keys()[captain.state], captain.health, captain.invulnerable])

	if OS.get_environment("HALL_DEATH") == "1":
		await _die_before_half(vf, hf, lf, cf, captain, hall_mark)
		return

	# 5. Hurt the captain past half: he stops playing.
	for i in 3:
		captain.take_hit(60.0, player.global_position)
		await _frames(3)
	await _wait_story()
	await _skip()
	await _frames(5)
	print("PHASE 2: captain invulnerable %s, unblockable %s, hp %.0f" % [captain.invulnerable, captain.data.unblockable, captain.health])

	# 6. Lose: the throat, Kael, the beheading, "Sacrificio" -> the Massacre.
	combat.take_hit(500.0, captain.global_position, true)
	await _wait_story()
	await _skip()
	await _frames(30)
	print("THROAT (mid-scene): %s" % notes.get("throat", "not seen"))
	print("KAEL (mid-scene): %s" % notes.get("kael", "not seen"))
	print("LOSS: current scene is now %s" % (current_scene.name if current_scene else "?"))
	quit()


## Die to the captain before half: back to the hall mark, the same fight again, everyone else down.
func _die_before_half(vf: Node, hf: Node, lf: Node, cf: Node, captain: Guard, hall_mark: Vector3) -> void:
	combat.take_hit(500.0, captain.global_position, true)
	for i in 300:  # the restart fade (~1.6 s) plus the 2.2 s before the fight restarts
		await physics_frame
	var down := "%s | %s | %s" % [_states(vf), _states(hf), _states(lf)]
	print("DEATH: Aeneas %.1f m from HallMark, health %.0f, controls %s" % [_flat(player.global_position, hall_mark), combat.health, player.controls_enabled])
	print("DEATH: others %s" % down)
	print("DEATH: captain %s, fight active %s, Valentina still gone %s" % [Guard.State.keys()[captain.state], cf.active, not level.get_node("Figures/ValentinaHall").visible])
	var ok: bool = _flat(player.global_position, hall_mark) < 1.5 and not ("PATROL" in down or "FIGHTING" in down) and cf.active
	print("HALL DEATH %s" % ("PASS" if ok else "FAIL"))
	quit()


## Notes taken while a scene is showing a given line.
func _observe(text: String) -> void:
	if "Another agent has Isabella" in text:
		var lt: Guard = level.get_node("LieutenantFight/Lieutenant")
		notes["captured"] = "Aeneas pose '%s', lieutenant pose '%s' %.2f m behind him (off the enemy layer %s), Isabella pose '%s', her captor pose '%s'" % [
				_pose(player), _pose(lt), _flat(lt.global_position, player.global_position), lt.collision_layer == 0,
				_pose(level.get_node("Figures/IsabellaHall")), _pose(level.get_node("Figures/IsabellaCaptor"))]
	elif "go in the fire with the rest" in text:
		var cap: Guard = level.get_node("CaptainFight/Captain")
		notes["throat"] = "captain pose '%s', Aeneas pose '%s', %.2f m apart" % [_pose(cap), _pose(player), _flat(cap.global_position, player.global_position)]
	elif "full of blood" in text:
		var cap: Guard = level.get_node("CaptainFight/Captain")
		var kael: Node3D = level.get_node("Figures/Kael")
		var arm := cap.find_child("Severable*", true, false) as Node3D
		notes["kael"] = "Kael shown %s pose '%s', captain arm gone %s, captain pose '%s', Aeneas pose '%s'" % [
				kael.visible, _pose(kael), arm != null and not arm.visible, _pose(cap), _pose(player)]


func _pose(n: Node) -> String:
	var a := StoryStage.animator_of(n)
	return a.story_playing() if a else "?"


func _walk_to(target: Vector3) -> void:
	var pivot: Node3D = player.get_node("CameraPivot")
	Input.action_press("move_forward")
	for i in 600:
		if story.playing:
			break
		var to: Vector3 = target - player.global_position
		to.y = 0.0
		if to.length() < 0.5:
			break
		pivot.rotation.y = atan2(-to.x, -to.z)
		await physics_frame
	Input.action_release("move_forward")


func _wait_story() -> void:
	for i in 300:
		if story.playing:
			return
		await physics_frame


func _skip() -> void:
	var presses := 0
	while story.playing and presses < 600:
		await _frames(6)
		if box.panel.visible and box.words.visible_characters == -1:
			print("   > %s%s" % [(box.speaker.text + ": ") if box.speaker.visible else "", box.words.text])
			_observe(box.words.text)
		Input.action_press("ui_accept")
		await process_frame
		await process_frame
		Input.action_release("ui_accept")
		await process_frame
		presses += 1
	await _frames(5)


func _states(fight: Node) -> String:
	var parts := []
	for guard in fight.get_children():
		if guard is Guard:
			parts.append("%s=%s" % [guard.name, Guard.State.keys()[guard.state]])
	return ", ".join(parts)


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
