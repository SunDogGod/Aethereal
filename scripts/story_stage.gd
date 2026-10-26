class_name StoryStage
extends RefCounted
## The stage directions of a dialogue scene: who stands where, which pose they play, who drops.
## Story (story.gd) hands every command it doesn't do itself to play(); Continue's fast-forward
## (story_replay.gd) hands the ones that change the level for good to replay().
##   [pose Name anim] / [pose Name]   a story pose (character_story.gd) / back to standing
##   [place Name Mark]                stand on a Marker3D, facing the way it faces
##   [stand Name Other 0.62]          0.62 m in front of Other, the two facing each other;
##                                    a minus number: that far BEHIND Other, facing the same way
##                                    (a hostage taker). Close up, an agent's body stops pushing
##                                    Aeneas until the scene ends (he still stands on the floor).
##   [move Name Mark 2.5]             walks there in 2.5 seconds (the scene goes on meanwhile)
##   [face Name Other]                turns to look at Other
##   [ink Name Agent 0.33]            Name's brush (Isabella) binds that agent: the stroke ends
##                                    0.33 s from now, the ink drop flies, he drops for good
##   [call Name method args...]       calls a method on the node (or its Animator if the node has
##                                    none): numbers, true/false and node names are converted.
##                                    Not replayed by Continue: follow it with a [hide] / [place]
##                                    that leaves the same result if it matters later.
##   [erupt on|off] [empower Name] [kill Name] [collapse Name] [heal] (older commands, same as before)

## Agents taken off the enemies' physics layer by a close [stand] (Aeneas's body would push them
## away), with the layer they had: put back when the scene ends.
static var _held := {}
## The [move] walks under way, by node: a later [place] / [stand] of the same node stops its walk.
static var _walks := {}


## Runs one command during a scene. `find` looks a node up by name the way Story does.
static func play(step: Dictionary, find: Callable, player: Player) -> void:
	var args: PackedStringArray = step.get("args", PackedStringArray())
	var node: Node = find.call(step.name) if step.has("name") else null
	match step.type:
		"erupt":
			if player:
				player.get_node("Combat").set_erupting(step.on)
		"empower":
			if node is Guard:
				node.empower()
		"collapse":
			if node:
				_collapse(node, false)
		"kill":
			if node is Guard:
				node.sacrifice()
		"heal":
			if player:
				player.get_node("Combat").heal_full()
		"pose":
			var anim := animator_of(node)
			if anim and args.size() > 0:
				if not anim.story_pose(args[0]):
					push_warning("Story: %s has no pose '%s'" % [step.name, args[0]])
			elif anim:
				anim.story_clear()
		"place":
			var mark: Node = find.call(args[0]) if args.size() > 0 else null
			if node is Node3D and mark is Node3D:
				put(node, mark.global_position, _yaw_of(mark))
		"stand":
			var other: Node = find.call(args[0]) if args.size() > 0 else null
			if node is Node3D and other is Node3D:
				var gap := args[1].to_float() if args.size() > 1 else 1.0
				stand(node, other, gap)
				if absf(gap) < 1.0:
					for n in [node, other]:
						_hold_body(n)
		"move":
			var goal: Node = find.call(args[0]) if args.size() > 0 else null
			if node is Node3D and goal is Node3D:
				walk(node, goal, args[1].to_float() if args.size() > 1 else 2.0)
		"face":
			var target: Node = find.call(args[0]) if args.size() > 0 else null
			if node is Node3D and target is Node3D:
				turn(node, _yaw_towards(node.global_position, target.global_position))
		"ink":
			var agent: Node = find.call(args[0]) if args.size() > 0 else null
			if node is Node3D and agent is Guard:
				ink(node, agent, args[1].to_float() if args.size() > 1 else 0.3)
		"call":
			if node and args.size() > 0:
				call_on(node, args[0], args.slice(1), find)


## The scene is over: agents held close for a pose block Aeneas again.
static func scene_ended() -> void:
	for g in _held.keys():
		if is_instance_valid(g):
			g.collision_layer = _held[g]
	_held.clear()


## Continue: the end state of a command, quietly (no sounds, no tweens). Aeneas is never moved
## here (the save puts him back itself), and agents already down stay where the save laid them.
static func replay(step: Dictionary, find: Callable, player: Player) -> void:
	var args: PackedStringArray = step.get("args", PackedStringArray())
	var node: Node = find.call(step.name) if step.has("name") else null
	if node == null or node is Player or (node is Guard and node.state == Guard.State.DOWN):
		return
	match step.type:
		"place", "stand", "face":
			play(step, find, player)
			scene_ended()  # no bodies held under the black screen
		"move":
			var goal: Node = find.call(args[0]) if args.size() > 0 else null
			if node is Node3D and goal is Node3D:
				put(node, goal.global_position, _yaw_towards(node.global_position, goal.global_position))
		"pose":
			var anim := animator_of(node)
			if anim == null:
				return
			if args.size() == 0:
				anim.story_clear(0.0)
			elif anim.story_pose(args[0], true, 0.0) and not _loops(anim, args[0]):
				anim.call("_play", "full", args[0], 40.0, true, 0.0)  # straight to its last frame
		"ink":
			var agent: Node = find.call(args[0]) if args.size() > 0 else null
			if agent is Guard and agent.state != Guard.State.DOWN:
				agent.sacrifice()
				if agent.animator:
					agent.animator.die(true)


