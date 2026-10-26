"""Posing: turns a readable pose description into bone rotations, and writes animations.

A pose is a dict. Angles are degrees, positions metres, all in the character's own axes
(x = his right, y = forward, z = up), measured from the rest pose:
    'hips':  {'loc': (x, y, z) offset, 'rot': (x, y, z)}
    'Spine', 'Chest', 'Neck', 'Head', 'Shoulder_L', 'Shoulder_R': (x, y, z) rotations
        +x tips an upright bone BACK (and swings a hanging limb forward), +y tips it to his right,
        +z turns it to his left (seen from above, counter-clockwise).
    'arm_R' / 'arm_L': {'ik': (x, y, z) wrist position}  or  {'ikc': (angle, radius, height)}
        (angle 0 = straight ahead, +90 = his left) or {'ikr': (x, y, z) from the shoulder},
        with 'pole': where the elbow points, and the
        hand as 'blade': (yaw, pitch, roll) for the held weapon's direction, 'hand': (x, y, z)
        rotation, or nothing (the hand follows the forearm).
        Or {'fk': [upper, lower, hand]} rotations.
        Placing the held item instead of the wrist: {'grip': (x, y, z)} or {'gripc': (angle, radius,
        height)} with 'blade' puts the weapon grip there; {'hold': (bone, t, roll)} grips an attach
        bone's axis t metres along it (the right hand on the sheathed sword: ('Scabbard', 0, 0);
        the left hand round the scabbard's mouth: ('Scabbard', 0.13, roll)).
    'Scabbard', 'Knife': (x, y, z) rotations of those attach bones (the scabbard tilts in a draw).
    'leg_R' / 'leg_L': {'ankle': (x, y, z), 'pole': knee direction, 'foot': (pitch, yaw)}
        (pitch + = toes up; yaw + = toes turned to his left), or {'fk': [upper, lower, foot]}.
Animations are lists of keys (time, pose[, ease]) or a function of time; every frame is solved
and keyed, so wrists and blades travel along arcs instead of cutting through the body.
"""
import math
import bpy
from mathutils import Vector, Matrix, Euler

FPS = 30
I3 = Matrix.Identity(3)
TORSO = ("Spine", "Chest", "Neck", "Head", "Shoulder_L", "Shoulder_R")
ROTATED = TORSO + ("Scabbard", "Knife")   # bones a pose may turn directly


def eul(r):
    return Euler([math.radians(a) for a in r], 'XYZ').to_matrix()


def frame(y, z):
    """Rotation whose Y column is y and Z column is z (made perpendicular)."""
    y = Vector(y).normalized()
    z = Vector(z) - y * Vector(z).dot(y)
    if z.length < 1e-6:
        z = y.orthogonal()
    z.normalize()
    return Matrix((y.cross(z), y, z)).transposed()


def blade_dirs(yaw, pitch, roll):
    """Blade direction and edge direction for a held weapon. Yaw 0 = ahead, +90 = his left;
    pitch + = point up. Roll 0 puts the edge leading a left-to-right cut; 180 a right-to-left one."""
    t, p, r = math.radians(yaw), math.radians(pitch), math.radians(roll)
    d = Vector((-math.cos(p) * math.sin(t), math.cos(p) * math.cos(t), math.sin(p)))
    e0 = Vector((math.cos(t), math.sin(t), 0.0))
    e = e0 * math.cos(r) + d.cross(e0) * math.sin(r)
    return d, e


def dirs_to_blade(d, e, ref_yaw=0.0):
    """The (yaw, pitch, roll) that blade_dirs() turns into direction d and edge e; yaw is picked
    within 180 degrees of ref_yaw so keys blend the short way round."""
    d = Vector(d).normalized()
    p = math.asin(max(-1.0, min(1.0, d.z)))
    t = math.atan2(-d.x, d.y)
    e0 = Vector((math.cos(t), math.sin(t), 0.0))
    r = math.atan2(Vector(e).dot(d.cross(e0)), Vector(e).dot(e0))
    yaw = math.degrees(t)
    while yaw - ref_yaw > 180.0:
        yaw -= 360.0
    while yaw - ref_yaw < -180.0:
        yaw += 360.0
    return (yaw, math.degrees(p), math.degrees(r))


