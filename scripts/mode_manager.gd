extends Node
## Coordinates the three editor modes and owns all mode transitions:
##   EXPLORE - third-person character, orthographic follow cam, mouse-aim build
##   BUILD   - first-person Minecraft-style building, captured mouse
##   GOD     - no character, free-fly camera + world-shaping tools
## The menu bar and F1/F2/F3 both route through set_mode().

enum Mode { EXPLORE, BUILD, GOD }

@export var player_path: NodePath
@export var rig_camera_path: NodePath
@export var fps_camera_path: NodePath
@export var god_path: NodePath
@export var block_editor_path: NodePath

signal mode_changed(mode: int)

var mode := Mode.EXPLORE

var _player: CharacterBody3D
var _rig_cam: Camera3D
var _fps_cam: Camera3D
var _god: Node
var _editor: Node

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_rig_cam = get_node_or_null(rig_camera_path)
	_fps_cam = get_node_or_null(fps_camera_path)
	_god = get_node_or_null(god_path)
	_editor = get_node_or_null(block_editor_path)
	# defer so every node's _ready (god panel, editor cursor) has run first
	set_mode.call_deferred(Mode.EXPLORE)

func set_mode(m: int) -> void:
	mode = m
	# tear down everything first, then activate the target mode
	if _god:
		_god.set_active(false)
	if _editor:
		_editor.set_active(false)
	if _player:
		_player.first_person = false

	match m:
		Mode.EXPLORE:
			# pure "run around" mode — no block editing, mouse free for menus
			_player.control_enabled = true
			_player.set_body_visible(true)
			if _rig_cam:
				_rig_cam.current = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Mode.BUILD:
			_player.control_enabled = true
			_player.first_person = true
			_player.set_body_visible(false)
			if _fps_cam:
				_fps_cam.current = true
			if _editor:
				_editor.set_camera(_fps_cam)
				_editor.aim_from_center = true
				_editor.set_active(true)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Mode.GOD:
			_player.control_enabled = false
			_player.set_body_visible(false)
			_reset_shader_globals()
			if _god:
				_god.set_active(true)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	mode_changed.emit(mode)

## Temporarily halt player control (e.g. while a modal file dialog is open, so
## typing a filename doesn't also drive the character). Restores the mode's
## normal control state when unfrozen.
func set_frozen(frozen: bool) -> void:
	if not _player:
		return
	if frozen:
		_player.control_enabled = false
	else:
		_player.control_enabled = (mode != Mode.GOD)

func _reset_shader_globals() -> void:
	RenderingServer.global_shader_parameter_set("voxel_cutaway", 0.0)
	RenderingServer.global_shader_parameter_set("voxel_water_reveal", 0.0)
	RenderingServer.global_shader_parameter_set("voxel_cut_height", 100000.0)
	RenderingServer.global_shader_parameter_set("voxel_cut_radius", 10.0)
	RenderingServer.global_shader_parameter_set("voxel_cut_soft", 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mode_explore"):
		set_mode(Mode.EXPLORE)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mode_build"):
		set_mode(Mode.BUILD)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mode_god"):
		set_mode(Mode.GOD)
		get_viewport().set_input_as_handled()
	elif mode == Mode.BUILD and event.is_action_pressed("ui_cancel"):
		# release the mouse to reach the menu bar; Esc again re-captures
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif mode == Mode.BUILD and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE \
		and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# clicked back into the 3D view (not on UI, since this is unhandled) —
		# recapture and swallow the click so it doesn't also place a block
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
