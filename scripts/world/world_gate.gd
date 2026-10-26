class_name WorldGate
extends Node3D
## A shutter in the big world that stays shut until the story has reached a zone, so nobody walks
## out of a chapter early (the service door behind the hall's stage opens once the story has
## reached Black Sand). Its children are the shutter: while shut they are solid, once open they
## are gone (hidden, and out of the physics).

@export var open_at := 3  ## opens when the story has reached the zone with this order (3 = Black Sand)


func _ready() -> void:
	var world := World.of(self)
	if world == null:
		return
	world.stage_changed.connect(_on_stage_changed)
	_on_stage_changed(world.stage)


func _on_stage_changed(stage: int) -> void:
	var open := stage >= open_at
	visible = not open
	process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
