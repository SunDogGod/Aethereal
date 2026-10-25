extends Node
## The dev menu's switches (DevTools/Cheats): god mode, noclip, blind guards, time scale,
## and skipping the story scene that is playing. Going places (teleports, restarts, reloads,
## chapters) lives next door in dev_places.gd.
## It only uses the public side of the game's nodes (their properties, methods and signals),
## looked up by name in untyped variables (var x = ...), so it keeps working while the
## Player, the guards and the Story change. Switches survive a level change: god mode and
## blind guards take hold of the new level's Aeneas and agents as soon as they appear.

signal changed  ## something switched or moved: the menu and the overlay redraw

const Noclip := preload("res://scripts/dev/dev_noclip.gd")
const SCALES := [0.25, 1.0, 2.0]  ## the time scale choices
const SKIP_SPEED := 4.0           ## the game runs this much faster while a scene is skipped
const SIGHT := &"dev_sight"       ## a blinded guard keeps his real sight range in this meta

var god := false
var blind := false
var time_scale := 1.0
var skipping := false             ## a story scene is being skipped right now
var noclip: Node                  ## the flyer (dev_noclip.gd)
var places: Node                  ## DevTools/Places (the last checkpoint lives there)

var _menu_open := false


func _ready() -> void:
	noclip = Noclip.new()
	noclip.name = "Noclip"
	noclip.cheats = self
	add_child(noclip)


func _physics_process(_delta: float) -> void:
	if god:
		_keep_alive()
	if blind:
		_blind_new_guards()


# --- Finding things ----------------------------------------------------------------------
# These return plain Nodes; callers keep them in untyped variables so that properties like
# `health` or `playing` are looked up while the game runs.

func level() -> Node:
	return get_tree().current_scene


func player() -> Node:
	return get_tree().get_first_node_in_group("player")


func combat() -> Node:
	var p := player()
	return p.get_node_or_null("Combat") if p else null


func story() -> Node:
	return get_node_or_null("/root/Story")


func director() -> Node:
	return level().find_child("StealthDirector", true, false) if level() else null


func story_playing() -> bool:
	var s := story()
	return s != null and s.get("playing") == true


## The floor under a point (a spot where he fits standing up), or null.
func find_floor(at: Vector3) -> Variant:
	var p := player() as Node3D
	if p == null:
		return null
	var space := p.get_world_3d().direct_space_state
	for from: Vector3 in [at + Vector3.UP * 1.0, at + Vector3.UP * 60.0]:
		var query := PhysicsRayQueryParameters3D.create(from, at + Vector3.DOWN * 80.0, 1)
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and _fits(space, hit.position):
			return hit.position
	return null  # inside a wall with nothing above, or over the void


func _fits(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var body := CapsuleShape3D.new()
	body.radius = 0.3
	body.height = 1.6
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body
	query.transform = Transform3D(Basis(), at + Vector3.UP * 0.9)
	query.collision_mask = 1
	return space.intersect_shape(query, 1).is_empty()


# --- Switches ----------------------------------------------------------------------------

## God mode: hits don't land and his health stays full.
func set_god(on: bool) -> void:
	god = on
	var c = combat()
	if on:
		_keep_alive()
	elif c and "invulnerable" in c:
		c.invulnerable = c.get("erupting") == true  # the eruption keeps its own protection
	changed.emit()


func _keep_alive() -> void:
	var c = combat()
	if c == null or not ("health" in c and "max_health" in c):
		return
	if "invulnerable" in c:
		c.invulnerable = true  # every frame: [erupt off] switches it off again
	if c.health < c.max_health:
		c.health = c.max_health
		if c.has_signal("health_changed"):
			c.emit_signal("health_changed", c.health, c.max_health)


## Blind guards: their sight range drops to nothing (kept in a meta), so nobody notices him.
## Switching it off gives every agent his own sight back.
func set_blind(on: bool) -> void:
	blind = on
	if on:
		_blind_new_guards()
	else:
		for guard in get_tree().get_nodes_in_group("guards"):
			if guard.has_meta(SIGHT):
				var data = guard.get("data")
				if data:
					data.sight_range = guard.get_meta(SIGHT)
				guard.remove_meta(SIGHT)
	changed.emit()


func _blind_new_guards() -> void:
	for guard in get_tree().get_nodes_in_group("guards"):
		var data = guard.get("data")
		var has_sight: bool = data != null and "sight_range" in data
		if not has_sight and "suspicion" in guard:
			guard.set("suspicion", 0.0)  # no sight range to take away: keep him calm instead
		if guard.has_meta(SIGHT) or not has_sight or not guard.is_node_ready():
			continue  # not ready yet: he hasn't made his own copy of his GuardData
		guard.set_meta(SIGHT, data.sight_range)
		data.sight_range = 0.0
		if "suspicion" in guard:
			guard.set("suspicion", 0.0)


func set_noclip(on: bool) -> void:
	noclip.set_on(on)
	changed.emit()


func set_time_scale(value: float) -> void:
	time_scale = value
	_apply_time()
	changed.emit()


## Steps through 0.25x / 1x / 2x (step -1 goes back).
func cycle_time_scale(step := 1) -> void:
	var i := SCALES.find(time_scale)
	set_time_scale(SCALES[posmod(i + step, SCALES.size())])


## The menu runs at normal speed while it's open; the game gets its time scale back after.
func hold_time(menu_open: bool) -> void:
	_menu_open = menu_open
	_apply_time()


func _apply_time() -> void:
	Engine.time_scale = 1.0 if _menu_open else (SKIP_SPEED if skipping else time_scale)


# --- Story -------------------------------------------------------------------------------

## Skips the scene that is playing the way a player would: it presses "advance" until the
## scene ends (with the game sped up), so every step in it ([hide], [teleport], [fight],
## [level]...) still happens.
func skip_scene() -> void:
	var s = story()
	if s == null or s.get("playing") != true or skipping:
		return
	skipping = true
	_apply_time()
	changed.emit()
	var presses := 0
	while is_instance_valid(s) and s.playing and presses < 2000:
		if get_tree().paused:
			await get_tree().process_frame  # a menu is up: wait, don't press
			continue
		Input.action_press("ui_accept")
		await get_tree().process_frame
		await get_tree().process_frame
		Input.action_release("ui_accept")
		await get_tree().process_frame
		presses += 1
	skipping = false
	_apply_time()
	changed.emit()
