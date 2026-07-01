extends CharacterBody3D

@export var walk_speed: float = 6.0
@export var run_speed: float = 12.0
@export var acceleration: float = 60.0
@export var turn_speed: float = 12.0
@export var gravity: float = 24.0
@export var jump_force: float = 10.0

var _model: Node3D
var _anim_player: AnimationPlayer
var _current_anim := ""
var _is_jumping := false

func _ready() -> void:
	_spawn_model()
	if _anim_player:
		_load_mixamo_anims()
		_play_anim("idle")

func _spawn_model() -> void:
	var scene := load("res://bodies/animations/fem.dae") as PackedScene
	if not scene:
		push_warning("Player: could not load fem.dae")
		return
	_model = scene.instantiate() as Node3D
	_model.scale = Vector3(102, 102, 102)
	add_child(_model)

	_fix_skinning()
	_anim_player = _find_animation_player(_model)

func _fix_skinning() -> void:
	var skel := _model.get_node_or_null("Skeleton3D") as Skeleton3D
	if not skel:
		return

	var joint_names: Array[String] = [
		"mixamorig_RightLeg", "mixamorig_RightFoot", "mixamorig_RightToeBase",
		"mixamorig_LeftFoot", "mixamorig_LeftToeBase", "mixamorig_LeftLeg",
		"mixamorig_LeftUpLeg", "mixamorig_RightUpLeg", "mixamorig_Hips",
		"mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2",
		"mixamorig_RightArm", "mixamorig_RightShoulder", "mixamorig_LeftShoulder",
		"mixamorig_LeftArm", "mixamorig_LeftHand", "mixamorig_Neck",
		"mixamorig_Head", "mixamorig_RightHandIndex2", "mixamorig_RightHandIndex3",
		"mixamorig_LeftHandIndex2", "mixamorig_LeftHandIndex3",
		"mixamorig_LeftHandIndex1", "mixamorig_RightHandIndex1",
		"mixamorig_RightHand", "mixamorig_LeftForeArm",
	]

	var ibm_list := _get_inverse_bind_matrices()
	var ibm_map := {}
	for i in joint_names.size():
		ibm_map[joint_names[i]] = ibm_list[i]

	var bone_count := skel.get_bone_count()
	var skin := Skin.new()
	skin.set_bind_count(bone_count)
	for i in bone_count:
		var bone_name := skel.get_bone_name(i)
		skin.set_bind_bone(i, i)
		skin.set_bind_name(i, bone_name)
		if ibm_map.has(bone_name):
			var t: Transform3D = ibm_map[bone_name]
			t.origin *= 0.01
			skin.set_bind_pose(i, t)
		else:
			skin.set_bind_pose(i, skel.get_bone_global_rest(i).inverse())

	for child in skel.get_children():
		if child is MeshInstance3D:
			child.skeleton = child.get_path_to(skel)
			child.skin = skin

func _ibm(m: Array) -> Transform3D:
	return Transform3D(
		Vector3(m[0], m[4], m[8]),
		Vector3(m[1], m[5], m[9]),
		Vector3(m[2], m[6], m[10]),
		Vector3(m[3], m[7], m[11]))

