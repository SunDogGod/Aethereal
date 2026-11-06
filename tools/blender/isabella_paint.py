"""Isabella's paint (isabella.py builds, this colours): fat strokes only, nothing thinner than two
texels, since a one-texel line turns to noise at 960x540. Worn cloth: faded hems, frayed edges,
stitched patches in ochre thread. Each function takes a texture block (paint.Rect), her colour
table C and, where a block is painted by angle and height, the shape tables (G = isabella module).
"""
import isabella_parts as ip
from paint import shade


def _dashes(r, v, color, on=4, off=4, px=2, u0=0.0, u1=1.0):
    """A row of fat stitch dashes along v (u0..u1)."""
    x0, _ = r.px(u0, v)
    x1, _ = r.px(u1, v)
    _, row = r.px(0, v)
    img = r.atlas.img
    x = x0
    while x < x1:
        img[row:row + px, x:min(x + on, x1 + 1)] = color
        x += on + off


def bodice(r, C, G):
    """Deep red, skin inside the collar's V, the collar's own colour above the bands, fat seams."""
    def px(th, z):
        if z > G.Z_CROSS and G.t_under(z) - 3 < th < G.t_top(z) + 3:
            return C["skin"]
        if z > 1.425:
            return C["collar"]
        if abs(((th + 90) % 180) - 90) < 2.5 and abs(th - 90) > 30:
            return C["robe_dk"]                 # side seams
        return C["robe"]
    ip.paint_tz(r, G.BODICE[0][0], G.BODICE[-1][0], px)


