"""Kael's sword Lamento, his talisman, the shadow his fringe throws on his brow, and the paint for
his clothes (kael.py builds the shapes and holds the colour table C, which it passes in here).
"""
import math
import numpy as np
from mathutils import Matrix, Vector
import base_body as bb
import body
import face
import mesh
import props
from paint import rgb, shade


def lamento(part, atlas, C, bloody=False):
    """Lamento: a long, single-edged bone-white blade with a clipped point, a short square iron
    guard, a long red-wrapped grip, a ring pommel and a red tassel. Grip at the origin, blade +Y.
    The blade is the one light on him: pale bone with a faint violet edge. The first call paints
    its texture; later calls reuse it (bloody: its own blade texture, with dark blood run down from
    the point and smeared along the edge)."""
    if "lamento_grip" in atlas.rects:
        rg, rm, rt = atlas.rects["lamento_grip"], atlas.rects["lamento_iron"], atlas.rects["lamento_tassel"]
        rb = atlas.rect("lamento_blood", 48, 12) if bloody else atlas.rects["lamento_blade"]
    else:
        rb, rg, rm, rt = (atlas.rect("lamento_blade", 48, 12), atlas.rect("lamento_grip", 24, 16),
                          atlas.rect("lamento_iron", 16, 8), atlas.rect("lamento_tassel", 8, 16))
    L, w, t = 0.86, 0.027, 0.0065

    def back(p):
        return (0.0, 0.0, -0.022 * ((p - 0.09) / L) ** 2)   # a gentle curve back toward the spine
    rows = [(0.09, w * 0.9, t), (0.13, w, t), (0.09 + L * 0.5, w * 0.97, t * 0.95), (0.09 + L * 0.82, w * 0.9, t * 0.85),
            (0.09 + L * 0.93, w * 0.62, t * 0.7)]
    props.rod(part, [rw + (back(rw[0]),) for rw in rows] + [(0.09 + L, 0.0, 0.0, (0, 0, -0.022 - w * 0.5))],
              rb.uv, sides=4, start=0.0, smooth=False)
    props.rod(part, [(0.078, 0.0, 0.0), (0.079, 0.040, 0.016), (0.094, 0.040, 0.016), (0.095, 0.0, 0.0)],
              rm.uv, sides=4, start=45.0, smooth=False)                             # the guard
    props.rod(part, [(-0.17, 0.015, 0.015), (-0.05, 0.0168, 0.0168), (0.078, 0.0152, 0.0152)], rg.uv, sides=6)
    props.rod(part, [(-0.185, 0.0, 0.0), (-0.182, 0.012, 0.012), (-0.17, 0.018, 0.018), (-0.165, 0.0, 0.0)],
              rm.uv, sides=6)                                                        # pommel collar
    rr, tube, yc = 0.026, 0.0065, -0.185 - 0.026
    rings = []
    for k in range(11):                                                              # the ring pommel
        a = 2 * math.pi * k / 10
        out = Vector((0, math.cos(a), math.sin(a)))
        rings.append({"c": Vector((0, yc, 0)) + out * rr, "x": Vector((1, 0, 0)), "y": out, "rx": tube, "ry": tube,
                      "n": 2.0, "w": {}})
    mesh.loft(part, rings, 4, rm.uv, start=45.0)
    top = Vector((0, yc, rr + tube))
    pts = [top, top + Vector((0, 0.035, 0.012)), top + Vector((0, 0.08, 0.018)), top + Vector((0, 0.11, 0.014))]
    body.strand(part, pts, [0.008, 0.012, 0.016, 0.0], 0.6, rt.uv, {}, up=Vector((1, 0, 0)), sides=5)
    rb.fill(C["bone"])
    rb.vline(0.0, C["bone_edge"], 3)                       # the edge (u 0 / 1): a faint violet
    rb.vline(0.94, C["bone_edge"], 3)
    rb.vline(0.5, C["bone_dark"], 2)                        # the spine
    for u in (0.3, 0.7):
        rb.vline(u, C["bone_dark"], 1, 0.06, 0.8)           # the fuller
    for v in (0.08, 0.13, 0.18):
        rb.box(0.16, v, 0.32, v + 0.02, C["bone_dark"])     # three engraved marks by the guard
    if bloody:
        blood, dried = rgb("#6a0f14"), rgb("#3e080b")
        rb.box(0, 0.55, 1, 1.0, blood)                      # the point half of the blade, wet
        for u in (0.12, 0.3, 0.55, 0.8):
            rb.vline(u, blood, 1, 0.28, 0.6)                # runs back toward the guard
        rb.vline(0.0, dried, 2, 0.2, 1.0)                   # smeared along the edge
        rb.vline(0.97, dried, 1, 0.4, 1.0)
    rg.fill(C["wrap"])
    for k in range(4):                                      # the wrap: dark bands crossing the red
        v = k / 4
        rg.box(0, v, 1, v + 0.02, C["wrap_dark"])
        rg.box(0.0, v + 0.12, 0.08, v + 0.14, C["wrap_dark"])
        rg.box(0.5, v + 0.12, 0.58, v + 0.14, C["wrap_dark"])
    rm.fill(C["iron"])
    rm.hline(0.5, shade(C["iron"], 1.35))
    rt.fill(C["red"])
    rt.vline(0.5, shade(C["red"], 0.7))
    rt.box(0, 0.85, 1, 1.0, C["wrap_dark"])


