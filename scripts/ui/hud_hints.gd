extends Control
## One-time control hints. The first time a mechanic matters (an agent starts to notice
## Aeneas, the first fight, running out of stamina, the first look-at prompt, a good stretch
## to sprint) a small card at the top left shows the buttons for a few seconds. Each hint
## shows once, ever: they are remembered in user://hints.cfg (delete that file, or call
## reset_all(), to see them again). Hints never take input, and they wait while a story
## scene plays or a restart fades.
## Test and screenshot scripts (anything run with -s) get no hints and never write the file,
## unless they set `in_tools` first (test_hud.gd does, with its own save_path).
## The words are in HINTS below: [keys, what they do]; keys are "keyboard / gamepad".

const HINTS := {
	"fight": {"title": "FIGHTING", "time": 10.0, "rows": [
		["Q / R3", "Lock on"],
		["F / X", "Attack: tap, or hold for a harder swing"],
		["RMB / LB", "Block: hold.  Parry: tap as the blow lands"],
		["Space / B", "Dodge roll (while locked on)"]]},
	"stamina": {"title": "STAMINA", "time": 6.0, "rows": [
		["", "Out of stamina. Hold off for a moment: it refills"]]},
	"crouch": {"title": "CROUCH", "time": 7.0, "rows": [
		["C / B", "Crouch: you are seen from half as far"]]},
	"look": {"title": "LOOK", "time": 5.0, "rows": [
		["E / Up", "Look at what the prompt names"]]},
	"sprint": {"title": "SPRINT", "time": 5.0, "rows": [
		["Shift / L3", "Hold to sprint"]]},
}
const POLL := 0.2              ## seconds between looks at the game
const SPRINT_AFTER := 1.5      ## seconds of running flat out before the sprint hint

static var save_path := "user://hints.cfg"
static var in_tools := false   ## a tool run (a -s script) that wants hints anyway

var player: Node               ## set by hud.gd
var combat: Node               ## set by hud.gd (may be null)
var prompt: Label              ## set by hud.gd: the prompt line (the look hint waits for it)
var tool_run := Engine.get_main_loop().get_script() != null  ## true under a -s test script
var active := true             ## false: no hints at all (a tool run that didn't ask for them)
var persist := true            ## write seen hints to save_path (never in a tool run)
var seen := {}                 ## hint name -> true
var queue: Array[String] = []
var current := ""              ## the hint on screen, "" for none (tests read it)

var _panel: PanelContainer
var _box: VBoxContainer
var _left := 0.0
var _poll := 0.0
var _running := 0.0
var _loaded := false


func _ready() -> void:
	name = "Hints"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(12, 36)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.035, 0.06, 0.82)  # MenuFx.INK
	style.border_width_left = 2
	style.border_color = MenuFx.ACCENT                # the amber bar the menus show on focus
	style.set_content_margin_all(6)
	style.content_margin_left = 9
	style.content_margin_right = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 3)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_box)
	_panel.modulate.a = 0.0
	_panel.visible = false
	active = in_tools or not tool_run
	persist = not tool_run


## Queues a hint unless it was seen before. True if it was queued.
func trigger(hint: String) -> bool:
	_load()
	if not active or not HINTS.has(hint) or seen.has(hint) or queue.has(hint) or current == hint:
		return false
	queue.append(hint)
	return true


## Forgets every hint, so they all show again.
static func reset_all() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _process(delta: float) -> void:
	if not active or not is_instance_valid(player):
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL
		_watch(POLL)
	var allowed: bool = player.get("controls_enabled") != false and player.get("in_cutscene") != true
	# A more urgent hint (earlier in HINTS) cuts in; the one it interrupts comes back afterwards.
	var next := _next()
	if current != "" and next != "" and HINTS.keys().find(next) < HINTS.keys().find(current):
		queue.push_front(current)
		current = ""
	if current == "" and allowed and _panel.modulate.a <= 0.0 and next != "":
		queue.erase(next)
		_show(next)
	if current != "":
		if allowed:
			_left -= delta
			if _left <= 0.0:
				current = ""
		_panel.modulate.a = move_toward(_panel.modulate.a, 1.0 if allowed and current != "" else 0.0, delta * 5.0)
		_panel.position.x = roundf(-8.0 * (1.0 - _panel.modulate.a))
	else:
		_panel.modulate.a = move_toward(_panel.modulate.a, 0.0, delta * 3.0)
	_panel.visible = _panel.modulate.a > 0.0


