class_name ObjLoader
## Parses OBJ + MTL files at runtime and builds an ArrayMesh with vertex
## colors, bypassing Godot's OBJ importer entirely.

static var _bad_winding_blocks: PackedStringArray = []
static var blocks_directory := "res://blocks"

static func load_block(block_name: String) -> ArrayMesh:
	var obj_path := "%s/%s.obj" % [blocks_directory, block_name]
	var mtl_path := "%s/%s.mtl" % [blocks_directory, block_name]
	var colors := _parse_mtl(mtl_path)
	return _parse_obj(obj_path, block_name, colors)

static func get_bad_winding_blocks() -> PackedStringArray:
	return _bad_winding_blocks

static func _parse_mtl(path: String) -> Dictionary:
	var colors := {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return colors
	var current_name := ""
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("newmtl "):
			current_name = line.substr(7).strip_edges()
		elif line.begins_with("Kd ") and current_name != "":
			var p := line.split(" ", false)
			if p.size() >= 4:
				colors[current_name] = Color(float(p[1]), float(p[2]), float(p[3]))
	f.close()
	return colors

static func _parse_obj(path: String, block_name: String, colors: Dictionary) -> ArrayMesh:
	var verts: Array[Vector3] = []
	var norms: Array[Vector3] = []

	var tri_v := PackedVector3Array()
	var tri_n := PackedVector3Array()
	var tri_c := PackedColorArray()

	var bad_face_count := 0
	var cur_color := Color.WHITE
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return null

	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("v "):
			var p := line.split(" ", false)
			verts.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
		elif line.begins_with("vn "):
			var p := line.split(" ", false)
			norms.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
		elif line.begins_with("usemtl "):
			var mat_name := line.substr(7).strip_edges()
			cur_color = colors.get(mat_name, Color.WHITE)
		elif line.begins_with("f "):
			var p := line.split(" ", false)
			var face_v: Array[int] = []
			var face_n: Array[int] = []
			for i in range(1, p.size()):
				var pair := p[i].split("//")
				face_v.append(int(pair[0]) - 1)
				face_n.append(int(pair[1]) - 1)
			for i in range(1, face_v.size() - 1):
				var v0 := verts[face_v[0]]
				var v1 := verts[face_v[i]]
				var v2 := verts[face_v[i + 1]]
				var n0 := norms[face_n[0]]
				var n1 := norms[face_n[i]]
				var n2 := norms[face_n[i + 1]]
				if (v1 - v0).cross(v2 - v0).dot(n0) > 0.0:
					bad_face_count += 1
				tri_v.append(v0); tri_v.append(v1); tri_v.append(v2)
				tri_n.append(n0); tri_n.append(n1); tri_n.append(n2)
				tri_c.append(cur_color)
				tri_c.append(cur_color)
				tri_c.append(cur_color)
	f.close()

	if bad_face_count > 0:
		push_warning("OBJ winding issue: %s has %d faces with bad winding" % [block_name, bad_face_count])
		if block_name not in _bad_winding_blocks:
			_bad_winding_blocks.append(block_name)

	var mesh := ArrayMesh.new()
	var mat: Material
	var cel_shader := load("res://shaders/cel.gdshader") as Shader
	if cel_shader:
		var sm := ShaderMaterial.new()
		sm.shader = cel_shader
		sm.set_shader_parameter("use_vertex_color", true)
		sm.set_shader_parameter("shadow_strength", 0.4)
		sm.set_shader_parameter("bands", 3)
		mat = sm
	else:
		var std := StandardMaterial3D.new()
		std.vertex_color_use_as_albedo = true
		std.roughness = 1.0
		std.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mat = std

	var total := tri_v.size()
	var chunk := 60000
	var i := 0
	while i < total:
		var end := mini(i + chunk, total)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = tri_v.slice(i, end)
		arrays[Mesh.ARRAY_NORMAL] = tri_n.slice(i, end)
		arrays[Mesh.ARRAY_COLOR] = tri_c.slice(i, end)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		i = end

	return mesh
