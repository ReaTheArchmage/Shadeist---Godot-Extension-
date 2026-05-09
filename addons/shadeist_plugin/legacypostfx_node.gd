## Legacy post-processing effects node for [Camera2D] and [Camera3D].
## [br][br]
## Provides classic real-time visual effects: Pixelation, Chromatic Aberration,
## Blur, Color Correction, Bloom, Scanlines, Film Grain, Vignette, and Color Tint.
## A global Quality setting scales sample counts across all multi-tap effects
## to balance visual quality against GPU cost.
## [br][br]
## Attach as a direct child of a [Camera2D] or [Camera3D].
@tool
class_name LegacyPostFX
extends "res://addons/shadeist_plugin/PostFX.gd"

func _get_shader_path() -> String:
	return "res://addons/shadeist_plugin/legacypostfx.gdshader"


# ─── Quality ──────────────────────────────────────────────────────────────────

## Overall render quality tier. Scales sample counts for Blur, Bloom, and
## Chromatic Aberration and toggles per-effect optimisations.
## [br]
## [b]Very Low[/b] — 5-tap blur/bloom, 2-sample chroma, step scanlines, linear vignette, hue skipped.[br]
## [b]Low[/b] — 5-tap, all per-effect math enabled.[br]
## [b]Mid[/b] — 9-tap 3×3 Gaussian, 3-sample chroma with green shift (default).[br]
## [b]High[/b] — 13-tap with approximate Gaussian weights.[br]
## [b]Very High[/b] — 13-tap with accurate Gaussian (σ=1) weights.
@export_enum("Very Low", "Low", "Mid", "High", "Very High") var quality: int = 2:
	set(v): quality = v; _sp("quality", v)

# ─── Legacy Effects ───────────────────────────────────────────────────────────

@export_group("Pixelation", "pixel_")

## Enable or disable the Pixelation effect.
@export var pixel_on: bool = false:
	set(v): pixel_on = v; _sp("pixel_on", v)

## Blend strength of the Pixelation effect.
@export_range(0.0, 1.0) var pixel_opacity: float = 1.0:
	set(v): pixel_opacity = v; _sp("pixel_opacity", v)

## Blend mode used to composite the Pixelation result.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var pixel_blend: int = 0:
	set(v): pixel_blend = v; _sp("pixel_blend", v)

## Width and height of each pixel block in screen pixels.
## Higher values produce a coarser, more retro look.
@export_range(1.0, 64.0) var pixel_size: float = 6.0:
	set(v): pixel_size = v; _sp("pixel_size", v)

@export_group("Chromatic Aberration", "chroma_")

## Enable or disable Chromatic Aberration.
@export var chroma_on: bool = false:
	set(v): chroma_on = v; _sp("chroma_on", v)

## Blend strength of the Chromatic Aberration effect.
@export_range(0.0, 1.0) var chroma_opacity: float = 1.0:
	set(v): chroma_opacity = v; _sp("chroma_opacity", v)

## Blend mode used to composite the Chromatic Aberration result.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var chroma_blend: int = 0:
	set(v): chroma_blend = v; _sp("chroma_blend", v)

## Horizontal separation distance between the R and B channels in UV space.
## Larger values create a stronger lens-fringe appearance.
## At [b]Mid[/b] quality and above, the G channel is also shifted slightly.
@export_range(0.0, 0.02) var chroma_size: float = 0.003:
	set(v): chroma_size = v; _sp("chroma_size", v)

@export_group("Blur", "blur_")

## Enable or disable Gaussian Blur.
@export var blur_on: bool = false:
	set(v): blur_on = v; _sp("blur_on", v)

## Blend strength of the Blur effect.
@export_range(0.0, 1.0) var blur_opacity: float = 1.0:
	set(v): blur_opacity = v; _sp("blur_opacity", v)

## Blend mode used to composite the Blur result.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var blur_blend: int = 0:
	set(v): blur_blend = v; _sp("blur_blend", v)

## Blur radius in pixels. The number of texture samples scales with the
## [member quality] setting: 5-tap at Very Low/Low, 9-tap at Mid, 13-tap at High/Very High.
@export_range(0.0, 10.0) var blur_size: float = 2.0:
	set(v): blur_size = v; _sp("blur_size", v)

