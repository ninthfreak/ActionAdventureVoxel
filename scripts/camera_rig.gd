@tool
extends Node3D
## Orthographic camera rig for a 3D-rendered-as-2D action RPG.
##
## The rig pivots about its X axis; the camera sits at a fixed local offset
## behind it. Rotating the rig orbits the camera from a flat side view (pitch 0)
## up to a true top-down (pitch 90) with no gimbal degeneracy, and screen-up
## always corresponds to world -Z, so player input mapping stays constant.
##
## All three knobs below are exported and update live in the editor — scrub them
## in the inspector with the scene open to find the look you want:
##   - camera_pitch_degrees: 90 = classic top-down, ~55-65 = tilted 3/4 (shows voxels)
##   - camera_distance: how far the camera sits back (orthographic, so this only
##     affects clipping/feel, not apparent size)
##   - camera_view_size: the orthographic zoom — smaller = more zoomed in

@export_range(0.0, 90.0, 0.5) var camera_pitch_degrees: float = 60.0:
	set(value):
		camera_pitch_degrees = value
		_apply()

@export_range(-180.0, 180.0, 0.5) var camera_rotate_degrees: float = 0.0:
	set(value):
		camera_rotate_degrees = value
		_apply()

@export var camera_distance: float = 18.0:
	set(value):
		camera_distance = value
		_apply()

@export var camera_view_size: float = 12.0:
	set(value):
		camera_view_size = value
		_apply()

## What the camera follows at runtime (the Player). Leave empty to stay put.
@export var target_path: NodePath

## Degrees per second when rotating with the gamepad right stick.
@export var camera_rotate_speed: float = 150.0

func _ready() -> void:
	_apply()

func _apply() -> void:
	rotation_degrees = Vector3(-camera_pitch_degrees, camera_rotate_degrees, 0.0)
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.position = Vector3(0.0, 0.0, camera_distance)
		cam.rotation = Vector3.ZERO
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = camera_view_size

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var turn := Input.get_axis("camera_left", "camera_right")
	if absf(turn) > 0.0:
		camera_rotate_degrees = wrapf(camera_rotate_degrees - turn * camera_rotate_speed * delta, -180.0, 180.0)
	if target_path.is_empty():
		return
	var t := get_node_or_null(target_path) as Node3D
	if t:
		global_position = t.global_position
