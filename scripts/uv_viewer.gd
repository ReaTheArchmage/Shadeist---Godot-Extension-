@tool
extends Control

@export var target_mesh: MeshInstance3D:
	set(value):
		target_mesh = value
		_refresh()

@export_range(0, 1) var uv_layer: int = 0:
	set(value):
		uv_layer = value
		_refresh()

@export var show_texture: bool = true:
	set(value):
		show_texture = value
		queue_redraw()

@export var wire_color: Color = Color(0.0, 1.0, 0.4, 0.85)
@export var background_color: Color = Color(0.1, 0.1, 0.1)
@export var cursor_color: Color = Color(1.0, 0.4, 0.0, 1.0)

## Emitted when a writable paint texture has been created and is ready for the brush.
signal paint_texture_ready(image: Image, mat: Material)

var _uv_lines: PackedVector2Array = []
var _texture: Texture2D = null

# Each entry: { v: [Vector3, Vector3, Vector3], uv: [Vector2, Vector2, Vector2] }
var _triangles: Array = []

var _paint_image: Image = null
var _paint_mat: Material = null

var _cursor_uv: Vector2 = Vector2.ZERO
var _has_cursor: bool = false

## Public read access for the brush to consume.
var cursor_uv: Vector2:
	get: return _cursor_uv
var has_cursor: bool:
	get: return _has_cursor


func _refresh() -> void:
	_uv_lines.clear()
	_triangles.clear()
	_texture = null
	_has_cursor = false

	if not target_mesh or not target_mesh.mesh:
		queue_redraw()
		return

	_build_uv_lines()
	_build_triangles()
	_fetch_texture()
	queue_redraw()


func _build_uv_lines() -> void:
	var mesh := target_mesh.mesh
	var array_key := Mesh.ARRAY_TEX_UV if uv_layer == 0 else Mesh.ARRAY_TEX_UV2

	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var uvs: PackedVector2Array = arrays[array_key]
		if uvs.is_empty():
			continue

		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var has_indices := indices.size() > 0
		var ic := indices.size() if has_indices else uvs.size()

		for j in range(0, ic, 3):
			for k in range(3):
				var ai := indices[j + k] if has_indices else j + k
				var bi := indices[j + (k + 1) % 3] if has_indices else j + (k + 1) % 3
				_uv_lines.append(uvs[ai])
				_uv_lines.append(uvs[bi])


func _build_triangles() -> void:
	var mesh := target_mesh.mesh
	var array_key := Mesh.ARRAY_TEX_UV if uv_layer == 0 else Mesh.ARRAY_TEX_UV2

	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[array_key]
		if uvs.is_empty():
			continue

		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var has_indices := indices.size() > 0
		var ic := indices.size() if has_indices else verts.size()

		for j in range(0, ic, 3):
			var ai := indices[j] if has_indices else j
			var bi := indices[j + 1] if has_indices else j + 1
			var ci := indices[j + 2] if has_indices else j + 2
			_triangles.append({
				"v": [verts[ai], verts[bi], verts[ci]],
				"uv": [uvs[ai], uvs[bi], uvs[ci]]
			})


func _fetch_texture() -> void:
	var mat := target_mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		_texture = (mat as StandardMaterial3D).albedo_texture
	elif mat is ShaderMaterial:
		for param: StringName in ["texture_albedo", "albedo_texture", "texture", "tex"]:
			var val = (mat as ShaderMaterial).get_shader_parameter(param)
			if val is Texture2D:
				_texture = val
				break


## Call each frame with the world-space hit position from a surface raycast.
func update_cursor_from_world(world_pos: Vector3) -> void:
	if not target_mesh or _triangles.is_empty():
		_has_cursor = false
		queue_redraw()
		return

	var local_pos := target_mesh.global_transform.affine_inverse() * world_pos

	var best_dist := INF
	var best_uv := Vector2.ZERO
	_has_cursor = false

	for tri in _triangles:
		var v: Array = tri.v
		var uv: Array = tri.uv
		var bary := _barycentric(local_pos, v[0], v[1], v[2])
		if bary.x < -0.001 or bary.y < -0.001 or bary.z < -0.001:
			continue
		# Project the point onto the triangle plane to get a distance for ranking
		var projected: Vector3 = v[0] * bary.x + v[1] * bary.y + v[2] * bary.z
		var dist := local_pos.distance_to(projected)
		if dist < best_dist:
			best_dist = dist
			best_uv = uv[0] * bary.x + uv[1] * bary.y + uv[2] * bary.z
			_has_cursor = true

	_cursor_uv = best_uv
	queue_redraw()


func clear_cursor() -> void:
	if _has_cursor:
		_has_cursor = false
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	if show_texture and _texture:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)

	if _uv_lines.is_empty():
		var font := ThemeDB.fallback_font
		var msg := "Assign a MeshInstance3D" if not target_mesh else "No UV%d found" % (uv_layer + 1)
		var text_size := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		draw_string(font, size * 0.5 - text_size * 0.5, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		return

	var scaled := PackedVector2Array()
	scaled.resize(_uv_lines.size())
	for i in _uv_lines.size():
		scaled[i] = _uv_lines[i] * size

	draw_multiline(scaled, wire_color, 1.0)

	if _has_cursor:
		var p := _cursor_uv * size
		const R := 5.0
		const ARM := 10.0
		draw_circle(p, R, cursor_color)
		draw_arc(p, R + 2.0, 0.0, TAU, 32, Color.WHITE, 1.5)
		draw_line(p + Vector2(-ARM, 0), p + Vector2(ARM, 0), Color.WHITE, 1.5)
		draw_line(p + Vector2(0, -ARM), p + Vector2(0, ARM), Color.WHITE, 1.5)


## Duplicates the current albedo texture and reassigns it to the mesh material,
## so edits don't affect the original imported asset.
func create_paint_texture() -> bool:
	if not target_mesh or not target_mesh.mesh:
		push_warning("[UVViewer] create_paint_texture: no target mesh assigned")
		return false

	if not _texture:
		push_warning("[UVViewer] create_paint_texture: mesh has no albedo texture to copy")
		return false

	var image := _texture.get_image()
	if image == null:
		push_error("[UVViewer] create_paint_texture: get_image() returned null — texture may not be readable")
		return false

	image = image.duplicate() as Image
	var paint_texture := ImageTexture.create_from_image(image)

	var mat := target_mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		(mat as StandardMaterial3D).albedo_texture = paint_texture
	elif mat is ShaderMaterial:
		for param: StringName in ["texture_albedo", "albedo_texture", "texture", "tex"]:
			if (mat as ShaderMaterial).get_shader_parameter(param) is Texture2D:
				(mat as ShaderMaterial).set_shader_parameter(param, paint_texture)
				break
	else:
		push_error("[UVViewer] create_paint_texture: unsupported material type: %s" % mat.get_class())
		return false

	_paint_image = image
	_paint_mat = mat
	print("[UVViewer] Paint texture created — size: %dx%d, format id: %d" % [
		image.get_width(), image.get_height(), image.get_format()
	])
	paint_texture_ready.emit(image, mat)
	_refresh()
	return true


## Compute barycentric coordinates of p with respect to triangle (a, b, c).
## Returns Vector3(u, v, w) where u+v+w=1. All >= 0 means p is inside.
static func _barycentric(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denom := d00 * d11 - d01 * d01
	if absf(denom) < 1e-10:
		return Vector3(-1.0, -1.0, -1.0)
	var bv := (d11 * d20 - d01 * d21) / denom
	var bw := (d00 * d21 - d01 * d20) / denom
	return Vector3(1.0 - bv - bw, bv, bw)
