class_name TerrainBrushTool
extends GodTool
## Raise or lower terrain in a circular brush around the clicked point.
## LMB applies; toggle Lower to dig instead of build.

var _radius := 3
var _lower := false

func get_display_name() -> String:
	return "Terrain Brush"

func get_help() -> String:
	return "LMB: raise terrain (or lower if toggled). Right-drag to fly."

func build_options(container: VBoxContainer) -> void:
	var rlabel := Label.new()
	rlabel.text = "Radius: %d" % _radius
	container.add_child(rlabel)
	var slider := HSlider.new()
	slider.min_value = 1
	slider.max_value = 10
	slider.step = 1
	slider.value = _radius
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v):
		_radius = int(v)
		rlabel.text = "Radius: %d" % _radius)
	container.add_child(slider)

	var lower := CheckButton.new()
	lower.text = "Lower (dig)"
	lower.button_pressed = _lower
	lower.focus_mode = Control.FOCUS_NONE
	lower.toggled.connect(func(v): _lower = v)
	container.add_child(lower)

func on_primary(hit: Dictionary) -> void:
	if hit.is_empty():
		return
	var c: Vector3 = hit["position"] - hit["normal"] * 0.5
	var cx := floori(c.x)
	var cz := floori(c.z)
	var grass := BlockRegistry.get_id("grass.cube")
	var dirt := BlockRegistry.get_id("dirt.cube")
	for off: Vector2i in _disk(_radius):
		var x := cx + off.x
		var z := cz + off.y
		var top := world.surface_y(x, z)
		if top == world.NO_SURFACE:
			continue
		if _lower:
			_put(x, top, z, BlockRegistry.AIR)
		else:
			_put(x, top, z, dirt)      # old surface becomes subsoil
			_put(x, top + 1, z, grass) # new grassy top
	_flush()
