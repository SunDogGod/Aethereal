"""Aeneas's travel gear for the first arc: the poncho (with its hood down and a ragged hem), the
rifle sling over it, and the knife's sheath at the small of his back.

The poncho is its own skinned object ("Poncho" in Godot), so the game can switch it off (see
scripts/aeneas_outfit.gd) and later arcs show the jacket underneath. It is modelled over the rest
pose (arms 45 degrees out): over the shoulders and upper arms it leans out along the arm and is
weighted to it, so when his arms come down the sides hang with them, and when he swings they lift.
The front and back panels follow the torso exactly like the jacket under them (same weights).
"""
import math
from mathutils import Vector
import body
import mesh
from isabella_parts import sheet
from paint import shade

Z_NECK = 1.468
# The shape the poncho hangs from: (z, half width, front, back, squareness), for a 1.72 m body.
PROFILE = [(0.84, 0.236, 0.172, 0.178, 2.4), (0.95, 0.233, 0.166, 0.174, 2.4), (1.05, 0.230, 0.160, 0.170, 2.4),
           (1.15, 0.234, 0.152, 0.162, 2.4), (1.25, 0.238, 0.146, 0.154, 2.5), (1.32, 0.232, 0.136, 0.144, 2.6),
           (1.37, 0.212, 0.120, 0.128, 2.6), (1.41, 0.160, 0.102, 0.108, 2.4), (1.445, 0.108, 0.090, 0.095, 2.2),
           (1.468, 0.098, 0.086, 0.092, 2.0)]
ROWS = [0.0, 0.14, 0.30, 0.46, 0.61, 0.74, 0.85, 0.93, 1.0]   # hem (0) to neck (1)
COLS = 40
# Torn hem: how much lower than the line each column hangs (repeats round the poncho).
TEARS = [0.0, 0.022, 0.006, 0.030, 0.012, 0.0, 0.026, 0.008, 0.018, 0.034, 0.004, 0.015]


def _smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def hem_z(th):
    """Where the hem is at angle th (0 = his right, 90 = front, 180 = left, 270 = back): just
    above the belt in front (so the sword hilt and his hands stay clear), up to the elbows at
    the sides, down to a point over the small of his back."""
    sn = math.sin(math.radians(th))
    return 1.165 - 0.155 * max(0.0, sn) ** 1.3 - 0.30 * max(0.0, -sn) ** 1.6


def point(J, th, z, lift=0.0):
    """A point on the poncho (theta, height for a 1.72 m body, pushed out by lift) and its bone
    weights. Shared by the cloth, the hood and the sling so they move together."""
    s = J["height"] / 1.72
    p = body.trunk_point(J, PROFILE, th, z, lift)
    c = math.cos(math.radians(th))
    side = max(0.0, abs(c) - 0.45) / 0.55              # 1 right at his side
    # Over the arm (rest pose: 45 degrees out) the cloth leans out to lie on top of it.
    need = 0.235 + max(0.0, 1.397 - z) + lift
    lean = side ** 1.2 * max(0.0, need - abs(p.x) / s) if z < 1.40 else 0.0
    p = p + Vector((math.copysign(lean * s, c), 0.0, 0.0))
    sh_z = J["shoulder"].z / s
    below = max(0.0, sh_z + 0.03 - z) / 0.12
    reach = max(0.0, abs(c) - 0.28) / 0.72          # the arm's pull reaches wider than the lean
    k_sh = reach * 0.5 * (1 - min(1.0, below))
    k_arm = reach * 0.72 * _smooth(below)
    front = max(0.0, math.sin(math.radians(th)))
    k_leg = 0.3 * front * _smooth((1.07 - z) / 0.1)     # the front hem rides up on raised thighs
    w = {b: v * (1 - k_sh - k_arm - k_leg) for b, v in body.spine_w(J, z * s).items()}
    sn = "_R" if c > 0 else "_L"
    if k_sh > 0:
        w["Shoulder" + sn] = k_sh
    if k_arm > 0:
        w["UpperArm" + sn] = k_arm
    if k_leg > 0:
        right = min(1.0, max(0.0, 0.5 + 0.8 * c))
        for leg, share in (("R", right), ("L", 1 - right)):
            if share > 0:
                w["UpperLeg_" + leg] = w.get("UpperLeg_" + leg, 0.0) + k_leg * share
    return p, w


