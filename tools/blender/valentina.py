"""Valentina, the village girl Aeneas means to marry: about his age, warm, quick, dressed for work.
Her village keeps the old estate's two heritages, Spanish and Japanese, so her clothes mix them:
a cream blouse with a high crossed, kimono-style collar trimmed in indigo and a standing band at
the neck, its sleeves rolled to the elbow; an indigo corselet laced up the front over it; a wide
marigold sash with a magenta stripe (her one bright accent), knotted at her left hip with two tails;
a full ochre skirt to mid-calf, patched, dusty at the hem, with an indigo hem band stitched in fat
white sashiko dashes; dark stockings and short brown boots; a marigold kerchief at her throat.
Long dark-brown hair: a blunt fringe cut straight above the brows, the sides swept back over her
ears into one thick plaited braid down her back, tied with a marigold ribbon.
(Proposed: the author has not described her yet. Colours are the C table; shapes the profiles.)

Rebuild:  .\\tools\\blender\\rebuild.ps1 valentina    (from the project folder, Godot closed)
"""
import math
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Vector  # noqa: E402
import character_base as cb   # noqa: E402
import base_body as bb        # noqa: E402
import body                   # noqa: E402
import mesh                   # noqa: E402
import isabella_parts as ip   # noqa: E402
import isabella as isa        # noqa: E402  (her head shape and hair locks)
import agency_parts as ap     # noqa: E402  (weather(): dust at a hem)
import face                   # noqa: E402
import face_paint             # noqa: E402
from paint import rgb, shade  # noqa: E402

C = {k: rgb(v) for k, v in {
    "skin": "#d6a27c", "hair": "#2a1a14", "hair_hi": "#4a3024", "eye": "#2a1a12", "iris": "#5c3a22",
    "lip": "#b55a55", "brow": "#24150f", "blouse": "#efe6d2", "blouse_dk": "#d3c5a6",
    "indigo": "#2f3f66", "indigo_dk": "#1f2a47", "indigo_hi": "#46587f", "stitch": "#e8e1cf",
    "skirt": "#b8772c", "skirt_dk": "#8c5720", "patch": "#a06a2a",
    "marigold": "#e3a032", "marigold_dk": "#b47a1e", "magenta": "#c0307a", "magenta_dk": "#8a1f58",
    "leather": "#5a3a22", "stocking": "#3b2b26", "boot": "#4a301f", "sole": "#1e140e"}.items()}

# Rings (height, half width, front, back, squareness) for a 1.72 m body (she is scaled to 1.62).
# Her face (face.py): open, bright eyes, a small nose, a ready smile; a slightly larger head reads younger.
FACE = face.look(face.WOMAN, rows=isa.HEAD_F, scale=1.1, eye_h=0.0082, eye_lo=0.0054, iris_r=0.0072, eye_tilt=0.0009,
                 wing=0.12, nose=0.0125, nose_w=4.1, nose_tip_z=0.072, brow_thick=0.0030, brow_arch=0.0030, smile=0.0010,
                 blush=0.4, lip_sat=0.6, skin=C["skin"], hair=C["hair"], brow=C["brow"], lash_col=shade(C["eye"], 0.5),
                 iris=C["iris"], lip=C["lip"])
BLOUSE = [(r[0], r[1] * 0.95, r[2] * 0.96, r[3] * 0.97, r[4]) for r in isa.BODICE]
# The standing collar round her neck, over the blouse's top ring (below the chin: it can't poke through).
COLLAR = [(1.432, 0.064, 0.057, 0.059, 2.0), (1.476, 0.058, 0.051, 0.054, 2.0)]
VEST = [(0.985, 0.146, 0.098, 0.101, 2.6), (1.06, 0.136, 0.092, 0.094, 2.6), (1.15, 0.140, 0.102, 0.093, 2.6),
        (1.235, 0.150, 0.112, 0.096, 2.6), (1.25, 0.146, 0.108, 0.094, 2.6)]
SASH = [(0.955, 0.150, 0.103, 0.106, 2.7), (0.965, 0.153, 0.106, 0.109, 2.7), (1.07, 0.146, 0.102, 0.102, 2.7),
        (1.08, 0.142, 0.098, 0.099, 2.7)]