def hairline(theta):
    """Where his scalp turns from skin to hair: low at the sides and nape, under the fringe."""
    return bb.hair_line(theta) - 0.018


def fringe_shadow(head, rect, L):
    """The fringe's shadow on his brow: the forehead darkens toward the hairline (strongest just
    under the hair, gone by the brows), across the face only."""
    r = rect
    u = (np.arange(r.w) + 0.5) / r.w
    v = 1.0 - (np.arange(r.h) + 0.5) / r.h
    lo, hi = 0.5 - face.FACE_U / 360.0, 0.5 + face.FACE_U / 360.0
    f = np.interp(u, [0.0, (1 - face.U_FACE) / 2, (1 + face.U_FACE) / 2, 1.0], [0.0, lo, hi, 1.0])
    theta = f * 360.0 - 90.0
    z = np.interp(v, [p[1] for p in face.V_PTS], [p[0] for p in face.V_PTS])
    A, Z = np.meshgrid(theta, z)
    hl = np.array([hairline(t) for t in theta])[None, :]
    z0 = L["brow_z"] + 0.004
    k = np.clip((Z - z0) / (hl - 0.004 - z0), 0.0, 1.0) * (np.abs(A - 90.0) < 48.0)
    k = k * np.clip(1.0 - (np.abs(A - 90.0) - 36.0) / 12.0, 0.0, 1.0)   # fades out at the temples
    k = k * (Z < hl - 0.002)
    r.atlas.img[r.y:r.y + r.h, r.x:r.x + r.w] *= (1.0 - 0.45 * k)[..., None]


def talisman(P, J, r_cord, r_disc, torso):
    """A black-metal disc on a cord at his throat, hanging in the open V of the coat: an eight-sided
    coin, bevelled, its face ringed in thin silver with a bright centre (an eye). Two cords run from
    the sides of his neck down to it."""
    s = J["height"] / 1.72
    zc = 1.335
    front = body.trunk_point(J, torso, 90, zc, 0.0).y + 0.016 * s
    centre = Vector((0.0, front, zc * s))
    rad = 0.025 * s
    v0 = len(P.verts)
    props.rod(P, [(-0.006 * s, 0.0, 0.0), (-0.004 * s, rad * 0.22, rad * 0.22), (-0.0025 * s, rad, rad),
                  (0.0025 * s, rad, rad), (0.004 * s, rad * 0.22, rad * 0.22), (0.006 * s, 0.0, 0.0)],
              r_disc.uv, sides=8, start=22.5, smooth=False)
    mesh.transform_part(P, Matrix.Translation(centre), since=v0)
    for i in range(v0, len(P.verts)):
        P.weights[i] = body.spine_w(J, zc * s)
    top = centre + Vector((0, 0, rad))
    for side in (1, -1):
        pts = [body.trunk_point(J, torso, 90 - side * 38, 1.428, 0.006),
               body.trunk_point(J, torso, 90 - side * 22, 1.395, 0.010), top + Vector((side * 0.004 * s, 0, 0))]
        body.strand(P, pts, [0.0055 * s, 0.0055 * s, 0.0], 0.9, r_cord.uv,
                    lambda k: body.spine_w(J, (1.428 - 0.093 * k) * s), up=Vector((0, 1, 0)), sides=4)


