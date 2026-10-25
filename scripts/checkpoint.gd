extends Area3D
## A save spot for the sneaking. Walk into it, and being spotted later sends you back here.
## Put its origin on the floor where Aeneas should reappear.
## It can also hide something when reached, e.g. the round-up line once it has moved on.

signal reached(checkpoint: Node3D)

@export var hide_when_reached: Node3D


func _enter_tree() -> void:
	add_to_group("checkpoints")


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	if not await player.land_safely() or not overlaps_body(player):
		return  # he fell through on the way down a drop that sends him back
	if hide_when_reached:
		hide_when_reached.visible = false
	reached.emit(self)
