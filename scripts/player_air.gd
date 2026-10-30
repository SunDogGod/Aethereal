class_name PlayerAir
extends RefCounted
## Aeneas in the air: the double jump (once Kael has taught it) and what a landing does to him.
## A landing is judged by how fast he is falling when his feet touch: up to safe_landing_speed it
## does nothing, then it hurts more the closer it gets to fatal_landing_speed, and from there on it
## is a fall (back to the checkpoint). The double jump resets his fall speed, so one used just
## above the ground can save him from a long drop.

var _player: Player
var _air_jumps := 0         # double jumps left before he lands
var _fall_speed := 0.0      # how fast he was falling going into this frame's move
var _was_airborne := false  # he was in the air going into this frame's move


func _init(player: Player) -> void:
	_player = player


## Before move_and_slide: the speed he would land with this frame.
func before_move() -> void:
	_fall_speed = maxf(0.0, -_player.velocity.y)
	_was_airborne = not _player.is_on_floor()
	if not _was_airborne:
		_air_jumps = 1 if _player.double_jump_unlocked else 0


## A jump pressed in the air: true if he had a double jump left (and it is now spent).
func try_double_jump() -> bool:
	if _air_jumps <= 0 or not _player.double_jump_unlocked:
		return false
	_air_jumps -= 1
	return true


## After move_and_slide, on the frame he touches down: 0 = a safe landing, more = the damage it
## does, INF = a fatal fall. Story scenes never hurt him.
func landing_damage() -> float:
	if not _was_airborne or _player.in_cutscene:
		return 0.0
	_was_airborne = false
	var p := _player
	if _fall_speed <= p.safe_landing_speed:
		return 0.0
	if _fall_speed >= p.fatal_landing_speed:
		return INF
	var t := inverse_lerp(p.safe_landing_speed, p.fatal_landing_speed, _fall_speed)
	return lerpf(p.landing_damage_min, p.landing_damage_max, t)
