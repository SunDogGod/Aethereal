"""Isabella's own story animations (the hall), on top of the shared sets. Her brush is in her
right hand (prop "Brush" on Weapon_R), so her right arm is posed by where the brush goes:
sword_arm(s, angle round her, radius, height, brush yaw, pitch, roll).

    break_free     out of the agent's hold ("hostage"): she drops her weight, slashes ink up over
                   her right shoulder into the man behind her (BREAK_HITS[0]), turns out and sweeps
                   a wide stroke through the guards in front (BREAK_HITS[1]), ends on guard.
    lunge          a long lunge at the captain, the brush driven at him (held at full stretch:
                   it carries her LUNGE_REACH metres forward of where she stands)
    stabbed        the captain's hand goes into her chest: a jolt, then she folds round it (held)
    stagger_back   she staggers back to where she stood, her left hand on her heart, and lifts
                   her head to look at Aeneas (held)
    kneel_draw     she kneels and draws the circle on the floor round herself with the brush: it
                   touches down at CIRCLE_START at her right-back and sweeps round her front to
                   her left by CIRCLE_END (the rest of the ring is the ink's), then she sits up (held)
    collapse       from kneeling she slumps and falls onto her left side (held)
"""
from pose import keyed
from anims_combat import P, torso, stance, sword_arm, _v
import anims_story as st

BREAK_HITS = (0.33, 0.85)   # the two ink strokes land (character_story.gd scenes time effects by these)
LUNGE_REACH = 0.30
CIRCLE_START, CIRCLE_END = 1.1, 3.0


def left(s, x, y, z, pole=(-1.0, -0.3, -0.4)):
    return {"arm_L": {"ik": _v((x, y, z), s), "pole": pole}}


def ready(s):
    return P(torso(-8, -3, 0, (0, 0, -0.05), s), stance(s), sword_arm(s, -20, 0.32, 1.02, -6, 8, 70),
             left(s, -0.17, 0.08, 0.95))


def break_free(s):
    held = dict(st.hostage(s)(0.0))
    held.update(sword_arm(s, -6, 0.18, 1.31, 80, 20, 90, (0.9, -0.2, -0.5)))
    drop = P(torso(-15, -8, 0, (0, 0.0, -0.10), s, hips_share=0.2), stance(s),
             sword_arm(s, -35, 0.28, 0.98, -30, -35, 90, (0.6, -0.4, -0.6)), left(s, -0.22, 0.20, 1.20))
    back = P(torso(-55, 4, 0, (0, -0.02, -0.08), s, hips_share=0.35, look=0.3), stance(s),
             sword_arm(s, -125, 0.34, 1.58, -165, 35, 90, (0.6, 0.2, -0.8)), left(s, -0.28, 0.32, 1.12))
    turn = P(torso(-10, -6, 0, (0, 0.06, -0.08), s), stance(s),
             sword_arm(s, -60, 0.42, 1.40, -70, 15, 90, (0.8, -0.2, -0.5)), left(s, -0.18, 0.15, 1.05))
    sweep = P(torso(35, -12, 0, (0, 0.08, -0.06), s), stance(s),
              sword_arm(s, 45, 0.50, 1.25, 60, -5, 90, (0.6, -0.4, -0.6)), left(s, -0.16, 0.10, 0.98))
    flick = P(torso(26, -9, 0, (0, 0.05, -0.05), s), stance(s),
              sword_arm(s, 36, 0.44, 1.12, 38, -20, 90, (0.6, -0.4, -0.6)), left(s, -0.16, 0.10, 0.98))
    return keyed([(0.0, held, "in"), (0.15, drop, "in"), (BREAK_HITS[0], back, "out"), (0.55, turn, "in"),
                  (BREAK_HITS[1], sweep, "out"), (1.0, flick, "io"), (1.35, ready(s))])


def lunge_pose(s, k=1.0):
    return P(torso(10, -20, 0, (0, LUNGE_REACH * k, -0.13), s),
             {"leg_L": {"ankle": _v((-0.14, 0.62, 0.085), s), "pole": (-0.2, 1, 0), "foot": (0, 8)},
              "leg_R": {"ankle": _v((0.14, -0.30, 0.11), s), "pole": (0.2, 1, 0), "foot": (-30, -20)}},
             sword_arm(s, 4, 0.62, 1.20, 0, 0, 90, (0.6, -0.4, -0.6)), left(s, -0.24, -0.12, 0.78, (-0.8, 0.3, -0.5)))


