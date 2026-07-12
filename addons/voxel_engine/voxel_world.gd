extends Node3D

const SAVE_PATH := "user://maps/world.vxel"
const MAPS_DIR := "user://maps"

@export var gen_params: MapGenParams

## Absolute path of the map currently open, or "" for a never-saved new map.
var current_path: String = ""

## Fired whenever the open map changes (load / new / save-as) so the menu bar
## can update its title. Argument is a human-readable name.
signal map_changed(display_name: String)

## Fired when a save was requested but there is no path yet (untitled map) —
## the menu bar responds by opening its Save As dialog.
signal save_as_requested

var _chunks: Dictionary = {}
var _chunk_nodes: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var params := _get_params()
	var err := VoxelSave.load_world(self, SAVE_PATH)
	var up_to_date := err == OK \
		and int(VoxelSave.last_meta.get("gen_version", 0)) == MapGenerator.GEN_VERSION \
		and int(VoxelSave.last_meta.get("params_hash", 0)) == params.hash_value()
	if not up_to_date:
		clear_world()
		MapGenerator.generate(self, params)
		_save_to(SAVE_PATH)
	current_path = SAVE_PATH
	map_changed.emit(display_name())

func _get_params() -> MapGenParams:
	if gen_params:
		return gen_params
	return MapGenParams.new()

func clear_world() -> void:
	for ck in _chunk_nodes:
		_chunk_nodes[ck].queue_free()
	_chunk_nodes.clear()
	_chunks.clear()

func display_name() -> String:
	if current_path.is_empty():
		return "Untitled"
	return current_path.get_file().get_basename()

# --- File operations (driven by the menu bar) ---------------------------------

## Blank buildable canvas: a flat grass platform centered on the origin.
func new_map(half_extent: int = 24) -> void:
	clear_world()
	var grass := BlockRegistry.get_id("grass.cube")
	var dirt := BlockRegistry.get_id("dirt.cube")
	for z in range(-half_extent, half_extent):
		for x in range(-half_extent, half_extent):
			set_block_no_rebuild(x, -2, z, dirt)
			set_block_no_rebuild(x, -1, z, grass)
	rebuild_all()
	current_path = ""
	map_changed.emit(display_name())

func load_map(path: String) -> Error:
	# validate the file BEFORE destroying the current world, so a corrupt or
	# missing map leaves the open one untouched
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return FileAccess.get_open_error()
	var json := JSON.new()
	var parse_err := json.parse(f.get_as_text())
	f.close()
	if parse_err != OK or not (json.data is Dictionary) or not (json.data as Dictionary).has("chunks"):
		return ERR_PARSE_ERROR
	clear_world()
	var err := VoxelSave.load_world(self, path)
	if err == OK:
		current_path = path
		map_changed.emit(display_name())
	return err

## Save to the current path; returns false if there is no path yet (Save As).
func save_current() -> bool:
	if current_path.is_empty():
		return false
	_save_to(current_path)
	return true

func save_map(path: String) -> void:
	_save_to(path)
	current_path = path
	map_changed.emit(display_name())

func _save_to(path: String) -> void:
	VoxelSave.save_world(self, path, {
		"gen_version": MapGenerator.GEN_VERSION,
		"params_hash": _get_params().hash_value(),
	})

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("editor_save"):
		if not save_current():
			save_as_requested.emit()  # untitled — menu bar opens Save As
		get_viewport().set_input_as_handled()

# --- Tool helpers (God mode) --------------------------------------------------

func chunk_key_of(wx: int, wy: int, wz: int) -> Vector3i:
	return _world_to_chunk_key(wx, wy, wz)

func rebuild_keys(keys: Array) -> void:
	for ck in keys:
		_rebuild_chunk(ck)

## Highest y at (x,z) holding a collidable block, or NO_SURFACE if the column
## is empty within the scanned range.
const NO_SURFACE := -2147483648
func surface_y(wx: int, wz: int, y_top: int = 40, y_bottom: int = -20) -> int:
	for y in range(y_top, y_bottom - 1, -1):
		var id := get_block(wx, y, wz)
		if id != BlockRegistry.AIR and BlockRegistry.has_collision(id):
			return y
	return NO_SURFACE

func get_block(wx: int, wy: int, wz: int) -> int:
	var ck := _world_to_chunk_key(wx, wy, wz)
	var chunk := _chunks.get(ck) as ChunkData
	if not chunk:
		return BlockRegistry.AIR
	var local := _world_to_local(wx, wy, wz)
	return chunk.get_block(local.x, local.y, local.z)

func set_block(wx: int, wy: int, wz: int, id: int, rot: int = 0) -> void:
	var ck := _world_to_chunk_key(wx, wy, wz)
	var chunk := _chunks.get(ck) as ChunkData
	if not chunk:
		if id == BlockRegistry.AIR:
			return
		chunk = ChunkData.new()
		_chunks[ck] = chunk
	var local := _world_to_local(wx, wy, wz)
	chunk.set_block(local.x, local.y, local.z, id, rot)
	_rebuild_chunk(ck)

func set_block_no_rebuild(wx: int, wy: int, wz: int, id: int, rot: int = 0) -> void:
	var ck := _world_to_chunk_key(wx, wy, wz)
	var chunk := _chunks.get(ck) as ChunkData
	if not chunk:
		if id == BlockRegistry.AIR:
			return
		chunk = ChunkData.new()
		_chunks[ck] = chunk
	var local := _world_to_local(wx, wy, wz)
	chunk.set_block(local.x, local.y, local.z, id, rot)

func rebuild_all() -> void:
	# snapshot: _rebuild_chunk erases empty chunks from _chunks as it goes
	for ck in _chunks.keys():
		_rebuild_chunk(ck)

func get_chunk_keys() -> Array:
	return _chunks.keys()

func get_chunk_data(ck: Vector3i) -> ChunkData:
	return _chunks.get(ck)

func set_chunk_data(ck: Vector3i, data: ChunkData) -> void:
	_chunks[ck] = data

func _rebuild_chunk(ck: Vector3i) -> void:
	var chunk := _chunks.get(ck) as ChunkData

	if _chunk_nodes.has(ck):
		var old_node: Node3D = _chunk_nodes[ck]
		old_node.queue_free()
		_chunk_nodes.erase(ck)

	if not chunk or chunk.is_empty():
		_chunks.erase(ck)
		return

	var node := preload("res://addons/voxel_engine/chunk_node.gd").new()
	node.chunk_key = ck
	node.data = chunk
	node.position = Vector3(ck.x * ChunkData.SIZE, ck.y * ChunkData.SIZE, ck.z * ChunkData.SIZE)
	node.build()
	add_child(node)
	_chunk_nodes[ck] = node

func _world_to_chunk_key(wx: int, wy: int, wz: int) -> Vector3i:
	return Vector3i(
		floori(float(wx) / ChunkData.SIZE),
		floori(float(wy) / ChunkData.SIZE),
		floori(float(wz) / ChunkData.SIZE)
	)

func _world_to_local(wx: int, wy: int, wz: int) -> Vector3i:
	return Vector3i(
		posmod(wx, ChunkData.SIZE),
		posmod(wy, ChunkData.SIZE),
		posmod(wz, ChunkData.SIZE)
	)
