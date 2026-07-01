extends Node

@export var voxel_world_path: NodePath
@export var camera_path: NodePath

var active := false
var selected_idx := 0
var _placeable_ids: Array[int] = []
var _cursor_preview: MeshInstance3D
var _cursor_mat: StandardMaterial3D
var _world: Node
var _camera: Camera3D

signal editor_toggled(is_active: bool)
signal block_selected(block_id: int, block_name: String)

func _ready() -> void:
	_world = get_node(voxel_world_path)
	_camera = get_node(camera_path)
	_placeable_ids = BlockRegistry.get_placeable_ids()

	_cursor_mat = StandardMaterial3D.new()
	_cursor_mat.albedo_color = Color(1, 1, 1, 0.35)
	_cursor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cursor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cursor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_cursor_preview = MeshInstance3D.new()
	_cursor_preview.visible = false
	_update_cursor_mesh()
	get_tree().root.add_child.call_deferred(_cursor_preview)

func _update_cursor_mesh() -> void:
	var id := _placeable_ids[selected_idx]
	var mesh := BlockRegistry.get_mesh(id)
	if mesh:
		_cursor_preview.mesh = mesh
		_cursor_preview.material_override = _cursor_mat

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("editor_toggle"):
		active = not active
		_cursor_preview.visible = false
		editor_toggled.emit(active)
		get_viewport().set_input_as_handled()
		return

	if not active:
		return

	if event.is_action_pressed("editor_block_next"):
		selected_idx = (selected_idx + 1) % _placeable_ids.size()
		_update_cursor_mesh()
		block_selected.emit(_placeable_ids[selected_idx], BlockRegistry.get_name_from_id(_placeable_ids[selected_idx]))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("editor_block_prev"):
		selected_idx = (selected_idx - 1 + _placeable_ids.size()) % _placeable_ids.size()
		_update_cursor_mesh()
		block_selected.emit(_placeable_ids[selected_idx], BlockRegistry.get_name_from_id(_placeable_ids[selected_idx]))
		get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_place_block()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_remove_block()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not active:
		_cursor_preview.visible = false
		return
	var result := _raycast_cursor()
	if result.is_empty():
		_cursor_preview.visible = false
		return
	var place_pos := _get_place_position(result)
	_cursor_preview.position = Vector3(place_pos.x, place_pos.y, place_pos.z)
	_cursor_preview.visible = true

func _place_block() -> void:
	var result := _raycast_cursor()
	if result.is_empty():
		return
	var pos := _get_place_position(result)
	var id := _placeable_ids[selected_idx]
	_world.set_block(pos.x, pos.y, pos.z, id)

func _remove_block() -> void:
	var result := _raycast_cursor()
	if result.is_empty():
		return
	var pos := _get_remove_position(result)
	if _world.get_block(pos.x, pos.y, pos.z) != BlockRegistry.AIR:
		_world.set_block(pos.x, pos.y, pos.z, BlockRegistry.AIR)

func _raycast_cursor() -> Dictionary:
	if not _camera:
		return {}
	var mouse_pos := _camera.get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse_pos)
	var direction := _camera.project_ray_normal(mouse_pos)
	var space := _camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0)
	return space.intersect_ray(query)

func _get_place_position(result: Dictionary) -> Vector3i:
	var hit_pos: Vector3 = result["position"]
	var hit_normal: Vector3 = result["normal"]
	var place := hit_pos + hit_normal * 0.5
	return Vector3i(floori(place.x), floori(place.y), floori(place.z))

func _get_remove_position(result: Dictionary) -> Vector3i:
	var hit_pos: Vector3 = result["position"]
	var hit_normal: Vector3 = result["normal"]
	var remove := hit_pos - hit_normal * 0.5
	return Vector3i(floori(remove.x), floori(remove.y), floori(remove.z))

func get_selected_block_name() -> String:
	return BlockRegistry.get_name_from_id(_placeable_ids[selected_idx])

func get_selected_block_id() -> int:
	return _placeable_ids[selected_idx]