## The queued hint to show now: the first in HINTS order (most urgent first). The look hint
## waits for a prompt to be on screen, so it always sits beside the prompt it explains.
func _next() -> String:
	for hint: String in HINTS:
		if queue.has(hint) and (hint != "look" or (is_instance_valid(prompt) and prompt.visible)):
			return hint
	return ""


## Looks at public game state for the moments that call for a hint.
func _watch(step: float) -> void:
	if player.get("in_cutscene") == true:
		return
	var fight := _fight_on()
	if fight:
		trigger("fight")
	if combat and combat.get("stamina") != null and combat.stamina <= combat.max_stamina * 0.05:
		trigger("stamina")
	for guard in get_tree().get_nodes_in_group("guards"):
		if guard.get("state") == Guard.State.SUSPICIOUS and guard.get("suspicion") > 0.05:
			trigger("crouch")
			break
	# Sprint: he has been running flat out on open ground for a moment, not sprinting yet.
	var body := player as CharacterBody3D
	var flat := Vector2(body.velocity.x, body.velocity.z).length() if body else 0.0
	var run: float = player.get("run_speed") if player.get("run_speed") != null else 6.0
	if not fight and body and body.is_on_floor() and player.get("is_crouched") != true \
			and player.get("controls_enabled") != false and flat >= run * 0.85 \
			and flat <= run * 1.05 and not Input.is_action_pressed("sprint"):
		_running += step
		if _running >= SPRINT_AFTER:
			trigger("sprint")
	else:
		_running = 0.0


## True while Aeneas is locked on or an agent is fighting him.
func _fight_on() -> bool:
	if combat and combat.get("lock_target") != null:
		return true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.get("dormant") != true and enemy.get("state") in [Guard.State.FIGHTING, Guard.State.STAGGERED]:
			return true
	return false


func _show(hint: String) -> void:
	current = hint
	var spec: Dictionary = HINTS[hint]
	_left = spec.time
	seen[hint] = true
	_save()
	for child in _box.get_children():
		_box.remove_child(child)  # out now, so the card shrinks to the new hint
		child.queue_free()
	_box.add_child(_label(spec.title, 9, 3, MenuFx.ACCENT))
	for row: Array in spec.rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if row[0] != "":
			line.add_child(_key_cap(row[0]))
		line.add_child(_label(row[1], 10, 0, Color(0.85, 0.86, 0.9)))
		_box.add_child(line)
	_box.reset_size()
	_panel.reset_size()


## A key name in a small bordered box ("F / X").
func _key_cap(keys: String) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.custom_minimum_size.x = 58
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.62, 0.66, 0.76, 0.55)
	style.set_corner_radius_all(2)
	style.content_margin_left = 4
	style.content_margin_right = 4
	cap.add_theme_stylebox_override("panel", style)
	var text := _label(keys, 9, 1, MenuFx.BRIGHT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(text)
	return cap


func _label(text: String, size: int, spacing: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	if spacing > 0:
		var font := FontVariation.new()
		font.base_font = get_theme_default_font()
		font.spacing_glyph = spacing
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(save_path) == OK:
		for key in file.get_section_keys("seen") if file.has_section("seen") else PackedStringArray():
			seen[key] = true


func _save() -> void:
	if not persist:
		return
	var file := ConfigFile.new()
	for key: String in seen:
		file.set_value("seen", key, true)
	file.save(save_path)
