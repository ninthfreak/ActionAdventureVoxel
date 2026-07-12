extends Node
## Block editing for Build mode (first person, screen-center aim; also works
## with mouse aim). Two explicit tools chosen via the Tab block selector:
##   PLACE  — LMB places the selected block; a full-color translucent ghost
##            previews the exact cell and rotation before you click.
##   DELETE — LMB removes the targeted block, which is shown with a bright
##            outline. Right-click never deletes.
## R taps spin the pending block 90°; holding R opens an orientation picker
## covering all 24 orientations: Up/Down arrows choose which way the block's
## top faces, Left/Right spin it, release R to confirm.

enum Tool { PLACE, DELETE }

@export var voxel_world_path: NodePath
@export var camera_path: NodePath
@export var mode_manager_path: NodePath

var active := false
## Aim from the screen center (first person) instead of the mouse cursor.
var aim_from_center := false
var tool: int = Tool.PLACE
var selected_id := 0
var cursor_rot := 0

var _world: Node
var _camera: Camera3D
var _mode_manager: Node
var _sfx: BlockSfx

var _ghost: MeshInstance3D
var _ghost_meshes: Dictionary = {}
var _outline: MeshInstance3D

# hold-R orientation picker (all 24 orientations)
var _rotate_held := false
var _rotate_hold_time := 0.0
var _picker_open := false
var _picker_prev_rot := 0
var _picker_had_capture := false
var _picker_layer: CanvasLayer
var _picker_buttons: Array[Button] = []
var _up_label: Label
const HOLD_THRESHOLD := 0.32
const SPIN_NAMES := ["0°", "90°", "180°", "270°"]

# hold-Tab copy menu (tap Tab = block selector, via selector_requested)
var _tab_held := false
var _tab_hold_time := 0.0
var _copy_open := false
var _copy_layer: CanvasLayer
var _copy_title: Label
var _copy_labels: Array[Label] = []
var _copy_choice := 2
var _copy_id := 0
var _copy_rot := 0
const COPY_OPTIONS := ["Copy Block", "Copy Orientation", "Copy Block + Orientation"]

signal editor_toggled(is_active: bool)
signal block_selected(block_id: int, block_name: String)
signal tool_changed(tool: int)
signal selector_requested

func _ready() -> void:
	_world = get_node(voxel_world_path)
	_camera = get_node_or_null(camera_path)
	_mode_manager = get_node_or_null(mode_manager_path)
	var ids := BlockRegistry.get_placeable_ids()
	selected_id = BlockRegistry.get_id("grass.cube")
	if selected_id == BlockRegistry.AIR and not ids.is_empty():
		selected_id = ids[0]
	_sfx = BlockSfx.new()
	add_child(_sfx)

	_ghost = MeshInstance3D.new()
	_ghost.visible = false
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().root.add_child.call_deferred(_ghost)

	_outline = MeshInstance3D.new()
	_outline.visible = false
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline.mesh = _build_outline_mesh()
	get_tree().root.add_child.call_deferred(_outline)

	_build_picker_ui()
	_build_copy_ui()
	_refresh_ghost_mesh()

func set_active(v: bool) -> void:
	if active == v:
		return
	active = v
	if not active:
		if _ghost:
			_ghost.visible = false
		if _outline:
			_outline.visible = false
		_close_picker()
		_close_copy()
	editor_toggled.emit(active)

func set_camera(cam: Camera3D) -> void:
	_camera = cam

func select_block(id: int) -> void:
	selected_id = id
	set_tool(Tool.PLACE)
	_refresh_ghost_mesh()
	block_selected.emit(id, BlockRegistry.get_name_from_id(id))

func set_tool(t: int) -> void:
	if tool == t:
		return
	tool = t
	tool_changed.emit(tool)

func get_selected_block_name() -> String:
	return BlockRegistry.get_name_from_id(selected_id)

func get_selected_block_id() -> int:
	return selected_id

