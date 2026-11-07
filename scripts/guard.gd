class_name Guard
extends CharacterBody3D
## An Agency agent. He walks his route (the Marker3D points under his Route node,
## in order, then back to the first) or, with no Route, stands his post.
## While he can see Aeneas, his suspicion fills (the "?" over his head); when it
## is full he spots him. Isabella is never noticed. His numbers and look come
## from a GuardData file in data/enemies/.

signal spotted(guard: Guard)     ## the stealth director restarts from the last checkpoint
signal taken_down(guard: Guard)
signal health_changed(health: float, max_health: float)

enum State { PATROL, SUSPICIOUS, SPOTTED, DOWN, FIGHTING, STAGGERED }

const GRAVITY := 22.0

const GuardHunt := preload("res://scripts/guard_hunt.gd")

@export var data: GuardData
@export var fights := false  ## true: being spotted starts a fight instead of a restart
@export var dormant := false ## true: he ignores Aeneas until a story scene starts his fight
@export var hunts := false  ## true: while shown he runs at Aeneas, and a grab sends him back to the checkpoint (guard_hunt.gd)
@export var hunt_speed := 3.2  ## metres per second while hunting

@onready var model: Node3D = $Model
@onready var eyes: Node3D = $Model/Eyes
@onready var visor: MeshInstance3D = $Model.find_child("Visor", true, false)  ## his eye-light (a mesh named Visor on his head)
@onready var ink_glyph: Node3D = $Model/InkGlyph
@onready var alert: Label3D = $Alert
@onready var blood: Decal = $BloodPool
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var animator: CharacterAnimator = get_node_or_null("Model/Animator")  ## walks, swings, falls
@onready var fighter: Node = $Fighter

var state := State.PATROL
var suspicion := 0.0  # 0 = calm, 1 = spotted
var killed := false   # true if Aeneas's knife killed him (Isabella's binds don't set this)
var health := 60.0
var invulnerable := false  ## the empowered captain: hits land but don't count
var _stagger_left := 0.0

var _route: Array[Vector3] = []
var _route_index := 0
var _waited := 0.0
var _last_seen := Vector3.ZERO
var _start_position := Vector3.ZERO
var _start_facing := 0.0
var down_for_good := false  ## down before the last checkpoint (or the save): a restart leaves him down
var _player: Player
var _start_fights := false   # the level's own `fights` / `dormant`: a restart puts them back
var _start_dormant := false


func _enter_tree() -> void:
	add_to_group("guards")
	add_to_group("enemies")


func _ready() -> void:
	GuardLook.swap_model(self)  # the captain wears his own model (GuardData.model_scene)
	# Read the route before anything moves (the markers ride along with him).
	var route := get_node_or_null("Route")
	if route:
		for point in route.get_children():
			if point is Node3D:
				_route.append(point.global_position)
	# Whichever way the guard node was turned in the level is the way he faces.
	_start_facing = global_rotation.y
	rotation = Vector3.ZERO
	model.rotation.y = _start_facing
	_start_position = global_position
	_apply_look()
	data = data.duplicate()  # his own copy, so empower() can't change every agent at once
	health = data.health
	_player = get_tree().get_first_node_in_group("player")
	_start_fights = fights
	_start_dormant = dormant


func _physics_process(delta: float) -> void:
	if state == State.DOWN:
		return
	if hunts and not dormant:
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
		GuardHunt.tick(self, delta)
		move_and_slide()
		return
	if _player and _player.in_cutscene and state in [State.FIGHTING, State.STAGGERED]:
		_stop()
		move_and_slide()
		return  # fights pause for story scenes
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	_watch(delta)
	match state:
		State.PATROL:
			_patrol(delta)
		State.SUSPICIOUS:
			_look_at_last_seen(delta)
		State.SPOTTED:
			_stop()
		State.FIGHTING:
			fighter.tick(delta)
		State.STAGGERED:
			_stop()
			_stagger_left -= delta
			if _stagger_left <= 0.0:
				state = State.FIGHTING
	move_and_slide()
	_update_alert()


## How well he can see a point right now: 0 = not at all, up to 1 = clearly, up close.
func sees_point(point: Vector3, crouched := false) -> float:
	var from := eyes.global_position
	var to := point - from
	var reach := data.sight_range * (data.crouch_sight_multiplier if crouched else 1.0)
	var distance := to.length()
	if distance > reach:
		return 0.0
	if rad_to_deg((-model.global_basis.z).angle_to(to)) > data.sight_angle * 0.5:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(from, point, 1)  # walls and floors only
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return 0.0
	return 1.0 - 0.7 * distance / reach


