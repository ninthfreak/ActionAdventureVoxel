class_name BlockRegistry

const CHUNK_SIZE := 16

const AIR := 0

static var _defs: Array[Dictionary] = []
static var _name_to_id: Dictionary = {}
static var _mesh_cache: Dictionary = {}

static func _ensure_init() -> void:
	if not _defs.is_empty():
		return
	_register(AIR, "air", false)
	_register(1, "grass", true)
	_register(2, "dirt", true)
	_register(3, "sand", true)
	_register(4, "water", false)
	_register(5, "asphalt", true)
	_register(6, "gravel", true)
	_register(7, "concrete_walkway", true)
	_register(8, "bricks", true)
	_register(9, "cement_blocks", true)
	_register(10, "leaves", true)
	_register(11, "shingles_slate", true)
	_register(12, "tree_generic_large", true)
	_register(13, "tree_birch_small", true)
	_register(14, "metal_pole_large", true)
	_register(15, "metal_pole_small", true)

static func _register(id: int, block_name: String, has_collision: bool) -> void:
	while _defs.size() <= id:
		_defs.append({})
	_defs[id] = {"id": id, "name": block_name, "has_collision": has_collision}
	_name_to_id[block_name] = id

static func get_id(block_name: String) -> int:
	_ensure_init()
	return _name_to_id.get(block_name, AIR)

static func get_name_from_id(id: int) -> String:
	_ensure_init()
	if id < 0 or id >= _defs.size():
		return "air"
	return _defs[id].get("name", "air")

static func has_collision(id: int) -> bool:
	_ensure_init()
	if id < 0 or id >= _defs.size():
		return false
	return _defs[id].get("has_collision", false)

static func get_mesh(id: int) -> ArrayMesh:
	if id == AIR:
		return null
	if _mesh_cache.has(id):
		return _mesh_cache[id]
	var block_name := get_name_from_id(id)
	if block_name == "air":
		return null
	var mesh := ObjLoader.load_block(block_name)
	_mesh_cache[id] = mesh
	return mesh

static func get_placeable_ids() -> Array[int]:
	_ensure_init()
	var ids: Array[int] = []
	for def in _defs:
		if def.is_empty():
			continue
		if def["id"] != AIR:
			ids.append(def["id"])
	return ids

static func block_count() -> int:
	_ensure_init()
	return _defs.size()
