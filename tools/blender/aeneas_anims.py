"""Aeneas's own animations, on top of the shared sets (anims_loco.py, anims_combat.py):

  idle / walk / run / sprint / crouch_idle / crouch_walk / jump / fall: the shared cycles (sword
      drawn), except that his free left arm swings back less, so it stays under the poncho
  idle / walk / run / sprint / crouch_idle / crouch_walk + "_sheathed": the same legs as the
      shared cycles (so Godot can blend between them in step), but the sword is in its scabbard:
      his left hand holds the scabbard by the mouth, thumb on the guard, and his right arm swings.
  iai          the drawn-in stance (held): right hand on the hilt, knees bent, body turned a little;
               the last part deepens for up to 0.6 s of charge
  draw_cut     the cross-body quick draw: out of the scabbard at his left hip and straight into a
               left-to-right cut; the blade crosses his front at DRAW_HIT seconds
  sheathe      the blade back into the scabbard (an upper-body action, so he can walk meanwhile);
               it is home at SHEATHE_HOME seconds
The game uses the same numbers: DRAW_HIT in scripts/character_animator.gd and SHEATHE_HOME in
scripts/character_anim_layers.gd, so change both sides together.
"""
import math
from pose import make_action, keyed
import anims_loco as L
import anims_combat as K

DRAW_HIT = 0.105
SHEATHE_HOME = 0.50
HOLD_T = 0.115     # the left hand grips the scabbard this far below the sword's grip (at the mouth)
ROLL_L = 180.0     # ...from above, fingers down round it
ROLL_R = 0.0       # the right hand on the hilt: edge up, as the sword sits in the scabbard
TAU = math.pi * 2


def left_hold(s):
    return {"hold": ("Scabbard", HOLD_T * s, ROLL_L), "pole": (-0.75, -0.65, -0.1)}


def free_right(s, x, y, z, hand=(10, 0, 15)):
    return {"ikr": (x * s, y * s, z * s), "pole": (0.35, -1.0, -0.2), "hand": hand}


# ---------------------------------------------------------------- carrying the sheathed sword
def _carry(base, arm_swing, arm_bend, extra=(0.0, 0.0, 0.0), sway=2.0):
    """Wraps a shared cycle: same legs and body, left hand on the scabbard, right arm swinging."""
    def at(t, s):
        p = base(t)
        fwd_r = 0.5 + 0.5 * math.cos(TAU * (t - 0.5))   # 1 when the right arm is forward
        ay, az = arm_swing
        p["arm_R"] = free_right(s, 0.05 - 0.02 * fwd_r + extra[0], ay * (-0.35 + 1.35 * fwd_r) + extra[1],
                                -arm_bend + az * fwd_r + extra[2])
        p["arm_L"] = left_hold(s)
        p["Scabbard"] = (0, 0, sway * math.sin(TAU * t))   # it swings a little with his stride
        return p
    return at


def add_loco(rig, s):
    """The shared locomotion (anims_loco.add_all), except that his free left arm swings back less
    while the sword is drawn, so it doesn't push out through the back of the poncho."""
    swings = {"walk": 0.12, "run": 0.22, "sprint": 0.30}

    def tame(base, ay):
        def at(t):
            p = base(t)
            fwd_l = 0.5 - 0.5 * math.cos(TAU * (t - 0.5))
            x, _, z = p["arm_L"]["ikr"]
            p["arm_L"]["ikr"] = (x, ay * (-0.35 + 1.35 * fwd_l) * s, z)
            return p
        return at
    make_action(rig, "idle", L.idle(rig, s), 2.4, loop=True)
    for name, fn in (("walk", L.walk), ("run", L.run), ("sprint", L.sprint)):
        make_action(rig, name, tame(fn(rig, s), swings[name]), 1.0, loop=True)
    make_action(rig, "crouch_idle", L.crouch_idle(rig, s), 2.0, loop=True)
    make_action(rig, "crouch_walk", L.crouch_walk(rig, s), 1.0, loop=True)
    make_action(rig, "jump", L.jump(rig, s), 0.5)
    make_action(rig, "fall", L.fall(rig, s), 0.8, loop=True)


def add_carry(rig, s):
    cycles = {
        "walk": (L.walk(rig, s), (0.12, 0.05), 0.49, (0, 0, 0)),
        "run": (L.run(rig, s), (0.22, 0.20), 0.33, (0, 0, 0)),
        "sprint": (L.sprint(rig, s), (0.30, 0.26), 0.30, (0, 0, 0)),
        "crouch_walk": (L.crouch_walk(rig, s), (0.07, 0.04), 0.40, (-0.04, 0.16, 0.04)),
    }
    for name, (base, swing, bend, extra) in cycles.items():
        at = _carry(base, swing, bend, extra)
        make_action(rig, name + "_sheathed", lambda t, at=at: at(t, s), 1.0, loop=True)
    idle = L.idle(rig, s)
    def idle_at(t):
        p = idle(t)
        b = math.sin(TAU * t / 2.4)
        p["arm_R"] = free_right(s, 0.07, 0.03, -0.50 + 0.005 * b, (8, 0, 12))
        p["arm_L"] = left_hold(s)
        return p
    make_action(rig, "idle_sheathed", idle_at, 2.4, loop=True)
    crouch = L.crouch_idle(rig, s)
    def crouch_at(t):
        p = crouch(t)
        b = math.sin(TAU * t / 2.0)
        p["arm_R"] = {"ikr": (-0.02 * s, 0.26 * s, (-0.36 + 0.004 * b) * s), "pole": (0.5, -1, 0.2), "hand": (20, 0, 10)}
        p["arm_L"] = left_hold(s)
        return p
    make_action(rig, "crouch_idle_sheathed", crouch_at, 2.0, loop=True)


