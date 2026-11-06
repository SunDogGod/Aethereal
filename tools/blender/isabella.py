"""Isabella, Aeneas's mother: calm, dignified, deliberate, dressed for a long road. The Vermeer
trio on near-black: an ULTRAMARINE headwrap (its two tails, one blue and one ochre, hang at her
nape), an OCHRE sash (obi) with a dark cord, and everything else dark: a deep red wrapped robe
(kimono-like, her left panel over her right, canon), a dark wool shawl with one ochre stripe, a
leather strap across her chest to a satchel on her right hip, dark buckled boots. Worn: faded,
frayed hems, patches stitched in ochre thread. One long braid down her back is her silhouette.
Her ink brush is in her right hand (prop "Brush") and her bell hangs at her left hip ("Bell").

Rebuild:  .\\tools\\blender\\rebuild.ps1 isabella    (from the project folder, Godot closed)
Colours and shape tables are here; the shapes (skirt, shawl, collar bands, hair shell, headwrap,
strap, satchel) are in isabella_parts.py, the paint in isabella_paint.py, her face is FACE (face.py).
"""
import math
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Matrix, Vector  # noqa: E402
import character_base as cb   # noqa: E402
import base_body as bb        # noqa: E402
import body                   # noqa: E402
import mesh                   # noqa: E402
import props                  # noqa: E402
import isabella_parts as ip   # noqa: E402
import isabella_paint as pt   # noqa: E402
import face                   # noqa: E402
import face_paint             # noqa: E402
import isabella_anims         # noqa: E402
from paint import rgb, shade  # noqa: E402

# Her colours: change a hex code and rebuild.
C = {k: rgb(v) for k, v in {
    "skin": "#d9a785", "hair": "#2e211d", "hair_hi": "#4d3832", "eye": "#24170f", "iris": "#55372a",
    "lip": "#a8474c", "brow": "#2a1b16",
    "robe": "#8a1f27", "robe_dk": "#5c1319", "robe_fade": "#9e3a38", "worn": "#b0665a", "collar": "#4a0f15",
    "lining": "#3a0d15", "inner": "#e6dcc4",
    "shawl": "#2a2220", "shawl_dk": "#17120f",
    "blue": "#2a3f9e", "blue_dk": "#1b2a6c", "blue_hi": "#4a62c0", "blue_fade": "#4d5ea6",
    "ochre": "#c8912e", "ochre_dk": "#8a6120",
    "leather": "#3a2a1e", "leather_dk": "#231810", "leather_hi": "#5c4330", "brass": "#b08a3e",
    "boot": "#2c1f1b", "sole": "#15100e",
    "bamboo": "#c9ab66", "bamboo_dk": "#8f763e", "bristle": "#e6dcc4", "ink": "#121216",
    "bronze": "#c69c48", "bronze_dk": "#7c5d25", "cord": "#a82d31"}.items()}

# A softer, narrower face than the default head, tapering to a small chin (rows as body.HEAD_ROWS).
HEAD_F = [(0.000, 0.044, 0.022, 0.025, 0.024, 2.1), (0.016, 0.029, 0.045, 0.058, 0.046, 2.2),
          (0.044, 0.015, 0.058, 0.077, 0.070, 2.3), (0.074, 0.007, 0.067, 0.086, 0.088, 2.4),
          (0.103, 0.004, 0.075, 0.088, 0.097, 2.4), (0.135, 0.0, 0.076, 0.089, 0.101, 2.4),
          (0.170, -0.005, 0.073, 0.083, 0.100, 2.3), (0.203, -0.010, 0.062, 0.066, 0.084, 2.2),
          (0.229, -0.015, 0.038, 0.040, 0.050, 2.0)]