class Rig:
    """Rest-pose data of an armature, and the solver."""

    def __init__(self, arm):
        self.arm = arm
        self.rest = {}
        for b in arm.data.bones:
            self.rest[b.name] = (b.head_local.copy(), b.matrix_local.to_3x3().normalized(),
                                 b.parent.name if b.parent else None)
        self.order = []
        def visit(b):
            self.order.append(b.name)
            for c in b.children:
                visit(c)
        for b in arm.data.bones:
            if b.parent is None:
                visit(b)

    def head(self, name):
        return self.rest[name][0]

    def attach_frame(self, hold, Q, D, P):
        """Grip point, item direction and edge direction for a 'hold' on an attach bone (a child
        of an already-posed bone, e.g. the Scabbard on the Hips), turned `roll` degrees about it."""
        bone, t, roll = hold
        h, R, parent = self.rest[bone]
        M = D[parent] @ Q.get(bone, I3) @ R
        y, z = M.col[1].to_3d(), M.col[2].to_3d()
        r = math.radians(roll)
        z = z * math.cos(r) + y.cross(z) * math.sin(r)
        base = D[parent] @ (h - self.rest[parent][0]) + P[parent]
        return base + y * t, y, z

    def ikc_as_grip(self, pose, side):
        """The same pose with arm_<side>'s 'ikc' wrist written as a 'gripc' weapon grip."""
        arm = dict(pose["arm_" + side])
        ang, rad, z = arm.pop("ikc")
        t = math.radians(ang)
        hw, Rw, _ = self.rest["Weapon_" + side]
        g = Vector((-rad * math.sin(t), rad * math.cos(t), z)) + \
            (frame(*blade_dirs(*arm["blade"])) @ Rw.transposed()) @ (hw - self.rest["Hand_" + side][0])
        arm["gripc"] = (math.degrees(math.atan2(-g.x, g.y)), Vector((g.x, g.y)).length, g.z)
        out = dict(pose)
        out["arm_" + side] = arm
        return out

    def hold_as_grip(self, pose, side, ref_yaw=0.0):
        """The same pose with arm_<side>'s 'hold' written as 'gripc' + 'blade', so a key that
        holds the scabbard can blend smoothly into keys that swing the blade freely."""
        arm = dict(pose["arm_" + side])
        hips = pose.get("hips", {})
        Q = {"Hips": eul(hips.get("rot", (0, 0, 0)))}
        for b in ROTATED:
            if b in pose and b in self.rest:
                Q[b] = eul(pose[b])
        D, P = {"Hips": Q["Hips"]}, {"Hips": self.rest["Hips"][0] + Vector(hips.get("loc", (0, 0, 0)))}
        g, d, e = self.attach_frame(arm.pop("hold"), Q, D, P)
        ang = math.degrees(math.atan2(-g.x, g.y))
        arm["gripc"] = (ang, Vector((g.x, g.y)).length, g.z)
        arm["blade"] = dirs_to_blade(d, e, ref_yaw)
        out = dict(pose)
        out["arm_" + side] = arm
        return out

    def solve(self, spec):
        """Returns ({bone: rotation in rest axes}, hips offset)."""
        Q = {}
        hips = spec.get("hips", {})
        loc = Vector(hips.get("loc", (0, 0, 0)))
        Q["Hips"] = eul(hips.get("rot", (0, 0, 0)))
        for b in ROTATED:
            if b in spec and b in self.rest:
                Q[b] = eul(spec[b])
        D, P = {}, {}
        for b in self.order:
            h, R, parent = self.rest[b]
            if b.startswith("UpperArm_") or b.startswith("UpperLeg_"):
                side = b[-1]
                limb = "arm" if b.startswith("UpperArm_") else "leg"
                sub = spec.get(limb + "_" + side)
                if sub:
                    self._limb(limb, side, sub, Q, D, P)
            q = Q.get(b, I3)
            if parent is None:
                D[b], P[b] = q, h + loc
            else:
                D[b] = D[parent] @ q
                P[b] = D[parent] @ (h - self.rest[parent][0]) + P[parent]
        return Q, loc

    def _limb(self, limb, side, sub, Q, D, P):
        names = (["UpperArm_", "LowerArm_", "Hand_"] if limb == "arm" else ["UpperLeg_", "LowerLeg_", "Foot_"])
        n0, n1, n2 = [n + side for n in names]
        if "fk" in sub:
            for n, r in zip((n0, n1, n2), sub["fk"]):
                Q[n] = eul(r)
            return
        parent = self.rest[n0][2]
        h0, R0, _ = self.rest[n0]
        h1, R1, _ = self.rest[n1]
        h2, R2, _ = self.rest[n2]
        S = D[parent] @ (h0 - self.rest[parent][0]) + P[parent]
        self.last_root = getattr(self, "last_root", {})
        self.last_root[limb + "_" + side] = S.copy()   # where the limb starts (natural_arm.py reads it)
        Dg = None   # the hand's turn when the spec places the held item's grip instead of the wrist
        if limb == "arm" and ("hold" in sub or "grip" in sub or "gripc" in sub):
            hw, Rw, _ = self.rest["Weapon_" + side]
            if "hold" in sub:
                g, bd, be = self.attach_frame(sub["hold"], Q, D, P)
            else:
                bd, be = blade_dirs(*sub["blade"])
                if "grip" in sub:
                    g = Vector(sub["grip"])
                else:
                    ang, rad, z = sub["gripc"]
                    g = Vector((-rad * math.sin(math.radians(ang)), rad * math.cos(math.radians(ang)), z))
            Dg = frame(bd, be) @ Rw.transposed()
            W = g - Dg @ (hw - h2)
        elif "ikc" in sub:
            ang, rad, z = sub["ikc"]
            t = math.radians(ang)
            W = Vector((-rad * math.sin(t), rad * math.cos(t), z))
        elif "ikr" in sub:
            W = S + Vector(sub["ikr"])  # relative to the (posed) shoulder
        else:
            W = Vector(sub.get("ik", sub.get("ankle")))
        default_pole = (0.0, 1.0, 0.0) if limb == "leg" else ((0.4 if side == "R" else -0.4), -1.0, -0.2)
        pole = Vector(sub.get("pole", default_pole)).normalized()
        a, b = (h1 - h0).length, (h2 - h1).length
        d = W - S
        dist = min(max(d.length, abs(a - b) + 1e-4), (a + b) * 0.9995)
        dh = d.normalized() if d.length > 1e-6 else Vector((0, 0, -1))
        pp = pole - dh * pole.dot(dh)
        if pp.length < 1e-4:
            pp = dh.orthogonal()
        pp.normalize()
        ca = (a * a + dist * dist - b * b) / (2 * a * dist)
        sa = math.sqrt(max(0.0, 1 - ca * ca))
        E = S + (dh * ca + pp * sa) * a
        Wc = S + dh * dist
        u, f = (E - S).normalized(), (Wc - E).normalized()
        bend = f - u * f.dot(u)
        if bend.length > 0.02:
            z0 = bend.normalized() if limb == "arm" else -bend.normalized()
        else:
            perp = pp - u * pp.dot(u)
            z0 = (-perp if limb == "arm" else perp).normalized()
        F0 = frame(u, z0)
        x0 = F0.col[0].to_3d()
        zf = x0.cross(f)  # the lower bone, bent about the same hinge with no twist
        # The end bone: hand / foot orientation.
        D2 = None
        if limb == "arm":
            if Dg is not None:
                D2 = Dg
            elif "blade" in sub:
                bd, be = blade_dirs(*sub["blade"])
                Rw = self.rest["Weapon_" + side][1]
                D2 = frame(bd, be) @ Rw.transposed()
            elif "hand_aim" in sub:
                hd, hu = sub["hand_aim"]
                D2 = frame(Vector(hd), Vector(hu)) @ R2.transposed()
        else:
            pitch, yaw = sub.get("foot", (0.0, 0.0))
            D2 = eul((0, 0, yaw)) @ eul((pitch, 0, 0))
        if D2 is not None and limb == "arm":
            # Share the wrist's twist with the forearm so the wrist doesn't wring.
            zh = (D2 @ R2).col[2].to_3d()
            zh = zh - f * zh.dot(f)
            if zh.length > 1e-4:
                mixed = zf.normalized() + zh.normalized()
                zf = mixed if mixed.length > 0.2 else zh
        F1 = frame(f, zf)
        D0 = F0 @ R0.transposed()
        D1 = F1 @ R1.transposed()
        if D2 is None:
            D2 = D1 @ eul(sub.get("hand", (0, 0, 0)))
        Q[n0] = D[parent].transposed() @ D0
        Q[n1] = D0.transposed() @ D1
        Q[n2] = D1.transposed() @ D2


