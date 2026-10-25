"""Contact sheets for checking a character and its animations without opening Godot.

    blender -b --factory-startup -P tools/blender/preview.py -- <file.blend> <out.png> <anim> [times...]

or from another script: preview.sheet(arm, ["run", "idle"], out_png). Renders with Blender's
Workbench (flat, textured) from behind-left (the game camera) and from the side.
"""
import math
import os
import sys
import bpy
import numpy as np
from mathutils import Vector


def _camera(sc):
    cam = sc.objects.get("PreviewCam")
    if cam is None:
        cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
        sc.collection.objects.link(cam)
    cam.data.lens = 50
    sc.camera = cam
    return cam


def _aim(cam, eye, target):
    cam.location = eye
    d = Vector(target) - Vector(eye)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


VIEWS = {
    # name: (eye offset from the target, target height)
    "behind": ((-0.9, -2.5, 0.75), 0.9),   # over his left shoulder from behind: the game camera
    "side": ((2.7, 0.3, 0.2), 0.85),
    "front": ((0.8, 2.6, 0.2), 0.9),
    "face": ((0.25, 0.95, 0.02), 1.58),
}


def render_one(path, view, size=(256, 320), target_z=None):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'TEXTURE'
    sc.display.shading.show_object_outline = False
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.film_transparent = False
    sc.world = sc.world or bpy.data.worlds.new("W")
    off, tz = VIEWS[view]
    tz = target_z if target_z is not None else tz
    cam = _camera(sc)
    _aim(cam, (off[0], off[1], tz + off[2]), (0, 0, tz))
    if view == "face":
        cam.data.lens = 85
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def _load(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(img)
    return px


def sheet(arm, anims, out_png, views=("behind", "side"), count=6, size=(200, 260)):
    """One row per (animation, view): `count` evenly spaced frames. `anims` holds action names
    (with or without the _loop suffix) or (name, [times]) pairs."""
    tmp = os.path.join(os.path.dirname(out_png), "_frame.png")
    rows = []
    for entry in anims:
        name, times = (entry if isinstance(entry, tuple) else (entry, None))
        act = bpy.data.actions.get(name) or bpy.data.actions.get(name + "_loop")
        if act is None:
            print("PREVIEW: no action", name)
            continue
        arm.animation_data_create()
        arm.animation_data.action = act
        f0, f1 = act.frame_range
        if times is None:
            frames = [round(f0 + (f1 - f0) * i / max(1, count - 1)) for i in range(count)]
        else:
            frames = [round(t * bpy.context.scene.render.fps) for t in times]
        for view in views:
            row = []
            for fr in frames:
                bpy.context.scene.frame_set(int(fr))
                render_one(tmp, view, size)
                row.append(_load(tmp))
            rows.append(np.concatenate(row, axis=1))
    arm.animation_data.action = None
    width = max(r.shape[1] for r in rows)
    rows = [np.pad(r, ((0, 0), (0, width - r.shape[1]), (0, 0))) for r in rows]
    full = np.concatenate(rows[::-1], axis=0)  # Blender images are bottom-up
    img = bpy.data.images.new("sheet", full.shape[1], full.shape[0])
    img.pixels.foreach_set(full.ravel())
    img.filepath_raw = out_png
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)
    if os.path.exists(tmp):
        os.remove(tmp)
    print("PREVIEW:", out_png)


if __name__ == "__main__" and "--" in sys.argv:
    args = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.open_mainfile(filepath=args[0])
    names = args[2].split(",")
    sheet(bpy.data.objects["Armature"], names, args[1])
