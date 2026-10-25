"""The shapes Isabella's look script (isabella.py) builds her from that the shared helpers don't
have: a robe skirt her legs carry, a shawl panel, raised collar bands, a sleek hair shell, a bun,
the obi knot, and her face paint. Colours and shape tables live in isabella.py; change them there.
"""
import math
from mathutils import Vector
import body
import mesh
from paint import rgb, shade


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def paint_tz(rect, z0, z1, fn):
    """Paints a trunk-style block by angle (90 = front, 0 = her right) and height (1.72 m units):
    fn(angle, height) returns a colour (or None to leave the pixel)."""
    img = rect.atlas.img
    for col in range(rect.w):
        th = (col + 0.5) / rect.w * 360.0 - 90.0
        for row in range(rect.h):
            c = fn(th, z0 + (1 - (row + 0.5) / rect.h) * (z1 - z0))
            if c is not None:
                img[rect.y + row, rect.x + col] = c


# ---------------------------------------------------------------- face and hair
def paint_face(head, r, C):
    """Her face on the head block: almond eyes under calm, slightly lowered lids, fine arched
    brows, a soft mouth."""
    img = r.atlas.img
    def at(th, z):
        return r.px(*head.uv(th, z))
    white, lash = rgb("#f1ebe2"), shade(C["eye"], 0.45)
    for side in (1, -1):
        th = 90 + 21 * side
        x0, y0 = at(th - 7.5 * side, 0.100)
        x1, _ = at(th + 7.5 * side, 0.100)
        lo, hi = min(x0, x1), max(x0, x1)
        inner, outer = (lo, hi) if side == 1 else (hi, lo)
        img[y0 - 1:y0 + 2, lo + 1:hi] = white                  # the white, 3 rows
        img[y0, lo:hi + 1] = white
        ix, _ = at(th - 1.5 * side, 0.100)
        img[y0 - 1:y0 + 2, ix - 1:ix + 2] = C["iris"]           # the iris, its top under the lid
        img[y0:y0 + 2, ix:ix + 1] = shade(C["eye"], 0.5)
        img[y0, ix + side] = rgb("#f6f1e8")                     # a glint
        img[y0 - 2, lo:hi + 1] = lash                           # the upper lash line
        o = outer + side
        img[y0 - 3, min(o, outer - 2 * side):max(o, outer - 2 * side) + 1] = lash   # thicker, lifting outward
        img[y0 - 4, o + side] = lash
        img[y0 + 2, min(inner, outer) + 2:max(inner, outer)] = shade(C["skin"], 0.86)   # lower lid
        img[y0 - 4, lo + 1:hi] = shade(C["skin"], 0.9)          # the lid crease
        # A fine brow, arched, highest about two thirds of the way out.
        bx0, by0 = at(90 + 12 * side, 0.127)
        bx1, by1 = at(90 + 33 * side, 0.121)
        n = abs(bx1 - bx0)
        for k in range(n + 1):
            t = k / max(1, n)
            y = round(by0 + (by1 - by0) * t - 2.2 * math.sin(math.pi * min(1.0, t * 1.2)))
            img[y:y + (2 if t < 0.35 else 1), bx0 + (k if bx1 > bx0 else -k)] = C["brow"]
    mx0, my = at(90 - 7, 0.043)
    mx1, _ = at(90 + 7, 0.043)
    lo, hi = min(mx0, mx1), max(mx0, mx1)
    img[my, lo:hi + 1] = shade(C["lip"], 0.72)                    # where the lips meet
    img[my - 1, lo + 2:hi - 1] = C["lip"]                         # upper lip
    img[my + 1, lo + 1:hi] = shade(C["lip"], 1.15)               # fuller lower lip
    img[my + 2, lo + 3:hi - 2] = shade(C["skin"], 0.9)
    nx0, ny = at(90 - 4, 0.064)
    nx1, _ = at(90 + 4, 0.064)
    img[ny, min(nx0, nx1):max(nx0, nx1) + 1] = shade(C["skin"], 0.84)   # under the nose