# ---------------------------------------------------------------- the draw
def iai_pose(s, depth):
    """Right hand on the hilt, left on the scabbard's mouth, knees bent; depth 0..1 deepens it."""
    return K.P(K.torso(26 + 8 * depth, -14 - 6 * depth, 0, (0.0, -0.02, -0.09 - 0.05 * depth), s, hips_share=0.2),
               K.stance(s, front=0.17, back=-0.15, width=0.15),
               {"arm_R": {"hold": ("Scabbard", 0.0, ROLL_R), "pole": (0.6, -0.5, -0.6)},
                "arm_L": left_hold(s), "Scabbard": (0, 0, 6 + 6 * depth), "Shoulder_R": (0, -4, 28)})


def iai(rig, s):
    return keyed([(0.0, iai_pose(s, 0.0), "snap"), (0.10, iai_pose(s, 0.25), "io"), (0.6, iai_pose(s, 1.0))])


def _held(rig, s, p, t, scab):
    """Pose p with the right hand gripping the sword t metres out of the scabbard (0 = home),
    written as a free grip so it blends with swinging keys."""
    p = dict(p)
    p["arm_R"] = {"hold": ("Scabbard", t * s, ROLL_R), "pole": (0.6, -0.45, -0.65)}
    p["arm_L"] = left_hold(s)
    p["Scabbard"] = (0, 0, scab)
    return rig.hold_as_grip(p, "R", ref_yaw=170.0)


def _swing(rig, s, twist, lean, loc, ang, rad, h, yaw, pitch, roll, scab, feet=None):
    """A key with the blade held freely (written as a grip) and the left hand still on the scabbard."""
    p = K.P(K.torso(twist, lean, 0, loc, s), feet or K.stance(s, front=0.17, back=-0.15, width=0.15),
            K.sword_arm(s, ang, rad, h, yaw, pitch, roll, (0.5, -0.3, -0.9)),
            {"arm_L": left_hold(s), "Scabbard": (0, 0, scab)})
    return rig.ikc_as_grip(p, "R")


def draw_cut(rig, s):
    """From the iai stance: the hand pulls the blade along the scabbard while the left hand turns
    the scabbard's mouth forward, the blade comes free beside his left hip and sweeps across. The
    left hand keeps hold of the scabbard all through (it lets go as the cut blends out)."""
    k0 = _held(rig, s, iai_pose(s, 0.35), 0.0, 9)
    pull = K.P(iai_pose(s, 0.35), K.torso(11, -11, 0, (0.0, -0.01, -0.12), s, hips_share=0.25))
    k1 = _held(rig, s, pull, -0.26, 32)
    out = _swing(rig, s, 30, -10, (0, 0.0, -0.12), 70, 0.40, 1.02, 118, -4, -30, 26)
    hit = _swing(rig, s, 0, -9, (0, 0.04, -0.10), 4, 0.53, 1.10, 4, 3, 0, 10)
    c = _swing(rig, s, -30, -8, (0, 0.05, -0.09), -40, 0.52, 1.12, -72, 2, 0, 2)
    d = _swing(rig, s, -46, -6, (0, 0.03, -0.08), -76, 0.43, 1.11, -136, -6, 0, 0)
    e = _swing(rig, s, -44, -5, (0, 0.02, -0.07), -82, 0.38, 1.07, -150, -14, 0, 0)
    end = _swing(rig, s, -8, -3, (0, 0, -0.05), -22, 0.30, 0.98, -10, -32, 70, 0, K.stance(s))
    return keyed([(0.0, k0, "lin"), (0.035, k1, "lin"), (0.068, out, "lin"), (DRAW_HIT, hit, "lin"),
                  (0.135, c, "out"), (0.18, d, "out"), (0.26, e, "io"), (0.5, end)])


def sheathe(rig, s):
    """Upper body: the blade comes across, its tip finds the mouth of the scabbard (the left
    hand turns it to meet it) and slides home; the right hand lets go as the action blends out
    into his walk (character_animator.gd)."""
    body = K.P(K.torso(30, -13, 0, (0.015, 0.0, -0.022), s), K.stance(s),
               {"hips": {"loc": (0.015 * s, 0.0, -0.022 * s), "rot": (0, -2.0, 3.0)}, "Shoulder_R": (0, -4, 32)})
    start = _swing(rig, s, -8, -3, (0, 0, -0.05), -22, 0.30, 0.98, -10, -32, 70, 0, K.stance(s))
    across = _swing(rig, s, 14, -4, (0.015, 0.0, -0.022), 62, 0.36, 1.16, 150, -22, -90, 22, K.stance(s))
    mouth = _held(rig, s, body, -0.42, 22)
    home = _held(rig, s, body, 0.0, 4)
    return keyed([(0.0, start, "io"), (0.16, across, "io"), (0.30, mouth, "in"), (SHEATHE_HOME, home, "io"),
                  (0.65, home)])


def add_all(rig):
    s = rig.head("Hips").z / 0.93
    add_loco(rig, s)
    add_carry(rig, s)
    make_action(rig, "iai", iai(rig, s), 0.6)
    make_action(rig, "draw_cut", draw_cut(rig, s), 0.5)
    make_action(rig, "sheathe", sheathe(rig, s), 0.65)
