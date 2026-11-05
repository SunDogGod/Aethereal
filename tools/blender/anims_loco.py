"""Locomotion: idle, walk, run, sprint, crouch_idle, crouch_walk, jump, fall.

The walk, run, sprint and crouch_walk cycles are all one second long with the left heel landing
at 0, so Godot can blend them by speed and they stay in step. STRIDE says how far one cycle
carries him; character_animator.gd plays a cycle at speed / STRIDE cycles per second, which keeps
the feet planted. Cycles are written as functions of the phase (0..1) instead of keys.
"""
import math
from pose import make_action, keyed

STRIDE = {"walk": 1.5, "run": 3.4, "sprint": 4.8, "crouch_walk": 1.9}
TAU = math.pi * 2


def _sm(a, b, t):
    t = min(1.0, max(0.0, (t - a) / (b - a))) if b != a else float(t >= a)
    return t * t * (3 - 2 * t)


def _pw(t, pts):
    """Smooth piecewise curve through (t, value) points (t in 0..1)."""
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if t <= t1:
            k = _sm(t0, t1, t)
            return v0 + (v1 - v0) * k
    return pts[-1][1]


class Gait:
    """Numbers for one cycle. Distances are for a 1.72 m body."""
    def __init__(self, stride, stance, land, lift, kick, width, pitch_land, pitch_off, swing_pitch, knee_y):
        self.stride, self.stance, self.land, self.lift, self.kick = stride, stance, land, lift, kick
        self.width, self.pitch_land, self.pitch_off, self.swing_pitch, self.knee_y = width, pitch_land, pitch_off, swing_pitch, knee_y


def foot_at(g, p, s, side):
    """Ankle position and foot pitch at foot phase p (0 = heel lands)."""
    travel = g.stride * g.stance
    y_land, y_off = g.land, g.land - travel
    if p < g.stance:
        k = p / g.stance
        y = y_land - travel * k
        pitch = _pw(k, [(0, g.pitch_land), (0.18, 0), (0.6, 0), (1.0, g.pitch_off)])
        lift = 0.0
    else:
        k = (p - g.stance) / (1 - g.stance)
        y = _pw(k, [(0, y_off), (0.3, y_off + (y_land - y_off) * 0.3), (0.75, y_land + 0.04), (1.0, y_land)])
        lift = g.lift * math.sin(math.pi * min(1.0, k * 1.15)) + g.kick * math.sin(math.pi * min(1.0, k * 2.2)) ** 2 * (k < 0.46)
        pitch = _pw(k, [(0, g.pitch_off), (0.3, g.swing_pitch), (0.75, 0), (1.0, g.pitch_land)])
    return ankle_with_roll(side * g.width, y, lift, pitch, s), pitch


def ankle_with_roll(x, y, lift, pitch, s):
    """Rolling over the toe when the heel lifts (pitch < 0), over the heel when the toes lift."""
    r = math.radians(pitch)
    c, sn = math.cos(r), math.sin(r)
    if pitch < 0:   # pivot on the ball of the foot (0.145 ahead of the ankle, 0.03 up)
        ay = y + 0.145 - 0.145 * c - 0.055 * sn
        az = 0.03 - 0.145 * sn + 0.055 * c
    else:           # pivot on the heel (0.06 behind the ankle, 0.01 up)
        ay = y - 0.06 + 0.06 * c - 0.075 * sn
        az = 0.01 + 0.06 * sn + 0.075 * c
    return (x * s, ay * s, (az + lift) * s)


def legs(g, phase, s):
    out = {}
    for side, key, off in ((-1, "leg_L", 0.0), (1, "leg_R", 0.5)):
        p = (phase + off) % 1.0
        ank, pitch = foot_at(g, p, s, side)
        out[key] = {"ankle": ank, "pole": (side * 0.12, 1.0, 0.0), "foot": (pitch, -side * 4.0)}
    return out