# Her face (face.py): calm and dignified; almond eyes under slightly lowered lids, a winged lash line,
# fine high-arched brows, a straight nose, full lips, the faint lines of her years.
FACE = face.look(face.WOMAN, rows=HEAD_F, eye_h=0.0068, eye_tilt=0.0015, iris_r=0.0062, nose=0.0145, nose_w=4.3,
                 brow_z0=0.1215, brow_z1=0.1205, brow_arch=0.0040, cheek=0.0042, cheek_z=0.088, blush=0.15,
                 age=0.12, lip_sat=0.7, skin=C["skin"], hair=C["hair"], brow=C["brow"],
                 lash_col=shade(C["eye"], 0.45), iris=C["iris"], lip=C["lip"])
# Rings, low to high: (height, half width, front, back, squareness), for a 1.72 m body.
BODICE = [(1.06, 0.136, 0.088, 0.092, 2.4), (1.15, 0.138, 0.098, 0.090, 2.5), (1.24, 0.146, 0.110, 0.093, 2.5),
          (1.31, 0.156, 0.102, 0.093, 2.6), (1.36, 0.164, 0.086, 0.088, 2.7), (1.395, 0.138, 0.070, 0.075, 2.5),
          (1.425, 0.088, 0.058, 0.060, 2.2), (1.445, 0.058, 0.050, 0.052, 2.0)]
# The robe below the obi, hem first: a little wider toward the hem so her legs have room.
SKIRT = [(0.26, 0.205, 0.152, 0.150, 2.3), (0.30, 0.203, 0.150, 0.148, 2.3), (0.38, 0.196, 0.143, 0.142, 2.3),
         (0.48, 0.188, 0.134, 0.136, 2.3), (0.58, 0.184, 0.128, 0.132, 2.3), (0.69, 0.180, 0.122, 0.128, 2.3),
         (0.80, 0.175, 0.114, 0.124, 2.4), (0.90, 0.168, 0.106, 0.118, 2.5), (0.98, 0.152, 0.097, 0.106, 2.5),
         (1.06, 0.136, 0.088, 0.092, 2.4)]
OBI = [(1.00, 0.160, 0.106, 0.112, 2.7), (1.012, 0.162, 0.108, 0.114, 2.7), (1.128, 0.151, 0.112, 0.104, 2.7),
       (1.14, 0.147, 0.108, 0.101, 2.7)]
# The shawl hugs this shape (the shoulders), then leans out over the upper arms.
CAPE = [(1.08, 0.150, 0.112, 0.112, 2.5), (1.18, 0.150, 0.122, 0.104, 2.4), (1.26, 0.160, 0.128, 0.104, 2.3),
        (1.32, 0.176, 0.118, 0.106, 2.3), (1.37, 0.174, 0.100, 0.100, 2.3), (1.41, 0.126, 0.080, 0.086, 2.2),
        (1.445, 0.072, 0.064, 0.068, 2.0)]
# Arm rows: (t: 0..1 upper arm, 1..2 forearm, radius across, front[, back]).
SLEEVE = [(-0.05, 0.060, 0.062), (0.3, 0.064, 0.066), (0.8, 0.070, 0.072), (1.2, 0.076, 0.079),
          (1.6, 0.082, 0.085), (1.86, 0.085, 0.088), (1.92, 0.082, 0.085)]
BOOT = [(1.12, 0.046, 0.049), (1.3, 0.048, 0.052, 0.056), (1.6, 0.044, 0.047), (1.85, 0.041, 0.043),
        (2.02, 0.043, 0.047, 0.044)]
# Hair locks over the ears (kept for Valentina, who borrows them; Isabella's wrap covers hers) and
# the loose strand by each side of her face: (angle from the face, height, lift) points and a width.
LOCKS = [(((40, 0.168, 0.006), (70, 0.150, 0.011), (100, 0.126, 0.012), (130, 0.102, 0.011),
           (155, 0.086, 0.009), (175, 0.078, 0.004)), 0.042),
         (((62, 0.122, 0.004), (85, 0.104, 0.008), (110, 0.088, 0.009), (140, 0.076, 0.008),
           (162, 0.070, 0.006), (178, 0.070, 0.003)), 0.036)]