def hair_shell(P, head, rect, hair_line, hair, sheen):
    """The hair's volume: rows from the hairline (on the skin, closing the edge) up to the crown,
    a little proud of the head, with a groove along the parting. Painted with strands sweeping
    back from the parting to the nape (darker grooves) and a soft sheen."""
    cols = 28
    rows = [(0.0, 0.0), (0.0, 0.009), (0.25, 0.012), (0.5, 0.013), (0.75, 0.012), (0.93, 0.010)]
    z_top = 0.226
    grid = []
    for f, lift in rows:
        row = []
        for j in range(cols):
            th = 90.0 + 360.0 * j / cols
            z0 = hair_line(th)
            groove = 1.0 - (0.55 if (j == 0 and f > 0.1) else 0.0)
            row.append(P.vert(head.surface(th, z0 + (z_top - z0) * f, lift * groove), {"Head": 1.0}))
        grid.append(row)
    pole = P.vert(head.ring(len(head.rows) - 1)["c"] + Vector((0, 0, 0.018 * head.s)), {"Head": 1.0})
    u0, v0, u1, v1 = rect.uv
    U = [u0 + (u1 - u0) * j / cols for j in range(cols + 1)]
    V = [v0 + (v1 - v0) * k / (len(rows)) for k in range(len(rows) + 1)]
    for i in range(len(rows) - 1):
        for j in range(cols):
            a, b = grid[i][j], grid[i][(j + 1) % cols]
            c, d = grid[i + 1][(j + 1) % cols], grid[i + 1][j]
            P.face((a, b, c, d), [(U[j], V[i]), (U[j + 1], V[i]), (U[j + 1], V[i + 1]), (U[j], V[i + 1])])
    for j in range(cols):
        P.face((grid[-1][j], grid[-1][(j + 1) % cols], pole),
               [(U[j], V[-2]), (U[j + 1], V[-2]), ((U[j] + U[j + 1]) / 2, V[-1])])
    img = rect.atlas.img
    rect.fill(hair)
    fs = [f for f, _ in rows] + [1.0]
    for col in range(rect.w):
        th = 90.0 + 360.0 * (col + 0.5) / rect.w
        a = abs(((th - 90) + 180) % 360 - 180)
        q = (a / 180.0) ** 0.8
        for row in range(rect.h):
            k = (1 - (row + 0.5) / rect.h) * len(rows)          # rows sit at v = k / len(rows)
            i = min(int(k), len(rows) - 1)
            f = fs[i] + (fs[i + 1] - fs[i]) * (k - i)
            z0 = hair_line(th)
            z = z0 + (z_top - z0) * f
            if 0.5 < f < 0.72 and a < 100:
                img[rect.y + row, rect.x + col] = sheen
            if q < 0.93:
                zs = (z - 0.07 * q) / (1 - q)                     # which strand line this is on
                if ((zs - 0.12) / 0.05) % 1.0 < 0.15:
                    img[rect.y + row, rect.x + col] = shade(hair, 0.62)


def bun_and_pin(P, head, bun_uv, pin_uv, bead_uv):
    """A soft ball of hair at the nape (a loft heading backwards) with a pin through it: a thin
    stick from upper right to lower left and a bead on its upper end."""
    hs = head.s * head.k
    c0 = head.surface(270, 0.072, 0.0)
    back, up, right = Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0))
    rings = [{"c": c0 + back * d * hs, "x": right, "y": up, "rx": rx * hs, "ry": rz * hs, "n": 2.2,
              "w": {"Head": 1.0}} for d, rx, rz in ((-0.012, 0.040, 0.034), (0.008, 0.056, 0.047),
                                                     (0.030, 0.060, 0.051), (0.050, 0.050, 0.043),
                                                     (0.064, 0.030, 0.027))]
    rings[-1]["cap_len"] = 0.008 * hs
    mesh.loft(P, rings, 12, bun_uv, cap1="pole")
    mid = c0 + back * 0.03 * hs
    a_end, b_end = mid + Vector((0.085, -0.012, 0.045)) * hs, mid + Vector((-0.07, -0.006, -0.03)) * hs
    mesh.strand(P, [a_end, mid, b_end], [0.0045 * hs, 0.0045 * hs, 0.003 * hs], 1.0, pin_uv, {"Head": 1.0}, sides=4)
    d = (a_end - b_end).normalized()
    mesh.strand(P, [a_end - d * 0.004, a_end + d * 0.008 * hs, a_end + d * 0.02 * hs],
                [0.007 * hs, 0.010 * hs, 0.0], 1.0, bead_uv, {"Head": 1.0}, sides=5)


