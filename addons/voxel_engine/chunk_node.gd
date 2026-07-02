extends Node3D

var chunk_key := Vector3i.ZERO
var data: ChunkData

func build() -> void:
	for child in get_children():
		child.queue_free()

	if not data or data.is_empty():
		return

	var groups: Dictionary = {}
	for y in ChunkData.SIZE:
		for z in ChunkData.SIZE:
			for x in ChunkData.SIZE:
				var id := data.get_block(x, y, z)
				if id == BlockRegistry.AIR:
					continue
				if not groups.has(id):
					groups[id] = []
				groups[id].append(Vector3(x, y, z))

	for id in groups:
		var positions: Array = groups[id]
		var mesh := BlockRegistry.get_mesh(id)
		if not mesh:
			continue

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = positions.size()
		for i in positions.size():
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)

	var collision_positions: Array[Vector3] = []
	for id in groups:
		if not BlockRegistry.has_collision(id):
			continue
		for pos in groups[id]:
			if _is_exposed(int(pos.x), int(pos.y), int(pos.z)):
				collision_positions.append(pos)

	if not collision_positions.is_empty():
		var body := StaticBody3D.new()
		for pos in collision_positions:
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.0, 1.0, 1.0)
			col.shape = box
			col.position = pos + Vector3(0.0, 0.5, 0.0)
			body.add_child(col)
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
		if not BlockRegistry.has_collision(data.get_block(nx, ny, nz)):
			return true
	return false
