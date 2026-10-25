"""Isabella, Aeneas's mother: calm, dignified, deliberate. A deep red wrapped robe (kimono-like,
her left panel over her right) with a black obi sash, a gold cord and a flat knot at the back; a
cream shawl over her shoulders with a point at the back, its ends slanting down the front to the
sash, a few embroidered roses; wide sleeves; long dark hair parted in the middle and swept back
into a low bun with a gold pin; dark boots. Her ink brush is in her right hand (prop "Brush") and
her bell hangs from the sash at her left hip ("Bell").

Rebuild:  .\\tools\\blender\\rebuild.ps1 isabella    (from the project folder, Godot closed)
Colours and shape tables are here; the shapes the shared helpers don't have (the skirt her legs
carry, the shawl, collar bands, hair shell, bun, knot, face paint) are in isabella_parts.py.
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
from paint import rgb, shade  # noqa: E402

# Her colours: change a hex code and rebuild.
C = {k: rgb(v) for k, v in {
    "skin": "#d9a785", "hair": "#2e211d", "hair_hi": "#4d3832", "eye": "#24170f", "iris": "#55372a",
    "lip": "#a8474c", "brow": "#2a1b16",
    "robe": "#9c2630", "robe_dk": "#6e1720", "collar": "#5a1219", "lining": "#43101a", "inner": "#efe6d2",
    "shawl": "#ebdfc4", "shawl_dk": "#cdbd98", "rose": "#a8343c", "leaf": "#6b7552",
    "obi": "#1f1c24", "obi_hi": "#3b3644", "gold": "#cba650", "boot": "#34241f", "sole": "#1a1210",
    "bamboo": "#c9ab66", "bamboo_dk": "#8f763e", "bristle": "#e6dcc4", "ink": "#121216",
    "bronze": "#c69c48", "bronze_dk": "#7c5d25", "cord": "#a82d31"}.items()}

# A softer, narrower jaw than the default head (rows as body.HEAD_ROWS).
HEAD_F = [(0.000, 0.046, 0.026, 0.028, 0.026, 2.1), (0.016, 0.030, 0.050, 0.060, 0.048, 2.2),
          (0.044, 0.016, 0.064, 0.078, 0.070, 2.35), (0.074, 0.008, 0.071, 0.087, 0.088, 2.4),
          (0.103, 0.004, 0.075, 0.088, 0.097, 2.4), (0.135, 0.0, 0.076, 0.089, 0.101, 2.4),
          (0.170, -0.005, 0.073, 0.083, 0.100, 2.3), (0.203, -0.010, 0.062, 0.066, 0.084, 2.2),
          (0.229, -0.015, 0.038, 0.040, 0.050, 2.0)]
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
# Hair locks: (angle from the face, height, lift) points from behind the temple, over the ear, to
# the bun, and their width. Mirrored for her left side.
LOCKS = [(((40, 0.168, 0.006), (70, 0.150, 0.011), (100, 0.126, 0.012), (130, 0.102, 0.011),
           (155, 0.086, 0.009), (175, 0.078, 0.004)), 0.042),
         (((62, 0.122, 0.004), (85, 0.104, 0.008), (110, 0.088, 0.009), (140, 0.076, 0.008),
           (162, 0.070, 0.006), (178, 0.070, 0.003)), 0.036)]
FACE_STRAND = ((25, 0.160, 0.006), (34, 0.13, 0.010), (45, 0.092, 0.010), (54, 0.058, 0.008), (59, 0.028, 0.004))


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


def t_top(z):
    """Angle of the top panel's collar edge at height z: from the left of her neck to her right hip."""
    return 62 + (z - 1.06) * 135.0


def t_under(z):
    """The under panel's edge, its mirror; the two cross at the front at Z_CROSS."""
    return 118 - (z - 1.06) * 135.0


Z_CROSS = 1.06 + 28 / 135.0


