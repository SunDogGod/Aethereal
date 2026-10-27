extends RefCounted
## How in-game edits are written down in data/edits/<level>.json and read back (level_edits.gd).
## Plain JSON the author can read: a transform is {"pos": [x, y, z], "rot": [x, y, z] degrees,
## "scale": [x, y, z]} relative to the node's parent; a property value is Godot's own text
## form (var_to_str, e.g. "3" or "Vector3(2, 2, 2)"), a resource file is "res:" + its path.
## Nothing here touches a scene; it only turns values into JSON and back.

const RES := "res:"


## A local transform as JSON (rounded so the file stays readable and stable).
static func xf_to_json(xf: Transform3D) -> Dictionary:
	var scale := xf.basis.get_scale()
	var rot := xf.basis.orthonormalized().get_euler()  # YXZ, Godot's default order
	return {
		"pos": _round3(xf.origin, 0.0001),
		"rot": _round3(Vector3(rad_to_deg(rot.x), rad_to_deg(rot.y), rad_to_deg(rot.z)), 0.01),
		"scale": _round3(scale, 0.0001),
	}


## Reads a transform written by xf_to_json(). Missing parts default to no move / no turn.
static func xf_from_json(d: Variant) -> Transform3D:
	if not d is Dictionary:
		return Transform3D.IDENTITY
	var pos := _vec3(d.get("pos"), Vector3.ZERO)
	var rot := _vec3(d.get("rot"), Vector3.ZERO)
	var scale := _vec3(d.get("scale"), Vector3.ONE)
	var basis := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
	return Transform3D(basis * Basis.from_scale(scale), pos)


## True when the two transforms are the same once written down (no edit needed).
static func same_xf(a: Transform3D, b: Transform3D) -> bool:
	return xf_to_json(a) == xf_to_json(b)


## A property value as text. Resources saved in their own files keep their path; anything
## that can't be written down (a resource made inside a scene, a node) gives null.
static func value_to_json(value: Variant) -> Variant:
	if value is Resource:
		var path: String = (value as Resource).resource_path
		if path == "" or path.contains("::"):
			return null
		return RES + path
	if value is Object:
		return null
	return var_to_str(value)


## Reads a value written by value_to_json(). Null if it can't be read.
static func value_from_json(text: Variant) -> Variant:
	if not text is String:
		return null
	var s: String = text
	if s.begins_with(RES):
		var path := s.trim_prefix(RES)
		return load(path) if ResourceLoader.exists(path) else null
	return str_to_var(s)


## The node's settings that differ from a fresh node of its kind (its script's exported
## variables and the engine's stored properties), as JSON. The transform, name and other
## node bookkeeping are left out: they are written separately.
static func props_of(node: Node) -> Dictionary:
	var out := {}
	var script := node.get_script() as Script
	var fresh: Node = ClassDB.instantiate(node.get_class()) if ClassDB.can_instantiate(node.get_class()) else null
	for p: Dictionary in node.get_property_list():
		var prop_name: String = p.name
		if not (p.usage & PROPERTY_USAGE_STORAGE) or prop_name in SKIP or prop_name.begins_with("metadata/"):
			continue
		var value: Variant = node.get(prop_name)
		var default: Variant = null
		var has_default := false
		if script and _script_has(script, prop_name):
			default = script.get_property_default_value(prop_name)
			has_default = true
		elif fresh and prop_name in fresh:
			default = fresh.get(prop_name)
			has_default = true
		if has_default and typeof(default) == typeof(value) and default == value:
			continue
		var text: Variant = value_to_json(value)
		if text != null:
			out[prop_name] = text
	if fresh:
		fresh.free()
	return out


## Sets properties written by props_of() on a node (unknown or unreadable ones are skipped).
static func set_props(node: Node, props: Variant) -> void:
	if not props is Dictionary:
		return
	for key: String in props:
		if key in SKIP or not key in node:
			continue
		var value: Variant = value_from_json(props[key])
		if value != null or str(props[key]) == "null":
			node.set(key, value)


## Node bookkeeping that is never copied as a "setting".
const SKIP := ["transform", "position", "rotation", "rotation_degrees", "quaternion", "basis",
		"scale", "global_transform", "global_position", "name", "owner", "script",
		"scene_file_path", "unique_name_in_owner", "process_mode", "rotation_edit_mode",
		"rotation_order", "top_level"]


static func _script_has(script: Script, prop_name: String) -> bool:
	for p: Dictionary in script.get_script_property_list():
		if p.name == prop_name:
			return true
	return false


static func _round3(v: Vector3, step: float) -> Array:
	return [snappedf(v.x, step), snappedf(v.y, step), snappedf(v.z, step)]


static func _vec3(a: Variant, fallback: Vector3) -> Vector3:
	if a is Array and (a as Array).size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


## A world transform as seen from `parent` (what its `transform` must be to sit there).
static func local_xf(parent: Node, world_xf: Transform3D) -> Transform3D:
	return (parent as Node3D).global_transform.affine_inverse() * world_xf if parent is Node3D else world_xf


static func local_dir(parent: Node, world_dir: Vector3) -> Vector3:
	return (parent as Node3D).global_basis.inverse() * world_dir if parent is Node3D else world_dir