# --- input ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if event.is_action_pressed("editor_rotate") and not event.is_echo():
		_rotate_held = true
		_rotate_hold_time = 0.0
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("editor_rotate"):
		if _picker_open:
			_close_picker()
		elif _rotate_held:
			# short tap: next spin around the current up axis
			_set_rot(Orientations.make(Orientations.up_index(cursor_rot), Orientations.spin(cursor_rot) + 1))
		_rotate_held = false
		get_viewport().set_input_as_handled()
		return

	# Tab: tap opens the block selector, holding opens the copy menu
	if event.is_action_pressed("block_selector") and not event.is_echo():
		_tab_held = true
		_tab_hold_time = 0.0
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("block_selector"):
		if _copy_open:
			_apply_copy()
			_close_copy()
		elif _tab_held:
			selector_requested.emit()
		_tab_held = false
		get_viewport().set_input_as_handled()
		return

	if _picker_open and event is InputEventKey and event.pressed:
		var up := Orientations.up_index(cursor_rot)
		var sp := Orientations.spin(cursor_rot)
		match event.keycode:
			KEY_UP:
				_set_rot(Orientations.make(up - 1, sp))
			KEY_DOWN:
				_set_rot(Orientations.make(up + 1, sp))
			KEY_RIGHT:
				_set_rot(Orientations.make(up, sp + 1))
			KEY_LEFT:
				_set_rot(Orientations.make(up, sp - 1))
			_:
				return
		get_viewport().set_input_as_handled()
		return

	if _copy_open and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_copy_choice = posmod(_copy_choice - 1, COPY_OPTIONS.size())
			KEY_DOWN:
				_copy_choice = posmod(_copy_choice + 1, COPY_OPTIONS.size())
			_:
				return
		_update_copy_labels()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# right-click cancels either held menu without applying
		if _copy_open:
			_close_copy()
			_tab_held = false
			get_viewport().set_input_as_handled()
			return
		if _picker_open:
			_set_rot(_picker_prev_rot)
			_close_picker()
			_rotate_held = false
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _picker_open or _copy_open:
			return
		# in first person (center aim) only act while the mouse is captured, so
		# clicks meant for the released-cursor menus don't edit blocks
		if aim_from_center and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		if tool == Tool.PLACE:
			_place_block()
		else:
			_delete_block()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active:
		return

	if _rotate_held and not _picker_open:
		_rotate_hold_time += delta
		if _rotate_hold_time >= HOLD_THRESHOLD:
			_open_picker()

	if _tab_held and not _copy_open:
		_tab_hold_time += delta
		if _tab_hold_time >= HOLD_THRESHOLD:
			_try_open_copy()

	var result := _raycast_cursor()
	if tool == Tool.PLACE:
		_outline.visible = false
		if result.is_empty():
			_ghost.visible = false
			return
		var pos := _get_place_position(result)
		_ghost.transform = Orientations.block_transform(cursor_rot, Vector3(pos))
		_ghost.visible = true
	else:
		_ghost.visible = false
		if result.is_empty():
			_outline.visible = false
			return
		var pos := _get_remove_position(result)
		if _world.get_block(pos.x, pos.y, pos.z) == BlockRegistry.AIR:
			_outline.visible = false
			return
		_outline.position = Vector3(pos)
		_outline.visible = true

# --- editing -------------------------------------------------------------

func _place_block() -> void:
	var result := _raycast_cursor()
	if result.is_empty():
		return
	var pos := _get_place_position(result)
	_world.set_block(pos.x, pos.y, pos.z, selected_id, cursor_rot)
	_sfx.play_place()

func _delete_block() -> void:
	var result := _raycast_cursor()
	if result.is_empty():
		return
	var pos := _get_remove_position(result)
	if _world.get_block(pos.x, pos.y, pos.z) != BlockRegistry.AIR:
		_world.set_block(pos.x, pos.y, pos.z, BlockRegistry.AIR)
		_sfx.play_break()

func _raycast_cursor() -> Dictionary:
	if not _camera:
		return {}
	var screen := _camera.get_viewport().get_visible_rect().size * 0.5 if aim_from_center \
		else _camera.get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(screen)
	var direction := _camera.project_ray_normal(screen)
	var space := _camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0)
	return space.intersect_ray(query)

func _get_place_position(result: Dictionary) -> Vector3i:
	var place: Vector3 = result["position"] + result["normal"] * 0.5
	return Vector3i(floori(place.x), floori(place.y), floori(place.z))

