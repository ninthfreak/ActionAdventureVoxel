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
static var _swap_mats: Array[ShaderMaterial] = []
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
	if scene:
		var inst := scene.instantiate()
		var mi := _find_mesh_instance(inst)
		if mi and mi.mesh:
			# PrismCraft GLBs bake their 32x32 textures as one quad PER TEXEL
			# (a plain cube is ~8600 triangles). Rebuild .cube blocks as
			# 12-triangle cubes with the colors extracted into a real texture.
			if block_name.ends_with(".cube"):
				mesh = _build_cube_proxy(mi.mesh, block_name)
			if not mesh:
				mesh = mi.mesh.duplicate()
				var mat := _get_water_material() if block_name == "water.cube" else _get_cel_material()
				for si in mesh.get_surface_count():
					mesh.surface_set_material(si, mat)
		inst.free()
	_mesh_cache[id] = mesh
	return mesh

# --- textured cube proxies ------------------------------------------------

## Face order +X, -X, +Y, -Y, +Z, -Z; each is a 32x32 tile in a 192x32 atlas.
const _FACE_NORMALS: Array[Vector3] = [
	Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0),
	Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
]

## Corner order per face is clockwise seen from outside (Godot front-face
## winding); geometry spans x,z in [-0.5,0.5], y in [0,1] like the GLBs.
const _FACE_CORNERS := [
	[Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(0.5, 1, 0.5), Vector3(0.5, 1, -0.5)],
	[Vector3(-0.5, 0, -0.5), Vector3(-0.5, 1, -0.5), Vector3(-0.5, 1, 0.5), Vector3(-0.5, 0, 0.5)],
	[Vector3(-0.5, 1, -0.5), Vector3(0.5, 1, -0.5), Vector3(0.5, 1, 0.5), Vector3(-0.5, 1, 0.5)],
	[Vector3(-0.5, 0, -0.5), Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, 0.5), Vector3(0.5, 0, -0.5)],
	[Vector3(-0.5, 0, 0.5), Vector3(-0.5, 1, 0.5), Vector3(0.5, 1, 0.5), Vector3(0.5, 0, 0.5)],
	[Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 1, -0.5), Vector3(-0.5, 1, -0.5)],
]

static func _face_uv(face: int, p: Vector3) -> Vector2:
	match face:
		0, 1:
			return Vector2(p.z + 0.5, p.y)
		2, 3:
			return Vector2(p.x + 0.5, p.z + 0.5)
		_:
			return Vector2(p.x + 0.5, p.y)

static func _dominant_face(n: Vector3) -> int:
	var ax := absf(n.x)
	var ay := absf(n.y)
	var az := absf(n.z)
	if ax >= ay and ax >= az:
		return 0 if n.x > 0.0 else 1
	if ay >= az:
		return 2 if n.y > 0.0 else 3
	return 4 if n.z > 0.0 else 5

