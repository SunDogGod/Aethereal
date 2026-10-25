"""Body-part builders shared by every character. Each takes the Part to add to, the joint layout
J (rig.layout), a texture block (paint.Rect) and a few shape numbers, and returns what painting
needs. Right-side limbs are built, then mirrored with mesh.mirror_part.

Shapes are given for a 1.72 m body and scaled by the layout's height.
"""
import math
from mathutils import Vector
from mesh import loft, strand, frame_along, ring_point

FWD, UP = Vector((0, 1, 0)), Vector((0, 0, 1))


def spine_w(J, z):
    """Weights for a point at height z on the trunk."""
    zs, zc, zn = J["spine"].z, J["chest"].z, J["neck"].z
    def mix(a, b, z0, z1):
        t = min(1.0, max(0.0, (z - z0) / (z1 - z0)))
        return {a: 1 - t, b: t}
    if z < zs + 0.05:
        return mix("Hips", "Spine", zs - 0.05, zs + 0.05)
    if z < zc + 0.05:
        return mix("Spine", "Chest", zc - 0.06, zc + 0.05)
    return mix("Chest", "Neck", zn - 0.01, zn + 0.05)


def trunk(part, J, rect, profile, segs=16, arc=None, thickness=0.0, lining=None, cap0=None, legs=0.0):
    """The torso or anything worn around it (shirt, jacket, coat, belt).
    profile: rows (z, rx, ry_front, ry_back, n[, y_offset[, front gap]]) for a 1.72 m body.
    With arc (an open shell such as an open jacket) the 7th number is the front opening's half-angle.
    legs (0..1): how much of a hem below the hips follows the thighs at the front."""
    s = J["height"] / 1.72
    rings = []
    for row in profile:
        z, rx, ryf, ryb, n = row[:5]
        dy = row[5] if len(row) > 5 else 0.0
        z *= s
        w = spine_w(J, z)
        ring = {"c": Vector((0, dy * s, z)), "x": Vector((1, 0, 0)), "y": FWD, "rx": rx * s,
                "ry": ryf * s, "ryb": ryb * s, "n": n, "w": w}
        if arc is not None and len(row) > 6:
            ring["arc"] = (90.0 + row[6], 450.0 - row[6])  # an opening at the front, half-angle row[6]
        if z > J["shoulder"].z - 0.07 * s:
            # The outer shoulders follow the collarbones a little.
            def wf(th, w=w, z=z):
                c = math.cos(math.radians(th))
                k = max(0.0, abs(c) - 0.55) / 0.45 * 0.6
                out = {b: v * (1 - k) for b, v in w.items()}
                out["Shoulder_R" if c > 0 else "Shoulder_L"] = k
                return out
            ring["wf"] = wf
        low = J["hips"].z + 0.03 * s - z
        if legs > 0.0 and low > 0.0:
            # A hem below the hips: its front rides on the thighs (a crouch, a high knee), so a
            # raised thigh lifts the jacket instead of poking through it.
            k = legs * min(1.0, low / (0.08 * s))
            def wl(th, w=w, k=k):
                c, front = math.cos(math.radians(th)), max(0.0, math.sin(math.radians(th)))
                right = min(1.0, max(0.0, 0.5 + 0.8 * c))
                out = {b: v * (1 - k * front) for b, v in w.items()}
                for side, share in (("R", right), ("L", 1.0 - right)):
                    if share > 0.0:
                        out["UpperLeg_" + side] = k * front * share
                return out
            ring["wf"] = wl
        rings.append(ring)
    return loft(part, rings, segs, rect.uv, arc=arc, thickness=thickness,
                lining=lining.uv if lining else None, cap0=cap0)


def _chain(J, a, b, c, t):
    """Point and direction at t along a two-bone chain a-b-c (0..1 first bone, 1..2 second)."""
    if t <= 1.0:
        d = (b - a).normalized()
        p = a + (b - a) * t
        if t > 0.85:
            d = (d + (c - b).normalized() * ((t - 0.85) / 0.3)).normalized()
        return p, d
    d = (c - b).normalized()
    p = b + (c - b) * (t - 1.0)
    if t < 1.15:
        d = ((b - a).normalized() * ((1.15 - t) / 0.3) + d).normalized()
    return p, d


