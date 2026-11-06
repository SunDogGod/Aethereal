"""Aeneas, about sixteen: brown hair short at the sides and longer on top with a thin tail at the
nape, aviator goggles pushed up on his forehead, a brass earring (aeneas_hair.py), green eyes.
A navy cropped jacket (chest flap pockets, epaulettes, scuffed and dusty) worn open over a
grey-olive shirt, olive cargo trousers with knee pads and shin guards, dark boots, fingerless
gloves, a belt with a pouch at his right hip. His sword (Rocinante, a rapier with a swept hilt)
rides in a worn scabbard at his left hip (his left hand holds it there while he moves; the game
moves the sword to his right hand when he draws), a knife across the small of his back, a rifle
on his back. In the first arc he wears a travel poncho over it all (aeneas_gear.py): set
PONCHO = False to build him without it, or untick Poncho on his Model in Godot
(scripts/aeneas_outfit.gd) to hide it. One hot colour on him: the rust and amber of the poncho's
band and the goggles' lenses.

Rebuild:  blender -b --factory-startup -P tools/blender/aeneas.py
then Godot's import and make_wrapper.gd (see tools/blender/README.md).
"""
import math
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Vector   # noqa: E402
import agency_parts as ap     # noqa: E402
import character_base as cb   # noqa: E402
import base_body as bb        # noqa: E402
import body                   # noqa: E402
import mesh                   # noqa: E402
import props                  # noqa: E402
import aeneas_gear as gear    # noqa: E402
import aeneas_hair as hair    # noqa: E402
import face                   # noqa: E402
import face_paint             # noqa: E402
import aeneas_anims           # noqa: E402
import anims_combat           # noqa: E402
from paint import rgb, shade  # noqa: E402

PONCHO = True   # build the first arc's poncho (its own object, "Poncho", so the game can hide it)

