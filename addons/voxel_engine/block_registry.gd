class_name BlockRegistry
## Runtime registry of every block in res://blocks. Blocks are GLB meshes
## named "<material-variant>.<shape>" (PrismCraft convention). IDs are
## assigned alphabetically at startup; save files remap through the palette,
## so IDs staying stable across library changes is not required.

const CHUNK_SIZE := 16
const AIR := 0
const BLOCKS_DIR := "res://blocks"

static var _defs: Array[Dictionary] = []
static var _name_to_id: Dictionary = {}
static var _mesh_cache: Dictionary = {}
static var _shape_cache: Dictionary = {}
static var _cel_mat: ShaderMaterial
static var _water_mat: ShaderMaterial
static var _box_shape: BoxShape3D

static func _ensure_init() -> void:
	if not _defs.is_empty():
		return
	_register(AIR, "air", false)
	var found := {}
	var dir := DirAccess.open(BLOCKS_DIR)
	if dir:
		for f in dir.get_files():
			if f.ends_with(".glb"):
				found[f.trim_suffix(".glb")] = true
			elif f.ends_with(".glb.import"):
				found[f.trim_suffix(".glb.import")] = true
	var names := found.keys()
	names.sort()
	var id := 1
	for n: String in names:
		_register(id, n, n != "water.cube")
		id += 1

static func _register(id: int, block_name: String, has_col: bool) -> void:
	while _defs.size() <= id:
		_defs.append({})
	_defs[id] = {"id": id, "name": block_name, "has_collision": has_col}
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

static func get_mesh(id: int) -> Mesh:
	if id == AIR:
		return null
	if _mesh_cache.has(id):
		return _mesh_cache[id]
	var block_name := get_name_from_id(id)
	if block_name == "air":
		return null
	var scene := load("%s/%s.glb" % [BLOCKS_DIR, block_name]) as PackedScene
	var mesh: Mesh = null
	var mat := _get_water_material() if block_name == "water.cube" else _get_cel_material()
	if scene:
		var inst := scene.instantiate()
		var mi := _find_mesh_instance(inst)
		if mi and mi.mesh:
			mesh = mi.mesh.duplicate()
			for si in mesh.get_surface_count():
				mesh.surface_set_material(si, mat)
		inst.free()
	_mesh_cache[id] = mesh
	return mesh

## Unit box for full cubes, convex hull for shaped blocks (ramps, stairs,
## slabs, octagons, gables) so they are walkable, null for water.
static func get_collision_shape(id: int) -> Shape3D:
	if not has_collision(id):
		return null
	if _shape_cache.has(id):
		return _shape_cache[id]
	var block_name := get_name_from_id(id)
	var shape: Shape3D
	if block_name.ends_with(".cube") or block_name.ends_with(".opening"):
		if not _box_shape:
			_box_shape = BoxShape3D.new()
			_box_shape.size = Vector3.ONE
		shape = _box_shape
	elif block_name.contains(".stairs"):
		# stair meshes have vertical riser lips a capsule can't climb;
		# collide as a smooth ramp wedge instead (rises toward +X like the mesh)
		shape = _wedge_shape()
	else:
		var mesh := get_mesh(id)
		if mesh:
			shape = mesh.create_convex_shape(true, true)
	_shape_cache[id] = shape
	return shape

static var _wedge: ConvexPolygonShape3D

static func _wedge_shape() -> ConvexPolygonShape3D:
	if not _wedge:
		_wedge = ConvexPolygonShape3D.new()
		_wedge.points = PackedVector3Array([
			Vector3(-0.5, 0.0, -0.5), Vector3(-0.5, 0.0, 0.5),
			Vector3(0.5, 0.0, -0.5), Vector3(0.5, 0.0, 0.5),
			Vector3(0.5, 1.0, -0.5), Vector3(0.5, 1.0, 0.5),
		])
	return _wedge

static func is_full_cube(id: int) -> bool:
	var n := get_name_from_id(id)
	return n.ends_with(".cube") or n.ends_with(".opening")

static func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null

static func _get_cel_material() -> ShaderMaterial:
	if _cel_mat:
		return _cel_mat
	var sh := load("res://shaders/cel.gdshader") as Shader
	_cel_mat = ShaderMaterial.new()
	_cel_mat.shader = sh
	_cel_mat.set_shader_parameter("use_vertex_color", true)
	_cel_mat.set_shader_parameter("shadow_strength", 0.4)
	_cel_mat.set_shader_parameter("bands", 3)
	_cel_mat.set_shader_parameter("cutaway_affected", true)
	return _cel_mat

static func _get_water_material() -> ShaderMaterial:
	if _water_mat:
		return _water_mat
	_water_mat = _get_cel_material().duplicate()
	_water_mat.set_shader_parameter("is_water", true)
	return _water_mat

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