FACE_STRAND = ((25, 0.160, 0.006), (34, 0.13, 0.010), (45, 0.092, 0.010), (54, 0.058, 0.008), (59, 0.028, 0.004))
# The headwrap: rows (fraction from its edge to the crown, how far it stands off the head); its
# edge sits high on her forehead (parted hair shows under it) and comes down low at the nape.
WRAP = [(0.0, 0.015), (0.0, 0.026), (0.25, 0.029), (0.5, 0.030), (0.75, 0.028), (0.95, 0.025)]
WRAP_TOP = 0.238
# The braid: (back, height) points down her back for a 1.72 m body, from the nape to above the
# obi's knot; it lies over the shawl.
BRAID = ((-0.098, 1.47), (-0.126, 1.41), (-0.148, 1.34), (-0.155, 1.27), (-0.152, 1.21), (-0.147, 1.16),
         (-0.144, 1.135))
# The satchel strap: (angle round her: 0 = her right, 90 = front; height; the shape it lies on;
# how far off it) from the bag on her right hip, across her chest, over her left shoulder and
# down her back to the bag again. Over the shawl it rides on CAPE, elsewhere on the robe.
STRAP = [(326, 1.085, "OBI", 0.028), (5, 1.12, "OBI", 0.030), (35, 1.165, "BODICE", 0.020),
         (65, 1.20, "BODICE", 0.018), (90, 1.225, "BODICE", 0.018), (113, 1.265, "BODICE", 0.022),
         (130, 1.33, "CAPE", 0.030), (150, 1.40, "CAPE", 0.026), (175, 1.445, "CAPE", 0.020),
         (205, 1.43, "CAPE", 0.024), (235, 1.36, "CAPE", 0.028), (262, 1.27, "CAPE", 0.030),
         (285, 1.18, "CAPE", 0.032), (300, 1.125, "OBI", 0.028), (312, 1.085, "OBI", 0.028)]
SATCHEL_AT, SATCHEL_Z = 318.0, 1.005    # behind her right hip, out of the sleeve's swing


def hair_line(theta):
    """Where her hair starts (above the head joint): a high forehead, swept back from the temples
    over the tops of her ears, down to the nape."""
    a = abs(((theta - 90) + 180) % 360 - 180)   # 0 = the face, 180 = the back
    if a <= 28:
        return 0.172 - 0.0006 * a
    if a <= 62:
        return 0.155 - 0.045 * (a - 28) / 34
    if a <= 96:
        return 0.110 - 0.05 * (a - 62) / 34
    return 0.060 - 0.035 * (a - 96) / 84


def wrap_line(theta):
    """The headwrap's lower edge: high across the forehead, down past the temples to just above
    the ears, lowest at the nape where it is knotted."""
    a = abs(((theta - 90) + 180) % 360 - 180)
    if a <= 30:
        return 0.196 - 0.0002 * a
    if a <= 90:
        return 0.190 - 0.065 * (a - 30) / 60
    return 0.125 - 0.040 * (a - 90) / 90


def t_top(z):
    """Angle of the top panel's collar edge at height z: from the left of her neck to her right hip."""
    return 62 + (z - 1.06) * 135.0


def t_under(z):
    """The under panel's edge, its mirror; the two cross at the front at Z_CROSS."""
    return 118 - (z - 1.06) * 135.0


Z_CROSS = 1.06 + 28 / 135.0
PROFILES = {"OBI": OBI, "BODICE": BODICE, "CAPE": CAPE}


