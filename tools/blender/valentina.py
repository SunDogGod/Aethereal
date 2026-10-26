"""Valentina, the village girl Aeneas means to marry: about his age, warm, quick, dressed for work.
Her village keeps the old estate's two heritages, Spanish and Japanese, so her clothes mix them:
a cream blouse with a crossed, kimono-style collar trimmed in indigo and its sleeves rolled to the
elbow; an indigo corselet laced up the front over it; a marigold sash; a full ochre skirt to
mid-calf with an indigo hem band stitched in white sashiko crosses; dark stockings and short brown
boots; a marigold kerchief at her throat. Long dark-brown hair parted in the middle, a short
fringe, swept back into one thick braid down her back tied with a marigold ribbon.
(Proposed: the author has not described her yet. Colours are the C table; shapes the profiles.)

Rebuild:  .\\tools\\blender\\rebuild.ps1 valentina    (from the project folder, Godot closed)
"""
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
import isabella as isa        # noqa: E402  (her head shape, hair locks and collar lines)
from paint import rgb, shade  # noqa: E402

C = {k: rgb(v) for k, v in {
    "skin": "#d6a27c", "hair": "#2a1a14", "hair_hi": "#4a3024", "eye": "#2a1a12", "iris": "#5c3a22",
    "lip": "#b55a55", "brow": "#24150f", "blouse": "#efe6d2", "blouse_dk": "#d3c5a6",
    "indigo": "#2f3f66", "indigo_dk": "#1f2a47", "stitch": "#e8e1cf", "skirt": "#b8772c", "skirt_dk": "#8c5720",
    "marigold": "#e3a032", "marigold_dk": "#b47a1e", "leather": "#5a3a22", "stocking": "#3b2b26",
    "boot": "#4a301f", "sole": "#1e140e"}.items()}

# Rings (height, half width, front, back, squareness) for a 1.72 m body (she is scaled to 1.62).
BLOUSE = [(r[0], r[1] * 0.95, r[2] * 0.96, r[3] * 0.97, r[4]) for r in isa.BODICE]
VEST = [(0.985, 0.146, 0.098, 0.101, 2.6), (1.06, 0.140, 0.094, 0.096, 2.6), (1.15, 0.142, 0.103, 0.093, 2.6),
        (1.235, 0.150, 0.112, 0.096, 2.6), (1.25, 0.146, 0.108, 0.094, 2.6)]
SASH = [(0.965, 0.150, 0.103, 0.106, 2.7), (0.975, 0.152, 0.105, 0.108, 2.7), (1.035, 0.148, 0.103, 0.103, 2.7),
        (1.045, 0.144, 0.099, 0.100, 2.7)]
KERCHIEF = [(1.395, 0.128, 0.076, 0.078, 2.3), (1.425, 0.094, 0.066, 0.068, 2.1), (1.452, 0.066, 0.058, 0.060, 2.0)]
# A full skirt, hem first (mid-calf), the legs carry it (isabella_parts.skirt).
SKIRT = [(0.40, 0.232, 0.176, 0.170, 2.2), (0.44, 0.228, 0.172, 0.166, 2.2), (0.55, 0.214, 0.160, 0.156, 2.25),
         (0.68, 0.198, 0.144, 0.146, 2.3), (0.80, 0.180, 0.126, 0.134, 2.4), (0.90, 0.166, 0.110, 0.120, 2.5),
         (0.98, 0.150, 0.100, 0.106, 2.5)]
# Arms (t 0..1 upper arm, 1..2 forearm): the blouse sleeve, rolled up just past the elbow.
SLEEVE = [(-0.05, 0.058, 0.060), (0.3, 0.060, 0.062), (0.75, 0.062, 0.064), (1.02, 0.062, 0.064)]
CUFF = [(0.98, 0.066, 0.068), (1.06, 0.070, 0.072), (1.16, 0.066, 0.068), (1.20, 0.044, 0.046)]
FOREARM = [(1.0, 0.044, 0.046), (1.5, 0.038, 0.040), (2.0, 0.026, 0.027)]
STOCKING = [(0.95, 0.050, 0.054), (1.2, 0.046, 0.052, 0.056), (1.6, 0.038, 0.040)]
BOOT = [(1.55, 0.044, 0.047), (1.6, 0.047, 0.050), (1.85, 0.042, 0.044), (2.02, 0.044, 0.048, 0.045)]
FRINGE = [((78, 0.214, 0.012), (82, 0.18, 0.018), (86, 0.150, 0.014), (88, 0.132, 0.006)),
          ((100, 0.214, 0.012), (98, 0.18, 0.018), (95, 0.150, 0.014), (93, 0.134, 0.006)),
          ((60, 0.205, 0.010), (64, 0.17, 0.016), (66, 0.140, 0.012), (66, 0.122, 0.005))]


