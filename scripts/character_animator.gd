class_name CharacterAnimator
extends CharacterStory
## Plays a character's animations (made by tools/blender) from what its body is doing.
## It lives in every character model scene (scenes/characters/*_model.tscn) as "Animator".
## Standing, walking, running, sprinting, crouching and falling follow the body by themselves
## (from how fast it moves, is_crouched, and whether it's on the floor). Scripts call the
## one-shots: swing_windup / swing_release / swing_cancel, set_block, roll, hit, stab, die,
## revive, telegraph, strike, stagger, cast; and for Aeneas's sheathed sword iai_stance,
## draw_release, draw_instant and sheathe. The story poses (story_pose, story_clear...) are in
## character_story.gd; the layers, the tree and the props that change hands in character_anim_layers.gd.

## Metres one walk / run / sprint / crouch-walk cycle carries him (tools/blender/anims_loco.py).
const STRIDE := {"walk": 1.5, "run": 3.4, "sprint": 4.8, "crouch_walk": 1.9}
const SWEEP_HIT := 0.07     ## a sweep's blade crosses his front this long after it starts
const DRAW_HIT := 0.105     ## the quick draw's blade crosses his front (tools/blender/aeneas_anims.py)
const CAST_HIT := 0.22      ## Isabella's slash: her brush finishes the stroke (tools/blender/anims_combat.py)

@export var body_path: NodePath        ## the body to follow (empty: the model's parent)
@export var walk_speed := 1.6          ## speeds (m/s) where each cycle plays on its own
@export var run_speed := 6.0
@export var sprint_speed := 9.5
@export var crouch_walk_speed := 2.8

var body: Node3D
var dead := false
var _last_pos := Vector3.ZERO
var _speed := 0.0
var _air := 0.0
var _airborne := 0.0
var _crouch := 0.0
var _vel := Vector3.ZERO      # smoothed ground velocity
var _twist: Node             # character_twist.gd under the skeleton
var _backwards := false
var _blow := ""               # the variant wound up by telegraph() ("_hook"...), for strike()


func _ready() -> void:
	var model := get_parent()
	body = get_node_or_null(body_path) if not body_path.is_empty() else model.get_parent() as Node3D
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 2  # the characters render layer: blob shadows skip it
	if body == null:
		return
	_setup_layers(model, {"walk": walk_speed, "run": run_speed, "sprint": sprint_speed, "crouch_walk": crouch_walk_speed})
	if _tree == null:
		return
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
	_step_props(delta)


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
	for sfx: String in (["", "_s"] if has_carry else [""]):
		_tree.set("parameters/stand%s/blend_position" % sfx, minf(sized, sprint_speed))
		_tree.set("parameters/crouch%s/blend_position" % sfx, minf(sized, crouch_walk_speed))
		_tree.set("parameters/crouch_mix%s/blend_amount" % sfx, _crouch)
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


# ---------------------------------------------------------------- the one-shots
## Cocks the sword: side 1 = across his body to the left (a left-to-right cut follows),
## -1 = out to his right (the return stroke). Held until release or cancel.
func swing_windup(side: int) -> void:
	if dead:
		return
	put_sword(true)  # (Aeneas opens with the quick draw; this is only a safety net)
	_stop("full", 0.06)  # a chained swing: come out of the last cut into this wind-up
	_play("upper", "windup_L" if side > 0 else "windup_R", 1.0, true, 0.05)


## The cut. Light swings (power 0) play a little faster than a full charge (power 1).
func swing_release(side: int, power: float) -> void:
	if dead:
		return
	_play("full", "sweep_LR" if side > 0 else "sweep_RL", sweep_rate(power), false, 0.035)
	_stop("upper", 0.1)


## Lowers a wound-up blade, or rises out of the iai stance without drawing.
func swing_cancel() -> void:
	if playing("upper").begins_with("windup"):
		_stop("upper", 0.12)
	if playing("full") == "iai":
		_stop("full", 0.12)


func sweep_rate(power: float) -> float:
	return lerpf(1.25, 1.0, clampf(power, 0.0, 1.0))


## Seconds from release until the blade crosses his front (when the hit should land).
func sweep_hit_time(power: float) -> float:
	return SWEEP_HIT / sweep_rate(power)


