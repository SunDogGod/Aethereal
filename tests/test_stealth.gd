extends SceneTree
# Headless test of the sneaking: patrol, spotting + checkpoint restart, crouching range,
# solo takedown, paired takedown with Isabella (and her first-pair line), and a witnessed takedown without her.

var level: Node
var player: Player
var isabella: Companion
var pivot: Node3D
var guards := {}


func _initialize() -> void:
	_run()


func _run() -> void:
	level = load("res://scenes/levels/empty_town.tscn").instantiate()
	root.add_child(level)
	player = level.get_node("Player")
	isabella = level.get_node("Isabella")
	pivot = player.get_node("CameraPivot")
	for name in ["AgentEastDeck", "AgentPairEast", "AgentPairWest", "AgentAlley"]:
		guards[name] = level.get_node("Guards/" + name)
	await _frames(10)
	# The arrival scene plays as the level starts: read through it first.
	var story := root.get_node("Story")
	for i in 20:
		if not story.playing:
			break
		await _press("ui_accept")
		await _frames(30)
	print("SETUP: %d guards in group, companion linked: %s, round-up visible: %s" % [
			get_nodes_in_group("guards").size(), player.companion == isabella,
			level.get_node("Figures/RoundUp").visible])

	# 1. Patrol: the East-deck agent walks his route.
	var east: Guard = guards["AgentEastDeck"]
	var start := east.global_position
	await _frames(240)
	print("PATROL: East agent moved %.1f m in 4 s (state %s)" % [start.distance_to(east.global_position), Guard.State.keys()[east.state]])

	# 2. Checkpoint: walking into SneakStart sets the restart point and hides the round-up.
	await _put(Vector3(20, 24, 11))
	await _frames(10)
	print("CHECKPOINT: round-up visible after SneakStart: %s" % level.get_node("Figures/RoundUp").visible)

	# 3. Spotted standing in front of the pair's west agent, then restart at SneakStart.
	await _put(Vector3(-15, 8, -1.8))
	var west: Guard = guards["AgentPairWest"]
	var t := 0
	while west.state != Guard.State.SPOTTED and t < 300:
		await physics_frame
		t += 1
	print("SPOTTED: standing 4 m in front -> spotted after %.2f s" % (t / 60.0))
	await _frames(150)
	print("RESTART: Aeneas back at %s (SneakStart is (20, 24, 11)); west agent state %s, suspicion %.2f" % [
			_fmt(player.global_position), Guard.State.keys()[west.state], west.suspicion])

	# 4. Crouched beyond 7.7 m in front of the west agent: not spotted.
	await _put(Vector3(-10.5, 8, -1.0))
	await _crouch(true)
	await _frames(180)
	print("CROUCHED at 8.5 m: west agent suspicion %.2f, state %s" % [west.suspicion, Guard.State.keys()[west.state]])

	# 5. Paired takedown: crouched behind the pair's east agent, Isabella close behind.
	# The first time the paired prompt shows, Isabella's line plays (scene first_pair): read it.
	var east_pair: Guard = guards["AgentPairEast"]
	await _put(Vector3(-10.2, 8, -1.8))
	await _frames(30)
	var cue_played: bool = story.playing
	var cue_words := ""
	var box = story.get("_box")
	for i in 30:
		if not story.playing:
			break
		await _frames(20)
		if box.words.text != "":
			cue_words = "%s: %s" % [box.speaker.text, box.words.text]
		await _press("ui_accept")
	await _frames(10)
	print("PAIR CUE: scene played %s ('%s'), first_pair trigger done %s" % [cue_played, cue_words,
			level.get_node("StoryTriggers/FirstPair").get("_done")])
	var prompt := _prompt()
	_press("attack")
	await _frames(60)
	print("PAIRED: prompt was '%s'; east %s, west %s; Aeneas spotted: %s" % [prompt,
			Guard.State.keys()[east_pair.state], Guard.State.keys()[west.state], _any_spotted()])

	# 6. Checkpoint after the pair, then spotted: the pair stays down.
	await _crouch(false)
	await _put(Vector3(-18.5, 8, 1))
	await _frames(10)
	var alley: Guard = guards["AgentAlley"]
	await _put(alley.global_position - alley.model.global_basis.z * 3.0)  # 3 m in front of him
	t = 0
	while not _any_spotted() and t < 300:
		await physics_frame
		t += 1
	await _frames(150)
	print("KEPT DOWN: after restart at Alleys, pair east %s, pair west %s, Aeneas at %s" % [
			Guard.State.keys()[east_pair.state], Guard.State.keys()[west.state], _fmt(player.global_position)])

	# 7. Solo takedown from behind the alley agent.
	await _frames(30)
	var behind := alley.global_position + alley.model.global_basis.z * 1.2
	await _put(Vector3(behind.x, 8, behind.z))
	await _frames(2)
	prompt = _prompt()
	_press("attack")
	await _frames(60)
	print("SOLO: prompt was '%s'; alley agent %s" % [prompt, Guard.State.keys()[alley.state]])

	# 8. Witnessed with no Isabella: reset everything, unlink her, take down the east pair agent.
	for g: Guard in get_nodes_in_group("guards"):
		g.set("down_for_good", false)  # was _down_at_checkpoint (renamed with saving, 2026-10-26)
		g.reset_to_checkpoint()
	player.companion = null
	await _put(Vector3(-10.2, 8, -1.8))
	await _crouch(true)
	await _frames(30)
	prompt = _prompt()
	_press("attack")
	await _frames(20)
	print("WITNESSED: prompt was '%s'; west agent %s" % [prompt, Guard.State.keys()[west.state]])
	quit()


func _put(point: Vector3) -> void:
	player.respawn_at(point)
	await _frames(3)


func _crouch(on: bool) -> void:
	if player.is_crouched != on:
		_press("crouch")
		await _frames(30)


func _press(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


func _prompt() -> String:
	return player.get_node("Hud/Prompt").text if player.get_node("Hud/Prompt").visible else "(none)"


func _any_spotted() -> bool:
	for g: Guard in get_nodes_in_group("guards"):
		if g.state == Guard.State.SPOTTED:
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _fmt(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