def lunge(s):
    cock = P(torso(-25, 4, 0, (0, -0.04, -0.08), s), stance(s),
             sword_arm(s, -40, 0.22, 1.25, -10, 10, 90, (0.6, -0.4, -0.6)), left(s, -0.20, 0.20, 1.10))
    return keyed([(0.0, ready(s), "io"), (0.18, cock, "in"), (0.40, lunge_pose(s), "out"), (0.55, lunge_pose(s, 1.02))])


def _hurt(s, lean, loc, head, brush=(-20, 0.25, 0.85)):
    """Folded round the wound: her left hand on her heart, the brush hanging from her right."""
    return P(torso(0, lean, 0, loc, s, look=0.0), {"Neck": (head, 0, 0), "Head": (head, 0, 0)},
             {"arm_L": {"ikr": _v((0.12, 0.14, -0.17), s), "pole": (-1.0, -0.3, -0.3), "hand": (0, 0, 40)}},
             sword_arm(s, brush[0], brush[1], brush[2], -10, -60, 90, (0.4, -1, -0.3)))


def stabbed(s):
    lp = lunge_pose(s, 1.02)
    jolt = P(lp, torso(0, 8, 0, (0, 0.26, -0.13), s, look=0.0), {"Neck": (12, 0, 0), "Head": (14, 0, 0)},
             sword_arm(s, 20, 0.40, 1.15, 10, -20, 90, (0.6, -0.4, -0.6)),
             {"arm_L": {"ikr": _v((-0.16, 0.10, -0.22), s), "pole": (-1.0, -0.3, -0.3), "hand": (0, 0, 20)}})
    fold = P(lp, _hurt(s, -22, (0, 0.22, -0.16), -12))
    return keyed([(0.0, lp, "snap"), (0.08, jolt, "io"), (0.5, fold)])


def stagger_back(s):
    def legs(lf, rb, lift=0.0):
        return {"leg_L": {"ankle": _v((-0.13, lf, 0.085 + lift), s), "pole": (-0.2, 1, 0), "foot": (0, 6)},
                "leg_R": {"ankle": _v((0.13, rb, 0.085), s), "pole": (0.2, 1, 0), "foot": (0, -10)}}
    start = P(lunge_pose(s, 1.02), _hurt(s, -22, (0, 0.22, -0.16), -12))
    a = P(_hurt(s, -16, (0.02, 0.14, -0.08), -8), legs(0.30, -0.30, 0.04))
    b = P(_hurt(s, -12, (-0.02, 0.04, -0.05), -2), legs(0.12, -0.18))
    c = P(_hurt(s, -6, (0, 0.0, -0.03), 8), legs(0.03, -0.04))
    sway = P(_hurt(s, -8, (0.01, 0.0, -0.035), 6), legs(0.03, -0.04))
    return keyed([(0.0, start, "io"), (0.4, a, "io"), (0.8, b, "io"), (1.2, c, "io"), (1.6, sway)])


KNEES = {"leg_L": {"ankle": (-0.13, -0.33, 0.075), "pole": (-0.1, 1, -0.3), "foot": (-62, 4)},
         "leg_R": {"ankle": (0.13, -0.35, 0.075), "pole": (0.1, 1, -0.3), "foot": (-62, -4)}}


def _knees(s):
    return {k: dict(v, ankle=_v(v["ankle"], s)) for k, v in KNEES.items()}


def _drawing(s, ang, twist, lean, side, h=0.22, rad=0.40, pitch=-55):
    """Kneeling, the brush tip on the floor at angle `ang` round her (0 ahead, + to her left)."""
    p = P(torso(twist, lean, side, (0, 0.04, -0.475), s, hips_share=0.15, look=0.7), _knees(s),
          {"arm_R": {"gripc": (ang, rad * s, h * s), "blade": (ang, pitch, 90), "pole": (0.8, -0.5, 0.4)}},
          {"arm_L": {"ikr": _v((0.12, 0.14, -0.17), s), "pole": (-1.0, -0.3, -0.3), "hand": (0, 0, 40)}})
    return p


