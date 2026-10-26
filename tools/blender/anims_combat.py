"""Fighting animations.

Sword swings (windup_L / sweep_LR / windup_R / sweep_RL) are in anims_swings.py; add_all() makes
them too. SWEEP_HIT is when a sweep's blade crosses his front.
Here: block (held), dodge_roll, dodge_back, hit, stab (knife takedown), death (held), and for
guards telegraph (blade raised, held), strike and stagger; cast is Isabella's brush slash.
Upper-body ones (windup_*, block, telegraph, cast) play over the legs' walking in Godot.
"""
from pose import make_action, keyed
from natural_arm import natural, tracked

SWEEP_HIT = 0.07    # seconds into a sweep when the blade crosses his front (player_combat.gd uses this)
STAB_DRAW = 0.13    # the knife moves from the sheath to his left hand (character_animator.gd)
STAB_SHEATHE = 0.64
CAST_HIT = 0.22     # Isabella's slash: the brush finishes its stroke (companion.gd: the ink lands)
_RIG = None         # add_all() sets it, so guard_pose() can keep the wrist human (natural_arm.py)
_GUARD = {}


def _v(t, s):
    return tuple(x * s for x in t)


def torso(twist=0.0, lean=0.0, side=0.0, loc=(0, 0, 0), s=1.0, hips_share=0.25, look=1.0):
    """Hips, spine and chest share a twist (+ = to his left) and a lean (- = forward); the neck and
    head turn back so he keeps looking at what he's hitting (look 1 = straight ahead)."""
    hs = hips_share
    rest = 1.0 - hs
    return {"hips": {"loc": _v(loc, s), "rot": (lean * 0.3, side * 0.5, twist * hs)},
            "Spine": (lean * 0.4, side * 0.3, twist * rest * 0.45), "Chest": (lean * 0.3, side * 0.2, twist * rest * 0.55),
            "Neck": (-lean * 0.35, 0, -twist * 0.45 * look), "Head": (-lean * 0.35, 0, -twist * 0.5 * look)}


def stance(s, front=0.13, back=-0.11, width=0.14):
    """Feet planted for fighting: left foot forward, right foot back and turned out."""
    return {"leg_L": {"ankle": _v((-width, front, 0.085), s), "pole": (-0.25, 1, 0), "foot": (0, 8)},
            "leg_R": {"ankle": _v((width, back, 0.085), s), "pole": (0.35, 1, 0), "foot": (0, -28)}}


def P(*parts):
    out = {}
    for p in parts:
        out.update(p)
    return out


def sword_arm(s, angle, radius, height, yaw, pitch=0.0, roll=0.0, pole=(0.3, -0.4, -1.0)):
    return {"arm_R": {"ikc": (angle, radius * s, height * s), "pole": pole, "blade": (yaw, pitch, roll)}}


def free_arm(s, x, y, z, pole=(-0.4, -1.0, -0.3), hand=(5, 0, -10)):
    return {"arm_L": {"ikr": _v((x, y, z), s), "pole": pole, "hand": hand}}


def guard_pose(s):
    """Neutral fighting stance: sword at his right side, its point forward at chest height."""
    if s not in _GUARD:
        p = P(torso(-8, -3, 0, (0.0, 0.0, -0.05), s), stance(s), sword_arm(s, -20, 0.32, 1.02, -6, 8, 70),
              free_arm(s, -0.06, 0.06, -0.48))
        _GUARD[s] = natural(_RIG, p, roll_tol=90) if _RIG else p
    return _GUARD[s]


def block(s):
    up = P(torso(-12, -4, 0, (0, 0, -0.06), s, hips_share=0.0), stance(s),
           {"arm_R": {"ik": _v((0.13, 0.30, 1.30), s), "pole": (0.6, -0.3, -0.8), "blade": (92, 12, 0)},
            "arm_L": {"ik": _v((-0.22, 0.31, 1.33), s), "pole": (-0.6, -0.4, -0.8),
                      "hand_aim": ((0.3, 0.2, 1.0), (0.0, 1.0, 0.0))}})
    return keyed([(0.0, guard_pose(s), "snap"), (0.09, up, "io"), (0.4, up)])


