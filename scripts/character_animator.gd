class_name CharacterAnimator
extends Node
## Plays a character's animations (made by tools/blender) from what its body is doing.
## It lives in every character model scene (scenes/characters/*_model.tscn) as "Animator".
## Standing, walking, running, sprinting, crouching and falling follow the body by themselves
## (from how fast it moves, is_crouched, and whether it's on the floor). Scripts call the
## one-shots: swing_windup / swing_release / swing_cancel, set_block, roll, hit, stab, die,
## revive, telegraph, strike, stagger, cast.
## Layers: the legs walk; an upper-body layer (wind-ups, block, telegraph) plays over them; a
## whole-body layer (cuts, rolls, deaths) plays over everything.

## Metres one walk / run / sprint / crouch-walk cycle carries him (tools/blender/anims_loco.py).
const STRIDE := {"walk": 1.5, "run": 3.4, "sprint": 4.8, "crouch_walk": 1.9}
const SWEEP_HIT := 0.07     ## a sweep's blade crosses his front this long after it starts
const STAB_DRAW := 0.13     ## in the stab, the knife leaves the sheath for the left hand...
const STAB_SHEATHE := 0.64  ## ...and goes back
const UPPER_BONES := ["Spine", "Chest", "Neck", "Head", "Shoulder_L", "Shoulder_R", "UpperArm_L",
		"UpperArm_R", "LowerArm_L", "LowerArm_R", "Hand_L", "Hand_R", "Weapon_L", "Weapon_R", "Back"]
const UPPER := ["windup_L", "windup_R", "block", "telegraph", "cast"]
const FULL := ["sweep_LR", "sweep_RL", "dodge_roll", "dodge_back", "hit", "stab", "death", "strike", "stagger"]

@export var body_path: NodePath        ## the body to follow (empty: the model's parent)
@export var walk_speed := 1.6          ## speeds (m/s) where each cycle plays on its own
@export var run_speed := 6.0
@export var sprint_speed := 9.5
@export var crouch_walk_speed := 2.8

var body: Node3D
var dead := false
var _player: AnimationPlayer
var _tree: AnimationTree
var _knife: BoneAttachment3D
var _last_pos := Vector3.ZERO
var _speed := 0.0
var _air := 0.0
var _airborne := 0.0
var _crouch := 0.0
var _vel := Vector3.ZERO      # smoothed ground velocity
var _twist: Node             # character_twist.gd under the skeleton
var _backwards := false
var _layers := {
	"upper": {"anim": "", "time": 0.0, "length": 0.0, "hold": false, "amount": 0.0, "target": 0.0, "fade": 0.1},
	"full": {"anim": "", "time": 0.0, "length": 0.0, "hold": false, "amount": 0.0, "target": 0.0, "fade": 0.1},
}


func _ready() -> void:
	var model := get_parent()
	body = get_node_or_null(body_path) if not body_path.is_empty() else model.get_parent() as Node3D
	_player = model.find_child("AnimationPlayer", true, false)
	_knife = model.get_node_or_null("Knife") as BoneAttachment3D
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 2  # the characters render layer: blob shadows skip it
	if _player == null or body == null:
		return
	_build_tree()
	_last_pos = body.global_position
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skeleton:
		_twist = preload("res://scripts/character_twist.gd").new()
		_twist.name = "Twist"
		skeleton.add_child(_twist)


func _physics_process(delta: float) -> void:
	if _tree == null or body == null:
		return
	_follow_body(delta)
	for key: String in _layers:
		_step_layer(key, delta)
	_update_knife()


## How the legs move: speed, crouch and air from the body, and the cycle rate that keeps feet planted.
func _follow_body(delta: float) -> void:
	var pos := body.global_position
	var v := (pos - _last_pos) / maxf(delta, 0.0001)
	_last_pos = pos
	if v.length() > 40.0:
		v = Vector3.ZERO  # teleported (a checkpoint, a cutscene): not a sprint
	_vel = _vel.lerp(Vector3(v.x, 0.0, v.z), 1.0 - exp(-14.0 * delta))
	_speed = _vel.length()
	var on_floor := true
	if body is CharacterBody3D:
		on_floor = (body as CharacterBody3D).is_on_floor()
	_airborne = 0.0 if on_floor else _airborne + delta
	_air = move_toward(_air, 1.0 if _airborne > 0.12 else 0.0, delta / 0.12)
	_crouch = move_toward(_crouch, 1.0 if body.get("is_crouched") == true else 0.0, delta / 0.15)
	# A child-sized model (the Massacre memory) takes shorter steps: judge his speed at his size.
	var sized := _speed / maxf(0.05, get_parent().global_basis.get_scale().y)
	_tree.set("parameters/stand/blend_position", minf(sized, sprint_speed))
	_tree.set("parameters/crouch/blend_position", minf(sized, crouch_walk_speed))
	_tree.set("parameters/crouch_mix/blend_amount", _crouch)
	_tree.set("parameters/air/blend_position", clampf(v.y / 5.0, -1.0, 1.0))
	_tree.set("parameters/air_mix/blend_amount", _air)
	var rate := lerpf(_stand_rate(sized), _crouch_rate(sized), _crouch)
	_tree.set("parameters/rate/scale", rate * _strafe(delta))


