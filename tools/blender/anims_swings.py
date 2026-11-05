"""The horizontal sword swings (everyone with a sword: Aeneas, Kael, the agents, the captain
mirrored). Seen from the camera behind him:
  windup_L   cocked across his body to his LEFT (held; deepens over 0.6 s of charge)
  sweep_LR   the cut, left to right: the elbow leads, the arm reaches out as the blade crosses
             his front (SWEEP_HIT, anims_combat.py) and the follow-through rises over his right
             shoulder, the wrist turning over
  windup_R   cocked out to his RIGHT for the return stroke (held)
  sweep_RL   the return cut, right to left, finishing high by his left shoulder
Every frame goes through natural_arm.tracked(), which picks the elbow and the blade's roll that
keep the wrist and forearm in a human range, so a key only says where the hand goes and where the
blade points.

A key row: (time, ease to the next key, twist, lean, forward, drop, wrist angle, radius, height,
blade yaw, blade pitch, left hand (x, y, z) from his left shoulder, right shoulder (x, y, z),
how far the edge may roll from the key's own). Twist + = his body turned to his left; lean - =
forward; forward / drop move his hips (metres); wrist angle 0 = straight ahead, + = his left;
blade yaw 0 = ahead, + = his left; pitch + = point up. Right shoulder: y - lifts it, z + brings
it forward (reaching).
"""
from pose import keyed
import anims_combat as K
from natural_arm import tracked

L_HAND = (-0.10, 0.16, -0.34)
R_HAND = (-0.12, 0.08, -0.36)   # free hands stay in front: behind him they push through the poncho

COCKED_L = (42, -4, -0.01, 0.06, 80, 0.34, 1.18, 140, 10, L_HAND, (0, 0, 16))
DEEP_L = (60, -7, -0.02, 0.09, 98, 0.36, 1.16, 154, 12, (-0.14, 0.22, -0.30), (0, 0, 22))
COCKED_R = (-42, -4, -0.01, 0.06, -80, 0.36, 1.20, -140, 14, R_HAND, (0, -6, -4))
DEEP_R = (-58, -7, -0.02, 0.09, -94, 0.38, 1.22, -154, 18, (-0.14, 0.06, -0.34), (0, -10, -8))

# Left to right. The blade lags his hand, crosses his front just after SWEEP_HIT (0.07 s) with his
# arm reaching, then the wrist turns over (the edge rolls up) as the follow-through rises.
# The last two numbers: the edge roll (0 = edge leading the cut) and how far tracked() may vary it.
# The cuts are DEEP (the author, 2026-11-05: "deep, and he bends his knees"): he sinks 20 cm into
# his knees and leans into the cut, his hips driving 16 cm forward, the blade passing low at
# chest height and finishing out past his body before the follow-through rises.
SWEEP_LR = [
    (0.00, "in", 48, -6, -0.01, 0.10, 82, 0.34, 1.12, 146, 9, L_HAND, (0, 0, 18), 0, 60),
    (0.04, "lin", 24, -14, 0.06, 0.16, 34, 0.52, 1.06, 100, 2, (-0.12, 0.10, -0.34), (0, 0, 16), 10, 45),
    (K.SWEEP_HIT, "lin", -4, -22, 0.16, 0.22, -14, 0.72, 0.98, 12, 0, (-0.14, 0.0, -0.32), (0, -2, 18), 20, 30),
    (0.10, "out", -26, -20, 0.17, 0.21, -48, 0.62, 1.04, -64, 10, (-0.14, 0.06, -0.32), (0, -6, 10), -30, 45),
    (0.14, "out", -40, -14, 0.14, 0.17, -68, 0.50, 1.22, -110, 30, (-0.14, 0.08, -0.32), (0, -12, 2), -60, 45),
    (0.22, "io", -44, -8, 0.08, 0.12, -62, 0.36, 1.40, -150, 46, (-0.12, 0.10, -0.34), (0, -16, 0), -80, 45),
]
# Right to left (the return stroke), as deep, finishing high by his left shoulder.
SWEEP_RL = [
    (0.00, "in", -44, -6, -0.01, 0.10, -82, 0.36, 1.14, -146, 12, R_HAND, (0, -6, -4), 180, 60),
    (0.04, "lin", -22, -14, 0.06, 0.16, -40, 0.52, 1.06, -104, 3, (-0.12, 0.08, -0.34), (0, -2, 8), 180, 45),
    (K.SWEEP_HIT, "lin", 4, -22, 0.16, 0.22, 4, 0.70, 0.98, -12, 0, (-0.14, 0.04, -0.32), (0, -2, 20), 165, 30),
    (0.10, "out", 26, -20, 0.17, 0.21, 36, 0.56, 1.04, 66, 10, (-0.14, 0.12, -0.32), (0, -4, 22), 135, 45),
    (0.14, "out", 40, -14, 0.14, 0.17, 52, 0.44, 1.20, 110, 28, (-0.12, 0.16, -0.32), (0, -8, 22), 115, 45),
    (0.22, "io", 46, -8, 0.08, 0.12, 52, 0.30, 1.36, 148, 44, (-0.10, 0.16, -0.34), (0, -12, 18), 95, 45),
]

