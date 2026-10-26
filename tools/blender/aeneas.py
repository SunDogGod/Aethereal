"""Aeneas, about sixteen: brown hair short at the sides and longer on top with a thin tail at the
nape, a dark brown leather jacket (high collar, light trim) worn open over a cream shirt, dark
trousers, brown boots. His sword (Rocinante) rides in a scabbard at his left hip (his left hand
holds it there while he moves; the game moves the sword to his right hand when he draws), a knife
across the small of his back, a rifle on his back. In the first arc he wears a travel poncho over
it all (aeneas_gear.py): set PONCHO = False to build him without it, or untick Poncho on his Model
in Godot (scripts/aeneas_outfit.gd) to hide it.

Rebuild:  blender -b --factory-startup -P tools/blender/aeneas.py
then Godot's import and make_wrapper.gd (see tools/blender/README.md).
"""
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import character_base as cb   # noqa: E402
import base_body as bb        # noqa: E402
import body                   # noqa: E402
import mesh                   # noqa: E402
import props                  # noqa: E402
import aeneas_gear as gear    # noqa: E402
import aeneas_hair as hair    # noqa: E402
import aeneas_anims           # noqa: E402
import anims_combat           # noqa: E402
from paint import rgb, shade  # noqa: E402

PONCHO = True   # build the first arc's poncho (its own object, "Poncho", so the game can hide it)

C = {k: rgb(v) for k, v in {
    "skin": "#e2b593", "hair": "#5e3c25", "hair_dark": "#3f2717", "eye": "#3a2a1e", "iris": "#6b4a2b",
    "lip": "#b27a66", "brow": "#4a2e1b", "tie": "#2b1b12",
    "jacket": "#4d3020", "trim": "#a4805a", "lining": "#2b1b12", "seam": "#352113",
    "shirt": "#e9dec4", "trousers": "#2c2b33", "boot": "#6e4729", "boot_cuff": "#8c5d38", "sole": "#2a1d14",
    "belt": "#3a2415", "brass": "#c9a24a", "strap": "#5a3d26",
    # The poncho (Proposed): dusty, sun-faded olive with rust and bone stripes and a patch.
    "poncho": "#6e6a50", "poncho_dk": "#46432f", "poncho_band": "#7a4532", "poncho_line": "#b3a581",
    "patch": "#86704f"}.items()}

# The jacket: a little bigger than the torso, open at the front (last number: opening half-angle).
JACKET = [(0.90, 0.172, 0.100, 0.108, 2.5, 0.0, 36), (0.97, 0.165, 0.100, 0.104, 2.5, 0.0, 32),
          (1.06, 0.152, 0.100, 0.098, 2.6, 0.0, 28), (1.15, 0.161, 0.112, 0.101, 2.6, 0.0, 25),
          (1.24, 0.173, 0.120, 0.108, 2.7, 0.0, 24), (1.31, 0.187, 0.112, 0.108, 2.8, 0.0, 26),
          (1.36, 0.201, 0.098, 0.102, 2.9, 0.0, 30), (1.395, 0.169, 0.083, 0.089, 2.7, 0.0, 36),
          (1.425, 0.108, 0.071, 0.074, 2.3, 0.0, 42)]
COLLAR = [(1.40, 0.104, 0.078, 0.082, 2.2, -0.004, 44), (1.44, 0.082, 0.068, 0.073, 2.0, -0.006, 44),
          (1.49, 0.083, 0.074, 0.079, 2.0, -0.008, 46), (1.515, 0.090, 0.082, 0.086, 2.0, -0.01, 50)]
SLEEVE = [(0.0, 0.060, 0.062), (0.25, 0.056, 0.058), (0.7, 0.050, 0.052), (1.0, 0.047, 0.048),
          (1.3, 0.047, 0.049), (1.75, 0.043, 0.045), (1.85, 0.047, 0.049), (2.0, 0.046, 0.048)]
TROUSERS = [(-0.15, 0.084, 0.090), (0.0, 0.087, 0.092), (0.3, 0.078, 0.083), (0.7, 0.065, 0.069),
            (1.0, 0.057, 0.060), (1.3, 0.057, 0.061, 0.065), (1.6, 0.050, 0.053), (2.0, 0.045, 0.047)]
BOOT = [(1.30, 0.066, 0.068, 0.072), (1.34, 0.067, 0.069, 0.073), (1.36, 0.061, 0.064, 0.068),
        (1.6, 0.056, 0.059, 0.062), (1.85, 0.051, 0.054, 0.054), (2.02, 0.050, 0.055, 0.050)]
BELT = [(0.950, 0.163, 0.097, 0.101, 2.5), (0.992, 0.157, 0.095, 0.098, 2.5)]


def hair_line(theta):
    """Aeneas's hair reaches lower at the back (short sides, a fuller nape)."""
    return bb.hair_line(theta) - 0.012