func _get_remove_position(result: Dictionary) -> Vector3i:
	var remove: Vector3 = result["position"] - result["normal"] * 0.5
	return Vector3i(floori(remove.x), floori(remove.y), floori(remove.z))

# --- ghost preview -------------------------------------------------------

## Ghost = the real block mesh with its textures/colors, re-materialed with
## the unshaded translucent ghost shader.
func _refresh_ghost_mesh() -> void:
	if not _ghost:
		return
	if _ghost_meshes.has(selected_id):
		_ghost.mesh = _ghost_meshes[selected_id]
		return
	var src := BlockRegistry.get_mesh(selected_id)
	if not src:
		return
	var ghost_shader := load("res://shaders/ghost.gdshader") as Shader
	var mesh := src.duplicate() as ArrayMesh
	for s in mesh.get_surface_count():
		var src_mat := src.surface_get_material(s) as ShaderMaterial
		var gm := ShaderMaterial.new()
		gm.shader = ghost_shader
		if src_mat:
			gm.set_shader_parameter("use_texture", src_mat.get_shader_parameter("use_texture"))
			gm.set_shader_parameter("albedo_tex", src_mat.get_shader_parameter("albedo_tex"))
			gm.set_shader_parameter("use_vertex_color", src_mat.get_shader_parameter("use_vertex_color"))
		mesh.surface_set_material(s, gm)
	_ghost_meshes[selected_id] = mesh
	_ghost.mesh = mesh

func _set_ghost_alpha(a: float) -> void:
	if not _ghost or not _ghost.mesh:
		return
	for s in _ghost.mesh.get_surface_count():
		var m := _ghost.mesh.surface_get_material(s) as ShaderMaterial
		if m:
			m.set_shader_parameter("alpha", a)

## Bright edge box marking the block DELETE will remove.
func _build_outline_mesh() -> ArrayMesh:
	var half := 0.512  # slightly larger than the cell so lines don't z-fight
	var lo := Vector3(-half, 0.5 - half, -half)
	var hi := Vector3(half, 0.5 + half, half)
	var corners := [
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z),
		Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z),
		Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	]
	var edges := [0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, 2, 6, 3, 7]
	var pts := PackedVector3Array()
	for e in edges:
		pts.append(corners[e])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.no_depth_test = false
	mesh.surface_set_material(0, mat)
	return mesh

# --- copy menu (hold Tab) --------------------------------------------------

## Samples the aimed block when the hold threshold fires. Stays pending (and
## keeps trying) while the crosshair is over air.
func _try_open_copy() -> void:
	var result := _raycast_cursor()
	if result.is_empty():
		return
	var pos := _get_remove_position(result)
	var id: int = _world.get_block(pos.x, pos.y, pos.z)
	if id == BlockRegistry.AIR:
		return
	_copy_id = id
	_copy_rot = _world.get_rot(pos.x, pos.y, pos.z)
	_copy_choice = 2  # block + orientation is the common case
	_copy_open = true
	_copy_title.text = BlockRegistry.get_name_from_id(id).replace(".", "  ").capitalize()
	_update_copy_labels()
	_copy_layer.visible = true
	if _mode_manager:
		_mode_manager.set_frozen(true)  # arrows navigate the menu

func _apply_copy() -> void:
	match _copy_choice:
		0:
			select_block(_copy_id)
		1:
			_set_rot(_copy_rot)
		2:
			select_block(_copy_id)
			_set_rot(_copy_rot)

func _close_copy() -> void:
	if not _copy_open:
		return
	_copy_open = false
	_copy_layer.visible = false
	if _mode_manager:
		_mode_manager.set_frozen(false)

func _update_copy_labels() -> void:
	for i in _copy_labels.size():
		var current := i == _copy_choice
		_copy_labels[i].add_theme_color_override("font_color",
			Color(1.0, 0.9, 0.3) if current else Color(0.65, 0.68, 0.72))
		_copy_labels[i].text = ("»  %s  «" if current else "%s") % COPY_OPTIONS[i]

