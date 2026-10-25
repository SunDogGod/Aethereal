class_name CharacterAnimLayers
extends Node
## The machinery under CharacterAnimator (character_animator.gd, which says what plays when):
## the blend tree and its two action layers with their fades, and the props that change place
## during actions: the knife (sheath -> left hand in a stab) and Aeneas's sword (scabbard at his
## left hip <-> right hand).
## Layers: the legs walk; an upper-body layer (wind-ups, block, sheathe...) plays over them; a
## whole-body layer (cuts, the draw, rolls, deaths) plays over everything.

const UPPER_BONES := ["Spine", "Chest", "Neck", "Head", "Shoulder_L", "Shoulder_R", "UpperArm_L",
		"UpperArm_R", "LowerArm_L", "LowerArm_R", "Hand_L", "Hand_R", "Weapon_L", "Weapon_R", "Back", "Scabbard"]
const UPPER := ["windup_L", "windup_R", "block", "telegraph", "cast", "sheathe"]
const FULL := ["sweep_LR", "sweep_RL", "dodge_roll", "dodge_back", "hit", "stab", "death", "strike", "stagger",
		"iai", "draw_cut"]
const LOOPS := ["idle", "walk", "run", "sprint", "crouch_idle", "crouch_walk", "fall"]
const STAB_DRAW := 0.13     ## in the stab, the knife leaves its sheath for the left hand...
const STAB_SHEATHE := 0.64  ## ...and goes back
const SHEATHE_HOME := 0.50  ## in "sheathe" the blade is home in the scabbard (tools/blender/aeneas_anims.py)
const CARRY_FADE := 0.2     ## seconds to blend between the sword-drawn and sword-sheathed walks

## True for a character that carries a sheathed sword (it has "*_sheathed" cycles, a "Sword"
## attachment and a visible "Scabbard"): Aeneas. Everyone else always has the sword in hand.
var has_carry := false
var sword_in_hand := true

var _player: AnimationPlayer
var _tree: AnimationTree
var _knife: BoneAttachment3D
var _knife_home := ""
var _sword: BoneAttachment3D
var _carry := 0.0
var _layers := {
	"upper": {"anim": "", "time": 0.0, "length": 0.0, "hold": false, "amount": 0.0, "target": 0.0, "fade": 0.1},
	"full": {"anim": "", "time": 0.0, "length": 0.0, "hold": false, "amount": 0.0, "target": 0.0, "fade": 0.1},
}


func _setup_layers(model: Node, speeds: Dictionary) -> void:
	_player = model.find_child("AnimationPlayer", true, false)
	_knife = model.get_node_or_null("Knife") as BoneAttachment3D
	if _knife:
		_knife_home = _knife.bone_name
	_sword = model.get_node_or_null("Sword") as BoneAttachment3D
	var scabbard := model.get_node_or_null("Scabbard") as Node3D
	if _player == null:
		return
	has_carry = _player.has_animation("walk_sheathed") and _sword != null and scabbard != null and scabbard.visible
	_build_tree(speeds)
	if has_carry:
		put_sword(false)
		_carry = 1.0


## Moves the sword between his right hand and the scabbard (it changes which bone it rides).
func put_sword(in_hand: bool) -> void:
	if not has_carry:
		return
	sword_in_hand = in_hand
	_sword.bone_name = "Weapon_R" if in_hand else "Scabbard"


func _step_props(delta: float) -> void:
	if has_carry:
		# A sheathe that reaches the point where the blade is home leaves it in the scabbard;
		# one cut short (he attacked, blocked, rolled, was hit) leaves it in his hand.
		var up: Dictionary = _layers.upper
		if up.anim == "sheathe" and up.target > 0.0 and sword_in_hand and up.time >= SHEATHE_HOME:
			put_sword(false)
		_carry = move_toward(_carry, 0.0 if sword_in_hand else 1.0, delta / CARRY_FADE)
		_tree.set("parameters/carry_mix/blend_amount", _carry)
	if _knife:
		var l: Dictionary = _layers.full
		var t: float = l.time * _tree.get("parameters/full_rate/scale")
		var bone := "Weapon_L" if l.anim == "stab" and t >= STAB_DRAW and t < STAB_SHEATHE else _knife_home
		if _knife.bone_name != bone:
			_knife.bone_name = bone


func _step_layer(key: String, delta: float) -> void:
	var l: Dictionary = _layers[key]
	l.time += delta
	if not l.hold and l.anim != "" and l.time >= l.length:
		l.target = 0.0
		l.fade = 0.18
	l.amount = move_toward(l.amount, l.target, delta / maxf(l.fade, 0.001))
	if l.amount <= 0.0 and l.target <= 0.0:
		l.anim = ""
	_tree.set("parameters/%s_mix/blend_amount" % key, l.amount)


func _play(key: String, anim: String, rate := 1.0, hold := false, fade := 0.05) -> void:
	if _tree == null or not _player.has_animation(anim):
		return
	var l: Dictionary = _layers[key]
	l.anim = anim
	l.time = 0.0
	l.length = _player.get_animation(anim).length / rate
	l.hold = hold
	l.target = 1.0
	l.fade = fade
	_tree.set("parameters/%s/transition_request" % key, anim)
	_tree.set("parameters/%s_rate/scale" % key, rate)


func _stop(key: String, fade := 0.12) -> void:
	var l: Dictionary = _layers[key]
	l.target = 0.0
	l.fade = fade
	if fade <= 0.0:
		l.amount = 0.0
		l.anim = ""


## The action a layer is playing ("" when none). A fading-out action still counts.
func playing(key: String) -> String:
	return _layers[key].anim


func _build_tree(speeds: Dictionary) -> void:
	for anim: String in LOOPS:
		for clip: String in [anim, anim + "_sheathed"]:
			if _player.has_animation(clip):
				_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_tree = AnimationTree.new()
	_tree.name = "Tree"
	add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_player)
	_tree.root_node = _tree.get_path_to(_player.get_node(_player.root_node))
	_tree.tree_root = CharacterAnimTree.build(_player, speeds, UPPER, FULL, UPPER_BONES, has_carry)
	_tree.active = true
	for n in ["rate", "upper_rate", "full_rate"]:
		_tree.set("parameters/%s/scale" % n, 1.0)
