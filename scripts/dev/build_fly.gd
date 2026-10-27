extends Camera3D
## Build Mode's free camera. It starts where the game camera was and flies through everything.
##   WASD / left stick: fly (where you look)   Space / C, or the triggers: up / down
##   Shift / click the left stick: faster        hold the right mouse button / right stick: look
##   mouse wheel: flying speed
## It runs while the game is paused and ignores the game's time scale.

const SPEEDS := [2.0, 4.0, 8.0, 16.0, 32.0]  ## metres per second, the wheel steps through these
const FAST := 3.0          ## Shift multiplies the speed by this
const MOUSE_TURN := 0.0035 ## radians per pixel of mouse movement while looking
const STICK_TURN := 2.4    ## radians per second at full right-stick tilt
const DEAD := 0.18         ## stick dead zone

var speed_index := 2
var enabled := true        ## off while the search box has the keyboard
var looking := false       ## the right mouse button is held

var _yaw := 0.0
var _pitch := 0.0


## Starts at a camera's view (the game's) with the same lens and look.
func start_from(other: Camera3D) -> void:
	if other:
		global_transform = other.global_transform
		fov = other.fov
		near = maxf(other.near, 0.05)
		cull_mask = other.cull_mask
		environment = other.environment
		attributes = other.attributes
	far = maxf(far, 500.0)
	var e := global_basis.get_euler()
	_pitch = clampf(e.x, -1.5, 1.5)
	_yaw = e.y
	_apply_turn()


func _process(delta: float) -> void:
	if not current:
		return
	var dt := delta / maxf(Engine.time_scale, 0.01)  # real seconds, whatever the time scale
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > DEAD:
		_yaw -= stick.x * STICK_TURN * dt
		_pitch -= stick.y * STICK_TURN * dt
		_apply_turn()
	if not enabled:
		return
	var move := Vector3.ZERO
	var ctrl := Input.is_key_pressed(KEY_CTRL)
	if not ctrl:  # Ctrl+D copies, Ctrl+Z undoes: those aren't flying
		move.x = _key(KEY_D) - _key(KEY_A)
		move.z = _key(KEY_S) - _key(KEY_W)
		move.y = _key(KEY_SPACE) - _key(KEY_C)
	var left := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if left.length() > DEAD:
		move.x += left.x
		move.z += left.y
	move.y += Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if move.length_squared() < 0.0001:
		return
	var fast := Input.is_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_STICK)
	var flat := Basis(Vector3.UP, _yaw)
	var dir := global_basis * Vector3(move.x, 0, move.z) + flat * Vector3(0, move.y, 0)
	global_position += dir.limit_length(1.0) * SPEEDS[speed_index] * (FAST if fast else 1.0) * dt


## Mouse look and the wheel. Returns true when it used the event.
func handle(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			looking = mb.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE
			return true
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var step := 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			speed_index = clampi(speed_index + step, 0, SPEEDS.size() - 1)
			return true
	elif event is InputEventMouseMotion and looking:
		var rel := (event as InputEventMouseMotion).relative
		_yaw -= rel.x * MOUSE_TURN
		_pitch -= rel.y * MOUSE_TURN
		_apply_turn()
		return true
	return false


## Lets go of the mouse (leaving Build Mode while looking around).
func stop_looking() -> void:
	if looking:
		looking = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func speed() -> float:
	return SPEEDS[speed_index]


func _apply_turn() -> void:
	_pitch = clampf(_pitch, -1.55, 1.55)
	global_basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))


func _key(k: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(k) else 0.0