def kneel_draw(s):
    stand = P(_hurt(s, -8, (0.01, 0.0, -0.035), 6), {"arm_R": {"gripc": (-20, 0.25 * s, 0.85 * s), "blade": (-10, -60, 90),
                                                     "pole": (0.4, -1, -0.3)}},
              {"leg_L": {"ankle": _v((-0.13, 0.03, 0.085), s), "pole": (-0.2, 1, 0), "foot": (0, 6)},
               "leg_R": {"ankle": _v((0.13, -0.04, 0.085), s), "pole": (0.2, 1, 0), "foot": (0, -10)}})
    kneel = P(torso(0, -6, 0, (0, 0.04, -0.475), s, look=0.0), _knees(s),
              {"arm_R": {"gripc": (-30, 0.30 * s, 0.70 * s), "blade": (-30, -30, 90), "pole": (0.6, -0.8, -0.2)}},
              {"arm_L": {"ikr": _v((0.12, 0.14, -0.17), s), "pole": (-1.0, -0.3, -0.3), "hand": (0, 0, 40)}})
    lift = _drawing(s, 60, 22, -14, 4, h=0.62, rad=0.36, pitch=0)
    sit = P(torso(0, -4, 0, (0, 0.04, -0.475), s, look=0.0), _knees(s),
            {"arm_R": {"gripc": (0, 0.24 * s, 0.82 * s), "blade": (0, 60, 90), "pole": (0.6, -0.8, -0.2)}},
            {"arm_L": {"ikr": _v((0.12, 0.14, -0.17), s), "pole": (-1.0, -0.3, -0.3), "hand": (0, 0, 40)}})
    return keyed([(0.0, stand, "in"), (0.7, kneel, "io"), (CIRCLE_START, _drawing(s, -130, -62, -34, 22), "lin"),
                  (1.6, _drawing(s, -80, -46, -46, 18), "lin"), (2.1, _drawing(s, -30, -16, -52, 8), "lin"),
                  (2.6, _drawing(s, 20, 14, -50, 0), "lin"), (CIRCLE_END, _drawing(s, 66, 40, -42, -6), "io"),
                  (3.25, lift, "io"), (3.6, sit)])


def collapse(s):
    sit = kneel_draw(s)(3.6)
    slump = P(sit, torso(0, -30, 0, (0, 0.06, -0.50), s, look=0.0), {"Neck": (-16, 0, 0), "Head": (-14, 0, 0)},
              {"leg_L": {"fk": [(2, -3, 0), (-92, 0, 0), (-28, 0, 0)]}, "leg_R": {"fk": [(2, 3, 0), (-92, 0, 0), (-28, 0, 0)]}},
              {"arm_R": {"gripc": (-10, 0.30 * s, 0.40 * s), "blade": (-20, -70, 90), "pole": (0.4, -1, -0.3)}})
    tip = P(slump, {"hips": {"loc": _v((-0.18, 0.05, -0.69), s), "rot": (-10, -55, 0)}, "Spine": (-8, -6, 0),
                    "Chest": (-6, -4, 0), "Neck": (-6, -8, 0), "Head": (-4, -10, 0)})
    down = {"hips": {"loc": _v((-0.30, 0.0, -0.76), s), "rot": (-12, -86, 0)}, "Spine": (-10, -4, 0),
            "Chest": (-8, 0, 0), "Neck": (-4, -10, 0), "Head": (0, -14, 0),
            "leg_L": {"fk": [(70, 0, 0), (-100, 0, 0), (-20, 0, 0)]},
            "leg_R": {"fk": [(55, 0, 0), (-90, 0, 0), (-20, 0, 0)]},
            "arm_L": {"ikr": _v((0.10, 0.30, -0.20), s), "pole": (-0.2, -1, 0.5), "hand": (0, 0, 0)},
            "arm_R": {"gripc": (20, 0.40 * s, 0.30 * s), "blade": (40, -10, 90), "pole": (0.5, -0.5, 0.6)}}
    rest = P(down, {"hips": {"loc": _v((-0.30, 0.0, -0.77), s), "rot": (-12, -88, 0)}})
    return keyed([(0.0, sit, "in"), (0.4, slump, "in"), (0.9, tip, "in"), (1.25, down, "out"), (1.6, rest)])


def add_all(rig, make_action):
    s = rig.head("Hips").z / 0.93
    make_action(rig, "break_free", break_free(s), 1.35)
    make_action(rig, "lunge", lunge(s), 0.55)
    make_action(rig, "stabbed", stabbed(s), 0.5)
    make_action(rig, "stagger_back", stagger_back(s), 1.6)
    make_action(rig, "kneel_draw", kneel_draw(s), 3.6)
    make_action(rig, "collapse", collapse(s), 1.6)


def animations(rig):
    """The shared sets (locomotion, fighting and the shared story poses), then hers."""
    import anims_loco
    import anims_combat
    from pose import make_action
    anims_loco.add_all(rig)
    anims_combat.add_all(rig)
    add_all(rig, make_action)
