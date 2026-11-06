"""The paint the Agency's armour and lower body share (agent.py, lieutenant.py, captain.py): the
dark plate with its keel, lames, straps, rivets, the cult's eye on the left breast and rank bars on
the right, chips and dents (`worn`); the gauntlets, boots, trousers, belt, pouches and straps.
"""
import agency_parts as ap
import agency_marks as am
from agency_parts import C
from paint import shade


def paint_armour(R, chipped=True, rank=0, worn=1.0):
    """Breastplate, shoulders, lames, knee and hip plates: dark steel with a lit lower bevel, the
    keel, abdomen lames, side straps, rivets, the cult's eye mark on the left breast, rank bars on
    the right, and old chips and dents (`worn` = how many: the captain's plate has seen more)."""
    plate = [R[n] for n in ("cuirass", "pauldron", "lame", "knee", "tasset") if n in R]
    for r in plate:
        r.fill(C["plate"])
        r.box(0, 0.0, 1, 0.12, C["plate_hi"])        # light bevel along the lower edge
        r.hline(0.13, C["plate_dk"])
        if chipped:
            ap.chips(r, shade(C["plate_hi"], 1.15), count=max(3, int(r.w // 8 * worn)), seed=r.w + r.h,
                     v_range=(0.0, 0.2))
            am.dents(r, C["plate_dk"], C["plate_hi"], count=max(1, int(r.w // 24 * worn)), seed=r.w * 3 + r.h,
                     v_range=(0.2, 0.85))
    c = R["cuirass"]
    c.box(0, 0.93, 1, 1.0, C["plate_hi"])            # neck edge
    c.hline(0.92, C["plate_dk"])
    c.vline(0.5, C["plate_hi"], 1, 0.13, 0.92)      # the keel
    c.vline(0.51, C["plate_dk"], 1, 0.13, 0.92)
    for v in (0.30, 0.45):                            # abdomen lames
        c.hline(v, C["plate_dk"])
        c.hline(v - 0.03, shade(C["plate"], 1.25))
    for u in (0.25, 0.75):                            # side straps with buckles
        c.box(u - 0.02, 0.15, u + 0.02, 0.9, C["leather"])
        c.box(u - 0.025, 0.55, u + 0.025, 0.62, C["buckle"])
    for k in range(12):                               # rivets along the neck edge
        c.dot(0.04 + k * 0.083, 0.88, C["rivet"])
    am.eye_mark(c, 0.625, 0.72, 8, 10, C["mark"], C["mark"], C["plate_dk"])   # the cult's eye on the left breast
    if rank:
        am.rank_bars(c, 0.375, 0.78, rank, C["mark"])
    if worn > 1.0:
        am.crack(c, 0.68, 0.16, 0.52, C["plate_dk"], seed=9)             # a crack up from the fauld
        c.box(0.26, 0.40, 0.33, 0.47, shade(C["plate"], 0.8))            # a big old dent in the ribs
        c.hline(0.39, C["plate_hi"], 1)
    if "pauldron" in R:
        R["pauldron"].box(0, 0.9, 1, 1.0, C["plate_dk"])
        for k in range(6):
            R["pauldron"].dot(0.1 + k * 0.16, 0.2, C["rivet"])
        R["pauldron"].box(0.42, 0.45, 0.58, 0.5, C["scuff"])             # a scuff across the dome
    if "tasset" in R:
        R["tasset"].hline(0.5, C["plate_dk"])
        R["tasset"].dot(0.5, 0.85, C["rivet"], 2)
    R["plate_in"].fill(C["plate_dk"])


def paint_lower(R):
    """Gauntlets, gloves, trousers, boots (dusty at the foot), feet, belt and pouches."""
    g = R["gauntlet"]
    g.fill(C["leather"])
    g.box(0.56, 0.22, 0.94, 0.8, C["plate"])        # the steel plate on the back of the forearm
    g.hline(0.8, C["plate_hi"])
    g.hline(0.22, C["plate_dk"])
    g.box(0, 0.86, 1, 1.0, C["leather_hi"])           # flared cuff edge
    am.stitches(g, 0.0, 0.84, 1.0, 0.84, C["leather_hi"])
    R["hand"].fill(C["leather"])
    R["hand"].hline(0.62, C["leather_hi"], 2)        # knuckle ridge
    R["neck"].fill(C["suit"])
    R["trousers"].fill(C["suit"])
    R["trousers"].seam(0.0, shade(C["suit"], 0.7), shade(C["suit"], 1.4))
    R["trousers"].seam(0.5, shade(C["suit"], 0.7), shade(C["suit"], 1.4))
    b = R["boot"]
    b.fill(C["boot"])
    b.box(0, 0.88, 1, 1.0, C["leather_hi"])           # boot top
    for v in (0.35, 0.6):                             # straps with buckles
        b.hline(v, C["leather_hi"], 2)
        b.box(0.70, v - 0.02, 0.78, v + 0.05, C["buckle"])
    b.seam(0.5, shade(C["boot"], 0.6), shade(C["boot"], 1.8), 0.0, 0.86)
    am.stitches(b, 0.0, 0.86, 1.0, 0.86, C["leather_hi"])             # the welt
    ap.weather(b, 0.30, C["dust"], seed=7, strength=0.45, flip=True)   # road dust at the foot
    if "strap" in R:                                                     # the agents' loose belt straps
        R["strap"].fill(C["leather"])
        R["strap"].vline(0.0, C["leather_hi"])
        am.stitches(R["strap"], 0.5, 0.0, 0.5, 1.0, C["leather_hi"], on=1, off=2)
        for v in (0.3, 0.6):
            R["strap"].hline(v, C["buckle"])                             # eyelets down the strap
    f = R["foot"]
    f.fill(shade(C["boot"], 1.0) * 0.6 + C["dust"] * 0.4)
    f.box(0.0, 0.0, 0.2, 1.0, C["sole"])
    f.box(0.8, 0.0, 1.0, 1.0, C["sole"])
    f.box(0.0, 0.0, 1.0, 0.1, C["sole"])
    R["belt"].fill(C["leather"])
    R["belt"].hline(0.15, C["leather_hi"])
    R["belt"].hline(0.8, C["leather_hi"])
    R["buckle"].fill(C["buckle"])
    R["buckle"].box(0.25, 0.25, 0.75, 0.75, C["plate_dk"])
    R["pouch"].fill(C["leather_hi"])
    R["pouch"].hline(0.7, C["leather"])


