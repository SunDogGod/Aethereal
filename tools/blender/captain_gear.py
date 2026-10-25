"""The captain's white Agency coat, worn draped around his shoulders like a cape with the sleeves
hanging empty, and the stump of his right arm. Shapes are for a 1.72 m body (scaled by height).

The coat sits on both shoulders and covers his back and his right side; on the left it falls
behind his sword arm, so the one arm he has is free. Its top follows the chest and collarbones,
its hem rides a little on the thighs at the back so his stride doesn't push through it, and the
edge behind his left arm leans a little with that arm.
"""
import math
from mathutils import Vector
import body
import mesh
import agency_parts as ap

# The draped coat, hem up: (z, half width, front depth, back depth, squareness, left edge, right edge).
# Edges are angles round him (0 = his right, 90 = front, 180 = left, 270 = back): the coat runs
# from the left edge round his back to the right edge (over 360 = past his right side to the front).
CAPE = [(0.34, 0.340, 0.240, 0.290, 2.0, 226, 438), (0.56, 0.310, 0.215, 0.240, 2.05, 226, 438),
        (0.78, 0.288, 0.200, 0.200, 2.1, 224, 438), (0.96, 0.276, 0.195, 0.168, 2.2, 221, 436),
        (1.12, 0.285, 0.180, 0.153, 2.35, 214, 434), (1.25, 0.300, 0.150, 0.142, 2.55, 202, 431),
        (1.34, 0.298, 0.130, 0.132, 2.7, 176, 429), (1.39, 0.255, 0.117, 0.122, 2.6, 150, 427),
        (1.42, 0.180, 0.102, 0.112, 2.4, 132, 425), (1.443, 0.112, 0.088, 0.098, 2.2, 120, 423)]
FOLDS = (9.0, 0.03)                     # soft folds hanging from the shoulders: how many per circle, depth at the hem
# Its standing collar, open at the front (z, half width, front, back, squareness, forward offset).
COLLAR = [(1.43, 0.118, 0.098, 0.108, 2.3, -0.008), (1.48, 0.135, 0.110, 0.130, 2.3, -0.018),
          (1.525, 0.158, 0.122, 0.152, 2.3, -0.030)]
COLLAR_OPEN = 58                        # half-angle of the collar's opening at the front
# The empty sleeves: where each hangs on the coat (angle round him) and how far down it reaches.
SLEEVES = ((350, 1.35, 0.82), (233, 1.30, 0.82))
STUMP_DIR = (0.40, -0.05, -1.0)       # the folded sleeve over his right shoulder points down and out


def cape_weights(J, side_arm=0.3):
    """Per-angle bone weights for a coat ring at height z (shell's wf)."""
    s = J["height"] / 1.72
    hip = J["hips"].z / s

    def ring(z, w):
        def wf(th):
            c, sn = math.cos(math.radians(th)), math.sin(math.radians(th))
            out = dict(w)
            if z > 1.30:                                 # on the shoulders: follow the collarbones
                k = max(0.0, abs(c) - 0.5) / 0.5 * 0.7
                out = {b: v * (1 - k) for b, v in out.items()}
                out["Shoulder_R" if c > 0 else "Shoulder_L"] = k
            if 0.9 < z < 1.36 and c < 0:                 # the edge behind the sword arm leans with it
                near = max(0.0, 1.0 - abs((th % 360) - 228) / 40.0)
                k = side_arm * near * min(1.0, (z - 0.9) / 0.2)
                if k > 0:
                    out = {b: v * (1 - k) for b, v in out.items()}
                    out["UpperArm_L"] = k
            low = hip + 0.02 - z
            if low > 0:                                  # below the belt: the hem rides on the thighs
                right = min(1.0, max(0.0, 0.5 + 0.9 * c))   # a sharper split shears the back between the legs
                back = 0.35 * min(1.0, low / 0.40) * min(1.2, max(0.0, -sn * 0.8 + 0.45))
                front = 1.0 * min(1.0, low / 0.30) * max(0.0, sn) * right   # the panel over his right leg
                k = min(0.9, back + front)
                out = {b: v * (1 - k) for b, v in out.items()}
                for leg, share in (("UpperLeg_R", right), ("UpperLeg_L", 1 - right)):
                    if share > 0:
                        out[leg] = out.get(leg, 0.0) + k * share
            return out
        return wf
    return ring


def cape(T, J, rect, lining):
    """The coat over his shoulders (an open shell with an inside)."""
    s = J["height"] / 1.72
    rows = [r[:5] for r in CAPE]
    arcs = [(r[5], r[6]) for r in CAPE]
    n, depth = FOLDS

    def folds(z):
        a = depth * max(0.0, min(1.0, (1.30 - z) / 0.9))   # none on the shoulders, deepest at the hem
        return lambda th: 1.0 + a * math.sin(math.radians(th) * n)
    ap.shell(T, J, rect, rows, segs=30, thickness=0.008 * s, lining=lining, arcs=arcs, wf=cape_weights(J), rz=folds)


