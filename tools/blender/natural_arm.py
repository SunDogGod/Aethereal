"""Keeps a sword arm human: picks where the elbow points and how far the blade turns in the hand.

A swing key says where the wrist goes ('ikc' or 'ik') and where the blade points ('blade': yaw,
pitch, roll). Many elbows reach that wrist (the elbow can swing round the shoulder-wrist line),
and some blade rolls look the same from the camera; most of them bend the wrist backwards or
wring the forearm. natural() tries them all and keeps the one with the least strain:

    pose = natural(rig, pose)                 # the right arm (pole and roll rewritten)
    pose = natural(rig, pose, roll_tol=30)    # keep the edge within 30 degrees of what the key says

Strain counts (degrees): the wrist bent beyond WRIST_FREE from straight (the hand holds the grip at
right angles to the forearm, so "straight" is the blade across the forearm, its edge leading),
the wrist twisting, the forearm twisting beyond its range, the elbow lifted above the
shoulder-wrist line or tucked into the body. report() prints the same numbers for a pose.
"""
import math
from mathutils import Vector, Quaternion
from pose import blade_dirs, frame

WRIST_FREE = 35.0     # the wrist bends this far without cost (a sword grip sits diagonally)
TWIST_FREE = 20.0     # ...and twists this far
FOREARM_FREE = 75.0   # the forearm turns (pronation) this far from the elbow's hinge
ELBOW_UP = 0.03       # metres the elbow may sit above the shoulder-wrist line
BODY_R = 0.17         # the elbow stays this far from the spine (in plan)
UPPER_REST, UPPER_FREE = -20.0, 70.0   # the upper arm turns about itself this far from its rest


def _swing_twist(q):
    """Split a bone's turn into swing (degrees off its rest direction) and twist about itself."""
    t = Quaternion((q.w, 0.0, q.y, 0.0))
    if t.magnitude < 1e-9:
        return 180.0, 0.0
    t.normalize()
    tw = math.degrees(2 * math.atan2(t.y, t.w))
    tw = (tw + 180.0) % 360.0 - 180.0
    sw = q @ t.conjugated()
    return math.degrees(2 * math.acos(min(1.0, abs(sw.w)))), tw


def _wrist(rig, arm, side):
    """Where the wrist goes: given directly ('ikc', 'ik'), or found from the grip ('gripc', 'grip')
    and the blade's direction and roll (the hand sits behind the grip)."""
    if "ikc" in arm:
        ang, rad, z = arm["ikc"]
        t = math.radians(ang)
        return Vector((-rad * math.sin(t), rad * math.cos(t), z))
    if "gripc" in arm or "grip" in arm:
        if "gripc" in arm:
            ang, rad, z = arm["gripc"]
            g = Vector((-rad * math.sin(math.radians(ang)), rad * math.cos(math.radians(ang)), z))
        else:
            g = Vector(arm["grip"])
        hw, Rw, _ = rig.rest["Weapon_" + side]
        return g - (frame(*blade_dirs(*arm["blade"])) @ Rw.transposed()) @ (hw - rig.head("Hand_" + side))
    return Vector(arm["ik"])


def _solve(rig, pose, side):
    """rig.solve, with every bone (the captain's animations drop his right arm from rig.order)."""
    if "UpperArm_" + side in rig.order:
        return rig.solve(pose)
    kids = {}
    for name, (_, _, parent) in rig.rest.items():
        kids.setdefault(parent, []).append(name)
    order = []

    def visit(b):
        order.append(b)
        for c in kids.get(b, []):
            visit(c)
    for root in kids.get(None, []):
        visit(root)
    saved, rig.order = rig.order, order
    try:
        return rig.solve(pose)
    finally:
        rig.order = saved