def build():
    ch = cb.Character("valentina", height=1.62, shoulders=0.88, hips=1.04)
    J, A, P = ch.J, ch.atlas, ch.part("Body")
    s = J["height"] / 1.72
    R = {n: A.rect(n, w, h) for n, w, h in (
        ("head", 128, 72), ("skirt", 120, 48), ("blouse", 128, 56), ("sleeve", 64, 32), ("hair", 32, 32),
        ("skin", 16, 16), ("hair_cap", 64, 32), ("vest", 96, 24), ("boot", 40, 32), ("stocking", 32, 24),
        ("hand", 24, 16), ("foot", 32, 16), ("braid", 16, 32), ("sash", 64, 8), ("kerchief", 32, 8),
        ("band", 16, 8), ("inner_band", 8, 8), ("ribbon", 8, 8), ("cuff", 16, 8), ("lining", 8, 8))}
    R["skin"].fill(C["skin"])
    R["lining"].fill(C["skirt_dk"])
    # Head and face: open, bright eyes; a slightly larger head reads younger.
    head = body.Head(J, rows=isa.HEAD_F, brow=0.003, scale=1.1)
    head.build(P, R["head"])
    body.nose(P, head, R["head"], length=0.013)
    bb.paint_head(head, R["head"], C["skin"], C["hair"], C["eye"], C["lip"], brow=C["brow"],
                  hairline=isa.hair_line, iris=C["iris"])
    body.neck(P, J, R["skin"], r=0.041)
    _hair(P, J, head, R)
    # Blouse, collar bands, corselet, sash, kerchief.
    body.trunk(P, J, R["blouse"], BLOUSE, segs=18)
    _paint_blouse(R["blouse"])
    R["band"].fill(C["indigo"])
    R["band"].hline(0.5, C["stitch"])
    R["inner_band"].fill(C["blouse_dk"])
    top = [(isa.t_top(z), z) for z in (1.448, 1.42, 1.38, 1.33, 1.28)]
    under = [(isa.t_under(z), z) for z in (1.448, 1.42, 1.38, 1.33, isa.Z_CROSS - 0.01)]
    ip.band(P, J, BLOUSE, top, 0.022, 0.006, R["band"].uv, 0.004, inner=(-1, R["inner_band"].uv, isa.Z_CROSS))
    ip.band(P, J, BLOUSE, under, 0.022, 0.005, R["band"].uv, 0.002, inner=(1, R["inner_band"].uv, isa.Z_CROSS))
    body.trunk(P, J, R["vest"], VEST, segs=18)
    _paint_vest(R["vest"])
    body.trunk(P, J, R["sash"], SASH, segs=18)
    R["sash"].fill(C["marigold"])
    R["sash"].hline(0.2, C["marigold_dk"])
    R["sash"].hline(0.8, C["marigold_dk"])
    body.trunk(P, J, R["kerchief"], KERCHIEF, segs=12)
    R["kerchief"].fill(C["marigold"])
    R["kerchief"].hline(0.35, C["marigold_dk"])
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
    R["sleeve"].hline(0.45, C["blouse_dk"])
    R["sleeve"].vline(0.0, C["blouse_dk"])
    R["cuff"].fill(C["blouse"])
    R["cuff"].hline(0.3, C["blouse_dk"])
    R["cuff"].hline(0.7, C["blouse_dk"])
    R["hand"].fill(C["skin"])
    R["hand"].hline(0.6, shade(C["skin"], 0.88))
    # Legs below the hem: stockings and short boots.
    legs = body.leg_joints(J)
    bb.mirrored(P, lambda: body.limb(P, J, legs, ("UpperLeg_R", "LowerLeg_R"), R["stocking"], STOCKING))
    bb.mirrored(P, lambda: body.limb(P, J, legs, ("UpperLeg_R", "LowerLeg_R"), R["boot"], BOOT))
    bb.mirrored(P, lambda: body.foot(P, J, R["foot"], rows=[
        (-0.085, 0.030, 0.033, -0.034), (-0.06, 0.038, 0.048, -0.026), (0.0, 0.041, 0.052, -0.02),
        (0.065, 0.043, 0.036, -0.041), (0.12, 0.042, 0.027, -0.052), (0.165, 0.035, 0.020, -0.06)]))
    R["stocking"].fill(C["stocking"])
    R["stocking"].vline(0.5, shade(C["stocking"], 0.8))
    R["boot"].fill(C["boot"])
    R["boot"].box(0, 0.82, 1, 1.0, shade(C["boot"], 1.2))     # the turned-down top
    R["boot"].vline(0.5, C["leather"], 1, 0.1, 0.8)            # front lacing
    R["foot"].fill(C["boot"])
    R["foot"].box(0.0, 0.0, 0.18, 1.0, C["sole"])
    R["foot"].box(0.82, 0.0, 1.0, 1.0, C["sole"])
    return ch


