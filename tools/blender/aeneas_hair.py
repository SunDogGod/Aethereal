"""Aeneas's haircut (after Jim Hawkins): the sides and back buzzed short (an undercut), a longer top
swept back over the crown, a heavy fringe swept across his forehead from a parting on his left so
it falls over his right brow, and a thin tied tail at the nape.

Three pieces, all on the Head bone (the tail follows the neck and chest):
  cap()     the volume: a shell from the hairline to the crown. It hugs the skull below LEDGE
            (the buzzed sides, painted as short hair over skin) and stands proud above it (the long
            top), so the cut shows as a step in his silhouette from the camera behind him.
  locks     thick clumps lying on the shell, roots buried in it, thinning to their tips: the fringe
            (FRINGE), the top swept back over the temples and down the back (SIDES, BACK), a
            cowlick at the crown (CROWN). They follow the hair's flow, so nothing stands up in spikes.
  tail()    the thin tail, tied near the root, ending in a small brush.
Each lock is a path of (angle round the head, height, lift) points, root first: angle 90 = his
face, 0 = his right, 180 = his left, 270 = the back; height in metres above the head joint (the
crown is 0.229, brows 0.12); lift = how far it stands above the shell there (the root is sunk in).
Widths run root to tip: wider = a fatter clump.
"""
import math
import numpy as np
from mathutils import Vector
import body
from paint import shade

LEDGE = 0.170      # height where the buzzed sides stop and the long top begins (at the temples)
LEDGE_BACK = 0.150 # ...and at the back of his head, so the long top rounds the skull
Z_TOP = 0.229      # the crown (the last head row)
SHORT = 0.0030     # how far the buzzed sides stand off the skin
FW = [0.050, 0.054, 0.048, 0.036, 0.022, 0.0]   # a fringe clump: thick root, thinning to the tip
BW = [0.050, 0.056, 0.050, 0.036, 0.0]          # a clump down the back or side

# The fringe: from the parting on his left (about 140 degrees) across the forehead to his right,
# the longest clumps falling to his right brow.
FRINGE = [
    ([(152, 0.222, -0.004), (138, 0.218, 0.004), (122, 0.202, 0.005), (110, 0.176, 0.005), (103, 0.150, 0.005),
      (99, 0.128, 0.004)], FW),
    ([(132, 0.228, -0.004), (116, 0.222, 0.004), (100, 0.204, 0.006), (88, 0.176, 0.006), (79, 0.148, 0.006),
      (74, 0.124, 0.005)], FW),
    ([(110, 0.229, -0.004), (94, 0.222, 0.004), (78, 0.202, 0.006), (66, 0.176, 0.006), (57, 0.150, 0.006),
      (52, 0.128, 0.005)], FW),
    ([(88, 0.229, -0.004), (72, 0.220, 0.004), (56, 0.202, 0.005), (44, 0.182, 0.005), (36, 0.162, 0.004),
      (31, 0.146, 0.003)], FW),
    # the short side of the parting, toward his left temple
    ([(158, 0.222, -0.004), (166, 0.210, 0.004), (173, 0.192, 0.005), (178, 0.172, 0.004), (180, 0.158, 0.002)],
     [0.040, 0.044, 0.036, 0.022, 0.0]),
]
# The top swept back over each temple, ending over the buzzed sides.
SIDES = [
    ([(60, 0.228, -0.004), (36, 0.220, 0.004), (16, 0.204, 0.005), (2, 0.184, 0.005), (-6, 0.164, 0.004)], BW),
    ([(196, 0.226, -0.004), (212, 0.216, 0.004), (226, 0.198, 0.005), (236, 0.178, 0.005), (241, 0.160, 0.004)],
     BW),
    ([(20, 0.229, -0.004), (2, 0.222, 0.004), (-16, 0.204, 0.005), (-28, 0.182, 0.005), (-34, 0.162, 0.004)], BW),
]
# Down the back of the head, fanning out from the crown; tips flick out a little over the ledge.
BACK = [([(270 + s * 0.4, 0.229, -0.004), (270 + s * 0.75, 0.218, 0.003), (270 + s, 0.194, 0.004),
          (270 + s * 1.1, 0.166, 0.004), (270 + s * 1.15, 0.142, 0.006)], BW) for s in (-60, -30, 0, 30, 60)]
