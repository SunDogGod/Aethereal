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
  slide        the sprint slide (whole body): down by 0.2 s, feet first, right leg out, left folded
               under, left hand trailing; hold its last frame for as long as he slides
  slide_getup  up out of the slide over the folded leg into a running lean
  sheathe      the blade back into the scabbard (an upper-body action, so he can walk meanwhile);
               it is home at SHEATHE_HOME seconds
The game uses the same numbers: DRAW_HIT in scripts/character_animator.gd and SHEATHE_HOME in
scripts/character_anim_layers.gd, so change both sides together.
"""
import math
from pose import make_action, keyed
import anims_loco as L
import anims_combat as K
from natural_arm import tracked

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
    def held(depth):   # the hand on the hilt, free to turn round it (natural_arm.tracked)
        return _held(rig, s, iai_pose(s, depth), 0.0, 6 + 6 * depth, 50)
    return tracked(rig, keyed([(0.0, held(0.0), "snap"), (0.10, held(0.25), "io"), (0.6, held(1.0))]), 0.6)


def _held(rig, s, p, t, scab, tol=None):
    """Pose p with the right hand gripping the sword t metres out of the scabbard (0 = home),
    written as a free grip so it blends with swinging keys."""
    p = dict(p)
    p["arm_R"] = {"hold": ("Scabbard", t * s, ROLL_R), "pole": (0.6, -0.45, -0.65)}
    p["arm_L"] = left_hold(s)
    p["Scabbard"] = (0, 0, scab)
    p = rig.hold_as_grip(p, "R", ref_yaw=170.0)
    if tol is not None:      # the hand may turn round the grip this far (natural_arm.tracked)
        p["arm_R"]["roll_tol"] = tol
    return p


def _swing(rig, s, twist, lean, loc, ang, rad, h, yaw, pitch, roll, scab, feet=None, shoulder=(0, 0, 0), tol=None):
    """A key with the blade held freely (written as a grip) and the left hand still on the scabbard.
    tol: how far natural_arm.tracked() may roll the edge to keep his wrist human (None: exactly)."""
    p = K.P(K.torso(twist, lean, 0, loc, s), feet or K.stance(s, front=0.17, back=-0.15, width=0.15),
            K.sword_arm(s, ang, rad, h, yaw, pitch, roll, (0.5, -0.3, -0.9)),
            {"arm_L": left_hold(s), "Scabbard": (0, 0, scab), "Shoulder_R": shoulder})
    p = rig.ikc_as_grip(p, "R")
    if tol is not None:
        p["arm_R"]["roll_tol"] = tol
    return p


def _guard(rig, s, roll_near=None):
    """The fighting guard (anims_combat.guard_pose) with his left hand on the scabbard, as a grip."""
    g = K.P(K.guard_pose(s), {"arm_L": left_hold(s), "Scabbard": (0, 0, 0)})
    arm = dict(g["arm_R"])
    if roll_near is not None:
        yaw, pitch, r = arm["blade"]
        arm["blade"] = (yaw, pitch, r + 360.0 * round((roll_near - r) / 360.0))
    g["arm_R"] = arm
    return rig.ikc_as_grip(g, "R")


def draw_cut(rig, s):
    """From the iai stance: the hand pulls the blade along the scabbard while the left hand turns
    the scabbard's mouth forward, the blade comes free beside his left hip and sweeps across, his
    arm reaching out as it crosses his front, and the follow-through rises over his right
    shoulder, the wrist turning over. The left hand keeps hold of the scabbard all through (it
    lets go as the cut blends out). natural_arm.tracked() keeps the right arm human."""
    # Deep, like the sweeps (anims_swings.py): he sinks into his knees and drives forward as the
    # blade comes free, and the cut passes low, at chest height, before the follow-through rises.
    k0 = _held(rig, s, iai_pose(s, 0.35), 0.0, 9, 50)
    pull = K.P(iai_pose(s, 0.35), K.torso(20, -14, 0, (0.0, 0.0, -0.15), s, hips_share=0.25))
    k1 = _held(rig, s, pull, -0.22, 32, 50)
    out = _swing(rig, s, 30, -14, (0, 0.04, -0.17), 70, 0.42, 0.98, 118, -6, -30, 26, shoulder=(0, 0, 18), tol=45)
    hit = _swing(rig, s, -4, -22, (0, 0.15, -0.22), -12, 0.70, 1.00, 12, 0, 15, 10, shoulder=(0, -2, 18), tol=30)
    c = _swing(rig, s, -26, -20, (0, 0.16, -0.21), -48, 0.60, 1.08, -64, 10, -30, 2, shoulder=(0, -6, 10), tol=45)
    d = _swing(rig, s, -40, -14, (0, 0.13, -0.17), -68, 0.48, 1.24, -110, 30, -60, 0, shoulder=(0, -12, 2), tol=45)
    e = _swing(rig, s, -44, -8, (0, 0.08, -0.12), -62, 0.36, 1.40, -150, 46, -80, 0, shoulder=(0, -16, 0), tol=45)
    return tracked(rig, keyed([(0.0, k0, "lin"), (0.035, k1, "lin"), (0.068, out, "lin"), (DRAW_HIT, hit, "lin"),
                               (0.135, c, "out"), (0.18, d, "out"), (0.26, e, "io"), (0.5, _guard(rig, s, -80))]), 0.5)


def sheathe(rig, s):
    """Upper body: the blade comes across, its tip finds the mouth of the scabbard (the left
    hand turns it to meet it) and slides home; the right hand lets go as the action blends out
    into his walk (character_animator.gd)."""
    body = K.P(K.torso(30, -13, 0, (0.015, 0.0, -0.022), s), K.stance(s),
               {"hips": {"loc": (0.015 * s, 0.0, -0.022 * s), "rot": (0, -2.0, 3.0)}, "Shoulder_R": (0, -4, 32)})
    start = _guard(rig, s)
    across = _swing(rig, s, 14, -4, (0.015, 0.0, -0.022), 62, 0.36, 1.16, 150, -22, -90, 22, K.stance(s))
    mouth = _held(rig, s, body, -0.42, 22)
    home = _held(rig, s, body, 0.0, 4)
    return keyed([(0.0, start, "io"), (0.16, across, "io"), (0.30, mouth, "in"), (SHEATHE_HOME, home, "io"),
                  (0.65, home)])


# ---------------------------------------------------------------- the slide
def slide_pose(s, skid=0.0):
    """Feet first and low: his weight back on his left hip, the right leg out straight ahead with the
    heel down and toes up, the left leg folded under it (knee out to the side), the left hand
    trailing on the ground behind him, the right arm up and forward for balance; the head stays up,
    watching where he goes. `skid` (-1..1) shakes it a little as he scrapes along."""
    return K.P({"hips": {"loc": (0.02 * s, -0.05 * s, (-0.66 + 0.006 * skid) * s), "rot": (30, -10, -6)},
                "Spine": (14 + skid, -4, -4), "Chest": (8, -3, -4), "Neck": (-24, 2, 4), "Head": (-20, 3, 6 + 2 * skid),
                "Shoulder_L": (0, 0, 6), "Scabbard": (-58, 0, 8)},
               {"leg_R": {"ankle": (0.11 * s, 0.78 * s, 0.10 * s), "pole": (0.1, 0.2, 1.0), "foot": (34, -4)},
                "leg_L": {"ankle": (0.03 * s, 0.36 * s, 0.075 * s), "pole": (-1.0, 0.3, -0.1), "foot": (-10, -70)}},
               {"arm_L": {"ik": ((-0.38 - 0.01 * skid) * s, -0.50 * s, 0.05 * s), "pole": (-0.5, 0.3, 0.6), "hand": (-30, 0, -10)},
                "arm_R": {"ikr": (0.30 * s, 0.14 * s, -0.10 * s), "pole": (0.3, -0.6, -1.0), "blade": (-125, 15, 70)}})


def slide(s):
    """The drop from a sprint into the slide (by 0.2 s), then the slide itself, scraping along; the
    last frame holds as long as the game keeps playing it (0.8 s is one pass)."""
    drop = K.P(K.torso(0, 6, 0, (0, -0.02, -0.30), s), {"Scabbard": (-14, 0, 4)},
               {"leg_R": {"ankle": (0.11 * s, 0.42 * s, 0.30 * s), "pole": (0.1, 1, 0.4), "foot": (10, -4)},
                "leg_L": {"ankle": (-0.12 * s, -0.10 * s, 0.10 * s), "pole": (-0.4, 1, 0), "foot": (-30, 6)}},
               {"arm_L": {"ikr": (-0.20 * s, -0.10 * s, -0.36 * s), "pole": (-0.6, -0.4, 0.2), "hand": (-10, 0, -10)},
                "arm_R": {"ikr": (0.22 * s, 0.14 * s, -0.22 * s), "pole": (0.3, -0.6, -1.0), "blade": (-110, 0, 70)}})
    land = slide_pose(s, 1.0)
    land["hips"] = {"loc": (0.02 * s, -0.04 * s, -0.64 * s), "rot": (24, -8, -4)}
    return keyed([(0.0, drop, "in"), (0.20, land, "out"), (0.32, slide_pose(s, -1.0), "io"),
                  (0.48, slide_pose(s, 0.6), "io"), (0.64, slide_pose(s, -0.3), "io"), (0.8, slide_pose(s))])


def slide_getup(s):
    """Out of the slide onto the folded left leg: the left hand pushes off the ground, the body
    comes forward over the left foot and he rises into a running lean (ends near the run's stride,
    so the run can take over)."""
    push = K.P({"hips": {"loc": (0.0, 0.18 * s, -0.48 * s), "rot": (-6, -6, -4)}, "Spine": (-12, -2, -2),
                "Chest": (-8, 0, -2), "Neck": (6, 0, 2), "Head": (6, 0, 2), "Scabbard": (-20, 0, 6)},
               {"leg_L": {"ankle": (-0.06 * s, 0.22 * s, 0.085 * s), "pole": (-0.6, 1, 0.2), "foot": (0, 20)},
                "leg_R": {"ankle": (0.12 * s, 0.62 * s, 0.12 * s), "pole": (0.2, 0.5, 1.0), "foot": (10, -4)}},
               {"arm_L": {"ik": (-0.30 * s, 0.10 * s, 0.10 * s), "pole": (-0.6, 0.4, 0.2), "hand": (-40, 0, -10)},
                "arm_R": {"ikr": (0.26 * s, 0.20 * s, -0.14 * s), "pole": (0.3, -0.6, -1.0), "blade": (-110, 10, 70)}})
    up = K.P(K.torso(4, -14, 0, (0, 0.04, -0.07), s), {"Scabbard": (0, 0, 0)},
             {"leg_L": {"ankle": (-0.11 * s, 0.10 * s, 0.085 * s), "pole": (-0.2, 1, 0), "foot": (0, 6)},
              "leg_R": {"ankle": (0.11 * s, -0.24 * s, 0.16 * s), "pole": (0.2, 1, 0), "foot": (-40, -4)}},
             {"arm_L": {"ikr": (-0.06 * s, 0.22 * s, -0.36 * s), "pole": (-0.4, -1, -0.3), "hand": (10, 0, -10)},
              "arm_R": {"ikr": (0.08 * s, -0.14 * s, -0.42 * s), "pole": (0.4, -1, -0.3), "blade": (-20, -20, 70)}})
    return keyed([(0.0, slide_pose(s), "io"), (0.14, push, "out"), (0.38, up)])


def add_all(rig):
    s = rig.head("Hips").z / 0.93
    add_loco(rig, s)
    add_carry(rig, s)
    make_action(rig, "iai", iai(rig, s), 0.6)
    make_action(rig, "draw_cut", draw_cut(rig, s), 0.5)
    make_action(rig, "sheathe", sheathe(rig, s), 0.65)
    make_action(rig, "slide", slide(s), 0.8)
    make_action(rig, "slide_getup", slide_getup(s), 0.38)