def build():
    ch = cb.Character("isabella", height=1.66, shoulders=0.9, hips=1.06, atlas_size=512)
    J, A, P = ch.J, ch.atlas, ch.part("Body")
    s = J["height"] / 1.72
    # Blocks of the 512 px texture, in packing order (rows of the atlas fill left to right).
    R = {n: A.rect(n, w, h) for n, w, h in (
        ("head", face.HEAD_RECT[0], face.HEAD_RECT[1]), ("shawl", 96, 40), ("skin", 16, 16), ("lining", 8, 8),
        ("bodice", 128, 64), ("skirt", 120, 56),
        ("sleeve", 64, 40), ("hair", 32, 32), ("boot", 40, 32), ("wrap", 64, 32), ("knot", 24, 16),
        ("hand", 24, 16), ("cuff", 16, 8), ("tail_b", 16, 16), ("tail_o", 16, 16),
        ("obi", 64, 16), ("foot", 32, 16), ("braid", 16, 32), ("tie", 8, 8), ("shawl_in", 8, 8), ("hair_cap", 64, 32),
        ("collar_band", 16, 8), ("inner_band", 8, 8), ("strap", 16, 48), ("bag", 48, 32), ("flap", 16, 24))}
    R["skin"].fill(C["skin"])
    R["lining"].fill(C["lining"])
    R["shawl_in"].fill(shade(C["shawl"], 0.8))
    # Head and face (face.py, face_paint.py), hair, the wrap and the braid.
    head = face.Head(J, FACE)
    head.build(P, R["head"])
    face_paint.paint(head, FACE, hair_line)
    body.neck(P, J, R["skin"], r=0.043)
    _hair(P, J, head, R, s)
    # Robe: bodice and its crossed collar, skirt, sleeves; the obi and its knot; the shawl.
    body.trunk(P, J, R["bodice"], BODICE, segs=18)
    pt.bodice(R["bodice"], C, sys.modules[__name__])
    _collar(P, J, R)
    ip.skirt(P, J, SKIRT, R["skirt"], R["lining"])
    pt.skirt(R["skirt"], C, sys.modules[__name__])
    arm = body.arm_joints(J)
    bb.mirrored(P, lambda: body.limb(P, J, arm, ("UpperArm_R", "LowerArm_R"), R["sleeve"], SLEEVE, segs=12,
                                     hand_bone="Hand_R"))
    # The sleeve opening turns inward to the wrist (the cream under-sleeve), then wrist and hand.
    bb.mirrored(P, lambda: body.limb(P, J, arm, ("UpperArm_R", "LowerArm_R"), R["cuff"],
                                     [(1.92, 0.082, 0.085), (1.895, 0.030, 0.031)], segs=12, hand_bone="Hand_R"))
    bb.mirrored(P, lambda: body.limb(P, J, arm, ("UpperArm_R", "LowerArm_R"), R["skin"],
                                     [(1.78, 0.029, 0.031), (2.0, 0.026, 0.027)], segs=8, hand_bone="Hand_R"))
    bb.mirrored(P, lambda: body.fist(P, J, R["hand"], size=0.93))
    pt.sleeves(R["sleeve"], R["cuff"], R["hand"], C)
    body.trunk(P, J, R["obi"], OBI, segs=18)
    ip.knot(P, J, R["knot"])
    pt.obi(R["obi"], R["knot"], C)
    ip.shawl(P, J, CAPE, R["shawl"], R["shawl_in"])
    pt.shawl(R["shawl"], C)
    # The strap over everything, and the satchel on her right hip.
    pts = [body.trunk_point(J, PROFILES[prof], th, z, lift) for th, z, prof, lift in STRAP]
    wts = [body.spine_w(J, z * s) for th, z, prof, lift in STRAP]
    ip.strip(P, pts, wts, 0.03, 0.006, R["strap"].uv, s)
    base = body.trunk_point(J, OBI, SATCHEL_AT, SATCHEL_Z, 0.004)
    ip.satchel(P, base, SATCHEL_AT, (0.075, 0.065, 0.055), R["bag"].uv, R["flap"].uv, s)
    pt.leather(R["strap"], R["bag"], R["flap"], C)
    # Boots (the thighs stay hidden under the skirt, so only the shins are built).
    legs = body.leg_joints(J)
    bb.mirrored(P, lambda: body.limb(P, J, legs, ("UpperLeg_R", "LowerLeg_R"), R["boot"], BOOT))
    bb.mirrored(P, lambda: body.foot(P, J, R["foot"], rows=[
        (-0.085, 0.031, 0.034, -0.034), (-0.06, 0.039, 0.05, -0.026), (0.0, 0.042, 0.054, -0.02),
        (0.065, 0.045, 0.037, -0.041), (0.12, 0.044, 0.028, -0.052), (0.17, 0.036, 0.021, -0.06)]))
    pt.boots(R["boot"], R["foot"], C)
    # Props.
    _brush(ch.prop("BrushMesh", "Weapon_R", "Brush"), A)
    _bell(ch.prop("BellMesh", "Sheath", "Bell"), A)
    return ch