## Aeneas: the iai stance (right hand on the hilt, knees bent), held until draw_release() or
## swing_cancel(). The sword stays in its scabbard meanwhile.
func iai_stance() -> void:
	if dead:
		return
	_play("full", "iai", 1.0, true, 0.06)
	_stop("upper", 0.06)


## The quick draw: out of the scabbard and across in one cut (same speeds as swing_release).
func draw_release(power: float) -> void:
	if dead:
		return
	put_sword(true)  # his hand already grips it where it sits, so it leaves the scabbard with the hand
	_play("full", "draw_cut", sweep_rate(power), false, 0.035)
	_stop("upper", 0.06)


func draw_hit_time(power: float) -> float:
	return DRAW_HIT / sweep_rate(power)


## The sword straight into his hand (blocking from the scabbard).
func draw_instant() -> void:
	if playing("upper") == "sheathe":
		_stop("upper", 0.08)
	put_sword(true)


## Back into the scabbard (an upper-body action, so he can keep walking). Anything else he does
## before the blade is home leaves it in his hand.
func sheathe() -> void:
	if has_carry and sword_in_hand and not dead and playing("full") == "" and playing("upper") == "":
		_play("upper", "sheathe", 1.0, false, 0.12)


func sheathing() -> bool:
	return playing("upper") == "sheathe" and _layers.upper.target > 0.0


func set_block(on: bool) -> void:
	if on and not dead and playing("upper") != "block" and playing("full") == "":
		put_sword(true)
		_play("upper", "block", 1.0, true, 0.06)
	elif not on and playing("upper") == "block":
		_stop("upper", 0.12)


## Dodge: a forward roll, or a hop back when he dodges straight backwards.
func roll(backwards := false) -> void:
	_play("full", "dodge_back" if backwards else "dodge_roll", 1.0, false, 0.04)
	_stop("upper", 0.05)


## The slide (player_slide.gd): down and scraping along, held until slide_end().
func slide() -> void:
	_play("full", "slide", 1.0, true, 0.06)
	_stop("upper", 0.05)


## The slide is over: `getup` pushes him up into a run; otherwise he settles into the crouch.
func slide_end(getup: bool) -> void:
	if playing("full") != "slide":
		return
	if getup:
		_play("full", "slide_getup", 1.0, false, 0.05)
	else:
		_stop("full", 0.15)


func hit() -> void:
	if dead or playing("full") in ["stab", "death", "dodge_roll"]:
		return
	_play("full", "hit", 1.0, false, 0.03)
	_stop("upper", 0.05)


func stab() -> void:
	_play("full", "stab", 1.0, false, 0.05)
	_stop("upper", 0.05)


## Falls and holds the last pose. `instant`: reaches it in a few frames (Continue lays the dead
## down under the black screen).
func die(instant := false) -> void:
	dead = true
	_play("full", "death", 40.0 if instant else 1.0, true, 0.0 if instant else 0.06)
	_stop("upper", 0.06)


## Back on his feet at once (a checkpoint restart), the sword back in its scabbard.
func revive() -> void:
	dead = false
	_stop("full", 0.0)
	_stop("upper", 0.0)
	if has_carry:
		put_sword(false)
		_carry = 1.0
	if _tree:
		_step_props(0.0)


## A guard's raised blade, timed to reach the top as the wind-up ends; held until strike().
## `kind` picks a variant the model may have (the captain's fists: "hook", "heavy"; "" or "jab" the
## plain one): telegraph_<kind> now, strike_<kind> on the strike.
func telegraph(seconds: float, kind := "") -> void:
	if dead:
		return
	_blow = "_" + kind if kind != "" and _player and _player.has_animation("telegraph_" + kind) else ""
	_play("upper", "telegraph" + _blow, 0.6 / maxf(seconds, 0.1), true, 0.08)


## A feint: the raised blade comes back down without striking (the captain's choreography).
func lower_blade() -> void:
	if playing("upper").begins_with("telegraph"):
		_stop("upper", 0.15)


func strike() -> void:
	if dead:
		return
	_play("full", "strike" + _blow, 1.0, false, 0.04)
	_blow = ""
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
