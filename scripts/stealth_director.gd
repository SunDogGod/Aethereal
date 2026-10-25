extends Node
## Checkpoints and restarts for a level. Whenever Aeneas is spotted, falls off the world, or
## dies outside a story fight, the screen fades and he, Isabella and the guards go back to
## the last checkpoint. Guards he took down before that checkpoint stay down.

@export var player: Player

@onready var fade: ColorRect = $Screen/Fade
@onready var message: Label = $Screen/Message

var _checkpoint := Vector3.ZERO
var _resetting := false


func _ready() -> void:
	_checkpoint = player.global_position
	player.fell.connect(func() -> void: restart("FELL"))
	for guard: Guard in get_tree().get_nodes_in_group("guards"):
		guard.spotted.connect(_on_guard_spotted)
	for checkpoint in get_tree().get_nodes_in_group("checkpoints"):
		checkpoint.reached.connect(_on_checkpoint_reached)


func _on_checkpoint_reached(checkpoint: Node3D) -> void:
	if _resetting:
		return
	_checkpoint = checkpoint.global_position
	get_tree().call_group("guards", "commit_checkpoint")


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


## A story scene moved Aeneas somewhere new (into the hall): restarts happen there from now on,
## and agents already down stay down.
func move_checkpoint(at: Vector3) -> void:
	_checkpoint = at
	get_tree().call_group("guards", "commit_checkpoint")