def build():
    ch = cb.Character("isabella", height=1.66, shoulders=0.9, hips=1.06)
    J, A, P = ch.J, ch.atlas, ch.part("Body")
    # Blocks of the 256 px texture, in packing order (rows of the atlas fill left to right).
    R = {n: A.rect(n, w, h) for n, w, h in (
        ("head", 128, 72), ("shawl", 96, 40), ("skin", 16, 16), ("lining", 8, 8),
        ("bodice", 128, 64), ("skirt", 120, 56),
        ("sleeve", 64, 40), ("hair", 32, 32), ("boot", 40, 32), ("bun", 32, 16), ("knot", 24, 16),
        ("hand", 24, 16), ("cuff", 16, 8), ("pin", 8, 8),
        ("obi", 64, 16), ("foot", 32, 16), ("bead", 8, 8), ("shawl_in", 8, 8), ("hair_cap", 64, 32),
        ("collar_band", 16, 8), ("inner_band", 8, 8))}
    R["skin"].fill(C["skin"])
    R["lining"].fill(C["lining"])
    R["shawl_in"].fill(shade(C["shawl"], 0.86))
    # Head, face, hair.
    head = body.Head(J, rows=HEAD_F, brow=0.003)
    head.build(P, R["head"])
    body.nose(P, head, R["head"], length=0.014)
    bb.paint_head(head, R["head"], C["skin"], C["hair"], C["eye"], C["lip"], hairline=hair_line, face=False)
    ip.paint_face(head, R["head"], C)
    body.neck(P, J, R["skin"], r=0.043)
    _hair(P, head, R)
    # Robe: bodice and its crossed collar, skirt, sleeves; the obi and its knot; the shawl.
    body.trunk(P, J, R["bodice"], BODICE, segs=18)
    _paint_bodice(R["bodice"])
    _collar(P, J, R)
    ip.skirt(P, J, SKIRT, R["skirt"], R["lining"])
    _paint_skirt(R["skirt"])
    arm = body.arm_joints(J)
    bb.mirrored(P, lambda: body.limb(P, J, arm, ("UpperArm_R", "LowerArm_R"), R["sleeve"], SLEEVE, segs=12,
                                     hand_bone="Hand_R"))
    # The sleeve opening turns inward to the wrist (the cream under-sleeve), then wrist and hand.
    bb.mirrored(P, lambda: body.limb(P, J, arm, ("UpperArm_R", "LowerArm_R"), R["cuff"],
                                     [(1.92, 0.082, 0.085), (1.895, 0.030, 0.031)], segs=12, hand_bone="Hand_R"))
    bb.mirrored(P, lambda: body.limb(P, J, arm, ("UpperArm_R", "LowerArm_R"), R["skin"],
                                     [(1.78, 0.029, 0.031), (2.0, 0.026, 0.027)], segs=8, hand_bone="Hand_R"))
    bb.mirrored(P, lambda: body.fist(P, J, R["hand"], size=0.93))
    _paint_sleeve(R["sleeve"], R["cuff"], R["hand"])
    body.trunk(P, J, R["obi"], OBI, segs=18)
    ip.knot(P, J, R["knot"])
    _paint_obi(R["obi"], R["knot"])
    ip.shawl(P, J, CAPE, R["shawl"], R["shawl_in"])
    _paint_shawl(R["shawl"])
    # Boots (the thighs stay hidden under the skirt, so only the shins are built).
    legs = body.leg_joints(J)
    bb.mirrored(P, lambda: body.limb(P, J, legs, ("UpperLeg_R", "LowerLeg_R"), R["boot"], BOOT))
    bb.mirrored(P, lambda: body.foot(P, J, R["foot"], rows=[
        (-0.085, 0.031, 0.034, -0.034), (-0.06, 0.039, 0.05, -0.026), (0.0, 0.042, 0.054, -0.02),
        (0.065, 0.045, 0.037, -0.041), (0.12, 0.044, 0.028, -0.052), (0.17, 0.036, 0.021, -0.06)]))
    _paint_boots(R["boot"], R["foot"])
    # Props.
    _brush(ch.prop("BrushMesh", "Weapon_R", "Brush"), A)
    _bell(ch.prop("BellMesh", "Sheath", "Bell"), A)
    return ch


