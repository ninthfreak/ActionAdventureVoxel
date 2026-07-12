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

## Selected floor band (Floors.MIN_FLOOR..MAX_FLOOR), or MAX_FLOOR+1 = "All"
## (no slicing). The slice hides every block above the floor's top plane.
var _slice_floor := Floors.MAX_FLOOR + 1
var _floor_slider: VSlider
var _floor_label: Label

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
		_apply_slice()
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
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_PAGEUP and _floor_slider:
			_floor_slider.value += 1
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_PAGEDOWN and _floor_slider:
			_floor_slider.value -= 1
			get_viewport().set_input_as_handled()

## Slicing hides blocks above the active floor but their collision shapes
## remain, so the ray marches past any hit above the slice plane — tools only
## ever act on what's visible.
func _raycast() -> Dictionary:
	if not _camera:
		return {}
	var mouse := _camera.get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var dir := _camera.project_ray_normal(mouse)
	var space := _camera.get_world_3d().direct_space_state
	var cut := 1e9 if _slice_floor > Floors.MAX_FLOOR else float(Floors.top_of(_slice_floor))
	var from := origin
	for _i in 32:
		var query := PhysicsRayQueryParameters3D.create(from, origin + dir * 500.0)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return hit
		if (hit["position"] as Vector3).y <= cut + 0.05:
			return hit
		from = (hit["position"] as Vector3) + dir * 0.05
	return {}

func _apply_slice() -> void:
	# hard slice (not the in-game translucent cutaway): plan view for editing
	RenderingServer.global_shader_parameter_set("voxel_cut_soft", 0.0)
	if _slice_floor > Floors.MAX_FLOOR:
		RenderingServer.global_shader_parameter_set("voxel_cutaway", 0.0)
		RenderingServer.global_shader_parameter_set("voxel_cut_height", 100000.0)
	else:
		RenderingServer.global_shader_parameter_set("voxel_cutaway", 1.0)
		RenderingServer.global_shader_parameter_set("voxel_cut_height", float(Floors.top_of(_slice_floor)))
		RenderingServer.global_shader_parameter_set("voxel_cut_radius", 1e6)
	if _floor_label:
		_floor_label.text = "All" if _slice_floor > Floors.MAX_FLOOR else str(_slice_floor)

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

	_build_floor_slider()

## Vertical floor slider docked to the right edge. Topmost position is "All"
## (no slicing); below it, each step selects one 4-block floor band and the
## whole map is sliced at that floor's ceiling plane. PgUp/PgDn also step it.
func _build_floor_slider() -> void:
	var side := PanelContainer.new()
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_top = 0.0
	side.anchor_bottom = 1.0
	side.offset_left = -72.0
	side.offset_right = -8.0
	side.offset_top = 44.0
	side.offset_bottom = -8.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.14, 0.92)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10.0)
	side.add_theme_stylebox_override("panel", style)
	_layer.add_child(side)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	side.add_child(vbox)

	var title := Label.new()
	title.text = "Floor"
	title.add_theme_font_size_override("font_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_floor_label = Label.new()
	_floor_label.text = "All"
	_floor_label.add_theme_font_size_override("font_size", 16)
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_floor_label)

	_floor_slider = VSlider.new()
	_floor_slider.min_value = Floors.MIN_FLOOR
	_floor_slider.max_value = Floors.MAX_FLOOR + 1  # top notch = All
	_floor_slider.step = 1
	_floor_slider.value = Floors.MAX_FLOOR + 1
	_floor_slider.tick_count = (Floors.MAX_FLOOR + 1) - Floors.MIN_FLOOR + 1
	_floor_slider.ticks_on_borders = true
	_floor_slider.focus_mode = Control.FOCUS_NONE
	_floor_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_floor_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_floor_slider.value_changed.connect(_on_floor_slider_changed)
	vbox.add_child(_floor_slider)

	var hint := Label.new()
	hint.text = "PgUp\nPgDn"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

func _on_floor_slider_changed(v: float) -> void:
	_slice_floor = int(v)
	_apply_slice()
