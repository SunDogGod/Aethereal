"""Plain grey stand-ins for Kael, Isabella and the guards, so the game runs with real skeletons
and animations before their looks are made. A look script (kael.py, isabella.py, guard.py)
replaces one by exporting the same name; nothing else needs to change.

    blender -b --factory-startup -P tools/blender/grey_bodies.py -- kael isabella guard
Then Godot's import and make_wrapper.gd for the same names (README.md).
"""
import math
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Matrix, Vector  # noqa: E402
import character_base as cb   # noqa: E402
import base_body as bb        # noqa: E402
import mesh                   # noqa: E402
import props                  # noqa: E402
from paint import rgb, shade  # noqa: E402

TORSO_F = [(0.86, 0.13, 0.080, 0.090, 2.2), (0.92, 0.168, 0.095, 0.105, 2.4), (0.99, 0.155, 0.090, 0.098, 2.4),
           (1.06, 0.125, 0.082, 0.082, 2.4), (1.15, 0.130, 0.095, 0.085, 2.5), (1.24, 0.140, 0.108, 0.090, 2.5),
           (1.31, 0.150, 0.098, 0.090, 2.6), (1.36, 0.160, 0.082, 0.085, 2.7), (1.395, 0.135, 0.066, 0.072, 2.5),
           (1.425, 0.082, 0.054, 0.056, 2.2), (1.44, 0.054, 0.047, 0.049, 2.0)]
GUARD = {"skin": "#34353a", "top": "#e4e4e4", "legs": "#3a3b40", "shoes": "#222327", "hair": "#2a2b30",
         "eye": "#111111", "lip": "#34353a"}


def kael():
    ch = cb.Character("kael", height=1.82, shoulders=1.04)
    bb.base_body(ch, bb.GREY)
    # Lamento, bone-white, slung on his back with the grip over his right shoulder.
    p = ch.prop("LamentoMesh", "Back", "Lamento")
    props.sword(p, ch.atlas, length=0.95, steel="#ddd5c0", guard="#8f8a80", grip="#4a4642", name="lamento")
    mesh.transform_part(p, Matrix.Translation((0, 0.38, 0)) @ Matrix.Rotation(math.pi, 4, "Z"))
    return ch


def isabella():
    ch = cb.Character("isabella", height=1.66, shoulders=0.9, hips=1.06)
    bb.base_body(ch, bb.GREY, torso=TORSO_F)
    A = ch.atlas
    r_wood, r_ink, r_bell = A.rect("brush", 16, 8), A.rect("ink", 8, 8), A.rect("bell", 16, 8)
    brush = ch.prop("BrushMesh", "Weapon_R", "Brush")
    props.rod(brush, [(-0.08, 0.0, 0.0), (-0.075, 0.009, 0.009), (0.22, 0.008, 0.008)], r_wood.uv, sides=6)
    props.rod(brush, [(0.215, 0.010, 0.010), (0.26, 0.014, 0.014), (0.31, 0.0, 0.0)], r_ink.uv, sides=6)
    r_wood.fill(rgb("#8a6b3c"))
    r_ink.fill(rgb("#141418"))
    bell = ch.prop("BellMesh", "Sheath", "Bell")
    props.rod(bell, [(0.0, 0.0, 0.0), (0.005, 0.012, 0.012), (0.03, 0.026, 0.026), (0.06, 0.034, 0.034),
                     (0.075, 0.042, 0.042)], r_bell.uv, sides=8)
    r_bell.fill(rgb("#c9b04e"))
    r_bell.hline(0.8, shade(rgb("#c9b04e"), 1.3))
    return ch


def guard():
    ch = cb.Character("guard", height=1.80)
    bb.base_body(ch, GUARD, hair=False, top_obj="Coat", face=False)
    A = ch.atlas
    r_visor = A.rect("visor", 16, 8)
    r_visor.fill(rgb("#ffffff"))   # white: guard.gd tints it with the GuardData visor colour
    v = ch.prop("Visor", "Head", "HeadGear")
    s = ch.J["height"] / 1.72 * 1.08   # the head's own scale (body.Head)
    y, z = 0.100 * s, 0.098 * s
    props.rod(v, [(-0.094 * s, 0.0, 0.0, (0, y, z - 0.035 * s)), (-0.086 * s, 0.015, 0.008, (0, y, z - 0.03 * s)),
                  (-0.05 * s, 0.017, 0.009, (0, y, z - 0.004 * s)), (0.0, 0.018, 0.009, (0, y, z + 0.01 * s)),
                  (0.05 * s, 0.017, 0.009, (0, y, z - 0.004 * s)), (0.086 * s, 0.015, 0.008, (0, y, z - 0.03 * s)),
                  (0.094 * s, 0.0, 0.0, (0, y, z - 0.035 * s))], r_visor.uv, sides=6, along="x")
    props.sword(ch.prop("BladeMesh", "Weapon_R", "Blade"), A, length=0.78, steel="#9aa0a8", guard="#4a4c52",
                grip="#1c1c20", name="blade")
    return ch


BUILDERS = {"kael": kael, "isabella": isabella, "guard": guard}

if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(BUILDERS)
    for n in names:
        BUILDERS[n]().finish()
