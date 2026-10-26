extends Node3D
## A fight: the Guards under this node, started by a story scene ([fight NodeName]).
## When they're all down it plays `won_scene`; if Aeneas dies it plays `death_scene`,
## or, with none set, sends him back to the last checkpoint. A `boss` can have a
## `boss_half_scene` that plays the first time his health drops under half.
## With a `choreography_file`, its guards play authored beats instead of fighting freely (the captain).

@export_file("*.txt") var dialogue_file := ""
@export var won_scene := ""
@export var death_scene := ""   ## "" = restart at the checkpoint instead
@export var boss: Guard
@export var boss_half_scene := ""
## Optional: an Area3D (e.g. a StoryTrigger kept switched off) that switches on when the fight is
## won. The Valentina fight uses it so the capture waits at the hall door instead of starting at once.
@export var unlock_on_win: Area3D
## Optional: the beats this fight's guards play instead of fighting freely (data/fights/*.txt; the
## format is at the top of data/fights/captain.txt). Sections without a guard name are the boss's.
@export_file("*.txt") var choreography_file := ""

var active := false
var _half_done := false
var _player: Player
var _scenes_played := {}  # a choreography's scenes play once per visit, even across restarts


func start() -> void:
	if active:
		return
	active = true
	MusicBus.fight(true, self)  # the fight track takes over from the level's bed
	_player = get_tree().get_first_node_in_group("player")
	var combat: PlayerCombat = _player.get_node("Combat")
	if not combat.died.is_connected(_on_player_died):
		combat.died.connect(_on_player_died)
	for guard in _guards():
		guard.visible = true
		guard.engage()
		if not guard.taken_down.is_connected(_on_guard_down):
			guard.taken_down.connect(_on_guard_down)
	_choreograph()
	if boss and boss_half_scene != "" and not boss.health_changed.is_connected(_on_boss_health):
		boss.health_changed.connect(_on_boss_health)
	# Safety net: if every agent is somehow down already, the fight is won (never a soft lock).
	if _guards().all(func(g: Guard) -> bool: return g.state == Guard.State.DOWN):
		var story := get_tree().root.get_node_or_null("Story")
		while story and story.playing:
			await get_tree().process_frame
		_on_guard_down(null)


func stop() -> void:
	active = false
	MusicBus.fight(false, self)
	if _player:
		var combat: PlayerCombat = _player.get_node("Combat")
		if combat.died.is_connected(_on_player_died):
			combat.died.disconnect(_on_player_died)


func _guards() -> Array[Guard]:
	var list: Array[Guard] = []
	for child in get_children():
		if child is Guard:
			list.append(child)
	return list


func _on_guard_down(_guard: Guard) -> void:
	if not active:
		return
	for guard in _guards():
		if guard.state != Guard.State.DOWN:
			return
	stop()
	# A won story fight counts as a checkpoint for its agents: a later death must not stand them up.
	for guard in _guards():
		guard.commit_checkpoint()
	if unlock_on_win:
		unlock_on_win.monitoring = true
	if won_scene != "":
		_story_play(won_scene)


func _on_boss_health(health: float, max_health: float) -> void:
	if _half_done or not active or health > max_health * 0.5:
		return
	_half_done = true
	_story_play(boss_half_scene)


func _on_player_died() -> void:
	if not active:
		return
	# A boss fight meant to be lost only ends in its death scene once the boss is past half.
	if death_scene != "" and (boss == null or _half_done):
		stop()
		_story_play(death_scene)
		return
	# Otherwise: back to the checkpoint, and the same fight again.
	stop()
	var director := get_tree().current_scene.find_child("StealthDirector", true, false)
	for guard in _guards():
		guard.dormant = true
		if not director:
			guard.reset_to_checkpoint()
		elif guard.state != Guard.State.DOWN:
			guard.state = Guard.State.PATROL  # lower the blades; the director puts them back once the screen is black
	if director and director.has_signal("restarted"):
		director.restart("SLAIN")
		await director.restarted  # everyone is back at the checkpoint (a pause during the fade waits too)
		await get_tree().create_timer(1.1, false).timeout  # and the screen has faded back in
	else:
		await get_tree().create_timer(2.2, false).timeout  # false: the wait stops while the game is paused
	start()


## Plays a scene from this fight's dialogue file. The autoload isn't named (see CLAUDE.md):
## headless tests load this script before it registers.
func _story_play(scene: String) -> void:
	var story := get_tree().root.get_node_or_null("Story")
	if story == null:
		return
	while story.playing:  # a choreography's camera beat is still on: this scene comes right after
		await get_tree().process_frame
	story.play(dialogue_file, scene)


## Gives each guard his beats from the choreography file (a fresh start every time the fight
## starts, so a restart plays the set piece from the top). Guards with no section fight freely.
func _choreograph() -> void:
	var sections := {}
	if choreography_file != "":
		sections = ChoreographyFile.parse(FileAccess.get_file_as_string(choreography_file))
	for guard in _guards():
		var key := String(guard.name)
		if guard == boss and not sections.has(key):
			key = ""
		var beats: Choreography = null
		if sections.has(key):
			beats = Choreography.new(guard, guard.fighter, self, sections[key])
		guard.fighter.set("choreography", beats)


## A choreography's scene beat (a camera cut, a taunt): plays once per visit. False if it can't
## play now (another scene is playing) or already has.
func play_scene_once(scene: String) -> bool:
	var story := get_tree().root.get_node_or_null("Story")
	if _scenes_played.has(scene) or story == null or story.playing:
		return false
	_scenes_played[scene] = true
	return story.play(dialogue_file, scene)