def poncho(P, J, r, lining):
    """The cloth: a closed tube of COLS columns (starting at the front, going to his left) and
    ROWS rows, with an inside and a rim at the hem and the neck."""
    s = J["height"] / 1.72
    grid, wts = [], []
    for i, f in enumerate(ROWS):
        prow, wrow = [], []
        for j in range(COLS):
            th = 90.0 + 360.0 * j / COLS
            h = hem_z(th) - (TEARS[j % len(TEARS)] if i == 0 else 0.0)
            z = h + (Z_NECK - h) * f
            p, w = point(J, th, z, 0.010 + 0.006 * (1 - f))
            prow.append(p)
            wrow.append(w)
        grid.append(prow)
        wts.append(wrow)
    _closed_sheet(P, grid, wts, r.uv, lining.uv, 0.006 * s)


def _closed_sheet(part, grid, wts, uv, lining, thick):
    """Like isabella_parts.sheet, but the columns close into a ring (the last joins the first)."""
    rows, cols = len(grid), len(grid[0])
    out = [[part.vert(grid[i][j], wts[i][j]) for j in range(cols)] for i in range(rows)]
    inn = [[part.vert(grid[i][j] - Vector((grid[i][j].x, grid[i][j].y, 0)).normalized() * thick, wts[i][j])
            for j in range(cols)] for i in range(rows)]
    u0, v0, u1, v1 = uv
    U = [u0 + (u1 - u0) * j / cols for j in range(cols + 1)]
    V = [v0 + (v1 - v0) * i / (rows - 1) for i in range(rows)]
    lu = ((lining[0] + lining[2]) / 2, (lining[1] + lining[3]) / 2)
    for i in range(rows - 1):
        for j in range(cols):
            k = (j + 1) % cols
            part.face((out[i][j], out[i][k], out[i + 1][k], out[i + 1][j]),
                      [(U[j], V[i]), (U[j + 1], V[i]), (U[j + 1], V[i + 1]), (U[j], V[i + 1])])
            part.face((inn[i + 1][j], inn[i + 1][k], inn[i][k], inn[i][j]), [lu] * 4)
    hem = (U[0], V[0])
    for j in range(cols):
        k = (j + 1) % cols
        part.face((out[0][j], inn[0][j], inn[0][k], out[0][k]), [hem] * 4, False)
        part.face((out[-1][k], inn[-1][k], inn[-1][j], out[-1][j]), [lu] * 4, False)


def hood(P, J, r):
    """The hood, down: a soft fold lying on his upper back, its point between the shoulder
    blades and its rolled edge round the back of the neck."""
    s = J["height"] / 1.72
    cols, fs = 15, [0.0, 0.25, 0.5, 0.75, 0.9, 1.0]
    grid, wts = [], []
    for f in fs:
        prow, wrow = [], []
        for j in range(cols):
            th = 200.0 + 140.0 * j / (cols - 1)
            a = abs(th - 270.0) / 70.0                # 0 at the middle of the back, 1 at the ends
            bottom = 1.25 + 0.17 * a ** 1.4
            top = Z_NECK + 0.012 - 0.01 * a
            z = bottom + (top - bottom) * f
            puff = (0.012 + 0.030 * math.sin(math.pi * min(1.0, f * 1.15))) * (1 - 0.75 * a ** 3)
            p, w = point(J, th, z, 0.016 + puff)
            if f > 0.85:   # the roll tucks in toward the neck
                p = p + (Vector((0, 0, z * s)) - Vector((p.x, p.y, z * s))) * 0.06 * (f - 0.85) / 0.15
            prow.append(p)
            wrow.append(w)
        grid.append(prow)
        wts.append(wrow)
    sheet(P, grid, wts, r.uv, r.uv, 0.005 * s)


