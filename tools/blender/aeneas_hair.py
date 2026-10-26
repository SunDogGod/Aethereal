"""Aeneas's haircut: short cropped sides and back, a longer swept top with a fringe falling over
his forehead to his left from a side parting on his right, and a thin tied tail at the nape.

Three pieces, all on the Head bone (the tail follows the neck and chest):
  cap()     the volume: a shell from the hairline to the crown. It hugs the skull below LEDGE
            (the short sides) and stands proud above it (the long top), so the cut shows as a step
            in his silhouette, which is what reads from the camera behind him.
  locks     chunky clumps on top of the shell: the fringe (FRINGE), the long top falling back over
            the ledge at the sides and back (TOP), a cowlick at the crown.
  tail()    the thin tail, tied near the root, ending in a small brush.
Each lock is a path of (angle round the head, height, lift) points, root first: angle 90 = his
face, 0 = his right, 180 = his left, 270 = the back; height in metres above the head joint (the
crown is 0.23, brows 0.12); lift = how far it stands above the shell there. Wider widths = fatter lock.
"""
import math
from mathutils import Vector
import body
from paint import shade

LEDGE = 0.168      # height where the short sides stop and the long top begins (at the temples)
LEDGE_BACK = 0.146 # ...and at the back of his head, so the long top rounds the skull
Z_TOP = 0.229      # the crown (the last head row)
SHORT = 0.0035     # how far the cropped sides stand off the skin
W = [0.046, 0.054, 0.044, 0.0]   # a broad lock: root, middle, near the tip, the tip

# Lock paths: (angle, height, lift ABOVE the shell there), so a lock follows the shell's shape and
# only its middle stands proud; a small lift at the tip lets it overhang the ledge.
# The fringe: from the parting (his right, about 50 degrees) forward and down to his left.
FRINGE = [
    ([(56, 0.226, 0.004), (70, 0.204, 0.007), (82, 0.170, 0.006), (88, 0.138, 0.003)], W),
    ([(72, 0.228, 0.005), (88, 0.204, 0.008), (102, 0.166, 0.007), (110, 0.126, 0.003)], W),
    ([(92, 0.228, 0.005), (108, 0.206, 0.008), (122, 0.170, 0.007), (132, 0.136, 0.003)], W),
    ([(112, 0.226, 0.004), (128, 0.206, 0.007), (142, 0.178, 0.006), (150, 0.150, 0.003)], W),
    # a short lock on the other side of the parting, toward his right temple
    ([(46, 0.220, 0.003), (34, 0.204, 0.006), (24, 0.184, 0.006), (20, 0.168, 0.003)], [0.036, 0.042, 0.034, 0.0]),
]
# The long top falling back and down over the ledge at the sides and back (shingles).
TOP = [([(th, 0.226, 0.003), (th + 2 * d, 0.200, 0.005), (th + 4 * d, 0.168, 0.004), (th + 5 * d, 0.132, 0.002)], W)
       for th, d in ((228, 1), (256, 1), (284, -1), (312, -1))]
TOP += [
    ([(20, 0.224, 0.003), (2, 0.206, 0.006), (-14, 0.184, 0.005), (-22, 0.162, 0.003)], W),
    ([(160, 0.224, 0.003), (178, 0.206, 0.006), (194, 0.184, 0.005), (202, 0.162, 0.003)], W),
    ([(350, 0.226, 0.003), (338, 0.206, 0.006), (328, 0.184, 0.005), (322, 0.162, 0.003)], W),
    ([(190, 0.226, 0.003), (202, 0.206, 0.006), (212, 0.184, 0.005), (218, 0.162, 0.003)], W),
]
# A cowlick standing up at the crown, pointing back.
CROWN = [([(266, 0.229, 0.002), (272, 0.229, 0.012), (282, 0.214, 0.018), (288, 0.198, 0.012)], [0.032, 0.030, 0.022, 0.0])]