def paint_clothes(r, C):
    """The black coat: fat lighter seams and piping so its shape still reads in the dark, silver
    clasps, the blood-red lining where it shows (the open front, inside the collar, the cuffs), the
    hem worn and dusty; a black leather sash; the talisman and its cord; the hair's shading."""
    coat, edge, line, lining = C["coat"], C["coat_edge"], C["coat_line"], C["lining"]
    c = r["coat"]
    c.fill(coat)
    c.box(0.0, 0.0, 0.04, 1.0, edge)                     # piping down both front edges
    c.box(0.96, 0.0, 1.0, 1.0, edge)
    for u in (0.25, 0.75):
        c.seam(u, line, shade(coat, 0.8), 0.0, 0.95)     # side seams
    c.seam(0.5, line, shade(coat, 0.8), 0.0, 1.0)        # back seam
    c.box(0, 0.80, 1, 0.83, edge)                         # the yoke across the shoulders
    c.hline(0.80, line, 2)
    for u in (0.07, 0.93):
        for v in (0.3, 0.5, 0.7):
            c.dot(u, v, C["silver"], 2)                   # clasps along the V
    col = r["collar"]
    col.fill(coat)
    col.box(0, 0.82, 1, 1.0, edge)
    col.hline(0.82, line, 2)
    col.box(0, 0.0, 1, 0.08, line)                        # the seam where it meets the coat
    r["lining"].fill(lining)
    r["collar_in"].fill(lining)
    r["collar_in"].box(0, 0.0, 1, 0.2, shade(lining, 0.7))
    _skirt(r["skirt"], C)
    sl = r["sleeve"]
    sl.fill(coat)
    sl.box(0, 0.85, 1, 1.0, lining)                       # turned-back cuff: the lining shows
    sl.hline(0.85, shade(lining, 0.55), 2)
    sl.seam(0.5, line, shade(coat, 0.8), 0.0, 0.84)
    sl.hline(0.48, line)                                  # a crease at the elbow
    r["sash"].fill(C["sash"])
    r["sash"].hline(0.2, shade(C["sash"], 1.7))
    r["sash"].hline(0.8, shade(C["sash"], 1.7))
    r["sash_tail"].fill(C["sash"])
    r["sash_tail"].vline(0.5, shade(C["sash"], 1.5))
    r["sash_tail"].box(0, 0.88, 1, 1.0, C["silver"])      # metal tips on the ends
    sh = r["shirt"]
    sh.fill(C["shirt"])
    sh.box(0, 0.0, 1, 0.22, C["trousers"])
    sh.box(0, 0.93, 1, 1.0, shade(C["shirt"], 1.5))       # the shirt's own collar band
    sh.vline(0.5, shade(C["shirt"], 1.4), 1, 0.3, 1.0)
    t = r["trousers"]
    t.fill(C["trousers"])
    t.seam(0.0, shade(C["trousers"], 0.75), shade(C["trousers"], 1.25))
    t.seam(0.5, shade(C["trousers"], 0.75), shade(C["trousers"], 1.25))
    _boots(r, C)
    r["hand"].fill(C["glove"])
    r["hand"].box(0, 0.0, 1, 0.16, shade(C["glove"], 1.5))   # glove cuff
    r["hand"].hline(0.62, shade(C["glove"], 1.7))            # knuckle line
    r["neck"].fill(C["skin"])
    h = r["hair"]
    h.fill(C["hair"])
    h.box(0, 0.0, 1, 0.16, C["hair_dark"])                   # darker at the roots
    h.box(0.0, 0.16, 0.22, 1.0, shade(C["hair"], 0.9))       # the underside of each wedge, a shade cooler
    h.box(0.38, 0.3, 0.62, 1.0, C["hair_light"])             # a light ridge along the top
    st = r["strap"]
    st.fill(C["strap"])
    st.vline(0.25, shade(C["strap"], 1.5))
    st.vline(0.75, shade(C["strap"], 1.5))
    st.box(0, 0.315, 1, 0.33, C["silver"])                    # the buckle on his chest
    r["cord"].fill(shade(C["strap"], 0.8))
    d = r["talisman"]                                         # v: back pole (0) to the front pole (1)
    d.fill(C["metal"])
    d.box(0, 0.46, 1, 0.54, shade(C["silver"], 0.8))          # the rim, silver
    d.box(0, 0.78, 1, 0.83, C["silver"])                      # a thin ring on its face
    d.box(0, 0.96, 1, 1.0, C["silver"])                       # the centre (the pole): a bright eye


