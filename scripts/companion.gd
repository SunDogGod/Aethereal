class_name Companion
extends Node3D
## A companion who walks in the leader's footsteps (her Model's Animator plays the walking). The leader leaves a trail of
## points as he moves; she follows that trail, so she takes the same ramps,
## catwalks and jumps, and never gets stuck on a corner.
## She walks a little to the side of his trail, so she isn't standing between him
## and the camera. When he crouches she crouches too (after a moment) and tucks in
## closer, so she hides with him. Enemies will ignore her; only the leader can be spotted.

@export var leader: Player              ## who to follow: pick the Player in the Inspector
@export var follow_distance := 2.2      ## metres behind him, measured along his path
@export var crouch_follow_distance := 1.1
@export var side_offset := 0.8          ## metres to the side of his path (less if a wall or an edge is there)
@export var speed := 6.5                ## a little faster than Aeneas, so she keeps up
@export var catch_up_speed := 11.0      ## when she's far behind
@export var catch_up_after := 12.0      ## metres behind before she hurries
@export var reaction_time := 0.15       ## seconds before she copies a crouch
@export var turn_speed := 10.0
@export var bind_reach := 12.0          ## how far her ink reaches when she binds a guard

const STEP := 0.25  # metres between trail points

@onready var model: Node3D = $Model
@onready var animator: CharacterAnimator = get_node_or_null("Model/Animator")  ## walks, crouches, casts

var is_crouched := false
var _anchor := Vector3.ZERO       # her place on his trail; she stands a little to the side of it
var _side := Vector3.ZERO         # that sideways shift, eased so she doesn't snap at corners
var _trail: Array[Vector3] = []   # [0] is always her anchor; the end is his newest step
var _hold_facing := 0.0           # seconds she keeps facing a guard she just bound


func _ready() -> void:
	_anchor = global_position
	if leader:
		_join()  # no leader: he just stands there (a figure in a scene)


## Starts following the leader: at _ready, or later when the big world hands her one (World.carry,
## once the story reaches her zone).
func _join() -> void:
	_anchor = global_position
	_trail = [_anchor, leader.global_position]
	if not leader.crouched_changed.is_connected(_on_leader_crouched_changed):
		leader.crouched_changed.connect(_on_leader_crouched_changed)
	if not leader.respawned.is_connected(_on_leader_respawned):
		leader.respawned.connect(_on_leader_respawned)
	leader.companion = self  # so his takedowns can call on her ink


func _physics_process(delta: float) -> void:
	if leader == null:
		return
	if _trail.is_empty():
		_join()  # the leader arrived after _ready (see _join)
	var wanted := crouch_follow_distance if is_crouched else follow_distance
	# He came back to her: forget the path he took, so she doesn't walk out and back along it.
	var offset := leader.global_position - _anchor
	if offset.length() < wanted and absf(offset.y) < 0.5:
		_trail = [_anchor]
	if leader.global_position.distance_to(_trail.back()) >= STEP:
		_trail.append(leader.global_position)

	var gap := _distance_to_leader() - wanted
	var moved := Vector3.ZERO
	if gap > 0.05:
		var pace := catch_up_speed if gap > catch_up_after else speed
		moved = _walk(minf(gap, pace * delta))

	_side = _side.lerp(_pick_side(), 6.0 * delta)
	global_position = _anchor + _side
	# Stand on whatever floor is under her: the trail has his height, so a step to the side of a
	# slope (or a ledge he dropped from) would otherwise leave her in the air.
	var down := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6, global_position + Vector3.DOWN * 4.0, 1)
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(down)
	if not floor_hit.is_empty():
		global_position.y = floor_hit.position.y
	if _hold_facing > 0.0:
		_hold_facing -= delta
	else:
		_turn_towards(moved, delta)


## Of these guards, the nearest one her ink can reach (in range, and she can see him), or null.
func pick_bind_target(candidates: Array[Guard]) -> Guard:
	var best: Guard = null
	var best_distance := bind_reach
	var head := global_position + Vector3.UP * 1.6
	for guard in candidates:
		var chest := guard.global_position + Vector3.UP * 1.2
		var distance := head.distance_to(chest)
		if distance > best_distance:
			continue
		var query := PhysicsRayQueryParameters3D.create(head, chest, 1)  # walls and floors only
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			best = guard
			best_distance = distance
	return best


