class_name Player
extends CharacterBody3D
## Aeneas in 3D: runs relative to the camera, turns to face where he runs,
## jumps (tap for a hop, hold for a full jump) and crouches (press to toggle).
## Every number below shows up in the Inspector when you select the Player,
## so you can tune the feel without touching code.

signal crouched_changed(crouched: bool)  ## companions copy this to hide with him
signal respawned                         ## after being put back somewhere
signal fell                              ## he dropped below fall_limit; a checkpoint system can take over

@export_group("Running")
@export var run_speed := 6.0       ## metres per second
@export var sprint_speed := 9.5    ## holding Shift (or clicking the left stick)
@export var acceleration := 40.0   ## how fast he gets up to speed
@export var friction := 50.0       ## how fast he stops on the ground
@export var air_control := 15.0    ## how much he can steer in the air
@export var turn_speed := 12.0     ## how fast his body turns to face the run

@export_group("Jumping")
@export var jump_velocity := 8.0
@export var gravity := 22.0
@export var fall_gravity_multiplier := 1.5  ## falls faster than he rises: snappier jumps
@export var jump_cut := 0.5                 ## let go of jump early and he keeps this much upward speed
@export var coyote_time := 0.1              ## seconds after running off a ledge when jump still works
@export var jump_buffer_time := 0.12        ## seconds a jump press is remembered before landing

@export_group("Crouching")
@export var crouch_speed := 2.8   ## metres per second while crouched
@export var crouch_height := 1.1  ## how tall he is crouched (standing is 1.8): low enough to hide behind a railing

@export_group("Falling")
@export var fall_limit := -15.0  ## fall below this height and he's put back on the last ground he stood on
@export var fall_death_height := 6.0  ## a drop longer than this (metres) is a fall too: back to the checkpoint

@onready var model: Node3D = $Model
@onready var animator: CharacterAnimator = get_node_or_null("Model/Animator")  ## plays his animations
@onready var camera_pivot: Node3D = $CameraPivot
@onready var body_shape: CollisionShape3D = $CollisionShape3D

var is_crouched := false
var controls_enabled := true  ## off during takedowns and while being sent back to a checkpoint
var in_cutscene := false      ## set by the Story player; guards don't look for him meanwhile
var falling_back := false     ## a fall is sending him to the checkpoint (from the landing until he is put back)
var companion: Companion      ## Isabella, if she's following him (she signs herself up)
var rooted := false           ## his feet stay planted (Combat sets it while he holds the iai stance)

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _last_ground := Vector3.ZERO
var _fall_from := 0.0  # the height he last stood at: how far a drop went when he lands
var _capsule: CapsuleShape3D
var _stand_height := 0.0
var _pivot_height := 0.0

func _enter_tree() -> void:
	add_to_group("player")


func _ready() -> void:
	_last_ground = global_position
	_fall_from = global_position.y
	_ensure_sprint_action()
	# Our own copy of the collision capsule, so crouching can shrink it.
	_capsule = body_shape.shape.duplicate()
	body_shape.shape = _capsule
	_stand_height = _capsule.height
	_pivot_height = camera_pivot.position.y
	respawned.connect(_on_respawned)
	var combat: PlayerCombat = get_node_or_null("Combat")
	if combat:
		combat.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_crouch()
	_handle_jump(delta)
	_handle_run(delta)
	move_and_slide()
	_handle_falling()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		return
	_coyote_timer -= delta
	var g := gravity
	if velocity.y < 0.0:
		g *= fall_gravity_multiplier
	velocity.y -= g * delta


func _handle_crouch() -> void:
	if controls_enabled and Input.is_action_just_pressed("crouch") and is_on_floor():
		_set_crouched(not is_crouched)


func _handle_jump(delta: float) -> void:
	_jump_buffer_timer -= delta
	if controls_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	var combat: PlayerCombat = get_node_or_null("Combat")
	if combat and (combat.dodge_ready() or combat.move != PlayerCombat.Move.NONE):
		_jump_buffer_timer = 0.0  # Space is the dodge while locked on or in a fight
		return
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		# Jumping stands him up first; no jump if something is right above his head.
		_set_crouched(false)
		if not is_crouched:
			velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= jump_cut


func _handle_run(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled and not rooted:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Turn the input so "forward" always means "away from the camera".
	var direction := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera_pivot.global_rotation.y)
	var speed := run_speed
	if is_crouched:
		speed = crouch_speed
	elif Input.is_action_pressed("sprint"):
		speed = sprint_speed
	var target := direction * speed

	var rate := acceleration if is_on_floor() else air_control
	if direction == Vector3.ZERO and is_on_floor():
		rate = friction
	var flat := Vector2(velocity.x, velocity.z).move_toward(Vector2(target.x, target.z), rate * delta)
	velocity.x = flat.x
	velocity.z = flat.y

	# Only the Model turns, so the camera (a sibling) isn't spun around with him.
	# Locked on, he keeps facing the enemy and strafes instead.
	var combat: PlayerCombat = get_node_or_null("Combat")
	if combat and combat.move == PlayerCombat.Move.DODGE and combat.dodge_facing != Vector3.ZERO:
		model.rotation.y = atan2(-combat.dodge_facing.x, -combat.dodge_facing.z)  # rolling: face the roll
	elif combat and combat.lock_target:
		face(combat.lock_target.global_position)
	elif combat and combat.aiming():
		pass  # a swing's soft aim is turning him toward the enemy in front (swing_assist.gd)
	elif direction.length() > 0.1:
		var facing := atan2(-direction.x, -direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, facing, turn_speed * delta)


