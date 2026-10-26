class_name StorySkip
extends Node
## Skipping a story scene: Story's helper (a child of the Story autoload, story.gd).
## Hold Tab, or the gamepad's Back / Select / View button (the Stadia's three dots), for 0.7 s:
## the hint in the corner (ui/skip_hint.gd) fills its ring and calls begin(). The screen dips to
## black, the sound goes quiet, and the rest of the scene runs at once: lines, waits and titles
## are dropped, the stage directions jump to their end state (the way Continue replays a scene,
## story_replay.gd), and cameras, teleports, [hide] / [show], [call] and [heal] happen as written.
## It stops at a [fight] (a fight is never skipped) or at the scene's end, and the picture comes
## back. A [level] changes level as usual, behind the black screen. Look-ats can't be skipped.

const COVER := 0.25    ## seconds to black when a skip starts
const UNCOVER := 0.45  ## seconds back to the picture when it ends
const INK_LAND := 0.95 ## seconds after its stroke ends that an inked agent has dropped (guard.gd)

var active := false  ## a skip is fast-forwarding the playing scene
var story: Node      ## the Story autoload (story.gd)
var hint: SkipHint

var _token := 0                       # reset() bumps this: a skip still waiting gives up
var _covered := false
var _end_fade := Color(0, 0, 0, 0)    # what the scene's own fades leave on the screen
var _tween: Tween
var _muted := false
var _was_muted := false
var _inked: Array[Guard] = []         # agents the scene inked before a skip (their drop may be in flight)
var _ink_until := 0                   # ticks (ms) when the last of their drops has landed


## Story calls this once, from its _ready (after it made its dialogue box).
static func attach(to: Node) -> StorySkip:
	var skipper := StorySkip.new()
	skipper.name = "Skip"
	skipper.story = to
	to.add_child(skipper)
	return skipper


func _ready() -> void:
	hint = SkipHint.new()
	hint.name = "SkipHint"
	hint.can_skip = _can_skip
	hint.skip.connect(begin)
	story.get("_box").add_child(hint)


## Starts skipping the playing scene: whatever it waits on (a line, a wait, a fade, a title)
## lets go, and the scene's next step finds `active` set and comes to fast() instead.
func begin() -> void:
	if not _can_skip():
		return
	active = true
	_covered = false
	_end_fade = story.get("_fade_goal")
	for walk: Tween in StoryStage._walks.values().duplicate():  # [move] walks still under way
		if walk and walk.is_valid():
			walk.custom_step(3600.0)  # to the end, so they turn the way the marker faces
	story.get("_box").close()
	match story.get("_waiting_on"):
		"line":
			story.get("_box").advanced.emit()
		"wait":
			var timer: SceneTreeTimer = story.get("_wait_timer")
			if timer:
				timer.time_left = 0.0
		"fade":
			_finish_tween(story.get("_fade_tween"))
		"title":
			_finish_tween(story.get("_title_tween"))


## One step of a scene being skipped. True: it was done here, at once (or dropped). False: Story
## runs it as usual (they take no time: cameras, teleports, [place], [hide], [fight], [call]...).
func fast(step: Dictionary, find: Callable, player: Player) -> bool:
	if not _covered:
		_covered = true
		var token := _token
		_tween = create_tween()
		_tween.tween_property(story.get("_fade"), "color", Color(0, 0, 0, 1), COVER)
		await _tween.finished
		if token != _token:
			return true
		_mute(true)
		await settle()
		if token != _token:
			return true
	match step.type:
		"line", "wait", "title":
			return true
		"fade":
			_end_fade = Color(_end_fade.r, _end_fade.g, _end_fade.b, 0.0) if step.how == "in" \
					else Color(1, 1, 1, 1) if step.how == "white" \
					else Color(0, 0, 0, 0.6 if step.how == "dim" else 1.0)
			return true
		"move":
			var node: Node = find.call(step.name)
			var args: PackedStringArray = step.get("args", PackedStringArray())
			var goal: Node = find.call(args[0]) if args.size() > 0 else null
			if node is Node3D and goal is Node3D:
				StoryStage.put(node, goal.global_position, goal.global_rotation.y)  # where the walk ends
			return true
		"pose":
			if find.call(step.name) is Player:
				return false  # his poses play as usual (Continue never poses him)
			StoryReplay.apply(step, find, player)  # straight to its last frame
			return true
		"ink", "kill", "collapse":
			StoryReplay.apply(step, find, player)  # down at once, in the last frame of the fall
			return true
		"level":
			_end()  # stays black: Story changes level behind it
	return false


## Story ran an ink stroke as usual (no skip yet): remember when the agent will have dropped.
func note(step: Dictionary, find: Callable) -> void:
	if step.type != "ink":
		return
	var args: PackedStringArray = step.get("args", PackedStringArray())
	var agent: Node = find.call(args[0]) if args.size() > 0 else null
	if agent is Guard:
		_inked.append(agent as Guard)
		var lands := Time.get_ticks_msec() + int(((args[1].to_float() if args.size() > 1 else 0.3) + INK_LAND) * 1000.0)
		_ink_until = maxi(_ink_until, lands)


## Under the black screen, waits for ink drops still in flight to land, then lays those agents
## straight into the last frame of their fall.
## (Skipped on the last line, with the picture still up, they just finish falling.)
func settle() -> void:
	if not (active and _covered):
		_inked.clear()
		return
	var token := _token
	var left := (_ink_until - Time.get_ticks_msec()) / 1000.0
	if left > 0.0:
		await get_tree().create_timer(left, false).timeout
	if token != _token:
		return
	for agent in _inked:
		if is_instance_valid(agent) and agent.animator and agent.state == Guard.State.DOWN:
			agent.animator.die(true)
	_inked.clear()


## The skipped scene has reached its end: a physics step first, so the bodies it just moved are
## where it put them before Story gives the held agents their collision back (Jolt moves a
## teleported agent during the next step: one moved away from behind Aeneas in this frame would
## still shove him), then the picture comes back while he gets his controls.
func land() -> void:
	if _covered:
		await get_tree().physics_frame
		await get_tree().physics_frame  # (resumes before that frame's step: two make one full step)
	finish()


## The skip is over: sound back on, the picture fades back to what the scene left on screen.
func finish() -> void:
	if not active:
		return
	_end()
	var token := _token
	_tween = create_tween()
	_tween.tween_property(story.get("_fade"), "color", _end_fade, UNCOVER)
	await _tween.finished
	if token == _token:
		_tween = null


## A new scene, or Story.stop(): no skip, sound back, nothing left waiting. A fade back to the
## picture still under way finishes at once (a scene may start as the last one's skip uncovers).
func reset() -> void:
	_token += 1
	_finish_tween(_tween)
	_tween = null
	_end()
	_inked.clear()
	_ink_until = 0


func _end() -> void:
	active = false
	_covered = false
	_mute(false)


func _can_skip() -> bool:
	return story.get("playing") and not active and story.get("_scene_path") != "" \
			and not story.get("_waiting_on") in ["level", "end"]


## The SFX bus goes quiet while the scene races to its end, so its sounds don't all play at once.
## Its own mute (Settings: Effects at zero) is put back afterwards.
func _mute(on: bool) -> void:
	if on == _muted:
		return
	var bus := AudioServer.get_bus_index("SFX")
	if bus < 0:
		return
	if on:
		_was_muted = AudioServer.is_bus_mute(bus)
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, _was_muted)
	_muted = on


func _finish_tween(tween: Tween) -> void:
	if tween and tween.is_valid() and tween.is_running():
		tween.custom_step(60.0)
