class_name PlayerCombat
extends Node
## Aeneas's sword fighting, Souls-style: lock on, stamina, a charged swing, a dodge roll,
## a block, and a parry (tap block just as a hit lands) that opens a riposte.
## Lives under the Player as "Combat". Enemies call take_hit() on it.
##   Q / right stick click: lock on
##   F, left click / X: attack. Tap = an instant light swing; HOLD to wind up, release to
##     swing. The longer the hold (up to charge_time), the harder the hit.
##   G / Y: a full-power swing at once (no hold)
##   right click (hold) / LB: block; tap for a parry
##   Space / B while locked on: dodge roll (jump and crouch otherwise)

signal health_changed(health: float, max_health: float)
signal stamina_changed(stamina: float, max_stamina: float)
signal died
signal lock_changed(target: Node3D)

enum Move { NONE, SWING, DODGE }

@export var max_health := 100.0
@export var max_stamina := 100.0
@export var stamina_regen := 28.0      ## per second, after a short pause
@export var lock_range := 12.0
@export var sword_reach := 1.9
@export var charge_time := 0.6         ## seconds of holding attack for a full-power swing
@export var light_damage := 22.0
@export var heavy_damage := 45.0
@export var invulnerable := false      ## set during story moments (the eruption)

# The dodge's timing; the swing's is worked out from its power in _swing().
const DODGE := {"stamina": 22.0, "windup": 0.0, "active": 0.32, "recovery": 0.18}
const PARRY_WINDOW := 0.18   # seconds after pressing block during which a hit is parried
const RIPOSTE_MULTIPLIER := 3.0
const BLOCK_DAMAGE_SHARE := 0.25
const DODGE_SPEED := 9.0

@onready var player: Player = get_parent()

var health := 100.0
var stamina := 100.0
var lock_target: Node3D
var move := Move.NONE
var blocking := false
var erupting := false  ## the Empty Town's eruption: raw gravity instead of the sword
var dodge_facing := Vector3.ZERO  ## which way he rolls (zero for a hop straight back): the Player faces it

const ERUPT_RANGE := 7.0
const ERUPT_DAMAGE := 40.0
const ERUPT_COOLDOWN := 0.9
var _erupt_cooldown := 0.0

var _move_time := 0.0
var _move_spec := {}
var _hit_done := false
var _regen_pause := 0.0
var _block_pressed_at := -10.0
var _dodge_dir := Vector3.ZERO
var _riposte_target: Node3D
var _charging := false
var _charge := 0.0


func _ready() -> void:
	_ensure_actions()
	health = max_health
	stamina = max_stamina


func _physics_process(delta: float) -> void:
	_tick(delta)
	player.show_block(blocking)  # the Animator raises or lowers the blade


func _tick(delta: float) -> void:
	_regen(delta)
	_keep_lock()
	if not player.controls_enabled:
		blocking = false
		return
	if Input.is_action_just_pressed("lock_on"):
		_toggle_lock()
	if erupting:
		_erupt_cooldown -= delta
		if (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("heavy_attack")) and _erupt_cooldown <= 0.0:
			_shockwave()
		return
	if move != Move.NONE:
		_advance_move(delta)
		# Chaining: once the blade has landed, the next press starts the next swing at once,
		# so how fast you tap is how fast he swings (stamina permitting).
		if move == Move.SWING and _hit_done and Input.is_action_just_pressed("attack") and not _takedown_available():
			move = Move.NONE
			_charging = true
			_charge = 0.0
			player.wind_up(true)  # chained: the return stroke
		return
	if _charging:
		# Winding up: he keeps the pose until the button comes up, then swings.
		_charge += delta
		if not Input.is_action_pressed("attack"):
			_charging = false
			_swing(clampf(_charge / charge_time, 0.0, 1.0))
		return
	blocking = Input.is_action_pressed("block") and player.is_on_floor() and not player.is_crouched
	if Input.is_action_just_pressed("block"):
		_block_pressed_at = Time.get_ticks_msec() / 1000.0
	if player.is_crouched:
		return
	if Input.is_action_just_pressed("attack") and not _takedown_available():
		_charging = true
		_charge = 0.0
		blocking = false
		player.wind_up()
	elif Input.is_action_just_pressed("heavy_attack"):
		player.wind_up()
		_swing(1.0)
	elif lock_target and Input.is_action_just_pressed("jump"):
		_start_dodge()