# ---------------------------------------------------------------- blending pose dicts
def blend(values, weights):
    """Weighted mix of poses (nested dicts / tuples / numbers). Strings: the heaviest wins."""
    first = next(v for v in values if v is not None)
    if isinstance(first, dict):
        out = {}
        keys = []
        for v in values:
            for k in v:
                if k not in keys:
                    keys.append(k)
        for k in keys:
            have = [v[k] for v in values if k in v]
            out[k] = blend([v[k] if k in v else have[0] for v in values], weights)
        return out
    if isinstance(first, (tuple, list)):
        return type(first)(blend([v[i] for v in values], weights) for i in range(len(first)))
    if isinstance(first, (int, float)):
        return sum(v * w for v, w in zip(values, weights))
    return values[max(range(len(weights)), key=lambda i: weights[i])]


EASE = {
    "lin": lambda t: t,
    "io": lambda t: t * t * (3 - 2 * t),
    "in": lambda t: t * t,
    "out": lambda t: 1 - (1 - t) * (1 - t),
    "snap": lambda t: 1 - (1 - t) ** 3,      # fast start, soft landing (a cut)
    "whip": lambda t: t * t * t * (t * (6 * t - 15) + 10),  # slow-fast-slow, sharper than io
    "hold": lambda t: 0.0,
}


