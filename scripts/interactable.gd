class_name Interactable
extends Area3D
## Something Aeneas can look at. Stand inside this area, face it, and the HUD offers
## "E / Up: Look at the well"; press E (D-pad up on a gamepad) and the Story box shows a
## line or two of narration. The words come from `text` ("line 1|line 2"), or, when
## `text` is empty, from the `file` (data/inspect/<level>.txt: `node_name|line 1|line 2`)
## under this node's own name, so placing a new one is naming it and writing a line.

@export_multiline var text := ""      ## lines separated by "|"; empty = read from `file`
@export var label := "Look"           ## what the prompt says after "E / Up: "
@export var once := false             ## true = can only be read one time
@export_file("*.txt") var file := ""  ## where to look the text up by node name
@export var reach := 2.5              ## metres from Aeneas to this node's origin

const FACING := 0.3  ## cos of the widest angle that still counts as facing it (~72 degrees)

static var active: Interactable = null  ## the one showing its prompt right now
static var _files := {}                 ## path -> {node name: [lines]}, read once

var _player: Player = null
var _done := false


func _enter_tree() -> void:
	add_to_group("interactables")


func _ready() -> void:
	ensure_action()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	if active == self:
		_hide()


## A once-only spot that has been read (the save remembers it).
func is_read() -> bool:
	return once and _done


## Continue: it was read before the save.
func mark_read() -> void:
	_done = true


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	if not _can_offer():
		if active == self:
			_hide()
		return
	if active != null and active != self:
		return  # another one has the prompt
	active = self
	_player.get_node("Hud").show_hint("E / Up: " + label)
	if Input.is_action_just_pressed("interact"):
		_read()


## In range, facing it, not busy with a takedown or a scene, and not already read.
func _can_offer() -> bool:
	if _done or not _player.controls_enabled or _player.in_cutscene:
		return false
	var takedown := _player.get_node_or_null("Takedown")
	if takedown and takedown.has_target():
		return false
	if _fight_on():
		return false  # a look pauses the world, and a fight must not pause
	var to_me := global_position - _player.global_position
	to_me.y = 0.0
	if to_me.length() > reach:
		return false
	if to_me.length() < 0.6:
		return true  # standing on or under it: no need to face anything
	var forward := -_player.model.global_basis.z
	forward.y = 0.0
	return forward.normalized().dot(to_me.normalized()) > FACING


## True while Aeneas is locked on or any agent is fighting him.
func _fight_on() -> bool:
	var combat := _player.get_node_or_null("Combat")
	if combat and combat.lock_target:
		return true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Guard and enemy.state in [Guard.State.FIGHTING, Guard.State.STAGGERED]:
			return true
	return false


func _read() -> void:
	var lines := _lines()
	if lines.is_empty():
		push_warning("Interactable '%s' has no text" % name)
		return
	_hide()
	if once:
		_done = true
	# The autoload isn't named here (see CLAUDE.md): headless tests load this before it registers.
	var story := get_tree().root.get_node_or_null("Story")
	if story:
		story.narrate(lines)


func _hide() -> void:
	if active == self:
		active = null
	if is_instance_valid(_player):
		_player.get_node("Hud").show_hint("")


## The lines to show: `text` split on "|", or this node's entry in `file`.
func _lines() -> Array:
	var raw := text
	if raw.is_empty() and not file.is_empty():
		raw = _entries(file).get(name, "")
	var lines: Array = []
	for part: String in raw.split("|"):
		if not part.strip_edges().is_empty():
			lines.append(part.strip_edges())
	return lines


## Reads an inspect file once: `node_name|line 1|line 2` per line, # for notes.
static func _entries(path: String) -> Dictionary:
	if not _files.has(path):
		var entries := {}
		for raw: String in FileAccess.get_file_as_string(path).split("\n"):
			var line := raw.strip_edges()
			if line.is_empty() or line.begins_with("#") or not line.contains("|"):
				continue
			var cut := line.find("|")
			entries[line.substr(0, cut).strip_edges()] = line.substr(cut + 1)
		_files[path] = entries
	return _files[path]


## Registers the "interact" action (E, D-pad up) in code, like player_combat.gd does.
static func ensure_action() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	InputMap.action_add_event("interact", key)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_DPAD_UP
	InputMap.action_add_event("interact", button)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_player = body


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_hide()
		_player = null
