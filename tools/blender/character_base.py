"""Building a character, start to finish. A character script does:

    import character_base as cb
    ch = cb.Character("kael", height=1.82)       # empty scene, the shared skeleton, a 256 px atlas
    body = ch.part("Body")                       # geometry skinned to the skeleton
    ... body.* builders (see body.py and base_body() below), painting into ch.atlas ...
    blade = ch.prop("Lamento", "Weapon_R")       # a prop: grip at the origin, length along +Y
    ch.finish()                                  # animations, export, Godot material + import + wrapper spec

finish() writes into models/characters/: <name>.glb (body + skeleton + every animation),
<name>_props.glb, <name>.png (atlas), <name>_mat.tres (the PS1 ShaderMaterial), the .import files
that tell Godot to use that material, and <name>.json (what make_wrapper.gd needs to build
scenes/characters/<name>_model.tscn). Then run Godot's import and make_wrapper.gd (README.md).
"""
import json
import os
import sys
import bpy

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import rig as rigmod   # noqa: E402
import pose            # noqa: E402
import paint           # noqa: E402
import mesh            # noqa: E402
import anims_loco      # noqa: E402
import anims_combat    # noqa: E402

PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(PROJECT, "models", "characters")


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = pose.FPS


class Character:
    def __init__(self, name, height=1.72, shoulders=1.0, hips=1.0, atlas_size=256):
        clear_scene()
        self.name = name
        self.J = rigmod.layout(height, shoulders, hips)
        self.arm = rigmod.build_rig(name, self.J)
        self.rig = pose.Rig(self.arm)
        self.atlas = paint.Atlas(atlas_size)
        self.parts = {}
        self.props = {}        # name -> (Part, bone, node name in Godot)
        self.attach_order = []

    def part(self, obj="Body"):
        """Geometry for one skinned object. Use a second object (e.g. "Coat") only when the game
        needs to recolour it on its own (guards tint their coat from GuardData)."""
        if obj not in self.parts:
            self.parts[obj] = mesh.Part()
        return self.parts[obj]

    def prop(self, name, bone, node=None):
        """A rigid prop riding on an attach bone. Model it with its grip at the origin, its length
        along +Y and its edge (if any) along +Z. In Godot it becomes <node>/<name> under the model
        (node defaults to the prop name), a BoneAttachment3D following `bone`."""
        p = mesh.Part()
        self.props[name] = (p, bone, node or name)
        return p

    def finish(self, animations="all", preview=None):
        os.makedirs(OUT_DIR, exist_ok=True)
        png = os.path.join(OUT_DIR, self.name + ".png")
        img = self.atlas.save(png, self.name + "_atlas")
        mat = paint.material(self.name, img)
        objects = [self.arm]
        tris = 0
        for obj, part in self.parts.items():
            objects.append(mesh.to_object(part, obj, self.arm, mat))
            tris += part.tris()
        prop_objects = []
        self.prop_objects = prop_objects
        for name, (part, bone, node) in self.props.items():
            prop_objects.append(mesh.to_object(part, name, None, mat))
            tris += part.tris()
        print("CHARACTER %s: %d triangles (props included)" % (self.name, tris))
        if animations == "all":
            anims_loco.add_all(self.rig)
            anims_combat.add_all(self.rig)
        elif animations:
            animations(self.rig)
        pose.reset_pose(self.arm)
        self._export(objects, os.path.join(OUT_DIR, self.name + ".glb"), True)
        if prop_objects:
            self._export(prop_objects, os.path.join(OUT_DIR, self.name + "_props.glb"), False)
        self._godot_files(bool(prop_objects))
        if preview:
            import preview as pv
            pv.sheet(self.arm, preview["anims"], preview["out"], views=preview.get("views", ("behind", "side")),
                     count=preview.get("count", 6))
        if os.environ.get("SAVE_BLEND"):
            bpy.ops.wm.save_as_mainfile(filepath=os.environ["SAVE_BLEND"])
        return tris

    def show_props_in_blender(self):
        """For previews only (after finish): hang each prop on its bone so renders show it."""
        for ob in self.prop_objects:
            bone = self.props[ob.name][1]
            ob.parent = self.arm
            ob.parent_type = 'BONE'
            ob.parent_bone = bone
            ob.matrix_world = self.arm.matrix_world @ self.arm.data.bones[bone].matrix_local

    def _export(self, objects, path, animated):
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.export_scene.gltf(
            filepath=path, export_format='GLB', use_selection=True, export_image_format='NONE',
            export_yup=True, export_apply=False, export_animations=animated, export_animation_mode='ACTIONS',
            export_force_sampling=True, export_skins=animated, export_def_bones=False,
            export_reset_pose_bones=True, export_optimize_animation_size=False, export_morph=False,
            export_extras=False, export_cameras=False, export_lights=False)

    def _godot_files(self, has_props):
        res = "res://models/characters/"
        n = self.name
        with open(os.path.join(OUT_DIR, n + "_mat.tres"), "w", newline="\n") as f:
            f.write('[gd_resource type="ShaderMaterial" format=3]\n\n'
                    '[ext_resource type="Shader" path="res://shaders/ps1_surface.gdshader" id="1_shader"]\n'
                    '[ext_resource type="Texture2D" path="%s%s.png" id="2_atlas"]\n\n'
                    '[resource]\nshader = ExtResource("1_shader")\n'
                    'shader_parameter/albedo_texture = ExtResource("2_atlas")\n'
                    'shader_parameter/snap_scale = 2.0\n' % (res, n))
        for glb in [n + ".glb"] + ([n + "_props.glb"] if has_props else []):
            write_import(os.path.join(OUT_DIR, glb), {n: res + n + "_mat.tres"})
        spec = {
            "name": n,
            "root": n.capitalize() + "Model",
            "glb": res + n + ".glb",
            "props_glb": res + n + "_props.glb" if has_props else "",
            "scene": "res://scenes/characters/%s_model.tscn" % n,
            "attach": [],
            # A script for the model scene's root (e.g. Aeneas's outfit switches), if the character has one.
            "root_script": getattr(self, "root_script", ""),
        }
        nodes = {}
        for name, (part, bone, node) in self.props.items():
            if node not in nodes:
                nodes[node] = {"node": node, "bone": bone, "props": []}
                spec["attach"].append(nodes[node])
            nodes[node]["props"].append(name)
        with open(os.path.join(OUT_DIR, n + ".json"), "w", newline="\n") as f:
            json.dump(spec, f, indent=1)


def write_import(glb_path, materials):
    """The .import file next to a .glb: use our PS1 ShaderMaterial for the named Blender
    materials, keep every animation track, and skip LODs / shadow meshes."""
    path = glb_path + ".import"
    head = '[remap]\n\nimporter="scene"\nimporter_version=1\n'
    if os.path.exists(path):
        old = open(path, encoding="utf-8").read()
        for line in old.splitlines():
            if line.startswith("uid="):
                head += line + "\n"
    mats = ",\n".join('"%s": {\n"use_external/enabled": true,\n"use_external/path": "%s"\n}' % (k, v)
                      for k, v in materials.items())
    body = ("\n[params]\n\nmeshes/ensure_tangents=false\nmeshes/generate_lods=false\n"
            "meshes/create_shadow_meshes=false\nanimation/fps=30\nanimation/remove_immutable_tracks=false\n"
            "animation/trimming=false\n_subresources={\n\"materials\": {\n%s\n}\n}\n" % mats)
    with open(path, "w", newline="\n") as f:
        f.write(head + body)
