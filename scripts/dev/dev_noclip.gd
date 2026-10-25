extends Node
## Noclip (DevTools/Cheats/Noclip): Aeneas flies through walls and floors.
##   Move: the movement keys / left stick (relative to the camera, like running)
##   Up: Space / A        Down: C or Ctrl / B        Faster: hold Shift / click the left stick
## While it is on, his own movement code is switched off, he has no collision (walls, guards,
## triggers and checkpoints all ignore him) and the camera arm stops bumping into walls.
## Switching it off puts all of that back and sets him down on the floor below him.

const SPEED := 8.0   ## metres per second
const FAST := 22.0   ## holding sprint

var on := false
var cheats: Node     ## DevTools/Cheats: finds the floor when he lands

var _player = null   # the Player (untyped: we only use what he shows in public)
var _layer := 0
var _mask := 0
var _arm_mask := 0


func set_on(value: bool) -> void:
	if value == on:
		return
	if value:
		_start()
	else:
		_land()


## The level is being replaced: forget this Aeneas without touching him.
func forget() -> void:
	on = false
	_player = null


func _start() -> void:
	_player = cheats.player()
	if _player == null:
		return
	_layer = _player.collision_layer
	_mask = _player.collision_mask
	_player.collision_layer = 0
	_player.collision_mask = 0
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(false)  # no gravity, no running: we move him here
	var arm := _arm()
	if arm:
		_arm_mask = arm.collision_mask
		arm.collision_mask = 0
	on = true


func _land() -> void:
	on = false
	if not is_instance_valid(_player):
		return
	_player.collision_layer = _layer
	_player.collision_mask = _mask
	var arm := _arm()
	if arm:
		arm.collision_mask = _arm_mask
	_player.set_physics_process(true)
	var ground: Variant = cheats.find_floor(_player.global_position)
	# Nothing to stand on below him (the void, or deep inside a block): back to the checkpoint.
	_player.respawn_at(ground if ground != null else cheats.places.checkpoint_at)
	_player = null


func _physics_process(delta: float) -> void:
	if not on:
		return
	if not is_instance_valid(_player):
		on = false
		return
	if not _player.get("controls_enabled"):
		return  # a story scene or a restart has him
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var pivot := _player.get_node_or_null("CameraPivot") as Node3D
	var yaw := pivot.global_rotation.y if pivot else 0.0
	var move := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)
	move.y = Input.get_action_strength("jump") - Input.get_action_strength("crouch")
	var fast := InputMap.has_action("sprint") and Input.is_action_pressed("sprint")
	_player.global_position += move.limit_length(1.0) * (FAST if fast else SPEED) * delta
	_player.velocity = Vector3.ZERO
	if Vector2(move.x, move.z).length() > 0.1 and _player.has_method("face"):
		_player.face(_player.global_position + Vector3(move.x, 0.0, move.z))


func _arm() -> SpringArm3D:
	if not is_instance_valid(_player):
		return null
	return _player.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