func _get_inverse_bind_matrices() -> Array[Transform3D]:
	var r: Array[Transform3D] = []
	r.append(_ibm([-0.999969,0.007838,-0.000224,-0.064303,-0.007839,-0.999969,0.000722,0.212315,-0.000219,0.000724,1.0,0.032188,0,0,0,1]))
	r.append(_ibm([-0.849496,0.006278,-0.527557,-0.071609,-0.371408,-0.7173,0.589522,0.055497,-0.374716,0.696736,0.611676,-0.062504,0,0,0,1]))
	r.append(_ibm([-0.838559,-0.013429,-0.544646,-0.069812,-0.543832,-0.039284,0.838274,-0.085653,-0.032654,0.999138,0.025639,-0.007527,0,0,0,1]))
	r.append(_ibm([-0.822642,0.003337,0.568549,0.071091,0.381902,-0.737566,0.556909,0.052104,0.421201,0.675266,0.605479,-0.067549,0,0,0,1]))
	r.append(_ibm([-0.84219,-0.029572,0.538369,0.074299,0.539167,-0.038947,0.841298,-0.085701,-0.003911,0.998804,0.048745,-0.004364,0,0,0,1]))
	r.append(_ibm([-0.999969,-0.007833,0.000311,0.067699,0.007837,-0.999821,0.017209,0.212763,0.000176,0.017211,0.999852,0.027078,0,0,0,1]))
	r.append(_ibm([-0.999982,-0.006044,0.00024,0.067317,0.006049,-0.999194,0.039691,0.407272,0.0,0.039691,0.999212,0.022286,0,0,0,1]))
	r.append(_ibm([-0.999982,0.006048,-0.000173,-0.063921,-0.006051,-0.999572,0.028615,0.407004,0.0,0.028616,0.99959,0.026253,0,0,0,1]))
	r.append(_ibm([1.0,0.0,0.0,-0.001698,0.0,1.0,0.0,-0.462099,0.0,0.0,1.0,0.038386,0,0,0,1]))
	r.append(_ibm([1.0,0.0,0.0,-0.001698,0.0,0.999548,0.030076,-0.560941,0.0,-0.030076,0.999548,0.052267,0,0,0,1]))
	r.append(_ibm([1.0,0.0,0.0,-0.001698,0.0,0.999548,0.030076,-0.677847,0.0,-0.030076,0.999548,0.052267,0,0,0,1]))
	r.append(_ibm([1.0,0.0,0.0,-0.001698,0.0,0.999548,0.030076,-0.811454,0.0,-0.030076,0.999548,0.052267,0,0,0,1]))
	r.append(_ibm([-0.225689,0.1209,0.966668,-0.094548,-0.005006,-0.9924,0.12295,0.910725,0.974186,0.022909,0.224579,0.199356,0,0,0,1]))
	r.append(_ibm([-0.189419,-0.035512,0.981254,0.056497,-0.951855,-0.238666,-0.192381,0.149591,0.241024,-0.970452,0.011406,0.935358,0,0,0,1]))
	r.append(_ibm([-0.158071,0.034691,-0.986818,-0.055395,0.957199,-0.240006,-0.161764,0.148736,-0.242454,-0.970151,0.004731,0.93574,0,0,0,1]))
	r.append(_ibm([-0.192567,-0.110851,-0.975003,0.085232,0.005012,-0.993697,0.111987,0.910399,-0.981271,0.016678,0.191909,0.206401,0,0,0,1]))
	r.append(_ibm([-0.194097,0.048371,-0.979789,-0.000906,0.019652,-0.998391,-0.053182,0.471856,-0.980786,-0.029577,0.192834,0.233695,0,0,0,1]))
	r.append(_ibm([1.0,0.0,0.0,-0.001698,0.0,1.0,0.0,-0.962899,0.0,0.0,1.0,0.023317,0,0,0,1]))
	r.append(_ibm([1.0,0.0,0.0,-0.001698,0.0,1.0,0.0,-1.079378,0.0,0.0,1.0,0.027207,0,0,0,1]))
	r.append(_ibm([-0.227526,-0.020219,0.973562,-0.016573,0.025666,-0.999562,-0.014761,0.393458,0.973434,0.021629,0.227945,0.211071,0,0,0,1]))
	r.append(_ibm([-0.227526,-0.020219,0.973562,-0.005966,0.025666,-0.999562,-0.014761,0.359618,0.973434,0.021629,0.227945,0.207143,0,0,0,1]))
	r.append(_ibm([-0.195046,0.127833,-0.972428,-0.03326,0.045623,-0.989214,-0.13919,0.366855,-0.979732,-0.071513,0.18711,0.250602,0,0,0,1]))
	r.append(_ibm([-0.195046,0.127833,-0.972428,-0.038694,0.045623,-0.989214,-0.13919,0.340053,-0.979732,-0.071513,0.18711,0.240173,0,0,0,1]))
	r.append(_ibm([-0.195046,0.127833,-0.972428,-0.03326,0.045623,-0.989214,-0.13919,0.394137,-0.979732,-0.071513,0.18711,0.250602,0,0,0,1]))
	r.append(_ibm([-0.227526,-0.020219,0.973562,-0.016573,0.025666,-0.999562,-0.014761,0.424659,0.973434,0.021629,0.227945,0.211071,0,0,0,1]))
	r.append(_ibm([-0.225945,0.005445,0.974125,-0.026978,-0.06438,-0.997882,-0.009355,0.462875,0.97201,-0.064827,0.225817,0.246977,0,0,0,1]))
	r.append(_ibm([-0.192414,-0.037429,-0.9806,0.039724,0.027893,-0.999077,0.032661,0.611664,-0.980917,-0.021068,0.19328,0.229665,0,0,0,1]))
	return r

