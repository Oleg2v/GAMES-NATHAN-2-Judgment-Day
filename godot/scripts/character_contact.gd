class_name NathanContactModifier
extends SkeletonModifier3D
## Runs after AnimationTree. Adjusts actual skeletal joints, never mesh parts.
## Two-bone arm/leg solve preserves segment lengths; torso CCD positions the head.
var actor: Node3D
var residuals: Dictionary = {}
var anchors: Dictionary = {}
var capture_pose: bool = false
var captured_pose: Dictionary = {}
var _indices: Dictionary = {}


func _bone(name: String) -> int:
	if not _indices.has(name):
		_indices[name] = get_skeleton().find_bone(name)
	return int(_indices[name])


func _process_modification_with_delta(_delta: float) -> void:
	if not is_instance_valid(actor) or not actor.has_method("contact_targets"):
		return
	var targets: Dictionary = actor.call("contact_targets")
	var weight: float = float(targets.get("weight", 0.0))
	residuals.clear()
	anchors.clear()
	if weight < 0.001:
		return
	var skeleton: Skeleton3D = get_skeleton()
	var foot_goals: Dictionary = {}
	if bool(targets.get("feet_lock", false)):
		for side: String in ["l", "r"]:
			if _bone("foot_" + side) >= 0:
				foot_goals[side] = skeleton.global_transform * skeleton.get_bone_global_pose(_bone("foot_" + side)).origin
	if targets.has("pelvis_shift") and _bone("pelvis") >= 0:
		var pose: Transform3D = skeleton.get_bone_global_pose(_bone("pelvis"))
		pose.origin += skeleton.global_basis.inverse() * (targets["pelvis_shift"] as Vector3) * weight
		skeleton.set_bone_global_pose(_bone("pelvis"), pose)
	if targets.has("torso_lean"):
		var lean: float = float(targets["torso_lean"]) * weight
		var axis: Vector3 = skeleton.global_basis.inverse() * actor.global_basis.x
		for name: String in ["spine_01", "spine_02", "spine_03"]:
			var index: int = _bone(name)
			if index >= 0:
				var pose: Transform3D = skeleton.get_bone_global_pose(index)
				pose.basis = Basis(Quaternion(axis.normalized(), lean / 3.0)) * pose.basis
				skeleton.set_bone_global_pose(index, pose)
	if targets.has("head"):
		var original: Vector3 = head_contact_world()
		_solve_head(original.lerp(targets["head"], weight))
		residuals["head"] = head_contact_world().distance_to(targets["head"])
	for side: String in ["l", "r"]:
		var key: String = "left_hand" if side == "l" else "right_hand"
		if targets.has(key):
			var hand: int = _bone("hand_" + side)
			if hand < 0:
				continue
			var initial: Vector3 = palm_world(side)
			var desired: Vector3 = initial.lerp(targets[key], weight)
			var sign_value: float = 1.0 if side == "l" else -1.0
			var pole: Vector3 = actor.global_position + actor.global_basis.x * sign_value * 0.8 + Vector3.UP * 1.05 - actor.global_basis.z * 0.15
			if targets.has(side+"_elbow_pole"):
				pole = targets[side+"_elbow_pole"]
			for iteration: int in range(2):
				var pose: Transform3D = skeleton.get_bone_global_pose(hand)
				var wrist_world: Vector3 = skeleton.global_transform * pose.origin
				var palm_offset: Vector3 = palm_world(side) - wrist_world
				_solve_limb("upperarm_" + side, "lowerarm_" + side, "hand_" + side, desired - palm_offset, pole)
			residuals[key] = palm_world(side).distance_to(targets[key])
	for side: String in foot_goals:
		_solve_limb("thigh_" + side, "calf_" + side, "foot_" + side, foot_goals[side], actor.global_position + actor.global_basis.z * 1.0 + Vector3.UP * 0.5)
	for name: String in ["pelvis", "foot_l", "foot_r", "head", "spine_03", "upperarm_l", "upperarm_r", "hand_l", "hand_r"]:
		if _bone(name) >= 0:
			anchors[name] = skeleton.global_transform * skeleton.get_bone_global_pose(_bone(name)).origin
	if capture_pose:
		captured_pose.clear()
		for index: int in range(skeleton.get_bone_count()):
			var world_pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(index)
			captured_pose[skeleton.get_bone_name(index)] = [[world_pose.basis.x.x,world_pose.basis.x.y,world_pose.basis.x.z],[world_pose.basis.y.x,world_pose.basis.y.y,world_pose.basis.y.z],[world_pose.basis.z.x,world_pose.basis.z.y,world_pose.basis.z.z],[world_pose.origin.x,world_pose.origin.y,world_pose.origin.z]]