C = {k: rgb(v) for k, v in {
    "skin": "#dfb08c", "hair": "#5e3c25", "hair_dark": "#3f2717", "eye": "#2a2a22", "iris": "#4f8c5c",
    "lip": "#b27a66", "brow": "#4a2e1b", "tie": "#2b1b12",
    "jacket": "#2f3a4f", "trim": "#4a5569", "lining": "#1d2230", "seam": "#222a3a", "scuff": "#5e6a80",
    "shirt": "#8a8870", "trousers": "#4c5040", "boot": "#4a3222", "sole": "#1e1613",
    "belt": "#3a2415", "brass": "#c9a24a", "strap": "#5a3d26", "pouch": "#5a3d26", "pad": "#2e2824",
    "glove": "#3a2a1e", "steel": "#b5bac2", "steel_dk": "#5a5e66", "hilt": "#b08a3e", "grip": "#2a1e16",
    "scab": "#3a2416", "cord": "#8a7a52", "goggle": "#3a2a1e", "lens": "#b8702e", "dust": "#8c8272",
    # The poncho: dusty, sun-faded olive with a rust band (his one hot colour) and bone stripes.
    "poncho": "#6e6a50", "poncho_dk": "#46432f", "poncho_band": "#8f4630", "poncho_line": "#b3a581",
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
BOOT = [(1.30, 0.062, 0.064, 0.068), (1.6, 0.056, 0.059, 0.062), (1.85, 0.051, 0.054, 0.054),
        (2.02, 0.050, 0.055, 0.050)]   # a plain shaft: the shin guards (aeneas_gear.SHIN) strap over it
BELT = [(0.950, 0.163, 0.097, 0.101, 2.5), (0.992, 0.157, 0.095, 0.098, 2.5)]


# His face (face.py): about sixteen, big open green eyes, a short nose with a lifted tip, high
# cheekbones, a narrow pointed chin, a mouth that turns up on one side.
FACE = face.look(face.YOUNG_MAN, rows=face.HEART_ROWS, nose=0.0155, nose_w=4.7, nose_tip_z=0.072, chin=0.006,
                 chin_w=11.0, jaw=0.001, cheek=0.0042, hollow=0.001, eye_tilt=0.0010,
                 brow_thick=0.0036, brow_arch=0.0022, smirk=0.00045, lip_sat=0.35,
                 skin=C["skin"], hair=C["hair_dark"], brow=C["brow"], lash_col=shade(C["eye"], 0.7),
                 iris=C["iris"], lip=C["lip"])


def hair_line(theta):
    """Aeneas's hair reaches lower at the back (short sides, a fuller nape)."""
    return bb.hair_line(theta) - 0.012


def build():
    ch = cb.Character("aeneas", height=1.72, atlas_size=512)
    J, A, P = ch.J, ch.atlas, ch.part("Body")
    r_head = A.rect("head", *face.HEAD_RECT)
    r_jacket = A.rect("jacket", 96, 56)
    r_sleeve = A.rect("sleeve", 64, 40)
    r_shirt = A.rect("shirt", 64, 48)
    r_trousers = A.rect("trousers", 48, 48)
    r_boot = A.rect("boot", 48, 24)
    r_foot = A.rect("foot", 40, 24)
    r_collar = A.rect("collar", 48, 16)
    r_lining = A.rect("lining", 8, 8)
    r_hand = A.rect("hand", 24, 16)
    r_neck = A.rect("neck", 16, 12)
    r_belt = A.rect("belt", 64, 8)
    r_strap = A.rect("strap", 8, 32)
    r_sheath = A.rect("sheath", 16, 16)
    r_pouch, r_flap, r_epaulette = A.rect("pouch", 16, 16), A.rect("flap", 16, 8), A.rect("epaulette", 8, 8)
    r_knee, r_shin = A.rect("knee", 24, 16), A.rect("shin", 24, 24)

    # Shirt (the torso) and neck.
    body.trunk(P, J, r_shirt, bb.TORSO, cap0="pole")
    r_shirt.fill(C["shirt"])
    r_shirt.box(0, 0.0, 1, 0.22, C["trousers"])          # below the belt: trousers
    r_shirt.vline(0.5, shade(C["shirt"], 0.82), 1, 0.25, 1.0)   # button line
    for v in (0.4, 0.55, 0.7, 0.85):
        r_shirt.dot(0.5, v, shade(C["shirt"], 0.7))
    body.neck(P, J, r_neck)
    r_neck.fill(C["skin"])
    # Head and face (face.py shapes it, face_paint.py paints it), ears, the haircut, goggles and
    # earring (aeneas_hair.py).
    head = face.Head(J, FACE)
    head.build(P, r_head)
    face.ears(P, head, A.rect("ear", 16, 16), FACE, C["skin"], shade(C["skin"], 0.8))
    face_paint.paint(head, FACE, hair_line)
    hair.build(P, head, A, hair_line, C, FACE)
    # Jacket, collar, sleeves, epaulettes and pocket flaps.
    body.trunk(P, J, r_jacket, JACKET, segs=18, arc=(126, 414), thickness=0.008, lining=r_lining, legs=0.6)
    body.trunk(P, J, r_collar, COLLAR, segs=12, arc=(134, 406), thickness=0.007, lining=r_lining)
    _paint_jacket(r_jacket, r_collar, r_lining, r_sleeve)
    _epaulettes(P, J, r_epaulette)
    _pocket_flaps(P, J, r_flap)
    bb.mirrored(P, lambda: body.limb(P, J, body.arm_joints(J), ("UpperArm_R", "LowerArm_R"), r_sleeve,
                                     SLEEVE, hand_bone="Hand_R", cap0="pole", cap1="pole"))
    bb.mirrored(P, lambda: body.fist(P, J, r_hand))
    r_hand.fill(C["skin"])
    r_hand.box(0, 0.0, 1, 0.58, C["glove"])                  # fingerless glove (wrist to the knuckles)
    r_hand.hline(0.58, shade(C["glove"], 0.6))
    r_hand.box(0, 0.0, 1, 0.12, shade(C["glove"], 1.3))      # its strap at the wrist
    # Belt, pouch, strap, sheath.
    body.trunk(P, J, r_belt, BELT, segs=16)
    r_belt.fill(C["belt"])
    r_belt.box(0.46, 0.15, 0.54, 0.85, C["brass"])
    r_belt.box(0.48, 0.35, 0.52, 0.65, C["belt"])
    gear.pouch(P, J, r_pouch, BELT, C)
    _strap(P, J, r_strap)
    gear.knife_sheath(P, J, r_sheath, C["belt"], C["brass"])
    # Trousers, knee pads and shin guards, boots.
    bb.mirrored(P, lambda: body.limb(P, J, body.leg_joints(J), ("UpperLeg_R", "LowerLeg_R"), r_trousers, TROUSERS))
    _paint_trousers(r_trousers)
    gear.leg_armour(P, J, r_knee, r_shin, C)
    bb.mirrored(P, lambda: body.limb(P, J, body.leg_joints(J), ("UpperLeg_R", "LowerLeg_R"), r_boot, BOOT))
    r_boot.fill(C["boot"])
    r_boot.seam(0.5, shade(C["boot"], 0.7), shade(C["boot"], 1.2))
    ap.weather(r_boot, 0.3, C["dust"], seed=7, strength=0.4, flip=True)   # dust toward the foot
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
    gear.rapier(ch.prop("Rocinante", "Weapon_R", "Sword"), A, C)
    gear.scabbard(ch.prop("ScabbardMesh", "Scabbard", "Scabbard"), A, C)
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
    """Navy cloth with stitched seams, a hem band, chest pockets, scuffs and the road's dust."""
    jk, tr, sm = C["jacket"], C["trim"], C["seam"]
    r.fill(jk)
    r.box(0.0, 0.0, 0.035, 1.0, tr)          # front edge trims (the two ends of the shell)
    r.box(0.965, 0.0, 1.0, 1.0, tr)
    r.box(0.0, 0.0, 1.0, 0.07, tr)            # hem band
    r.hline(0.07, shade(jk, 0.7))
    gear.stitches(r, 0.0, 0.035, 1.0, 0.035, shade(tr, 1.4))
    for u in (0.25, 0.75):                    # side seams
        r.seam(u, sm, shade(jk, 1.25), 0.07, 0.95)
    r.seam(0.5, sm, shade(jk, 1.25), 0.07, 1.0)   # back seam
    r.hline(0.80, sm)                          # yoke across the shoulders
    gear.stitches(r, 0.0, 0.775, 1.0, 0.775, shade(jk, 1.5))
    for u in (0.12, 0.88):                     # chest pockets: a flap with a button, stitched round
        r.box(u - 0.06, 0.42, u + 0.06, 0.64, shade(jk, 0.9))
        r.box(u - 0.06, 0.6, u + 0.06, 0.66, shade(jk, 0.72))
        gear.stitches(r, u - 0.06, 0.42, u + 0.06, 0.42, shade(jk, 1.4), 2)
        r.dot(u, 0.6, C["brass"])
    for u, v, w in ((0.42, 0.30, 0.05), (0.58, 0.52, 0.04), (0.30, 0.66, 0.035), (0.68, 0.24, 0.05)):
        r.box(u, v, u + w, v + 0.02, C["scuff"])   # scuffs: short pale scrapes
    for u, v in ((0.36, 0.20), (0.62, 0.40), (0.22, 0.48)):
        r.box(u, v, u + 0.03, v + 0.05, shade(jk, 0.78))   # grime
    ap.weather(r, 0.2, C["dust"], seed=8, strength=0.4)
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
    sleeve.box(0.2, 0.3, 0.28, 0.33, C["scuff"])
    sleeve.box(0.6, 0.62, 0.66, 0.65, C["scuff"])
    ap.weather(sleeve, 0.14, C["dust"], seed=9, strength=0.35, flip=True)   # dust at the cuffs


def _paint_trousers(r):
    """Olive cargo trousers: seams front and back, a cargo pocket on each outer thigh (u 0.75 is
    the outside of the leg; v runs hip 0 to ankle 1), dust at the ankles."""
    tz = C["trousers"]
    r.fill(tz)
    r.seam(0.0, shade(tz, 0.75), shade(tz, 1.25))
    r.seam(0.5, shade(tz, 0.75), shade(tz, 1.25))
    r.box(0.64, 0.22, 0.86, 0.40, shade(tz, 1.08))                # the pocket
    r.box(0.64, 0.36, 0.86, 0.41, shade(tz, 0.78))                # its flap
    gear.stitches(r, 0.64, 0.22, 0.64, 0.40, shade(tz, 1.5), 2)
    gear.stitches(r, 0.86, 0.22, 0.86, 0.40, shade(tz, 1.5), 2)
    gear.stitches(r, 0.64, 0.22, 0.86, 0.22, shade(tz, 1.5), 2)
    r.dot(0.75, 0.37, C["brass"])
    ap.weather(r, 0.12, C["dust"], seed=10, strength=0.4, flip=True)


def _epaulettes(P, J, r):
    """Shoulder straps on the jacket, collar to shoulder point, a button at the collar end."""
    for th in (0.0, 180.0):
        pts = [body.trunk_point(J, JACKET, th, z, 0.010) for z in (1.428, 1.418, 1.405, 1.392, 1.378)]
        w = {"Chest": 0.45, "Shoulder" + ("_R" if th == 0.0 else "_L"): 0.55}
        body.strand(P, pts, [0.016, 0.017, 0.017, 0.016, 0.013], 0.3, r.uv, w, up=Vector((0, 0, 1)), sides=4)
    r.fill(C["jacket"])
    r.box(0.3, 0.0, 0.7, 0.2, C["brass"])


def _pocket_flaps(P, J, r):
    """The chest pockets' flaps, standing a little off the jacket's front."""
    s = J["height"] / 1.72
    for th in (50.0, 130.0):
        c = body.trunk_point(J, JACKET, th, 1.225, 0.012)
        out = Vector((math.cos(math.radians(th)), math.sin(math.radians(th)), 0.0))
        up = Vector((0, 0, 1))
        ap.box(P, c, (0.034 * s, 0.006 * s, 0.014 * s), r, body.spine_w(J, 1.225 * s), axes=(out.cross(up), out, up))
    r.fill(shade(C["jacket"], 0.85))
    gear.stitches(r, 0.0, 0.3, 1.0, 0.3, shade(C["jacket"], 1.5), 2)


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
