"""The captain's animations: he has only his LEFT arm, so he fights left-handed.

Every animation of the shared set (and the agent's own idle and patrol walk) is played through a
mirror, left for right: the blade arm becomes his left, the stance flips, the twists turn the other
way. His right arm is gone, so nothing keys it: the right arm's bones are left out of every
animation. His blade rides Weapon_L, which captain.py turns into a forward grip (the exact mirror
of Weapon_R), so a mirrored 'blade' direction lands the blade in his left hand the right way round.
"""
import bpy
import anims_loco
import anims_combat
import pose
import agent

RIGHT_ARM = ("UpperArm_R", "LowerArm_R", "Hand_R", "Weapon_R")


def _m3(v):
    """A position or direction, mirrored (x is his right)."""
    return (-v[0], v[1], v[2])


def _mrot(r):
    """A rotation (x, y, z degrees), mirrored: the tip back/forward stays, the side lean and the
    turn flip."""
    return (r[0], -r[1], -r[2])


def _limb(sub):
    out = {}
    for k, v in sub.items():
        if k in ("ik", "ikr", "grip", "pole", "ankle"):
            out[k] = _m3(v)
        elif k in ("ikc", "gripc"):
            out[k] = (-v[0], v[1], v[2])               # angle round him flips, radius and height stay
        elif k == "blade":
            out[k] = (-v[0], v[1], 180.0 - v[2])       # yaw flips; roll mirrors (pose.blade_dirs)
        elif k == "hand":
            out[k] = _mrot(v)
        elif k == "fk":
            out[k] = [_mrot(r) for r in v]
        elif k == "foot":
            out[k] = (v[0], -v[1])                     # toes up stays, toes turned in/out flips
        elif k == "hand_aim":
            out[k] = (_m3(v[0]), _m3(v[1]))
        else:
            raise ValueError("captain_anims: can't mirror %r" % k)
    return out


def mirror_pose(p):
    """A pose dict (pose.py) with left and right swapped."""
    out = {}
    for k, v in p.items():
        if k == "hips":
            out[k] = {"loc": _m3(v.get("loc", (0, 0, 0))), "rot": _mrot(v.get("rot", (0, 0, 0)))}
        elif k in ("arm_L", "arm_R", "leg_L", "leg_R"):
            out[k[:-1] + ("R" if k.endswith("L") else "L")] = _limb(v)
        elif k in ("Shoulder_L", "Shoulder_R"):
            out[k[:-1] + ("R" if k.endswith("L") else "L")] = _mrot(v)
        elif k in ("Spine", "Chest", "Neck", "Head"):
            out[k] = _mrot(v)
        else:
            raise ValueError("captain_anims: can't mirror %r" % k)
    return out


def one_armed(p):
    """The mirrored pose without anything for the right arm he doesn't have."""
    p = dict(p)
    p.pop("arm_R", None)
    return p


def heavy_run(s):
    """His run: the shared run's stride (3.4 m a cycle, so the feet stay planted in Godot) with
    the heel kick taken out and a shorter push-off behind him, a long-coated stride whose back foot never swings up through
    the coat. He doesn't sprint: the same cycle stands in for it."""
    g = anims_loco.Gait(3.4, 0.24, 0.30, 0.12, 0.04, 0.09, 8, -40, -30, 0)
    return lambda t: anims_loco._cycle_pose(t, s, g, -0.05, 0.022, (-6, -3, -1, 4, 4), 8, 4, 0.012,
                                            (0.22, 0.20), 0.33, (0.12, 0.08, -135, -26))


def animations(rig):
    """The shared set and the agent's idle and walk, mirrored, with no right arm."""
    real = pose.make_action

    def make(rig_, name, pose_at, length, loop=False):
        return real(rig_, name, lambda t: one_armed(mirror_pose(pose_at(t))), length, loop)

    full_order = rig.order
    rig.order = [b for b in full_order if b not in RIGHT_ARM]   # those bones get no keys at all
    anims_loco.make_action = anims_combat.make_action = make
    try:
        anims_loco.add_all(rig)
        anims_combat.add_all(rig)
        s = rig.head("Hips").z / 0.93
        for name, fn, length in (("idle", agent.agent_idle(s), 6.0), ("walk", agent.agent_walk(s), 1.0),
                                 ("run", heavy_run(s), 1.0), ("sprint", heavy_run(s), 1.0)):
            old = bpy.data.actions.get(name + "_loop")
            if old:
                bpy.data.actions.remove(old)
            make(rig, name, fn, length, loop=True)
    finally:
        anims_loco.make_action = anims_combat.make_action = real
        rig.order = full_order