def skirt(r, C, G):
    """The robe below the obi: the top panel's edge running down her front, a faded and frayed hem
    over the cream under-robe, an ochre stitched hem line, a patch at her right knee."""
    hem0 = G.SKIRT[0][0]
    def px(th, z):
        edge = 62 - (1.06 - z) * 5.0
        if z < hem0 + 0.012:
            return C["inner"]                   # the under-robe peeking out
        if z < hem0 + 0.04:
            fray = int(th // 6) % 2 == 0 and z < hem0 + 0.02
            return C["worn"] if fray else C["robe_fade"]
        if 20 <= th <= 52 and 0.40 <= z <= 0.56:          # a patch, stitched on
            on_edge = th < 25 or th > 47 or z < 0.43 or z > 0.53
            return C["ochre"] if on_edge and (int(th // 5) + int(z * 60)) % 2 == 0 else C["robe_dk"]
        if edge - 8 <= th <= edge:
            return C["collar"]
        if edge < th <= edge + 5:
            return C["inner"]
        if abs(((th + 90) % 180) - 90) < 4.0:
            return C["robe_dk"]
        return C["robe"]
    ip.paint_tz(r, hem0, G.SKIRT[-1][0], px)
    _dashes(r, 0.085, C["ochre"], on=3, off=3, px=2)


def sleeves(r, cuff, hand, C):
    r.fill(C["robe"])
    r.box(0, 0.88, 1, 1.0, C["robe_fade"])     # a faded band at the opening
    r.hline(0.87, C["ochre"], 2)               # its stitched edge
    r.box(0.28, 0.42, 0.72, 0.60, C["robe_dk"])   # an elbow patch
    _dashes(r, 0.60, C["ochre"], on=2, off=2, px=2, u0=0.28, u1=0.72)
    _dashes(r, 0.42, C["ochre"], on=2, off=2, px=2, u0=0.28, u1=0.72)
    r.vline(0.0, C["robe_dk"], 2, 0.0, 0.87)
    cuff.fill(C["inner"])
    cuff.box(0, 0.0, 1, 0.25, C["robe_fade"])
    hand.fill(C["skin"])
    hand.hline(0.6, shade(C["skin"], 0.86))


def obi(r, knot, C):
    """The ochre sash: worn darker at its edges, a dark leather cord round it and a plate at the
    front; the flat knot at the back to match."""
    r.fill(C["ochre"])
    r.box(0, 0.0, 1, 0.14, C["ochre_dk"])
    r.box(0, 0.86, 1, 1.0, C["ochre_dk"])
    r.hline(0.46, C["leather"], 2)
    r.box(0.45, 0.25, 0.55, 0.75, C["leather"])
    r.box(0.48, 0.42, 0.52, 0.58, C["brass"])
    knot.fill(C["ochre"])
    knot.box(0, 0.0, 1, 0.15, C["ochre_dk"])
    knot.hline(0.5, C["leather"], 2)
    knot.vline(0.3, C["ochre_dk"], 2)
    knot.vline(0.7, C["ochre_dk"], 2)


def shawl(r, C):
    """Dark wool, an ochre stripe above a frayed hem, the neck fold worn pale, rubbed shoulders
    (u: 0 = inner edge of her left front end, 0.5 = the middle of her back; v: 0 hem, 1 neck)."""
    img = r.atlas.img
    r.fill(C["shawl"])
    for x in range(r.w):                       # frayed tufts along the hem
        img[r.y + r.h - 3:r.y + r.h, r.x + x] = C["shawl_dk"] if (x // 2) % 2 else C["shawl"]
    r.box(0, 0.14, 1, 0.24, C["ochre"])
    r.box(0, 0.24, 1, 0.28, C["ochre_dk"])
    r.box(0, 0.93, 1, 1.0, shade(C["shawl"], 1.35))
    for u in (0.22, 0.78):
        r.box(u - 0.06, 0.55, u + 0.06, 0.85, shade(C["shawl"], 1.18))
    r.box(0.0, 0.0, 0.02, 1.0, C["shawl_dk"])
    r.box(0.98, 0.0, 1.0, 1.0, C["shawl_dk"])


def wrap(r, tail_b, tail_o, C):
    """The ultramarine headwrap: a pale rolled edge, two darker turns of cloth, the crown faded by
    the sun (v: 0 edge, 1 crown); its two tails, one blue and one ochre."""
    r.fill(C["blue"])
    r.box(0, 0.0, 1, 0.14, C["blue_hi"])
    r.hline(0.14, C["blue_dk"], 2)
    r.hline(0.40, C["blue_dk"], 2)
    r.hline(0.64, C["blue_dk"], 2)
    r.box(0, 0.84, 1, 1.0, C["blue_fade"])
    tail_b.fill(C["blue"])
    tail_b.box(0, 0.0, 1, 0.2, C["blue_dk"])
    tail_o.fill(C["ochre"])
    tail_o.box(0, 0.0, 1, 0.2, C["ochre_dk"])


def braid(b, tie, C):
    """Plaited hair: fat chevrons, a pale sheen down the middle, ochre thread wound round it in
    three bands so it reads against the dark shawl (v runs from the nape to the tip); the ochre
    tie at the end."""
    b.fill(C["hair"])
    img = b.atlas.img
    for y in range(b.h):
        for x in range(b.w):
            k = (x + (y if (y // 4) % 2 else -y)) % 8
            if k < 2:
                img[b.y + y, b.x + x] = shade(C["hair"], 0.55)
            elif k in (4, 5) and 3 <= x < b.w - 3:
                img[b.y + y, b.x + x] = shade(C["hair_hi"], 1.2)
    for v in (0.3, 0.55, 0.8):
        b.hline(v, C["ochre"], 2)
        b.hline(v - 0.06, C["ochre_dk"], 1)
    tie.fill(C["ochre"])
    tie.hline(0.5, C["ochre_dk"], 2)


def hair(r, C):
    r.fill(C["hair"])
    r.vline(0.5, C["hair_hi"], 2, 0.15, 0.85)
    r.vline(0.15, shade(C["hair"], 0.7), 2)
    r.vline(0.8, shade(C["hair"], 0.7), 2)


def leather(strap, bag, flap, C):
    """The satchel strap (its outer face is u 0..0.25: a lighter worn middle), the bag and its flap
    with a brass buckle."""
    strap.fill(C["leather"])
    strap.vline(0.07, C["leather_hi"], 2)
    bag.fill(C["leather"])
    bag.box(0, 0.0, 1, 0.12, C["leather_dk"])
    bag.box(0, 0.88, 1, 1.0, C["leather_hi"])
    bag.box(0.45, 0.3, 0.55, 0.9, C["leather_hi"])
    flap.fill(C["leather"])
    flap.box(0.25, 0.0, 0.75, 1.0, C["leather_hi"])
    flap.box(0.25, 0.0, 0.75, 0.1, C["leather_dk"])
    flap.box(0.42, 0.62, 0.58, 0.82, C["brass"])


def boots(r, foot, C):
    """Dark boots with two buckled straps."""
    r.fill(C["boot"])
    for v in (0.28, 0.56):
        r.hline(v, C["leather_dk"], 2)
        r.box(0.44, v - 0.02, 0.56, v + 0.08, C["brass"])
    r.vline(0.5, shade(C["boot"], 0.7), 2, 0.0, 0.9)
    r.vline(0.0, shade(C["boot"], 1.3), 2, 0.0, 0.9)
    foot.fill(C["boot"])
    foot.box(0.0, 0.0, 0.18, 1.0, C["sole"])
    foot.box(0.82, 0.0, 1.0, 1.0, C["sole"])
    foot.box(0.0, 0.0, 1.0, 0.08, shade(C["boot"], 0.7))