KERCHIEF = [(1.395, 0.118, 0.078, 0.080, 2.3), (1.415, 0.092, 0.070, 0.072, 2.1), (1.436, 0.072, 0.062, 0.064, 2.0)]
# A full skirt, hem first (mid-calf), flaring from the hips; the legs carry it (isabella_parts.skirt).
SKIRT = [(0.40, 0.246, 0.188, 0.182, 2.2), (0.44, 0.240, 0.182, 0.176, 2.2), (0.55, 0.222, 0.166, 0.162, 2.25),
         (0.68, 0.202, 0.148, 0.150, 2.3), (0.80, 0.182, 0.128, 0.136, 2.4), (0.90, 0.166, 0.110, 0.120, 2.5),
         (0.98, 0.150, 0.100, 0.106, 2.5)]
# Arms (t 0..1 upper arm, 1..2 forearm): a slightly full blouse sleeve, rolled up just past the elbow.
SLEEVE = [(-0.05, 0.060, 0.062), (0.25, 0.066, 0.068), (0.6, 0.064, 0.066), (1.02, 0.060, 0.062)]
CUFF = [(0.98, 0.064, 0.066), (1.06, 0.070, 0.072), (1.16, 0.066, 0.068), (1.20, 0.044, 0.046)]
FOREARM = [(1.0, 0.044, 0.046), (1.5, 0.038, 0.040), (2.0, 0.026, 0.027)]
STOCKING = [(0.95, 0.050, 0.054), (1.2, 0.046, 0.052, 0.056), (1.6, 0.038, 0.040)]
BOOT = [(1.55, 0.044, 0.047), (1.6, 0.047, 0.050), (1.85, 0.042, 0.044), (2.02, 0.044, 0.048, 0.045)]
# The blunt fringe: flat locks side by side across the forehead, all cut off at the same height.
FRINGE_CUT, FRINGE_ANGLES = 0.129, (-30, -15, 0, 15, 30)
# The collar's crossing (her left panel over her right): higher than Isabella's, a closed neckline.
Z_CROSS, SLOPE = 1.355, 258.0


def t_top(z):
    return 90 + (z - Z_CROSS) * SLOPE


def t_under(z):
    return 90 - (z - Z_CROSS) * SLOPE


def dashes(r, v, color, on=2, off=2, px=1):
    """A fat dashed line across a block: stitching that still reads at 960x540."""
    _, row = r.px(0, v)
    for x in range(r.w):
        if x % (on + off) < on:
            r.atlas.img[row:row + px, r.x + x] = color


