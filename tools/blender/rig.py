"""The shared humanoid skeleton every Aethereal character uses.

Blender axes while building: x = the character's RIGHT, y = FORWARD (he faces +y), z = UP.
(The glTF export turns that into Godot's: he faces -z, right is +x, up is +y.)

Bone names are fixed; scripts and every animation rely on them:
    Hips (root, at the pelvis)
      Spine > Chest > Neck > Head
      Chest > Shoulder_L/R > UpperArm_L/R > LowerArm_L/R > Hand_L/R
      Hand_R > Weapon_R      grip of the main weapon (blade along the bone, +Y)
      Hand_L > Weapon_L      grip of an off-hand item (Aeneas's knife in a stab)
      Chest > Back           something slung across the back (Aeneas's rifle)
      Hips > Sheath          a blade at the left hip (Aeneas's knife)
      Hips > UpperLeg_L/R > LowerLeg_L/R > Foot_L/R
Attach bones (Weapon_*, Back, Sheath) never deform the mesh. A prop modelled with its grip at
the origin and its length along +Y sits on them exactly (see make_wrapper.gd).
"""
import math
import bpy
from mathutils import Vector

BONE_PARENTS = {
    "Hips": None, "Spine": "Hips", "Chest": "Spine", "Neck": "Chest", "Head": "Neck",
    "Shoulder_L": "Chest", "UpperArm_L": "Shoulder_L", "LowerArm_L": "UpperArm_L", "Hand_L": "LowerArm_L",
    "Shoulder_R": "Chest", "UpperArm_R": "Shoulder_R", "LowerArm_R": "UpperArm_R", "Hand_R": "LowerArm_R",
    "Weapon_R": "Hand_R", "Weapon_L": "Hand_L", "Back": "Chest", "Sheath": "Hips",
    "UpperLeg_L": "Hips", "LowerLeg_L": "UpperLeg_L", "Foot_L": "LowerLeg_L",
    "UpperLeg_R": "Hips", "LowerLeg_R": "UpperLeg_R", "Foot_R": "LowerLeg_R",
}
DEFORM_BONES = [b for b in BONE_PARENTS if b not in ("Weapon_R", "Weapon_L", "Back", "Sheath")]


def _n(v):
    return Vector(v).normalized()


def layout(height=1.72, shoulders=1.0, hips=1.0, arm_angle=45.0):
    """Joint positions for a character `height` metres tall (about 6.8 heads, long legs).
    `shoulders` / `hips` widen or narrow the frame. Returns a dict of name -> Vector (right side;
    the left side is the mirror) plus 'height'."""
    s = height / 1.72
    J = {"height": height}
    def p(x, y, z):
        return Vector((x * s, y * s, z * s))
    J["hips"] = p(0, 0.0, 0.93)
    J["spine"] = p(0, 0.0, 1.03)
    J["chest"] = p(0, 0.0, 1.18)
    J["neck"] = p(0, -0.005, 1.385)
    J["head"] = p(0, 0.0, 1.475)
    J["head_top"] = p(0, 0.0, 1.72)
    J["clavicle"] = p(0.025 * shoulders, 0.0, 1.355)
    J["shoulder"] = p(0.165 * shoulders, -0.005, 1.355)
    a = math.radians(arm_angle)
    J["elbow"] = J["shoulder"] + _n((math.cos(a), -0.03, -math.sin(a))) * 0.275 * s
    J["wrist"] = J["elbow"] + _n((math.cos(a), 0.06, -math.sin(a))) * 0.25 * s
    J["hand_tip"] = J["wrist"] + _n((math.cos(a) * 0.95, 0.06, -math.sin(a))) * 0.17 * s
    J["hip_joint"] = p(0.093 * hips, 0.0, 0.91)
    J["knee"] = p(0.098 * hips, 0.015, 0.495)
    J["ankle"] = p(0.10 * hips, -0.02, 0.085)
    J["toe"] = p(0.10 * hips, 0.125, 0.03)
    return J


def mirror(v):
    return Vector((-v.x, v.y, v.z))


def build_rig(name, J):
    """Creates the armature object (named `name`) from a layout() dict and returns it."""
    data = bpy.data.armatures.new(name + "_rig")
    arm = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = data.edit_bones
    fwd, up = Vector((0, 1, 0)), Vector((0, 0, 1))

    def bone(bname, head, tail, roll_to, parent=None, connect=False):
        b = eb.new(bname)
        b.head, b.tail = head, tail
        b.align_roll(roll_to)
        if parent:
            b.parent = eb[parent]
            b.use_connect = connect
        return b

    bone("Hips", J["hips"], J["spine"], fwd)
    bone("Spine", J["spine"], J["chest"], fwd, "Hips", True)
    bone("Chest", J["chest"], J["neck"], fwd, "Spine", True)
    bone("Neck", J["neck"], J["head"], fwd, "Chest", True)
    bone("Head", J["head"], J["head_top"], fwd, "Neck", True)
    for side, m in (("R", lambda v: Vector(v)), ("L", mirror)):
        bone("Shoulder_" + side, m(J["clavicle"]), m(J["shoulder"]), up, "Chest")
        bone("UpperArm_" + side, m(J["shoulder"]), m(J["elbow"]), fwd, "Shoulder_" + side, True)
        bone("LowerArm_" + side, m(J["elbow"]), m(J["wrist"]), fwd, "UpperArm_" + side, True)
        bone("Hand_" + side, m(J["wrist"]), m(J["hand_tip"]), fwd, "LowerArm_" + side, True)
        bone("UpperLeg_" + side, m(J["hip_joint"]), m(J["knee"]), fwd, "Hips")
        bone("LowerLeg_" + side, m(J["knee"]), m(J["ankle"]), fwd, "UpperLeg_" + side, True)
        bone("Foot_" + side, m(J["ankle"]), m(J["toe"]), up, "LowerLeg_" + side, True)
    s = J["height"] / 1.72
    # Grips. The main weapon points forward out of the right fist (thumb side), edge along the fingers.
    hand_r = (J["hand_tip"] - J["wrist"]).normalized()
    grip_r = J["wrist"] + hand_r * 0.085 * s
    bone("Weapon_R", grip_r, grip_r + Vector((0, 0.1, 0)), hand_r, "Hand_R")
    # The off hand holds things in a reverse grip: blade out of the little-finger side (backwards).
    hand_l = mirror(hand_r)
    grip_l = mirror(J["wrist"]) + hand_l * 0.085 * s
    bone("Weapon_L", grip_l, grip_l + Vector((0, -0.1, 0)), hand_l, "Hand_L")
    # Sheath: a knife at the left hip, handle up and forward, blade down and a little back.
    sheath = Vector((-0.165 * s, 0.05 * s, 0.925 * s))
    bone("Sheath", sheath, sheath + _n((0.0, -0.35, -1.0)) * 0.1, fwd, "Hips")
    # Back: a long item across the back, its +Y end up over the right shoulder.
    back = Vector((0.0, -0.15 * s, 1.17 * s))
    bone("Back", back, back + _n((0.70, 0.0, 0.72)) * 0.1, Vector((0, -1, 0)), "Chest")
    bpy.ops.object.mode_set(mode='OBJECT')
    for b in data.bones:
        b.use_deform = b.name in DEFORM_BONES
    return arm