def bob_at(g, phase):
    """The body's rise and fall, -1..1, twice a cycle. A walk is highest over the straight standing
    leg (mid-stance) and lowest with both feet down; a run is the other way round: lowest at
    mid-stance, where the knee folds to take the landing, highest in the air between steps."""
    if g.stance >= 0.5:
        peak = g.stance / 2
    else:
        peak = g.stance + (0.5 - g.stance) / 2
    return math.cos(2 * TAU * (phase - peak))


def _cycle_pose(phase, s, g, hips_z, bob, lean, twist, roll, sway, arm_swing, arm_bend, sword):
    """One frame of a cycle. hips_z is the hips' height (metres from rest, so a bend in the knees),
    bob how far they rise and fall (bob_at), lean the forward lean of hips / spine / chest / neck /
    head, twist how far the hips and chest counter-rotate with the stride, roll the hips' side
    tilt, sway the sideways shift. The weight reads in what rides on top: the chest settles a
    little forward as the body drops, the head nods against it, the shoulders dip with the arm
    that swings forward."""
    c = math.cos(TAU * phase)
    b = bob_at(g, phase)
    pose = legs(g, phase, s)
    pose["hips"] = {"loc": (-sway * math.cos(TAU * (phase - g.stance / 2)) * s, 0.0, (hips_z + bob * b) * s),
                    "rot": (lean[0], roll * math.cos(TAU * (phase - g.stance / 2)), -twist * c)}
    settle = 60.0 * bob            # degrees of pitch per metre of drop: the torso folds with it
    pose["Spine"] = (lean[1] - settle * (1 - b) * 0.5, 0, twist * 0.8 * c)
    pose["Chest"] = (lean[2] - settle * (1 - b) * 0.5, 0, twist * 0.8 * c)
    pose["Neck"] = (lean[3] + settle * (1 - b) * 0.6, 0, -twist * 0.3 * c)
    pose["Head"] = (lean[4] + settle * (1 - b) * 0.6, 0, -twist * 0.3 * c)
    fwd_l = 0.5 - 0.5 * math.cos(TAU * (phase - 0.5))   # 1 when the left arm is forward
    fwd_r = 1.0 - fwd_l
    dip = 2.5 + 20.0 * bob         # the shoulder of the forward arm comes forward and down
    pose["Shoulder_L"] = (dip * (fwd_l - 0.5), 0, -dip * 0.6 * (fwd_l - 0.5))
    pose["Shoulder_R"] = (dip * (fwd_r - 0.5), 0, dip * 0.6 * (fwd_r - 0.5))
    ay, az = arm_swing
    pose["arm_L"] = {"ikr": ((-0.05 + 0.02 * fwd_l) * s, (-ay + 2 * ay * fwd_l) * s, (-arm_bend + az * fwd_l) * s),
                     "pole": (-0.3, -1.0, -0.2), "hand": (10, 0, -15)}
    sy, sz, yaw, pitch = sword
    pose["arm_R"] = {"ikr": (0.07 * s, (-sy + 2 * sy * fwd_r) * s, (-arm_bend - 0.03 + sz * fwd_r) * s),
                     "pole": (0.4, -1.0, -0.3), "blade": (yaw - 8 * fwd_r, pitch + 6 * fwd_r, 70)}
    return pose


WALK = Gait(1.5, 0.62, 0.47, 0.06, 0.03, 0.075, 18, -32, -12, 0)
RUN = Gait(3.4, 0.30, 0.32, 0.10, 0.22, 0.07, 8, -48, -65, 0)
SPRINT = Gait(4.8, 0.26, 0.36, 0.13, 0.30, 0.065, 6, -55, -75, 0)
CROUCH = Gait(1.9, 0.56, 0.52, 0.06, 0.04, 0.11, 10, -30, -20, 0)

# The author (2026-11-05): "he waddles left to right like some penguin, he doesn't go up and down,
# and he's stiff and weightless like a robot". So: the hips barely shift or tilt sideways, the
# body rises and falls for real (3.5 cm walking, 5-6 cm running, knees bending to take it), and
# the chest, head and shoulders move with the step.