def _hair(P, J, head, R):
    """The shell, a short fringe, locks over her ears sweeping back, and the braid down her back."""
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
    for path in FRINGE:
        body.lock(P, head, r, path, [0.020, 0.024, 0.018, 0.0], depth=0.4, sides=4)
    # The braid: from the back of her head down to the middle of her back, following her neck then
    # her chest as she bends (weights pass from the head to the neck to the chest).
    s = J["height"] / 1.72
    pts = [Vector((0.0, y * s, z * s)) for y, z in ((-0.086, 1.55), (-0.098, 1.47), (-0.112, 1.40), (-0.128, 1.32),
                                                      (-0.132, 1.24), (-0.130, 1.16), (-0.126, 1.10), (-0.122, 1.05))]
    widths = [0.034 * s, 0.032 * s, 0.030 * s, 0.028 * s, 0.026 * s, 0.022 * s, 0.020 * s, 0.0]

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
    mesh.strand(P, [tie + Vector((0, -0.004, 0.012 * s)), tie + Vector((0, -0.008, -0.004 * s)),
                    tie + Vector((0, -0.010, -0.012 * s))], [0.026 * s, 0.027 * s, 0.0], 1.0,
                R["ribbon"].uv, {"Chest": 1.0}, up=(0, -1, 0), sides=6)
    b = R["braid"]
    b.fill(C["hair"])
    img = b.atlas.img
    for y in range(b.h):                                        # plaits: alternating slants
        for x in range(b.w):
            if (x + (y if (y // 4) % 2 else -y)) % 6 == 0:
                img[b.y + y, b.x + x] = shade(C["hair"], 0.62)
    R["ribbon"].fill(C["marigold"])


def _paint_blouse(r):
    def px(th, z):
        if z > isa.Z_CROSS and isa.t_under(z) - 3 < th < isa.t_top(z) + 3:
            return C["skin"]
        if abs(((th + 90) % 180) - 90) < 1.2 and abs(th - 90) > 30:
            return C["blouse_dk"]
        return C["blouse"]
    ip.paint_tz(r, BLOUSE[0][0], BLOUSE[-1][0], px)


def _paint_vest(r):
    """Indigo, laced up the front (blouse showing in the gap), white running stitch at the edges."""
    def px(th, z):
        f = abs(th - 90)
        if f < 4:
            return C["blouse"] if int((z - 0.98) * 260) % 4 else C["marigold"]   # the gap, crossed by laces
        if f < 5.5:
            return C["indigo_dk"]
        if z > 1.225 or z < 0.995:
            return C["stitch"] if int(th // 5) % 2 == 0 else C["indigo_dk"]
        return C["indigo"]
    ip.paint_tz(r, VEST[0][0], VEST[-1][0], px)


def _paint_skirt(r):
    """Ochre, softly folded, with an indigo band at the hem stitched in white crosses (sashiko)."""
    def px(th, z):
        if z < 0.47:
            band = (z - 0.40) / 0.07
            if 0.18 < band < 0.82 and int(th // 4) % 2 == 0 and abs(int((z - 0.40) * 600) % 8 - 4) < 2:
                return C["stitch"]
            return C["indigo"] if band > 0.08 else C["indigo_dk"]
        if int(th // 22) % 2 == 0 and z < 0.92:
            return shade(C["skirt"], 0.92)              # broad folds
        return C["skirt"]
    ip.paint_tz(r, SKIRT[0][0], SKIRT[-1][0], px)


if __name__ == "__main__":
    ch = build()
    ch.finish()
