"""Kael's sword Lamento, the paint for his clothes and his hairline (kael.py builds the shapes and
holds the colour table C, which it passes in here).
"""
import math
from mathutils import Vector
import base_body as bb
import body
import mesh
import props
from paint import rgb, shade


def lamento(part, atlas, C, bloody=False):
    """Lamento: a long, single-edged bone-white blade with a clipped point, a short square iron
    guard, a long red-wrapped grip, a ring pommel and a red tassel. Grip at the origin, blade +Y.
    The first call paints its texture; later calls reuse it (bloody: its own blade texture, with
    dark blood run down from the point and smeared along the edge)."""
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
    rb.vline(0.0, C["bone_edge"], 2)                       # the edge (u 0 / 1)
    rb.vline(0.97, C["bone_edge"], 2)
    rb.vline(0.5, C["bone_dark"], 1)                        # the spine
    for u in (0.36, 0.64):
        rb.vline(u, C["bone_dark"], 1, 0.06, 0.8)           # the fuller
    for v in (0.08, 0.12, 0.16):
        rb.box(0.18, v, 0.30, v + 0.01, C["bone_dark"])     # three engraved marks by the guard
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


def paint_clothes(r, C):
    """The black coat: lighter seams and piping so its shape still reads in the dark, silver clasps,
    the crimson lining only where it shows inside; a black leather sash, a charcoal scarf."""
    coat, edge, line = C["coat"], C["coat_edge"], C["coat_line"]
    c = r["coat"]
    c.fill(coat)
    c.box(0.0, 0.0, 0.03, 1.0, edge)                     # piping down both front edges
    c.box(0.97, 0.0, 1.0, 1.0, edge)
    for u in (0.25, 0.75):
        c.seam(u, line, shade(coat, 0.8), 0.0, 0.95)     # side seams
    c.seam(0.5, line, shade(coat, 0.8), 0.0, 1.0)        # back seam
    c.hline(0.80, edge)                                   # the yoke across the shoulders
    for u in (0.05, 0.95):
        for v in (0.3, 0.5, 0.7):
            c.dot(u, v, C["silver"])                      # clasps along the V
    r["collar"].fill(coat)
    r["collar"].box(0, 0.80, 1, 1.0, edge)
    r["collar"].hline(0.92, C["silver"])                  # a thin silver line round its top
    r["lining"].fill(C["lining"])
    r["collar_in"].fill(shade(coat, 1.2))
    k = r["skirt"]                                        # u: back slit (0) round to the front split (1)
    k.fill(coat)
    k.box(0, 0.0, 1, 0.06, edge)                          # hem band
    k.hline(0.06, line)
    k.box(0.0, 0.0, 0.025, 1.0, edge)
    k.box(0.975, 0.0, 1.0, 1.0, edge)
    for u in (0.3, 0.62):
        k.vline(u, line, 1, 0.08, 0.75)                   # two long folds
    k.seam(0.5, line, shade(coat, 0.8), 0.06, 1.0)        # side seam
    sl = r["sleeve"]
    sl.fill(coat)
    sl.box(0, 0.87, 1, 1.0, edge)                         # turned-back cuff
    sl.hline(0.87, C["lining"])
    sl.seam(0.5, line, shade(coat, 0.8), 0.0, 0.86)
    sl.hline(0.48, line)                                  # a crease at the elbow
    r["sash"].fill(C["sash"])
    r["sash"].hline(0.2, shade(C["sash"], 1.6))
    r["sash"].hline(0.8, shade(C["sash"], 1.6))
    r["sash_tail"].fill(C["sash"])
    r["sash_tail"].vline(0.5, shade(C["sash"], 1.5))
    r["sash_tail"].box(0, 0.88, 1, 1.0, C["silver"])      # metal tips on the ends
    r["scarf"].fill(C["scarf"])
    for v in (0.3, 0.65):
        r["scarf"].hline(v, shade(C["scarf"], 0.7))       # the wraps
    sh = r["shirt"]
    sh.fill(C["shirt"])
    sh.box(0, 0.0, 1, 0.22, C["trousers"])
    sh.vline(0.5, shade(C["shirt"], 1.4), 1, 0.3, 1.0)
    t = r["trousers"]
    t.fill(C["trousers"])
    t.seam(0.0, shade(C["trousers"], 0.75), shade(C["trousers"], 1.25))
    t.seam(0.5, shade(C["trousers"], 0.75), shade(C["trousers"], 1.25))
    b = r["boot"]
    b.fill(C["boot"])
    b.box(0, 0.86, 1, 1.0, C["boot_top"])                 # the boot's top band
    b.hline(0.86, C["silver"])
    b.box(0, 0.30, 1, 0.36, C["strap"])                   # an ankle strap with a silver buckle
    b.box(0.70, 0.29, 0.80, 0.37, C["silver"])
    b.seam(0.5, shade(C["boot"], 0.7), shade(C["boot"], 1.6), 0.0, 0.85)
    f = r["foot"]
    f.fill(C["boot"])
    f.box(0.0, 0.0, 0.18, 1.0, C["sole"])
    f.box(0.82, 0.0, 1.0, 1.0, C["sole"])
    f.box(0.0, 0.0, 1.0, 0.08, C["sole"])
    f.vline(0.5, shade(C["boot"], 1.5), 1, 0.3, 1.0)
    r["hand"].fill(C["glove"])
    r["hand"].box(0, 0.0, 1, 0.16, shade(C["glove"], 1.4))   # glove cuff
    r["hand"].hline(0.62, shade(C["glove"], 1.6))            # knuckle line
    r["neck"].fill(C["skin"])
    h = r["hair"]
    h.fill(C["hair"])
    h.vline(0.25, C["hair_dark"], 1, 0.15, 1.0)
    h.vline(0.75, C["hair_dark"], 1, 0.15, 1.0)
    h.vline(0.5, C["hair_light"], 1, 0.0, 0.6)
    h.box(0, 0.0, 1, 0.12, C["hair_dark"])                   # darker at the roots
    st = r["strap"]
    st.fill(C["strap"])
    st.vline(0.25, shade(C["strap"], 1.5))
    st.vline(0.75, shade(C["strap"], 1.5))
    st.box(0, 0.315, 1, 0.33, C["silver"])                    # the buckle on his chest
