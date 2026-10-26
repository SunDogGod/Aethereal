class_name SaveRestore
extends RefCounted
## Continue: puts a save (save_state.gd) back into a freshly loaded level or big world, so Aeneas
## stands where he was and the place is as he left it. Story calls prepare() just before the new
## scene goes in; apply() then runs the moment it is ready, before the first physics step, so no
## trigger or checkpoint ever sees him at the level's start.
## The order in apply() matters (each step is commented).

const FIGHT_DELAY := 1.0  ## seconds before a story fight the save was in starts (the screen fades in first)


## Before the scene enters the tree: moves Aeneas to the saved spot (in the big world the World
## does it in _enter_tree, see world.gd), and arranges for apply() once the scene is ready.
static func prepare(next: Node, data: Dictionary) -> void:
	if data.is_empty() or data.get("fresh", false):
		return
	if next is World:
		World.pending_save = data
	else:
		var player := next.get_node_or_null("Player") as Node3D
		if player:
			player.position = (next as Node3D).transform * spot_position(data)
	next.ready.connect(func() -> void: apply(next, data), CONNECT_ONE_SHOT)


## The saved spot, relative to its level. (Only his Model and camera turn, never the Player body:
## the way he faces is put back in apply().)
static func spot_position(data: Dictionary) -> Vector3:
	return _vec(data.spot.pos)


## Big world only, from World._enter_tree: the zone to start in is the saved one (never guessed
## from where he stands, which may be a walkway), and he starts at the saved spot.
static func place(world: World, data: Dictionary, fallback: WorldZone) -> WorldZone:
	var zone := world.zone_of(str(data.level))
	if zone == null:
		return fallback
	var at := World.xf_in(world, zone.level) * spot_position(data)
	if not zone.has_point(at) and not world.links.any(func(l: WorldLink) -> bool: return l.has_point(at)):
		at = zone.start_transform(world).origin  # the zone moved since this save: its Start is safe
	world.player.position = at
	return zone


## The scene is ready: everything else, in this order.
static func apply(root: Node, data: Dictionary) -> void:
	var level := SaveState.level_node(root, str(data.level))
	if level == null:
		return
	var tree := root.get_tree()
	var story: Dictionary = data.get("story", {})
	# 1. Triggers of finished scenes never play again.
	for t in tree.get_nodes_in_group("story_triggers"):
		if story.get(t.dialogue_file, []).has(t.scene):
			t.mark_done()
	# 2. Checkpoints already reached (hiding what they hide).
	var reached := []
	for key: String in data.get("checkpoints", []):
		var cp := SaveState.node_of(root, key)
		if cp and cp.has_method("mark_reached"):
			cp.mark_reached()
			reached.append(cp)
	# 3. Agents down for good lie where they fell (before step 7, which keeps them down).
	for entry: Dictionary in data.get("guards_down", []):
		var g := SaveState.node_of(root, entry.key) as Guard
		if g:
			var own := SaveState.level_of(g)
			lay_down(g, own.global_transform * _vec(entry.pos), float(entry.yaw) + own.global_rotation.y, entry.killed)
	# 4. Fights already won (their agents stay down; the capture door opens).
	var won := []
	for key: String in data.get("fights_won", []):
		var fight := SaveState.node_of(root, key)
		if fight and fight.has_method("restore_won"):
			fight.restore_won()
			won.append(fight)
	# 5. Look-at spots that can only be read once.
	for key: String in data.get("looked", []):
		var spot_node := SaveState.node_of(root, key)
		if spot_node and spot_node.has_method("mark_read"):
			spot_node.mark_read()
	# 6. What the finished scenes changed (who is hidden, who collapsed, the eruption...). In the big
	#    world the zones the story is past are set by the stage instead (their scenes are not replayed).
	var to_start := []
	for path: String in story:
		if root is World:
			var zone := (root as World).zone_of(root.level_for_dialogue(path).scene_file_path)
			if zone and zone.order < (root as World).stage:
				continue
		for scene: String in story[path]:
			for fight: Node in StoryReplay.run(root, path, scene, won):
				if not fight in to_start:
					to_start.append(fight)
	# 7. The restart point (spotted, slain, fell) and how far on the checkpoints are.
	var director := root.get_node_or_null("StealthDirector")
	if director and director.has_method("restore"):
		var restart: Vector3 = level.global_transform * _vec(data.restart.pos) if data.has("restart") \
				else level.global_transform * _vec(data.spot.pos)
		director.restore(reached, restart)
	# 8. Aeneas, facing the saved way; companions snap beside him (they listen to respawned).
	var player := tree.get_first_node_in_group("player") as Player
	if player:
		player.respawn_at(player.global_position)
		player.model.rotation.y = float(data.spot.yaw) + level.global_rotation.y
		player.camera_pivot.rotation.y = float(data.spot.get("cam_yaw", data.spot.yaw))
		var combat := player.get_node_or_null("Combat")
		if combat and not combat.erupting:
			combat.heal_full()
	# 9. The flashlight, as he left it.
	for light in tree.get_nodes_in_group("flashlights"):
		if light.has_method("set_on"):
			light.set_on(data.get("flashlight", false))
	# 10. A story fight the save was in starts again once the screen is up.
	if not to_start.is_empty():
		tree.create_timer(FIGHT_DELAY, false).timeout.connect(func() -> void:
			for fight: Node in to_start:
				if is_instance_valid(fight) and fight.is_inside_tree():
					fight.start())


## An agent who went down for good before the save: on the floor, still, no sound, no signal.
static func lay_down(g: Guard, at: Vector3, yaw: float, knifed: bool) -> void:
	g.global_position = at
	g.velocity = Vector3.ZERO
	g.model.rotation = Vector3(0.0, yaw, 0.0)
	g.state = Guard.State.DOWN
	g.suspicion = 0.0
	g.killed = knifed
	g.alert.visible = false
	g.visor.visible = false
	g.body_shape.set_deferred("disabled", true)
	if g.animator:
		g.animator.die(true)
	if knifed:  # the blood pool, already spread, under his chest
		var ahead := -g.model.global_basis.z
		ahead.y = 0.0
		ahead = ahead.normalized() * 0.8
		g.blood.position = Vector3(ahead.x, -1.0, ahead.z)
		g.blood.size = Vector3(1.5, 2.4, 1.5)
		g.blood.visible = true
	g.down_for_good = true


static func _vec(a: Variant) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