## Moving sideways or backwards to where he faces (strafing round a locked-on enemy, a guard
## sidestepping): the hips turn toward the movement while the chest stays square, and moving
## straight back plays the cycle backwards. Returns -1 when backing up, else 1.
func _strafe(delta: float) -> float:
	if _twist == null:
		return 1.0
	var target := 0.0
	if _speed > 0.6 and _air < 0.5 and playing("full") == "":
		var local: Vector3 = get_parent().global_basis.orthonormalized().inverse() * _vel
		var a := atan2(-local.x, -local.z)  # 0 = ahead, + = to his left
		if absf(a) > deg_to_rad(125.0):
			_backwards = true
		elif absf(a) < deg_to_rad(100.0):
			_backwards = false
		if _backwards:
			a -= signf(a) * PI
		target = clampf(a, -1.1, 1.1)
	else:
		_backwards = false
	_twist.twist = lerp_angle(_twist.twist, target, 1.0 - exp(-10.0 * delta))
	return -1.0 if _backwards else 1.0


func _stand_rate(v: float) -> float:
	if v < walk_speed:
		return lerpf(1.0, v / STRIDE.walk, v / walk_speed)
	if v < run_speed:
		return v / lerpf(STRIDE.walk, STRIDE.run, (v - walk_speed) / (run_speed - walk_speed))
	if v < sprint_speed:
		return v / lerpf(STRIDE.run, STRIDE.sprint, (v - run_speed) / (sprint_speed - run_speed))
	return v / STRIDE.sprint


func _crouch_rate(v: float) -> float:
	if v < crouch_walk_speed:
		return lerpf(1.0, v / STRIDE.crouch_walk, v / crouch_walk_speed)
	return v / STRIDE.crouch_walk


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


func playing(key: String) -> String:
	return _layers[key].anim


# ---------------------------------------------------------------- the one-shots
## Cocks the sword: side 1 = across his body to the left (a left-to-right cut follows),
## -1 = out to his right (the return stroke). Held until release or cancel.
func swing_windup(side: int) -> void:
	if dead:
		return
	_stop("full", 0.06)  # a chained swing: come out of the last cut into this wind-up
	_play("upper", "windup_L" if side > 0 else "windup_R", 1.0, true, 0.05)


## The cut. Light swings (power 0) play a little faster than a full charge (power 1).
func swing_release(side: int, power: float) -> void:
	if dead:
		return
	_play("full", "sweep_LR" if side > 0 else "sweep_RL", sweep_rate(power), false, 0.035)
	_stop("upper", 0.1)


func swing_cancel() -> void:
	if playing("upper").begins_with("windup"):
		_stop("upper", 0.12)


func sweep_rate(power: float) -> float:
	return lerpf(1.25, 1.0, clampf(power, 0.0, 1.0))


## Seconds from release until the blade crosses his front (when the hit should land).
func sweep_hit_time(power: float) -> float:
	return SWEEP_HIT / sweep_rate(power)


func set_block(on: bool) -> void:
	if on and not dead and playing("upper") != "block" and playing("full") == "":
		_play("upper", "block", 1.0, true, 0.06)
	elif not on and playing("upper") == "block":
		_stop("upper", 0.12)


## Dodge: a forward roll, or a hop back when he dodges straight backwards.
func roll(backwards := false) -> void:
	_play("full", "dodge_back" if backwards else "dodge_roll", 1.0, false, 0.04)
	_stop("upper", 0.05)


func hit() -> void:
	if dead or playing("full") in ["stab", "death", "dodge_roll"]:
		return
	_play("full", "hit", 1.0, false, 0.03)
	_stop("upper", 0.05)


func stab() -> void:
	_play("full", "stab", 1.0, false, 0.05)
	_stop("upper", 0.05)


func die() -> void:
	dead = true
	_play("full", "death", 1.0, true, 0.06)
	_stop("upper", 0.06)


## Back on his feet at once (a checkpoint restart).
func revive() -> void:
	dead = false
	_stop("full", 0.0)
	_stop("upper", 0.0)
	_update_knife()


## A guard's raised blade, timed to reach the top as the wind-up ends; held until strike().
func telegraph(seconds: float) -> void:
	if dead:
		return
	_play("upper", "telegraph", 0.6 / maxf(seconds, 0.1), true, 0.08)


func strike() -> void:
	if dead:
		return
	_play("full", "strike", 1.0, false, 0.04)
	_stop("upper", 0.06)


## Reels and recovers over `seconds`.
func stagger(seconds: float) -> void:
	if dead:
		return
	_play("full", "stagger", 1.0 / maxf(seconds, 0.2), false, 0.05)
	_stop("upper", 0.05)


func cast() -> void:
	if not dead:
		_play("upper", "cast", 1.0, false, 0.05)


## The knife rides the left hand during the middle of the stab, the sheath otherwise.
func _update_knife() -> void:
	if _knife == null:
		return
	var l: Dictionary = _layers.full
	var in_hand: bool = l.anim == "stab" and l.time * _tree.get("parameters/full_rate/scale") >= STAB_DRAW \
			and l.time * _tree.get("parameters/full_rate/scale") < STAB_SHEATHE
	var bone := "Weapon_L" if in_hand else "Sheath"
	if _knife.bone_name != bone:
		_knife.bone_name = bone


# ---------------------------------------------------------------- the blend tree
func _build_tree() -> void:
	for anim: String in ["idle", "walk", "run", "sprint", "crouch_idle", "crouch_walk", "fall"]:
		if _player.has_animation(anim):
			_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	var speeds := {"walk": walk_speed, "run": run_speed, "sprint": sprint_speed, "crouch_walk": crouch_walk_speed}
	_tree = AnimationTree.new()
	_tree.name = "Tree"
	add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_player)
	_tree.root_node = _tree.get_path_to(_player.get_node(_player.root_node))
	_tree.tree_root = CharacterAnimTree.build(_player, speeds, UPPER, FULL, UPPER_BONES)
	_tree.active = true
	for n in ["rate", "upper_rate", "full_rate"]:
		_tree.set("parameters/%s/scale" % n, 1.0)
