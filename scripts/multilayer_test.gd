extends Node3D

@onready var gizmo: Gizmo3D = $Gizmo3D
@onready var mesh: MeshInstance3D = $MeshInstance3D2
@onready var surface_raycast = $SurfaceRaycast
@onready var uv_viewer: Control = $Control/uv_viewer_ui/uv_unwrap_texture/uv_viewer

## Assign the brush scene instance in the inspector once it is added to the scene.
@export var brush: Node

func _ready() -> void:
	gizmo.select(mesh)
	uv_viewer.paint_texture_ready.connect(_on_paint_texture_ready)
	if brush:
		brush.uv_source = uv_viewer
		# Defer so Godot's layout pass finishes before we read positions/sizes.
		brush.call_deferred("align_to", uv_viewer)
		uv_viewer.resized.connect(func(): brush.align_to(uv_viewer))

func _process(_delta: float) -> void:
	if surface_raycast.has_hit:
		uv_viewer.update_cursor_from_world(surface_raycast.hit_point)
	else:
		uv_viewer.clear_cursor()

func _on_paint_texture_ready(image: Image, mat: Material) -> void:
	if brush == null:
		push_warning("[multilayer_test] paint_texture_ready fired but no brush node assigned")
		return
	brush.setup(image, mat)
	print("[multilayer_test] Brush wired to paint texture (%dx%d)" % [
		image.get_width(), image.get_height()
	])