func palm_world(side: String) -> Vector3:
	var skeleton: Skeleton3D = get_skeleton()
	var pose: Transform3D = skeleton.get_bone_global_pose(_bone("hand_" + side))
	var unit: float = 1.0 / skeleton.global_basis.get_scale().y
	return skeleton.global_transform * (pose * Vector3(0.0, 0.065 * unit, 0.0))


func head_contact_world() -> Vector3:
	var skeleton: Skeleton3D = get_skeleton()
	var index: int = _bone("head")
	if index < 0:
		return actor.global_position + Vector3.UP * 1.7
	var unit: float = 1.0 / skeleton.global_basis.get_scale().y
	return skeleton.global_transform * (skeleton.get_bone_global_pose(index) * Vector3(0.0, 0.12 * unit, 0.09 * unit))


func _solve_head(goal_world: Vector3) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	var goal: Vector3 = skeleton.to_local(goal_world)
	for iteration: int in range(24):
		for name: String in ["neck_01", "spine_03", "spine_02", "spine_01", "pelvis"]:
			var index: int = _bone(name)
			if index < 0:
				continue
			var pose: Transform3D = skeleton.get_bone_global_pose(index)
			var current: Vector3 = skeleton.to_local(head_contact_world()) - pose.origin
			var desired: Vector3 = goal - pose.origin
			if current.length() < 0.001 or desired.length() < 0.001:
				continue
			var turn := Quaternion(current.normalized(), desired.normalized())
			var maximum: float = 0.08 if name == "neck_01" else 0.14
			if turn.get_angle() > maximum:
				turn = Quaternion.IDENTITY.slerp(turn, maximum / turn.get_angle())
			pose.basis = Basis(turn) * pose.basis
			skeleton.set_bone_global_pose(index, pose)
		if head_contact_world().distance_to(goal_world) < 0.005:
			break


func _solve_limb(upper_name: String, middle_name: String, end_name: String, goal_world: Vector3, pole_world: Vector3) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	var upper: int = _bone(upper_name)
	var middle: int = _bone(middle_name)
	var end: int = _bone(end_name)
	if upper < 0 or middle < 0 or end < 0:
		return
	var upper_pose: Transform3D = skeleton.get_bone_global_pose(upper)
	var middle_pose: Transform3D = skeleton.get_bone_global_pose(middle)
	var end_pose: Transform3D = skeleton.get_bone_global_pose(end)
	var end_basis: Basis = end_pose.basis
	var first: float = upper_pose.origin.distance_to(middle_pose.origin)
	var second: float = middle_pose.origin.distance_to(end_pose.origin)
	var line: Vector3 = skeleton.to_local(goal_world) - upper_pose.origin
	if line.length() < 0.001:
		return
	var distance: float = clampf(line.length(), absf(first - second) + 0.001, first + second - 0.001)
	var axis: Vector3 = line.normalized()
	var pole: Vector3 = skeleton.to_local(pole_world) - upper_pose.origin
	var bend: Vector3 = (pole - axis * pole.dot(axis)).normalized()
	if bend.length() < 0.01:
		bend = axis.cross(Vector3.RIGHT).normalized()
	var along: float = (first * first - second * second + distance * distance) / (2.0 * distance)
	var elbow: Vector3 = upper_pose.origin + axis * along + bend * sqrt(maxf(0.0, first * first - along * along))
	var goal: Vector3 = upper_pose.origin + axis * distance
	var turn := Quaternion((middle_pose.origin - upper_pose.origin).normalized(), (elbow - upper_pose.origin).normalized())
	upper_pose.basis = Basis(turn) * upper_pose.basis
	skeleton.set_bone_global_pose(upper, upper_pose)
	middle_pose = skeleton.get_bone_global_pose(middle)
	end_pose = skeleton.get_bone_global_pose(end)
	turn = Quaternion((end_pose.origin - middle_pose.origin).normalized(), (goal - middle_pose.origin).normalized())
	middle_pose.basis = Basis(turn) * middle_pose.basis
	skeleton.set_bone_global_pose(middle, middle_pose)
	end_pose = skeleton.get_bone_global_pose(end)
	end_pose.basis = end_basis
	skeleton.set_bone_global_pose(end, end_pose)
