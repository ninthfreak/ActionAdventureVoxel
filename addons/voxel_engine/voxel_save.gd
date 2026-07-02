class_name VoxelSave

## Metadata (e.g. gen_version) from the most recent successful load_world call.
static var last_meta: Dictionary = {}

static func save_world(world: Node, path: String, meta: Dictionary = {}) -> Error:
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var palette: Array[String] = []
	for i in BlockRegistry.block_count():
		palette.append(BlockRegistry.get_name_from_id(i))

	var chunks_dict := {}
	for ck in world.get_chunk_keys():
		var data: ChunkData = world.get_chunk_data(ck)
		if not data or data.is_empty():
			continue
		var key_str := "%d,%d,%d" % [ck.x, ck.y, ck.z]
		chunks_dict[key_str] = Marshalls.raw_to_base64(data.blocks)

	var save_data := {
		"version": 1,
		"palette": palette,
		"chunks": chunks_dict,
	}
	save_data.merge(meta)

	var json_str := JSON.stringify(save_data, "  ")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		return FileAccess.get_open_error()
	f.store_string(json_str)
	f.close()
	return OK

static func load_world(world: Node, path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND

	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return FileAccess.get_open_error()
	var json_str := f.get_as_text()
	f.close()

	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK:
		return err

	var save_data: Dictionary = json.data
	var palette: Array = save_data.get("palette", [])
	var chunks_dict: Dictionary = save_data.get("chunks", {})
	last_meta = {
		"gen_version": int(save_data.get("gen_version", 0)),
		"params_hash": int(save_data.get("params_hash", 0)),
	}

	var id_remap: Array[int] = []
	for i in palette.size():
		id_remap.append(BlockRegistry.get_id(palette[i]))

	for key_str in chunks_dict:
		var parts := (key_str as String).split(",")
		if parts.size() != 3:
			continue
		var ck := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		var raw := Marshalls.base64_to_raw(chunks_dict[key_str])
		var data := ChunkData.new()
		for i in raw.size():
			var file_id := raw[i]
			if file_id < id_remap.size():
				data.blocks[i] = id_remap[file_id]
			else:
				data.blocks[i] = 0
		world.set_chunk_data(ck, data)

	world.rebuild_all()
	return OK
