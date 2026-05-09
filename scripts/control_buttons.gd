extends BoxContainer

@onready var uv_viewer: Control = $"../uv_viewer_ui/uv_unwrap_texture/uv_viewer"
@onready var uv_unwrap: Button = $uv_viewer_visible
@onready var create_paint: Button = $create_paint_texture

var uv_toggle: bool = true

func _ready():
	uv_viewer.visible = false
	uv_unwrap.pressed.connect(_on_uv_unwrap_pressed)
	create_paint.pressed.connect(_on_create_paint_texture_pressed)

func _on_uv_unwrap_pressed():
	uv_toggle = !uv_toggle
	uv_viewer.visible = uv_toggle

func _on_create_paint_texture_pressed():
	var ok: bool = uv_viewer.create_paint_texture()
	if ok:
		print("[ControlButtons] Paint texture assigned successfully")
		create_paint.text = "Paint Texture Active"
		create_paint.disabled = true
	else:
		push_warning("[ControlButtons] Paint texture creation failed — check output above")