# ---------------------------------------------------------------- the robe
def skirt_w(J, th, z, z_hem):
    """Skirt weights: the hips at the top, then more and more of the thigh on that side (the
    middle of the front and back shares both), and toward the hem a little of the shin."""
    zh, zk = J["hips"].z, J["knee"].z
    if z >= zh:
        return body.spine_w(J, z)
    k = 0.8 * smooth((zh - z) / (zh - zk))
    right = min(1.0, max(0.0, 0.5 + 0.8 * math.cos(math.radians(th))))
    low = 0.35 * smooth((zk - z) / (zk - z_hem)) if z < zk else 0.0
    w = {"Hips": 1.0 - k}
    for side, share in (("R", right), ("L", 1.0 - right)):
        if share > 0:
            w["UpperLeg_" + side] = k * share * (1 - low)
            if low > 0:
                w["LowerLeg_" + side] = k * share * low
    return w


def skirt(P, J, profile, rect, lining):
    """The robe below the obi (profile rows hem first), and a lining inside the hem so the skirt
    isn't see-through from a low angle."""
    s = J["height"] / 1.72
    z_hem = profile[0][0] * s
    def ring(z, rx, ryf, ryb, n, inset=0.0, flip=False):
        zz = z * s
        # Inside (flip): mirrored x turns the faces inward, so an angle th lands where 180 - th is.
        wf = (lambda th: skirt_w(J, 180 - th, zz, z_hem)) if flip else (lambda th: skirt_w(J, th, zz, z_hem))
        return {"c": Vector((0, 0, zz)), "x": Vector((-1 if flip else 1, 0, 0)), "y": body.FWD,
                "rx": (rx - inset) * s, "ry": (ryf - inset) * s, "ryb": (ryb - inset) * s, "n": n,
                "w": wf(90), "wf": wf}
    mesh.loft(P, [ring(*row) for row in profile], 22, rect.uv)
    mesh.loft(P, [ring(*row, inset=0.006, flip=True) for row in profile[:4]], 22, lining.uv)


def band(P, J, profile, path, width, thick, uv, lift, inner=None):
    """A flat strip lying on a trunk profile along (angle, height) points: a collar edge. inner =
    (side, uv, lowest z): a narrower strip beside it on that side, down to that height."""
    s = J["height"] / 1.72
    pts = [body.trunk_point(J, profile, th, z, lift) for th, z in path]
    rings, cream = [], []
    for k, (th, z) in enumerate(path):
        p = pts[k]
        t = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
        n = Vector((p.x, p.y, 0)).normalized()
        n = (n - t * n.dot(t)).normalized()
        x = n.cross(t)
        w = body.spine_w(J, z * s)
        rings.append({"c": p + n * thick * 0.5 * s, "x": x, "y": n, "rx": width * 0.707 * s,
                      "ry": thick * 0.707 * s, "n": 2.0, "w": w})
        if inner and z >= inner[2] - 0.005:
            off = inner[0] * (width * 0.5 + 0.007) * s
            cream.append({"c": p + x * off + n * thick * 0.3 * s, "x": x, "y": n, "rx": 0.014 * 0.707 * s,
                          "ry": thick * 0.5 * s, "n": 2.0, "w": w})
    mesh.loft(P, rings, 4, uv, start=45.0, cap0="pole", cap1="pole")
    if len(cream) > 1:
        mesh.loft(P, cream, 4, inner[1], start=45.0, cap0="pole", cap1="pole")


def knot(P, J, rect):
    """The obi's flat knot at the small of her back (a padded box, wider than tall)."""
    s = J["height"] / 1.72
    zc, y0 = 1.045 * s, -0.098 * s
    back, up, right = Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0))
    rings = [{"c": Vector((0, y0, zc)) + back * d * s, "x": right, "y": up, "rx": rx * s, "ry": rz * s, "n": 4.0,
              "w": body.spine_w(J, zc)} for d, rx, rz in ((0.0, 0.112, 0.074), (0.020, 0.128, 0.082),
                                                         (0.034, 0.122, 0.078))]
    rings[-1]["cap_len"] = 0.006 * s
    mesh.loft(P, rings, 12, rect.uv, cap1="pole")