def keyed(keys, loop_len=None):
    """A function of time from keys [(time, pose, ease_to_next)]. With loop_len the keys wrap
    and play through a smooth curve (Catmull-Rom)."""
    keys = [(k[0], k[1], k[2] if len(k) > 2 else "io") for k in keys]

    def at(t):
        if loop_len:
            t = t % loop_len
            n = len(keys)
            times = [k[0] for k in keys]
            i = max(j for j in range(n) if times[j] <= t)
            t0 = times[i]
            t1 = times[i + 1] if i + 1 < n else loop_len + times[0]
            s = (t - t0) / (t1 - t0)
            p = [keys[(i + o) % n][1] for o in (-1, 0, 1, 2)]
            w = [(-s ** 3 + 2 * s ** 2 - s) / 2, (3 * s ** 3 - 5 * s ** 2 + 2) / 2,
                 (-3 * s ** 3 + 4 * s ** 2 + s) / 2, (s ** 3 - s ** 2) / 2]
            return blend(p, w)
        if t <= keys[0][0]:
            return keys[0][1]
        for (t0, p0, e), (t1, p1, _) in zip(keys, keys[1:]):
            if t0 <= t <= t1:
                s = EASE[e]((t - t0) / (t1 - t0)) if t1 > t0 else 1.0
                return blend([p0, p1], [1 - s, s])
        return keys[-1][1]
    return at


# ---------------------------------------------------------------- writing actions
def make_action(rig, name, pose_at, length, loop=False):
    """Bakes pose_at(t) into an action called `name` (`name_loop` if it loops, which Godot turns
    into a looping animation called `name`)."""
    arm = rig.arm
    act = bpy.data.actions.new(name + ("_loop" if loop else ""))
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    frames = max(1, round(length * FPS))
    prev = {}
    for f in range(frames + 1):
        Q, loc = rig.solve(pose_at(f / FPS))
        for b in rig.order:
            h, R, parent = rig.rest[b]
            q = (R.transposed() @ Q.get(b, I3) @ R).to_quaternion()
            if b in prev and prev[b].dot(q) < 0:
                q.negate()
            prev[b] = q
            pb = arm.pose.bones[b]
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f, group=b)
        hp = arm.pose.bones["Hips"]
        hp.location = rig.rest["Hips"][1].transposed() @ loc
        hp.keyframe_insert("location", frame=f, group="Hips")
    arm.animation_data.action = None
    return act


def reset_pose(arm):
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
