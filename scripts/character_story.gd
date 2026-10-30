class_name CharacterStory
extends CharacterAnimLayers
## Story poses: what a cutscene makes a character do, by name, and the props that change with
## them. CharacterAnimator (character_animator.gd) is built on this, so every model's "Animator"
## has these calls. The poses are made in tools/blender (anims_story.py for everyone,
## anims_agency.py, isabella_anims.py, captain_anims.py / captain_story.py, kael_anims.py).
##   story_pose("hostage")       play a pose; it holds its last frame (or keeps looping) until
##   story_clear()               ...this lets him go back to standing and walking
## Grabs: captor_grab(_low) and hostage_grabbed play once and go on by themselves into captor_knife(_low)
## and hostage (CHAIN), so [pose Lieutenant captor_grab] alone ends in the held loop.
## Props: the agents' knife is in hand during captor_knife; Kael's Lamento leaves his back during
## draw_lamento (set_lamento for a cut straight to it drawn or bloody); the captain loses his arm
## with set_arm_severed(true); attach() / detach() carry a body (or Valentina) in a hand.

## Whole-body poses. Loops: hostage, captive, held_by_throat, captor_knife(_low), hold_throat.
## captor_grab, captor_grab_low and hostage_grabbed run into their loops (CHAIN).
const STORY := ["hostage", "hostage_grabbed", "drop_to_knees", "captive", "limp", "lifted_by_throat", "held_by_throat",
		"captor_knife", "captor_knife_low", "captor_grab", "captor_grab_low", "heave_body",
		"break_free", "lunge", "stabbed", "stagger_back", "kneel_draw", "collapse",
		"spear_hand", "lift_throat", "hold_throat", "arm_severed", "throw_one_arm",
		"draw_lamento", "sever_cut", "behead_cut", "bloody_stand",
		"lean_look", "reach"]  ## The Grey (dream): lean_look, reach (tools/blender/grey_alien_anims.py)
## Upper-body poses: the legs keep walking under them while the scene moves the body.
const STORY_UPPER := ["dragged", "drag_by_arm"]
const KNIFE_POSES := ["captor_knife", "captor_knife_low"]
## A pose that plays once and goes straight on into another (held) when it ends.
const CHAIN := {"captor_grab": "captor_knife", "captor_grab_low": "captor_knife_low", "hostage_grabbed": "hostage"}
const GRAB_DRAW := 0.30      ## captor_grab: the knife leaves its sheath for his left hand (anims_agency.py)
## A pose this character lacks, played as another: [pose Player collapse] = his death fall.
const FALLBACK := {"collapse": "death"}
const HIDE_DURING := {"heave_body": ["Blade"], "throw_one_arm": []}
const LAMENTO_SWAP := 0.32   ## draw_lamento: his hand closes on the grip behind his shoulder (kael_anims.py)
const HEAVE_RELEASE := 1.05  ## heave_body: the body leaves the agent's hands (anims_agency.py)

var _hidden: Array[Node3D] = []
var _lamento_drawn := false


func _setup_story(model: Node) -> void:
	# Props that start put away: Kael's drawn Lamento, the captain's stump.
	set_lamento(false)
	for n: Node3D in _named(model, "Stump"):
		n.visible = false


func _extra(layer: String) -> Array:
	return STORY_UPPER if layer == "upper" else STORY


## Plays a story pose. Returns false if this character has no such pose (nothing changes).
## `hold`: stay in it (a loop keeps looping) until story_clear() or another pose.
## A character without its own "collapse" (only Isabella has one) falls with his death animation.
func story_pose(anim: String, hold := true, fade := 0.2) -> bool:
	if _player != null and not _player.has_animation(anim) and FALLBACK.has(anim):
		anim = FALLBACK[anim]
	if _player == null or not _player.has_animation(anim):
		return false
	_show_hidden()
	var key := "upper" if anim in STORY_UPPER else "full"
	_play(key, anim, 1.0, hold, fade)
	var other := "full" if key == "upper" else "upper"
	if key == "full" or playing(other) in STORY:
		_stop(other, fade)  # one story pose at a time (a whole-body one also ends any upper-body action)
	for prop_name: String in HIDE_DURING.get(anim, []):
		var n := get_parent().get_node_or_null(prop_name) as Node3D
		if n and n.visible:
			n.visible = false
			_hidden.append(n)
	return true


