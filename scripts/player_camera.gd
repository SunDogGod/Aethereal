extends Node3D
## Third-person camera. Turns with the mouse or the right stick.
## This node turns left/right; the SpringArm3D below it tilts up/down and holds the camera.
## Esc / Start opens the pause menu (which frees the mouse); clicking the game window grabs
## the mouse again if something else let it go. The player's Settings (GameSettings: mouse
## and stick speed, invert Y) multiply the speeds below.
##
## Walls: the camera is pulled in when a wall gets between it and Aeneas, at once (it never
## shows the inside of a wall), then waits a moment and eases back out, so grazing a corner in a
## narrow alley doesn't make it pump in and out. Small things (vending machines, crates, rails,
## pipes, signs, AC units) are ignored: the camera passes them instead of jumping in front of
## Aeneas. A body with the metadata "camera_blocks" (true/false) overrides that guess.

@export var mouse_sensitivity := 0.003  ## radians per pixel of mouse movement
@export var stick_speed := 3.0          ## radians per second at full stick tilt
@export_range(-89.0, 0.0) var lowest_pitch := -70.0  ## degrees: how far down you can look
@export_range(0.0, 89.0) var highest_pitch := 30.0   ## degrees: how far up you can look
@export_group("Walls")
@export var hold_time := 0.35  ## seconds the camera stays pulled in before easing back out
@export var ease_in := 14.0  ## how quickly it glides in ahead of a wall (higher = faster)
@export var ease_out := 3.0  ## how quickly it eases back out (higher = faster)
@export var small_prop := 2.6  ## metres: anything smaller than this every way is ignored

@onready var spring_arm: SpringArm3D = $SpringArm3D

var lock_target: Node3D  ## set by PlayerCombat; the camera keeps this enemy in frame

var _reach := 4.5  # the arm's full length, from the scene (the Massacre's is shorter)
var _length := 4.5  # the length the camera is at now
var _hold := 0.0  # seconds left before it may ease back out
var _ignored: Array[RID] = []  # small props the camera passes through
var _verdicts := {}  # body instance id -> true when it blocks the camera
var _probe := SphereShape3D.new()  # the arm's own size: the camera may never pass this
var _cushion := SphereShape3D.new()  # fatter: starts the glide in a little early


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_reach = spring_arm.spring_length
	_length = _reach
	_probe.radius = 0.2
	if spring_arm.shape is SphereShape3D:
		_probe.radius = (spring_arm.shape as SphereShape3D).radius
	_cushion.radius = _probe.radius + 0.4


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


## Runs before the SpringArm3D (a child) does its own check, so the length set here is used
## this same physics tick. The arm still checks too, with the same props left out.
## A fatter probe (the cushion) sees a wall coming a little earlier, so the camera usually glides
## in before the thin one has to snap it in.
func _physics_process(delta: float) -> void:
	var room := _room(_probe)
	var cushion := _room(_cushion)
	# The cushion has no say when it already touches at Aeneas, and at most 1 m of say otherwise.
	var want := room if cushion <= 0.05 else clampf(cushion, room - 1.0, room)
	if room < _length:
		_length = room  # at once: never through a wall
		_hold = hold_time
	elif want < _length - 0.01:
		_length = lerpf(_length, want, 1.0 - exp(-ease_in * delta))
		_hold = hold_time
	elif _hold > 0.0:
		_hold -= delta
	else:
		_length = minf(want, lerpf(_length, want, 1.0 - exp(-ease_out * delta)))
	spring_arm.spring_length = maxf(_length, 0.05)


func _turn(yaw: float, pitch: float) -> void:
	rotation.y += yaw
	spring_arm.rotation.x = clampf(spring_arm.rotation.x + pitch, deg_to_rad(lowest_pitch), deg_to_rad(highest_pitch))


## How far back the camera can sit before something solid (and not small) is in the way.
func _room(probe: SphereShape3D) -> float:
	var mask := spring_arm.collision_mask
	if mask == 0 or not is_inside_tree():  # the developer fly mode turns the arm's mask off
		return _reach
	var space := get_world_3d().direct_space_state
	var from := spring_arm.global_position
	var motion := spring_arm.global_basis.z.normalized() * _reach
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.collision_mask = mask
	for attempt in 4:
		q.transform = Transform3D(Basis(), from)
		q.motion = motion
		q.exclude = _ignored
		var hit := space.cast_motion(q)
		if hit[1] >= 1.0:
			return _reach
		q.transform = Transform3D(Basis(), from + motion * hit[1])
		q.motion = Vector3.ZERO
		var info := space.get_rest_info(q)
		var body := instance_from_id(info.get("collider_id", 0)) if not info.is_empty() else null
		if body == null or _blocks(body):
			return maxf(_reach * hit[0] - 0.05, 0.0)
		_ignored.append(info.rid)
		spring_arm.add_excluded_object(info.rid)
	return _reach


## Does this body stop the camera? Big things (walls, floors, columns) do; small props don't.
func _blocks(body: Object) -> bool:
	var id := body.get_instance_id()
	if _verdicts.has(id):
		return _verdicts[id]
	var blocks := true
	if body is Node and (body as Node).has_meta("camera_blocks"):
		blocks = bool((body as Node).get_meta("camera_blocks"))
	elif body is Node3D:
		var dims := _size_of(body as Node3D)
		dims.sort()
		# Small every way (a vending machine, a crate), or thin and narrow (a rail, a pipe, a sign).
		blocks = not (dims[2] < small_prop or (dims[0] < 0.5 and dims[1] < 1.5))
	_verdicts[id] = blocks
	return blocks


## A body's size: a Block's own size, else the box around its collision shapes.
func _size_of(body: Node3D) -> Array[float]:
	var s := body.global_basis.get_scale()
	if "size" in body and body.get("size") is Vector3:
		var v: Vector3 = body.get("size") * s
		return [v.x, v.y, v.z]
	var box := AABB()
	var first := true
	for c in body.get_children():
		if c is CollisionShape3D and c.shape:
			var b: AABB = (c as CollisionShape3D).transform * c.shape.get_debug_mesh().get_aabb()
			box = b if first else box.merge(b)
			first = false
	if first:
		return [INF, INF, INF]
	var v := box.size * s
	return [v.x, v.y, v.z]
