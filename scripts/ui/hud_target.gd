extends Control
## The enemy side of the HUD: while Aeneas is locked on, a small name and health bar float
## over his target; while a fight with a boss is on (a Fight node with `boss` set and
## `active` true), a long bar with the boss's name sits at the bottom of the screen.
## Built by hud.gd. Names come from each guard's GuardData (`display_name`).

const HudBar := preload("res://scripts/ui/hud_bar.gd")
const ENEMY_RED := Color(0.78, 0.2, 0.16)
const STEEL := Color(0.62, 0.66, 0.76)       ## a target hits can't hurt (the empowered captain)
const TRAIL := Color(1.0, 0.76, 0.4)         ## MenuFx.ACCENT
const BOSS_WIDTH := 360.0
const HEAD := 2.1                             ## metres above a guard's feet for his bar (just over his head)
const POLL := 0.25                            ## seconds between looks for an active boss fight

var lock_target: Node3D        ## set by hud.gd from Combat's lock_changed
var boss: Node3D               ## the boss of the active fight, or null (tests read it)
var lock_panel: Control
var lock_name: Label
var lock_bar: Node
var boss_panel: Control
var boss_name: Label
var boss_bar: Node

var _fights: Array[Node] = []
var _fights_scene: Node
var _poll := 0.0
var _lock_health := -1.0
var _lock_for: Node3D          # whose name and bar the lock panel shows now
var _boss_health := -1.0


func _ready() -> void:
	name = "Targets"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_lock()
	_build_boss()


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL
		_find_boss()
	_update_boss(delta)
	_update_lock()


## The display name of a guard: his GuardData's display_name, or "Agency Agent".
static func name_of(guard: Node) -> String:
	var data = guard.get("data")
	if data != null and "display_name" in data and str(data.display_name).strip_edges() != "":
		return str(data.display_name)
	return "Agency Agent"


## His health as a share (0..1), read from `health` and `data.health` (his maximum).
static func share_of(guard: Node) -> float:
	var data = guard.get("data")
	var top: float = data.health if data != null and "health" in data else 1.0
	var now = guard.get("health")
	if now == null or top <= 0.0:
		return 1.0
	return clampf(float(now) / top, 0.0, 1.0)


func _update_lock() -> void:
	var target := lock_target
	if not is_instance_valid(target) or target == boss:
		lock_panel.visible = false  # the boss already has his bar at the bottom
		_lock_health = -1.0
		return
	var camera := get_viewport().get_camera_3d()
	var head: Vector3 = target.global_position + Vector3.UP * HEAD
	if camera == null or camera.is_position_behind(head):
		lock_panel.visible = false
		return
	if target != _lock_for or _lock_health < 0.0:  # a new target: his name, his bar at once
		_lock_for = target
		_lock_health = share_of(target)
		lock_name.text = name_of(target).to_upper()
		lock_bar.set_share(_lock_health, true)
	var share := share_of(target)
	if share != _lock_health:
		lock_bar.set_share(share)
		_lock_health = share
	lock_bar.fill_color = STEEL if target.get("invulnerable") == true else ENEMY_RED
	lock_panel.visible = true
	var at := camera.unproject_position(head) - Vector2(lock_panel.size.x * 0.5, lock_panel.size.y)
	var screen := get_viewport_rect().size
	lock_panel.position = Vector2(clampf(roundf(at.x), 4.0, screen.x - lock_panel.size.x - 4.0),
			clampf(roundf(at.y), 4.0, screen.y - 60.0))


func _update_boss(delta: float) -> void:
	var on := is_instance_valid(boss)
	if on:
		var share := share_of(boss)
		if share != _boss_health:
			boss_bar.set_share(share, _boss_health < 0.0)
			_boss_health = share
		boss_bar.fill_color = STEEL if boss.get("invulnerable") == true else ENEMY_RED
	boss_panel.modulate.a = move_toward(boss_panel.modulate.a, 1.0 if on else 0.0, delta * 3.0)
	boss_panel.visible = boss_panel.modulate.a > 0.0


## Looks for a Fight node with a boss that is on right now. The list of fights is gathered
## once per level (any node with `boss` and `active` properties: fight.gd's public surface).
func _find_boss() -> void:
	var scene := get_tree().current_scene
	if scene != _fights_scene:
		_fights_scene = scene
		_fights.clear()
		if scene:
			for node in scene.find_children("*", "Node3D", true, false):
				if "boss" in node and "active" in node:
					_fights.append(node)
	var found: Node3D = null
	for fight in _fights:
		if not is_instance_valid(fight) or fight.get("active") != true:
			continue
		var who = fight.get("boss")
		# Not down, and not still waiting for his scene (can_be_locked covers both).
		if who is Node3D and is_instance_valid(who) and share_of(who) > 0.0 \
				and (not who.has_method("can_be_locked") or who.can_be_locked()):
			found = who
			break
	if found != boss:
		boss = found
		_boss_health = -1.0
		if boss:
			boss_name.text = name_of(boss).to_upper()


func _build_lock() -> void:
	lock_panel = Control.new()
	lock_panel.name = "LockTarget"
	lock_panel.size = Vector2(96, 18)
	lock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_panel.visible = false
	add_child(lock_panel)
	lock_name = _label(9, 2, MenuFx.BRIGHT)
	lock_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_name.size = Vector2(96, 11)
	lock_panel.add_child(lock_name)
	var frame := ColorRect.new()
	var fill := ColorRect.new()
	frame.add_child(fill)
	lock_panel.add_child(frame)
	lock_bar = HudBar.dress(frame, fill, Vector2(64, 3), ENEMY_RED, TRAIL)
	lock_bar.set_home(Vector2(14, 11))


func _build_boss() -> void:
	boss_panel = Control.new()
	boss_panel.name = "BossBar"
	boss_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	boss_panel.offset_left = -BOSS_WIDTH * 0.5 - 2.0
	boss_panel.offset_right = BOSS_WIDTH * 0.5 + 2.0
	boss_panel.offset_top = -78.0
	boss_panel.offset_bottom = -52.0
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.modulate.a = 0.0
	boss_panel.visible = false
	add_child(boss_panel)
	boss_name = _label(11, 4, MenuFx.BRIGHT)
	boss_name.position = Vector2(1, 0)
	boss_name.size = Vector2(BOSS_WIDTH, 14)
	boss_panel.add_child(boss_name)
	var tick := ColorRect.new()  # a short amber line under the name, like the menus' headers
	tick.color = Color(MenuFx.ACCENT, 0.8)
	tick.position = Vector2(2, 15)
	tick.size = Vector2(24, 1)
	boss_panel.add_child(tick)
	var frame := ColorRect.new()
	var fill := ColorRect.new()
	frame.add_child(fill)
	boss_panel.add_child(frame)
	boss_bar = HudBar.dress(frame, fill, Vector2(BOSS_WIDTH, 5), ENEMY_RED, TRAIL)
	boss_bar.set_home(Vector2(0, 18))


## A small HUD label: `size` px text, letters `spacing` px apart, with a dark outline.
func _label(size: int, spacing: int, color: Color) -> Label:
	var label := Label.new()
	var font := FontVariation.new()
	font.base_font = get_theme_default_font()
	font.spacing_glyph = spacing
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