# ---------------------------------------------------------------- moving
def dodge_roll(s):
    def fk_legs(thigh, knee, spread=6):
        foot = -10 if knee < -60 else 0
        return {"leg_L": {"fk": [(thigh, -spread, 0), (knee, 0, 0), (foot, 0, 0)]},
                "leg_R": {"fk": [(thigh, spread, 0), (knee, 0, 0), (foot, 0, 0)]}}

    def key(rot, loc, thigh, knee, curl, arm_z):
        return P({"hips": {"loc": _v(loc, s), "rot": (rot, 0, 0)}, "Spine": (curl, 0, 0), "Chest": (curl * 0.6, 0, 0),
                  "Neck": (curl * 1.1, 0, 0), "Head": (curl * 0.5, 0, 0)}, fk_legs(thigh, knee),
                 {"arm_R": {"ikr": _v((0.05, 0.16, arm_z), s), "pole": (0.6, -0.5, -0.4), "blade": (-170, -20, 70)},
                  "arm_L": {"ikr": _v((-0.02, 0.20, arm_z), s), "pole": (-0.6, -0.5, -0.4)}})
    return keyed([(0.0, key(0, (0, 0, -0.04), 15, -25, -4, -0.40), "in"),
                  (0.10, key(-45, (0, 0.06, -0.22), 75, -105, -30, -0.30), "lin"),
                  (0.20, key(-150, (0, 0.10, -0.03), 112, -140, -46, -0.24), "lin"),
                  (0.30, key(-250, (0, 0.06, -0.70), 112, -140, -34, -0.24), "lin"),
                  (0.40, key(-330, (0, 0.0, -0.58), 85, -115, -18, -0.30), "out"),
                  (0.55, key(-360, (0, 0, -0.04), 15, -25, -4, -0.42))])


def dodge_back(s):
    lean = P(torso(0, 10, 0, (0, -0.05, -0.08), s),
             {"leg_L": {"ankle": _v((-0.13, 0.22, 0.085), s), "pole": (-0.2, 1, 0), "foot": (12, 6)},
              "leg_R": {"ankle": _v((0.13, 0.05, 0.13), s), "pole": (0.2, 1, 0), "foot": (-20, -6)}},
             sword_arm(s, -35, 0.30, 1.05, -20, -10, 70), free_arm(s, -0.18, 0.05, -0.36))
    air = P(torso(0, 6, 0, (0, -0.02, 0.0), s),
            {"leg_L": {"ankle": _v((-0.13, 0.12, 0.20), s), "pole": (-0.2, 1, 0), "foot": (0, 6)},
             "leg_R": {"ankle": _v((0.13, 0.02, 0.24), s), "pole": (0.2, 1, 0), "foot": (-15, -6)}},
            sword_arm(s, -35, 0.30, 1.08, -20, -5, 70), free_arm(s, -0.20, 0.08, -0.32))
    return keyed([(0.0, guard_pose(s), "out"), (0.08, lean, "io"), (0.2, air, "io"), (0.4, guard_pose(s))])


def hit_react(s):
    jolt = P(torso(10, 14, -4, (0, -0.05, -0.06), s, look=0.2), stance(s),
             sword_arm(s, -50, 0.36, 1.02, -60, -10, 70), free_arm(s, -0.22, -0.05, -0.30))
    return keyed([(0.0, guard_pose(s), "snap"), (0.07, jolt, "io"), (0.35, guard_pose(s))])


def stab(s):
    """Knife takedown: the left hand draws from the hip sheath, lunges and stabs, sheathes."""
    def key(twist, lean, loc, lw, hand=None, front=0.13, sword=(-40, 0.30, 0.98, -150, -30)):
        arm_l = {"ik": _v(lw, s), "pole": (-0.6, -0.6, -0.4)}
        if hand:
            arm_l["hand_aim"] = hand
        return P(torso(twist, lean, 0, loc, s), stance(s, front=front),
                 sword_arm(s, sword[0], sword[1], sword[2], sword[3], sword[4], 70), {"arm_L": arm_l})
    grip = ((1.0, 0.2, 0.1), (0.0, -0.5, 0.85))   # reverse grip: the blade points forward-down
    rest = guard_pose(s)
    reach = key(14, -10, (0, 0, -0.07), (-0.21, 0.06, 0.98))
    drawn = key(8, -6, (0, 0.02, -0.06), (-0.18, 0.22, 1.24), grip)
    up = key(-4, -4, (0, 0.04, -0.05), (-0.10, 0.30, 1.46), grip, 0.2)
    lunge = key(-14, -22, (0, 0.16, -0.12), (-0.02, 0.64, 1.16), grip, 0.34)
    push = key(-16, -24, (0, 0.18, -0.13), (0.0, 0.66, 1.10), grip, 0.34)
    back = key(6, -8, (0, 0.05, -0.07), (-0.18, 0.24, 1.14), grip, 0.2)
    return keyed([(0.0, rest, "io"), (0.10, reach, "io"), (0.16, drawn, "io"), (0.24, up, "in"),
                  (0.31, lunge, "out"), (0.46, push, "io"), (0.56, back, "io"), (STAB_SHEATHE, reach, "io"),
                  (0.70, rest)])


