extends Node
## Aeneas's footsteps (the "Footsteps" child of the Player): one sound every stride metres of
## ground covered, plus one on landing, with the sound of whatever he's standing on (read off
## the floor Block's material). Crouched steps are quieter. A child runs its physics step after
## its parent's, so velocity and is_on_floor() are already this frame's.

@export var stride_run := 1.6     ## metres of ground between footstep sounds at a run
@export var stride_crouch := 1.1  ## crouched: shorter, quieter steps
@export var stride_sprint := 1.9  ## sprinting: longer strides, so the steps stay just under 5 a second
@export var volume_db := -6.0     ## how loud a running step is (crouched: 8 dB quieter)

@onready var player: Player = get_parent()

var _step_distance := 0.0   # ground covered since the last footstep sound
var _was_on_floor := true


func _physics_process(delta: float) -> void:
	var on_floor := player.is_on_floor()
	if on_floor and not _was_on_floor:
		_step(volume_db + 2.0)  # landing
	_was_on_floor = on_floor
	var flat := Vector2(player.velocity.x, player.velocity.z).length()
	if not on_floor or flat < 0.5:
		_step_distance = stride_run * 0.4  # so the first step after a pause comes quickly
		return
	_step_distance += flat * delta
	var stride := stride_run
	if player.is_crouched:
		stride = stride_crouch
	elif flat > player.run_speed + 0.5:
		stride = stride_sprint
	if _step_distance >= stride:
		_step_distance -= stride
		_step(volume_db - 8.0 if player.is_crouched else volume_db)


func _step(volume: float) -> void:
	SfxBus.play("footstep_%s_%d" % [_floor_surface(), randi_range(1, 3)], player.global_position, volume)


## What he's standing on, read off the floor Block's material: "plates", "pavement" or "concrete".
func _floor_surface() -> String:
	var from := player.global_position + Vector3.UP * 0.9  # from the hips, down through the feet
	var query := PhysicsRayQueryParameters3D.create(from, player.global_position - Vector3.UP * 0.5, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "concrete"
	var mat: Variant = hit.collider.get("material")
	var path: String = mat.resource_path if mat is Material else ""
	if "metal_plates" in path or "grating" in path:
		return "plates"
	if "pavement" in path or "dev_grid" in path:
		return "pavement"
	return "concrete"
