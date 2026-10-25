class_name GuardLook
extends RefCounted
## How a guard looks, from his GuardData: which model he wears (model_scene: the captain has his
## own; everyone else is the agent in guard.tscn), the coat, trim and visor colours, and the
## colour flash when something happens to him. guard.gd calls these.
## Models paint their coat ("Coat..." meshes) and trim ("Trim..." meshes) near-white with the dust
## painted in, so the colour from GuardData shows as it is.


## Puts GuardData.model_scene in place of the agent model, keeping the guard's own markers (the
## Eyes his sight starts from, Isabella's ink glyph), raised to the new model's height.
## Call at the start of _ready, before anything uses the model.
static func swap_model(guard: Guard) -> void:
	if guard.data == null or guard.data.model_scene == null:
		return
	var old: Node3D = guard.model
	var fresh: Node3D = guard.data.model_scene.instantiate()
	old.name = "AgentModel"
	fresh.name = "Model"
	fresh.transform = old.transform
	guard.add_child(fresh)
	guard.move_child(fresh, old.get_index())
	var ratio := _head_height(fresh) / maxf(_head_height(old), 0.01)
	for keep: Node3D in [guard.eyes, guard.ink_glyph]:
		keep.reparent(fresh, false)
		keep.position.y *= ratio
	guard.remove_child(old)
	old.queue_free()
	guard.model = fresh
	guard.visor = fresh.find_child("Visor", true, false)
	guard.animator = fresh.get_node_or_null("Animator")


## Colours from the GuardData file. Each guard gets his own copies so kinds can differ.
static func apply(guard: Guard) -> void:
	for part in parts(guard.model, "Coat"):
		_tinted_copy(part, guard.data.coat_color)
	for part in parts(guard.model, "Trim"):
		_tinted_copy(part, guard.data.trim_color)
	var eye_light: ShaderMaterial = guard.visor.get_active_material(0).duplicate()
	eye_light.set_shader_parameter("albedo_color", guard.data.visor_color)
	eye_light.set_shader_parameter("emission_color", guard.data.visor_color)
	eye_light.set_shader_parameter("emission_energy", 2.0)
	guard.visor.material_override = eye_light


## The coat flashes `color` and fades back to its own colour over a quarter second.
static func flash(guard: Guard, color: Color) -> void:
	for part in parts(guard.model, "Coat"):
		var mat: ShaderMaterial = part.material_override
		if mat == null:
			continue
		var copy: ShaderMaterial = mat.duplicate()
		copy.set_shader_parameter("albedo_color", color)
		part.material_override = copy
		var tween := guard.create_tween()
		tween.tween_property(copy, "shader_parameter/albedo_color", guard.data.coat_color, 0.25)


## The meshes of a model whose names start with `prefix` ("Coat" also takes the guard_coat group).
static func parts(model: Node, prefix: String) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if part.name.begins_with(prefix) or (prefix == "Coat" and part.is_in_group("guard_coat")):
			found.append(part)
	return found


static func _tinted_copy(part: MeshInstance3D, color: Color) -> void:
	var mat: ShaderMaterial = part.get_active_material(0).duplicate()
	mat.set_shader_parameter("albedo_color", color)
	part.material_override = mat


## How high a model's head joint stands in its rest pose (to place the Eyes on a taller model).
static func _head_height(model: Node) -> float:
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skeleton == null or skeleton.find_bone("Head") < 0:
		return 1.0
	return skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin.y
