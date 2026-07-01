extends CharacterBody3D

@export var move_speed: float = 6.0
@export var acceleration: float = 60.0
@export var turn_speed: float = 12.0
@export var gravity: float = 24.0

var _model: Node3D
var _anim_player: AnimationPlayer
var _current_anim := ""

func _ready() -> void:
	_spawn_model()
	if _anim_player:
		_load_mixamo_anims()
		_play_anim("idle")

func _spawn_model() -> void:
	var scene := load("res://bodies/animations/fem.dae") as PackedScene
	if not scene:
		push_warning("Could not load player model fem.dae")
		return
	_model = scene.instantiate() as Node3D
	add_child(_model)
	_anim_player = _find_animation_player(_model)

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
		var scene := load(path) as PackedScene
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
						lib.add_animation(anim_name, anim.duplicate())
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
	var target := input_dir * move_speed

	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	if input_dir.length() > 0.1:
		var desired_yaw := atan2(input_dir.x, input_dir.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(turn_speed * delta, 0.0, 1.0))

	_update_animation()

func _update_animation() -> void:
	if not is_on_floor():
		_play_anim("falling")
		return
	var h_speed := Vector2(velocity.x, velocity.z).length()
	if h_speed > 0.5:
		_play_anim("walking")
	else:
		_play_anim("idle")