def _hair(P, head, R):
    """Sleek hair: the shell over her skull, two locks over each ear, a loose strand by each side
    of her face, one down the back of her head, and the low bun with its gold pin."""
    ip.hair_shell(P, head, R["hair_cap"], hair_line, C["hair"], C["hair_hi"])
    r = R["hair"]
    r.fill(C["hair"])
    r.vline(0.5, C["hair_hi"], 1, 0.15, 0.85)
    r.vline(0.2, shade(C["hair"], 0.7), 1, 0.0, 1.0)
    r.vline(0.8, shade(C["hair"], 0.7), 1, 0.0, 1.0)
    for side in (1, -1):
        for path, w in LOCKS:
            pts = [(90 - side * a, z, l) for a, z, l in path]
            body.lock(P, head, r, pts, [w * 0.6, w, w, w * 0.9, w * 0.7, 0.0], depth=0.34, sides=5)
        pts = [(90 - side * a, z, l) for a, z, l in FACE_STRAND]
        body.lock(P, head, r, pts, [0.010, 0.012, 0.011, 0.008, 0.0], depth=0.5, sides=4)
    body.lock(P, head, r, [(270, 0.200, 0.012), (270, 0.16, 0.020), (270, 0.12, 0.018), (270, 0.09, 0.006)],
              [0.050, 0.056, 0.048, 0.0], depth=0.36, sides=5)
    ip.bun_and_pin(P, head, R["bun"].uv, R["pin"].uv, R["bead"].uv)
    b = R["bun"]
    b.fill(C["hair"])
    for k in range(4):                         # wrapped turns: diagonal stripes
        for x in range(b.w):
            b.atlas.img[b.y + (x // 2 + k * 4) % b.h, b.x + x] = shade(C["hair"], 0.68)
    b.box(0, 0.0, 1, 0.15, shade(C["hair"], 0.8))
    R["pin"].fill(C["gold"])
    R["bead"].fill(C["cord"])


def _collar(P, J, R):
    """The crossed collar as raised bands on the bodice: a dark red band along each panel's edge
    (the under one stops where it slides beneath the top one) and a cream under-collar inside."""
    R["collar_band"].fill(C["collar"])
    R["collar_band"].hline(0.5, shade(C["collar"], 1.3))
    R["inner_band"].fill(C["inner"])
    top = [(t_top(z), z) for z in (1.448, 1.42, 1.38, 1.33, 1.28, 1.23, 1.18, 1.125)]
    under = [(t_under(z), z) for z in (1.448, 1.42, 1.38, 1.33, 1.29, Z_CROSS - 0.01)]
    ip.band(P, J, BODICE, top, 0.024, 0.006, R["collar_band"].uv, 0.004, inner=(-1, R["inner_band"].uv, Z_CROSS))
    ip.band(P, J, BODICE, under, 0.024, 0.005, R["collar_band"].uv, 0.002, inner=(1, R["inner_band"].uv, Z_CROSS))


# ---------------------------------------------------------------- painting
def _paint_bodice(r):
    """Red robe, with skin inside the V of the collar (the raised bands cover its edges)."""
    def px(th, z):
        if z > Z_CROSS and t_under(z) - 3 < th < t_top(z) + 3:
            return C["skin"]
        if z > 1.425:
            return C["collar"]
        if abs(((th + 90) % 180) - 90) < 1.2 and abs(th - 90) > 30:
            return shade(C["robe"], 0.8)       # side seams
        return C["robe"]
    ip.paint_tz(r, BODICE[0][0], BODICE[-1][0], px)


def _paint_skirt(r):
    def px(th, z):
        edge = 62 - (1.06 - z) * 5.0          # the top panel's front edge, straight down
        if z < 0.268:
            return C["inner"]                  # the under-robe's hem peeking out
        if z < 0.30:
            return C["robe_dk"]
        if z < 0.312:
            return C["gold"] if (int(th // 6) % 2 == 0) else C["robe_dk"]
        if edge - 3 <= th <= edge:
            return C["collar"]
        if edge < th <= edge + 1.5:
            return C["inner"]
        if abs(((th + 90) % 180) - 90) < 1.2:
            return shade(C["robe"], 0.8)       # side seams
        return C["robe"]
    ip.paint_tz(r, SKIRT[0][0], SKIRT[-1][0], px)


def _paint_sleeve(r, cuff, hand):
    r.fill(C["robe"])
    r.box(0, 0.90, 1, 1.0, C["robe_dk"])       # a darker band at the opening
    r.hline(0.90, C["gold"])
    r.hline(0.5, shade(C["robe"], 0.82))       # the elbow fold
    r.vline(0.0, shade(C["robe"], 0.8), 1, 0.0, 0.9)
    cuff.fill(C["inner"])                      # the cream under-sleeve inside the opening
    cuff.box(0, 0.0, 1, 0.25, C["robe_dk"])
    hand.fill(C["skin"])
    hand.hline(0.6, shade(C["skin"], 0.86))


def _paint_obi(r, knot):
    r.fill(C["obi"])
    for k in range(8):                         # a quiet diamond pattern
        u = (k + 0.5) / 8
        r.dot(u, 0.72, C["obi_hi"], 2)
        r.dot(u + 1 / 16, 0.28, C["obi_hi"], 2)
    r.hline(0.5, C["gold"], 2)                 # the gold cord round the middle
    r.box(0.48, 0.38, 0.52, 0.62, C["gold"])   # its knot at the front
    r.hline(0.97, C["robe"])                   # a red edge peeking out at the top
    knot.fill(C["obi"])
    knot.hline(0.5, C["gold"], 2)
    knot.vline(0.25, C["obi_hi"])
    knot.vline(0.75, C["obi_hi"])


def _paint_shawl(r):
    """Cream, a fringe along the hem, a thin red border, roses on the back and on the front ends
    (u: 0 = inner edge of her left front end, 0.5 = the middle of her back; v: 0 hem, 1 neck)."""
    img = r.atlas.img
    r.fill(C["shawl"])
    for x in range(r.w):                       # the fringe: short strands along the hem
        img[r.y + r.h - 3:r.y + r.h, r.x + x] = C["shawl_dk"] if x % 2 else C["shawl"]
    r.hline(0.16, C["rose"])
    r.hline(0.93, C["shawl_dk"])
    r.box(0.0, 0.0, 0.012, 1.0, C["shawl_dk"])
    r.box(0.988, 0.0, 1.0, 1.0, C["shawl_dk"])
    def rose(u, v, big):
        cx, cy = r.px(u, v)
        rr = 3 if big else 2
        for dy in range(-rr - 2, rr + 3):
            for dx in range(-rr - 3, rr + 4):
                if abs(dx) > rr and abs(dy) <= 1 and abs(dx) <= rr + 3:
                    img[cy + dy, cx + dx] = C["leaf"]          # leaves either side
                elif dx * dx + dy * dy <= rr * rr + 1:
                    img[cy + dy, cx + dx] = C["rose"]
        img[cy, cx - 1:cx + 1] = shade(C["rose"], 0.7)        # the heart of the flower
        img[cy - 1, cx] = shade(C["rose"], 0.7)
    rose(0.5, 0.42, True)
    for u in (0.36, 0.64):
        rose(u, 0.5, False)
    for u in (0.05, 0.95):
        rose(u, 0.35, False)


def _paint_boots(r, foot):
    r.fill(C["boot"])
    r.hline(0.30, C["cord"])                   # a red cord tied round the ankle
    r.hline(0.26, C["cord"])
    r.vline(0.5, shade(C["boot"], 0.7), 1, 0.0, 0.9)
    r.vline(0.0, shade(C["boot"], 1.3), 1, 0.0, 0.9)
    foot.fill(C["boot"])
    foot.box(0.0, 0.0, 0.18, 1.0, C["sole"])
    foot.box(0.82, 0.0, 1.0, 1.0, C["sole"])
    foot.box(0.0, 0.0, 1.0, 0.08, shade(C["boot"], 0.7))


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
    rf.hline(0.5, C["gold"])
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
    ch.finish(preview=None)
