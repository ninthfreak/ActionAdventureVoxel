extends Node
## God mode: a free-fly camera plus a palette of world-shaping tools. Owns its
## own tool panel (left side) and routes left clicks in the 3D view to the
## active tool. Right mouse is the camera's (look/fly), so it never reaches a
## tool. New tools are added by appending to _make_tools().

@export var voxel_world_path: NodePath
@export var free_camera_path: NodePath

var active := false
var _world: Node
var _camera: Camera3D
var _tools: Array[GodTool] = []
var _tool_idx := 0

var _layer: CanvasLayer
var _panel: PanelContainer
var _options: VBoxContainer
var _help: Label
var _tool_buttons: Array[Button] = []

func _ready() -> void:
	_world = get_node(voxel_world_path)
	_camera = get_node_or_null(free_camera_path) as Camera3D
	_tools = _make_tools()
	_build_ui()
	set_active(false)

func _make_tools() -> Array[GodTool]:
	var tools: Array[GodTool] = [
		TerrainBrushTool.new(_world),
		PaintTool.new(_world),
		WallTool.new(_world),
		RegenerateTool.new(_world),
		ScatterTool.new(_world),
	]
	return tools

func set_active(v: bool) -> void:
	active = v
	set_process_unhandled_input(v)
	if _layer:
		_layer.visible = v
	if _camera:
		_camera.set_enabled(v)
		if v:
			_camera.current = true
	if v:
		_select_tool(_tool_idx)
	else:
		for t in _tools:
			t.on_deactivate()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _raycast()
		_tools[_tool_idx].on_primary(hit)
		get_viewport().set_input_as_handled()

func _raycast() -> Dictionary:
	if not _camera:
		return {}
	var mouse := _camera.get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var dir := _camera.project_ray_normal(mouse)
	var space := _camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 500.0)
	return space.intersect_ray(query)

func _select_tool(idx: int) -> void:
	if idx < 0 or idx >= _tools.size():
		return
	_tools[_tool_idx].on_deactivate()
	_tool_idx = idx
	for i in _tool_buttons.size():
		_tool_buttons[i].button_pressed = (i == idx)
	for c in _options.get_children():
		_options.remove_child(c)
		c.queue_free()
	var active_tool := _tools[idx]
	active_tool.build_options(_options)
	_help.text = active_tool.get_help()

# --- UI -----------------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 8.0
	_panel.offset_top = 44.0
	_panel.offset_right = 236.0
	_panel.offset_bottom = -8.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.14, 0.92)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10.0)
	_panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.custom_minimum_size.x = 208.0
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "GOD MODE"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	for i in _tools.size():
		var btn := Button.new()
		btn.text = _tools[i].get_display_name()
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		var idx := i
		btn.pressed.connect(func(): _select_tool(idx))
		vbox.add_child(btn)
		_tool_buttons.append(btn)

	vbox.add_child(HSeparator.new())

	var opt_title := Label.new()
	opt_title.text = "Options"
	opt_title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(opt_title)

	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 4)
	vbox.add_child(_options)

	vbox.add_child(HSeparator.new())

	_help = Label.new()
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.add_theme_font_size_override("font_size", 11)
	_help.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75))
	vbox.add_child(_help)
