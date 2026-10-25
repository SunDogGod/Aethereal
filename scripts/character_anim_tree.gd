class_name CharacterAnimTree
extends RefCounted
## Builds the blend tree a CharacterAnimator plays (one tree per character, made in code):
##   stand: idle / walk / run / sprint blended by speed     crouch: crouch_idle / crouch_walk
##   crouch_mix -> rate (cycle speed) -> air_mix (jump / fall)
##   -> upper_mix: an upper-body action over the legs (only spine, arms, head)
##   -> full_mix: a whole-body action over everything -> output
## Parameters the animator sets: stand/crouch/air blend_position, *_mix blend_amount,
## rate / upper_rate / full_rate scale, upper / full transition_request.


static func build(player: AnimationPlayer, speeds: Dictionary, upper: Array, full: Array, upper_bones: Array) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("stand", _space(player, {"idle": 0.0, "walk": speeds.walk, "run": speeds.run, "sprint": speeds.sprint}, 0.0, speeds.sprint))
	bt.add_node("crouch", _space(player, {"crouch_idle": 0.0, "crouch_walk": speeds.crouch_walk}, 0.0, speeds.crouch_walk))
	bt.add_node("air", _space(player, {"fall": -1.0, "jump": 1.0}, -1.0, 1.0))
	for layer: String in ["upper", "full"]:
		var names: Array = (upper if layer == "upper" else full).filter(func(a: String) -> bool: return player.has_animation(a))
		bt.add_node(layer, _transition(names))
		for i in names.size():
			bt.add_node(layer + "_" + names[i], _clip(names[i]))
			bt.connect_node(layer, i, layer + "_" + names[i])
	for n: String in ["crouch_mix", "air_mix", "upper_mix", "full_mix"]:
		bt.add_node(n, AnimationNodeBlend2.new())
	for n: String in ["rate", "upper_rate", "full_rate"]:
		bt.add_node(n, AnimationNodeTimeScale.new())
	for link: Array in [["crouch_mix", 0, "stand"], ["crouch_mix", 1, "crouch"], ["rate", 0, "crouch_mix"],
			["air_mix", 0, "rate"], ["air_mix", 1, "air"], ["upper_rate", 0, "upper"], ["upper_mix", 0, "air_mix"],
			["upper_mix", 1, "upper_rate"], ["full_rate", 0, "full"], ["full_mix", 0, "upper_mix"],
			["full_mix", 1, "full_rate"], ["output", 0, "full_mix"]]:
		bt.connect_node(link[0], link[1], link[2])
	# The upper layer only moves the spine, arms and head (the legs keep walking).
	var upper_mix: AnimationNodeBlend2 = bt.get_node("upper_mix")
	upper_mix.filter_enabled = true
	var idle := player.get_animation("idle")
	for i in idle.get_track_count():
		var path := idle.track_get_path(i)
		if path.get_subname_count() > 0 and path.get_subname(0) in upper_bones:
			upper_mix.set_filter_path(path, true)
	return bt


static func _clip(anim: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = anim
	return a


static func _space(player: AnimationPlayer, points: Dictionary, lo: float, hi: float) -> AnimationNodeBlendSpace1D:
	var bs := AnimationNodeBlendSpace1D.new()
	bs.min_space = lo
	bs.max_space = hi
	bs.sync = true  # the cycles share a length, so blended feet stay in step
	for anim: String in points:
		if player.has_animation(anim):
			bs.add_blend_point(_clip(anim), points[anim], -1, anim)
	return bs


static func _transition(names: Array) -> AnimationNodeTransition:
	var t := AnimationNodeTransition.new()
	t.xfade_time = 0.05
	t.allow_transition_to_self = true  # the same swing twice restarts it
	t.input_count = names.size()
	for i in names.size():
		t.set_input_name(i, names[i])
		t.set_input_reset(i, true)
	return t
