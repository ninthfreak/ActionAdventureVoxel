extends CharacterBody3D
## Plane-constrained movement that plays like a 2D action RPG.
## Input is world-frame: "up" always moves toward -Z (the top of the screen)
## regardless of the camera pitch, so the controls stay consistent whether
## you scrub the camera to a true top-down or a tilted 3/4 view.

@export var move_speed: float = 6.0
@export var acceleration: float = 60.0
## How quickly the body rotates to face the direction it is moving.
@export var turn_speed: float = 12.0
@export var gravity: float = 24.0

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