def death(s):
    """Knees give, he drops forward onto his face and stays there (held)."""
    hit = P(torso(6, 12, 0, (0, -0.02, -0.04), s, look=0.3), stance(s),
            sword_arm(s, -40, 0.34, 1.0, -60, -20, 70), free_arm(s, -0.16, 0.0, -0.40))
    knees = P(torso(0, -12, 0, (0, 0.05, -0.47), s, look=0.0),
              {"leg_L": {"ankle": _v((-0.13, -0.32, 0.07), s), "pole": (-0.1, 1, -0.3), "foot": (-60, 4)},
               "leg_R": {"ankle": _v((0.13, -0.36, 0.07), s), "pole": (0.1, 1, -0.3), "foot": (-60, -4)}},
              sword_arm(s, -30, 0.30, 0.55, -30, -40, 70), free_arm(s, -0.10, 0.04, -0.46))
    tip = P({"hips": {"loc": _v((0, 0.18, -0.58), s), "rot": (-48, 0, 4)}, "Spine": (-10, 0, 0), "Chest": (-5, 0, 0),
             "Neck": (5, 0, 0), "Head": (0, 0, 10)},
            {"leg_L": {"ankle": _v((-0.14, -0.40, 0.07), s), "pole": (-0.1, 0.5, -1), "foot": (-70, 4)},
             "leg_R": {"ankle": _v((0.14, -0.42, 0.07), s), "pole": (0.1, 0.5, -1), "foot": (-70, -4)}},
            {"arm_R": {"ikr": _v((0.12, 0.25, -0.30), s), "pole": (0.5, -0.5, 0.3), "blade": (-20, -10, 70)},
             "arm_L": {"ikr": _v((-0.12, 0.28, -0.30), s), "pole": (-0.5, -0.5, 0.3)}})
    down = P({"hips": {"loc": _v((0, 0.32, -0.79), s), "rot": (-86, 0, 6)}, "Spine": (-2, 0, 0), "Chest": (-2, 0, 0),
              "Neck": (8, 0, 18), "Head": (4, 0, 26)},
             {"leg_L": {"ankle": _v((-0.17, -0.55, 0.07), s), "pole": (-0.2, 0, -1), "foot": (-80, 10)},
              "leg_R": {"ankle": _v((0.15, -0.56, 0.06), s), "pole": (0.2, 0, -1), "foot": (-80, -10)}},
             {"arm_R": {"ikr": _v((0.30, 0.12, -0.10), s), "pole": (0.3, -0.3, 1), "blade": (-40, 0, 70)},
              "arm_L": {"ikr": _v((-0.28, 0.20, -0.10), s), "pole": (-0.3, -0.3, 1)}})
    bounce = P(down, {"hips": {"loc": _v((0, 0.32, -0.77), s), "rot": (-87, 0, 6)}})
    settle = P(down, {"hips": {"loc": _v((0, 0.32, -0.80), s), "rot": (-88, 0, 6)}})
    return keyed([(0.0, guard_pose(s), "snap"), (0.12, hit, "in"), (0.42, knees, "in"), (0.72, tip, "in"),
                  (0.92, down, "out"), (1.0, bounce, "io"), (1.2, settle)])


# ---------------------------------------------------------------- guards
def raised(s):
    return P(torso(-16, 8, 0, (0, -0.02, -0.06), s, hips_share=0.0), stance(s),
             {"arm_R": {"ik": _v((0.20, -0.04, 1.72), s), "pole": (0.8, 0.2, 0.2), "blade": (-172, 38, 90)}},
             free_arm(s, 0.06, 0.40, -0.12, pole=(-0.6, -0.4, -0.6), hand=(0, 0, 0)))


def telegraph(s):
    r = raised(s)
    lift = P(r, {"arm_R": {"ik": _v((0.22, 0.16, 1.48), s), "pole": (0.8, -0.2, -0.3), "blade": (-15, 70, 90)}})
    more = P(r, torso(-20, 10, 0, (0, -0.03, -0.07), s, hips_share=0.0))
    return keyed([(0.0, guard_pose(s), "out"), (0.2, lift, "io"), (0.45, r, "io"), (0.6, more)])