def _hair(P, J, head, R, s):
    """Sleek parted hair under the wrap (the shell shows at the forehead, over the ears and at the
    nape), a loose strand by each side of her face, the wrap with its knot and two tails at the
    nape, and the braid from under the knot down her back, tied with ochre thread."""
    ip.hair_shell(P, head, R["hair_cap"], hair_line, C["hair"], C["hair_hi"])
    pt.hair(R["hair"], C)
    for side in (1, -1):
        pts = [(90 - side * a, z, l) for a, z, l in FACE_STRAND]
        body.lock(P, head, R["hair"], pts, [0.010, 0.012, 0.011, 0.008, 0.0], depth=0.5, sides=4)
    ip.cap(P, head, R["wrap"], wrap_line, WRAP, WRAP_TOP)
    pt.wrap(R["wrap"], R["tail_b"], R["tail_o"], C)
    hs = head.s
    knot = [head.surface(th, 0.088, lift) for th, lift in ((252, 0.022), (270, 0.034), (288, 0.022))]
    mesh.strand(P, knot, [0.012 * hs, 0.017 * hs, 0.012 * hs], 0.8, R["wrap"].uv, {"Head": 1.0}, sides=5)
    for side, uv in ((1, R["tail_b"].uv), (-1, R["tail_o"].uv)):
        p0 = head.surface(270 + side * 9, 0.078, 0.026)
        pts = [p0, p0 + Vector((side * 0.018, -0.022, -0.05)) * hs, p0 + Vector((side * 0.034, -0.030, -0.105)) * hs]
        mesh.strand(P, pts, [0.013 * hs, 0.016 * hs, 0.012 * hs], 0.25, uv, {"Head": 1.0},
                    up=(side * 0.5, -1, 0), sides=4)
    pts = [head.surface(270, 0.05, 0.012)] + [Vector((0.0, y * s, z * s)) for y, z in BRAID]
    widths = [0.019 * s, 0.021 * s, 0.020 * s, 0.019 * s, 0.018 * s, 0.016 * s, 0.014 * s, 0.0]

    def w(k):
        if k < 0.12:
            return {"Head": 1.0}
        if k < 0.3:
            t = (k - 0.12) / 0.18
            return {"Head": 1 - t, "Neck": t}
        if k < 0.5:
            t = (k - 0.3) / 0.2
            return {"Neck": 1 - t, "Chest": t}
        return {"Chest": 1.0}
    mesh.strand(P, pts, widths, 0.75, R["braid"].uv, w, up=(0, -1, 0), sides=6)
    tie = pts[-2]
    mesh.strand(P, [tie + Vector((0, -0.002, 0.012 * s)), tie + Vector((0, -0.004, 0.0)),
                    tie + Vector((0, -0.006, -0.012 * s))], [0.016 * s, 0.017 * s, 0.014 * s], 0.75,
                R["tie"].uv, {"Chest": 1.0}, up=(0, -1, 0), sides=6)
    pt.braid(R["braid"], R["tie"], C)


