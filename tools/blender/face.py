"""Heads with real faces: eye sockets under a brow, a nose with a bridge, a tip and nostril wings,
cheekbones, a mouth with lips, a chin and the angle of the jaw, and ears that stand off the head.
face_paint.py paints the eyes, brows, lips and skin onto it from the same numbers.

    import face, face_paint
    look = face.look(face.YOUNG_MAN, skin=..., iris=..., nose=0.019)   # shape and paint numbers
    head = face.Head(J, look)
    head.build(P, A.rect("head", *face.HEAD_RECT))
    face.ears(P, head, A.rect("ear", 16, 16), look)
    face_paint.paint(head, look, hairline)

Every shape number is in metres for a 1.72 m body (the Head scales it), angles in degrees away from
the middle of the face (21 = an eye's centre). A feature is a soft bump (or dent) on the head's
surface: relief() adds them up, so a bigger number stands further out. The face takes most of the
head's texture block (HEAD_RECT, so the character's atlas is 512 px): eyes about 18 px wide.
"""
import math
import numpy as np
from mathutils import Vector
import body
import mesh
from paint import rgb

HEAD_RECT = (192, 128)
MDEG = 0.00148            # metres per degree across the face (for painting in metres)
# Columns of the head mesh: angles away from the face, dense over it, sparse round the back.
HALF = (0, 3.5, 7.5, 11.5, 16, 21, 26, 31.5, 37.5, 44, 52, 62, 75, 92, 115, 145, 180)
FACE_U = 55.0             # the face (+-55 degrees) takes U_FACE of the texture's width
U_FACE = 0.65
# Texture rows: the band from the chin to the brow takes most of the height.
V_PTS = ((0.0, 0.0), (0.02, 0.06), (0.14, 0.80), (0.229, 1.0))

# Starting points (change a copy with look(...)).
BASE = dict(
    rows=None, scale=1.08,
    eye_a=21.0, eye_z=0.100, socket=0.0055, eyeball=0.0022,
    brow_z=0.123, brow_ridge=0.0035, temple=0.003,
    nose=0.017, nose_tip_z=0.071, nose_bridge=0.004, nose_w=5.0, nostril=0.0045,
    cheek=0.0035, cheek_a=40.0, cheek_z=0.086, hollow=0.0,
    muzzle=0.003, mouth_z=0.0435, mouth_w=9.0, lip_up=0.0040, lip_lo=0.0045,
    chin=0.0055, chin_z=0.013, chin_w=13.0, jaw=0.002,
    ear_z=0.083, ear_size=1.0, ear_a=-6.0,
    # paint (face_paint.py): colours are filled in by each character
    eye_w=8.6, eye_h=0.0074, eye_lo=0.0050, eye_tilt=0.0008, iris_r=0.0068, iris_look=-0.06,
    lash=0.0019, wing=0.0, lower_lash=0.35, crease=0.6,
    brow_in=8.5, brow_out=33.0, brow_z0=0.1205, brow_z1=0.1215, brow_arch=0.0028, brow_thick=0.0034,
    lip_h_up=0.0030, lip_h_lo=0.0038, lip_sat=0.45, smile=0.0, smirk=0.0,
    blush=0.0, age=0.0, stubble=0.0, shade=1.0,
    sclera=rgb("#efe9e0"), pupil=rgb("#141012"),
)
YOUNG_MAN = dict(BASE)
WOMAN = dict(BASE, socket=0.0048, brow_ridge=0.0022, nose=0.013, nose_w=4.4, nostril=0.0035, cheek=0.0035,
             jaw=0.0, chin=0.0045, chin_w=11.0, lip_up=0.0048, lip_lo=0.0055, mouth_w=8.4, eye_h=0.0078,
             eye_tilt=0.0012, lash=0.0023, wing=0.25, brow_thick=0.0024, brow_arch=0.0036, lip_h_up=0.0034,
             lip_h_lo=0.0043, lip_sat=0.8, blush=0.25)
MAN = dict(BASE, socket=0.0062, brow_ridge=0.0048, nose=0.019, nose_w=5.4, nostril=0.0052, cheek=0.0040,
           hollow=0.002, jaw=0.0045, chin=0.0065, chin_w=14.0, eye_h=0.0062, eye_tilt=0.0004, lash=0.0016,
           brow_thick=0.0042, brow_arch=0.0016, lip_up=0.0032, lip_lo=0.0042, lip_h_up=0.0024, lip_sat=0.3)