def build():
    ch = cb.Character("valentina", height=1.62, shoulders=0.88, hips=1.04, atlas_size=512)
    J, A, P = ch.J, ch.atlas, ch.part("Body")
    R = {n: A.rect(n, w, h) for n, w, h in (
        ("head", face.HEAD_RECT[0], face.HEAD_RECT[1]), ("skirt", 120, 48), ("blouse", 128, 56), ("sleeve", 64, 32),
        ("hair", 32, 32), ("fringe", 32, 16),
        ("skin", 16, 16), ("hair_cap", 64, 32), ("vest", 96, 24), ("boot", 40, 32), ("stocking", 32, 24),
        ("hand", 24, 16), ("foot", 32, 16), ("braid", 16, 48), ("sash", 64, 12), ("tail", 16, 32),
        ("kerchief", 32, 8), ("collar", 32, 8),
        ("band", 16, 8), ("inner_band", 8, 8), ("ribbon", 8, 8), ("cuff", 16, 8), ("lining", 8, 8))}
    R["skin"].fill(C["skin"]), R["lining"].fill(C["skirt_dk"]), R["hand"].fill(C["skin"])
    head = face.Head(J, FACE)
    head.build(P, R["head"])
    face_paint.paint(head, FACE, isa.hair_line)
    body.neck(P, J, R["skin"], r=0.041)
    _hair(P, J, head, R)
    # Blouse, its crossed collar bands, the standing collar, corselet, sash, kerchief.
    body.trunk(P, J, R["blouse"], BLOUSE, segs=18)
    _paint_blouse(R["blouse"])
    R["band"].fill(C["indigo"]), R["inner_band"].fill(C["blouse_dk"])
    dashes(R["band"], 0.5, C["stitch"], 2, 2)
    top = [(t_top(z), z) for z in (1.448, 1.42, 1.39, 1.36, 1.33, 1.30, 1.26)]
    under = [(t_under(z), z) for z in (1.448, 1.42, 1.39, Z_CROSS - 0.01)]
    ip.band(P, J, BLOUSE, top, 0.022, 0.006, R["band"].uv, 0.004, inner=(-1, R["inner_band"].uv, Z_CROSS))
    ip.band(P, J, BLOUSE, under, 0.022, 0.005, R["band"].uv, 0.002, inner=(1, R["inner_band"].uv, Z_CROSS))
    body.trunk(P, J, R["collar"], COLLAR, segs=14)
    R["collar"].fill(C["indigo"]), R["collar"].hline(0.95, C["indigo_hi"])
    dashes(R["collar"], 0.35, C["stitch"], 2, 2)
    body.trunk(P, J, R["vest"], VEST, segs=18)
    _paint_vest(R["vest"])
    body.trunk(P, J, R["sash"], SASH, segs=18)
    _sash_knot(P, J, R)
    body.trunk(P, J, R["kerchief"], KERCHIEF, segs=12)
    _kerchief_knot(P, J, R)
    R["kerchief"].fill(C["marigold"])
    R["kerchief"].box(0, 0.0, 1, 0.12, C["marigold_dk"])
    R["kerchief"].box(0, 0.88, 1, 1.0, C["marigold_dk"])
    # Skirt.
    ip.skirt(P, J, SKIRT, R["skirt"], R["lining"])
    _paint_skirt(R["skirt"])
    # Arms: sleeve, rolled cuff, bare forearm, hand.
    arm, bones = body.arm_joints(J), ("UpperArm_R", "LowerArm_R")
    bb.mirrored(P, lambda: body.limb(P, J, arm, bones, R["sleeve"], SLEEVE, segs=10, cap0="pole"))
    bb.mirrored(P, lambda: body.limb(P, J, arm, bones, R["cuff"], CUFF, segs=10))
    bb.mirrored(P, lambda: body.limb(P, J, arm, bones, R["skin"], FOREARM, segs=8, hand_bone="Hand_R"))
    bb.mirrored(P, lambda: body.fist(P, J, R["hand"], size=0.9))
    R["sleeve"].fill(C["blouse"])
    R["sleeve"].vline(0.0, C["blouse_dk"], 2)                   # the seam under the arm
    R["sleeve"].hline(0.45, C["blouse_dk"])                     # a fold at the elbow
    ap.weather(R["sleeve"], 0.22, C["blouse_dk"], shade(C["blouse_dk"], 0.9), seed=4, strength=0.5, flip=True)
    R["cuff"].fill(C["blouse"])
    R["cuff"].box(0, 0.25, 1, 0.75, shade(C["blouse"], 0.93))  # the roll's shadowed middle
    R["cuff"].hline(0.75, C["blouse_dk"], 2)
    R["hand"].hline(0.6, shade(C["skin"], 0.88))
    # Legs below the hem: stockings and short boots.
    legs = body.leg_joints(J)
    bb.mirrored(P, lambda: body.limb(P, J, legs, ("UpperLeg_R", "LowerLeg_R"), R["stocking"], STOCKING))
    bb.mirrored(P, lambda: body.limb(P, J, legs, ("UpperLeg_R", "LowerLeg_R"), R["boot"], BOOT))
    bb.mirrored(P, lambda: body.foot(P, J, R["foot"], rows=[
        (-0.085, 0.030, 0.033, -0.034), (-0.06, 0.038, 0.048, -0.026), (0.0, 0.041, 0.052, -0.02),
        (0.065, 0.043, 0.036, -0.041), (0.12, 0.042, 0.027, -0.052), (0.165, 0.035, 0.020, -0.06)]))
    R["stocking"].fill(C["stocking"]), R["stocking"].vline(0.5, shade(C["stocking"], 0.8))
    _paint_boots(R["boot"], R["foot"])
    return ch