def strike(s):
    a = P(raised(s), torso(-20, 10, 0, (0, -0.03, -0.07), s))
    b = P(torso(-8, -2, 0, (0, 0.02, -0.08), s), stance(s),
          {"arm_R": {"ik": _v((0.14, 0.32, 1.52), s), "pole": (0.8, -0.2, -0.4), "blade": (-15, 25, 90)}},
          free_arm(s, -0.10, 0.20, -0.30))
    hit = P(torso(8, -16, 0, (0, 0.06, -0.12), s), stance(s),
            {"arm_R": {"ik": _v((0.02, 0.52, 1.14), s), "pole": (0.8, -0.4, -0.5), "blade": (2, -22, 90)}},
            free_arm(s, -0.16, -0.05, -0.30))
    low = P(torso(26, -18, 0, (0, 0.06, -0.12), s), stance(s),
            sword_arm(s, 38, 0.42, 0.90, 52, -42, 90, (0.6, -0.4, -0.6)), free_arm(s, -0.20, -0.15, -0.30))
    return keyed([(0.0, a, "in"), (0.05, b, "lin"), (0.09, hit, "out"), (0.16, low, "io"), (0.28, low, "io"),
                  (0.5, guard_pose(s))])


def stagger(s):
    feet = {"leg_L": {"ankle": _v((-0.15, -0.18, 0.085), s), "pole": (-0.3, 1, 0), "foot": (0, 12)},
            "leg_R": {"ankle": _v((0.14, 0.03, 0.085), s), "pole": (0.3, 1, 0), "foot": (0, -20)}}
    reel = P(torso(8, 16, 4, (0, -0.10, -0.10), s, look=0.2), feet,
             sword_arm(s, -70, 0.42, 1.15, -100, 10, 70, (0.5, -0.2, -0.8)), free_arm(s, -0.30, 0.0, -0.18))
    dazed = P(torso(-4, -8, -3, (0, -0.06, -0.12), s, look=-0.3), feet,
              sword_arm(s, -40, 0.30, 0.86, -40, -45, 70), free_arm(s, -0.10, 0.05, -0.48))
    sway = P(dazed, torso(4, -10, 3, (0, -0.06, -0.12), s, look=-0.3))
    return keyed([(0.0, guard_pose(s), "snap"), (0.10, reel, "io"), (0.32, dazed, "io"), (0.62, sway, "io"),
                  (0.85, dazed, "io"), (1.0, guard_pose(s))])


def cast(s):
    """Isabella's ink: one quick calligraphy slash. The brush rises by her right shoulder, sweeps
    down and across her front to her left (the ink lands on the agent as the stroke finishes, at
    CAST_HIT), flicks off the end of the stroke, holds a beat and settles."""
    def key(twist, lean, ang, rad, h, yaw, pitch, roll, free, shoulder, tol=45):
        p = P(torso(twist, lean, 0, (0, 0.02 if lean < -4 else 0, -0.03), s, hips_share=0.0), stance(s),
              sword_arm(s, ang, rad, h, yaw, pitch, roll, (0.6, -0.4, -0.5)), free_arm(s, *free),
              {"Shoulder_R": shoulder})
        p["arm_R"]["roll_tol"] = tol
        return p
    sleeve = (-0.02, 0.20, -0.22)       # her left hand gathers her right sleeve at her chest
    rise = key(-26, 4, -52, 0.36, 1.62, -36, 70, 90, sleeve, (0, -14, 2))
    mid = key(-2, -8, 0, 0.56, 1.30, 10, 6, 90, sleeve, (0, -6, 14))
    end = key(24, -12, 48, 0.46, 0.98, 44, -40, 90, (-0.04, 0.16, -0.26), (0, 0, 18))
    flick = key(16, -9, 36, 0.42, 1.12, 34, -12, 90, (-0.04, 0.16, -0.26), (0, -2, 14))
    keys = [(0.0, guard_pose(s), "out"), (0.10, rise, "in"), (0.16, mid, "lin"), (CAST_HIT, end, "out"),
            (0.27, flick, "io"), (0.34, flick, "io"), (0.5, guard_pose(s))]
    return tracked(_RIG, keyed(keys), 0.5) if _RIG else keyed(keys)


def add_all(rig):
    global _RIG
    import anims_swings
    _RIG = rig
    _GUARD.clear()
    s = rig.head("Hips").z / 0.93
    anims_swings.add_all(rig, make_action)
    make_action(rig, "block", block(s), 0.4)
    make_action(rig, "dodge_roll", dodge_roll(s), 0.55)
    make_action(rig, "dodge_back", dodge_back(s), 0.4)
    make_action(rig, "hit", hit_react(s), 0.35)
    make_action(rig, "stab", stab(s), 0.7)
    make_action(rig, "death", death(s), 1.2)
    make_action(rig, "telegraph", telegraph(s), 0.6)
    make_action(rig, "strike", strike(s), 0.5)
    make_action(rig, "stagger", stagger(s), 1.0)
    make_action(rig, "cast", cast(s), 0.5)
