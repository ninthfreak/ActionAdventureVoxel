class_name ScatterTool
extends GodTool
## Placeholder for a future scatter/foliage brush (trees, rocks, props with
## density and jitter). Registered now so the tool framework and panel are
## exercised end to end; the brush logic lands in a later pass.

func get_display_name() -> String:
	return "Scatter (WIP)"

func get_help() -> String:
	return "Coming soon: scatter trees and props with adjustable density."

func build_options(container: VBoxContainer) -> void:
	var note := Label.new()
	note.text = "Not implemented yet.\nFramework placeholder."
	note.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	container.add_child(note)

func on_primary(_hit: Dictionary) -> void:
	pass