def _hair(P, J, head, R):
    """The shell, the blunt fringe, locks over her ears sweeping back, and the plaited braid."""
    ip.hair_shell(P, head, R["hair_cap"], isa.hair_line, C["hair"], C["hair_hi"])
    r = R["hair"]
    r.fill(C["hair"])
    r.vline(0.5, C["hair_hi"], 1, 0.15, 0.85)
    r.vline(0.2, shade(C["hair"], 0.7))
    r.vline(0.8, shade(C["hair"], 0.7))
    for side in (1, -1):
        for path, w in isa.LOCKS:
            pts = [(90 - side * a, z, l) for a, z, l in path]
            body.lock(P, head, r, pts, [w * 0.6, w, w, w * 0.9, w * 0.7, 0.0], depth=0.34, sides=5)
        pts = [(90 - side * a, z, l) for a, z, l in isa.FACE_STRAND]
        body.lock(P, head, r, pts, [0.010, 0.012, 0.011, 0.008, 0.0], depth=0.5, sides=4)
    # The fringe: five flat locks from under the shell down to one straight cut above the brows
    # (a last width that isn't zero ends a lock square instead of in a point).
    f = R["fringe"]
    f.fill(C["hair"])
    f.box(0, 0.58, 1, 0.70, shade(C["hair"], 1.3))             # one soft sheen band across the locks
    for a in FRINGE_ANGLES:
        th = 90 + a
        path = [(th, 0.186, 0.008), (th, 0.164, 0.013), (th, 0.146, 0.013), (th, FRINGE_CUT, 0.010)]
        body.lock(P, head, f, path, [0.020, 0.027, 0.027, 0.025], depth=0.22, sides=4)
    # The braid: from the back of her head down to the small of her back, plaited (the width
    # swells and narrows every link), following her neck then her chest as she bends.
    s = J["height"] / 1.72
    zs = (1.55, 1.49, 1.43, 1.37, 1.31, 1.25, 1.19, 1.13, 1.07, 1.02)
    ys = (-0.086, -0.096, -0.106, -0.118, -0.128, -0.132, -0.130, -0.126, -0.122, -0.118)
    pts = [Vector((0.0, y * s, z * s)) for y, z in zip(ys, zs)]
    widths = [(0.040 if k % 2 else 0.032) * s * (1.0 - 0.3 * k / 9) for k in range(9)] + [0.0]

    def w(k):
        if k < 0.15:
            return {"Head": 1.0}
        if k < 0.35:
            t = (k - 0.15) / 0.2
            return {"Head": 1 - t, "Neck": t}
        t = min(1.0, (k - 0.35) / 0.2)
        return {"Neck": 1 - t, "Chest": t}
    mesh.strand(P, pts, widths, 0.75, R["braid"].uv, w, up=(0, -1, 0), sides=6)
    tie = pts[-3]
    mesh.strand(P, [tie + Vector((0, -0.004, 0.012 * s)), tie + Vector((0, -0.010, -0.004 * s)),
                    tie + Vector((0, -0.012, -0.014 * s))], [0.030 * s, 0.031 * s, 0.0], 1.0,
                R["ribbon"].uv, {"Chest": 1.0}, up=(0, -1, 0), sides=6)
    b = R["braid"]
    b.fill(C["hair"])
    img = b.atlas.img
    for y in range(b.h):                                        # plaits: fat alternating chevrons
        for x in range(b.w):
            if ((x + (y if (y // 5) % 2 else -y)) % 8) < 2:
                img[b.y + y, b.x + x] = shade(C["hair"], 0.6)
            elif ((x + (y if (y // 5) % 2 else -y)) % 8) == 4:
                img[b.y + y, b.x + x] = C["hair_hi"]
    R["ribbon"].fill(C["marigold"])
    R["ribbon"].hline(0.5, C["magenta"], 2)


def _sash_knot(P, J, R):
    """The sash is knotted at her left hip: a padded knot and two tails hanging over the skirt."""
    s = J["height"] / 1.72
    r = R["sash"]
    r.fill(C["marigold"])
    r.box(0, 0.36, 1, 0.64, C["magenta"])                       # the stripe: her accent
    r.hline(0.08, C["marigold_dk"]), r.hline(0.92, C["marigold_dk"])
    th0 = 158.0
    out = Vector((math.cos(math.radians(th0)), math.sin(math.radians(th0)), 0))
    knot = body.trunk_point(J, SASH, th0, 1.01, 0.012)
    side = Vector((-out.y, out.x, 0))
    mesh.strand(P, [knot - side * 0.03 * s, knot, knot + side * 0.03 * s], [0.026 * s, 0.034 * s, 0.026 * s],
                0.7, r.uv, body.spine_w(J, 1.01 * s), up=out, sides=6)
    z_hem = SKIRT[0][0] * s
    for th, dz in ((164.0, 0.0), (150.0, 0.05)):
        zz = [0.985, 0.90, 0.82, 0.74 + dz]
        pts = [body.trunk_point(J, SKIRT, th - 3 * k, z, 0.012 + 0.004 * k) for k, z in enumerate(zz)]

        def w(k, th=th, zz=zz):
            z = (zz[0] + (zz[-1] - zz[0]) * k) * s
            return ip.skirt_w(J, th, z, z_hem)
        mesh.strand(P, pts, [0.042 * s, 0.040 * s, 0.036 * s, 0.0], 0.12, R["tail"].uv, w,
                    up=Vector((math.cos(math.radians(th)), math.sin(math.radians(th)), 0)), sides=4)
    t = R["tail"]
    t.fill(C["marigold"])
    t.box(0.36, 0, 0.64, 1, C["magenta"])                       # the stripe runs down the tail
    t.box(0, 0.0, 1, 0.08, C["marigold_dk"])                     # the frayed end
    dashes(t, 0.04, C["magenta_dk"], 2, 2)


def _kerchief_knot(P, J, R):
    """A small knot and one tail at the front left of the kerchief."""
    s = J["height"] / 1.72
    p0 = body.trunk_point(J, KERCHIEF, 112.0, 1.408, 0.006)
    w = body.spine_w(J, 1.40 * s)
    mesh.strand(P, [p0 + Vector((0.012, 0.0, 0.006)) * s, p0, p0 + Vector((-0.012, 0.0, -0.006)) * s],
                [0.014 * s, 0.018 * s, 0.014 * s], 0.8, R["kerchief"].uv, w, up=(0, 1, 0), sides=5)
    mesh.strand(P, [p0 + Vector((0, 0.004, -0.008)) * s, p0 + Vector((-0.010, 0.010, -0.030)) * s,
                    p0 + Vector((-0.018, 0.012, -0.050)) * s], [0.016 * s, 0.018 * s, 0.0], 0.25,
                R["kerchief"].uv, w, up=(0, 1, 0), sides=4)


def _paint_blouse(r):
    def px(th, z):
        if z > Z_CROSS and t_under(z) - 3 < th < t_top(z) + 3:
            return C["skin"]
        if abs(((th + 90) % 180) - 90) < 2.0 and abs(th - 90) > 30:
            return C["blouse_dk"]                               # side seams, fat
        return C["blouse"]
    ip.paint_tz(r, BLOUSE[0][0], BLOUSE[-1][0], px)


def _paint_vest(r):
    """Indigo, laced up the front in magenta (blouse showing in the gap), eyelet strips either side,
    faint boning, pale piping with white stitching inside it at the edges, the hem worn pale."""
    def px(th, z):
        f = abs(th - 90)
        if f < 5:
            return C["magenta_dk"] if int((z - 0.985) / 0.022) % 2 else C["blouse"]   # the gap, laces across
        if f < 9:
            return C["indigo_dk"]                               # eyelet strips
        if z > 1.239 or z < 0.996:
            return C["indigo_hi"]                               # piping
        if z > 1.228 or z < 1.007:
            return C["stitch"] if (th % 24) < 15 else C["indigo"]   # stitching inside it
        if abs(((th + 60) % 36) - 18) < 2:
            return shade(C["indigo"], 0.9)                      # boning seams
        return C["indigo"]
    ip.paint_tz(r, VEST[0][0], VEST[-1][0], px)
    ap.weather(r, 0.10, C["indigo_hi"], shade(C["indigo_hi"], 0.9), seed=6, waves=4, strength=0.45)


def _paint_skirt(r):
    """Ochre, softly folded, a patch on her left thigh, an indigo band at the hem stitched in fat white
    dashes (sashiko), dust climbing from the hem."""
    def px(th, z):
        if z < 0.50:
            row = int((z - 0.40) / 0.0125)
            if row in (2, 3) and (th % 24) < 15 or row in (5, 6) and ((th + 12) % 24) < 15:
                return C["stitch"]
            return C["indigo"] if row > 0 else C["indigo_dk"]
        if 126 < th < 156 and 0.60 < z < 0.72:
            edge = th < 130 or th > 152 or z < 0.615 or z > 0.705
            return C["stitch"] if edge and int((th + z * 300) // 4) % 2 else C["patch"]
        if int(th // 22) % 2 == 0 and z < 0.92:
            return shade(C["skirt"], 0.92)                      # broad folds
        return C["skirt"]
    ip.paint_tz(r, SKIRT[0][0], SKIRT[-1][0], px)
    ap.weather(r, 0.30, shade(C["skirt"], 0.84), shade(C["skirt_dk"], 0.85), seed=3, strength=0.45)


def _paint_boots(r, foot):
    r.fill(C["boot"])
    r.box(0, 0.82, 1, 1.0, shade(C["boot"], 1.2))               # the turned-down top
    r.vline(0.5, C["leather"], 2, 0.1, 0.8)                     # front lacing
    r.hline(0.45, C["sole"], 2)                                 # an ankle strap
    r.dot(0.5, 0.45, C["marigold_dk"], 2)                       # its buckle
    ap.weather(r, 0.2, shade(C["boot"], 1.25), seed=5, strength=0.4, flip=True)
    foot.fill(C["boot"])
    foot.box(0.0, 0.0, 0.18, 1.0, C["sole"]), foot.box(0.82, 0.0, 1.0, 1.0, C["sole"])
    foot.box(0.18, 0.0, 0.82, 0.3, shade(C["boot"], 1.2))       # scuffed toes


if __name__ == "__main__":
    ch = build()
    ch.finish()