# A cowlick at the crown, lying back.
CROWN = [([(244, 0.229, 0.0), (258, 0.229, 0.007), (274, 0.224, 0.010), (284, 0.212, 0.007)],
          [0.030, 0.032, 0.024, 0.0])]


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
        """How proud the long top stands: most at the front (the fringe's root), least at the back."""
        return 0.0095 + 0.0035 * math.cos(math.radians(theta - 90))

    def lift(self, theta, z):
        back = max(0.0, -math.sin(math.radians(theta)))   # at the back the long hair tapers into the buzz
        lo, hi = ledge(theta) - 0.010 - 0.02 * back, ledge(theta) + 0.014 + 0.02 * back
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
    pole_c = head.ring(len(head.rows) - 1)["c"] + Vector((0, 0, (0.006 + 0.012) * sh.s))
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
    """The buzzed sides: short hair over skin (lighter than the long hair, so the cut reads as an
    undercut, not a helmet), in fine vertical strokes. Above the ledge the long hair, its strands
    running back over the crown, a shadow where it overhangs the buzz and a soft sheen."""
    img = rect.atlas.img
    hair, dark = C["hair"], C["hair_dark"]
    buzz = dark * 0.62 + C["skin"] * 0.38
    for col in range(rect.w):
        u = (col + 0.5) / rect.w
        th = -90.0 + 360.0 * u
        tuft = 0.03 * abs(((u * 22) % 1.0) - 0.5) * 2      # the long hair's edge, in soft points
        edge = v_of(ledge(th)) - 0.02 + tuft
        for row in range(rect.h):
            v = 1 - (row + 0.5) / rect.h
            if v < edge:
                c = shade(buzz, 0.94) if col % 3 == 0 else buzz
                if v > edge - 0.05:
                    c = shade(buzz, 0.78)                                    # in the long hair's shadow
            else:
                c = hair
                groove = ((u * 16 + v * 0.8) % 1.0)
                if groove < 0.16:
                    c = shade(hair, 0.76)
                elif 0.66 < v < 0.84 and groove > 0.6:
                    c = shade(hair, 1.25)                                    # sheen on top
            img[rect.y + row, rect.x + col] = c


def paint_lock(rect, C):
    """A clump's texture: u runs round it (0.5 = its outer face), v root to tip."""
    hair = C["hair"]
    img = rect.atlas.img
    for col in range(rect.w):
        u = (col + 0.5) / rect.w
        for row in range(rect.h):
            v = 1 - (row + 0.5) / rect.h
            k = 0.74 if (u < 0.2 or u > 0.8) else 1.0                       # the underside
            k *= 0.8 + 0.25 * min(1.0, v / 0.35)                             # the root, in shadow
            if abs(u - 0.38) < 0.03 or abs(u - 0.64) < 0.03:
                k *= 0.82                                                    # strands splitting the clump
            if 0.45 < u < 0.56 and 0.3 < v < 0.75:
                k *= 1.22                                                    # the sheen on its outer face
            img[rect.y + row, rect.x + col] = np.clip(hair * k, 0.0, 1.0)


def locks(P, sh, rect):
    for path, widths in FRINGE + SIDES + BACK + CROWN:
        pts = [sh.on(th, z, extra) for th, z, extra in path]
        up = (pts[1] - sh.c0).normalized()
        body.strand(P, pts, [w * sh.s for w in widths], 0.40, rect.uv, {"Head": 1.0}, up=up, sides=5)


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