def limb(part, J, side_joints, bones, rect, profile, segs=10, cap0=None, cap1=None, up_hint=FWD, hand_bone=None):
    """An arm or leg (sleeve, trouser leg). side_joints = (top, middle, end) Vectors,
    bones = (upper, lower). profile rows: (t, r_across, r_front[, r_back]) with t 0..1 along the
    upper bone and 1..2 along the lower (t < 0 starts inside the body)."""
    s = J["height"] / 1.72
    a, b, c = side_joints
    up_b, lo_b = bones
    rings = []
    for row in profile:
        t, rx, ry = row[:3]
        ryb = row[3] if len(row) > 3 else ry
        p, d = _chain(J, a, b, c, t)
        x, y = frame_along(d, up_hint)
        if t < 0.85:
            w = {up_b: 1.0}
        elif t < 1.15:
            k = (t - 0.85) / 0.3
            w = {up_b: 1 - k, lo_b: k}
        else:
            w = {lo_b: 1.0}
        if hand_bone and t > 1.85:
            k = min(1.0, (t - 1.85) / 0.3) * 0.5
            w = {lo_b: 1 - k, hand_bone: k}
        rings.append({"c": p, "x": x, "y": y, "rx": rx * s, "ry": ry * s, "ryb": ryb * s, "n": 2.0, "w": w})
    return loft(part, rings, segs, rect.uv, cap0=cap0, cap1=cap1)


def arm_joints(J):
    return (J["shoulder"], J["elbow"], J["wrist"])


def leg_joints(J):
    return (J["hip_joint"], J["knee"], J["ankle"])


def fist(part, J, rect, size=1.0, segs=8):
    """A right hand closed in a loose fist (it holds a grip at the Weapon_R point), with a thumb."""
    s = J["height"] / 1.72 * size
    wrist, tip = J["wrist"], J["hand_tip"]
    d = (tip - wrist).normalized()
    x, y = frame_along(d, FWD)   # y: thumb side (forward), x: back of the hand
    rows = [(-0.01, 0.020, 0.027), (0.02, 0.022, 0.033), (0.05, 0.026, 0.042), (0.08, 0.028, 0.045),
            (0.105, 0.026, 0.042), (0.12, 0.018, 0.032)]
    rings = []
    for t, rx, ry in rows:
        rings.append({"c": wrist + d * t * s, "x": x, "y": y, "rx": rx * s, "ry": ry * s, "n": 2.6,
                      "w": {"Hand_R": 1.0} if t > 0.0 else {"Hand_R": 0.7, "LowerArm_R": 0.3}})
    loft(part, rings, segs, rect.uv, cap1="pole")
    # Thumb: from the base of the palm, round the front of the grip.
    base = wrist + d * 0.03 * s + y * 0.03 * s
    pts = [base, base + d * 0.035 * s + y * 0.012 * s - x * 0.006 * s,
           base + d * 0.06 * s + y * 0.004 * s - x * 0.02 * s]
    strand(part, pts, [0.013 * s, 0.011 * s, 0.0], 0.8, rect.uv, {"Hand_R": 1.0}, up=x, sides=5)


def foot(part, J, rect, rows=None, segs=8):
    """A right shoe or boot foot, heel to toe. rows: (y, half_width, half_height, centre_z)
    relative to the ankle, for a 1.72 m body."""
    s = J["height"] / 1.72
    ank = J["ankle"]
    rows = rows or [(-0.085, 0.032, 0.036, -0.036), (-0.06, 0.041, 0.052, -0.026), (0.0, 0.045, 0.058, -0.02),
                    (0.07, 0.049, 0.040, -0.040), (0.13, 0.049, 0.030, -0.052), (0.18, 0.042, 0.023, -0.06)]
    rings = []
    for y, hw, hh, cz in rows:
        w = {"Foot_R": 1.0} if y > -0.03 else {"Foot_R": 0.8, "LowerLeg_R": 0.2}
        if hh > 0.05:
            w = {"Foot_R": 0.6, "LowerLeg_R": 0.4}
        rings.append({"c": Vector((ank.x, ank.y + y * s, ank.z + cz * s)), "x": Vector((-1, 0, 0)), "y": UP,
                      "rx": hw * s, "ry": hh * s, "n": 3.0, "w": w, "cap_len": 0.012 * s})
    loft(part, rings, segs, rect.uv, cap0="pole", cap1="pole", start=-90.0)


