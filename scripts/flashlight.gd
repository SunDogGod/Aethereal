class_name Flashlight
extends Node3D
## A hand torch for dark places. Drop `scenes/flashlight.tscn` anywhere in a level: when the level
## starts it finds the Player (group "player") and clips a cone of light to his chest that points
## wherever the camera looks. L on the keyboard or D-pad down on a gamepad switches it on and off.
## A level without this node has no flashlight. It starts off unless `start_on` is ticked.
## The input action "flashlight" is registered here in code (like the combat actions), so the
## editor's Input Map can't lose it.

signal toggled(on: bool)

## Untick to keep the node in a level but take the torch away (L does nothing).
@export var enabled := true
## On when the level starts.
@export var start_on := false
@export var color := Color(1.0, 0.93, 0.8)
@export var energy := 6.0
## How far the beam reaches, in metres.
@export var reach := 30.0
## The cone's half-angle, in degrees (the soft edge is inside it).
@export var cone_degrees := 30.0
## Where the lamp sits on him: metres above his feet, and in front of his chest.
@export var chest_height := 1.3
@export var chest_forward := 0.3
## The beam dips this many degrees below the camera's aim, so it lights the floor ahead.
@export var dip_degrees := 10.0
## How quickly the beam swings round to follow the camera (higher = snappier).
@export var follow_speed := 14.0

var light: SpotLight3D
var _player: Node3D
var _camera: Camera3D
var _aim := Vector3.FORWARD


func _ready() -> void:
	ensure_action()
	# The Player joins the "player" group in his own _ready, which may run after this one.
	_attach.call_deferred()


static func ensure_action() -> void:
	if InputMap.has_action("flashlight"):
		return
	InputMap.add_action("flashlight")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_L
	InputMap.action_add_event("flashlight", key)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_DPAD_DOWN
	InputMap.action_add_event("flashlight", button)


func _attach() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		push_warning("Flashlight: no Player in this level")
		return
	_camera = _player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	light = SpotLight3D.new()
	light.name = "FlashlightBeam"
	light.top_level = true  # placed by hand every frame, so his turning model doesn't spin it
	light.light_color = color
	light.light_energy = energy
	light.spot_range = reach
	light.spot_angle = cone_degrees
	light.spot_angle_attenuation = 0.4
	light.spot_attenuation = 0.5
	light.shadow_enabled = false  # no real-time shadows in this game
	light.visible = start_on and enabled
	_player.add_child(light)  # freed with him
	_aim = -_player.global_basis.z
	_place(1.0)


func is_on() -> bool:
	return light != null and light.visible


func toggle() -> void:
	if light == null or not enabled:
		return
	light.visible = not light.visible
	SfxBus.play("ui_blip", light.global_position, -16.0)
	toggled.emit(light.visible)


func _process(delta: float) -> void:
	if light == null or not is_instance_valid(_player):
		return
	if Input.is_action_just_pressed("flashlight") and not _player.get("in_cutscene"):
		toggle()
	if light.visible:
		_place(1.0 - exp(-follow_speed * delta))


## Puts the lamp on his chest and turns it toward the camera's aim (eased by `blend`).
func _place(blend: float) -> void:
	var cam := _camera if is_instance_valid(_camera) else get_viewport().get_camera_3d()
	var want := -cam.global_basis.z if cam else -_player.global_basis.z
	want = want.rotated(want.cross(Vector3.UP).normalized(), -deg_to_rad(dip_degrees)) if absf(want.y) < 0.98 else want
	_aim = _aim.slerp(want.normalized(), clampf(blend, 0.0, 1.0)).normalized()
	var flat := Vector3(_aim.x, 0.0, _aim.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var origin := _player.global_position + Vector3.UP * chest_height + flat * chest_forward
	var up := Vector3.UP if absf(_aim.y) < 0.98 else Vector3.BACK
	light.global_transform = Transform3D(Basis.looking_at(_aim, up), origin)