def build():
    ch = cb.Character("aeneas", height=1.72)
    J, A, P = ch.J, ch.atlas, ch.part("Body")
    r_head = A.rect("head", 128, 72)
    r_jacket = A.rect("jacket", 96, 56)
    r_sleeve = A.rect("sleeve", 64, 40)
    r_shirt = A.rect("shirt", 64, 48)
    r_trousers = A.rect("trousers", 48, 48)
    r_boot = A.rect("boot", 48, 32)
    r_foot = A.rect("foot", 40, 24)
    r_collar = A.rect("collar", 48, 16)
    r_lining = A.rect("lining", 8, 8)
    r_hand = A.rect("hand", 24, 16)
    r_neck = A.rect("neck", 16, 12)
    r_belt = A.rect("belt", 64, 8)
    r_strap = A.rect("strap", 8, 32)
    r_sheath = A.rect("sheath", 16, 16)

    # Shirt (the torso) and neck.
    body.trunk(P, J, r_shirt, bb.TORSO, cap0="pole")
    r_shirt.fill(C["shirt"])
    r_shirt.box(0, 0.0, 1, 0.22, C["trousers"])          # below the belt: trousers
    r_shirt.vline(0.5, shade(C["shirt"], 0.82), 1, 0.25, 1.0)   # button line
    for v in (0.4, 0.55, 0.7, 0.85):
        r_shirt.dot(0.5, v, shade(C["shirt"], 0.7))
    body.neck(P, J, r_neck)
    r_neck.fill(C["skin"])
    # Head, face, ears, nose.
    head = body.Head(J)
    head.build(P, r_head)
    body.nose(P, head, r_head)
    body.ear(P, head, r_head, 1)
    body.ear(P, head, r_head, -1)
    bb.paint_head(head, r_head, C["skin"], C["hair_dark"], C["eye"], C["lip"], brow=C["brow"],
                  hairline=hair_line, iris=C["iris"])
    hair.build(P, head, A, hair_line, C)   # the haircut: aeneas_hair.py
    # Jacket, collar, sleeves.
    body.trunk(P, J, r_jacket, JACKET, segs=18, arc=(126, 414), thickness=0.008, lining=r_lining, legs=0.6)
    body.trunk(P, J, r_collar, COLLAR, segs=12, arc=(134, 406), thickness=0.007, lining=r_lining)
    _paint_jacket(r_jacket, r_collar, r_lining, r_sleeve)
    bb.mirrored(P, lambda: body.limb(P, J, body.arm_joints(J), ("UpperArm_R", "LowerArm_R"), r_sleeve,
                                     SLEEVE, hand_bone="Hand_R", cap0="pole", cap1="pole"))
    bb.mirrored(P, lambda: body.fist(P, J, r_hand))
    r_hand.fill(C["skin"])
    r_hand.box(0, 0.0, 1, 0.18, shade(C["jacket"], 0.8))   # glove cuff at the wrist
    r_hand.hline(0.62, shade(C["skin"], 0.84))               # knuckle line
    # Belt, strap, sheath.
    body.trunk(P, J, r_belt, BELT, segs=16)
    r_belt.fill(C["belt"])
    r_belt.box(0.46, 0.15, 0.54, 0.85, C["brass"])
    r_belt.box(0.48, 0.35, 0.52, 0.65, C["belt"])
    _strap(P, J, r_strap)
    gear.knife_sheath(P, J, r_sheath, C["belt"], C["brass"])
    # Trousers and boots.
    bb.mirrored(P, lambda: body.limb(P, J, body.leg_joints(J), ("UpperLeg_R", "LowerLeg_R"), r_trousers, TROUSERS))
    r_trousers.fill(C["trousers"])
    r_trousers.seam(0.0, shade(C["trousers"], 0.75), shade(C["trousers"], 1.25))
    r_trousers.seam(0.5, shade(C["trousers"], 0.75), shade(C["trousers"], 1.25))
    bb.mirrored(P, lambda: body.limb(P, J, body.leg_joints(J), ("UpperLeg_R", "LowerLeg_R"), r_boot, BOOT))
    r_boot.fill(C["boot"])
    r_boot.box(0, 0.86, 1, 1.0, C["boot_cuff"])
    r_boot.hline(0.86, shade(C["boot"], 0.65))
    r_boot.seam(0.5, shade(C["boot"], 0.7), shade(C["boot"], 1.2), 0.0, 0.85)
    bb.mirrored(P, lambda: body.foot(P, J, r_foot, rows=[
        (-0.09, 0.034, 0.038, -0.034), (-0.065, 0.045, 0.056, -0.024), (0.0, 0.050, 0.062, -0.018),
        (0.075, 0.053, 0.043, -0.040), (0.14, 0.053, 0.032, -0.052), (0.195, 0.045, 0.025, -0.06)]))
    _paint_foot(r_foot)
    # The poncho: its own object so the game can switch it off.
    if PONCHO:
        Q = ch.part("Poncho")
        r_poncho, r_hood = A.rect("poncho", 128, 40), A.rect("hood", 48, 20)
        r_pin = A.rect("poncho_in", 8, 8)
        gear.poncho(Q, J, r_poncho, r_pin)
        gear.hood(Q, J, r_hood)
        gear.sling(Q, J, r_strap)
        gear.paint_poncho(r_poncho, r_hood, r_pin, C)
    # Props. The sword starts in his hand (Weapon_R); the game moves it to the Scabbard bone.
    props.sword(ch.prop("Rocinante", "Weapon_R", "Sword"), A, name="rocinante")
    props.scabbard(ch.prop("ScabbardMesh", "Scabbard", "Scabbard"), A)
    props.knife(ch.prop("KnifeMesh", "Knife", "Knife"), A)
    rifle = ch.prop("RifleMesh", "Back", "Rifle")
    props.rifle(rifle, A)
    mesh.transform_part(rifle, mesh_offset(0.0, 0.0, 0.04))   # +Z is away from his back: clear the poncho
    ch.root_script = "res://scripts/aeneas_outfit.gd"
    return ch