@export_group("Color Correction", "colorcorrect_")

## Enable or disable basic Color Correction (brightness, contrast, saturation, hue).
@export var colorcorrect_on: bool = false:
	set(v): colorcorrect_on = v; _sp("colorcorrect_on", v)

## Blend strength of the Color Correction effect.
@export_range(0.0, 1.0) var colorcorrect_opacity: float = 1.0:
	set(v): colorcorrect_opacity = v; _sp("colorcorrect_opacity", v)

## Blend mode used to composite the Color Correction result.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var colorcorrect_blend: int = 0:
	set(v): colorcorrect_blend = v; _sp("colorcorrect_blend", v)

## Additive brightness offset. [code]0.0[/code] is unchanged.
## Positive values brighten the whole image; negative values darken it.
@export_range(-1.0, 1.0) var colorcorrect_brightness: float = 0.0:
	set(v): colorcorrect_brightness = v; _sp("brightness", v)

## Contrast multiplier around the midpoint. [code]1.0[/code] is unchanged.
## Values above [code]1.0[/code] push brights and darks further apart;
## below [code]1.0[/code] compresses the range toward grey.
@export_range(0.0, 3.0) var colorcorrect_contrast: float = 1.0:
	set(v): colorcorrect_contrast = v; _sp("contrast", v)

## Saturation multiplier. [code]1.0[/code] is unchanged. [code]0.0[/code] is grayscale.
## Values above [code]1.0[/code] over-saturate all colours.
@export_range(0.0, 3.0) var colorcorrect_saturation: float = 1.0:
	set(v): colorcorrect_saturation = v; _sp("saturation", v)

## Hue rotation in degrees. [code]0[/code] is unchanged; [code]±180[/code] inverts all hues.
## [b]Note:[/b] Skipped at the [b]Very Low[/b] quality setting to reduce GPU cost.
@export_range(-180.0, 180.0) var colorcorrect_hue_shift: float = 0.0:
	set(v): colorcorrect_hue_shift = v; _sp("hue_shift", v)

@export_group("Bloom", "bloom_")

## Enable or disable Bloom.
@export var bloom_on: bool = false:
	set(v): bloom_on = v; _sp("bloom_on", v)

## Blend strength of the Bloom effect.
@export_range(0.0, 1.0) var bloom_opacity: float = 0.5:
	set(v): bloom_opacity = v; _sp("bloom_opacity", v)

## Blend mode used to composite the Bloom result. Defaults to [b]Add[/b] so
## the glow naturally brightens the image without changing its hue.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var bloom_blend: int = 4:
	set(v): bloom_blend = v; _sp("bloom_blend", v)

## Luminance threshold above which pixels contribute to the bloom glow.
## [code]0.0[/code] makes every pixel bloom; [code]1.0[/code] limits bloom to pure white only.
@export_range(0.0, 1.0) var bloom_threshold: float = 0.65:
	set(v): bloom_threshold = v; _sp("bloom_threshold", v)

## Spread radius of the bloom glow in pixels. Sample count scales with the
## [member quality] setting: 5-tap at Very Low/Low, 9-tap at Mid, 13-tap at High/Very High.
@export_range(0.5, 8.0) var bloom_size: float = 2.5:
	set(v): bloom_size = v; _sp("bloom_size", v)

@export_group("Scanlines", "scan_")

## Enable or disable animated Scanlines.
@export var scan_on: bool = false:
	set(v): scan_on = v; _sp("scan_on", v)

## Blend strength of the Scanlines effect.
@export_range(0.0, 1.0) var scan_opacity: float = 0.3:
	set(v): scan_opacity = v; _sp("scan_opacity", v)

## Blend mode used to composite the Scanlines result. Defaults to [b]Multiply[/b]
## so the lines darken the image rather than adding colour.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var scan_blend: int = 1:
	set(v): scan_blend = v; _sp("scan_blend", v)

