extends Node

## UV viewer node — reads cursor_uv and has_cursor each frame to drive stamp position.
@export var uv_source: Control
## Texture stamped at each brush dab. Assign in the inspector or at runtime.
@export var brush_texture: Texture2D
## Seconds between dabs while the paint button is held.
@export_range(0.01, 1.0) var stamp_interval: float = 0.05
## Display diameter of each dab in pixels.
@export_range(1.0, 512.0) var brush_size: float = 32.0

@onready var strokes_container: Node = $strokes_container
@onready var undo_btn: Button = $brush_buttons/undo_stroke
@onready var redo_btn: Button = $brush_buttons/redo_stroke
@onready var bg: ColorRect = $bg

var _undo_stack: Array[Node] = []
var _redo_stack: Array[Node] = []
var _active_stroke: Node2D = null
var _stamp_timer: float = 0.0
var _is_painting: bool = false
var _stroke_count: int = 0

var _svc: SubViewportContainer = null
var _subviewport: SubViewport = null
var _base_sprite: Sprite2D = null
var _texture_size: Vector2i = Vector2i.ZERO

const BAKE_EVERY := 25
var _bake_counter: int = 0
var _bake_pending: bool = false


func _ready() -> void:
	undo_btn.pressed.connect(undo)
	redo_btn.pressed.connect(redo)
	_build_subviewport()
	_update_buttons()


func _build_subviewport() -> void:
	# SubViewportContainer replaces the bg ColorRect as the visible canvas.
	_svc = SubViewportContainer.new()
	_svc.position = bg.position
	_svc.size = bg.size
	# stretch = false keeps SubViewport.size at _texture_size regardless of the
	# container's display bounds. stretch = true would let the container override
	# SubViewport.size to the display resolution, causing a UV scale mismatch on bake.
	_svc.stretch = false
	# Display only — all painting input comes from the 3D viewport via _unhandled_input.
	_svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_svc)
	bg.hide()

	_subviewport = SubViewport.new()
	_subviewport.transparent_bg = true
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_subviewport.size = Vector2i(512, 512)  # placeholder until setup() is called
	_svc.add_child(_subviewport)

	# Move strokes_container inside the SubViewport so strokes render into the texture.
	strokes_container.reparent(_subviewport)

	# _svc is now the last child and sits on top in z-order, blocking button clicks.
	# Move the buttons container above it so it receives input first.
	var buttons := get_node_or_null("brush_buttons")
	if buttons:
		move_child(buttons, get_child_count() - 1)


## Call after uv_viewer.create_paint_texture() to wire up the live texture.
##   image — duplicated paint Image, becomes the base background layer
##   mat   — mesh Material that will receive the ViewportTexture as its albedo
func setup(image: Image, mat: Material) -> void:
	_texture_size = Vector2i(image.get_width(), image.get_height())
	_subviewport.size = _texture_size

	# Drop any previous base sprite.
	if is_instance_valid(_base_sprite):
		_base_sprite.queue_free()
	_base_sprite = Sprite2D.new()
	_base_sprite.texture = ImageTexture.create_from_image(image)
	_base_sprite.centered = true
	_base_sprite.position = Vector2(_subviewport.size) / 2.0
	_subviewport.add_child(_base_sprite)
	# Keep base sprite at index 0 so it renders behind all stroke Node2Ds.
	_subviewport.move_child(_base_sprite, 0)

	# Assign the live ViewportTexture to the mesh material.
	var vp_tex := _subviewport.get_texture()
	if mat is StandardMaterial3D:
		(mat as StandardMaterial3D).albedo_texture = vp_tex
	elif mat is ShaderMaterial:
		for param: StringName in ["texture_albedo", "albedo_texture", "texture", "tex"]:
			if (mat as ShaderMaterial).get_shader_parameter(param) is Texture2D:
				(mat as ShaderMaterial).set_shader_parameter(param, vp_tex)
				break

	# Fresh canvas — clear any leftover strokes.
	for child in strokes_container.get_children():
		child.queue_free()
	_undo_stack.clear()
	_redo_stack.clear()
	_stroke_count = 0
	_bake_counter = 0
	_bake_pending = false
	_update_buttons()

	print("[Brush] Setup complete — SubViewport %dx%d, ViewportTexture assigned to material" % [
		image.get_width(), image.get_height()
	])


func _process(delta: float) -> void:
	if not _is_painting or _subviewport == null:
		return
	if uv_source == null or not uv_source.has_cursor:
		return
	_stamp_timer -= delta
	if _stamp_timer <= 0.0:
		_stamp_timer += stamp_interval
		_place_stamp(uv_source.cursor_uv * Vector2(_subviewport.size))


# ── 3D viewport input ─────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.is_pressed():
		if uv_source != null and uv_source.has_cursor:
			_begin_stroke(uv_source.cursor_uv * Vector2(_subviewport.size))
	elif _is_painting:
		_end_stroke()


