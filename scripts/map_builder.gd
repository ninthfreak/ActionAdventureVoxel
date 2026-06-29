extends Node3D
## Builds a block map at runtime from a text layout.
## Each character maps to a voxel block type loaded from res://blocks/.
## Supports a ground layer and a structures layer for multi-height builds.

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

## How many blocks tall each structure character stacks
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

## Characters that get collision (walls, poles)
const COLLISION_TILES := ["B", "T", "t", "P", "p"]

@export_multiline var map_layout: String
@export_multiline var struct_layout: String
@export var center_map: bool = true

var _mesh_cache: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build()
	_check_bad_obj_files()

func _build() -> void:
	var rows := map_layout.strip_edges().split("\n")
	var width := 0
	for r in rows:
		width = max(width, r.strip_edges().length())
	var height := rows.size()

	var offset := Vector3.ZERO
	if center_map:
		offset = Vector3(-width * 0.5, 0.0, -height * 0.5)

	for row_idx in height:
		var row := rows[row_idx].strip_edges()
		for col_idx in row.length():
			var ch := row[col_idx]
			if ch == " " or ch == ".":
				continue
			var block_name: String = BLOCK_KEY.get(ch, "")
			if block_name.is_empty():
				continue

			var ground_y := -1.0
			if ch == "W":
				ground_y = -1.15

			var pos := Vector3(col_idx, ground_y, row_idx) + offset
			_add_block(block_name, pos)

	if struct_layout.strip_edges().is_empty():
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

			if GROUND_UNDER.has(ch):
				var ground_name: String = GROUND_UNDER[ch]
				_add_block(ground_name, Vector3(col_idx, -1.0, row_idx) + offset)

			var stack: int = STACK_HEIGHT.get(ch, 1)
			var has_collision: bool = ch in COLLISION_TILES
			for y in stack:
				var pos := Vector3(col_idx, float(y), row_idx) + offset
				if has_collision:
					_add_wall(block_name, pos)
				else:
					_add_block(block_name, pos)

			if ch == "R":
				_place_roof_peak(block_name, col_idx, row_idx, row, srows, offset)

func _place_roof_peak(block_name: String, col: int, row_idx: int, row: String, srows: PackedStringArray, offset: Vector3) -> void:
	var left_r := col > 0 and col - 1 < row.length() and row[col - 1] == "R"
	var right_r := col + 1 < row.length() and row[col + 1] == "R"
	if left_r and right_r:
		_add_block(block_name, Vector3(col, 1.0, row_idx) + offset)

func _add_block(block_name: String, pos: Vector3) -> void:
	var mesh := _get_mesh(block_name)
	if not mesh:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)

func _add_wall(block_name: String, pos: Vector3) -> void:
	var mesh := _get_mesh(block_name)
	if not mesh:
		return

	var body := StaticBody3D.new()
	body.position = pos

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	col.shape = box
	col.position = Vector3(0.0, 0.5, 0.0)
	body.add_child(col)

	add_child(body)

func _check_bad_obj_files() -> void:
	var bad := ObjLoader.get_bad_winding_blocks()
	if bad.is_empty():
		return
	var msg := "Bad face winding detected in OBJ files:\n"
	for b in bad:
		msg += "  • %s.obj\n" % b
	msg += "\nThese blocks will render incorrectly with back-face culling.\nRe-export them from PrismCraft to fix."
	var dialog := AcceptDialog.new()
	dialog.title = "OBJ Winding Warning"
	dialog.dialog_text = msg
	dialog.min_size = Vector2i(420, 200)
	get_tree().root.add_child.call_deferred(dialog)
	dialog.popup_centered.call_deferred()

func _get_mesh(block_name: String) -> ArrayMesh:
	if _mesh_cache.has(block_name):
		return _mesh_cache[block_name]
	var mesh := ObjLoader.load_block(block_name)
	_mesh_cache[block_name] = mesh
	return mesh
