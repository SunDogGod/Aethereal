extends Node3D
## Third-person camera. Turns with the mouse or the right stick.
## This node turns left/right; the SpringArm3D below it tilts up/down and
## pulls the camera in when a wall gets between it and Aeneas.
## Esc / Start opens the pause menu (which frees the mouse); clicking the game window grabs
## the mouse again if something else let it go. The player's Settings (GameSettings: mouse
## and stick speed, invert Y) multiply the speeds below.

@export var mouse_sensitivity := 0.003  ## radians per pixel of mouse movement
@export var stick_speed := 3.0          ## radians per second at full stick tilt
@export_range(-89.0, 0.0) var lowest_pitch := -70.0  ## degrees: how far down you can look
@export_range(0.0, 89.0) var highest_pitch := 30.0   ## degrees: how far up you can look

@onready var spring_arm: SpringArm3D = $SpringArm3D

var lock_target: Node3D  ## set by PlayerCombat; the camera keeps this enemy in frame


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_instance_valid(lock_target):
		# screen_relative ignores the low-res stretch, so speed is the same at any window size.
		var speed := mouse_sensitivity * GameSettings.mouse_sensitivity
		_turn(-event.screen_relative.x * speed, -event.screen_relative.y * speed * GameSettings.y_sign())
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if is_instance_valid(lock_target):
		var to := lock_target.global_position - global_position
		var yaw := atan2(-to.x, -to.z)
		rotation.y = lerp_angle(rotation.y, yaw, 8.0 * delta)
		spring_arm.rotation.x = lerpf(spring_arm.rotation.x, deg_to_rad(-18.0), 4.0 * delta)
		return
	var stick := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	var speed := stick_speed * GameSettings.stick_sensitivity * delta
	_turn(-stick.x * speed, -stick.y * speed * GameSettings.y_sign())


func _turn(yaw: float, pitch: float) -> void:
	rotation.y += yaw
	spring_arm.rotation.x = clampf(spring_arm.rotation.x + pitch, deg_to_rad(lowest_pitch), deg_to_rad(highest_pitch))
