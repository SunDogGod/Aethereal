extends SceneTree
## Builds scenes/characters/<name>_model.tscn from what a Blender character script exported
## (models/characters/<name>.glb, <name>_props.glb and <name>.json). Run after Godot's import:
##   godot --headless --path <project> -s res://tools/blender/make_wrapper.gd -- aeneas
## The scene: the glb (body, skeleton, animations), one BoneAttachment3D per attach point holding
## its props (e.g. Sword/Rocinante on Weapon_R), and the Animator (scripts/character_animator.gd).
## Characters' own scenes (player.tscn, kael.tscn, guard.tscn...) instance it as their "Model".


func _initialize() -> void:
	var names := OS.get_cmdline_user_args()
	if names.is_empty() and OS.get_environment("CHAR") != "":
		names = [OS.get_environment("CHAR")]
	for n in names:
		print("WRAPPER %s: %s" % [n, _build(n)])
	quit()


func _build(char_name: String) -> String:
	var spec_path := "res://models/characters/%s.json" % char_name
	if not FileAccess.file_exists(spec_path):
		return "no " + spec_path
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	var glb: PackedScene = load(spec.glb)
	if glb == null:
		return "can't load %s (run Godot's import first)" % spec.glb
	var root := Node3D.new()
	root.name = spec.root
	var model := glb.instantiate()
	model.name = char_name
	root.add_child(model)
	model.owner = root
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var props: Node = null
	if spec.props_glb != "":
		props = (load(spec.props_glb) as PackedScene).instantiate()
	# A prop is modelled with its grip at the origin and its length along Blender's +Y; turning it
	# +90 degrees about X undoes the glTF axis change, so it lines up with the bone's own axes.
	var to_bone := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	var made := []
	for a: Dictionary in spec.attach:
		var att := BoneAttachment3D.new()
		att.name = a.node
		root.add_child(att)
		att.owner = root
		att.use_external_skeleton = true
		att.external_skeleton = att.get_path_to(skeleton)
		att.bone_name = a.bone
		for p: String in a.props:
			var src: MeshInstance3D = props.find_child(p, true, false) if props else null
			if src == null:
				continue
			var mi := MeshInstance3D.new()
			mi.name = p
			mi.mesh = src.mesh.duplicate()
			mi.layers = 2
			mi.transform = to_bone * src.transform
			att.add_child(mi)
			mi.owner = root
			made.append("%s/%s" % [a.node, p])
	var animator := Node.new()
	animator.name = "Animator"
	animator.set_script(load("res://scripts/character_animator.gd"))
	root.add_child(animator)
	animator.owner = root
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		return "pack failed %d" % err
	err = ResourceSaver.save(packed, spec.scene)
	root.free()
	if props:
		props.free()
	return "%s (%s)" % [spec.scene if err == OK else "save failed %d" % err, ", ".join(made)]