def ledge(theta):
    """Height of the ledge round the head: LEDGE at the sides and front, LEDGE_BACK at the back."""
    return LEDGE + (LEDGE_BACK - LEDGE) * max(0.0, -math.sin(math.radians(theta)))


def _smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


class Shape:
    """Points on Aeneas's head pushed out from its centre (so lift also works on the crown)."""

    def __init__(self, head, hairline):
        self.head, self.hairline, self.s = head, hairline, head.s
        self.c0 = Vector((0.0, -0.004 * head.s, head.z0 + 0.115 * head.s * head.k))

    def at(self, theta, z, lift):
        p = self.head.surface(theta, z, 0.0)
        return p + (p - self.c0).normalized() * lift * self.s

    def volume(self, theta):
        """How proud the long top stands: most at the front (the swept fringe), least at the back."""
        return 0.015 + 0.005 * math.cos(math.radians(theta - 90))

    def lift(self, theta, z):
        back = max(0.0, -math.sin(math.radians(theta)))   # at the back the long hair tapers into the crop
        lo, hi = ledge(theta) - 0.012 - 0.03 * back, ledge(theta) + 0.016 + 0.02 * back
        return SHORT + (self.volume(theta) - SHORT) * _smooth(lo, hi, z)

    def on(self, theta, z, extra):
        """A point `extra` above the shell (locks ride on it)."""
        return self.at(theta, z, self.lift(theta, z) + extra)


def cap(P, sh, rect, cols=28):
    """The shell. Row 0 sits just under the skin at the hairline (so the edge never floats); the
    rest climb to the crown. v in the texture is height, so the paint can mark the ledge."""
    head = sh.head
    fr = [0.0, 0.0, 0.10, 0.22, 0.36, 0.5, 0.64, 0.78, 0.9]
    z_lo = min(sh.hairline(th) for th in range(0, 360, 10))
    pole_c = head.ring(len(head.rows) - 1)["c"] + Vector((0, 0, (0.006 + 0.020) * sh.s))
    z_hi = (pole_c.z - head.z0) / sh.s

    def v_of(z):
        return (z - z_lo) / (z_hi - z_lo)
    grid, vs = [], []
    for i, f in enumerate(fr):
        row, vrow = [], []
        for j in range(cols):
            th = -90.0 + 360.0 * j / cols
            z0 = sh.hairline(th)
            z = z0 + (Z_TOP - z0) * f
            lift = -0.002 if i == 0 else sh.lift(th, z)
            row.append(P.vert(sh.at(th, z, lift), {"Head": 1.0}))
            vrow.append(v_of(z))
        grid.append(row)
        vs.append(vrow)
    pole = P.vert(pole_c, {"Head": 1.0})
    u0, v0, u1, v1 = rect.uv

    def uv(j, v):
        return (u0 + (u1 - u0) * j / cols, v0 + (v1 - v0) * min(1.0, max(0.0, v)))
    for i in range(len(fr) - 1):
        for j in range(cols):
            k = (j + 1) % cols
            P.face((grid[i][j], grid[i][k], grid[i + 1][k], grid[i + 1][j]),
                   [uv(j, vs[i][j]), uv(j + 1, vs[i][k]), uv(j + 1, vs[i + 1][k]), uv(j, vs[i + 1][j])])
    for j in range(cols):
        k = (j + 1) % cols
        P.face((grid[-1][j], grid[-1][k], pole), [uv(j, vs[-1][j]), uv(j + 1, vs[-1][k]), uv(j + 0.5, 1.0)])
    return v_of


