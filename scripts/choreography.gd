class_name Choreography
extends RefCounted
## Plays a guard's authored fight, beat by beat, instead of the fighter's usual close-circle-swing
## (the captain's set piece). The beats come from a text file (ChoreographyFile; the format is at
## the top of data/fights/captain.txt). Aeneas still fights him for real: hits land, parries
## stagger him, and the beat after a parry starts once he recovers. Hits don't break his beat
## (he is a boss), so trading blows loses: block, parry or dodge.
## Phase 2 starts by itself when he is empowered (the lieutenant's sacrifice).

const DAMAGE := {"swing": 1.0, "combo": 0.8, "heavy": 1.5, "finish": 1000.0}
const RECOVER := {"swing": 0.45, "combo": 0.5, "heavy": 0.7, "feint": 0.35, "finish": 0.9}
const ARC := 75.0  ## degrees either side of his facing that his blade covers
const CLOSE_TIMEOUT := 3.0  ## an attack beat chases this long, then cuts anyway

var guard: Guard
var fighter: Node    ## the guard's Fighter (enemy_fighter.gd): pathing, landing a blow
var fight: Node      ## the Fight (fight.gd): plays scenes from its dialogue file
var player: Player

var _phases: Dictionary
var _phase := 0
var _index := -1
var _beat := {}
var _t := 0.0
var _stage := ""            # attack beats: "close", "windup", "recover"
var _windups: Array = []    # wind-ups still to come in this attack beat
var _windup := 0.0
var _from := Vector3.ZERO   # where a "back" beat started
var _side := 1.0


func _init(p_guard: Guard, p_fighter: Node, p_fight: Node, phases: Dictionary) -> void:
	guard = p_guard
	fighter = p_fighter
	fight = p_fight
	_phases = phases


func tick(delta: float) -> void:
	if player == null:
		player = guard.get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var want := 2 if guard.invulnerable and _phases.has(2) else 1
	if want != _phase:
		_phase = want
		_lower_blade()
		_go(0)
	if _beat.is_empty():
		return
	_t += delta
	var to := player.global_position - guard.global_position
	to.y = 0.0
	var distance := to.length()
	var dir := to.normalized() if distance > 0.01 else -guard.model.global_basis.z
	match _beat.move:
		"guard":
			_hold(dir, delta)
			if _t >= ChoreographyFile.number(_beat, 0, 1.0):
				_next()
		"approach":
			_walk(fighter.chase_dir(delta, dir), guard.data.fight_speed, delta)
			if distance <= ChoreographyFile.number(_beat, 0, 2.0) or _t > 4.0:
				_next()
		"step_in":
			_walk(dir, guard.data.fight_speed * 2.2, delta, dir)
			if distance <= guard.data.attack_range * 0.75 or _t > 0.45:
				_next()
		"back":
			_walk(-dir, guard.data.fight_speed * 0.8, delta, dir)
			if guard.global_position.distance_to(_from) >= ChoreographyFile.number(_beat, 0, 1.5) or _t > 2.0:
				_next()
		"circle":
			var side := dir.cross(Vector3.UP) * _side
			var step := side * 1.6
			if distance > guard.data.attack_range * 1.6:
				step += dir * 1.2  # drifting out of reach: close a little as he circles
			_walk(step.normalized(), step.length(), delta, dir)
			if _t >= ChoreographyFile.number(_beat, 0, 1.5):
				_next()
		"scene":
			if _beat.args.size() > 0:
				fight.play_scene_once(_beat.args[0])
			_next()
		_:
			_attack(distance, dir, delta)


## A parry staggered him: the beat he was in is over; the next one starts when he recovers.
func interrupted() -> void:
	_lower_blade()
	_next()


## True if a hit should make him flinch (the animation only: his beat carries on regardless).
func flinches() -> bool:
	return _stage != "windup"


## swing / combo / heavy / feint / finish: close to striking range, wind up, cut, recover.
func _attack(distance: float, dir: Vector3, delta: float) -> void:
	match _stage:
		"close":
			if distance > guard.data.attack_range * 0.9 and _t < CLOSE_TIMEOUT:
				_walk(fighter.chase_dir(delta, dir), guard.data.fight_speed, delta)
				return
			_begin_windup()
		"windup":
			# He tracks Aeneas through most of the wind-up, then commits: a late sidestep or a
			# roll can still slip it.
			if _t < _windup * 0.75:
				_hold(dir, delta)
			else:
				_stop()
			if _t < _windup:
				return
			if _beat.move == "feint":
				_lower_blade()
			else:
				guard.strike()
				var unblockable: bool = _beat.move in ["heavy", "finish"] or guard.data.unblockable
				fighter.land_hit(guard.data.attack_damage * DAMAGE.get(_beat.move, 1.0), unblockable, ARC)
			_stage = "recover"
			_t = 0.0
		"recover":
			_stop()
			var rest: float = 0.12 if not _windups.is_empty() else RECOVER.get(_beat.move, 0.45)
			if _t < rest:
				return
			if _windups.is_empty():
				_next()
			else:
				_begin_windup()


func _begin_windup() -> void:
	_windup = maxf(0.15, float(_windups.pop_front()) if not _windups.is_empty() else 0.7)
	_stage = "windup"
	_t = 0.0
	guard.telegraph(_windup)
	if _beat.move in ["heavy", "finish"]:
		GuardLook.flash(guard, Color(1.0, 0.2, 0.08))  # the coat flashes red: this one can't be blocked


func _next() -> void:
	var phase: Dictionary = _phases.get(_phase, {})
	var beats: Array = phase.get("beats", [])
	var at := _index + 1
	if at >= beats.size():
		at = clampi(phase.get("loop", 0), 0, maxi(beats.size() - 1, 0))
	_go(at)


func _go(at: int) -> void:
	var beats: Array = _phases.get(_phase, {}).get("beats", [])
	_index = at
	_beat = beats[at] if at < beats.size() else {}
	_t = 0.0
	_stage = ""
	_windups = []
	_from = guard.global_position
	if _beat.is_empty():
		return
	match _beat.move:
		"circle":
			_side = -1.0 if "left" in _beat.args else 1.0
		"swing", "heavy", "feint":
			_windups = [ChoreographyFile.number(_beat, 0, {"heavy": 1.1, "feint": 0.5}.get(_beat.move, 0.75))]
			_stage = "close"
		"finish":
			_windups = [ChoreographyFile.number(_beat, 0, 1.0)]
			_stage = "close"
		"combo":
			for arg in _beat.args:
				if arg.is_valid_float():
					_windups.append(arg.to_float())
			if _windups.is_empty():
				_windups = [0.7, 0.4, 0.4]
			_stage = "close"


func _walk(dir: Vector3, speed: float, delta: float, face := Vector3.ZERO) -> void:
	guard.velocity.x = dir.x * speed
	guard.velocity.z = dir.z * speed
	_turn(face if face != Vector3.ZERO else dir, delta)


func _hold(dir: Vector3, delta: float) -> void:
	_stop()
	_turn(dir, delta)


func _stop() -> void:
	guard.velocity.x = 0.0
	guard.velocity.z = 0.0


func _turn(dir: Vector3, delta: float) -> void:
	if dir.length() > 0.01:
		guard.model.rotation.y = lerp_angle(guard.model.rotation.y, atan2(-dir.x, -dir.z), guard.data.turn_speed * delta)


func _lower_blade() -> void:
	if guard.animator:
		guard.animator.lower_blade()