def _collar(P, J, R):
    """The crossed collar as raised bands on the bodice: a dark red band along each panel's edge
    (the under one stops where it slides beneath the top one) and a cream under-collar inside."""
    R["collar_band"].fill(C["collar"])
    R["collar_band"].hline(0.5, shade(C["collar"], 1.4), 2)
    R["inner_band"].fill(C["inner"])
    top = [(t_top(z), z) for z in (1.448, 1.42, 1.38, 1.33, 1.28, 1.23, 1.18, 1.125)]
    under = [(t_under(z), z) for z in (1.448, 1.42, 1.38, 1.33, 1.29, Z_CROSS - 0.01)]
    ip.band(P, J, BODICE, top, 0.024, 0.006, R["collar_band"].uv, 0.004, inner=(-1, R["inner_band"].uv, Z_CROSS))
    ip.band(P, J, BODICE, under, 0.024, 0.005, R["collar_band"].uv, 0.002, inner=(1, R["inner_band"].uv, Z_CROSS))


# ---------------------------------------------------------------- props
def _brush(p, A):
    """The ink brush: a bamboo handle with node rings, a red lacquer collar, bristles dipped in ink."""
    rb, rf, rt = A.rect("brush", 32, 8), A.rect("ferrule", 8, 8), A.rect("bristle", 16, 12)
    props.rod(p, [(-0.105, 0.0, 0.0), (-0.10, 0.0085, 0.0085), (0.165, 0.0075, 0.0075)], rb.uv, sides=6)
    props.rod(p, [(0.16, 0.0095, 0.0095), (0.195, 0.0105, 0.0105)], rf.uv, sides=6)
    props.rod(p, [(0.192, 0.0098, 0.0098), (0.215, 0.0125, 0.0125), (0.245, 0.010, 0.010), (0.285, 0.0, 0.0)],
              rt.uv, sides=6)
    rb.fill(C["bamboo"])
    for v in (0.05, 0.36, 0.68):
        rb.box(0, v, 1, v + 0.04, C["bamboo_dk"])      # node rings (v runs along the rod)
    rb.box(0, 0.0, 1, 0.04, C["cord"])
    rf.fill(C["collar"])
    rf.hline(0.5, C["ochre"])
    rt.fill(C["bristle"])
    rt.box(0, 0.4, 1, 1.0, C["ink"])


def _bell(p, A):
    """Her bell on a short red cord, hanging straight down from the obi at her left hip."""
    rc, rb = A.rect("bell_cord", 8, 8), A.rect("bell", 24, 16)
    props.rod(p, [(0.0, 0.0045, 0.0045), (0.035, 0.0045, 0.0045)], rc.uv, sides=5)
    props.rod(p, [(0.032, 0.0, 0.0), (0.035, 0.008, 0.008), (0.046, 0.008, 0.008), (0.05, 0.0, 0.0)], rc.uv, sides=6)
    props.rod(p, [(0.048, 0.0, 0.0), (0.05, 0.007, 0.007), (0.058, 0.011, 0.011), (0.066, 0.022, 0.022),
                  (0.076, 0.027, 0.027), (0.098, 0.031, 0.031), (0.112, 0.037, 0.037), (0.117, 0.038, 0.038),
                  (0.114, 0.029, 0.029), (0.095, 0.0, 0.0)], rb.uv, sides=10)
    rc.fill(C["cord"])
    rb.fill(C["bronze"])
    rb.box(0, 0.70, 1, 0.80, C["bronze_dk"])
    rb.box(0, 0.40, 1, 0.45, C["bronze_dk"])
    rb.vline(0.25, shade(C["bronze"], 1.25), 1, 0.45, 0.7)
    rb.box(0, 0.0, 1, 0.12, C["bronze_dk"])
    # The Sheath bone leans down and back; turn the bell to hang plumb, lift it to the obi and
    # move it out to her side, clear of the skirt.
    lean = math.atan2(0.35, 1.0)
    up = Vector((0, -math.cos(lean), -math.sin(lean)))
    mesh.transform_part(p, Matrix.Translation(up * 0.085 + Vector((-0.03, 0, 0))) @ Matrix.Rotation(lean, 4, "X"))


if __name__ == "__main__":
    ch = build()
    ch.finish(animations=isabella_anims.animations, preview=None)   # the shared sets, then her story poses
