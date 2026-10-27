extends "C:/Users/ArmandoSanchez/Documents/Aethereal 3D Godot/aethereal-3d/tests/overnight/saving_impl/save_test_base.gd"
# Saving after the town: the Massacre (a level on its own: its scenes save, Continue puts Aeneas
# back mid-memory with the raiders shown), Black Sand (the camp, Kael, the checkpoints before and
# past the road) and the Vacuum Station (walking in saves at its Start, its mid-hall checkpoint,
# the flashlight). Every Continue goes through the title screen. Run headless.

const M_TXT := "res://data/dialogue/massacre.txt"
const BS_TXT := "res://data/dialogue/black_sand.txt"


func _initialize() -> void:
	_run()


func _run() -> void:
	setup("rest")
	SaveGame.recording = true
	# 1. The Massacre: chapter start, two scenes.
	change_scene_to_file(TITLE)
	await frames(10)
	var old := current_scene
	story.go_to_level(MASSACRE)
	var m := await next_scene(old)
	check("the Massacre loads with an Autosave", m.scene_file_path == MASSACRE and m.has_node("Autosave"))
	await wait_story()
	await skip()
	await put(Vector3(0, 0, -25))
	await wait_story()
	await skip()
	var data := await wait_save("story")
	check("the Massacre saves its scenes %s" % [data.get("story")], data.get("story", {}).get(M_TXT, []) == ["memory", "the_men"])
	var men_spot := spot_of(data)
	m = await via_title("Continue")
	var p := player()
	check("Continue: the Massacre, where he was %s vs %s" % [p.global_position, men_spot],
			m.scene_file_path == MASSACRE and near(p.global_position, men_spot))
	check("Continue: no scene replays, both triggers done", not story.playing and trigger_done(MASSACRE, "StoryTriggers/Memory")
			and trigger_done(MASSACRE, "StoryTriggers/TheMen") and not trigger_done(MASSACRE, "StoryTriggers/BehindTheHouse"))
	check("Continue: the raiders are there, the crowd gone", (m.get_node("Figures/Raiders") as Node3D).visible
			and not (m.get_node("Figures/Crowd") as Node3D).visible)

	# 2. The whiteout: Black Sand in the world. Waking, the cube, the road checkpoints.
	await put(Vector3(14, 0, -82))
	await wait_story()
	var w := await next_scene(m)
	check("the whiteout leads to the world at Black Sand", w is World and World.current_level == BS)
	check("a fresh save of Black Sand's start", SaveGame.load_save().get("fresh", false) and SaveGame.last_level() == BS)
	await wait_story()
	await skip()
	blind()
	await put(ground(BS, 20.0, 6.0))
	await wait_story()
	await skip()
	data = await wait_save("story")
	check("the cube saved %s" % [data.story], data.story.get(BS_TXT, []) == ["waking", "the_cube"])
	await put(at(BS, Vector3(0, 4.585, -26.8)))  # walking north: BeforeRoad first, the road scene 1.5 m on
	data = await wait_save("checkpoint")
	check("BeforeRoad saves, on the checkpoint", near(spot_of(data), Vector3(0, 4.585, -28)))
	await put(at(BS, Vector3(0, 4.66, -29.5)))
	await wait_story()
	await skip()
	data = await wait_save("story")
	var road_spot := spot_of(data)
	check("the road scene saves where he stands, restart still BeforeRoad", data.story.get(BS_TXT, []).back() == "the_road"
			and near(Vector3(data.restart.pos[0], data.restart.pos[1], data.restart.pos[2]), Vector3(0, 4.585, -28)))
	w = await via_title("Continue")
	p = player()
	var bs := zone_level(BS)
	check("Continue: the world at Black Sand, stage 3", w is World and World.current_level == BS and w.stage == 3)
	check("Continue: where the road scene ended %s" % p.global_position, near(p.global_position, at(BS, road_spot)))
	check("Continue: no scene replays; waking and cube done, the grave not", not story.playing
			and trigger_done(BS, "StoryTriggers/Waking") and trigger_done(BS, "StoryTriggers/Camp") and trigger_done(BS, "StoryTriggers/RoadEdge")
			and not trigger_done(BS, "StoryTriggers/Grave"))
	var kael := w.get_node_or_null("Carry/Kael") as Node3D
	check("Continue: Kael follows, visible, beside him; his camp figure gone", kael != null and kael.visible
			and kael.global_position.distance_to(p.global_position) < 4.0 and not (bs.get_node("Figures/KaelFigure") as Node3D).visible)
	check("Continue: Isabella is not with him", not w.has_node("Carry/Isabella"))
	var director := w.get_node("StealthDirector")
	check("Continue: restart at BeforeRoad", near(director.checkpoint_position(), at(BS, Vector3(0, 4.585, -28))))
	blind()
	await put(at(BS, Vector3(0, 0.05, -61)))
	data = await wait_save("checkpoint", 300)
	check("PastRoad (new) saves and moves the restart %s" % spot_of(data), near(spot_of(data), Vector3(0, 0.05, -61))
			and near(director.checkpoint_position(), at(BS, Vector3(0, 0.05, -61))))

	# 3. The station: walking in saves at its Start; the mid-hall checkpoint; the flashlight.
	await put(at(BS, Vector3(0, -4, -108)))  # the descent ("down" lets him walk on)
	await wait_story()
	await skip()
	await put(at(STATION, Vector3(0, 0, 50)))
	data = await wait_save("zone", 300)
	check("walking into the station saves at its Start %s" % spot_of(data), data.get("level", "") == STATION
			and near(spot_of(data), Vector3(0, 0.2, 62)) and data.stage == 4)
	w = await via_title("Continue")
	p = player()
	var start: Vector3 = w.zone_of(STATION).start_transform(w).origin
	check("Continue: the station, stage 4, at its Start", World.current_level == STATION and w.stage == 4
			and near(p.global_position, start))
	check("Continue: restart at the station Start", near(w.get_node("StealthDirector").checkpoint_position(), start))
	kael = w.get_node_or_null("Carry/Kael") as Node3D
	check("Continue: Kael and the flashlight come along", kael != null and kael.visible and w.has_node("Carry/Flashlight"))
	await frames(4)
	var torch := w.get_node("Carry/Flashlight")
	torch.toggle()
	await put(at(STATION, Vector3(0, 0, 0)))
	data = await wait_save("checkpoint", 300)
	check("the mid-hall checkpoint (new) saves, flashlight on", near(spot_of(data), Vector3.ZERO) and data.flashlight)
	w = await via_title("Continue")
	p = player()
	torch = w.get_node("Carry/Flashlight")
	check("Continue: mid-hall, flashlight on", near(p.global_position, at(STATION, Vector3.ZERO)) and torch.is_on())
	check("Continue: the arrival scene is still to come (never played)", not trigger_done(STATION, "StoryTriggers/Arrival"))

	# 4. A save on a walkway (the road tunnel): the world starts there, in the right zone and stage.
	SaveGame.write({"version": 1, "level": BS, "reason": "story", "stage": 3, "spot": {"pos": [0.0, -4.0, -125.0], "yaw": 0.0},
			"restart": {"pos": [0.0, 0.05, -61.0]}, "story": {BS_TXT: ["waking", "the_cube", "the_road", "the_arch", "down"]}})
	w = await via_title("Continue")
	p = player()
	check("Continue on the walkway: there, Black Sand, stage 3 %s" % p.global_position, near(p.global_position, Vector3(0, -54, -261), 0.5)
			and World.current_level == BS and w.stage == 3 and w.has_node("Carry/Kael") and not w.has_node("Carry/Isabella"))
	finish("SAVE REST TEST")