func _set_crouched(crouched: bool) -> void:
	if crouched == is_crouched:
		return
	if not crouched and not _has_headroom():
		return
	is_crouched = crouched
	var height := crouch_height if crouched else _stand_height
	_capsule.height = height
	body_shape.position.y = height * 0.5
	# The model crouches by itself (the Animator reads is_crouched); the camera drops with him.
	create_tween().tween_property(camera_pivot, "position:y", _pivot_height - (_stand_height - height), 0.15)
	crouched_changed.emit(is_crouched)


## True if there's room to stand up here (nothing solid where his head would go).
func _has_headroom() -> bool:
	var standing := CapsuleShape3D.new()
	standing.radius = _capsule.radius
	standing.height = _stand_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing
	query.transform = Transform3D(Basis(), global_position + Vector3(0.0, _stand_height * 0.5 + 0.05, 0.0))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## "sprint" is registered here (Shift, or the left stick click) rather than in project.godot,
## so it works even if the Input Map hasn't been edited.
func _ensure_sprint_action() -> void:
	if InputMap.has_action("sprint"):
		return
	InputMap.add_action("sprint")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SHIFT
	InputMap.action_add_event("sprint", key)
	var stick := InputEventJoypadButton.new()
	stick.button_index = JOY_BUTTON_LEFT_STICK
	InputMap.action_add_event("sprint", stick)


## Where his eyes are: what guards look for. Lower when he's crouched.
func eye_position() -> Vector3:
	return global_position + Vector3.UP * _capsule.height * 0.85


## Puts him at a spot (a checkpoint, or the last ground after a fall). Isabella follows.
func respawn_at(point: Vector3) -> void:
	global_position = point
	velocity = Vector3.ZERO
	_last_ground = point
	_fall_from = point.y
	falling_back = false
	respawned.emit()


func face(point: Vector3) -> void:
	var look := point - global_position
	model.rotation.y = atan2(-look.x, -look.z)


## The knife takedown (the Animator draws the knife from the small of his back, stabs, sheathes it).
func stab() -> void:
	if animator:
		animator.stab()


## The sword swings, played by the Animator. wind_up() cocks the blade across his body to his
## LEFT, release_swing() cuts left to right (seen from the camera behind him). A swing chained
## onto the last one (tapped as it lands) goes the other way, right to left, and they keep
## alternating; a fresh attack always opens left to right. cancel_swing() lowers the blade.
## With the sword in its scabbard the opening cut is the quick draw instead: iai_stance() (hand
## on the hilt) then release_draw(), out of the scabbard and left to right in one motion.
var _swing_side := 1  # +1: cocked on his left, cuts to the right; -1: the return stroke


func wind_up(chained := false) -> void:
	if not chained:
		_swing_side = 1
	if animator:
		animator.swing_windup(_swing_side)


func release_swing(power: float) -> void:
	if animator:
		animator.swing_release(_swing_side, power)
	_swing_side = -_swing_side  # chained swings alternate, like a real flurry


func iai_stance() -> void:
	if animator:
		animator.iai_stance()


func release_draw(power: float) -> void:
	if animator:
		animator.draw_release(power)
	_swing_side = -1  # the draw cut goes left to right, so a chained swing comes back


func cancel_swing() -> void:
	_swing_side = 1
	if animator:
		animator.swing_cancel()


## Seconds from releasing a swing (or the draw) until the blade crosses his front: when the hit lands.
func swing_hit_time(power: float, draw := false) -> float:
	if animator == null:
		return 0.0
	return animator.draw_hit_time(power) if draw else animator.sweep_hit_time(power)


func show_block(on: bool) -> void:
	if animator:
		animator.set_block(on)


func show_dodge(backwards: bool) -> void:
	if animator:
		animator.roll(backwards)


func show_hit() -> void:
	if animator:
		animator.hit()


func _on_died() -> void:
	if animator:
		animator.die()


func _on_respawned() -> void:
	if animator:
		animator.revive()


## The eruption's visual: a dark ring that races out along the floor (player_fx.gd).
func shockwave_ring(reach: float) -> void:
	PlayerFx.shockwave_ring(self, reach)


## A brief tint on his whole model (hit = red, parry = white).
func flash(color: Color) -> void:
	PlayerFx.flash(self, color)


func _handle_falling() -> void:
	if is_on_floor():
		if _fall_from - global_position.y > fall_death_height and not fell.get_connections().is_empty():
			velocity = Vector3.ZERO
			falling_back = true
			fell.emit()  # nobody walks away from a drop like that (or skips the level with one)
		_fall_from = global_position.y
		_last_ground = global_position
	elif global_position.y < fall_limit:
		if fell.get_connections().is_empty():
			respawn_at(_last_ground)  # no checkpoint system in this level: back on the last ground
		else:
			velocity = Vector3.ZERO
			global_position.y = fall_limit  # hold him here while the fade plays
			falling_back = true
			fell.emit()


## Waits until he stands on the ground (now, or after the jump or drop he is in). False if that
## landing was a fall that sends him back: checkpoints and story triggers he passed through on
## the way down must not count.
func land_safely() -> bool:
	while not is_on_floor() and not falling_back:
		await get_tree().physics_frame
	await get_tree().physics_frame
	return not falling_back
