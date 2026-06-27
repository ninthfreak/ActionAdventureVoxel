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
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	return dir.normalized()

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
