class_name WallTool
extends GodTool
## Two-click wall builder. First LMB sets the start, second builds a wall of
## the chosen block along the line between the points, `height` blocks tall,
## resting on the surface. Click again to start a new wall.

var _height := 3
var _block_id := 8
var _placeable: Array[int] = []
var _start := Vector2i.ZERO
var _has_start := false
var _status: Label

func get_display_name() -> String:
	return "Wall"

func get_help() -> String:
	return "LMB: set start, then LMB again to build. Right-drag to fly."

func build_options(container: VBoxContainer) -> void:
	_placeable = BlockRegistry.get_placeable_ids()
	if _placeable.size() > 0 and _block_id not in _placeable:
		_block_id = _placeable[0]

	var picker := OptionButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	for i in _placeable.size():
		var nm := BlockRegistry.get_name_from_id(_placeable[i])
		picker.add_item(nm.replace(".", "  ").replace("_", " "), _placeable[i])
		if _placeable[i] == _block_id:
			picker.select(i)
	picker.item_selected.connect(func(idx): _block_id = _placeable[idx])
	container.add_child(picker)

	var hlabel := Label.new()
	hlabel.text = "Height: %d" % _height
	container.add_child(hlabel)
	var slider := HSlider.new()
	slider.min_value = 1
	slider.max_value = 12
	slider.step = 1
	slider.value = _height
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v):
		_height = int(v)
		hlabel.text = "Height: %d" % _height)
	container.add_child(slider)

	_status = Label.new()
	_status.text = "Click a start point."
	_status.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	container.add_child(_status)

func on_deactivate() -> void:
	super.on_deactivate()
	_has_start = false
	if _status:
		_status.text = "Click a start point."

func on_primary(hit: Dictionary) -> void:
	if hit.is_empty():
		return
	var c: Vector3 = hit["position"] - hit["normal"] * 0.5
	var p := Vector2i(floori(c.x), floori(c.z))
	if not _has_start:
		_start = p
		_has_start = true
		if _status:
			_status.text = "Start (%d, %d). Click end." % [p.x, p.y]
		return
	_build_wall(_start, p)
	_has_start = false
	if _status:
		_status.text = "Wall built. Click a start point."

func _build_wall(a: Vector2i, b: Vector2i) -> void:
	for cell: Vector2i in _line(a, b):
		var base := world.surface_y(cell.x, cell.y)
		var y0 := 0 if base == world.NO_SURFACE else base + 1
		for h in _height:
			_put(cell.x, y0 + h, cell.y, _block_id)
	_flush()

## Integer grid line between two points (Bresenham on X/Z).
func _line(a: Vector2i, b: Vector2i) -> Array:
	var cells := []
	var dx := absi(b.x - a.x)
	var dz := absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sz := 1 if a.y < b.y else -1
	var err := dx - dz
	var x := a.x
	var z := a.y
	while true:
		cells.append(Vector2i(x, z))
		if x == b.x and z == b.y:
			break
		var e2 := 2 * err
		if e2 > -dz:
			err -= dz
			x += sx
		if e2 < dx:
			err += dx
			z += sz
	return cells
