class_name PaintTool
extends GodTool
## Repaint the surface blocks in a circular brush with a chosen block type.
## Good for laying grass, sand, asphalt patches, plazas, etc.

var _radius := 2
var _block_id := 1
var _placeable: Array[int] = []

func get_display_name() -> String:
	return "Surface Paint"

func get_help() -> String:
	return "LMB: paint the surface with the chosen block. Right-drag to fly."

func build_options(container: VBoxContainer) -> void:
	_placeable = BlockRegistry.get_placeable_ids()
	if _block_id == 1 and _placeable.size() > 0:
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

	var rlabel := Label.new()
	rlabel.text = "Radius: %d" % _radius
	container.add_child(rlabel)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 8
	slider.step = 1
	slider.value = _radius
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v):
		_radius = int(v)
		rlabel.text = "Radius: %d" % _radius)
	container.add_child(slider)

func on_primary(hit: Dictionary) -> void:
	if hit.is_empty():
		return
	var c: Vector3 = hit["position"] - hit["normal"] * 0.5
	var cx := floori(c.x)
	var cz := floori(c.z)
	for off: Vector2i in _disk(_radius):
		var x := cx + off.x
		var z := cz + off.y
		var top := world.surface_y(x, z)
		if top == world.NO_SURFACE:
			continue
		_put(x, top, z, _block_id)
	_flush()