def mesh_offset(x, y, z):
    from mathutils import Matrix
    return Matrix.Translation((x, y, z))


def animations(rig):
    """His locomotion (aeneas_anims.add_loco: the shared cycles, his left arm tamed for the poncho),
    the shared fighting set, then his own (the sheathed carry, iai, draw, sheathe)."""
    anims_combat.add_all(rig)
    aeneas_anims.add_all(rig)


def _paint_foot(r):
    """Sole band around the bottom of the boot foot (rings run around: back, side, top, side)."""
    r.fill(C["boot"])
    r.box(0.0, 0.0, 0.18, 1.0, C["sole"])     # underside (the first quarter faces down)
    r.box(0.82, 0.0, 1.0, 1.0, C["sole"])
    r.box(0.0, 0.0, 1.0, 0.08, shade(C["boot"], 0.7))  # heel
    r.vline(0.5, shade(C["boot"], 1.15), 1, 0.3, 1.0)   # a light crease over the toes


def _paint_jacket(r, collar, lining, sleeve):
    jk, tr, sm = C["jacket"], C["trim"], C["seam"]
    r.fill(jk)
    r.box(0.0, 0.0, 0.035, 1.0, tr)          # front edge trims (the two ends of the shell)
    r.box(0.965, 0.0, 1.0, 1.0, tr)
    r.box(0.0, 0.0, 1.0, 0.07, tr)            # hem band
    r.hline(0.07, shade(jk, 0.7))
    for u in (0.25, 0.75):                    # side seams
        r.seam(u, sm, shade(jk, 1.25), 0.07, 0.95)
    r.seam(0.5, sm, shade(jk, 1.25), 0.07, 1.0)   # back seam
    r.hline(0.80, sm)                          # yoke across the shoulders
    r.hline(0.79, shade(jk, 1.2))
    for u in (0.12, 0.88):                     # chest pockets: flaps with a button
        r.box(u - 0.05, 0.6, u + 0.05, 0.64, shade(jk, 0.75))
        r.dot(u, 0.6, C["brass"])
    collar.fill(jk)
    collar.box(0, 0.8, 1, 1.0, tr)
    collar.box(0.0, 0.0, 0.05, 1.0, tr)
    collar.box(0.95, 0.0, 1.0, 1.0, tr)
    lining.fill(C["lining"])
    sleeve.fill(jk)
    sleeve.box(0, 0.88, 1, 1.0, tr)            # cuff
    sleeve.hline(0.88, shade(jk, 0.7))
    sleeve.seam(0.5, sm, shade(jk, 1.25), 0.0, 0.86)
    sleeve.hline(0.48, shade(jk, 0.8))         # a crease at the elbow


def _strap(P, J, r):
    """The rifle sling: over the right shoulder and down across the chest to the left hip."""
    path = [(18, 1.40, 0.004), (50, 1.33, 0.010), (82, 1.22, 0.014), (112, 1.10, 0.012), (140, 0.99, 0.010),
            (158, 0.93, 0.008)]
    pts = [body.trunk_point(J, JACKET, th, z, lift) for th, z, lift in path]
    zs = [z for _, z, _ in path]
    def w(k):
        return body.spine_w(J, zs[0] + (zs[-1] - zs[0]) * k)
    body.strand(P, pts, [0.020] * (len(pts) - 1) + [0.018], 0.28, r.uv, w, up=body.Vector((0, 1, 0.2)), sides=4)
    r.fill(C["strap"])
    r.vline(0.25, shade(C["strap"], 1.35))
    r.vline(0.75, shade(C["strap"], 1.35))


if __name__ == "__main__":
    ch = build()
    ch.finish(animations=animations)