## A character falls and stays down (its death animation). `instant`: straight to the last pose.
static func _collapse(node: Node, instant: bool) -> void:
	for n in [node] + node.find_children("*", "", true, false):
		if n.has_method("die") and not n is Guard:
			n.call("die", instant)
			break


## The node's CharacterAnimator (a guard's, Aeneas's, a figure's), or null.
static func animator_of(node: Node) -> CharacterAnimator:
	if node == null:
		return null
	if node is CharacterAnimator:
		return node
	var a: Variant = node.get("animator")
	if a is CharacterAnimator:
		return a
	for n in node.find_children("*", "CharacterAnimator", true, false):
		return n as CharacterAnimator
	return null


## Puts a character at a point, facing `yaw` (0 = looking down -Z). Aeneas goes through
## respawn_at (his fall checks start over there); an agent also waits there between fights.
static func put(node: Node3D, at: Vector3, yaw: float) -> void:
	_stop_walk(node)
	if node is Player:
		(node as Player).respawn_at(at)
	else:
		node.global_position = at
		if node is CharacterBody3D:
			(node as CharacterBody3D).velocity = Vector3.ZERO
	if node is Guard:
		node.set("_start_position", at)  # a restart in this fight puts him back here
	turn(node, yaw)


## Turns a character to face `yaw`: its Model turns (a guard keeps facing that way at his post).
static func turn(node: Node3D, yaw: float) -> void:
	var facer: Node3D = node.get("model") if node.get("model") is Node3D else node.get_node_or_null("Model")
	if facer == null:
		facer = node
	facer.global_rotation = Vector3(0.0, yaw, 0.0)
	if node is Guard:
		node.set("_start_facing", facer.rotation.y)


## `gap` > 0: node stands that far in front of `other`, turned to face it.
## `gap` < 0: node stands that far behind `other`, facing the same way.
static func stand(node: Node3D, other: Node3D, gap: float) -> void:
	var yaw := facing_of(other)
	var ahead := Vector3(-sin(yaw), 0.0, -cos(yaw))
	put(node, other.global_position + ahead * gap, yaw + (PI if gap > 0.0 else 0.0))


## Walks a character to a marker over `seconds` (its legs walk from the movement).
static func walk(node: Node3D, goal: Node3D, seconds: float) -> void:
	var to := goal.global_position
	_stop_walk(node)
	turn(node, _yaw_towards(node.global_position, to))
	var tween := node.create_tween()
	_walks[node.get_instance_id()] = tween
	tween.tween_property(node, "global_position", to, maxf(seconds, 0.05))
	tween.tween_callback(func() -> void:
		if node is Guard:
			node.set("_start_position", to)
		turn(node, _yaw_of(goal)))


## Isabella's ink, as in a takedown: her brush's stroke, the drop, the glyph, and he is down for good.
static func ink(who: Node3D, agent: Guard, seconds: float) -> void:
	var stroke := InkStroke.new()
	stroke.start = maxf(0.0, seconds - 0.22)
	stroke.finish = seconds
	stroke.brush = who.find_child("Brush", true, false)
	stroke.target = agent.ink_glyph.global_position
	who.add_child(stroke)
	agent.bind_with_ink(seconds + stroke.fly_time)
	agent.down_for_good = true


## [call Name method args]: on the node, or failing that on its Animator.
static func call_on(node: Node, method: String, raw: PackedStringArray, find: Callable) -> void:
	var target: Object = node
	if not node.has_method(method):
		target = animator_of(node)
	if target == null or not target.has_method(method):
		push_warning("Story: %s can't %s" % [node.name, method])
		return
	var values := []
	for a in raw:
		if a.is_valid_float():
			values.append(a.to_float())
		elif a in ["true", "false"]:
			values.append(a == "true")
		elif find.call(a) != null:
			values.append(find.call(a))
		else:
			values.append(a)
	target.callv(method, values)


## Which way a character looks (its Model's yaw), in world space.
static func facing_of(node: Node3D) -> float:
	var facer: Node3D = node.get("model") if node.get("model") is Node3D else node.get_node_or_null("Model")
	return (facer if facer else node).global_rotation.y


static func _yaw_of(mark: Node3D) -> float:
	return mark.global_rotation.y


static func _yaw_towards(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z) if Vector2(d.x, d.z).length() > 0.01 else 0.0


static func _stop_walk(node: Node) -> void:
	var tween: Tween = _walks.get(node.get_instance_id())
	if tween and tween.is_valid():
		tween.kill()
	_walks.erase(node.get_instance_id())


static func _hold_body(n: Node) -> void:
	if n is Guard and not _held.has(n):
		_held[n] = n.collision_layer
		n.collision_layer = 0


static func _loops(anim: CharacterAnimator, pose: String) -> bool:
	var player: AnimationPlayer = anim.get("_player")
	return player != null and player.has_animation(pose) and player.get_animation(pose).loop_mode != Animation.LOOP_NONE
