class_name Autosave
extends Node
## Saves the game by itself; there is no save menu. Story adds one of these to every story level
## it loads (and to the big world) once the title screen has switched recording on. It saves:
##   - at a checkpoint that moves the restart point on (he reappears on the checkpoint),
##   - at the end of a story scene (where he stands; a scene that starts a fight saves the
##     start of that fight, so Continue begins it again),
##   - when a story fight is won (where he stands, once he is on his feet),
##   - when he walks into the next zone of the big world (at that zone's Start).
## Never during a fight, a scene, a restart or a fall: a checkpoint, fight or zone save waits for a
## quiet moment. A small "saved" mark shows in the corner when the file is written (hud_saved.gd).
## The file itself: scripts/ui/save_game.gd. What goes in it: save_state.gd.

const SETTLE := 1.0  ## seconds after the level loads before a waiting save is written

var story_log := {}  ## dialogue file -> the scenes finished in it, in order (Continue replays these)

var _age := 0.0
var _wanted := ""            # a save waiting for a quiet moment: "checkpoint", "fight" or "zone"
var _wanted_spot := Transform3D.IDENTITY  # where Continue puts him ("fight": where he is then)
var _wanted_level: Node3D
var _story: Node
var _director: Node
var _player: Player


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_director = get_parent().get_node_or_null("StealthDirector")
	if _director and _director.has_signal("checkpoint_committed"):
		_director.checkpoint_committed.connect(_on_checkpoint)
	if get_parent() is World:
		(get_parent() as World).stage_changed.connect(_on_zone)
	for fight in get_tree().get_nodes_in_group("fights"):
		if fight.has_signal("fight_won"):
			fight.fight_won.connect(_on_fight_won)
	# The autoload isn't named (see CLAUDE.md). Its signal lets go of this node when it is freed.
	_story = get_tree().root.get_node_or_null("Story")
	if _story and _story.has_signal("scene_done"):
		_story.scene_done.connect(_on_scene_done)


func _physics_process(delta: float) -> void:
	_age += delta
	if _wanted == "" or _age < SETTLE or not is_instance_valid(_wanted_level) or not _quiet([]):
		return
	if _wanted == "fight":
		if not _player.is_on_floor():
			return
		_wanted_spot = Transform3D(_facing(), _player.global_position)
	_write(_wanted, _wanted_spot, _wanted_level)


## The director moved the restart point to a checkpoint: save there, facing the way he runs.
func _on_checkpoint(checkpoint: Node3D) -> void:
	var level := SaveState.level_of(checkpoint)
	if level and _player:
		_ask("checkpoint", Transform3D(_facing(), checkpoint.global_position), level)


## He walked into the next zone of the big world (the restart point is its Start now).
func _on_zone(stage: int) -> void:
	for zone: WorldZone in (get_parent() as World).zones:
		if zone.order == stage and zone.level:
			_ask("zone", zone.start_transform(get_parent() as Node3D), zone.level)


## A story fight was won. If it plays a scene next, that scene's own save comes instead.
func _on_fight_won() -> void:
	var level := _level_here()
	if level:
		_ask("fight", Transform3D.IDENTITY, level)


## A story scene ended normally. It counts (and saves) unless a fight it didn't start is going on
## (the captain's taunts mid-fight are not milestones).
func _on_scene_done(path: String, scene: String) -> void:
	var started: Array = _story.get("last_started_fights") if _story else []
	if _fight_on(started):
		return
	if not story_log.has(path):
		story_log[path] = []
	story_log[path].append(scene)
	var level := _level_here()
	if level and _quiet(started):
		_write("story", Transform3D(_facing(), _player.global_position), level)


## Story calls this for each story level it loads. `restore` is Continue's save ({} otherwise):
## the log of finished scenes goes on from it.
static func attach(scene: Node, restore: Dictionary) -> void:
	if not SaveGame.recording:
		return  # a test, or a level run on its own
	var autosave := Autosave.new()
	autosave.name = "Autosave"
	autosave.story_log = restore.get("story", {}).duplicate(true)
	scene.add_child(autosave)


func _ask(reason: String, spot: Transform3D, level: Node3D) -> void:
	_wanted = reason
	_wanted_spot = spot
	_wanted_level = level


func _write(reason: String, spot: Transform3D, level: Node3D) -> void:
	_wanted = ""  # a later save covers anything still waiting
	if SaveGame.write(SaveState.capture(get_parent(), story_log, reason, spot, level)):
		var hud := _player.get_node_or_null("Hud")
		if hud and hud.has_method("show_saved"):
			hud.show_saved()


## Nothing is in the middle of happening: no scene, restart, fall, takedown or fight (except the
## fights in `allowed`, which a scene that just ended started), and he is alive.
func _quiet(allowed: Array) -> bool:
	if not SaveGame.recording or SceneLoader.busy or _player == null:
		return false
	if _story and _story.playing:
		return false
	if _director and _director.has_method("is_resetting") and _director.is_resetting():
		return false
	if _player.falling_back or not _player.controls_enabled or _player.in_cutscene:
		return false
	var combat := _player.get_node_or_null("Combat")
	if combat and combat.health <= 0.0:
		return false
	return not _fight_on(allowed)


func _fight_on(allowed: Array) -> bool:
	for fight in get_tree().get_nodes_in_group("fights"):
		if fight.get("active") == true and not fight in allowed:
			return true
	return false


## The level he is in: the big world's zone, or the level running alone.
func _level_here() -> Node3D:
	return get_parent().level_here() if get_parent() is World else get_parent() as Node3D


## The way he faces, as a turn about the vertical (his model may be scaled).
func _facing() -> Basis:
	return Basis(Vector3.UP, _player.model.global_rotation.y)
