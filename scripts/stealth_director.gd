extends Node
## Checkpoints and restarts for a level. Whenever Aeneas is spotted, falls off the world, or
## dies outside a story fight, the screen fades and he, Isabella and the guards go back to
## the last checkpoint. Guards he took down before that checkpoint stay down.

## Emitted once a restart has put everyone back, as the screen fades in again. A lost fight
## waits for it before it starts again.
signal restarted
## Emitted when a checkpoint moves the restart point on (the game saves there: autosave.gd).
signal checkpoint_committed(checkpoint: Node3D)

@export var player: Player

@onready var fade: ColorRect = $Screen/Fade
@onready var message: Label = $Screen/Message

var _checkpoint := Vector3.ZERO
var _rank := -1  # how far on the last checkpoint is (see _rank_of); -1 = none reached yet
var _resetting := false


func _ready() -> void:
	_checkpoint = player.global_position
	player.fell.connect(func() -> void: restart("FELL"))
	for guard: Guard in get_tree().get_nodes_in_group("guards"):
		guard.spotted.connect(_on_guard_spotted)
	for checkpoint in get_tree().get_nodes_in_group("checkpoints"):
		checkpoint.reached.connect(_on_checkpoint_reached)


## Checkpoints only move forward: walking back through one he already passed (or one further
## up the list) keeps the restart where it is. Agents he took down stay down either way.
## During a story fight a checkpoint does nothing: the fight restarts where it started.
func _on_checkpoint_reached(checkpoint: Node3D) -> void:
	if _resetting or _fight_on():
		return
	get_tree().call_group("guards", "commit_checkpoint")
	var rank := _rank_of(checkpoint)
	if rank <= _rank:
		return
	_rank = rank
	_checkpoint = checkpoint.global_position
	checkpoint_committed.emit(checkpoint)


func _fight_on() -> bool:
	for fight in get_tree().get_nodes_in_group("fights"):
		if fight.get("active") == true:
			return true
	return false


## Where a restart puts him now (the save keeps it).
func checkpoint_position() -> Vector3:
	return _checkpoint


## True while a restart's fade is under way (nothing is saved meanwhile).
func is_resetting() -> bool:
	return _resetting


## Continue: the restart point the save had, and the checkpoints already reached count as passed,
## so walking back through one doesn't move it back.
func restore(reached: Array, at: Vector3) -> void:
	for checkpoint: Node in reached:
		_rank = maxi(_rank, _rank_of(checkpoint))
	move_checkpoint(at)


## How far on a checkpoint is: its place in the level's Checkpoints list (top to bottom in the
## Scene panel = the order he reaches them) and, in the big world, its zone's story order first.
static func _rank_of(checkpoint: Node) -> int:
	var n := checkpoint.get_parent()
	while n:
		if n is WorldZone:
			return (n as WorldZone).order * 1000 + checkpoint.get_index()
		n = n.get_parent()
	return checkpoint.get_index()


func _on_guard_spotted(_guard: Guard) -> void:
	restart("SPOTTED")


## Fade out, put everyone back to the last checkpoint, fade in. `reason` is the word shown.
func restart(reason := "SPOTTED") -> void:
	if _resetting:
		return
	_resetting = true
	player.controls_enabled = false
	message.text = reason
	message.visible = true
	var out := create_tween()
	out.tween_interval(0.8 if reason == "SPOTTED" else 0.3)  # a beat to see who saw you
	out.tween_property(fade, "color:a", 1.0, 0.5)
	await out.finished

	player.respawn_at(_checkpoint)
	get_tree().call_group("guards", "reset_to_checkpoint")
	var combat: PlayerCombat = player.get_node_or_null("Combat")
	if combat:
		combat.heal_full()
	message.visible = false
	await get_tree().create_timer(0.3, false).timeout  # false: it waits while the game is paused

	var back := create_tween()
	back.tween_property(fade, "color:a", 0.0, 0.5)
	player.controls_enabled = true
	_resetting = false
	restarted.emit()


## A story scene moved Aeneas somewhere new (into the hall): restarts happen there from now on,
## and agents already down stay down.
func move_checkpoint(at: Vector3) -> void:
	_checkpoint = at
	get_tree().call_group("guards", "commit_checkpoint")
