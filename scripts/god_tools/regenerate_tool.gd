class_name RegenerateTool
extends GodTool
## Regenerate the whole world from the map generator. Pick a seed (or randomize)
## and press Generate. Uses the VoxelWorld's configured MapGenParams.

var _seed := 1337
var _seed_spin: SpinBox

func get_display_name() -> String:
	return "Regenerate World"

func get_help() -> String:
	return "Set a seed and press Generate to rebuild the world."

func build_options(container: VBoxContainer) -> void:
	var params := world._get_params()
	_seed = params.world_seed

	var slabel := Label.new()
	slabel.text = "Seed"
	container.add_child(slabel)
	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 0
	_seed_spin.max_value = 1000000
	_seed_spin.step = 1
	_seed_spin.value = _seed
	_seed_spin.focus_mode = Control.FOCUS_NONE
	_seed_spin.value_changed.connect(func(v): _seed = int(v))
	container.add_child(_seed_spin)

	var randomize_btn := Button.new()
	randomize_btn.text = "Randomize Seed"
	randomize_btn.focus_mode = Control.FOCUS_NONE
	randomize_btn.pressed.connect(func():
		_seed = randi() % 1000000
		if _seed_spin:
			_seed_spin.value = _seed)
	container.add_child(randomize_btn)

	var gen := Button.new()
	gen.text = "Generate"
	gen.focus_mode = Control.FOCUS_NONE
	gen.pressed.connect(_generate)
	container.add_child(gen)

	var note := Label.new()
	note.text = "Replaces the current world."
	note.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
	container.add_child(note)

func _generate() -> void:
	var params := world._get_params()
	params.world_seed = _seed
	world.clear_world()
	MapGenerator.generate(world, params)
