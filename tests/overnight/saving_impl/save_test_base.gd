extends SceneTree
# Shared helpers for the save tests (test_save_town.gd, test_save_rest.gd). Saves go to a scratch
# folder (SaveGame.folder); the author's real files in user:// are checked unchanged at the end.

const SCRATCH := "C:/Users/ArmandoSanchez/Documents/Aethereal 3D Godot/aethereal-3d/tests/overnight/saving_impl/"
const TITLE := "res://scenes/ui/title_screen.tscn"
const TOWN := "res://scenes/levels/empty_town.tscn"
const MASSACRE := "res://scenes/levels/massacre.tscn"
const BS := "res://scenes/levels/black_sand.tscn"
const STATION := "res://scenes/levels/vacuum_station.tscn"
const REAL := ["user://save.cfg", "user://savegame.json", "user://savegame.bak.json"]

var story: Node
var fails := 0
var _real := {}


func setup(sub: String) -> void:
	story = root.get_node("Story")
	for f: String in REAL:
		_real[f] = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
	SaveGame.folder = SCRATCH + sub
	DirAccess.make_dir_recursive_absolute(SaveGame.folder)
	for f in DirAccess.get_files_at(SaveGame.folder):
		DirAccess.remove_absolute(SaveGame.folder.path_join(f))


func finish(name: String) -> void:
	for f: String in REAL:
		var now: Variant = FileAccess.get_file_as_bytes(f) if FileAccess.file_exists(f) else null
		check("real %s untouched" % f, now == _real[f])
	print("%s %s (%d failed)" % [name, "PASS" if fails == 0 else "FAIL", fails])
	quit()


func check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


## The title screen, then its Continue (or New Game). Returns the scene that loads.
func via_title(item: String) -> Node:
	if story.playing:
		story.stop()
	change_scene_to_file(TITLE)
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.is_in_group("title_screen") and i > 4:
			break
	var button := current_scene.find_child(item, true, false) as MenuItem
	if button == null:
		check("title offers %s" % item, false)
		return null
	var old := current_scene
	button.pressed.emit()
	for i in 900:
		await process_frame
		if current_scene != null and current_scene != old and current_scene.is_inside_tree() \
				and not current_scene.is_in_group("title_screen"):
			break
	await seconds(1.6)  # the fade in, and a restored fight's delay
	return current_scene


## Waits for a scene change away from `old` (a [level] line).
func next_scene(old: Node) -> Node:
	for i in 900:
		await process_frame
		if current_scene != null and current_scene != old and current_scene.is_inside_tree():
			break
	await seconds(0.8)
	return current_scene


func player() -> Player:
	return get_first_node_in_group("player") as Player


## Agents don't see him: the test checks saving, not sneaking.
func blind() -> void:
	for g: Guard in get_nodes_in_group("guards"):
		g.data.sight_range = 0.0


## Puts him somewhere (as if he walked there) and lets the triggers and checkpoints see him.
func put(at: Vector3) -> void:
	player().respawn_at(at)
	await frames(8)


## Reads a playing scene to its end.
func skip() -> void:
	for i in 120:
		if not story.playing:
			break
		Input.action_press("ui_accept")
		await process_frame
		await process_frame
		Input.action_release("ui_accept")
		await frames(5)
	await frames(6)


func wait_story(max_frames := 240) -> bool:
	for i in max_frames:
		if story.playing:
			return true
		await physics_frame
	return false


## Waits for the save file to have this reason (and, if given, this many scenes in `path`).
func wait_save(reason: String, max_frames := 240) -> Dictionary:
	for i in max_frames:
		var data := SaveGame.load_save()
		if data.get("reason", "") == reason:
			return data
		await physics_frame
	return SaveGame.load_save()


func zone_level(path: String) -> Node3D:
	return SaveState.level_node(current_scene, path)


## A level-local point as a global one.
func at(level_path: String, local: Vector3) -> Vector3:
	return zone_level(level_path).global_transform * local


func near(a: Vector3, b: Vector3, metres := 0.35) -> bool:
	return a.distance_to(b) <= metres


func spot_of(data: Dictionary) -> Vector3:
	var p: Array = data.get("spot", {}).get("pos", [0, 0, 0])
	return Vector3(p[0], p[1], p[2])


func trigger_done(level_path: String, path: String) -> bool:
	var t := zone_level(level_path).get_node_or_null(path)
	return t != null and t.get("_done") == true


func down(level_path: String, path: String) -> bool:
	var g := zone_level(level_path).get_node_or_null(path) as Guard
	return g != null and g.state == Guard.State.DOWN


func take_down_all(fight: Node) -> void:
	for g in fight.get_children():
		if g is Guard and g.state != Guard.State.DOWN:
			g.take_down()
	await frames(4)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func seconds(s: float) -> void:
	await create_timer(s).timeout


## The floor under a level-local (x, z), found by a ray from `from_y` down (global point).
func ground(level_path: String, x: float, z: float, from_y := 12.0) -> Vector3:
	var lv := zone_level(level_path)
	var a := lv.global_transform * Vector3(x, from_y, z)
	var hit := lv.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + Vector3.DOWN * 40.0, 1))
	return hit.position if hit else a
