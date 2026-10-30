extends SceneTree
# Skipping a story scene ends in the same state as playing it through.
# For each Empty Town scene: load a fresh town, play the scene to its end by pressing "advance"
# (the full run), snapshot; load a fresh town again, play the scene, advance `k` lines, then HOLD
# the skip button (skip_cutscene) like a player, snapshot; compare.
# Saves go to a scratch folder. Run headless (no frame capture here).

const ME := "C:/Users/ArmandoSanchez/Documents/Aethereal 3D Godot/aethereal-3d/tests/batch9/sound-skip"
const TOWN := "res://scenes/levels/empty_town.tscn"
const FILE := "res://data/dialogue/empty_town.txt"
const SPEED := 3.0

# [scene, lines to advance before the skip, extra game seconds to wait before holding]
var CASES := [
	["arrival", 0, 0.5],
	["kael_meeting", 1, 0.3],
	["round_up", 0, 0.5],
	["valentina", 0, 1.0],
	["captured", 0, 0.4],
	["captured", 11, 0.5],   # skip while Isabella's ink is still in flight
	["valentina_fire", 0, 1.2],
	["captain_throat", 2, 0.2],
]

var story: Node
var town: PackedScene
var _advances := 0
var _fails := 0


func _initialize() -> void:
	var limit := OS.get_environment("SKIP_WATCHDOG").to_float()
	create_timer(limit if limit > 0.0 else 280.0, true, false, true).timeout.connect(func() -> void:
		print("WATCHDOG: quitting")
		quit(1))
	_run()


func _run() -> void:
	await process_frame  # the autoloads' _ready
	story = root.get_node("Story")
	SaveGame.folder = ME + "/saves"
	DirAccess.make_dir_recursive_absolute(SaveGame.folder)
	story.get("_box").advanced.connect(func() -> void: _advances += 1)
	town = load(TOWN)
	Engine.time_scale = SPEED
	var only := OS.get_environment("SKIP_ONLY")
	for c: Array in CASES:
		if only != "" and not only.split(",").has(c[0]):
			continue
		var full := await _play(c[0], -1, 0.0)
		var skipped := await _play(c[0], c[1], c[2])
		_compare("%s (skip after %d lines)" % [c[0], c[1]], full, skipped)
	print("SKIP TEST DONE: %d case(s) with differences" % _fails)
	Engine.time_scale = 1.0
	quit()


## Plays `scene` in a fresh town. skip_after < 0: through to the end. Returns the end-state snapshot.
func _play(scene: String, skip_after: int, delay: float) -> Dictionary:
	if story.playing:
		story.stop()
		await _frames(2)
	if current_scene:
		var old := current_scene
		current_scene = null
		old.queue_free()
		await _frames(3)
	var level: Node = town.instantiate()
	var triggers := level.get_node_or_null("StoryTriggers")
	if triggers:
		level.remove_child(triggers)
		triggers.free()  # only the scene under test plays
	root.add_child(level)
	current_scene = level
	await _frames(20)
	_advances = 0
	var started_ms := Time.get_ticks_msec()
	story.play(FILE, scene)
	var held := false
	var skip_ms := -1
	var guard := 0
	while story.playing and guard < 20000:
		guard += 1
		if current_scene != level:
			break  # the scene took us to another level, whose own opening may start at once
		if skip_after >= 0 and not held and _advances >= skip_after:
			await _seconds(delay)
			if not story.playing:
				break
			await process_frame  # (a timer fires after the nodes' _process: press at the frame's start)
			Input.action_press("skip_cutscene")
			var t0 := Time.get_ticks_msec()
			while not story.get("_skipper").active and story.playing and Time.get_ticks_msec() - t0 < 3000:
				await process_frame
			skip_ms = Time.get_ticks_msec() - t0
			Input.action_release("skip_cutscene")
			held = true
			continue
		if skip_after >= 0 and held:
			await process_frame  # a skip runs by itself: no presses
			continue
		Input.action_press("ui_accept")
		await process_frame
		await process_frame
		Input.action_release("ui_accept")
		await process_frame
	var took := (Time.get_ticks_msec() - started_ms) / 1000.0 * SPEED
	if OS.get_environment("SKIP_DEBUG") != "":
		var pl := get_first_node_in_group("player") as Node3D
		print("  [%s k=%d] at end: player %s, captain %s" % [scene, skip_after, pl.global_position, current_scene.find_child("Captain", true, false).global_position])
	if current_scene != level:  # a new level: let its fade-in finish (its load time varies)
		var t0 := Time.get_ticks_msec()
		while story.get("_fade").color.a > 0.01 and Time.get_ticks_msec() - t0 < 4000:
			await process_frame
	await _seconds(0.8)  # the picture back, ink drops landed
	var snap := _snapshot(scene)
	snap["_took"] = "%.1f game s" % took
	if skip_after >= 0:
		snap["_hold"] = "%d ms real (%.2f game s)" % [skip_ms, skip_ms / 1000.0 * SPEED]
	return snap


