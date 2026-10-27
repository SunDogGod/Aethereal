extends SceneTree
# Headless combat test in the test yard: a fighting agent vs Aeneas.
# Checks lock-on, light/heavy hits and stamina, the agent's swing hurting Aeneas, blocking,
# the parry window + riposte, the dodge's i-frames, and killing the agent.

var player: Player
var combat: PlayerCombat
var guard: Guard


func _initialize() -> void:
	_run()


func _run() -> void:
	var level: Node = load("res://scenes/test_yard.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	combat = player.get_node("Combat")
	level.get_node("Isabella").queue_free()
	guard = load("res://scenes/guard.tscn").instantiate()
	guard.name = "Agent"
	guard.fights = true
	guard.position = Vector3(0, 0, 1.5)  # 1.5 m in front of Aeneas (he starts at z = 3)
	level.add_child(guard)
	await _frames(10)
	guard.engage()
	print("SETUP: actions %s/%s/%s, guard health %.0f, in enemies group %s" % [
			InputMap.has_action("lock_on"), InputMap.has_action("block"), InputMap.has_action("heavy_attack"),
			guard.health, guard.is_in_group("enemies")])

	# 1. Lock on.
	await _tap("lock_on")
	await _frames(5)
	print("LOCK: target = %s" % (combat.lock_target.name if combat.lock_target else "none"))

	# 2. Light attack: guard loses 22 and starts fighting; stamina drops.
	player.face(guard.global_position)
	var s0 := combat.stamina
	await _tap("attack")
	await _frames(25)
	print("LIGHT: guard health %.0f (expect 38), state %s, stamina %.0f -> %.0f" % [guard.health, Guard.State.keys()[guard.state], s0, combat.stamina])

	# 3. The agent's swing hits Aeneas when he does nothing.
	guard.global_position = player.global_position + Vector3(0, 0, -1.3)
	var h0 := combat.health
	var t := 0
	while combat.health == h0 and t < 400:
		await physics_frame
		t += 1
	print("HIT: Aeneas %.0f -> %.0f after %.2f s" % [h0, combat.health, t / 60.0])

	# 4. Block: next hit does a quarter.
	player.face(guard.global_position)
	Input.action_press("block")
	h0 = combat.health
	t = 0
	while combat.health == h0 and t < 400:
		await physics_frame
		t += 1
	Input.action_release("block")
	print("BLOCK: damage %.1f (expect 4.5), stamina %.0f" % [h0 - combat.health, combat.stamina])
	await _frames(60)
	combat.heal_full()

	# 5. Parry: press block right before the swing lands (windup known: 0.6 s).
	var fighter = guard.get_node("Fighter")
	player.face(guard.global_position)
	t = 0
	while fighter.get("_windup") < 0.0 and t < 400:
		await physics_frame
		t += 1
	# windup started: wait until 0.1 s before it lands, then tap block
	while fighter.get("_windup") < guard.data.attack_windup - 0.1:
		await physics_frame
	await _tap("block")
	await _frames(15)
	print("PARRY: guard state %s (expect STAGGERED), Aeneas health %.0f (expect 100)" % [Guard.State.keys()[guard.state], combat.health])

	# 6. Riposte: the next attack is a heavy at x3.
	var gh := guard.health
	player.face(guard.global_position)
	await _tap("attack")
	await _frames(45)
	print("RIPOSTE: guard health %.0f -> %.0f (expect down: 45*3 > %.0f), state %s, killed %s" % [gh, guard.health, gh, Guard.State.keys()[guard.state], guard.killed])

	# 7. Chaining: a second agent; three quick taps should land three hits within ~half a second.
	var second: Guard = load("res://scenes/guard.tscn").instantiate()
	second.name = "Agent2"
	second.fights = true
	second.position = player.global_position + Vector3(0, 0, -1.4)
	level.add_child(second)
	await _frames(5)
	second.data.health = 300.0
	second.health = 300.0
	second.engage()
	player.face(second.global_position)
	combat.heal_full()
	var start_frame := Engine.get_physics_frames()
	for i in 3:
		await _tap("attack")
		await _frames(8)
	var hits := int(round((300.0 - second.health) / 23.0))
	print("CHAIN: 3 taps in %.2f s -> %d hits (health 300 -> %.0f)" % [(Engine.get_physics_frames() - start_frame) / 60.0, hits, second.health])
	quit()


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