## True if Aeneas, standing at this point, is outside his view (so he can be taken down).
func is_unaware_of(point: Vector3) -> bool:
	if dormant or hunts:
		return false  # waiting for his story fight: not a target until it starts
	if state in [State.DOWN, State.SPOTTED, State.FIGHTING, State.STAGGERED]:
		return false  # no quiet takedowns on a man who's already fighting you
	var to := point - global_position
	to.y = 0.0
	var forward := -model.global_basis.z
	forward.y = 0.0
	return rad_to_deg(forward.angle_to(to)) > data.sight_angle * 0.5 + 15.0


## He saw a fellow agent go down: no slow suspicion, he spots Aeneas at once.
func witness() -> void:
	if state != State.DOWN:
		_spot()


## Starts a fight (a guard with `fights` on, or one told to by the story).
func engage() -> void:
	if state in [State.DOWN, State.FIGHTING, State.STAGGERED]:
		return
	fights = true
	dormant = false
	state = State.FIGHTING
	suspicion = 1.0
	alert.visible = false


func can_be_locked() -> bool:
	return state != State.DOWN and not dormant and not hunts


## Fed to the cube: he drops where he stands, no blood, and stays down.
func sacrifice() -> void:
	if state == State.DOWN:
		return
	fighter.interrupt()
	_go_down()
	down_for_good = true


## The captain after the lieutenant's sacrifice: full health, harder hits, nothing gets through.
func empower() -> void:
	invulnerable = true
	data.unblockable = true
	data.attack_damage *= 1.6
	data.attack_cooldown *= 0.7
	data.fight_speed *= 1.3
	health = data.health
	health_changed.emit(health, data.health)
	_tint(Color(1.0, 0.1, 0.05))
	var eye: ShaderMaterial = visor.material_override
	if eye:
		eye.set_shader_parameter("emission_energy", 5.0)


## Aeneas's sword. Fighting back if he wasn't already.
func take_hit(damage: float, from: Vector3) -> void:
	if state == State.DOWN or dormant or hunts:
		return  # a fight that hasn't started can't be cut short (or shocked awake by the eruption)
	if invulnerable:
		_tint(Color(0.42, 0.44, 0.55))  # it lands, and it doesn't matter
		SfxBus.play("hit_thud", global_position + Vector3.UP, -10.0)
		return
	health = maxf(0.0, health - damage)
	health_changed.emit(health, data.health)
	_tint(Color(1, 0.4, 0.3))
	SfxBus.play("hit_thud", global_position + Vector3.UP, -2.0)
	var away := global_position - from
	away.y = 0.0
	velocity += away.normalized() * 3.0
	if health <= 0.0:
		take_down()
	elif state == State.STAGGERED:
		pass  # a riposte doesn't wake him early
	else:
		var flinch: bool = fighter.take_hit_reaction()  # a choreographed boss keeps his beat
		engage()
		if animator and flinch:
			animator.hit()


## A parry landed: he reels for a moment, open to a riposte.
func stagger(seconds: float) -> void:
	if state == State.DOWN or dormant:
		return
	fighter.interrupt()
	state = State.STAGGERED
	_stagger_left = seconds
	alert.visible = true
	alert.text = "!"
	alert.modulate = Color(1.0, 0.95, 0.6)
	_tint(Color(1.0, 0.78, 0.2))  # a gold flash: open for a riposte (a pale flash would vanish on a white coat)
	if animator:
		animator.stagger(seconds)


## The red flash and the raised blade before a swing.
func telegraph(seconds: float) -> void:
	var eye: ShaderMaterial = visor.material_override
	if eye:
		var tween := create_tween()
		tween.tween_property(eye, "shader_parameter/emission_energy", 6.0, seconds * 0.8)
		tween.tween_property(eye, "shader_parameter/emission_energy", 2.0, seconds * 0.2)
	if animator:
		animator.telegraph(seconds, fighter.next_blow())  # the blade rises (the captain: a fist draws back)


## The swing itself.
func strike() -> void:
	if animator:
		animator.strike()


func _tint(color: Color) -> void:
	GuardLook.flash(self, color)


