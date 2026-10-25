extends Node
## How a guard fights once a fight is on (the "Fighter" node under a Guard).
## He closes in, circles a little, and swings: a red flash on his visor and a raised
## blade for attack_windup seconds, then the hit lands if Aeneas is still in front of him.
## Parry him in the flash's last moment; dodge when the blade drops.

@onready var guard: Guard = get_parent()

var _cooldown := 1.0
var _windup := -1.0   # > 0 while winding up
var _circle := 1.0
var _player: Player
var _path := PackedVector3Array()  # the way to Aeneas over the navigation mesh, if the level has one
var _repath := 0.0


func tick(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		_circle = 1.0 if randf() < 0.5 else -1.0
	if _player == null:
		return
	var to: Vector3 = _player.global_position - guard.global_position
	to.y = 0.0
	var distance := to.length()
	var dir := to.normalized()
	var face := dir
	if _windup < 0.0 and distance > guard.data.attack_range * 0.9:
		face = _chase_dir(delta, dir)  # walking: look where he goes
	guard.model.rotation.y = lerp_angle(guard.model.rotation.y, atan2(-face.x, -face.z), guard.data.turn_speed * delta)

	if _windup >= 0.0:
		_windup += delta
		guard.velocity.x = 0.0
		guard.velocity.z = 0.0
		if _windup >= guard.data.attack_windup:
			_land(distance, dir)
			_windup = -1.0
			_cooldown = guard.data.attack_cooldown * randf_range(0.8, 1.3)
		return

	_cooldown -= delta
	if distance > guard.data.attack_range * 0.9:
		guard.velocity.x = face.x * guard.data.fight_speed
		guard.velocity.z = face.z * guard.data.fight_speed
	else:
		# In range: sidestep a little, then swing when the cooldown is up.
		var side := dir.cross(Vector3.UP) * _circle
		guard.velocity.x = side.x * 1.2
		guard.velocity.z = side.z * 1.2
		if randf() < 0.01:
			_circle = -_circle
		if _cooldown <= 0.0:
			_begin_swing()
	_separate()


func _begin_swing() -> void:
	_windup = 0.0
	guard.telegraph(guard.data.attack_windup)


func _land(distance: float, dir: Vector3) -> void:
	guard.strike()
	if distance > guard.data.attack_range + 0.3:
		return
	if absf(_player.global_position.y - guard.global_position.y) > 1.5:
		return  # he is on a ramp or ledge above (or below): the blade can't reach through it
	var combat: PlayerCombat = _player.get_node_or_null("Combat")
	if combat:
		combat.take_hit(guard.data.attack_damage, guard.global_position, guard.data.unblockable)


## Called when the guard is staggered or killed mid-swing.
func interrupt() -> void:
	_windup = -1.0
	_cooldown = maxf(_cooldown, 0.6)


## Which way to walk to reach Aeneas: along the level's navigation mesh when it has one (so he
## goes round the stage's edge to its ramp instead of walking into it), straight at him when not.
func _chase_dir(delta: float, straight: Vector3) -> Vector3:
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.25
		var map: RID = guard.get_world_3d().navigation_map
		_path = PackedVector3Array()
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			_path = NavigationServer3D.map_get_path(map, guard.global_position, _player.global_position, true)
	while not _path.is_empty():
		var to := _path[0] - guard.global_position
		to.y = 0.0
		if to.length() > 0.35:
			return to.normalized()
		_path.remove_at(0)  # reached that corner: on to the next
	return straight


## Fighters keep a little apart instead of walking into one spot. They don't collide with each
## other (a crowd would jam the stage ramp and shove one another off their paths), so this soft
## push does the job.
func _separate() -> void:
	var push := Vector3.ZERO
	for other in guard.get_tree().get_nodes_in_group("enemies"):
		if other == guard or not (other is Guard) or other.state == Guard.State.DOWN or other.dormant:
			continue
		var away: Vector3 = guard.global_position - other.global_position
		away.y = 0.0
		var d := away.length()
		if d > 0.001 and d < 1.0:
			push += away / d * (1.0 - d)
	guard.velocity.x += push.x * 7.0
	guard.velocity.z += push.z * 7.0
