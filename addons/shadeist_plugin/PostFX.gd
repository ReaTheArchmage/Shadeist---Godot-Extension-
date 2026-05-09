## Base class for all Shadeist post-processing effect nodes.
## [br][br]
## Must be a direct child of a [Camera2D] or [Camera3D]. The effect renders
## only when that camera is the active camera in the viewport, making it
## safe to place multiple PostFX nodes in scenes with multiple cameras.
@tool
extends CanvasLayer

var shader_rect: ColorRect

func _sp(param: String, value: Variant) -> void:
	if shader_rect and shader_rect.material:
		(shader_rect.material as ShaderMaterial).set_shader_parameter(param, value)

# ─── Global ───────────────────────────────────────────────────────────────────

## Opacity of the entire post-processing stack. At [code]1.0[/code] the fully
## processed image replaces the original; at [code]0.0[/code] all effects are
## invisible. Applied as the very last step, after every individual effect.
@export_range(0.0, 1.0) var global_opacity: float = 1.0:
	set(v): global_opacity = v; _sp("global_opacity", v)

## Blend mode used to composite the finished post-processed image back onto
## the original unprocessed frame. Applied together with [member global_opacity]
## as the very last step of the shader.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var global_blend: int = 0:
	set(v): global_blend = v; _sp("global_blend", v)


# ─── Virtual interface ────────────────────────────────────────────────────────

func _get_shader_path() -> String:
	return ""

func _sync_all() -> void:
	_sp("global_opacity", global_opacity)
	_sp("global_blend",   global_blend)


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _get_configuration_warnings() -> PackedStringArray:
	var parent := get_parent()
	if not (parent is Camera2D) and not (parent is Camera3D):
		return ["PostFX node must be a direct child of a Camera2D or Camera3D node to be displayed."]
	return []


func _ready() -> void:
	follow_viewport_enabled = false
	_build_rect()
	_fit_rect()
	_update_visibility()
	_sync_all()


func _process(_delta: float) -> void:
	_fit_rect()
	_update_visibility()


func _update_visibility() -> void:
	var parent := get_parent()
	if parent is Camera2D:
		var cam := parent as Camera2D
		visible = cam.get_viewport().get_camera_2d() == cam
	elif parent is Camera3D:
		visible = (parent as Camera3D).current
	else:
		visible = false


func _build_rect() -> void:
	if is_instance_valid(shader_rect):
		shader_rect.queue_free()
	shader_rect = ColorRect.new()
	shader_rect.name = "shader_rect"
	var mat := ShaderMaterial.new()
	var path := _get_shader_path()
	if path:
		mat.shader = load(path)
	shader_rect.material = mat
	# INTERNAL_MODE_BACK keeps the node out of the scene tree serializer
	# so ShaderMaterial parameters are never written to the scene file.
	add_child(shader_rect, false, Node.INTERNAL_MODE_BACK)


func _fit_rect() -> void:
	if not shader_rect:
		return
	var vp_size := get_viewport().get_visible_rect().size
	shader_rect.position = Vector2.ZERO
	shader_rect.size = vp_size