func _snapshot(scene: String) -> Dictionary:
	var s := {}
	var level := current_scene
	s["level"] = level.scene_file_path.get_file() if level else "?"
	var cam := root.get_viewport().get_camera_3d()
	s["camera"] = str(cam.name) if cam else "-"
	s["fade_a"] = snappedf(story.get("_fade").color.a, 0.05)
	s["playing"] = story.playing
	s["letterbox"] = snappedf(story.get("_box").get_node("BarTop").offset_bottom, 1.0)
	s["box_open"] = story.get("_box").get_node("Panel").visible
	var bus := AudioServer.get_bus_index("SFX")
	s["sfx_muted"] = AudioServer.is_bus_mute(bus) if bus >= 0 else "no bus"
	var player := get_first_node_in_group("player") as Player
	if player:
		s["player.pos"] = _v(player.global_position)
		s["player.controls"] = player.controls_enabled
		s["player.cutscene"] = player.in_cutscene
		s["player.erupting"] = player.get_node("Combat").get("erupting")
		var pa := StoryStage.animator_of(player)
		s["player.pose"] = pa.story_playing() if pa else "-"
	s["fights"] = story.last_started_fights.map(func(f: Node) -> String: return str(f.name) if is_instance_valid(f) else "freed")
	if s["level"] != TOWN.get_file():
		return s
	var names := {}
	var steps: Array = DialogueFile.parse(FileAccess.get_file_as_string(FILE)).get(scene, [])
	for step: Dictionary in steps:
		if step.has("name") and step.type in ["hide", "show", "place", "stand", "move", "face", "pose", "ink", "kill", "collapse", "empower", "call"]:
			names[step.name] = true
			for a in step.get("args", []):
				if level.find_child(a, true, false) is Node3D and not level.find_child(a, true, false) is Camera3D:
					names[a] = true
	for n: String in names:
		var node := level.find_child(n, true, false)
		if not node is Node3D or node is Player or node is Marker3D:
			continue
		var key := n
		s[key + ".visible"] = node.is_visible_in_tree()
		if not node.is_visible_in_tree():
			continue  # hidden (thrown on the fire, say): where it lies can't be seen
		s[key + ".pos"] = _v(node.global_position)
		var anim := StoryStage.animator_of(node)
		if anim:
			s[key + ".pose"] = anim.story_playing()
			s[key + ".dead"] = anim.get("dead")
			s[key + ".yaw"] = snappedf(StoryStage.facing_of(node), 0.1)
		if node is Guard:
			s[key + ".state"] = Guard.State.keys()[node.state]
			s[key + ".down_for_good"] = node.down_for_good
	return s


func _compare(label: String, a: Dictionary, b: Dictionary) -> void:
	var diffs := []
	for k in a:
		if k.begins_with("_"):
			continue
		var same: bool = str(a[k]) == str(b.get(k))
		if a[k] is Vector3 and b.get(k) is Vector3:
			# An agent (it has a .state) drifts a little on his own: nudged apart by the others
			# (Guard._separate), or already fighting. Others must land where the scene put them.
			var tolerance := 0.6 if a.has(k.trim_suffix(".pos") + ".state") else 0.15
			same = a[k].distance_to(b[k]) < tolerance
		if k.ends_with(".yaw") and b.get(k) is float:
			same = absf(angle_difference(a[k], b[k])) < 0.15  # 3.1 and -3.1 face the same way
		if k == "fade_a" and b.get(k) is float:
			same = absf(a[k] - b[k]) <= 0.1  # the next level's fade-in, caught a frame apart
		if not same:
			diffs.append("    %s: full %s | skip %s" % [k, a[k], b.get(k)])
	for k in b:
		if not a.has(k) and not k.begins_with("_"):
			diffs.append("    %s: only in skip (%s)" % [k, b[k]])
	print("CASE %s: full took %s, skip took %s, hold %s -> %s" % [label, a.get("_took"), b.get("_took"),
			b.get("_hold"), "SAME" if diffs.is_empty() else "%d DIFF(S)" % diffs.size()])
	print("    end: level %s, camera %s, fade %s, letterbox %s, box %s, sfx muted %s, controls %s, fights %s" % [
			b.get("level"), b.get("camera"), b.get("fade_a"), b.get("letterbox"), b.get("box_open"),
			b.get("sfx_muted"), b.get("player.controls"), b.get("fights")])
	for d in diffs:
		print(d)
	if not diffs.is_empty():
		_fails += 1


func _v(p: Vector3) -> Vector3:
	return p.snapped(Vector3.ONE * 0.01)


func _seconds(game_seconds: float) -> void:
	if game_seconds > 0.0:
		await create_timer(game_seconds).timeout


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