# ── Stroke lifecycle ──────────────────────────────────────────────────────────

func _begin_stroke(svp_pos: Vector2) -> void:
	for node in _redo_stack:
		node.queue_free()
	_redo_stack.clear()

	_active_stroke = Node2D.new()
	_active_stroke.name = "stroke_%03d" % _stroke_count
	_stroke_count += 1
	strokes_container.add_child(_active_stroke)

	_is_painting = true
	_stamp_timer = 0.0
	_place_stamp(svp_pos)
	print("[Brush] Stroke %s started" % _active_stroke.name)
	_update_buttons()


func _end_stroke() -> void:
	_is_painting = false
	if _active_stroke == null:
		return
	if _active_stroke.get_child_count() == 0:
		_active_stroke.queue_free()
		print("[Brush] Empty stroke discarded")
	else:
		_undo_stack.append(_active_stroke)
		_bake_counter += 1
		print("[Brush] Stroke %s committed (%d dabs) — bake in %d" % [
			_active_stroke.name,
			_active_stroke.get_child_count(),
			BAKE_EVERY - _bake_counter
		])
		if _bake_counter >= BAKE_EVERY and not _bake_pending:
			_do_bake()
	_active_stroke = null
	_update_buttons()


func _place_stamp(svp_pos: Vector2) -> void:
	if _active_stroke == null or brush_texture == null or _subviewport == null:
		return
	var dab := Sprite2D.new()
	dab.texture = brush_texture
	dab.position = svp_pos
	# Convert brush_size (display pixels) to SubViewport texture pixels.
	var svp_brush := brush_size * float(_subviewport.size.x) / _svc.size.x
	var tex_max := maxf(brush_texture.get_width(), brush_texture.get_height())
	dab.scale = Vector2.ONE * (svp_brush / tex_max)
	_active_stroke.add_child(dab)


# ── Undo / Redo ───────────────────────────────────────────────────────────────

func undo() -> void:
	if _undo_stack.is_empty():
		return
	var stroke: Node = _undo_stack.pop_back()
	strokes_container.remove_child(stroke)
	_redo_stack.append(stroke)
	print("[Brush] Undo — removed %s (undo: %d  redo: %d)" % [
		stroke.name, _undo_stack.size(), _redo_stack.size()
	])
	_update_buttons()


func redo() -> void:
	if _redo_stack.is_empty():
		return
	var stroke: Node = _redo_stack.pop_back()
	strokes_container.add_child(stroke)
	_undo_stack.append(stroke)
	print("[Brush] Redo — restored %s (undo: %d  redo: %d)" % [
		stroke.name, _undo_stack.size(), _redo_stack.size()
	])
	_update_buttons()


# ── Coordinate helpers ────────────────────────────────────────────────────────

## Map a display-pixel position on the SubViewportContainer to SubViewport
## world coordinates. Scales from canvas display resolution to texture resolution.
func _container_to_svp(local: Vector2) -> Vector2:
	if _svc == null or _subviewport == null:
		return Vector2.ZERO
	return local / _svc.size * Vector2(_subviewport.size)


## Position and size the canvas to exactly cover a target Control.
## Call deferred from the parent scene so layout has settled first.
func align_to(control: Control) -> void:
	if _svc == null:
		return
	_svc.global_position = control.global_position
	_svc.size = control.size
	print("[Brush] Aligned — position: %s  size: %s" % [
		str(_svc.global_position), str(_svc.size)
	])


func _do_bake() -> void:
	_bake_pending = true
	# Wait for the renderer to finish the current frame so the SubViewport
	# composite (base sprite + all strokes) is fully drawn before readback.
	await RenderingServer.frame_post_draw

	var img := _subviewport.get_texture().get_image()
	if img == null:
		push_error("[Brush] Bake failed — SubViewport returned null image")
		_bake_pending = false
		return

	# Guard: ensure the baked image is at the original texture resolution.
	# get_image() can occasionally return a different size depending on the
	# rendering configuration or viewport scaling.
	if img.get_size() != _texture_size:
		push_warning("[Brush] Bake size mismatch (%dx%d → %dx%d), resampling" % [
			img.get_width(), img.get_height(), _texture_size.x, _texture_size.y
		])
		img.resize(_texture_size.x, _texture_size.y, Image.INTERPOLATE_LANCZOS)

	# Replace the base sprite with the flattened image.
	_base_sprite.texture = ImageTexture.create_from_image(img)

	# Discard all stroke nodes — they are now part of the base layer.
	for child in strokes_container.get_children():
		child.queue_free()
	_undo_stack.clear()
	_redo_stack.clear()
	_bake_counter = 0
	_bake_pending = false
	_update_buttons()

	print("[Brush] Baked %d strokes into base texture — %dx%d" % [
		BAKE_EVERY, img.get_width(), img.get_height()
	])


func _update_buttons() -> void:
	undo_btn.disabled = _undo_stack.is_empty()
	redo_btn.disabled = _redo_stack.is_empty()