func _build_copy_ui() -> void:
	_copy_layer = CanvasLayer.new()
	_copy_layer.visible = false
	add_child(_copy_layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -150.0
	panel.offset_right = 150.0
	panel.offset_top = -90.0
	panel.offset_bottom = 90.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.13, 0.9)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", style)
	_copy_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	_copy_title = Label.new()
	_copy_title.add_theme_font_size_override("font_size", 14)
	_copy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_copy_title)

	vbox.add_child(HSeparator.new())

	for i in COPY_OPTIONS.size():
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)
		_copy_labels.append(lbl)

	var hint := Label.new()
	hint.text = "↑/↓ choose — release Tab to apply — RMB cancels"
	hint.add_theme_font_size_override("font_size", 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
	vbox.add_child(hint)

# --- orientation picker (hold R) --------------------------------------------
## A 6x4 grid (top-face rows x spin columns). Hovering a cell applies that
## orientation to the in-world ghost immediately — the ghost IS the preview.
## Click or release R to confirm; RMB restores the previous orientation.

func _open_picker() -> void:
	_picker_open = true
	_picker_prev_rot = cursor_rot
	_picker_layer.visible = true
	_set_ghost_alpha(0.22)  # wireframe-ish: mostly see-through with edges
	_outline.position = _ghost.position
	_outline.visible = tool == Tool.PLACE and _ghost.visible
	_update_picker_labels()
	_picker_had_capture = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _picker_had_capture:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _mode_manager:
		_mode_manager.set_frozen(true)  # arrows/mouse must not move the character

func _close_picker() -> void:
	if not _picker_open:
		return
	_picker_open = false
	_picker_layer.visible = false
	_set_ghost_alpha(0.55)
	if tool == Tool.PLACE:
		_outline.visible = false
	if _picker_had_capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _mode_manager:
		_mode_manager.set_frozen(false)

func _set_rot(r: int) -> void:
	cursor_rot = clampi(r, 0, Orientations.COUNT - 1)
	_update_picker_labels()

func _update_picker_labels() -> void:
	if not _up_label:
		return
	_up_label.text = "%s  ·  %s" % [
		Orientations.UP_NAMES[Orientations.up_index(cursor_rot)],
		SPIN_NAMES[Orientations.spin(cursor_rot)],
	]
	for r in _picker_buttons.size():
		_picker_buttons[r].set_pressed_no_signal(r == cursor_rot)

func _build_picker_ui() -> void:
	_picker_layer = CanvasLayer.new()
	_picker_layer.visible = false
	add_child(_picker_layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -190.0
	panel.offset_right = 190.0
	panel.offset_top = -150.0
	panel.offset_bottom = 150.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.13, 0.9)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", style)
	_picker_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "ORIENTATION"
	title.add_theme_font_size_override("font_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_up_label = Label.new()
	_up_label.add_theme_font_size_override("font_size", 15)
	_up_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_up_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_up_label)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	# header row: corner blank + spin columns
	grid.add_child(Control.new())
	for s in 4:
		var head := Label.new()
		head.text = SPIN_NAMES[s]
		head.add_theme_font_size_override("font_size", 11)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.custom_minimum_size.x = 58.0
		grid.add_child(head)

	_picker_buttons.resize(Orientations.COUNT)
	for u in Orientations.UPS.size():
		var row_head := Label.new()
		row_head.text = Orientations.UP_NAMES[u]
		row_head.add_theme_font_size_override("font_size", 11)
		grid.add_child(row_head)
		for s in 4:
			var rot := Orientations.make(u, s)
			var btn := Button.new()
			btn.toggle_mode = true
			btn.focus_mode = Control.FOCUS_NONE
			btn.custom_minimum_size = Vector2(58.0, 26.0)
			btn.text = "·"
			# hovering previews the orientation live on the ghost
			btn.mouse_entered.connect(func(): _set_rot(rot))
			btn.pressed.connect(func():
				_set_rot(rot)
				_close_picker()
				_rotate_held = false)
			grid.add_child(btn)
			_picker_buttons[rot] = btn

	var hint := Label.new()
	hint.text = "hover to preview — click or release R to confirm\narrows also work — RMB cancels"
	hint.add_theme_font_size_override("font_size", 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
	vbox.add_child(hint)
