"""What marks the Agency as a cult, and what hangs off its people (agent.py, lieutenant.py,
captain.py): the eye-in-a-ring mark painted in fat strokes at texel scale, stitch lines along
seams, dents and cracks in old plate, a ragged hem, rank bars, and the straps and hip plates
(tassets) that hang from a belt. Shapes are for a 1.72 m body (scaled by height).
"""
import math
import numpy as np
from mathutils import Vector
import body
import mesh
from agency_parts import at_z, box, shell


# ---------------------------------------------------------------- paint
def eye_mark(rect, u, v, rx, ry, ring, eye, pupil, stroke=2):
    """The cult mark: a single eye inside a ring. (u, v) is its centre on the block, rx / ry the
    ring's radii in texels (a block's texels are rarely square on the body), the strokes `stroke`
    texels fat so they survive the mipmaps. The eye is an almond in the ring's colour with a dark
    pupil; the gap between ring and eye keeps whatever is painted under it."""
    img = rect.atlas.img
    cx, cy = rect.px(u, v)
    r_min = float(min(rx, ry))
    s = stroke / r_min                      # the ring's thickness, as a fraction of the radius
    inner = 1.0 - s - 1.0 / r_min            # where the eye starts (one texel of gap inside the ring)
    for row in range(max(rect.y, cy - ry), min(rect.y + rect.h, cy + ry + 1)):
        for col in range(max(rect.x, cx - rx), min(rect.x + rect.w, cx + rx + 1)):
            dx, dy = (col - cx) / rx, (row - cy) / ry
            d = math.hypot(dx, dy)
            if d > 1.0:
                continue
            if d > 1.0 - s:
                img[row, col] = ring
            elif abs(dx) <= inner and abs(dy) <= inner * 0.55 * (1.0 - (dx / inner) ** 2) + 0.35 / ry:
                img[row, col] = pupil if d < inner * 0.42 else eye


def stitches(rect, u0, v0, u1, v1, color, on=2, off=2):
    """A dashed stitch line between two points of the block, horizontal or vertical."""
    img = rect.atlas.img
    x0, y0 = rect.px(u0, v0)
    x1, y1 = rect.px(u1, v1)
    if abs(x1 - x0) >= abs(y1 - y0):
        for k, col in enumerate(range(min(x0, x1), max(x0, x1) + 1)):
            if k % (on + off) < on:
                img[y0, col] = color
    else:
        for k, row in enumerate(range(min(y0, y1), max(y0, y1) + 1)):
            if k % (on + off) < on:
                img[row, x0] = color


def dents(rect, dark, light, count=4, seed=3, v_range=(0.1, 0.9)):
    """Old dents knocked into plate: a dark hollow two or three texels wide with a lit lip under it."""
    rng = np.random.RandomState(seed)
    img = rect.atlas.img
    for _ in range(count):
        c, r = rect.px(rng.uniform(0.06, 0.9), rng.uniform(*v_range))
        w = int(rng.randint(2, 4))
        c1 = min(rect.x + rect.w, c + w)
        img[r, c:c1] = dark
        if r + 1 < rect.y + rect.h:
            img[r + 1, c:c1] = dark
        if r + 2 < rect.y + rect.h:
            img[r + 2, c + 1:c1] = light


def crack(rect, u, v0, v1, color, seed=5):
    """A jagged crack running down the block from v1 to v0, wandering a texel each row."""
    rng = np.random.RandomState(seed)
    img = rect.atlas.img
    col, r1 = rect.px(u, v0)
    _, r0 = rect.px(u, v1)
    for row in range(r0, r1 + 1):
        img[row, col] = color
        col = min(rect.x + rect.w - 1, max(rect.x, col + int(rng.randint(-1, 2))))


def ragged_hem(rect, color, seed=1, notches=5, flip=False):
    """Notches torn out of a hem (the block's bottom edge, or its top with flip), painted in the
    colour of what is behind the cloth."""
    rng = np.random.RandomState(seed)
    img = rect.atlas.img
    for _ in range(notches):
        c = rect.x + int(rng.randint(1, max(2, rect.w - 4)))
        w, d = int(rng.randint(2, 4)), int(rng.randint(1, 3))
        rows = range(rect.y, rect.y + d) if flip else range(rect.y + rect.h - d, rect.y + rect.h)
        for row in rows:
            img[row, c:c + w] = color


def rank_bars(rect, u, v, count, color, w=0.05, gap=0.06):
    """Rank: short fat bars stacked on the right breast of the plate."""
    for k in range(count):
        rect.box(u - w, v - k * gap - 0.012, u + w, v - k * gap + 0.012, color)


# ---------------------------------------------------------------- geometry
def _skirt_point(J, skirt, th, z, off):
    """A point `off` outside the skirt's surface at angle th (0 = his right, 90 = front) and height z."""
    s = J["height"] / 1.72
    rx, ryf, ryb, n = at_z(skirt, z)
    ring = {"c": Vector((0, 0, z * s)), "x": Vector((1, 0, 0)), "y": body.FWD, "rx": rx * s, "ry": ryf * s,
            "ryb": ryb * s, "n": n}
    p = mesh.ring_point(ring, th)
    out = p - ring["c"]
    out.z = 0.0
    return p + out.normalized() * off * s, out.normalized()


def _skirt_w(z, leg):
    k = 0.9 * max(0.0, min(1.0, (0.95 - z) / 0.40)) ** 0.6   # 0 at the belt, 0.9 at the knee
    return {"Hips": 1 - k, leg: k} if k > 0 else {"Hips": 1.0}


def hanging_strap(part, J, rect, skirt, th, z0, z1, buckle=None, width=0.02, sway=0.0, leg="UpperLeg_L"):
    """A loose strap hanging from the belt down the skirt at angle th, flat against the cloth and
    standing a little off it, with a buckle plate at its end. It rides the hip, then the thigh."""
    s = J["height"] / 1.72
    n = 4
    pts, outs = [], []
    for k in range(n):
        f = k / (n - 1)
        z = z0 + (z1 - z0) * f
        p, out = _skirt_point(J, skirt, th + sway * f, z, 0.014 + 0.006 * f)
        pts.append(p)
        outs.append(out)
    mesh.strand(part, pts, [width * s] * n, 0.18, rect.uv, lambda f: _skirt_w(z0 + (z1 - z0) * f, leg),
                up=outs[0], sides=4)
    if buckle is not None:
        d = (pts[-1] - pts[-2]).normalized()
        side = d.cross(outs[-1]).normalized()
        box(part, pts[-1] - d * 0.012 * s, (0.012 * s, 0.004 * s, 0.014 * s), buckle, _skirt_w(z1, leg),
            (side, outs[-1], d))


def tassets(P, J, rect, lining, skirt, z0=0.80, z1=0.955, half=30):
    """A plate hanging off the belt over the right hip (mirror it for the left), standing off the
    skirt and flaring out at its foot."""
    s = J["height"] / 1.72
    rows = []
    for z in (z0, z0 + 0.05, z1):
        rx, ryf, ryb, n = at_z(skirt, z)
        off = 0.012 + 0.012 * (z1 - z) / (z1 - z0)
        rows.append((z, rx + off, ryf + off, ryb + off, n))
    shell(P, J, rect, rows, segs=6, thickness=0.006 * s, lining=lining, arcs=[(-half, half)] * len(rows),
          weights=lambda z: _skirt_w(z, "UpperLeg_R"))