def walk(rig, s):
    return lambda t: _cycle_pose(t, s, WALK, -0.05, 0.035, (-3, -3, 0, 2, 3), 6, 1.5, 0.005,
                                 (0.12, 0.05), 0.49, (0.06, 0.03, -5, -38))


def run(rig, s):
    return lambda t: _cycle_pose(t, s, RUN, -0.10, 0.05, (-10, -5, -1, 7, 7), 10, 2.0, 0.004,
                                 (0.22, 0.20), 0.33, (0.12, 0.08, -135, -26))


def sprint(rig, s):
    return lambda t: _cycle_pose(t, s, SPRINT, -0.12, 0.055, (-15, -7, -2, 10, 9), 12, 2.0, 0.003,
                                 (0.30, 0.26), 0.30, (0.10, 0.06, -142, -20))


def crouch_walk(rig, s):
    def at(t):
        p = _cycle_pose(t, s, CROUCH, -0.38, 0.02, (-24, -12, -4, 20, 12), 7, 1.5, 0.006,
                        (0.07, 0.04), 0.40, (0.05, 0.02, -28, -22))
        p["arm_L"]["ikr"] = (p["arm_L"]["ikr"][0] + 0.04 * s, p["arm_L"]["ikr"][1] + 0.16 * s, p["arm_L"]["ikr"][2] + 0.04 * s)
        return p
    return at


def idle(rig, s):
    def at(t):
        b = math.sin(TAU * t / 2.4)          # breath
        look = math.sin(TAU * t / 4.8)
        return {
            "hips": {"loc": (0.015 * s, 0.0, (-0.022 + 0.002 * b) * s), "rot": (0, -2.0, 3.0)},
            "Spine": (-1 + 0.5 * b, 1.0, -2.0), "Chest": (-0.8 * b, 0.5, -1.0),
            "Neck": (1.0, 0, 0.5 + look), "Head": (1.0 + 0.5 * b, 0, 1.5 * look),
            "Shoulder_L": (0, 0, -1.5 * b), "Shoulder_R": (0, 0, 1.5 * b),
            "leg_L": {"ankle": (-0.13 * s, 0.035 * s, 0.085 * s), "pole": (-0.25, 1, 0), "foot": (0, 9)},
            "leg_R": {"ankle": (0.12 * s, -0.04 * s, 0.085 * s), "pole": (0.2, 1, 0), "foot": (0, -7)},
            "arm_L": {"ikr": (-0.07 * s, 0.03 * s, (-0.50 + 0.005 * b) * s), "pole": (-0.3, -1, -0.2), "hand": (8, 0, -12)},
            "arm_R": {"ikr": (0.08 * s, 0.10 * s, (-0.47 + 0.005 * b) * s), "pole": (0.4, -1, -0.3),
                      "blade": (-16, -28 + b, 70)},
        }
    return at


def crouch_idle(rig, s):
    def at(t):
        b = math.sin(TAU * t / 2.0)
        return {
            "hips": {"loc": (0.0, -0.02 * s, (-0.38 + 0.004 * b) * s), "rot": (-24, 0, 4)},
            "Spine": (-12 + b, 0, -2), "Chest": (-4 - b, 0, -2), "Neck": (20, 0, 0), "Head": (12, 0, 0),
            "leg_L": {"ankle": (-0.13 * s, 0.17 * s, 0.085 * s), "pole": (-0.3, 1, 0), "foot": (0, 6)},
            "leg_R": {"ankle": (0.13 * s, -0.20 * s, 0.13 * s), "pole": (0.35, 1, 0), "foot": (-28, -6)},
            "arm_L": {"ikr": (0.02 * s, 0.26 * s, (-0.36 + 0.004 * b) * s), "pole": (-0.5, -1, 0.2), "hand": (20, 0, -10)},
            "arm_R": {"ikr": (0.10 * s, 0.10 * s, (-0.40 + 0.004 * b) * s), "pole": (0.5, -1, 0),
                      "blade": (-25, -24, 70)},
        }
    return at


