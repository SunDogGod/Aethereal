extends Interactable
## A bed Aeneas can sleep in: "E / Up: Rest", offered like a look-at spot (interactable.gd: in
## reach, facing it, never during a fight or a scene). Resting plays a story scene from
## `dialogue_file`: the scene heals him ([heal]) and the game saves by itself when it ends (Story's
## scene_done -> autosave.gd).
## When the story is waiting on a night's sleep, the sleep moves it on: once the `after` scene has
## played (a trigger plays that one), each rest plays the next of the `beats`, in order. Before
## that, and once the beats are used up, resting plays `rest_scene`.
## Continue: each of those scenes gets a small stand-in in the "story_triggers" group, so
## save_restore.gd marks the finished ones done, the same way it does a StoryTrigger's.

@export_file("*.txt") var dialogue_file := ""
@export var after := ""                    ## must have played before the beats start ("" = none)
@export var beats: PackedStringArray = []  ## one per rest, in order
@export var rest_scene := "rest"           ## any other rest: sleep, heal, save

var _played := {}  # scene name -> true, for `after` and the beats


func _ready() -> void:
	super()
	for scene_name: String in [after] + Array(beats):
		if scene_name != "":
			var stand_in := Played.new()
			stand_in.dialogue_file = dialogue_file
			stand_in.scene = scene_name
			stand_in.on_done = mark_played
			add_child(stand_in)
	# The autoload isn't named (see CLAUDE.md): headless tests load this before it registers.
	var story := get_tree().root.get_node_or_null("Story")
	if story and story.has_signal("scene_done"):
		story.scene_done.connect(_on_scene_done)


## Quietly notes a scene as played (Continue, through the stand-ins).
func mark_played(scene_name: String) -> void:
	_played[scene_name] = true


## The scene the next rest plays.
func next_scene() -> String:
	if after != "" and not _played.has(after):
		return rest_scene
	for beat: String in beats:
		if not _played.has(beat):
			return beat
	return rest_scene


## Pressed E: sleep (replaces the look-at's narration).
func _read() -> void:
	var story := get_tree().root.get_node_or_null("Story")
	if story == null:
		return
	_hide()
	story.play(dialogue_file, next_scene())


func _on_scene_done(path: String, scene_name: String) -> void:
	if path == dialogue_file:
		_played[scene_name] = true


## Stands in for a StoryTrigger in the "story_triggers" group: save_restore.gd reads its
## dialogue_file and scene, and calls mark_done() when the save says that scene has played.
class Played extends Node:
	var dialogue_file := ""
	var scene := ""
	var on_done: Callable

	func _enter_tree() -> void:
		add_to_group("story_triggers")

	func mark_done() -> void:
		on_done.call(scene)
