extends SceneTree
# Headless: the captain's choreographed fight. Logs every beat he plays (must follow
# data/fights/captain.txt), the scene beats, his blows on Aeneas, a parry mid-sequence, the
# switch to phase 2 after the lieutenant scene, and the loss.

var level: Node
var player: Player
var combat: PlayerCombat
var story: Node
var t := 0.0


func _initialize() -> void:
	_run()


func _run() -> void:
	story = root.get_node("Story")
	level = load("res://scenes/levels/empty_town.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	combat = player.get_node("Combat")
	await _frames(20)
	await _skip_story()
	var cf = level.get_node("CaptainFight")
	var captain: Guard = cf.get_node("Captain")
	var lieutenant = cf.get_node_or_null("Lieutenant")  # since 2026-10-26 he has his own fight
	player.respawn_at(Vector3(0, 0, -17.5))
	await _frames(5)
	cf.start()
	await _frames(2)
	var ch = captain.fighter.choreography
	print("SETUP: captain choreographed %s, lieutenant choreographed %s" % [ch != null, lieutenant != null and lieutenant.fighter.choreography != null])
	var last := ""
	var scenes := []
	var blows := 0
	var parried := false
	var stagger_seen := false
	var after_stagger := ""
	var phase2_beats := []
	var died_at := -1.0
	var hp := combat.health
	for frame in 60 * 60:
		t = frame / 60.0
		if not is_instance_valid(captain):
			break  # the loss moved on to the Massacre
		var phase2 := captain.invulnerable
		if frame < 60 * 24 and combat.health > 0.0:
			if combat.health < hp:
				blows += 1
			combat.health = 1000.0
			hp = 1000.0
		elif combat.health < hp:
			blows += 1
			hp = combat.health
		ch = captain.fighter.choreography
		var beat := ""
		if ch and not ch._beat.is_empty():
			beat = "%s#%d(%s)" % [ch._beat.move, ch._index, " ".join(ch._beat.args)]
		if beat != last:
			print("t=%5.2f  P%d  %s  dist %.1f" % [t, ch._phase if ch else 0, beat, captain.global_position.distance_to(player.global_position)])
			if stagger_seen and after_stagger == "":
				after_stagger = beat
			if phase2:
				phase2_beats.append(beat)
			last = beat
		if story.playing:
			var cam := root.get_viewport().get_camera_3d()
			if cam and not (cam.name in scenes):
				scenes.append(cam.name)
		# A parry: in phase 1's second loop pass, block just before a plain swing lands.
		if not parried and not phase2 and t > 6.0 and ch and ch._beat.move == "swing" and ch._stage == "windup" and ch._t >= ch._windup - 0.1:
			player.face(captain.global_position)
			Input.action_press("block")
			await physics_frame
			Input.action_release("block")
			parried = true
			await _frames(14)
			print("PARRY at t=%.2f: captain %s" % [t, Guard.State.keys()[captain.state]])
			stagger_seen = captain.state == Guard.State.STAGGERED
		# Past 24 s, cut the captain under half: the lieutenant scene, then phase 2.
		if frame == 60 * 24:
			for i in 3:
				captain.take_hit(60.0, player.global_position)
			combat.heal_full()
			hp = combat.health
		if story.playing:
			Input.action_press("ui_accept")
			await process_frame
			Input.action_release("ui_accept")
		if combat.health <= 0.0 and died_at < 0.0:
			died_at = t
		if current_scene and current_scene.name == "Massacre":
			break
		await physics_frame
	print("SCENE CAMERAS SEEN: %s" % [scenes])
	print("BLOWS on Aeneas: %d; parried %s, captain staggered %s, next beat after stagger %s" % [blows, parried, stagger_seen, after_stagger])
	print("PHASE 2: beats %s" % [phase2_beats.slice(0, 8)])
	print("LOSS: Aeneas died at %.1f s; scene now %s" % [died_at, current_scene.name if current_scene else "?"])
	var ok: bool = blows > 2 and stagger_seen and "StoryFrameShot" in scenes and phase2_beats.size() > 2 and current_scene and current_scene.name == "Massacre"
	print("CHOREO %s" % ("PASS" if ok else "FAIL"))
	quit()


func _skip_story() -> void:
	for i in 400:
		if not story.playing:
			return
		Input.action_press("ui_accept")
		await process_frame
		await process_frame
		Input.action_release("ui_accept")
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
