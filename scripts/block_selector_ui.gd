extends CanvasLayer
## Tab block selector for Build mode. Left column lists materials (plus the
## Delete tool); the grid shows every shape available for the chosen
## material. Picking a block selects it and switches to the Place tool.

@export var editor_path: NodePath
@export var mode_manager_path: NodePath

var _editor: Node
var _mode_manager: Node
var _panel: PanelContainer
var _material_list: VBoxContainer
var _grid: GridContainer
var _grid_title: Label
var _open := false

## material name -> Array of {id, shape}
var _by_material: Dictionary = {}
var _current_material := ""

func _ready() -> void:
	_editor = get_node(editor_path)
	_mode_manager = get_node_or_null(mode_manager_path)
	_collect_blocks()
	_build_ui()
	visible = false

func _collect_blocks() -> void:
	for id in BlockRegistry.get_placeable_ids():
		var block_name := BlockRegistry.get_name_from_id(id)
		var mat := block_name.get_slice(".", 0)
		var shape := block_name.get_slice(".", 1)
		if not _by_material.has(mat):
			_by_material[mat] = []
		_by_material[mat].append({"id": id, "shape": shape})

func _unhandled_input(event: InputEvent) -> void:
	if not _editor.active:
		return
	if event.is_action_pressed("block_selector"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif _open and event is InputEventMouseButton and event.pressed:
		# clicked outside the panel — close instead of leaving it dangling
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	_open = not _open
	visible = _open
	if _mode_manager:
		_mode_manager.set_frozen(_open)
	if _open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if _current_material.is_empty() and not _by_material.is_empty():
			var mats := _by_material.keys()
			mats.sort()
			_show_material(mats[0])
	else:
		# back to the captured first-person cursor if we're still in Build
		if _mode_manager and _mode_manager.mode == 1:  # Mode.BUILD
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_material(mat: String) -> void:
	_current_material = mat
	_grid_title.text = mat.capitalize()
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var entries: Array = _by_material[mat]
	entries.sort_custom(func(a, b): return a["shape"] < b["shape"])
	for e: Dictionary in entries:
		var btn := Button.new()
		btn.text = str(e["shape"])
		btn.icon = BlockRegistry.get_icon(e["id"])
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2(96, 88)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.add_theme_font_size_override("font_size", 11)
		btn.focus_mode = Control.FOCUS_NONE
		var id: int = e["id"]
		btn.pressed.connect(func():
			_editor.select_block(id)
			_toggle())
		_grid.add_child(btn)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -380.0
	_panel.offset_right = 380.0
	_panel.offset_top = -250.0
	_panel.offset_bottom = 250.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.13, 0.95)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12.0)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	_panel.add_child(hbox)

	# left: delete tool + material list
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 170.0
	left.add_theme_constant_override("separation", 4)
	hbox.add_child(left)

	var title := Label.new()
	title.text = "BLOCKS  [Tab]"
	title.add_theme_font_size_override("font_size", 15)
	left.add_child(title)

	var del_btn := Button.new()
	del_btn.text = "✖ Delete Tool"
	del_btn.focus_mode = Control.FOCUS_NONE
	del_btn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	del_btn.pressed.connect(func():
		_editor.set_tool(1)  # Tool.DELETE
		_toggle())
	left.add_child(del_btn)

	left.add_child(HSeparator.new())

	var mat_scroll := ScrollContainer.new()
	mat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(mat_scroll)

	_material_list = VBoxContainer.new()
	_material_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_material_list.add_theme_constant_override("separation", 2)
	mat_scroll.add_child(_material_list)

	var mats := _by_material.keys()
	mats.sort()
	for m: String in mats:
		var btn := Button.new()
		btn.text = m.capitalize()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_show_material.bind(m))
		_material_list.add_child(btn)

	# right: shape grid for the chosen material
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	hbox.add_child(right)

	_grid_title = Label.new()
	_grid_title.add_theme_font_size_override("font_size", 14)
	right.add_child(_grid_title)

	var grid_scroll := ScrollContainer.new()
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(grid_scroll)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	grid_scroll.add_child(_grid)