## Extract the texel colors from the tessellated source mesh into a face
## atlas, then build a 12-triangle cube that samples it. Returns null when
## the source has no vertex colors (falls back to the raw mesh).
static func _build_cube_proxy(src: Mesh, block_name: String) -> ArrayMesh:
	var img := Image.create(192, 32, false, Image.FORMAT_RGB8)
	var painted := false

	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] else PackedColorArray()
		if cols.is_empty():
			continue
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()
		var tri_count := (idx.size() if not idx.is_empty() else verts.size()) / 3

		if not painted:
			# prefill with the mesh's average color so any unpainted texel
			# blends in instead of showing black
			var sum := Vector3.ZERO
			for c in cols:
				sum += Vector3(c.r, c.g, c.b)
			sum /= float(cols.size())
			img.fill(Color(sum.x, sum.y, sum.z))
			painted = true

		for t in tri_count:
			var i0 := idx[t * 3] if not idx.is_empty() else t * 3
			var i1 := idx[t * 3 + 1] if not idx.is_empty() else t * 3 + 1
			var i2 := idx[t * 3 + 2] if not idx.is_empty() else t * 3 + 2
			var n := norms[i0] if not norms.is_empty() else Vector3.UP
			var face := _dominant_face(n)
			var uv0 := _face_uv(face, verts[i0])
			var uv1 := _face_uv(face, verts[i1])
			var uv2 := _face_uv(face, verts[i2])
			var lo := Vector2(minf(uv0.x, minf(uv1.x, uv2.x)), minf(uv0.y, minf(uv1.y, uv2.y)))
			var hi := Vector2(maxf(uv0.x, maxf(uv1.x, uv2.x)), maxf(uv0.y, maxf(uv1.y, uv2.y)))
			var px0 := clampi(floori(lo.x * 32.0 + 0.001), 0, 31)
			var px1 := clampi(ceili(hi.x * 32.0 - 0.001) - 1, 0, 31)
			var py0 := clampi(floori(lo.y * 32.0 + 0.001), 0, 31)
			var py1 := clampi(ceili(hi.y * 32.0 - 0.001) - 1, 0, 31)
			var col := cols[i0]
			for px in range(px0, px1 + 1):
				for py in range(py0, py1 + 1):
					img.set_pixel(face * 32 + px, py, col)

	if not painted:
		return null

	var mat := _get_cel_material().duplicate() as ShaderMaterial
	mat.set_shader_parameter("use_vertex_color", false)
	mat.set_shader_parameter("use_texture", true)
	mat.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))
	if block_name == "water.cube":
		mat.set_shader_parameter("is_water", true)
	_swap_mats.append(mat)

	var v_out := PackedVector3Array()
	var n_out := PackedVector3Array()
	var uv_out := PackedVector2Array()
	var i_out := PackedInt32Array()
	for f in 6:
		var base := v_out.size()
		var corners: Array = _FACE_CORNERS[f]
		for c: Vector3 in corners:
			v_out.append(c)
			n_out.append(_FACE_NORMALS[f])
			var uv := _face_uv(f, c)
			uv_out.append(Vector2((float(f) + uv.x) / 6.0, uv.y))
		i_out.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

	var arrays_out := []
	arrays_out.resize(Mesh.ARRAY_MAX)
	arrays_out[Mesh.ARRAY_VERTEX] = v_out
	arrays_out[Mesh.ARRAY_NORMAL] = n_out
	arrays_out[Mesh.ARRAY_TEX_UV] = uv_out
	arrays_out[Mesh.ARRAY_INDEX] = i_out
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_out)
	out.surface_set_material(0, mat)
	return out

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

static var _sh_opaque: Shader
static var _sh_soft: Shader

static func _get_cel_material() -> ShaderMaterial:
	if _cel_mat:
		return _cel_mat
	_sh_opaque = load("res://shaders/cel_blocks_opaque.gdshader") as Shader
	_sh_soft = load("res://shaders/cel_blocks.gdshader") as Shader
	_cel_mat = ShaderMaterial.new()
	_cel_mat.shader = _sh_opaque
	_cel_mat.set_shader_parameter("use_vertex_color", true)
	_cel_mat.set_shader_parameter("shadow_strength", 0.4)
	_cel_mat.set_shader_parameter("bands", 3)
	_cel_mat.set_shader_parameter("cutaway_affected", true)
	return _cel_mat

## Blocks run the opaque pipeline by default; switch the shared materials to
## the transparent-pipeline shader only while a translucent cutaway or water
## reveal is actually visible. Uniforms persist across the swap.
static func set_translucent_pipeline(on: bool) -> void:
	_get_cel_material()
	var sh := _sh_soft if on else _sh_opaque
	if _cel_mat.shader == sh:
		return
	_cel_mat.shader = sh
	if _water_mat:
		_water_mat.shader = sh
	for m in _swap_mats:
		m.shader = sh

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
