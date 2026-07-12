class_name GodTool
extends RefCounted
## Base class for God-mode tools. A tool receives the VoxelWorld on creation,
## may build an options panel, and reacts to primary (LMB) clicks in the world.
## Right mouse is reserved for the free-fly camera, so multi-step tools (e.g.
## the wall tool) chain successive primary clicks instead.

var world: Node
var _dirty: Dictionary = {}

func _init(voxel_world: Node) -> void:
	world = voxel_world

func get_display_name() -> String:
	return "Tool"

func get_help() -> String:
	return ""

## Populate the per-tool options area. Default: nothing.
func build_options(_container: VBoxContainer) -> void:
	pass

## Called on a left click that hit the world. `hit` has "position"/"normal",
## or is empty when the ray missed (some tools still act, e.g. Regenerate).
func on_primary(_hit: Dictionary) -> void:
	pass

## Reset any in-progress state (e.g. a pending wall start point).
func on_deactivate() -> void:
	_dirty.clear()

# --- batched editing helpers --------------------------------------------------

func _set(wx: int, wy: int, wz: int, id: int, rot: int = 0) -> void:
	world.set_block_no_rebuild(wx, wy, wz, id, rot)
	_dirty[world.chunk_key_of(wx, wy, wz)] = true

func _flush() -> void:
	world.rebuild_keys(_dirty.keys())
	_dirty.clear()

## Integer disk of (x,z) offsets within `radius`, for brush-style tools.
func _disk(radius: int) -> Array:
	var out := []
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dz * dz <= radius * radius:
				out.append(Vector2i(dx, dz))
	return out