## Enemies call this. Returns true if the hit landed.
func take_hit(damage: float, from: Vector3, unblockable := false) -> bool:
	if invulnerable or (move == Move.DODGE and _move_time < DODGE.active):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	var facing_it := _facing(from)
	if not unblockable and facing_it and now - _block_pressed_at <= PARRY_WINDOW:
		_parried(from)
		return false
	if not unblockable and blocking and facing_it:
		damage *= BLOCK_DAMAGE_SHARE
		_spend(damage * 1.2)
		_knockback(from, 2.0)
		SfxBus.play("hit_thud", player.global_position, -8.0)  # muffled through the block
	else:
		_knockback(from, 4.0)
		_cancel_move()
		player.show_hit()
		SfxBus.play("hit_thud", player.global_position)
	health = maxf(0.0, health - damage)
	_regen_pause = 0.8
	health_changed.emit(health, max_health)
	player.flash(Color(1, 0.3, 0.2))
	if health <= 0.0:
		died.emit()
	return true


## The eruption: he can't be hurt, and every press slams the ground around him.
func set_erupting(on: bool) -> void:
	erupting = on
	invulnerable = on
	move = Move.NONE
	blocking = false
	_charging = false
	player.cancel_swing()
	if on:
		_set_lock(null)
		heal_full()


func _shockwave() -> void:
	_erupt_cooldown = ERUPT_COOLDOWN
	player.flash(Color(0.6, 0.5, 1.0))
	player.shockwave_ring(ERUPT_RANGE)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(player.global_position) <= ERUPT_RANGE:
			enemy.take_hit(ERUPT_DAMAGE, player.global_position)
			if enemy.has_method("stagger") and enemy.state != Guard.State.DOWN:
				enemy.stagger(1.5)


func heal_full() -> void:
	health = max_health
	stamina = max_stamina
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)


## The swing itself: the cut starts at once (the blade is already wound up) and the hit lands
## when the animation's blade crosses his front. Harder the longer the hold.
## A riposte is always full power.
func _swing(power: float) -> void:
	if _riposte_target:
		power = 1.0
	var cost := lerpf(16.0, 30.0, power)
	if stamina < cost * 0.5:
		player.cancel_swing()
		return  # too winded; Souls lets you swing on fumes, but not on nothing
	_spend(cost)
	move = Move.SWING
	# The hit lands when the blade crosses his front in the animation (a few hundredths of a second).
	_move_spec = {"windup": player.swing_hit_time(power), "active": 0.1, "recovery": lerpf(0.22, 0.48, power), "damage": lerpf(light_damage, heavy_damage, power)}
	_move_time = 0.0
	_hit_done = false
	blocking = false
	if lock_target:
		player.face(lock_target.global_position)
	player.release_swing(power)
	SfxBus.play("swing_whoosh", player.global_position, lerpf(-8.0, 0.0, power), 0.12)  # harder = louder


func _start_dodge() -> void:
	if stamina < DODGE.stamina * 0.5:
		return
	_spend(DODGE.stamina)
	move = Move.DODGE
	_move_spec = DODGE
	_move_time = 0.0
	_hit_done = true
	blocking = false
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_dodge_dir = Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, player.camera_pivot.global_rotation.y)
	if _dodge_dir.length() < 0.1:
		_dodge_dir = player.model.global_basis.z  # backstep
	_dodge_dir = _dodge_dir.normalized()
	# A roll faces where it goes; straight back is a hop, still facing the enemy.
	var backwards := _dodge_dir.dot(player.model.global_basis.z) > 0.6
	dodge_facing = Vector3.ZERO if backwards else _dodge_dir
	player.show_dodge(backwards)


