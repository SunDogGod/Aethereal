class_name SwingAssist
extends RefCounted
## The soft aim for swings without lock-on (lock-on is only a helper). When Aeneas swings or
## draws, he turns toward the nearest enemy roughly in front of him (or where the stick points)
## and takes a short step in if the enemy is just out of reach. The camera is never touched.
## PlayerCombat asks pick() when a swing starts and calls tick() until the blade lands.

const RANGE := 3.6        ## metres: how far away an enemy can be and still be aimed at
const ARC := 80.0         ## degrees either side of where he faces (or where the stick points)
const TURN_RATE := 25.0   ## radians per second he turns toward the enemy (90° in under 0.07 s)
const STEP := 0.7         ## the longest step in he takes toward an enemy just out of reach (m)
const STEP_SPEED := 7.0   ## metres per second of that step

var target: Node3D
var _step_left := 0.0


## Picks who this swing aims at: `prefer` (a parried enemy, open to a riposte) if he is in reach,
## else the enemy with the best mix of close and straight ahead. Null = swing where he faces.
func pick(player: Player, reach: float, prefer: Node3D = null) -> Node3D:
	target = null
	_step_left = 0.0
	var ahead := _reference(player)
	var best_score := INF
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.can_be_locked():
			continue
		var to: Vector3 = enemy.global_position - player.global_position
		if absf(to.y) > 1.2:
			continue  # on a ledge above or below: not this swing's business
		to.y = 0.0
		var distance := to.length()
		var angle := rad_to_deg(ahead.angle_to(to)) if distance > 0.01 else 0.0
		if distance > RANGE or angle > ARC:
			continue
		var score := distance + angle * 0.03
		if enemy == prefer:
			score -= 10.0
		if score < best_score:
			best_score = score
			target = enemy
	if target:
		var gap := _flat(target.global_position - player.global_position).length()
		_step_left = clampf(gap - reach * 0.7, 0.0, STEP)
	return target


## Each physics tick until the hit lands: turn toward the target and finish the step in.
func tick(player: Player, delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to := _flat(target.global_position - player.global_position)
	if to.length() < 0.05:
		return
	var want := atan2(-to.x, -to.z)
	var turn := wrapf(want - player.model.rotation.y, -PI, PI)
	player.model.rotation.y += clampf(turn, -TURN_RATE * delta, TURN_RATE * delta)
	if _step_left > 0.0:
		var dir := to.normalized()
		player.velocity.x = dir.x * STEP_SPEED
		player.velocity.z = dir.z * STEP_SPEED
		_step_left -= STEP_SPEED * delta


func clear() -> void:
	target = null
	_step_left = 0.0


## Where "in front" is: the stick's direction (turned to the camera) if it is held, else his facing.
static func _reference(player: Player) -> Vector3:
	var input := Vector2.ZERO
	if player.controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length() > 0.3:
		return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, player.camera_pivot.global_rotation.y).normalized()
	return _flat(-player.model.global_basis.z).normalized()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## True if an agent is fighting within `reach` metres: the jump button then rolls (PlayerCombat).
static func in_fight(player: Player, reach := 8.0) -> bool:
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		if enemy is Guard and not enemy.dormant and enemy.state in [Guard.State.FIGHTING, Guard.State.STAGGERED] \
				and enemy.global_position.distance_to(player.global_position) <= reach:
			return true
	return false
