extends CanvasLayer

@export var editor_path: NodePath

var _panel: PanelContainer
var _block_label: Label
var _mode_label: Label
var _editor: Node
var _crosshair: Control

## Simple + reticle with a dark backing line so it reads on any surface.
class Crosshair:
	extends Control

	func _draw() -> void:
		var c := size * 0.5
		var arms := [
			[Vector2(-13, 0), Vector2(-4, 0)], [Vector2(4, 0), Vector2(13, 0)],
			[Vector2(0, -13), Vector2(0, -4)], [Vector2(0, 4), Vector2(0, 13)],
		]
		for a: Array in arms:
			draw_line(c + a[0], c + a[1], Color(0, 0, 0, 0.8), 4.0)
		for a: Array in arms:
			draw_line(c + a[0], c + a[1], Color(1, 1, 1, 0.95), 2.0)

func _ready() -> void:
	_editor = get_node(editor_path)
	_editor.editor_toggled.connect(_on_editor_toggled)
	_editor.block_selected.connect(_on_block_selected)
	_editor.tool_changed.connect(_on_tool_changed)
	_build_ui()
	_panel.visible = false

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.0
	_panel.offset_left = -120.0
	_panel.offset_right = 120.0
	_panel.offset_top = 12.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	_mode_label = Label.new()
	_mode_label.text = "BLOCK EDITOR"
	_mode_label.add_theme_font_size_override("font_size", 15)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_mode_label)

	_block_label = Label.new()
	_block_label.add_theme_font_size_override("font_size", 13)
	_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_block_label)

	var help := Label.new()
	help.text = "Tab: blocks (hold: copy)  R: rotate (hold: orient)  LMB: apply  L: camera"
	help.add_theme_font_size_override("font_size", 11)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(help)

	add_child(_panel)

	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.visible = false
	add_child(_crosshair)

func _update_crosshair() -> void:
	# reticle for the delete tool in first-person aim, where there's no
	# ghost block to show what's targeted
	_crosshair.visible = _editor.active and _editor.tool == 1 and _editor.aim_from_center

func _on_editor_toggled(is_active: bool) -> void:
	_panel.visible = is_active
	if is_active:
		_update_block_label()
	_update_crosshair()

func _on_block_selected(_id: int, _name: String) -> void:
	_update_block_label()
	_update_crosshair()

func _on_tool_changed(_tool: int) -> void:
	_update_block_label()
	_update_crosshair()

func _update_block_label() -> void:
	if _editor.tool == 1:  # Tool.DELETE
		_block_label.text = "DELETE MODE"
		_block_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	else:
		_block_label.text = "Place: " + _editor.get_selected_block_name().replace(".", "  ").capitalize()
		_block_label.add_theme_color_override("font_color", Color(1, 1, 1))