## Vertical scroll speed. Positive values scroll downward; negative scroll upward.
## [code]0[/code] produces static, non-moving lines.
## [b]Note:[/b] At [b]Very Low[/b] quality, scanlines use step-based hard edges instead of sine waves.
@export_range(-5.0, 5.0) var scan_speed: float = 0.5:
	set(v): scan_speed = v; _sp("scan_speed", v)

## Distance between scanline bands in screen pixels.
## Larger values produce thicker, more widely spaced lines.
@export_range(1.0, 32.0) var scan_size: float = 3.0:
	set(v): scan_size = v; _sp("scan_size", v)

@export_group("Film Grain", "grain_")

## Enable or disable animated Film Grain.
@export var grain_on: bool = false:
	set(v): grain_on = v; _sp("grain_on", v)

## Blend strength of the Film Grain effect.
@export_range(0.0, 1.0) var grain_opacity: float = 0.15:
	set(v): grain_opacity = v; _sp("grain_opacity", v)

## Blend mode used to composite the Film Grain result. Defaults to [b]Overlay[/b]
## so grain affects both bright and dark areas naturally.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var grain_blend: int = 3:
	set(v): grain_blend = v; _sp("grain_blend", v)

## Animation speed of the grain. Higher values refresh the noise pattern faster,
## producing a more active, film-like flutter.
@export_range(0.0, 30.0) var grain_speed: float = 10.0:
	set(v): grain_speed = v; _sp("grain_speed", v)

## Size of each individual grain cell in screen pixels.
## [code]1.0[/code] = one cell per screen pixel. Larger values produce chunkier grain.
@export_range(0.5, 8.0) var grain_size: float = 1.0:
	set(v): grain_size = v; _sp("grain_size", v)

@export_group("Vignette", "vignette_")

## Enable or disable the Vignette darkening effect.
@export var vignette_on: bool = false:
	set(v): vignette_on = v; _sp("vignette_on", v)

## Blend strength of the Vignette effect.
@export_range(0.0, 1.0) var vignette_opacity: float = 0.7:
	set(v): vignette_opacity = v; _sp("vignette_opacity", v)

## Blend mode used to composite the Vignette result.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var vignette_blend: int = 0:
	set(v): vignette_blend = v; _sp("vignette_blend", v)

## Radius of the vignette oval. Lower values tighten the dark ring toward the
## centre; higher values push it toward the screen edges.
@export_range(0.1, 2.0) var vignette_size: float = 1.0:
	set(v): vignette_size = v; _sp("vignette_size", v)

## Edge softness of the vignette falloff. [code]0.0[/code] = hard edge.
## [code]1.0[/code] = very gradual fade.
## [b]Note:[/b] Ignored at [b]Very Low[/b] quality; a linear falloff is used instead.
@export_range(0.0, 1.0) var vignette_softness: float = 0.45:
	set(v): vignette_softness = v; _sp("vignette_softness", v)

@export_group("Color Tint", "tint_")

## Enable or disable the Color Tint overlay.
@export var tint_on: bool = false:
	set(v): tint_on = v; _sp("tint_on", v)

## Blend strength of the Color Tint effect.
@export_range(0.0, 1.0) var tint_opacity: float = 0.4:
	set(v): tint_opacity = v; _sp("tint_opacity", v)

## Blend mode used to composite the Color Tint result. Defaults to [b]Multiply[/b]
## so the tint naturally preserves image detail and contrast.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var tint_blend: int = 1:
	set(v): tint_blend = v; _sp("tint_blend", v)

## The tint colour multiplied over the scene. Alpha is ignored; use
## [member tint_opacity] to control overall strength.
@export var tint_color: Color = Color(1.0, 0.85, 0.65, 1.0):
	set(v): tint_color = v; _sp("tint_color", v)

# ─── Debug ────────────────────────────────────────────────────────────────────

@export_group("Debug")

## Draw corner bracket markers to verify the shader rect covers the full viewport.
## Useful for confirming correct placement on unusual display configurations.
@export var debug_corners: bool = false:
	set(v): debug_corners = v; _sp("debug_corners", v)

## Color of the corner bracket markers.
@export var debug_corner_color: Color = Color(1.0, 0.2, 0.0, 1.0):
	set(v): debug_corner_color = v; _sp("debug_corner_color", v)

