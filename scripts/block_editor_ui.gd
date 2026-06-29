extends CanvasLayer

@export var editor_path: NodePath

var _panel: PanelContainer
var _block_label: Label
var _mode_label: Label
var _editor: Node

func _ready() -> void:
	_editor = get_node(editor_path)
	_editor.editor_toggled.connect(_on_editor_toggled)
	_editor.block_selected.connect(_on_block_selected)
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
	_mode_label.text = "BLOCK EDITOR  [E]"
	_mode_label.add_theme_font_size_override("font_size", 15)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_mode_label)

	_block_label = Label.new()
	_block_label.add_theme_font_size_override("font_size", 13)
	_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_block_label)

	var help := Label.new()
	help.text = "Q/R: cycle  LMB: place  RMB: remove"
	help.add_theme_font_size_override("font_size", 11)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(help)

	add_child(_panel)

func _on_editor_toggled(is_active: bool) -> void:
	_panel.visible = is_active
	if is_active:
		_update_block_label()

func _on_block_selected(_id: int, _name: String) -> void:
	_update_block_label()

func _update_block_label() -> void:
	_block_label.text = _editor.get_selected_block_name().replace("_", " ").capitalize()
