extends CanvasLayer
## In-game slider panel for tuning camera and sun parameters in real time.
## Press Tab to show/hide.

@export var camera_rig_path: NodePath
@export var sun_path: NodePath

var _panel: PanelContainer
var _pitch_slider: HSlider
var _rotate_slider: HSlider
var _size_slider: HSlider
var _dist_slider: HSlider
var _sun_slider: HSlider
var _pitch_label: Label
var _rotate_label: Label
var _size_label: Label
var _dist_label: Label
var _sun_label: Label

func _ready() -> void:
	_build_ui()
	_sync_from_rig()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tuner"):
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.offset_left = 12.0
	_panel.offset_top = 12.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.78)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Camera Tuner  [Tab]"
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)

	_pitch_label = Label.new()
	_pitch_slider = _add_slider(vbox, _pitch_label, 0.0, 90.0, 0.5)
	_pitch_slider.value_changed.connect(_on_pitch_changed)

	_rotate_label = Label.new()
	_rotate_slider = _add_slider(vbox, _rotate_label, -180.0, 180.0, 0.25)
	_rotate_slider.value_changed.connect(_on_rotate_changed)

	_size_label = Label.new()
	_size_slider = _add_slider(vbox, _size_label, 2.0, 30.0, 0.5)
	_size_slider.value_changed.connect(_on_size_changed)

	_dist_label = Label.new()
	_dist_slider = _add_slider(vbox, _dist_label, 2.0, 40.0, 0.5)
	_dist_slider.value_changed.connect(_on_dist_changed)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	_sun_label = Label.new()
	_sun_slider = _add_slider(vbox, _sun_label, 10.0, 170.0, 1.0)
	_sun_slider.value_changed.connect(_on_sun_changed)

	add_child(_panel)

func _add_slider(parent: VBoxContainer, label: Label, min_val: float, max_val: float, step: float) -> HSlider:
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.custom_minimum_size.x = 240.0
	slider.focus_mode = Control.FOCUS_NONE
	parent.add_child(slider)
	return slider

func _sync_from_rig() -> void:
	var rig := _get_rig()
	if rig:
		_pitch_slider.set_value_no_signal(rig.camera_pitch_degrees)
		_rotate_slider.set_value_no_signal(rig.camera_rotate_degrees)
		_size_slider.set_value_no_signal(rig.camera_view_size)
		_dist_slider.set_value_no_signal(rig.camera_distance)
	var sun := _get_sun()
	if sun:
		_sun_slider.set_value_no_signal(-sun.rotation_degrees.x)
	else:
		_sun_slider.set_value_no_signal(60.0)
	_update_labels()

func _get_rig() -> Node:
	if camera_rig_path.is_empty():
		return null
	return get_node_or_null(camera_rig_path)

func _get_sun() -> DirectionalLight3D:
	if sun_path.is_empty():
		return null
	return get_node_or_null(sun_path) as DirectionalLight3D

func _update_labels() -> void:
	_pitch_label.text = "Pitch: %.1f°" % _pitch_slider.value
	_rotate_label.text = "Rotate: %.1f°" % _rotate_slider.value
	_size_label.text = "Zoom: %.1f" % _size_slider.value
	_dist_label.text = "Distance: %.1f" % _dist_slider.value
	var angle := _sun_slider.value
	var tod := ""
	if angle < 30.0:
		tod = "Dawn"
	elif angle < 60.0:
		tod = "Morning"
	elif angle < 120.0:
		tod = "Midday"
	elif angle < 150.0:
		tod = "Afternoon"
	else:
		tod = "Dusk"
	_sun_label.text = "Sun: %.0f° (%s)" % [angle, tod]

func _on_pitch_changed(value: float) -> void:
	var rig := _get_rig()
	if rig:
		rig.camera_pitch_degrees = value
	_update_labels()

func _on_rotate_changed(value: float) -> void:
	var rig := _get_rig()
	if rig:
		rig.camera_rotate_degrees = value
	_update_labels()

func _on_size_changed(value: float) -> void:
	var rig := _get_rig()
	if rig:
		rig.camera_view_size = value
	_update_labels()

func _on_dist_changed(value: float) -> void:
	var rig := _get_rig()
	if rig:
		rig.camera_distance = value
	_update_labels()

func _on_sun_changed(value: float) -> void:
	var sun := _get_sun()
	if sun:
		sun.rotation_degrees.x = -value
	_update_labels()
