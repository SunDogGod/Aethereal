extends Node
## The ground heaving: shakes whatever camera is showing (a story shot or the player's) for a
## while. A scene starts it with `[call Quake shake 3.0]` (seconds) and can cut it short with
## `[call Quake stop]`. The shake is strongest at once and dies away over the time given; it
## moves the camera's view offset, so the camera itself stays where the scene put it.

@export var strength := 0.25  ## metres of throw at the start

var _left := 0.0
var _total := 1.0
var _camera: Camera3D


func shake(seconds: float = 2.0) -> void:
	_left = maxf(seconds, 0.05)
	_total = _left


func stop() -> void:
	_settle()
	_left = 0.0


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	var cam := get_viewport().get_camera_3d()
	if cam != _camera:
		_settle()
		_camera = cam
	_left -= delta
	if _left <= 0.0 or cam == null:
		_settle()
		return
	var k := strength * clampf(_left / _total, 0.0, 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	cam.h_offset = k * sin(t * 61.0) * 0.7
	cam.v_offset = k * sin(t * 47.0 + 1.3)


func _settle() -> void:
	if is_instance_valid(_camera):
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
	_camera = null