## Killed by Aeneas's knife: he drops face-first and blood spreads under him.
func take_down() -> void:
	var ahead := -model.global_basis.z
	ahead.y = 0.0
	killed = true
	SfxBus.play("takedown_stab", global_position + Vector3.UP * 0.8, -2.0, 0.05)
	_go_down()
	ahead = ahead.normalized() * 0.8  # where his chest lands
	blood.position = Vector3(ahead.x, -1.0, ahead.z)
	blood.size = Vector3(0.2, 2.4, 0.2)
	blood.visible = true
	create_tween().tween_property(blood, "size", Vector3(1.5, 2.4, 1.5), 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Isabella's ink: he stops dead, and when her stroke's ink reaches him (`delay` seconds later)
## a glyph opens round him and he drops.
func bind_with_ink(delay := 0.0) -> void:
	if state == State.DOWN:
		return
	state = State.DOWN
	velocity = Vector3.ZERO
	alert.visible = false
	ink_glyph.scale = Vector3.ONE * 0.2
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func() -> void: ink_glyph.visible = true)
	tween.tween_property(ink_glyph, "scale", Vector3.ONE, 0.15)
	tween.tween_property(ink_glyph, "rotation:z", TAU, 0.55)
	tween.tween_callback(_go_down)
	tween.tween_property(ink_glyph, "scale", Vector3.ZERO, 0.25)


## Called when Aeneas reaches a checkpoint: guards already down stay down from now on.
func commit_checkpoint() -> void:
	down_for_good = state == State.DOWN


## Called when Aeneas is sent back to a checkpoint.
func reset_to_checkpoint() -> void:
	if down_for_good:
		return
	fighter.interrupt()  # a wind-up doesn't carry over
	# A sneaking agent he cut fought back (engage() made him a fighter): after the restart he is
	# the level's agent again. A story Fight's agents keep what the Fight set.
	if not get_parent().is_in_group("fights"):
		fights = _start_fights
		dormant = _start_dormant
	state = State.PATROL
	suspicion = 0.0
	killed = false
	health = data.health
	blood.visible = false
	_route_index = 0
	_waited = 0.0
	global_position = _start_position
	velocity = Vector3.ZERO
	model.rotation = Vector3(0.0, _start_facing, 0.0)
	if animator:
		animator.revive()
	body_shape.set_deferred("disabled", false)
	visor.visible = true
	ink_glyph.visible = false
	alert.visible = false


func _watch(delta: float) -> void:
	if _player == null or state in [State.SPOTTED, State.FIGHTING, State.STAGGERED] or _player.in_cutscene:
		return  # nobody gets spotted during a story scene
	if dormant or (fights and not visible):
		return  # a fighter waiting for his scene
	var seen := sees_point(_player.eye_position(), _player.is_crouched)
	if seen > 0.0:
		suspicion += seen * delta / data.notice_time
		_last_seen = _player.global_position
	else:
		suspicion -= data.forget_rate * delta
	suspicion = clampf(suspicion, 0.0, 1.0)
	if suspicion >= 1.0:
		_spot()
	elif suspicion > 0.0:
		state = State.SUSPICIOUS
	elif state == State.SUSPICIOUS:
		state = State.PATROL


func _patrol(delta: float) -> void:
	if _route.is_empty():
		_stop()
		_turn_to(_start_facing, delta)
		return
	var to := _route[_route_index] - global_position
	to.y = 0.0
	if to.length() < 0.3:
		_stop()
		_waited += delta
		if _waited >= data.wait_time:
			_waited = 0.0
			_route_index = (_route_index + 1) % _route.size()
		return
	var direction := to.normalized()
	velocity.x = direction.x * data.walk_speed
	velocity.z = direction.z * data.walk_speed
	_turn_to(atan2(-direction.x, -direction.z), delta)


func _look_at_last_seen(delta: float) -> void:
	_stop()
	var to := _last_seen - global_position
	if Vector2(to.x, to.z).length() > 0.1:
		_turn_to(atan2(-to.x, -to.z), delta)


func _spot() -> void:
	if fights:
		engage()
		return
	state = State.SPOTTED
	suspicion = 1.0
	_stop()
	_update_alert()
	spotted.emit(self)


func _go_down() -> void:
	state = State.DOWN
	suspicion = 0.0
	velocity = Vector3.ZERO
	alert.visible = false
	visor.visible = false  # his eye-light goes out
	body_shape.set_deferred("disabled", true)
	if animator:
		animator.die()  # knees give and he falls on his face
	taken_down.emit(self)


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _turn_to(angle: float, delta: float) -> void:
	model.rotation.y = lerp_angle(model.rotation.y, angle, data.turn_speed * delta)


func _update_alert() -> void:
	if state in [State.FIGHTING, State.STAGGERED]:
		return  # the fight shows itself
	alert.visible = suspicion > 0.0 and state != State.DOWN
	if state == State.SPOTTED:
		alert.text = "!"
		alert.modulate = Color(1.0, 0.15, 0.1)
	else:
		alert.text = "?"
		alert.modulate = Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.35, 0.1), suspicion)
	alert.scale = Vector3.ONE * (0.6 + 0.6 * suspicion)


## Colours from the GuardData file (guard_look.gd).
func _apply_look() -> void:
	GuardLook.apply(self)