## Binds a guard with ink: she turns to him and slashes the air with her brush; the stroke hangs
## in the air as ink (ink_stroke.gd), a drop flies from its end to him, and he drops in a glyph.
## He stops dead at once, so he can't raise the alarm while the stroke is drawn.
func bind(guard: Guard) -> void:
	var stroke := InkStroke.new()
	stroke.finish = CharacterAnimator.CAST_HIT + 0.02
	guard.bind_with_ink(stroke.finish + stroke.fly_time)
	var look := guard.global_position - global_position
	model.rotation.y = atan2(-look.x, -look.z)
	_hold_facing = 0.8
	if animator:
		animator.cast()  # the slash
	stroke.brush = model.get_node_or_null("Brush")
	stroke.target = guard.ink_glyph.global_position
	add_child(stroke)


## Distance to the leader along the trail (not in a straight line).
func _distance_to_leader() -> float:
	var length := 0.0
	for i in range(1, _trail.size()):
		length += _trail[i - 1].distance_to(_trail[i])
	return length + _trail.back().distance_to(leader.global_position)


## Moves her anchor along the trail and drops the points she has passed.
func _walk(distance: float) -> Vector3:
	var start := _anchor
	while distance > 0.0 and _trail.size() > 1:
		var next := _trail[1]
		var to_next := _anchor.distance_to(next)
		if to_next <= distance:
			_anchor = next
			distance -= to_next
			_trail.remove_at(1)
		else:
			_anchor = _anchor.move_toward(next, distance)
			distance = 0.0
	_trail[0] = _anchor
	return _anchor - start


## Which side of his path to walk on: his right if there's room, else his left, else right on it.
func _pick_side() -> Vector3:
	var ahead := (_trail[1] if _trail.size() > 1 else leader.global_position) - _anchor
	ahead.y = 0.0
	if ahead.length() < 0.01:
		return _side  # standing still: stay where she is
	var right := ahead.cross(Vector3.UP).normalized()
	for dir in [right, -right]:
		var room := _room_towards(dir)
		if room > 0.2:
			return dir * room
	return Vector3.ZERO


## How far she can step sideways from her anchor: not into a wall, and not off an edge.
func _room_towards(dir: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var waist := _anchor + Vector3.UP
	var room := side_offset
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(waist, waist + dir * (side_offset + 0.3), 1))
	if not wall.is_empty():
		room = minf(room, waist.distance_to(wall.position) - 0.3)
	var foot := _anchor + dir * room + Vector3.UP * 0.5
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(foot, foot + Vector3.DOWN * 1.5, 1))
	if ground.is_empty():
		return 0.0
	return maxf(room, 0.0)


func _turn_towards(moved: Vector3, delta: float) -> void:
	var look := Vector3(moved.x, 0.0, moved.z)
	if look.length() < 0.001:
		# Standing still: face him.
		look = leader.global_position - global_position
		look.y = 0.0
	if look.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-look.x, -look.z), turn_speed * delta)


func _on_leader_crouched_changed(crouched: bool) -> void:
	await get_tree().create_timer(reaction_time).timeout
	if leader.is_crouched != crouched:
		return  # he changed his mind while she was reacting
	is_crouched = crouched  # the Animator sees this and crouches the model


func _on_leader_respawned() -> void:
	# He fell or was sent back to a checkpoint: she reappears beside him, not inside him.
	await get_tree().physics_frame  # let him settle on the ground first
	_anchor = _free_spot_near(leader.global_position)
	_side = Vector3.ZERO
	_trail = [_anchor, leader.global_position]
	global_position = _anchor


## A spot about a metre beside him (as the camera sees it, so she isn't blocking the view),
## with floor under it at his own level (not a bed or crate top) and no wall in between.
## Behind him only if both sides are blocked.
func _free_spot_near(point: Vector3) -> Vector3:
	var right := leader.camera_pivot.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var back := right.cross(Vector3.UP)
	var space := get_world_3d().direct_space_state
	for dir in [right, -right, (right + back).normalized(), (back - right).normalized(), back]:
		var spot: Vector3 = point + dir * 1.2
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP, spot + Vector3.UP, 1))
		var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 0.5, spot + Vector3.DOWN * 4.0, 1))
		if wall.is_empty() and not ground.is_empty() and absf(ground.position.y - point.y) < 0.3:
			return Vector3(spot.x, ground.position.y, spot.z)
	return point
