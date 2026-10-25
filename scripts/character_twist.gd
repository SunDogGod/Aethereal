extends SkeletonModifier3D
## Turns a character's hips toward where he is really going while his chest keeps facing ahead,
## so strafing round a locked-on enemy (or a guard sidestepping) runs sideways instead of sliding.
## The Animator (character_animator.gd) adds this under the skeleton and sets `twist` each frame.

var twist := 0.0  ## radians: + turns the hips to his left; the spine and chest turn back by as much

var _hips := -1
var _spine := -1
var _chest := -1


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or absf(twist) < 0.001:
		return
	if _hips < 0:
		_hips = skeleton.find_bone("Hips")
		_spine = skeleton.find_bone("Spine")
		_chest = skeleton.find_bone("Chest")
	if _hips < 0 or _spine < 0 or _chest < 0:
		return
	# The hips turn about the skeleton's up axis; the spine and chest each undo half of it about
	# their own length (they stand roughly upright), so the shoulders stay square to the front.
	skeleton.set_bone_pose_rotation(_hips, Quaternion(Vector3.UP, twist) * skeleton.get_bone_pose_rotation(_hips))
	for bone in [_spine, _chest]:
		var q: Quaternion = skeleton.get_bone_pose_rotation(bone)
		skeleton.set_bone_pose_rotation(bone, q * Quaternion(Vector3.UP, -twist * 0.5))