# The heavy: a cleave (the author, 2026-11-05: "light = low cuts, heavy = cleave"). Wound up high
# over his right shoulder (windup_high: held, the hilt by his ear, the point up and back), then
# a diagonal cut down to his left with a lunge: his left foot steps 40 cm out, his hips drive
# forward and down (knees deep), the blade crosses his front at CLEAVE_HIT and finishes low past
# his left hip. Same columns as the sweeps.
CLEAVE_HIT = 0.13     # scripts/character_animator.gd has the same number
COCKED_HIGH = (-30, 6, -0.03, 0.06, -40, 0.22, 1.62, -150, 70, (-0.12, 0.10, -0.32), (0, -14, -6))
DEEP_HIGH = (-40, 10, -0.05, 0.08, -50, 0.18, 1.66, -160, 78, (-0.14, 0.12, -0.30), (0, -18, -10))
LUNGE = {"front": 0.42, "back": -0.10, "width": 0.15}
CLEAVE = [
    (0.00, "in", -38, 8, -0.04, 0.08, -48, 0.20, 1.64, -156, 76, (-0.14, 0.12, -0.30), (0, -18, -8), 180, 60),
    (0.06, "lin", -16, -4, 0.06, 0.14, -20, 0.42, 1.58, -70, 50, (-0.14, 0.10, -0.32), (0, -10, 6), 180, 45),
    (CLEAVE_HIT, "lin", 10, -24, 0.20, 0.26, 10, 0.74, 1.00, 20, -20, (-0.14, 0.04, -0.32), (0, -2, 20), 170, 30),
    (0.17, "out", 28, -26, 0.24, 0.30, 36, 0.62, 0.74, 70, -50, (-0.12, 0.10, -0.32), (0, 0, 20), 160, 45),
    (0.24, "out", 36, -22, 0.24, 0.28, 48, 0.44, 0.62, 110, -60, (-0.10, 0.14, -0.34), (0, 0, 16), 150, 45),
    (0.36, "io", 30, -14, 0.18, 0.20, 40, 0.34, 0.80, 120, -40, (-0.10, 0.14, -0.34), (0, -4, 12), 140, 45),
]


def key(s, row, roll, roll_tol=60, feet=None):
    """A raw key: tracked() picks its elbow and edge roll frame by frame (natural_arm.py)."""
    twist, lean, fwd, drop, ang, rad, h, yaw, pitch, free, shoulder = row
    p = K.P(K.torso(twist, lean, 0, (0.0, fwd, -drop), s), feet or K.stance(s),
            K.sword_arm(s, ang, rad, h, yaw, pitch, roll, (0.5, -0.5, -0.7)),
            K.free_arm(s, *free, pole=(-0.6, -0.2, -0.8)),   # elbow down and out, not back through the poncho
            {"Shoulder_R": shoulder})
    p["arm_R"]["roll_tol"] = roll_tol
    return p


def _guard_near(s, roll):
    """The guard pose with its blade roll written within 180 degrees of `roll` (the same pose), so
    a swing settling into it turns the edge the short way round."""
    g = dict(K.guard_pose(s))
    arm = dict(g["arm_R"])
    yaw, pitch, r = arm["blade"]
    r += 360.0 * round((roll - r) / 360.0)
    arm["blade"] = (yaw, pitch, r)
    g["arm_R"] = arm
    return g


def windup(rig, s, side):
    """side 1: cocked to his left (opens a left-to-right cut); -1: cocked to his right."""
    roll = 0 if side > 0 else 180
    cocked, deep = (COCKED_L, DEEP_L) if side > 0 else (COCKED_R, DEEP_R)
    return tracked(rig, keyed([(0.0, K.guard_pose(s), "snap"), (0.09, key(s, cocked, roll), "io"),
                               (0.6, key(s, deep, roll))]), 0.6)


def sweep(rig, s, side):
    """The cut. side 1: left to right; -1: right to left (the return stroke)."""
    roll = 0 if side > 0 else 180
    rows = SWEEP_LR if side > 0 else SWEEP_RL
    keys = [(r[0], key(s, r[2:13], r[13], r[14]), r[1]) for r in rows]
    return tracked(rig, keyed(keys + [(0.45, _guard_near(s, rows[-1][13]))]), 0.45)


def windup_high(rig, s):
    """The heavy's wind-up: the blade raised over his right shoulder (held; deepens as he charges)."""
    return tracked(rig, keyed([(0.0, K.guard_pose(s), "snap"), (0.12, key(s, COCKED_HIGH, 180), "io"),
                               (0.6, key(s, DEEP_HIGH, 180))]), 0.6)


def cleave(rig, s):
    """The heavy cut: down and across from over his right shoulder, with a lunge (LUNGE)."""
    feet = K.stance(s, **LUNGE)
    keys = [(r[0], key(s, r[2:13], r[13], r[14], feet if r[0] >= CLEAVE_HIT else None), r[1]) for r in CLEAVE]
    return tracked(rig, keyed(keys + [(0.6, _guard_near(s, CLEAVE[-1][13]))]), 0.6)


def add_all(rig, make_action):
    s = rig.head("Hips").z / 0.93
    for side, name in ((1, "L"), (-1, "R")):
        make_action(rig, "windup_" + name, windup(rig, s, side), 0.6)
        make_action(rig, "sweep_" + ("LR" if side > 0 else "RL"), sweep(rig, s, side), 0.45)
    make_action(rig, "windup_high", windup_high(rig, s), 0.6)
    make_action(rig, "cleave", cleave(rig, s), 0.6)