def paint_cap(rect, v_of, C):
    """Cropped sides in the darker brown with short vertical strokes; above the ledge the long
    hair, with tufts biting down into the cropped part, grooves sweeping forward and a sheen."""
    img = rect.atlas.img
    hair, dark = C["hair"], C["hair_dark"]
    for col in range(rect.w):
        u = (col + 0.5) / rect.w
        th = -90.0 + 360.0 * u
        tuft = 0.022 * abs(((u * 18) % 1.0) - 0.5) * 2      # zigzag: tufts pointing down
        for row in range(rect.h):
            v = 1 - (row + 0.5) / rect.h
            if v < v_of(ledge(th)) - 0.03 + tuft:
                c = dark if (col + row // 3) % 4 else shade(dark, 0.86)   # crisp short strokes
            else:
                c = hair
                groove = ((u * 14 + v * 1.6) % 1.0)                          # strands sweeping forward
                if groove < 0.14:
                    c = shade(hair, 0.74)
                elif 0.62 < v < 0.8 and abs(math.sin(math.radians(th))) > 0.2 and groove > 0.55:
                    c = shade(hair, 1.32)                                    # sheen band on top
            img[rect.y + row, rect.x + col] = c


def paint_lock(rect, C):
    """A lock's texture: u runs round it (0.5 = its outer face), v root to tip."""
    hair = C["hair"]
    rect.fill(hair)
    rect.box(0.0, 0.0, 0.18, 1.0, shade(hair, 0.72))     # the underside
    rect.box(0.82, 0.0, 1.0, 1.0, shade(hair, 0.72))
    rect.vline(0.36, shade(hair, 0.8), 1, 0.1, 0.9)       # a groove splitting the clump
    rect.box(0.48, 0.35, 0.62, 0.75, shade(hair, 1.3))   # the sheen on its outer face
    rect.box(0.0, 0.0, 1.0, 0.08, shade(hair, 0.78))     # the root, in shadow


def locks(P, sh, rect):
    for path, widths in FRINGE + TOP + CROWN:
        pts = [sh.on(th, z, extra) for th, z, extra in path]
        up = (pts[0] - sh.c0).normalized()
        body.strand(P, pts, [w * sh.s for w in widths], 0.42, rect.uv, {"Head": 1.0}, up=up, sides=5)


def tail(P, sh, rect, C):
    """The thin tail: from the nape between the shoulder blades, a tie near the root, a brush tip."""
    s = sh.s
    nape = sh.at(270, 0.07, 0.006)
    offs = [(0, 0, 0), (0, -0.020, -0.03), (0, -0.040, -0.075), (0, -0.050, -0.125), (0.004, -0.054, -0.17),
            (0.006, -0.054, -0.20)]
    pts = [nape + Vector(o) * s for o in offs]

    def w(k):
        return {"Head": 1.0} if k < 0.25 else ({"Head": 0.4, "Neck": 0.6} if k < 0.6 else {"Neck": 0.4, "Chest": 0.6})
    widths = [0.012 * s, 0.010 * s, 0.009 * s, 0.011 * s, 0.009 * s, 0.0]
    body.strand(P, pts, widths, 0.8, rect.uv, w, up=Vector((0, -1, 0)), sides=6)
    rect.fill(C["hair"])
    rect.box(0.0, 0.10, 1.0, 0.22, C["tie"])              # the tie (v runs root to tip)
    rect.hline(0.10, shade(C["tie"], 0.7))
    rect.vline(0.5, shade(C["hair"], 1.25), 1, 0.25, 0.95)
    rect.box(0.0, 0.85, 1.0, 1.0, shade(C["hair"], 1.15))  # the brush end, lighter


def build(P, head, A, hairline, C):
    """Adds the whole haircut to part P. A is the atlas (reserves its own blocks)."""
    sh = Shape(head, hairline)
    r_cap, r_lock, r_tail = A.rect("hair_cap", 64, 32), A.rect("hair", 32, 32), A.rect("hair_tail", 8, 24)
    v_of = cap(P, sh, r_cap)
    paint_cap(r_cap, v_of, C)
    locks(P, sh, r_lock)
    paint_lock(r_lock, C)
    tail(P, sh, r_tail, C)
