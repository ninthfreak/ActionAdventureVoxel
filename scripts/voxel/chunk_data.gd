class_name ChunkData

const SIZE := 16
const VOLUME := SIZE * SIZE * SIZE

var blocks := PackedByteArray()

func _init() -> void:
	blocks.resize(VOLUME)
	blocks.fill(0)

func get_block(x: int, y: int, z: int) -> int:
	if x < 0 or x >= SIZE or y < 0 or y >= SIZE or z < 0 or z >= SIZE:
		return 0
	return blocks[x + z * SIZE + y * SIZE * SIZE]

func set_block(x: int, y: int, z: int, id: int) -> void:
	if x < 0 or x >= SIZE or y < 0 or y >= SIZE or z < 0 or z >= SIZE:
		return
	blocks[x + z * SIZE + y * SIZE * SIZE] = id

func is_empty() -> bool:
	for b in blocks:
		if b != 0:
			return false
	return true
