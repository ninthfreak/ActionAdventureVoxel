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

@export_multiline var map_layout: String
@export var center_map: bool = true

var _mesh_cache: Dictionary = {}

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

func _load_mesh(block_name: String) -> Mesh:
	if _mesh_cache.has(block_name):
		return _mesh_cache[block_name]
	var path := "res://blocks/%s.obj" % block_name
	var mesh: Mesh = load(path)
	if mesh:
		_make_unshaded(mesh)
	_mesh_cache[block_name] = mesh
	return mesh

func _make_unshaded(mesh: Mesh) -> void:
	for i in mesh.get_surface_count():
		var mat := mesh.surface_get_material(i)
		if mat is StandardMaterial3D:
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