def neck(part, J, rect, r=0.047, segs=10):
    s = J["height"] / 1.72
    rings = []
    for z, rr in ((J["neck"].z - 0.04 * s, r * 1.15), (J["neck"].z + 0.02 * s, r), (J["head"].z + 0.02 * s, r * 0.98),
                  (J["head"].z + 0.07 * s, r * 0.9)):
        w = {"Chest": 1.0} if z < J["neck"].z else ({"Neck": 1.0} if z < J["head"].z else {"Head": 0.7, "Neck": 0.3})
        rings.append({"c": Vector((0, -0.008 * s, z)), "x": Vector((1, 0, 0)), "y": FWD, "rx": rr * s,
                      "ry": rr * s, "n": 2.0, "w": w})
    loft(part, rings, segs, rect.uv)


# ---------------------------------------------------------------- the head
# Rows: (z above the head joint, y offset, half width, front depth, back depth, squareness),
# for a 1.72 m body. Chin at the first row, crown at the last.
HEAD_ROWS = [(0.000, 0.048, 0.030, 0.030, 0.028, 2.2), (0.016, 0.030, 0.056, 0.064, 0.050, 2.3),
             (0.044, 0.016, 0.068, 0.080, 0.072, 2.4), (0.074, 0.008, 0.074, 0.088, 0.088, 2.4),
             (0.103, 0.004, 0.077, 0.089, 0.097, 2.4), (0.135, 0.0, 0.078, 0.090, 0.101, 2.4),
             (0.170, -0.005, 0.075, 0.084, 0.100, 2.3), (0.203, -0.010, 0.064, 0.067, 0.084, 2.2),
             (0.229, -0.015, 0.039, 0.041, 0.050, 2.0)]


def head_warp(f):
    """More texture for the face: the front third of the head gets 60% of the width."""
    if f < 1 / 3:
        return 0.6 * f
    if f < 2 / 3:
        return 0.2 + (f - 1 / 3) * 1.8
    return 0.8 + (f - 2 / 3) * 0.6


class Head:
    """The head loft plus helpers to find points on it (hair) and in its texture (face paint)."""

    def __init__(self, J, rows=None, brow=0.004, scale=1.08):
        self.J = J
        self.s = J["height"] / 1.72
        self.k = scale  # stylised: a slightly big head
        self.rows = rows or HEAD_ROWS
        self.brow = brow
        self.z0 = J["head"].z

    def ring(self, i):
        z, dy, rx, ryf, ryb, n = self.rows[i]
        s = self.s * self.k
        brow_z = self.rows[5][0]
        def shape(th, z=z):
            # A soft brow ridge and flatter cheeks under it.
            front = max(0.0, math.sin(math.radians(th)))
            k = 1.0 + (self.brow / 0.09) * front ** 6 * max(0.0, 1 - abs(z - brow_z) / 0.03)
            return k
        return {"c": Vector((0, dy * s, self.z0 + z * s)), "x": Vector((1, 0, 0)), "y": FWD, "rx": rx * s,
                "ry": ryf * s, "ryb": ryb * s, "n": n, "r": shape, "w": {"Head": 1.0}, "cap_len": 0.0}

    def build(self, part, rect, segs=20):
        self.rect = rect
        rings = [self.ring(i) for i in range(len(self.rows))]
        rings[-1]["cap_len"] = 0.006 * self.s
        self.lens = [0.0]
        for a, b in zip(rings, rings[1:]):
            self.lens.append(self.lens[-1] + (b["c"] - a["c"]).length)
        loft(part, rings, segs, rect.uv, cap0="pole", cap1="pole", u_map=head_warp)

    def surface(self, theta, z, lift=0.0):
        """Point on the head at angle theta (90 = the face) and height z (metres above the head
        joint, for a 1.72 m body), pushed out by `lift`."""
        zs = [r[0] for r in self.rows]
        z = min(max(z, zs[0]), zs[-1])
        i = max(k for k in range(len(zs) - 1) if zs[k] <= z) if z < zs[-1] else len(zs) - 2
        t = (z - zs[i]) / (zs[i + 1] - zs[i])
        a, b = self.ring(i), self.ring(i + 1)
        pa, pb = ring_point(a, theta), ring_point(b, theta)
        p = pa.lerp(pb, t)
        c = a["c"].lerp(b["c"], t)
        out = (p - c)
        out.z = 0
        return p + out.normalized() * lift * self.s

    def uv(self, theta, z):
        """Block coordinates (u, v) of the face texture at angle theta and height z."""
        f = ((theta + 90.0) % 360.0) / 360.0
        zs = [r[0] for r in self.rows]
        z = min(max(z, zs[0]), zs[-1])
        i = max(k for k in range(len(zs) - 1) if zs[k] <= z) if z < zs[-1] else len(zs) - 2
        t = (z - zs[i]) / (zs[i + 1] - zs[i])
        v = (self.lens[i] + (self.lens[i + 1] - self.lens[i]) * t) / self.lens[-1]
        return head_warp(f), v