## Length of each corner bracket arm in normalised screen space (0–1).
@export_range(0.01, 0.2) var debug_arm_length: float = 0.06:
	set(v): debug_arm_length = v; _sp("debug_arm_length", v)

## Thickness of the corner bracket lines in normalised screen space.
@export_range(0.001, 0.05) var debug_thickness: float = 0.005:
	set(v): debug_thickness = v; _sp("debug_thickness", v)

## Draw a crosshair at the exact screen centre to verify pivot alignment.
@export var debug_pivot: bool = false:
	set(v): debug_pivot = v; _sp("debug_pivot", v)

## Color of the centre crosshair.
@export var debug_pivot_color: Color = Color(0.0, 1.0, 0.5, 1.0):
	set(v): debug_pivot_color = v; _sp("debug_pivot_color", v)

## Arm length of the centre crosshair in normalised screen space.
@export_range(0.005, 0.15) var debug_pivot_size: float = 0.03:
	set(v): debug_pivot_size = v; _sp("debug_pivot_size", v)

## Line thickness of the centre crosshair in normalised screen space.
@export_range(0.001, 0.02) var debug_pivot_thickness: float = 0.003:
	set(v): debug_pivot_thickness = v; _sp("debug_pivot_thickness", v)


# ─── Sync ─────────────────────────────────────────────────────────────────────

func _sync_all() -> void:
	super._sync_all()
	_sp("quality",              quality)
	_sp("pixel_on",             pixel_on)
	_sp("pixel_opacity",        pixel_opacity)
	_sp("pixel_blend",          pixel_blend)
	_sp("pixel_size",           pixel_size)
	_sp("chroma_on",            chroma_on)
	_sp("chroma_opacity",       chroma_opacity)
	_sp("chroma_blend",         chroma_blend)
	_sp("chroma_size",          chroma_size)
	_sp("blur_on",              blur_on)
	_sp("blur_opacity",         blur_opacity)
	_sp("blur_blend",           blur_blend)
	_sp("blur_size",            blur_size)
	_sp("colorcorrect_on",      colorcorrect_on)
	_sp("colorcorrect_opacity", colorcorrect_opacity)
	_sp("colorcorrect_blend",   colorcorrect_blend)
	_sp("brightness",           colorcorrect_brightness)
	_sp("contrast",             colorcorrect_contrast)
	_sp("saturation",           colorcorrect_saturation)
	_sp("hue_shift",            colorcorrect_hue_shift)
	_sp("bloom_on",             bloom_on)
	_sp("bloom_opacity",        bloom_opacity)
	_sp("bloom_blend",          bloom_blend)
	_sp("bloom_threshold",      bloom_threshold)
	_sp("bloom_size",           bloom_size)
	_sp("scan_on",              scan_on)
	_sp("scan_opacity",         scan_opacity)
	_sp("scan_blend",           scan_blend)
	_sp("scan_speed",           scan_speed)
	_sp("scan_size",            scan_size)
	_sp("grain_on",             grain_on)
	_sp("grain_opacity",        grain_opacity)
	_sp("grain_blend",          grain_blend)
	_sp("grain_speed",          grain_speed)
	_sp("grain_size",           grain_size)
	_sp("vignette_on",          vignette_on)
	_sp("vignette_opacity",     vignette_opacity)
	_sp("vignette_blend",       vignette_blend)
	_sp("vignette_size",        vignette_size)
	_sp("vignette_softness",    vignette_softness)
	_sp("tint_on",              tint_on)
	_sp("tint_opacity",         tint_opacity)
	_sp("tint_blend",           tint_blend)
	_sp("tint_color",           tint_color)
	_sp("debug_corners",        debug_corners)
	_sp("debug_corner_color",   debug_corner_color)
	_sp("debug_arm_length",     debug_arm_length)
	_sp("debug_thickness",      debug_thickness)
	_sp("debug_pivot",          debug_pivot)
	_sp("debug_pivot_color",    debug_pivot_color)
	_sp("debug_pivot_size",     debug_pivot_size)
	_sp("debug_pivot_thickness",debug_pivot_thickness)