func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _load_mixamo_anims() -> void:
	var anim_files := {
		"idle": "res://bodies/animations/idle.dae",
		"walking": "res://bodies/animations/walking.dae",
		"running": "res://bodies/animations/running.dae",
		"falling": "res://bodies/animations/falling idle.dae",
		"landing": "res://bodies/animations/hard landing.dae",
		"jump": "res://bodies/animations/jumping up.dae",
	}
	for anim_name in anim_files:
		var path: String = anim_files[anim_name]
		if not ResourceLoader.exists(path):
			continue
		var res := load(path)
		if not res:
			continue
		var scene := res as PackedScene
		if not scene:
			continue
		var inst := scene.instantiate()
		var src_player := _find_animation_player(inst)
		if src_player:
			for src_name in src_player.get_animation_list():
				if src_name == "RESET":
					continue
				var anim := src_player.get_animation(src_name)
				if anim:
					var lib := _anim_player.get_animation_library("")
					if lib:
						var dup := anim.duplicate()
						if anim_name in ["idle", "walking", "running", "falling"]:
							dup.loop_mode = Animation.LOOP_LINEAR
						lib.add_animation(anim_name, dup)
		inst.queue_free()

func _play_anim(anim_name: String) -> void:
	if not _anim_player or _current_anim == anim_name:
		return
	if _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name)
		_current_anim = anim_name

func _read_input_direction() -> Vector3:
	var raw := Vector3.ZERO
	raw.x = Input.get_axis("move_left", "move_right")
	raw.z = Input.get_axis("move_up", "move_down")
	if raw.length() < 0.01:
		return Vector3.ZERO
	var cam_rig := get_node_or_null("../CameraRig")
	if cam_rig:
		var yaw := deg_to_rad(cam_rig.camera_rotate_degrees)
		var c := cos(yaw)
		var s := sin(yaw)
		raw = Vector3(raw.x * c - raw.z * s, 0.0, raw.x * s + raw.z * c)
	return raw.normalized()

func _physics_process(delta: float) -> void:
	var input_dir := _read_input_direction()
	var running := Input.is_action_pressed("run")
	var speed := run_speed if running else walk_speed
	var target := input_dir * speed

	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

	if is_on_floor():
		if _is_jumping:
			_is_jumping = false
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force
			_is_jumping = true
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	if input_dir.length() > 0.1:
		var desired_yaw := atan2(input_dir.x, input_dir.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(turn_speed * delta, 0.0, 1.0))

	_update_animation()

func _update_animation() -> void:
	if not is_on_floor():
		if _is_jumping and velocity.y > 0.0:
			_play_anim("jump")
		else:
			_play_anim("falling")
		return
	var h_speed := Vector2(velocity.x, velocity.z).length()
	if h_speed > run_speed * 0.7:
		_play_anim("running")
	elif h_speed > 0.5:
		_play_anim("walking")
	else:
		_play_anim("idle")