def nose(part, head, rect, length=0.022, width=0.016):
    """A small wedge nose on the face (between the eyes and the mouth)."""
    s = head.s
    top = head.surface(90, 0.108, -0.002)
    base_z = 0.066
    tip = head.surface(90, base_z + 0.006, length)
    bl = head.surface(90 + 11, base_z, 0.0)
    br = head.surface(90 - 11, base_z, 0.0)
    bc = head.surface(90, base_z - 0.004, 0.008)
    w = {"Head": 1.0}
    i = [part.vert(p, w) for p in (top, tip, bl, br, bc)]
    u, v = head.uv(90, base_z + 0.02)
    uv = [(head.rect.uv[0] + (head.rect.uv[2] - head.rect.uv[0]) * u,
           head.rect.uv[1] + (head.rect.uv[3] - head.rect.uv[1]) * v)] * 3
    part.face((i[0], i[1], i[2]), uv)
    part.face((i[0], i[3], i[1]), uv)
    part.face((i[1], i[4], i[2]), uv, False)
    part.face((i[1], i[3], i[4]), uv, False)


def ear(part, head, rect, side=1):
    """A flat ear on the side of the head (side 1 = right, -1 = left)."""
    th = 0.0 if side > 0 else 180.0
    th += -6 * side
    pts = [head.surface(th, 0.060, -0.004), head.surface(th, 0.082, 0.006), head.surface(th, 0.108, 0.004)]
    out = Vector((side, -0.25, 0)).normalized()
    strand(part, pts, [0.012 * head.s, 0.016 * head.s, 0.0], 0.35, rect.uv, {"Head": 1.0}, up=out, sides=5)


def lock(part, head, rect, path, widths, depth=0.45, sides=4, w=None):
    """A chunky clump of hair. path: (theta, z, lift) points from root to tip on the head."""
    pts = [head.surface(t, z, lift) for t, z, lift in path]
    root_out = (pts[0] - Vector((0, 0, head.z0 + 0.12 * head.s)))
    widths = [x * head.s for x in widths]
    strand(part, pts, widths, depth, rect.uv, w or {"Head": 1.0}, up=root_out, sides=sides)


def trunk_point(J, profile, theta, z, lift=0.0):
    """A point on a trunk profile's surface (theta: 0 = his right, 90 = front), pushed out by lift.
    Handy for straps and buckles that sit on a jacket."""
    s = J["height"] / 1.72
    zs = [r[0] for r in profile]
    z = min(max(z, zs[0]), zs[-1])
    i = max(k for k in range(len(zs) - 1) if zs[k] <= z) if z < zs[-1] else len(zs) - 2
    t = (z - zs[i]) / (zs[i + 1] - zs[i])
    row = [a + (b - a) * t for a, b in zip(profile[i][:5], profile[i + 1][:5])]
    ring = {"c": Vector((0, 0, row[0] * s)), "x": Vector((1, 0, 0)), "y": FWD, "rx": (row[1] + lift) * s,
            "ry": (row[2] + lift) * s, "ryb": (row[3] + lift) * s, "n": row[4]}
    return ring_point(ring, theta)
