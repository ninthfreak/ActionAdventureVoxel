extends Node3D

const SAVE_PATH := "user://maps/world.vxel"

@export var gen_params: MapGenParams

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
		save()
	_check_bad_obj_files.call_deferred()

func _get_params() -> MapGenParams:
	if gen_params:
		return gen_params
	return MapGenParams.new()

func clear_world() -> void:
	for ck in _chunk_nodes:
		_chunk_nodes[ck].queue_free()
	_chunk_nodes.clear()
	_chunks.clear()

func _check_bad_obj_files() -> void:
	var bad := ObjLoader.get_bad_winding_blocks()
	if bad.is_empty():
		return
	var msg := "Bad face winding detected in OBJ files:\n"
	for b in bad:
		msg += "  - %s.obj\n" % b
	msg += "\nThese blocks will render incorrectly with back-face culling.\nRe-export them from PrismCraft to fix."
	var dialog := AcceptDialog.new()
	dialog.title = "OBJ Winding Warning"
	dialog.dialog_text = msg
	dialog.min_size = Vector2i(420, 200)
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("editor_save"):
		save()
		get_viewport().set_input_as_handled()

func save() -> void:
	VoxelSave.save_world(self, SAVE_PATH, {
		"gen_version": MapGenerator.GEN_VERSION,
		"params_hash": _get_params().hash_value(),
	})

func get_block(wx: int, wy: int, wz: int) -> int:
	var ck := _world_to_chunk_key(wx, wy, wz)
	var chunk := _chunks.get(ck) as ChunkData
	if not chunk:
		return BlockRegistry.AIR
	var local := _world_to_local(wx, wy, wz)
	return chunk.get_block(local.x, local.y, local.z)

func set_block(wx: int, wy: int, wz: int, id: int) -> void:
	var ck := _world_to_chunk_key(wx, wy, wz)
	var chunk := _chunks.get(ck) as ChunkData
	if not chunk:
		if id == BlockRegistry.AIR:
			return
		chunk = ChunkData.new()
		_chunks[ck] = chunk
	var local := _world_to_local(wx, wy, wz)
	chunk.set_block(local.x, local.y, local.z, id)
	_rebuild_chunk(ck)

func set_block_no_rebuild(wx: int, wy: int, wz: int, id: int) -> void:
	var ck := _world_to_chunk_key(wx, wy, wz)
	var chunk := _chunks.get(ck) as ChunkData
	if not chunk:
		if id == BlockRegistry.AIR:
			return
		chunk = ChunkData.new()
		_chunks[ck] = chunk
	var local := _world_to_local(wx, wy, wz)
	chunk.set_block(local.x, local.y, local.z, id)

func rebuild_all() -> void:
	for ck in _chunks:
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
