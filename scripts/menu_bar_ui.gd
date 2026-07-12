extends CanvasLayer
## Top menu bar for the map editor: File (New/Open/Save/Save As/Quit) and Mode
## (Explore/Build/God). Drives the VoxelWorld's file operations and the
## ModeManager. Shows the current map name on the right.

@export var voxel_world_path: NodePath
@export var mode_manager_path: NodePath

enum FileItem { NEW, OPEN, SAVE, SAVE_AS, QUIT }

var _world: Node
var _modes: Node
var _title: Label
var _open_dialog: FileDialog
var _save_dialog: FileDialog
## When true the current Save-As is fulfilling a plain Save with no path yet.
var _save_then := false

func _ready() -> void:
	_world = get_node_or_null(voxel_world_path)
	_modes = get_node_or_null(mode_manager_path)
	_build_bar()
	_build_dialogs()
	if _world:
		_world.connect("map_changed", _on_map_changed)
		_on_map_changed(_world.display_name())

func _build_bar() -> void:
	var bar := PanelContainer.new()
	bar.anchor_right = 1.0
	bar.offset_bottom = 36.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.12, 0.96)
	style.set_content_margin_all(4.0)
	bar.add_theme_stylebox_override("panel", style)
	add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	bar.add_child(hbox)

	var file_btn := MenuButton.new()
	file_btn.text = "File"
	file_btn.focus_mode = Control.FOCUS_NONE
	var fp := file_btn.get_popup()
	fp.add_item("New", FileItem.NEW)
	fp.add_item("Open…", FileItem.OPEN)
	fp.add_separator()
	fp.add_item("Save", FileItem.SAVE)
	fp.add_item("Save As…", FileItem.SAVE_AS)
	fp.add_separator()
	fp.add_item("Quit", FileItem.QUIT)
	fp.id_pressed.connect(_on_file_item)
	hbox.add_child(file_btn)

	var mode_btn := MenuButton.new()
	mode_btn.text = "Mode"
	mode_btn.focus_mode = Control.FOCUS_NONE
	var mp := mode_btn.get_popup()
	mp.add_item("Explore  (F1)", 0)
	mp.add_item("Build  (F2)", 1)
	mp.add_item("God  (F3)", 2)
	mp.id_pressed.connect(_on_mode_item)
	hbox.add_child(mode_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_title = Label.new()
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	hbox.add_child(_title)

func _build_dialogs() -> void:
	_open_dialog = FileDialog.new()
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = FileDialog.ACCESS_USERDATA
	_open_dialog.current_dir = "user://maps"
	_open_dialog.filters = PackedStringArray(["*.vxel ; Voxel Maps"])
	_open_dialog.title = "Open Map"
	_open_dialog.size = Vector2i(680, 460)
	_open_dialog.file_selected.connect(_on_open_selected)
	_open_dialog.visibility_changed.connect(func(): _freeze(_open_dialog.visible))
	add_child(_open_dialog)

	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_USERDATA
	_save_dialog.current_dir = "user://maps"
	_save_dialog.filters = PackedStringArray(["*.vxel ; Voxel Maps"])
	_save_dialog.title = "Save Map As"
	_save_dialog.size = Vector2i(680, 460)
	_save_dialog.file_selected.connect(_on_save_selected)
	_save_dialog.visibility_changed.connect(func(): _freeze(_save_dialog.visible))
	add_child(_save_dialog)

func _on_file_item(id: int) -> void:
	match id:
		FileItem.NEW:
			if _world:
				_world.new_map()
		FileItem.OPEN:
			_release_mouse()
			_open_dialog.popup_centered()
		FileItem.SAVE:
			if _world and not _world.save_current():
				_save_then = true
				_release_mouse()
				_save_dialog.popup_centered()
		FileItem.SAVE_AS:
			_save_then = false
			_release_mouse()
			_save_dialog.popup_centered()
		FileItem.QUIT:
			get_tree().quit()

func _on_mode_item(id: int) -> void:
	if _modes:
		_modes.set_mode(id)

func _on_open_selected(path: String) -> void:
	if _world:
		_world.load_map(path)

func _on_save_selected(path: String) -> void:
	if path.get_extension().to_lower() != "vxel":
		path += ".vxel"
	if _world:
		_world.save_map(path)
	_save_then = false

func _on_map_changed(display_name: String) -> void:
	if _title:
		_title.text = display_name + "   "

## A file dialog needs the cursor; free it if Build mode had it captured.
func _release_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Freeze/unfreeze player control while a modal dialog is up.
func _freeze(is_frozen: bool) -> void:
	if _modes:
		_modes.set_frozen(is_frozen)