# Head rows (as body.HEAD_ROWS) with a narrower jaw tapering to the chin: a younger, heart-shaped face.
HEART_ROWS = [(0.000, 0.046, 0.024, 0.026, 0.026, 2.1), (0.016, 0.030, 0.048, 0.060, 0.048, 2.2),
              (0.044, 0.016, 0.061, 0.078, 0.072, 2.3), (0.074, 0.008, 0.070, 0.088, 0.088, 2.4)] + body.HEAD_ROWS[4:]


def look(base, **changes):
    out = dict(base)
    out.update(changes)
    return out


def _g(a, z, a0, z0, sa, sz):
    return np.exp(-((a - a0) / sa) ** 2 - ((z - z0) / sz) ** 2)


def relief(L, a, z):
    """How far the face stands out (+) or sinks in (-) at angle a (from the middle of the face,
    degrees) and height z, in metres. Works on numbers and numpy arrays alike."""
    a = np.abs(a)
    t, ez = L["nose_tip_z"], L["eye_z"]
    n = L["nose"]
    prof = np.interp(z, [t - 0.0135, t - 0.0095, t - 0.0055, t, t + 0.012, ez, ez + 0.012, ez + 0.02],
                     [0.0, 0.2 * n, 0.78 * n, n, 0.6 * n, L["nose_bridge"], 0.35 * L["nose_bridge"], 0.0])
    w = np.interp(z, [t - 0.012, t, ez], [L["nose_w"] * 1.45, L["nose_w"] * 1.1, L["nose_w"] * 0.72])
    d = prof * np.exp(-(a / w) ** 3)
    d = d + L["nostril"] * _g(a, z, L["nose_w"] * 1.45, t - 0.006, 3.2, 0.0055)
    d = d - L["socket"] * _g(a, z, L["eye_a"] - 2.0, ez + 0.003, 11.0, 0.013)
    d = d + L["eyeball"] * _g(a, z, L["eye_a"], ez, 7.0, 0.0065)
    d = d + L["brow_ridge"] * _g(a, z, 17.0, L["brow_z"], 18.0, 0.008)
    d = d - L["temple"] * _g(a, z, 60.0, L["brow_z"], 10.0, 0.02)
    d = d + L["cheek"] * _g(a, z, L["cheek_a"], L["cheek_z"], 14.0, 0.016)
    d = d - L["hollow"] * _g(a, z, L["cheek_a"] + 2.0, L["cheek_z"] - 0.034, 13.0, 0.014)
    m = L["mouth_z"]
    d = d + L["muzzle"] * _g(a, z, 0.0, m + 0.008, 22.0, 0.016)
    d = d + L["lip_up"] * _g(a, z, 0.0, m + 0.0042, L["mouth_w"], 0.0034)
    d = d + L["lip_lo"] * _g(a, z, 0.0, m - 0.0050, L["mouth_w"] * 0.85, 0.0040)
    d = d - 0.0015 * _g(a, z, 0.0, m, L["mouth_w"] * 1.15, 0.0016)
    d = d - 0.0015 * _g(a, z, 0.0, m - 0.013, 10.0, 0.004)
    d = d + L["chin"] * _g(a, z, 0.0, L["chin_z"], L["chin_w"], 0.010)
    d = d + L["jaw"] * _g(a, z, 70.0, 0.028, 14.0, 0.016)
    return d


def heights(L):
    """The mesh's rows: an even spread, plus a row on each feature (lip, nostril, lid, brow)."""
    t, m, e = L["nose_tip_z"], L["mouth_z"], L["eye_z"]
    feat = [m - 0.005, m, m + 0.0042, t - 0.0095, t - 0.0055, t, e - 0.006, e, e + 0.007, L["brow_z"],
            L["chin_z"]]
    even = [0.0, 0.007, 0.021, 0.030, 0.056, 0.081, 0.088, 0.112, 0.131, 0.145, 0.163, 0.184, 0.207, 0.229]
    zs = sorted(feat)
    for z in even:
        if min(abs(z - f) for f in zs) > 0.0035 or z in (0.0, 0.229):
            zs.append(z)
    return sorted(set(round(z, 5) for z in zs))


def _spline(rows, z):
    """The head rows' numbers at height z, Catmull-Rom between the rows (no creases)."""
    zs = [r[0] for r in rows]
    i = max(0, min(len(rows) - 2, max(k for k in range(len(zs)) if zs[k] <= z) if z >= zs[0] else 0))
    p0, p1, p2, p3 = rows[max(0, i - 1)], rows[i], rows[i + 1], rows[min(len(rows) - 1, i + 2)]
    t = (z - p1[0]) / (p2[0] - p1[0])
    out = [z]
    for k in range(1, 6):
        a, b, c, d = p0[k], p1[k], p2[k], p3[k]
        out.append(0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t ** 3))
    return tuple(out)