def shawl(P, J, profile, rect, lining):
    """A grid of points: columns go round her from the inner edge of the left front end, across
    the back, to the inner edge of the right one; rows from the hem up to the neck. It hugs
    `profile`, leans out over the upper arms, and those flaps follow the arms."""
    s = J["height"] / 1.72
    sh_z = J["shoulder"].z / s
    cols, rows = 33, 6
    def edge_z(th):   # where the hem is, column by column
        a = abs(th - 270.0)                    # 0 = the back, 152 = the front ends
        if a <= 70:
            return 1.115 + 0.185 * a / 70      # down to a point at the back
        if a <= 98:
            return 1.30                        # over the shoulder and upper arm
        return 1.30 - 0.18 * ((a - 98) / 54) ** 0.8   # the front ends: a slant down to the obi
    grid, wts = [], []
    for i in range(rows):
        f = i / (rows - 1)
        prow, wrow = [], []
        for j in range(cols):
            th = 118.0 + 304.0 * j / (cols - 1)
            z = edge_z(th) + (1.442 - edge_z(th)) * f
            p = body.trunk_point(J, profile, th, z, 0.010 + 0.012 * (1 - f))
            c = math.cos(math.radians(th))
            side = max(0.0, abs(c) - 0.45) / 0.55          # 1 right at her side
            below = max(0.0, sh_z + 0.03 - z) / 0.12       # how far down the arm
            # Over the arm (rest pose: arms 45 degrees out) the shawl leans out along it.
            p = p + Vector((math.copysign(1, c), 0, 0)) * side * min(1.0, below) * 0.07 * s
            w = dict(body.spine_w(J, z * s))
            sname = "_R" if c > 0 else "_L"
            k_sh = side * 0.5 * (1 - min(1.0, below))
            k_arm = side * 0.85 * smooth(below)
            w = {b: v * (1 - k_sh - k_arm) for b, v in w.items()}
            if k_sh > 0:
                w["Shoulder" + sname] = k_sh
            if k_arm > 0:
                w["UpperArm" + sname] = k_arm
            prow.append(p)
            wrow.append(w)
        grid.append(prow)
        wts.append(wrow)
    sheet(P, grid, wts, rect.uv, lining.uv, 0.005 * s)


def sheet(part, grid, wts, uv, lining, thick):
    """A cloth panel with a little thickness: the outside, the inside (lining uv) and the rims.
    grid[row][column]: rows bottom to top, columns left to right seen from outside."""
    rows, cols = len(grid), len(grid[0])
    out = [[part.vert(grid[i][j], wts[i][j]) for j in range(cols)] for i in range(rows)]
    inn = [[part.vert(grid[i][j] - Vector((grid[i][j].x, grid[i][j].y, 0)).normalized() * thick, wts[i][j])
            for j in range(cols)] for i in range(rows)]
    u0, v0, u1, v1 = uv
    U = [u0 + (u1 - u0) * j / (cols - 1) for j in range(cols)]
    V = [v0 + (v1 - v0) * i / (rows - 1) for i in range(rows)]
    lu = ((lining[0] + lining[2]) / 2, (lining[1] + lining[3]) / 2)
    for i in range(rows - 1):
        for j in range(cols - 1):
            part.face((out[i][j], out[i][j + 1], out[i + 1][j + 1], out[i + 1][j]),
                      [(U[j], V[i]), (U[j + 1], V[i]), (U[j + 1], V[i + 1]), (U[j], V[i + 1])])
            part.face((inn[i + 1][j], inn[i + 1][j + 1], inn[i][j + 1], inn[i][j]), [lu] * 4)
    rim = (U[0], V[0])
    for i in range(rows - 1):
        o0, o1, i0, i1 = out[i][0], out[i + 1][0], inn[i][0], inn[i + 1][0]
        part.face((o1, o0, i0, i1), [rim] * 4, False)
        o0, o1, i0, i1 = out[i][-1], out[i + 1][-1], inn[i][-1], inn[i + 1][-1]
        part.face((o0, o1, i1, i0), [rim] * 4, False)
    for j in range(cols - 1):
        o0, o1, i0, i1 = out[0][j], out[0][j + 1], inn[0][j], inn[0][j + 1]
        part.face((o0, i0, i1, o1), [rim] * 4, False)
        o0, o1, i0, i1 = out[-1][j], out[-1][j + 1], inn[-1][j], inn[-1][j + 1]
        part.face((o1, i1, i0, o0), [rim] * 4, False)
