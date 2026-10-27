extends "C:/Users/ArmandoSanchez/Documents/Aethereal 3D Godot/aethereal-3d/tests/overnight/saving_impl/save_test_base.gd"
# Saving in the Empty Town, played through the title screen like the author would:
# New Game -> scenes and checkpoints save -> Continue puts everything back (spot, agents down,
# triggers that don't replay, the round-up figures, Isabella, the restart point and its rank);
# then the hall sequence of the 2026-10-26 story: the Valentina fight, the capture (its won scene),
# the eruption, the lieutenant, Valentina to the fire, the captain's fight. Run headless.
# (Story26 copy of overnight/saving_impl/test_save_town.gd, updated to the new scenes and names.)

const TXT := "res://data/dialogue/empty_town.txt"


func _initialize() -> void:
	_run()


func _run() -> void:
	setup("town")
	# 1. New Game: the arrival scene, then two more scenes and four checkpoints.
	var w := await via_title("NewGame")
	check("New Game loads the world", w is World)
	check("a fresh save of the town start", SaveGame.load_save().get("fresh", false) == true
			and SaveGame.last_level() == TOWN)
	await wait_story()
	await skip()
	var data := await wait_save("story")
	check("arrival saved at its end %s" % [data.get("story", {})], data.get("story", {}).get(TXT, []) == ["arrival"])
	blind()
	await put(Vector3(0, 24, 42))
	await wait_story()
	await skip()
	await put(Vector3(0, 24, 33))
	data = await wait_save("checkpoint")
	check("BridgeEnd saves, spot on the checkpoint %s" % spot_of(data), near(spot_of(data), Vector3(0, 24, 33)))
	await put(Vector3(0, 24, 12))  # the rim: its checkpoint and the round-up trigger
	await wait_story()
	await skip()
	await put(Vector3(20, 24, 11))
	data = await wait_save("checkpoint")
	check("SneakStart saves", near(spot_of(data), Vector3(20, 24, 11)))
	var deck := zone_level(TOWN).get_node("Guards/AgentEastDeck") as Guard
	deck.take_down()
	var deck_at := deck.global_position
	await frames(10)
	player().model.rotation.y = 1.3  # a facing and a camera angle to get back
	player().camera_pivot.rotation.y = 0.7
	await put(Vector3(-4, 10.3, -1.5))
	data = await wait_save("checkpoint")
	check("Catwalk saves with the knifed agent %s" % [data.get("guards_down")], near(spot_of(data), Vector3(-4, 10.3, -1.5))
			and data.get("guards_down", []).size() == 1 and data.guards_down[0].killed)
	check("the file keeps the scenes in order %s" % [data.story], data.story.get(TXT, []) == ["arrival", "kael_meeting", "round_up"])

	# 2. Continue.
	w = await via_title("Continue")
	var town := zone_level(TOWN)
	var p := player()
	check("Continue: the world, the town, stage 1", w is World and World.current_level == TOWN and w.stage == 1)
	check("Continue: on the Catwalk checkpoint %s" % p.global_position, near(p.global_position, Vector3(-4, 10.3, -1.5)))
	check("Continue: facing the saved way (body not turned, model %.2f, saved %.2f)" % [p.model.global_rotation.y, float(data.spot.yaw)],
			p.global_basis.is_equal_approx(Basis()) and absf(angle_difference(p.model.global_rotation.y, 1.3)) < 0.02
			and absf(angle_difference(p.camera_pivot.rotation.y, 0.7)) < 0.02)
	check("Continue: no scene replays", not story.playing)
	check("Continue: arrival, Kael and round-up triggers done", trigger_done(TOWN, "StoryTriggers/Arrival")
			and trigger_done(TOWN, "StoryTriggers/KaelMeeting") and trigger_done(TOWN, "StoryTriggers/RoundUp"))
	check("Continue: the Valentina trigger still armed", not trigger_done(TOWN, "StoryTriggers/Valentina"))
	deck = town.get_node("Guards/AgentEastDeck") as Guard
	check("Continue: the knifed agent lies where he fell, bleeding", deck.state == Guard.State.DOWN and deck.killed
			and deck.blood.visible and near(deck.global_position, deck_at, 0.6))
	check("Continue: the other agents patrol", not down(TOWN, "Guards/AgentPairEast") and not down(TOWN, "Guards/AgentAlley"))
	check("Continue: Kael gone with the round-up, the round-up line hidden", not (town.get_node("Figures/Kael") as Node3D).visible
			and not (town.get_node("Figures/RoundUp") as Node3D).visible)
	var isa := w.get_node_or_null("Carry/Isabella") as Node3D
	check("Continue: Isabella follows, beside him", isa != null and isa.visible and isa.global_position.distance_to(p.global_position) < 4.0)
	var director := w.get_node("StealthDirector")
	check("Continue: the restart point is the Catwalk", near(director.checkpoint_position(), Vector3(-4, 10.3, -1.5)))
	blind()
	await put(Vector3(0, 24, 33))
	await frames(80)
	check("walking back through BridgeEnd moves nothing", near(director.checkpoint_position(), Vector3(-4, 10.3, -1.5))
			and near(spot_of(SaveGame.load_save()), Vector3(-4, 10.3, -1.5)))

	# 3. The Valentina fight: its scene saves the fight's start.
	await put(Vector3(-7.5, 0, -7.2))
	await wait_story()
	await skip()
	data = await wait_save("story")
	check("valentina saved (fight start) %s" % [data.story], data.story.get(TXT, []).back() == "valentina")
	w = await via_title("Continue")
	town = zone_level(TOWN)
	var vf := town.get_node("ValentinaFight")
	var holder := town.get_node("HallFight/Dragger") as Guard
	var val := town.get_node("Figures/Valentina") as Node3D
	check("Continue: the Valentina fight starts again", vf.active and not story.playing)
	check("Continue: Valentina held at knife point by the wall %s" % val.global_position, val.visible and holder.visible
			and near(val.global_position, at(TOWN, Vector3(4.2, 0, -6.9)), 0.2)
			and holder.global_position.distance_to(val.global_position) < 0.45 and holder.state != Guard.State.DOWN)
	var fight_save := SaveGame.load_save()
	var fight_restart: Vector3 = w.get_node("StealthDirector").checkpoint_position()
	await put(Vector3(-18.5, 8, 1))  # the Alleys checkpoint, mid-fight
	await frames(70)
	check("a checkpoint touched mid-fight moves nothing and saves nothing", near(w.get_node("StealthDirector").checkpoint_position(), fight_restart)
			and SaveGame.load_save().get("saved_unix") == fight_save.get("saved_unix") and spot_of(SaveGame.load_save()) == spot_of(fight_save))
	await put(Vector3(-7.5, 0, -7.2))

	# 4. Won: the capture plays at once (no walk to the door), and its end saves the hall fight's start.
	await take_down_all(vf)
	check("fight won, the capture plays at once", vf.won and await wait_story(30))
	await skip()
	data = await wait_save("story")
	check("captured saved %s, fights won %s" % [data.story.get(TXT, []).back(), data.fights_won],
			data.story.get(TXT, []).back() == "captured" and data.fights_won.size() == 1)
	w = await via_title("Continue")
	town = zone_level(TOWN)
	p = player()
	var hall := town.get_node("HallFight")
	var mark := at(TOWN, Vector3(-3.4, 0, -12.6))
	check("Continue: at the hall mark %s" % p.global_position, near(p.global_position, mark, 0.5))
	check("Continue: the hall fight is on, erupting", hall.active and p.get_node("Combat").erupting and not story.playing)
	isa = w.get_node_or_null("Carry/Isabella") as Node3D
	var body := town.get_node("Figures/IsabellaHall") as Node3D
	var anim := StoryStage.animator_of(body)
	check("Continue: Isabella taken, her body in her circle (%s)" % (anim.story_playing() if anim else "?"),
			isa != null and not isa.visible and body.visible and anim != null and anim.story_playing() == "collapse"
			and near(body.global_position, at(TOWN, Vector3(-1.0, 0, -12.4)), 0.2) and (town.get_node("InkCircle") as Node3D).visible)
	check("Continue: her captor and the two guards down", down(TOWN, "Figures/IsabellaCaptor") and down(TOWN, "Figures/HallGuard1")
			and down(TOWN, "Figures/HallGuard2"))
	check("Continue: Valentina captive in the hall, not the courtyard", (town.get_node("Figures/ValentinaHall") as Node3D).visible
			and not (town.get_node("Figures/Valentina") as Node3D).visible
			and StoryStage.animator_of(town.get_node("Figures/ValentinaHall")).story_playing() == "captive")
	check("Continue: capture trigger done, Valentina's agents down", trigger_done(TOWN, "StoryTriggers/Captured")
			and down(TOWN, "ValentinaFight/CourtyardAgent") and down(TOWN, "ValentinaFight/CourtyardAgent2")
			and down(TOWN, "ValentinaFight/StairAgent") and down(TOWN, "Guards/AgentEastDeck"))
	check("Continue: the lieutenant and the captain spared, standing", not down(TOWN, "LieutenantFight/Lieutenant")
			and not down(TOWN, "CaptainFight/Captain") and not down(TOWN, "HallFight/Dragger"))
	check("Continue: restart at the hall mark", near(w.get_node("StealthDirector").checkpoint_position(), mark, 0.5))

	# 5. The eruption won: the lieutenant's fight starts (saved at its start).
	await take_down_all(hall)
	await wait_story()
	await skip()
	data = await wait_save("story")
	check("eruption_end saved %s" % [data.story.get(TXT, [])], data.story.get(TXT, []).back() == "eruption_end")
	w = await via_title("Continue")
	town = zone_level(TOWN)
	p = player()
	check("Continue: the lieutenant fight is on, no eruption", town.get_node("LieutenantFight").active
			and not p.get_node("Combat").erupting)
	check("Continue: the hall agents and Valentina's holder stay down", down(TOWN, "HallFight/HallAgent1")
			and down(TOWN, "HallFight/Dragger") and town.get_node("HallFight").won)

	# 6. The lieutenant dead: Valentina goes into the fire; the captain's fight start is saved.
	await take_down_all(town.get_node("LieutenantFight"))
	await wait_story()
	await skip()
	data = await wait_save("story")
	check("valentina_fire saved %s" % [data.story.get(TXT, [])], data.story.get(TXT, []).back() == "valentina_fire")
	w = await via_title("Continue")
	town = zone_level(TOWN)
	check("Continue: the captain fight is on, Valentina gone, the lieutenant down", town.get_node("CaptainFight").active
			and not (town.get_node("Figures/ValentinaHall") as Node3D).visible and down(TOWN, "LieutenantFight/Lieutenant"))
	# Walking on into Black Sand (as the dev menu can) takes Isabella off him and saves at its Start.
	blind()
	town.get_node("CaptainFight").stop()  # a zone save waits for no fight
	await put(Vector3(0, -45.8, -95))
	data = await wait_save("zone", 300)
	check("into Black Sand: zone save at its Start, Isabella gone from him %s" % [data.get("level")], data.get("level", "") == BS
			and data.get("stage", 0) == 3 and not w.has_node("Carry/Isabella"))
	finish("SAVE TOWN TEST")


## The capture scene is long: read it to its end.
func skip() -> void:
	for i in 900:
		if not story.playing:
			break
		Input.action_press("ui_accept")
		await process_frame
		await process_frame
		Input.action_release("ui_accept")
		await frames(5)
	await frames(6)
