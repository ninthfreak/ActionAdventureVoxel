class_name ChunkData

const SIZE := 16
const VOLUME := SIZE * SIZE * SIZE

var blocks := PackedByteArray()
## Per-block yaw: 0-3 quarter turns counter-clockwise (Basis(UP, rot * PI/2)).
var rots := PackedByteArray()

func _init() -> void:
	blocks.resize(VOLUME)
	blocks.fill(0)
	rots.resize(VOLUME)
	rots.fill(0)

func get_block(x: int, y: int, z: int) -> int:
	if x < 0 or x >= SIZE or y < 0 or y >= SIZE or z < 0 or z >= SIZE:
		return 0
	return blocks[x + z * SIZE + y * SIZE * SIZE]

func set_block(x: int, y: int, z: int, id: int, rot: int = 0) -> void:
	if x < 0 or x >= SIZE or y < 0 or y >= SIZE or z < 0 or z >= SIZE:
		return
	var i := x + z * SIZE + y * SIZE * SIZE
	blocks[i] = id
	rots[i] = rot & 3

func get_rot(x: int, y: int, z: int) -> int:
	if x < 0 or x >= SIZE or y < 0 or y >= SIZE or z < 0 or z >= SIZE:
		return 0
	return rots[x + z * SIZE + y * SIZE * SIZE]

func is_empty() -> bool:
	for b in blocks:
		if b != 0:
			return false
	return true