def warp_u(f):
    lo, hi = 0.5 - FACE_U / 360.0, 0.5 + FACE_U / 360.0
    return float(np.interp(f, [0.0, lo, hi, 1.0], [0.0, (1 - U_FACE) / 2, (1 + U_FACE) / 2, 1.0]))


def warp_v(z):
    return float(np.interp(z, [p[0] for p in V_PTS], [p[1] for p in V_PTS]))


class Head(body.Head):
    """body.Head with features: same surface() / uv() for hair and props, a denser mesh."""

    def __init__(self, J, L):
        super().__init__(J, rows=L["rows"] or body.HEAD_ROWS, brow=0.0, scale=L["scale"])
        self.look = L
        base = self.rows
        self.rows = [_spline(base, z) for z in heights(L)]

    def ring(self, i):
        z, dy, rx, ryf, ryb, n = self.rows[i]
        s = self.s * self.k
        L = self.look

        def shape(th, z=z):
            c, sn = math.cos(math.radians(th)), math.sin(math.radians(th))
            x = rx * math.copysign(abs(c) ** (2.0 / n), c)
            y = (ryf if sn >= 0 else ryb) * math.copysign(abs(sn) ** (2.0 / n), sn)
            r0 = max(0.01, math.hypot(x, y))
            a = ((th - 90.0 + 180.0) % 360.0) - 180.0
            return 1.0 + float(relief(L, a, z)) / r0
        return {"c": Vector((0, dy * s, self.z0 + z * s)), "x": Vector((1, 0, 0)), "y": body.FWD, "rx": rx * s,
                "ry": ryf * s, "ryb": ryb * s, "n": n, "r": shape, "w": {"Head": 1.0}, "cap_len": 0.0}

    def build(self, part, rect, segs=None):
        self.rect = rect
        rings = [self.ring(i) for i in range(len(self.rows))]
        rings[0]["cap_len"] = 0.002 * self.s
        rings[-1]["cap_len"] = 0.006 * self.s
        self.lens = [0.0]
        for a, b in zip(rings, rings[1:]):
            self.lens.append(self.lens[-1] + (b["c"] - a["c"]).length)
        ths = sorted({(90.0 + sd * h + 90.0) % 360.0 - 90.0 for h in HALF for sd in (1, -1)})
        mesh.loft(part, rings, 0, rect.uv, cap0="pole", cap1="pole", u_map=warp_u, thetas=ths,
                  vs=[warp_v(r[0]) for r in self.rows])

    def uv(self, theta, z):
        return warp_u(((theta + 90.0) % 360.0) / 360.0), warp_v(z)


def ears(part, head, rect, L, skin, inner):
    """Both ears (the right one built, then mirrored), painted skin with a shaded bowl."""
    v0, f0 = mesh.mark(part)
    _ear(part, head, rect, L)
    v1, f1 = mesh.mark(part)
    mesh.mirror_part(part, (v0, v1, f0, f1))
    rect.fill(skin)
    rect.box(0.0, 0.62, 1.0, 1.0, inner)          # the bowl (the end cap) in shade
    rect.box(0.0, 0.0, 1.0, 0.15, inner)          # where it meets the head


def _ear(part, head, rect, L):
    """The right ear: an oval that stands off the side of the head, flaring back, with a rim (the
    widest ring) and a hollow bowl (the end cap turns back toward the head). Wider at the top."""
    hs = head.s * head.k
    k = L["ear_size"]
    th = L["ear_a"]
    c = head.surface(th, L["ear_z"], -0.004)
    normal = Vector((0.93, 0.36, 0.0)).normalized()     # faces out and a little forward
    up = Vector((0.0, -0.22, 1.0)).normalized()          # leans back
    x = up.cross(normal).normalized()
    up = normal.cross(x).normalized()
    back = Vector((0.0, -1.0, 0.0))

    def wide_top(t):
        sn = math.sin(math.radians(t))
        return 1.0 + 0.16 * max(0.0, sn) - 0.12 * max(0.0, -sn)
    rings = []
    for d, rx, ry, flare in ((0.0, 0.0105, 0.020, 0.0), (0.0055, 0.0135, 0.0245, 0.003), (0.0085, 0.0125, 0.0232, 0.005)):
        rings.append({"c": c + normal * d * hs * k + back * flare * hs * k, "x": x, "y": up, "rx": rx * hs * k,
                      "ry": ry * hs * k, "n": 2.3, "r": wide_top, "w": {"Head": 1.0}, "cap_len": 0.0})
    rings[-1]["cap_len"] = -0.006 * hs * k
    mesh.loft(part, rings, 10, rect.uv, cap1="pole")