def _skirt(k, C):
    """The coat's skirt: u runs from the back slit (0) round to the front split (1), v hem to waist.
    Piping down both edges, a side seam, two long folds, and a hem gone grey with dust: a band of
    mottled grime, a few frayed notches, a patch at the back."""
    coat, edge, line = C["coat"], C["coat_edge"], C["coat_line"]
    k.fill(coat)
    k.box(0.0, 0.0, 0.03, 1.0, edge)
    k.box(0.97, 0.0, 1.0, 1.0, edge)
    for u in (0.3, 0.62):
        k.vline(u, line, 1, 0.12, 0.75)                   # two long folds
    k.seam(0.5, line, shade(coat, 0.8), 0.1, 1.0)         # side seam
    k.box(0, 0.0, 1, 0.07, C["dust"])                     # the hem, grey with dust
    for i in range(16):                                    # mottled grime climbing above it
        u = (i + 0.5) / 16
        top = 0.07 + 0.06 * (1 + math.sin(i * 2.4)) / 2
        k.box(u - 0.03, 0.07, u + 0.03, top, C["dust"] if i % 3 else C["dust_light"])
        if i % 5 == 2:
            k.box(u - 0.02, 0.0, u + 0.02, 0.03, shade(coat, 0.6))   # a frayed notch
    k.box(0.12, 0.18, 0.24, 0.30, shade(coat, 1.3))       # a patch sewn on near the back slit
    k.hline(0.07, shade(C["dust"], 1.25))


def _boots(r, C):
    """Tall black boots with a strap and buckle at the ankle, dusty at the foot."""
    b = r["boot"]
    b.fill(C["boot"])
    b.box(0, 0.86, 1, 1.0, C["boot_top"])                 # the boot's top band
    b.hline(0.86, C["silver"])
    b.box(0, 0.30, 1, 0.36, C["strap"])                   # an ankle strap with a silver buckle
    b.box(0.70, 0.29, 0.80, 0.37, C["silver"])
    b.seam(0.5, shade(C["boot"], 0.7), shade(C["boot"], 1.6), 0.0, 0.85)
    for i in range(8):                                     # dust up the foot of the boot
        u = (i + 0.5) / 8
        b.box(u - 0.05, 0.0, u + 0.05, 0.05 + 0.05 * (i % 3), C["dust"])
    f = r["foot"]
    f.fill(C["boot"])
    f.box(0.0, 0.0, 0.18, 1.0, C["sole"])
    f.box(0.82, 0.0, 1.0, 1.0, C["sole"])
    f.box(0.0, 0.0, 1.0, 0.08, C["sole"])
    f.box(0.2, 0.08, 0.8, 0.2, C["dust"])
    f.vline(0.5, shade(C["boot"], 1.5), 1, 0.3, 1.0)
