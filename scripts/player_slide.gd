class_name PlayerSlide
extends RefCounted
## The slide: while sprinting, press and hold crouch (C / B) and Aeneas drops into a feet-first
## slide that carries him for slide_time, slowing to a crouch walk. He can break out at any time:
## let go of crouch and he gets up running, or jump and he leaves the slide with its speed. If the
## button is still held when the slide runs out, he stays crouched.

var active := false
var _time := 0.0
var _air_time := 0.0  # seconds off the floor (shrinking to crouch height lifts him a frame)
var _dir := Vector3.ZERO
var _player: Player


func _init(player: Player) -> void:
	_player = player


## Crouch was pressed: start a slide if he is sprinting flat out. False = crouch as usual.
func try_start() -> bool:
	var p := _player
	var flat := Vector2(p.velocity.x, p.velocity.z)
	if p.is_crouched or p.rooted or not Input.is_action_pressed("sprint") or flat.length() < p.run_speed * 1.1:
		return false
	var combat: PlayerCombat = p.get_node_or_null("Combat")
	if combat and (combat.move != PlayerCombat.Move.NONE or combat.lock_target):
		return false
	active = true
	_time = 0.0
	_air_time = 0.0
	_dir = Vector3(flat.x, 0.0, flat.y).normalized()
	p._set_crouched(true)  # low: he slides under what he could crouch under
	if p.animator:
		p.animator.slide()
	return true


## Moves him while he slides, in place of running. False when he isn't sliding.
func move(delta: float) -> bool:
	if not active:
		return false
	var p := _player
	_air_time = 0.0 if p.is_on_floor() else _air_time + delta
	if p.velocity.y > 0.0 or _air_time > 0.12 or not p.controls_enabled:
		stop(false)  # jumped out, slid off an edge, or a scene took over
		return false
	if not Input.is_action_pressed("crouch"):
		stop(true)  # broke out: up and running
		return false
	_time += delta
	if _time >= p.slide_time:
		stop(false)  # still holding crouch: he stays down
		return false
	var speed := lerpf(p.slide_speed, p.crouch_speed, ease(_time / p.slide_time, 0.5))
	p.velocity.x = _dir.x * speed
	p.velocity.z = _dir.z * speed
	return true


## Ends the slide. `getup`: he stands (if there's headroom) with the get-up animation.
func stop(getup: bool) -> void:
	if not active:
		return
	active = false
	if getup:
		_player._set_crouched(false)
	if _player.animator:
		_player.animator.slide_end(getup and not _player.is_crouched)