## Ends a story pose: he eases back to standing (and walking, if his body moves).
func story_clear(fade := 0.3) -> void:
	for key: String in ["full", "upper"]:
		if playing(key) in STORY or playing(key) in STORY_UPPER:
			_stop(key, fade)
	_show_hidden()


## The story pose playing ("" when none; one fading out doesn't count).
func story_playing() -> String:
	for key: String in ["full", "upper"]:
		if _layers[key].target > 0.0 and (playing(key) in STORY or playing(key) in STORY_UPPER):
			return playing(key)
	return ""


func has_story_pose(anim: String) -> bool:
	return _player != null and _player.has_animation(anim)


## Seconds a pose takes (a loop: one cycle). 0 if he has none.
func story_length(anim: String) -> float:
	return _player.get_animation(anim).length if has_story_pose(anim) else 0.0


## The captain's arm, cut off above the elbow: the arm's meshes ("Severable") go, the bound
## stump ("Stump") shows. The cut itself is staged by the scene (a cut-away).
func set_arm_severed(on: bool) -> void:
	for n: Node3D in _named(get_parent(), "Severable"):
		n.visible = not on
	for n: Node3D in _named(get_parent(), "Stump"):
		n.visible = on


## Kael: Lamento on his back (drawn false) or in his hand; `bloody` shows the blade after the cuts.
func set_lamento(drawn: bool, bloody := false) -> void:
	_lamento_drawn = drawn
	var model := get_parent()
	var back := model.get_node_or_null("Lamento") as Node3D
	var hand := model.get_node_or_null("LamentoDrawn") as Node3D
	if back == null or hand == null:
		return
	back.visible = not drawn
	hand.visible = drawn
	for mesh: Node3D in hand.get_children():
		mesh.visible = (mesh.name == "LamentoBlood") == bloody


## Carries `node` (a wrapped body, Valentina) in a hand from where it is now: it follows the
## bone ("Weapon_R" the right hand, "Weapon_L" the left: the captain's) until detach().
func attach(node: Node3D, bone := "Weapon_R") -> void:
	var skeleton := get_parent().find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or skeleton.find_bone(bone) < 0:
		return
	var att := BoneAttachment3D.new()
	att.name = "Carrying"
	skeleton.add_child(att)
	att.bone_name = bone
	att.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone))
	node.reparent(att, true)


## Lets go of a carried node where it is, under `parent` (default: the character's own parent).
func detach(node: Node3D, parent: Node = null) -> void:
	var att := node.get_parent()
	if not att is BoneAttachment3D:
		return
	if parent == null:
		parent = get_parent().get_parent().get_parent()  # the model > the character > where he stands
	node.reparent(parent, true)
	if att.get_child_count() == 0 and att.name.begins_with("Carrying"):
		att.queue_free()


func _knife_in_hand() -> bool:
	var l: Dictionary = _layers.full
	if l.anim == "captor_grab" or l.anim == "captor_grab_low":
		return l.time * _tree.get("parameters/full_rate/scale") >= GRAB_DRAW
	return super() or l.anim in KNIFE_POSES


func _step_story_props() -> void:
	if not _hidden.is_empty() and story_playing() == "":
		_show_hidden()  # a pose that ended by itself (not held)
	var l: Dictionary = _layers.full
	if CHAIN.has(l.anim) and l.hold and l.target > 0.0 and l.time >= l.length:
		story_pose(CHAIN[l.anim], true, 0.0)  # a grab ends on the held loop's first frame
		return
	if l.anim == "draw_lamento" and l.target > 0.0 and not _lamento_drawn and l.time >= LAMENTO_SWAP:
		set_lamento(true)


func _show_hidden() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()


static func _named(model: Node, prefix: String) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for n: Node in model.find_children(prefix + "*", "Node3D", true, false):
		found.append(n as Node3D)
	return found