func _advance_move(delta: float) -> void:
	var spec: Dictionary = _move_spec
	_move_time += delta
	if move == Move.DODGE:
		if _move_time < spec.active:
			player.velocity.x = _dodge_dir.x * DODGE_SPEED
			player.velocity.z = _dodge_dir.z * DODGE_SPEED
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, 30.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, 30.0 * delta)
		if not _hit_done and _move_time >= spec.windup:
			_hit_done = true
			_land_hit(spec.damage)
	if _move_time >= spec.windup + spec.active + spec.recovery:
		move = Move.NONE


func _land_hit(damage: float) -> void:
	var origin := player.global_position + Vector3.UP
	var forward := -player.model.global_basis.z
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = enemy.global_position + Vector3.UP - origin
		if to.length() > sword_reach + 0.4 or rad_to_deg(forward.angle_to(to)) > 60.0:
			continue
		var dealt := damage
		if enemy == _riposte_target:
			dealt *= RIPOSTE_MULTIPLIER
			_riposte_target = null
		enemy.take_hit(dealt, player.global_position)


func _parried(from: Vector3) -> void:
	_block_pressed_at = -10.0
	player.flash(Color(1, 1, 0.7))
	SfxBus.play("parry_clang", player.global_position + Vector3.UP, 0.0, 0.05)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(from) < 0.5 and enemy.has_method("stagger"):
			enemy.stagger(2.2)
			_riposte_target = enemy


func _toggle_lock() -> void:
	if lock_target:
		_set_lock(null)
		return
	var best: Node3D = null
	var best_score := INF
	var camera: Node3D = player.camera_pivot.get_node("SpringArm3D/Camera3D")
	var forward: Vector3 = -camera.global_basis.z
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.can_be_locked():
			continue
		var to: Vector3 = enemy.global_position - player.global_position
		if to.length() > lock_range:
			continue
		var score: float = to.length() + rad_to_deg(forward.angle_to(to)) * 0.1
		if score < best_score:
			best = enemy
			best_score = score
	_set_lock(best)


func _keep_lock() -> void:
	if lock_target and (not is_instance_valid(lock_target) or not lock_target.can_be_locked()
			or lock_target.global_position.distance_to(player.global_position) > lock_range * 1.4):
		_set_lock(null)


func _set_lock(target: Node3D) -> void:
	lock_target = target
	player.camera_pivot.lock_target = target
	lock_changed.emit(target)


func _regen(delta: float) -> void:
	if _regen_pause > 0.0:
		_regen_pause -= delta
		return
	if stamina < max_stamina and move == Move.NONE and not blocking:
		stamina = minf(max_stamina, stamina + stamina_regen * delta)
		stamina_changed.emit(stamina, max_stamina)


func _spend(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	_regen_pause = 0.6
	stamina_changed.emit(stamina, max_stamina)


func _knockback(from: Vector3, strength: float) -> void:
	var away := player.global_position - from
	away.y = 0.0
	away = away.normalized() * strength
	player.velocity.x = away.x
	player.velocity.z = away.z


func _cancel_move() -> void:
	if move != Move.DODGE:
		move = Move.NONE
	if _charging:
		_charging = false
		player.cancel_swing()


func _facing(point: Vector3) -> bool:
	var to := point - player.global_position
	to.y = 0.0
	return rad_to_deg((-player.model.global_basis.z).angle_to(to)) < 75.0


func _takedown_available() -> bool:
	var takedown := player.get_node_or_null("Takedown")
	return takedown != null and takedown.has_target()


## Combat buttons are registered here (like sprint), so the Input Map needn't be edited.
func _ensure_actions() -> void:
	_action("heavy_attack", [_key(KEY_G)], [_button(JOY_BUTTON_Y)])
	_action("block", [_mouse(MOUSE_BUTTON_RIGHT)], [_button(JOY_BUTTON_LEFT_SHOULDER)])
	_action("lock_on", [_key(KEY_Q)], [_button(JOY_BUTTON_RIGHT_STICK)])


func _action(name: String, keys: Array, buttons: Array) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name)
	for e in keys + buttons:
		InputMap.action_add_event(name, e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _mouse(index: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = index
	return e


func _button(index: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	return e