def jump(rig, s):
    up = {"hips": {"loc": (0, 0, 0.02 * s), "rot": (-6, 0, 3)}, "Spine": (-2, 0, 0), "Chest": (2, 0, 0),
          "Neck": (2, 0, 0), "Head": (3, 0, 0),
          "leg_L": {"ankle": (-0.10 * s, 0.22 * s, 0.50 * s), "pole": (-0.1, 1, 0), "foot": (-10, 4)},
          "leg_R": {"ankle": (0.10 * s, -0.20 * s, 0.30 * s), "pole": (0.1, 1, 0), "foot": (-40, -4)},
          "arm_L": {"ikr": (-0.18 * s, 0.10 * s, -0.30 * s), "pole": (-1, -0.5, -0.2), "hand": (0, 0, -20)},
          "arm_R": {"ikr": (0.20 * s, 0.05 * s, -0.33 * s), "pole": (1, -0.5, -0.2), "blade": (-40, -10, 70)}}
    take = {"hips": {"loc": (0, 0, -0.06 * s), "rot": (-10, 0, 0)}, "Spine": (-4, 0, 0), "Chest": (0, 0, 0),
            "leg_L": {"ankle": (-0.10 * s, 0.10 * s, 0.10 * s), "pole": (-0.1, 1, 0), "foot": (-10, 4)},
            "leg_R": {"ankle": (0.10 * s, -0.10 * s, 0.10 * s), "pole": (0.1, 1, 0), "foot": (-25, -4)},
            "arm_L": {"ikr": (-0.10 * s, -0.12 * s, -0.42 * s), "pole": (-0.5, -1, -0.2)},
            "arm_R": {"ikr": (0.12 * s, -0.12 * s, -0.42 * s), "pole": (0.5, -1, -0.2), "blade": (-120, -30, 70)}}
    return keyed([(0.0, take, "out"), (0.25, up, "io"), (0.5, up)])


def fall(rig, s):
    def at(t):
        w = math.sin(TAU * t / 0.8)
        return {"hips": {"loc": (0, 0, 0.0), "rot": (-4 + 2 * w, 0, 0)}, "Spine": (2, 0, 2 * w), "Chest": (3, 0, 0),
                "Neck": (-4, 0, 0), "Head": (-3, 0, 0),
                "leg_L": {"ankle": (-0.13 * s, 0.10 * s, (0.22 + 0.04 * w) * s), "pole": (-0.2, 1, 0), "foot": (-20, 6)},
                "leg_R": {"ankle": (0.13 * s, -0.05 * s, (0.18 - 0.04 * w) * s), "pole": (0.2, 1, 0), "foot": (-25, -6)},
                "arm_L": {"ikr": (-0.30 * s, (0.05 + 0.04 * w) * s, (-0.16 + 0.03 * w) * s), "pole": (-0.3, -1, -0.6)},
                "arm_R": {"ikr": (0.30 * s, (0.05 - 0.04 * w) * s, (-0.18 - 0.03 * w) * s), "pole": (0.3, -1, -0.6),
                          "blade": (-60, -5, 70)}}
    return at


def add_all(rig):
    s = rig.head("Hips").z / 0.93
    make_action(rig, "idle", idle(rig, s), 2.4, loop=True)
    make_action(rig, "walk", walk(rig, s), 1.0, loop=True)
    make_action(rig, "run", run(rig, s), 1.0, loop=True)
    make_action(rig, "sprint", sprint(rig, s), 1.0, loop=True)
    make_action(rig, "crouch_idle", crouch_idle(rig, s), 2.0, loop=True)
    make_action(rig, "crouch_walk", crouch_walk(rig, s), 1.0, loop=True)
    make_action(rig, "jump", jump(rig, s), 0.5)
    make_action(rig, "fall", fall(rig, s), 0.8, loop=True)
