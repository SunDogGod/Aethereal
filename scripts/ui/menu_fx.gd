class_name MenuFx
extends RefCounted
## Shared bits for every menu: the colours, the menu sounds, and WASD navigation.
## Change a colour here and the title, pause and settings screens all follow.

const DIM := Color(0.62, 0.66, 0.76)        ## menu text without focus
const BRIGHT := Color(0.98, 0.96, 0.91)     ## menu text with focus
const ACCENT := Color(1.0, 0.76, 0.4)       ## the amber of the lit windows
const INK := Color(0.03, 0.035, 0.06, 0.9)  ## panel fill
const LINE := Color(0.45, 0.5, 0.66, 0.45)  ## panel border

## The pause menu hands over its own sound player: the Sfx autoload stops with the paused
## game, so blips in the pause menu play through this one instead.
static var paused_player: AudioStreamPlayer

static var _quiet_frame := -1


## Gives a control the focus without the blip (for the first highlight when a menu opens).
static func focus_quietly(control: Control) -> void:
	_quiet_frame = Engine.get_process_frames()
	control.grab_focus()


## The menu sounds: a soft wooden tok when the highlight moves (ui_blip), two warm notes when
## something is chosen (ui_choose). Both are quiet on purpose (the author, 2026-10-26: no pings).
static func blip(from: Node, chosen := false) -> void:
	if Engine.get_process_frames() == _quiet_frame or not from.is_inside_tree():
		return
	var sound := "ui_choose" if chosen else "ui_blip"
	var volume := -5.0 if chosen else -10.0
	if from.get_tree().paused and is_instance_valid(paused_player):
		var path := "res://audio/%s.wav" % sound
		if ResourceLoader.exists(path):
			paused_player.stream = load(path)
		paused_player.volume_db = volume
		paused_player.pitch_scale = 1.0
		paused_player.play()
	else:
		SfxBus.play(sound, Vector3.INF, volume, 0.02)


## WASD moves the highlight and changes sliders too (the arrows, the D-pad and the left stick
## already do, through Godot's ui_* actions). Returns true when it used the event.
static func extra_nav(event: InputEvent, viewport: Viewport) -> bool:
	if not (event is InputEventKey) or not event.is_pressed():
		return false
	var focused := viewport.gui_get_focus_owner()
	if focused == null or not focused.is_visible_in_tree():
		return false
	var side := -1
	if event.is_action("move_forward"):
		side = SIDE_TOP
	elif event.is_action("move_back"):
		side = SIDE_BOTTOM
	elif event.is_action("move_left") or event.is_action("move_right"):
		var step := -1.0 if event.is_action("move_left") else 1.0
		if focused is Range:
			focused.value += step * focused.step
			return true
		if focused is BaseButton and focused.toggle_mode:
			focused.button_pressed = not focused.button_pressed
			return true
		side = SIDE_LEFT if step < 0.0 else SIDE_RIGHT
	if side < 0:
		return false
	var next := focused.find_valid_focus_neighbor(side)
	if next:
		next.grab_focus()
	return true


## A soft horizontal glow, ACCENT on the left fading out to the right (focus highlights).
static func glow_texture(strength := 0.22) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(ACCENT, strength))
	gradient.set_color(1, Color(ACCENT, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 64
	tex.height = 4
	return tex
