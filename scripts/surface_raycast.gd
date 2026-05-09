extends Node3D

const RAY_LENGTH := 1000.0
const NORMAL_LENGTH := 0.5

## World-space hit position on the mesh surface, valid when has_hit is true.
var hit_point: Vector3
## Outward surface normal at the hit position, valid when has_hit is true.
var hit_normal: Vector3
var has_hit: bool = false

var _cursor_mesh: ImmediateMesh
var _normal_mesh: ImmediateMesh

func _ready() -> void:
	_cursor_mesh = _make_ray_instance(Color.YELLOW)
	_normal_mesh = _make_ray_instance(Color.CYAN)

func _make_ray_instance(color: Color) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.albedo_color = color
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	# top_level so the instance sits in world space regardless of parent transform
	instance.top_level = true
	add_child(instance)
	return mesh

func _process(_delta: float) -> void:
	_cursor_mesh.clear_surfaces()
	_normal_mesh.clear_surfaces()

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_pos) * RAY_LENGTH

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result := get_world_3d().direct_space_state.intersect_ray(query)

	has_hit = not result.is_empty()
	if not has_hit:
		return

	hit_point = result.position
	hit_normal = result.normal

	# Ray 1: camera origin → surface hit point (yellow)
	_cursor_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_cursor_mesh.surface_add_vertex(ray_origin)
	_cursor_mesh.surface_add_vertex(hit_point)
	_cursor_mesh.surface_end()

	# Ray 2: hit point → outward surface normal (cyan)
	_normal_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_normal_mesh.surface_add_vertex(hit_point)
	_normal_mesh.surface_add_vertex(hit_point + hit_normal * NORMAL_LENGTH)
	_normal_mesh.surface_end()
