extends Node3D
## Builds a block map at runtime from a text layout.
## Each character maps to a voxel block type loaded from res://blocks/.

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
}

const WALL_TILES := ["B"]

# Average fill color per block type — backs the voxel mesh so sub-pixel
# gaps between tiny quads show a matching color instead of the sky.
const FILL_COLORS := {
	"grass":             Color(0.40, 0.48, 0.30),
	"dirt":              Color(0.42, 0.32, 0.22),
	"sand":              Color(0.72, 0.64, 0.42),
	"water":             Color(0.22, 0.34, 0.50),
	"asphalt":           Color(0.28, 0.28, 0.28),
	"gravel":            Color(0.46, 0.44, 0.38),
	"concrete_walkway":  Color(0.62, 0.60, 0.56),
	"bricks":            Color(0.52, 0.30, 0.24),
	"cement_blocks":     Color(0.56, 0.54, 0.50),
}

@export_multiline var map_layout: String
@export var center_map: bool = true

var _mesh_cache: Dictionary = {}
var _fill_cache: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build()

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

			if ch in WALL_TILES:
				_add_wall(block_name, Vector3(col_idx, 0.0, row_idx) + offset)

func _add_block(block_name: String, pos: Vector3) -> void:
	_add_fill_box(block_name, pos)
	var mesh := _load_mesh(block_name)
	if not mesh:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)

func _add_wall(block_name: String, pos: Vector3) -> void:
	var mesh := _load_mesh(block_name)
	if not mesh:
		return

	var body := StaticBody3D.new()
	body.position = pos

	_add_fill_box(block_name, Vector3.ZERO, body)

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

func _add_fill_box(block_name: String, pos: Vector3, parent: Node = null) -> void:
	if not parent:
		parent = self
	var fill := MeshInstance3D.new()
	fill.mesh = _get_fill_mesh(block_name)
	fill.position = pos
	fill.scale = Vector3(0.998, 0.998, 0.998)
	parent.add_child(fill)

func _get_fill_mesh(block_name: String) -> BoxMesh:
	if _fill_cache.has(block_name):
		return _fill_cache[block_name]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = FILL_COLORS.get(block_name, Color(0.3, 0.3, 0.3))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 1.0, 1.0)
	bm.material = mat
	_fill_cache[block_name] = bm
	return bm

func _load_mesh(block_name: String) -> Mesh:
	if _mesh_cache.has(block_name):
		return _mesh_cache[block_name]
	var path := "res://blocks/%s.obj" % block_name
	var mesh: Mesh = load(path)
	_mesh_cache[block_name] = mesh
	return mesh
