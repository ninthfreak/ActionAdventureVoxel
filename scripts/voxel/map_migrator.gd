class_name MapMigrator

const BLOCK_KEY := {
	"G": "grass",
	"D": "dirt",
	"S": "sand",
	"W": "water",
	"A": "asphalt",
	"V": "gravel",
	"K": "concrete_walkway",
	"B": "bricks",
	"C": "cement_blocks",
	"L": "leaves",
	"R": "shingles_slate",
	"T": "tree_generic_large",
	"t": "tree_birch_small",
	"P": "metal_pole_large",
	"p": "metal_pole_small",
}

const GROUND_UNDER := {
	"T": "grass",
	"t": "grass",
	"P": "concrete_walkway",
	"p": "concrete_walkway",
	"L": "grass",
}

const STACK_HEIGHT := {
	"B": 2,
	"C": 2,
	"T": 1,
	"t": 1,
	"P": 3,
	"p": 2,
	"L": 1,
	"R": 1,
}

static func migrate(world: Node, map_layout: String, struct_layout: String, center: bool) -> void:
	var rows := map_layout.strip_edges().split("\n")
	var width := 0
	for r in rows:
		width = max(width, r.strip_edges().length())
	var height := rows.size()

	var ox := 0
	var oz := 0
	if center:
		ox = -int(width / 2)
		oz = -int(height / 2)

	for row_idx in height:
		var row := rows[row_idx].strip_edges()
		for col_idx in row.length():
			var ch := row[col_idx]
			if ch == " " or ch == ".":
				continue
			var block_name: String = BLOCK_KEY.get(ch, "")
			if block_name.is_empty():
				continue
			var wy := 0
			if ch == "W":
				wy = -1
			var wx := col_idx + ox
			var wz := row_idx + oz
			world.set_block_no_rebuild(wx, wy, wz, BlockRegistry.get_id(block_name))

	if struct_layout.strip_edges().is_empty():
		world.rebuild_all()
		return

	var srows := struct_layout.strip_edges().split("\n")
	for row_idx in srows.size():
		var row := srows[row_idx].strip_edges()
		for col_idx in row.length():
			var ch := row[col_idx]
			if ch == " " or ch == ".":
				continue
			var block_name: String = BLOCK_KEY.get(ch, "")
			if block_name.is_empty():
				continue

			var wx := col_idx + ox
			var wz := row_idx + oz

			if GROUND_UNDER.has(ch):
				var ground_name: String = GROUND_UNDER[ch]
				world.set_block_no_rebuild(wx, 0, wz, BlockRegistry.get_id(ground_name))

			var stack: int = STACK_HEIGHT.get(ch, 1)
			var block_id := BlockRegistry.get_id(block_name)
			for y in stack:
				world.set_block_no_rebuild(wx, y + 1, wz, block_id)

			if ch == "R":
				_place_roof_peak(world, block_name, col_idx, row_idx, row, srows, ox, oz)

	world.rebuild_all()

static func _place_roof_peak(world: Node, block_name: String, col: int, row_idx: int, row: String, srows: PackedStringArray, ox: int, oz: int) -> void:
	var left_r := col > 0 and col - 1 < row.length() and row[col - 1] == "R"
	var right_r := col + 1 < row.length() and row[col + 1] == "R"
	if left_r and right_r:
		world.set_block_no_rebuild(col + ox, 2, row_idx + oz, BlockRegistry.get_id(block_name))
