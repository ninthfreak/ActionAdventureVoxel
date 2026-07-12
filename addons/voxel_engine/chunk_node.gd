extends Node3D

var chunk_key := Vector3i.ZERO
var data: ChunkData

func build() -> void:
	for child in get_children():
		child.queue_free()

	if not data or data.is_empty():
		return

	# group by (id, rot) so each group renders as one MultiMesh.
	# Fully enclosed blocks (buried terrain fill, building attic fill) are
	# invisible and skipped entirely — a large instance-count win.
	var groups: Dictionary = {}
	for y in ChunkData.SIZE:
		for z in ChunkData.SIZE:
			for x in ChunkData.SIZE:
				var id := data.get_block(x, y, z)
				if id == BlockRegistry.AIR:
					continue
				if not _is_exposed(x, y, z):
					continue
				var key := (id << 2) | data.get_rot(x, y, z)
				if not groups.has(key):
					groups[key] = []
				groups[key].append(Vector3i(x, y, z))

	for key: int in groups:
		var id := key >> 2
		var rot := key & 3
		var positions: Array = groups[key]
		var mesh := BlockRegistry.get_mesh(id)
		if not mesh:
			continue

		var basis := Basis(Vector3.UP, float(rot) * PI * 0.5)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = positions.size()
		for i in positions.size():
			mm.set_instance_transform(i, Transform3D(basis, Vector3(positions[i])))

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)

	var body: StaticBody3D = null
	for key: int in groups:
		var id := key >> 2
		var rot := key & 3
		var shape := BlockRegistry.get_collision_shape(id)
		if not shape:
			continue
		for pos: Vector3i in groups[key]:
			if not body:
				body = StaticBody3D.new()
			var col := CollisionShape3D.new()
			col.shape = shape
			if shape is BoxShape3D:
				col.position = Vector3(pos) + Vector3(0.0, 0.5, 0.0)
			else:
				# shaped blocks: hull is modeled about the same origin as the
				# mesh, so it takes the same rotation
				col.transform = Transform3D(Basis(Vector3.UP, float(rot) * PI * 0.5), Vector3(pos))
			body.add_child(col)
	if body:
		add_child(body)

## A block needs a collision shape only if some face touches a non-solid
## neighbor. Out-of-chunk neighbors count as exposed to keep seams safe.
func _is_exposed(x: int, y: int, z: int) -> bool:
	for offset: Vector3i in [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]:
		var nx := x + offset.x
		var ny := y + offset.y
		var nz := z + offset.z
		if nx < 0 or nx >= ChunkData.SIZE or ny < 0 or ny >= ChunkData.SIZE or nz < 0 or nz >= ChunkData.SIZE:
			return true
		var nid := data.get_block(nx, ny, nz)
		if not BlockRegistry.has_collision(nid) or not BlockRegistry.is_full_cube(nid):
			return true
	return false