def measure(rig, pose, side="R"):
    """The strain numbers of a pose: dict of reach, elbow (bend), wrist, wtwist, ftwist, elbow_up,
    elbow_in, and the elbow position."""
    Q, _ = _solve(rig, pose, side)
    out = {}
    for key, bone in (("u", "UpperArm_"), ("f", "LowerArm_"), ("h", "Hand_")):
        R = rig.rest[bone + side][1]
        out[key] = _swing_twist((R.transposed() @ Q[bone + side] @ R).to_quaternion())
    S = rig.last_root["arm_" + side]
    W = _wrist(rig, pose["arm_" + side], side)
    a = (rig.head("LowerArm_" + side) - rig.head("UpperArm_" + side)).length
    b = (rig.head("Hand_" + side) - rig.head("LowerArm_" + side)).length
    return {"reach": (W - S).length / (a + b), "wrist": out["h"][0], "wtwist": out["h"][1],
            "ftwist": out["f"][1], "utwist": out["u"][1], "S": S, "W": W, "a": a, "b": b}


def _elbow(S, W, a, b, phi):
    d = W - S
    dist = min(max(d.length, abs(a - b) + 1e-4), (a + b) * 0.9995)
    dh = d.normalized()
    p1 = Vector((0, 0, -1)) - dh * Vector((0, 0, -1)).dot(dh)
    if p1.length < 1e-4:
        p1 = dh.orthogonal()
    p1.normalize()
    p2 = dh.cross(p1)
    ca = (a * a + dist * dist - b * b) / (2 * a * dist)
    sa = math.sqrt(max(0.0, 1 - ca * ca))
    out = p1 * math.cos(phi) + p2 * math.sin(phi)
    return S + dh * ca * a + out * sa * a, out, S + dh * dist


def strain(m, E, Wc):
    S = m["S"]
    cost = max(0.0, m["wrist"] - WRIST_FREE) ** 2 + max(0.0, abs(m["wtwist"]) - TWIST_FREE) ** 2
    cost += 0.5 * max(0.0, abs(m["ftwist"]) - FOREARM_FREE) ** 2
    cost += 0.5 * max(0.0, abs(m["utwist"] - UPPER_REST) - UPPER_FREE) ** 2
    mid = S.lerp(Wc, m["a"] / (m["a"] + m["b"]))
    cost += (max(0.0, (E.z - mid.z) - ELBOW_UP) * 800.0) ** 2
    cost += (max(0.0, BODY_R - Vector((E.x, E.y)).length) * 800.0) ** 2
    return cost


def natural(rig, pose, side="R", roll_tol=60.0, prev=None):
    """Returns the pose with arm_<side>'s pole and blade roll changed to the least strained ones
    (roll within roll_tol of the key's; a key may carry its own 'roll_tol' in the arm dict).
    prev: (roll, pole) chosen for the frame before, which the choice stays close to (so the
    elbow and the edge travel smoothly); without it the key's own pole is a gentle preference."""
    arm = dict(pose["arm_" + side])
    roll_tol = arm.pop("roll_tol", roll_tol)
    yaw, pitch, roll0 = arm["blade"]
    plain = dict(pose)
    plain["arm_" + side] = arm
    m = measure(rig, plain, side)
    S, W, a, b = m["S"], m["W"], m["a"], m["b"]
    if prev:
        roll_pref, pref, w_roll, w_pole = prev[0], Vector(prev[1]).normalized(), 0.04, 0.05
    else:
        roll_pref, pref, w_roll, w_pole = roll0, Vector(arm.get("pole", (0.4, -1.0, -0.2))).normalized(), 0.02, 0.015
    best = None
    rolls = [roll0 + r for r in range(-int(roll_tol), int(roll_tol) + 1, 10)]
    phis = [math.radians(x) for x in range(0, 360, 10)]
    for pass_ in range(2):
        if pass_ == 1:
            r_b, phi_b = best[1], best[2]
            rolls = [r_b + r for r in (-6, -3, 0, 3, 6) if abs(r_b + r - roll0) <= roll_tol]
            phis = [phi_b + math.radians(x) for x in (-6, -3, 0, 3, 6)]
        for roll in rolls:
            for phi in phis:
                W = _wrist(rig, dict(arm, blade=(yaw, pitch, roll)), side)
                E, out, Wc = _elbow(S, W, a, b, phi)
                cand = dict(plain)
                cand["arm_" + side] = dict(arm, blade=(yaw, pitch, roll), pole=tuple(out))
                c = strain(measure(rig, cand, side), E, Wc)
                c += w_pole * math.degrees(out.angle(pref, 0.0)) ** 2 + w_roll * (roll - roll_pref) ** 2
                if best is None or c < best[0]:
                    best = (c, roll, phi, tuple(out))
    out = dict(plain)
    out["arm_" + side] = dict(arm, blade=(yaw, pitch, best[1]), pole=best[3])
    return out


