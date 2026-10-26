extends Area3D
## Plays a dialogue scene when Aeneas walks in. Pick the dialogue file and type the
## scene's name (the name between === marks in that file) in the Inspector.
## If the same scene plays some other way first (a fight's won scene), the trigger counts it as
## played and stays quiet.

@export_file("*.txt") var dialogue_file := ""
@export var scene := ""
@export var once := true  ## off = plays every time he walks in

var _done := false


func _enter_tree() -> void:
	add_to_group("story_triggers")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_listen()


## Its scene has played already (Continue calls this for the scenes finished before the save).
func mark_done() -> void:
	_done = true


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or (once and _done):
		return
	if not await player.land_safely() or not overlaps_body(player) or (once and _done):
		return  # he fell through on the way down a drop that sends him back
	_play()


## Starts the scene. The autoload isn't named (see CLAUDE.md): headless tests load this before it registers.
func _play() -> bool:
	var story := get_tree().root.get_node_or_null("Story")
	if story and story.play(dialogue_file, scene):
		_done = true
		return true
	return false


func _listen() -> void:
	var story := get_tree().root.get_node_or_null("Story")
	if story and story.has_signal("scene_done"):
		story.scene_done.connect(_on_scene_done)


func _on_scene_done(path: String, done_scene: String) -> void:
	if once and path == dialogue_file and done_scene == scene:
		_done = true
