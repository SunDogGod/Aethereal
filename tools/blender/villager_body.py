"""A villager's body wrapped in a linen shroud and bound with rope: the bodies the agents carry to
the hall's fire (a prop, not a character: no animations; a little sag through the middle so it
reads as limp in an agent's arms). It lies along x (head at -x), its underside on the ground at
z = 0, its middle at the origin. Scene: scenes/characters/villager_body_model.tscn.

Rebuild:  .\\tools\\blender\\rebuild.ps1 villager_body
"""
import math
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Vector  # noqa: E402
import character_base as cb   # noqa: E402
import mesh                   # noqa: E402
from paint import rgb, shade  # noqa: E402

LINEN, STAIN, ROPE = rgb("#b9ae99"), rgb("#8c8070"), rgb("#6b5536")
# Along the body, head to feet: (x, half width, half height). The ropes: where they bind it.
SHAPE = [(-0.83, 0.015, 0.015), (-0.80, 0.060, 0.058), (-0.73, 0.090, 0.088), (-0.66, 0.080, 0.078),
         (-0.61, 0.068, 0.062), (-0.55, 0.170, 0.095), (-0.42, 0.190, 0.115), (-0.25, 0.168, 0.110),
         (-0.10, 0.155, 0.100), (0.03, 0.168, 0.105), (0.22, 0.150, 0.092), (0.42, 0.112, 0.074),
         (0.62, 0.090, 0.062), (0.76, 0.074, 0.060), (0.82, 0.050, 0.050), (0.845, 0.012, 0.012)]
ROPES = (-0.61, -0.40, -0.10, 0.42, 0.70)
SAG = 0.035


def centre(x):
    return Vector((x, 0.0, -SAG * math.cos(math.pi * x / 1.7)))


def build():
    ch = cb.Character("villager_body", height=1.70)
    A, P = ch.atlas, ch.part("Body")
    r_cloth, r_rope = A.rect("cloth", 64, 32), A.rect("rope", 16, 8)
    w = {"Hips": 1.0}
    lift = max(h for _, _, h in SHAPE) + SAG    # underside on the ground
    rings = [{"c": centre(x) + Vector((0, 0, lift)), "x": Vector((0, 1, 0)), "y": Vector((0, 0, 1)),
              "rx": rw, "ry": rh, "ryb": rh * 0.9, "n": 2.4, "w": w} for x, rw, rh in SHAPE]
    mesh.loft(P, rings, 12, r_cloth.uv, cap0="pole", cap1="pole")
    for x in ROPES:
        rw = max(r[1] for r in SHAPE if abs(r[0] - x) < 0.09)
        rh = max(r[2] for r in SHAPE if abs(r[0] - x) < 0.09)
        c = centre(x) + Vector((0, 0, lift))
        mesh.loft(P, [{"c": c + Vector((dx, 0, 0)), "x": Vector((0, 1, 0)), "y": Vector((0, 0, 1)),
                       "rx": rw * k + 0.006, "ry": rh * k + 0.006, "n": 2.4, "w": w}
                      for dx, k in ((-0.012, 0.92), (0.0, 1.0), (0.012, 0.92))], 12, r_rope.uv)
    r_cloth.fill(LINEN)
    for u in (0.1, 0.35, 0.6, 0.85):
        r_cloth.vline(u, shade(LINEN, 0.9))                   # the wrap's folds, along the body
    for k, (u, v) in enumerate(((0.3, 0.55), (0.62, 0.4), (0.8, 0.7))):
        r_cloth.box(u, v, u + 0.12, v + 0.1, STAIN)             # old stains (soot and earth)
    r_rope.fill(ROPE)
    r_rope.vline(0.5, shade(ROPE, 0.7))
    return ch


if __name__ == "__main__":
    build().finish(animations=None)