def cape_point(J, th, z, lift=0.0):
    """A point on the coat's outside at angle th and height z (1.72 m body), pushed out by lift."""
    s = J["height"] / 1.72
    zs = [r[0] for r in CAPE]
    z = min(max(z, zs[0]), zs[-1])
    i = max(k for k in range(len(zs) - 1) if zs[k] <= z) if z < zs[-1] else len(zs) - 2
    t = (z - zs[i]) / (zs[i + 1] - zs[i])
    row = [a + (b - a) * t for a, b in zip(CAPE[i][:5], CAPE[i + 1][:5])]
    ring = {"c": Vector((0, 0, row[0] * s)), "x": Vector((1, 0, 0)), "y": body.FWD, "rx": (row[1] + lift) * s,
            "ry": (row[2] + lift) * s, "ryb": (row[3] + lift) * s, "n": row[4]}
    return mesh.ring_point(ring, th)


def collar(T, J, rect, lining):
    ap.shell(T, J, rect, COLLAR, segs=14, thickness=0.008 * J["height"] / 1.72, lining=lining,
             arcs=[(90 + COLLAR_OPEN, 450 - COLLAR_OPEN)] * len(COLLAR))


def empty_sleeves(T, M, J, rect, cuff_rect):
    """Each sleeve hangs limp from the coat's shoulder, flattened against its side, with a cuff
    (trim) at the end."""
    s = J["height"] / 1.72
    ring_w = cape_weights(J, side_arm=0.0)
    for th, z0, z1 in SLEEVES:
        top, bot = cape_point(J, th, z0, 0.012), cape_point(J, th, z1, 0.03)
        out = Vector((math.cos(math.radians(th)), math.sin(math.radians(th)), 0.0))
        d = (bot - top).normalized()
        x, y = mesh.frame_along(d, out)              # y: away from the coat, x: along its surface
        rings, cuff = [], []
        for t, rx, ry in ((0.0, 0.070, 0.014), (0.15, 0.066, 0.013), (0.55, 0.058, 0.012), (0.92, 0.055, 0.012),
                          (1.0, 0.056, 0.014)):
            c = top.lerp(bot, t)
            w = ring_w(c.z / s, body.spine_w(J, c.z))(th)
            rings.append({"c": c, "x": x, "y": y, "rx": rx * s, "ry": ry * s, "n": 2.4, "w": w, "cap_len": 0.0})
            if t >= 0.86:
                cuff.append(dict(rings[-1], rx=(rx + 0.005) * s, ry=(ry + 0.006) * s))
        mesh.loft(T, rings, 8, rect.uv, cap1="pole")
        mesh.loft(M, cuff, 8, cuff_rect.uv)


def epaulettes(M, J, board, fringe):
    """A stiff board on each of the coat's shoulders with a short fringe at its outer end (trim)."""
    s = J["height"] / 1.72
    ring_w = cape_weights(J, side_arm=0.0)
    for side in (1, -1):
        th = 0 if side > 0 else 180
        inner, outer = cape_point(J, th, 1.425, 0.004), cape_point(J, th, 1.37, 0.006)
        along = (outer - inner).normalized()
        across = Vector((0, side, 0))                 # keeps the box's axes right-handed on both sides
        up = along.cross(across)
        w = ring_w(1.40, body.spine_w(J, 1.40 * s))(th)
        mid = inner.lerp(outer, 0.5) + up * 0.006 * s
        ap.box(M, mid, ((outer - inner).length * 0.55, 0.048 * s, 0.007 * s), board, w, (along, across, up))
        tip = outer + along * 0.012 * s - up * 0.028 * s
        ap.box(M, tip, (0.007 * s, 0.050 * s, 0.03 * s), fringe, w, (along, across, up))


def stump(P, J, rect):
    """What is left of his right arm: the uniform's sleeve folded up and pinned just below the
    shoulder, round and short. It rides the shoulder and chest, never an arm bone."""
    s = J["height"] / 1.72
    d = Vector(STUMP_DIR).normalized()
    x, y = mesh.frame_along(d, body.FWD)
    base = J["shoulder"]
    rings = []
    for t, r in ((-0.045, 0.064), (0.0, 0.068), (0.035, 0.066), (0.065, 0.058), (0.088, 0.042)):
        rings.append({"c": base + d * t * s, "x": x, "y": y, "rx": r * s, "ry": r * s * 1.04, "n": 2.0,
                      "w": {"Shoulder_R": 0.65, "Chest": 0.35}, "cap_len": 0.018 * s})
    mesh.loft(P, rings, 10, rect.uv, cap1="pole")