def sling(P, J, r):
    """The rifle sling over the poncho: over the right shoulder, across the chest, and under the
    hem on his left."""
    path = [(16, 1.425), (40, 1.37), (66, 1.29), (92, 1.20), (116, 1.12), (130, hem_z(130) + 0.03)]
    pts, ws = [], []
    for th, z in path:
        p, w = point(J, th, z, 0.024)
        pts.append(p)
        ws.append(w)
    body_w = lambda k: ws[min(len(ws) - 1, int(round(k * (len(ws) - 1))))]
    body.strand(P, pts, [0.020] * (len(pts) - 1) + [0.018], 0.28, r.uv, body_w, up=Vector((0, 1, 0.2)), sides=4)


def knife_sheath(P, J, r, belt, brass):
    """The knife's sheath across the small of his back, along the Knife bone (rig.py)."""
    s = J["height"] / 1.72
    h = Vector((-0.115 * s, -0.128 * s, 0.965 * s))
    d = Vector((1.0, 0.0, -0.12)).normalized()
    x, y = mesh.frame_along(d, (0, -1, 0))
    rings = []
    for t, rx, ry in ((0.045, 0.021, 0.010), (0.06, 0.023, 0.011), (0.20, 0.017, 0.009), (0.235, 0.008, 0.006)):
        rings.append({"c": h + d * t * s, "x": x, "y": y, "rx": rx * s, "ry": ry * s, "n": 2.4, "w": {"Hips": 1.0}})
    mesh.loft(P, rings, 6, r.uv, cap0="pole", cap1="pole")
    r.fill(belt)
    r.box(0, 0.85, 1, 1.0, brass)
    r.hline(0.4, shade(belt, 1.4))


def paint_poncho(r, hood_r, lining, C):
    """Dusty, sun-faded cloth: two stripe bands, a darker grimy hem with a fringe, a patch."""
    base, dark, rust, bone = C["poncho"], C["poncho_dk"], C["poncho_band"], C["poncho_line"]
    r.vgrad(shade(base, 0.78), shade(base, 1.06))       # grime low, faded high
    r.box(0, 0.0, 1, 0.045, shade(dark, 0.9))           # the hem, dirtiest
    img = r.atlas.img
    for x in range(r.w):                                # fringe threads
        if x % 2 == 0:
            img[r.y + r.h - 3:r.y + r.h, r.x + x] = shade(dark, 0.7)
    r.hline(0.11, bone)
    r.box(0, 0.125, 1, 0.19, rust)
    r.hline(0.205, bone)
    for k in range(16):                                 # small stepped marks in the band
        u = (k + 0.5) / 16
        r.box(u - 0.006, 0.145, u + 0.006, 0.17, shade(bone, 0.9))
    r.hline(0.80, rust)
    r.hline(0.835, bone)
    # A patch sewn on the back (the back is the middle of the block), and a mended tear.
    r.box(0.555, 0.34, 0.615, 0.47, shade(C["patch"], 1.0))
    for v in (0.34, 0.47):
        r.box(0.555, v, 0.615, v, shade(dark, 0.75))    # the patch's stitched border
    r.vline(0.555, shade(dark, 0.75), 1, 0.34, 0.47)
    r.vline(0.614, shade(dark, 0.75), 1, 0.34, 0.47)
    r.vline(0.30, shade(dark, 0.85), 1, 0.25, 0.33)
    hood_r.vgrad(shade(base, 0.92), shade(base, 1.04))
    hood_r.box(0, 0.86, 1, 1.0, shade(dark, 0.85))      # the rolled edge shows the darker inside
    hood_r.hline(0.08, shade(dark, 0.9))
    lining.fill(shade(base, 0.62))