def _states(rig, p, side, step_roll=15, step_phi=15):
    """Every (roll, elbow) choice for one frame: [(strain, roll, pole vector)]."""
    arm = dict(p["arm_" + side])
    roll_tol = arm.pop("roll_tol")
    yaw, pitch, roll0 = arm["blade"]
    plain = dict(p)
    plain["arm_" + side] = arm
    m = measure(rig, plain, side)
    out = []
    n = int(roll_tol // step_roll)
    for r in range(-n, n + 1):
        roll = roll0 + r * step_roll
        for deg in range(0, 360, step_phi):
            W = _wrist(rig, dict(arm, blade=(yaw, pitch, roll)), side)
            E, pole, Wc = _elbow(m["S"], W, m["a"], m["b"], math.radians(deg))
            cand = dict(plain)
            cand["arm_" + side] = dict(arm, blade=(yaw, pitch, roll), pole=tuple(pole))
            out.append((strain(measure(rig, cand, side), E, Wc), roll, pole))
    return plain, out


def tracked(rig, pose_at, length, side="R", fps=30, w_roll=0.05, w_pole=0.05):
    """Wraps an animation (a function of time, `length` seconds) so its arm is natural all the
    way through: for every frame it weighs each elbow and edge roll, then picks the path through
    the frames with the least strain plus the least change from frame to frame (so the elbow and
    the edge travel smoothly). Frames whose arm has no 'roll_tol' (an already natural pose, like
    the guard a swing starts or ends in) stay exactly as they are."""
    times = [f / fps for f in range(round(length * fps) + 1)]
    solved = {}

    def solve():
        frames = []
        for t in times:
            p = pose_at(t)
            arm = p.get("arm_" + side, {})
            if "roll_tol" in arm and "blade" in arm:
                frames.append(_states(rig, p, side))
            else:
                frames.append((p, [(0.0, arm["blade"][2], Vector(arm["pole"]))] if "pole" in arm else None))
        # Viterbi: best total cost to reach each state of each frame.
        cost = [s[0] for s in frames[0][1]]
        back = []
        for i in range(1, len(frames)):
            prev, cur = frames[i - 1][1], frames[i][1]
            new, links = [], []
            for c, roll, pole in cur:
                best, arg = None, 0
                for j, (_, r0, p0) in enumerate(prev):
                    v = cost[j] + w_roll * (roll - r0) ** 2 + w_pole * math.degrees(pole.angle(p0, 0.0)) ** 2
                    if best is None or v < best:
                        best, arg = v, j
                new.append(best + c)
                links.append(arg)
            cost, back = new, back + [links]
        k = min(range(len(cost)), key=lambda j: cost[j])
        for i in range(len(frames) - 1, -1, -1):
            plain, states = frames[i]
            _, roll, pole = states[k]
            out = dict(plain)
            arm = dict(out["arm_" + side])
            arm["blade"] = (arm["blade"][0], arm["blade"][1], roll)
            arm["pole"] = tuple(pole)
            out["arm_" + side] = arm
            solved[times[i]] = out
            if i > 0:
                k = back[i - 1][k]

    def at(t):
        if not solved:
            solve()
        near = min(solved, key=lambda x: abs(x - t))
        if abs(near - t) < 1e-6:
            return solved[near]
        return natural(rig, pose_at(t), side)
    return at


def report(rig, pose, label="", side="R"):
    m = measure(rig, pose, side)
    arm = pose["arm_" + side]
    print("ARM %-10s reach %.2f wrist %4.0f wtwist %4.0f ftwist %4.0f utwist %4.0f roll %4.0f" % (
        label, m["reach"], m["wrist"], m["wtwist"], m["ftwist"], m["utwist"], arm.get("blade", (0, 0, 0))[2]))
    return m
