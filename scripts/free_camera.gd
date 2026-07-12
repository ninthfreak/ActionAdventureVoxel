extends Camera3D
## Editor-style free-fly camera for God mode. Hold right mouse button to look
## and fly with WASD (+ Q/E or Space/Ctrl for down/up); scroll adjusts speed;
## Shift boosts. Only processes while enabled by the GodMode controller.

@export var move_speed: float = 20.0
@export var boost_multiplier: float = 3.0
@export var look_sensitivity: float = 0.005

var enabled := false
var _yaw := 0.0
var _pitch := -0.4
var _looking := false

func set_enabled(v: bool) -> void:
	enabled = v
	set_process(v)
	if not v:
		_looking = false

func _ready() -> void:
	# start looking down at the world; position comes from the scene
	rotation = Vector3(_pitch, _yaw, 0.0)
	set_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_looking = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and _looking:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			move_speed = minf(move_speed * 1.15, 200.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			move_speed = maxf(move_speed / 1.15, 2.0)
	elif event is InputEventMouseMotion and _looking:
		_yaw -= event.relative.x * look_sensitivity
		_pitch = clampf(_pitch - event.relative.y * look_sensitivity, -1.5, 1.5)
		rotation = Vector3(_pitch, _yaw, 0.0)

func _process(delta: float) -> void:
	if not _looking:
		return  # only fly while actively looking, like the Godot editor
	var dir := Vector3.ZERO
	dir.x = Input.get_axis("move_left", "move_right")
	dir.z = Input.get_axis("move_up", "move_down")
	var vertical := Input.get_action_strength("fly_up") - Input.get_action_strength("fly_down")
	var basis_move := (global_transform.basis * Vector3(dir.x, 0.0, dir.z))
	basis_move.y = 0.0
	var motion := basis_move + Vector3.UP * vertical
	if motion.length() > 0.001:
		var speed := move_speed * (boost_multiplier if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		global_position += motion.normalized() * speed * delta
