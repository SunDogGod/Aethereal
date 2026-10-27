extends Node
## Aeneas's knife takedowns. Get within reach of a guard who isn't looking your way
## and press attack (F, left click, or X on a gamepad).
## If another guard would see it happen, he spots you, unless Isabella can reach
## him: then she binds him with ink at the same moment. The prompt tells you which.

signal prompt_changed(text: String)  ## the HUD shows this; "" hides it

const REACH := 1.6         # metres from Aeneas to the guard
const FREEZE_TIME := 0.7   # seconds Aeneas is busy with a takedown

@onready var player: Player = get_parent()

var _prompt := ""
var _busy := false


func _physics_process(_delta: float) -> void:
	if _busy:
		return
	if not player.controls_enabled:
		_set_prompt("")  # no prompt during story scenes or a restart
		return
	var target := _find_target()
	var partner: Guard = null
	var exposed := false
	if target:
		var watchers := _witnesses_of(target)
		if player.companion and not watchers.is_empty():
			partner = player.companion.pick_bind_target(watchers)
		exposed = watchers.size() > (1 if partner else 0)
	_set_prompt(_prompt_for(target, partner, exposed))
	if target and player.controls_enabled and Input.is_action_just_pressed("attack"):
		_take_down(target, partner)


## True while a takedown is on offer (combat leaves the attack button to it then).
func has_target() -> bool:
	return _prompt != "" or _busy


func _take_down(target: Guard, partner: Guard) -> void:
	_busy = true
	_set_prompt("")
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	player.face(target.global_position)
	if partner:
		player.companion.bind(partner)
	player.stab()
	target.take_down()
	# Anyone still standing who saw it raises the alarm.
	for guard in _witnesses_of(target):
		guard.witness()
	await get_tree().create_timer(FREEZE_TIME, false).timeout  # false: a pause holds it too
	# A witness's restart (or a story scene) took him meanwhile: they hand control back.
	if not player.in_cutscene and not _restart_under_way():
		player.controls_enabled = true
	_busy = false


func _restart_under_way() -> bool:
	var scene := get_tree().current_scene
	var director := scene.find_child("StealthDirector", true, false) if scene else null
	return director != null and director.has_method("is_resetting") and director.is_resetting()


## The nearest guard in reach who isn't looking at Aeneas.
func _find_target() -> Guard:
	var best: Guard = null
	var best_distance := REACH
	for guard: Guard in get_tree().get_nodes_in_group("guards"):
		var distance := player.global_position.distance_to(guard.global_position)
		if distance <= best_distance and guard.is_unaware_of(player.global_position):
			best = guard
			best_distance = distance
	return best


## Other guards (still standing) who would see this guard go down.
func _witnesses_of(target: Guard) -> Array[Guard]:
	var watchers: Array[Guard] = []
	var chest := target.global_position + Vector3.UP * 1.2
	for guard: Guard in get_tree().get_nodes_in_group("guards"):
		if guard != target and guard.state != Guard.State.DOWN and guard.sees_point(chest) > 0.0:
			watchers.append(guard)
	return watchers


func _prompt_for(target: Guard, partner: Guard, exposed: bool) -> String:
	if target == null:
		return ""
	if exposed:
		return "F / X   Take down  (another agent will see!)"
	if partner:
		return "F / X   Take down  (Isabella binds the other)"
	return "F / X   Take down"


func _set_prompt(text: String) -> void:
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
