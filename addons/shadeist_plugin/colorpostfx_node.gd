## Color-grading post-processing node for [Camera2D] and [Camera3D].
## [br][br]
## Provides photographic-style adjustments: Exposure, White Balance,
## Color Wheels (Lift/Gamma/Gain), HSL, tone Curves, and a Channel Mixer.
## Effects run in that order; each has its own opacity and blend mode.
## Disable effects you are not using to save GPU cost.
## [br][br]
## Attach as a direct child of a [Camera2D] or [Camera3D].
@tool
class_name ColorPostFX
extends "res://addons/shadeist_plugin/PostFX.gd"

func _get_shader_path() -> String:
	return "res://addons/shadeist_plugin/colorpostfx.gdshader"


# ─── Exposure ─────────────────────────────────────────────────────────────────

@export_group("Exposure", "exposure_")

## Enable or disable the Exposure effect.
@export var exposure_on: bool = false:
	set(v): exposure_on = v; _sp("exposure_on", v)

## Blend strength of the Exposure effect. At [code]1.0[/code] the result
## fully replaces the layer below; at [code]0.0[/code] the effect is invisible.
@export_range(0.0, 1.0) var exposure_opacity: float = 1.0:
	set(v): exposure_opacity = v; _sp("exposure_opacity", v)

## Blend mode used to composite the Exposure result onto the image below.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var exposure_blend: int = 0:
	set(v): exposure_blend = v; _sp("exposure_blend", v)

## Exposure in EV (exposure value) stops. [code]0.0[/code] is unchanged.
## Each [code]+1.0[/code] stop doubles brightness; each [code]-1.0[/code] stop halves it.
@export_range(-4.0, 4.0) var exposure_ev: float = 0.0:
	set(v): exposure_ev = v; _sp("exposure_ev", v)

## Gamma power applied after the EV adjustment. [code]1.0[/code] is unchanged.
## Values above [code]1.0[/code] lift midtones; below [code]1.0[/code] crush them.
@export_range(0.1, 5.0) var exposure_gamma: float = 1.0:
	set(v): exposure_gamma = v; _sp("exposure_gamma", v)

## S-curve contrast adjustment. [code]0.0[/code] is unchanged.
## Positive values push shadows darker and highlights brighter;
## negative values flatten the image toward grey.
@export_range(-1.0, 1.0) var exposure_contrast: float = 0.0:
	set(v): exposure_contrast = v; _sp("exposure_contrast", v)

# ─── White Balance ────────────────────────────────────────────────────────────

@export_group("White Balance", "wb_")

## Enable or disable White Balance.
@export var wb_on: bool = false:
	set(v): wb_on = v; _sp("wb_on", v)

## Blend strength of the White Balance effect.
@export_range(0.0, 1.0) var wb_opacity: float = 1.0:
	set(v): wb_opacity = v; _sp("wb_opacity", v)

## Blend mode used to composite the White Balance result.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var wb_blend: int = 0:
	set(v): wb_blend = v; _sp("wb_blend", v)

## Color temperature shift on the blue–yellow axis.
## Negative values cool the image toward blue; positive values warm it toward yellow/orange.
@export_range(-1.0, 1.0) var wb_temperature: float = 0.0:
	set(v): wb_temperature = v; _sp("wb_temperature", v)

## Tint correction on the green–magenta axis.
## Negative values shift toward green; positive values shift toward magenta.
@export_range(-1.0, 1.0) var wb_tint: float = 0.0:
	set(v): wb_tint = v; _sp("wb_tint", v)

# ─── Color Wheels ─────────────────────────────────────────────────────────────

@export_group("Color Wheels", "wheels_")

## Enable or disable the Color Wheels (Lift / Gamma / Gain).
@export var wheels_on: bool = false:
	set(v): wheels_on = v; _sp("wheels_on", v)

## Blend strength of the Color Wheels effect.
@export_range(0.0, 1.0) var wheels_opacity: float = 1.0:
	set(v): wheels_opacity = v; _sp("wheels_opacity", v)

## Blend mode used to composite the Color Wheels result.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var wheels_blend: int = 0:
	set(v): wheels_blend = v; _sp("wheels_blend", v)

## Shadow tint wheel (Lift). RGB sets the tint direction; Alpha sets the
## overall strength. Neutral is [code](0.5, 0.5, 0.5, 1.0)[/code] — no shift.
## Dark areas of the image are affected most; bright areas are untouched.
@export var wheels_lift: Color = Color(0.5, 0.5, 0.5, 1.0):
	set(v): wheels_lift = v; _sp("wheels_lift", v)

## Midtone tint wheel (Gamma). RGB sets the tint direction; Alpha sets the
## overall strength. Neutral is [code](0.5, 0.5, 0.5, 1.0)[/code].
## Applied as a per-channel power curve targeting midtones.
@export var wheels_gamma: Color = Color(0.5, 0.5, 0.5, 1.0):
	set(v): wheels_gamma = v; _sp("wheels_gamma", v)

## Highlight tint wheel (Gain). RGB sets the tint direction; Alpha sets the
## overall strength. Neutral is [code](0.5, 0.5, 0.5, 1.0)[/code].
## Bright areas of the image are affected most; shadows are untouched.
@export var wheels_gain: Color = Color(0.5, 0.5, 0.5, 1.0):
	set(v): wheels_gain = v; _sp("wheels_gain", v)

# ─── HSL ──────────────────────────────────────────────────────────────────────

@export_group("HSL", "hsl_")

## Enable or disable HSL (Hue / Saturation / Lightness) adjustments.
@export var hsl_on: bool = false:
	set(v): hsl_on = v; _sp("hsl_on", v)

## Blend strength of the HSL effect.
@export_range(0.0, 1.0) var hsl_opacity: float = 1.0:
	set(v): hsl_opacity = v; _sp("hsl_opacity", v)

## Blend mode used to composite the HSL result.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var hsl_blend: int = 0:
	set(v): hsl_blend = v; _sp("hsl_blend", v)

## Global hue rotation in degrees. [code]0[/code] is unchanged.
## [code]±180[/code] fully inverts all hues.
@export_range(-180.0, 180.0) var hsl_hue: float = 0.0:
	set(v): hsl_hue = v; _sp("hsl_hue", v)

## Saturation multiplier. [code]1.0[/code] is unchanged. [code]0.0[/code] is
## grayscale. Values above [code]1.0[/code] over-saturate the image.
@export_range(0.0, 3.0) var hsl_saturation: float = 1.0:
	set(v): hsl_saturation = v; _sp("hsl_saturation", v)

## Lightness offset added to every pixel. [code]0.0[/code] is unchanged.
## Positive values brighten; negative values darken.
@export_range(-1.0, 1.0) var hsl_lightness: float = 0.0:
	set(v): hsl_lightness = v; _sp("hsl_lightness", v)

## Smart saturation boost that scales inversely with existing saturation.
## Already-vivid colours are protected while desaturated areas receive a
## stronger push — unlike [member hsl_saturation] which affects all colours equally.
@export_range(-1.0, 1.0) var hsl_vibrance: float = 0.0:
	set(v): hsl_vibrance = v; _sp("hsl_vibrance", v)

# ─── Curves ───────────────────────────────────────────────────────────────────

@export_group("Curves", "curves_")

## Enable or disable tone Curves.
@export var curves_on: bool = false:
	set(v): curves_on = v; _sp("curves_on", v)

## Blend strength of the Curves effect.
@export_range(0.0, 1.0) var curves_opacity: float = 1.0:
	set(v): curves_opacity = v; _sp("curves_opacity", v)

## Blend mode used to composite the Curves result.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var curves_blend: int = 0:
	set(v): curves_blend = v; _sp("curves_blend", v)

## Master curve — output level for the shadow input (x=0).
## [code]0.0[/code] = black point unchanged (default).
@export_range(0.0, 1.0) var curves_master_shadows: float = 0.0:
	set(v): curves_master_shadows = v; _sp("curves_master_shadows", v)

## Master curve — output level for the midtone input (x=0.5).
## [code]0.5[/code] = identity. Raise to brighten midtones; lower to darken them.
@export_range(0.0, 1.0) var curves_master_midtones: float = 0.5:
	set(v): curves_master_midtones = v; _sp("curves_master_midtones", v)

## Master curve — output level for the highlight input (x=1).
## [code]1.0[/code] = white point unchanged (default).
@export_range(0.0, 1.0) var curves_master_highlights: float = 1.0:
	set(v): curves_master_highlights = v; _sp("curves_master_highlights", v)

## Red curve — shadow output. Applied after the master curve.
@export_range(0.0, 1.0) var curves_r_shadows: float = 0.0:
	set(v): curves_r_shadows = v; _sp("curves_r_shadows", v)

## Red curve — midtone output. Applied after the master curve.
@export_range(0.0, 1.0) var curves_r_midtones: float = 0.5:
	set(v): curves_r_midtones = v; _sp("curves_r_midtones", v)

## Red curve — highlight output. Applied after the master curve.
@export_range(0.0, 1.0) var curves_r_highlights: float = 1.0:
	set(v): curves_r_highlights = v; _sp("curves_r_highlights", v)

## Green curve — shadow output. Applied after the master curve.
@export_range(0.0, 1.0) var curves_g_shadows: float = 0.0:
	set(v): curves_g_shadows = v; _sp("curves_g_shadows", v)

## Green curve — midtone output. Applied after the master curve.
@export_range(0.0, 1.0) var curves_g_midtones: float = 0.5:
	set(v): curves_g_midtones = v; _sp("curves_g_midtones", v)

## Green curve — highlight output. Applied after the master curve.
@export_range(0.0, 1.0) var curves_g_highlights: float = 1.0:
	set(v): curves_g_highlights = v; _sp("curves_g_highlights", v)

## Blue curve — shadow output. Applied after the master curve.
@export_range(0.0, 1.0) var curves_b_shadows: float = 0.0:
	set(v): curves_b_shadows = v; _sp("curves_b_shadows", v)

## Blue curve — midtone output. Applied after the master curve.
@export_range(0.0, 1.0) var curves_b_midtones: float = 0.5:
	set(v): curves_b_midtones = v; _sp("curves_b_midtones", v)

## Blue curve — highlight output. Applied after the master curve.
@export_range(0.0, 1.0) var curves_b_highlights: float = 1.0:
	set(v): curves_b_highlights = v; _sp("curves_b_highlights", v)

# ─── Mixer ────────────────────────────────────────────────────────────────────

@export_group("Mixer", "mixer_")

## Enable or disable the Channel Mixer.
@export var mixer_on: bool = false:
	set(v): mixer_on = v; _sp("mixer_on", v)

## Blend strength of the Channel Mixer effect.
@export_range(0.0, 1.0) var mixer_opacity: float = 1.0:
	set(v): mixer_opacity = v; _sp("mixer_opacity", v)

## Blend mode used to composite the Channel Mixer result.
@export_enum("Normal", "Multiply", "Screen", "Overlay", "Add", "Subtract") var mixer_blend: int = 0:
	set(v): mixer_blend = v; _sp("mixer_blend", v)

## Contribution of the input [b]Red[/b] channel to the output [b]Red[/b] channel.
## [code]1.0[/code] = passthrough (default).
@export_range(-2.0, 2.0) var mixer_rr: float = 1.0:
	set(v): mixer_rr = v; _sp("mixer_rr", v)

## Contribution of the input [b]Green[/b] channel to the output [b]Red[/b] channel.
## [code]0.0[/code] = no contribution (default).
@export_range(-2.0, 2.0) var mixer_rg: float = 0.0:
	set(v): mixer_rg = v; _sp("mixer_rg", v)

## Contribution of the input [b]Blue[/b] channel to the output [b]Red[/b] channel.
## [code]0.0[/code] = no contribution (default).
@export_range(-2.0, 2.0) var mixer_rb: float = 0.0:
	set(v): mixer_rb = v; _sp("mixer_rb", v)

## Contribution of the input [b]Red[/b] channel to the output [b]Green[/b] channel.
## [code]0.0[/code] = no contribution (default).
@export_range(-2.0, 2.0) var mixer_gr: float = 0.0:
	set(v): mixer_gr = v; _sp("mixer_gr", v)

## Contribution of the input [b]Green[/b] channel to the output [b]Green[/b] channel.
## [code]1.0[/code] = passthrough (default).
@export_range(-2.0, 2.0) var mixer_gg: float = 1.0:
	set(v): mixer_gg = v; _sp("mixer_gg", v)

## Contribution of the input [b]Blue[/b] channel to the output [b]Green[/b] channel.
## [code]0.0[/code] = no contribution (default).
@export_range(-2.0, 2.0) var mixer_gb: float = 0.0:
	set(v): mixer_gb = v; _sp("mixer_gb", v)

## Contribution of the input [b]Red[/b] channel to the output [b]Blue[/b] channel.
## [code]0.0[/code] = no contribution (default).
@export_range(-2.0, 2.0) var mixer_br: float = 0.0:
	set(v): mixer_br = v; _sp("mixer_br", v)

## Contribution of the input [b]Green[/b] channel to the output [b]Blue[/b] channel.
## [code]0.0[/code] = no contribution (default).
@export_range(-2.0, 2.0) var mixer_bg: float = 0.0:
	set(v): mixer_bg = v; _sp("mixer_bg", v)

## Contribution of the input [b]Blue[/b] channel to the output [b]Blue[/b] channel.
## [code]1.0[/code] = passthrough (default).
@export_range(-2.0, 2.0) var mixer_bb: float = 1.0:
	set(v): mixer_bb = v; _sp("mixer_bb", v)

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
	_sp("exposure_on",               exposure_on)
	_sp("exposure_opacity",          exposure_opacity)
	_sp("exposure_blend",            exposure_blend)
	_sp("exposure_ev",               exposure_ev)
	_sp("exposure_gamma",            exposure_gamma)
	_sp("exposure_contrast",         exposure_contrast)
	_sp("wb_on",                     wb_on)
	_sp("wb_opacity",                wb_opacity)
	_sp("wb_blend",                  wb_blend)
	_sp("wb_temperature",            wb_temperature)
	_sp("wb_tint",                   wb_tint)
	_sp("wheels_on",                 wheels_on)
	_sp("wheels_opacity",            wheels_opacity)
	_sp("wheels_blend",              wheels_blend)
	_sp("wheels_lift",               wheels_lift)
	_sp("wheels_gamma",              wheels_gamma)
	_sp("wheels_gain",               wheels_gain)
	_sp("hsl_on",                    hsl_on)
	_sp("hsl_opacity",               hsl_opacity)
	_sp("hsl_blend",                 hsl_blend)
	_sp("hsl_hue",                   hsl_hue)
	_sp("hsl_saturation",            hsl_saturation)
	_sp("hsl_lightness",             hsl_lightness)
	_sp("hsl_vibrance",              hsl_vibrance)
	_sp("curves_on",                 curves_on)
	_sp("curves_opacity",            curves_opacity)
	_sp("curves_blend",              curves_blend)
	_sp("curves_master_shadows",     curves_master_shadows)
	_sp("curves_master_midtones",    curves_master_midtones)
	_sp("curves_master_highlights",  curves_master_highlights)
	_sp("curves_r_shadows",          curves_r_shadows)
	_sp("curves_r_midtones",         curves_r_midtones)
	_sp("curves_r_highlights",       curves_r_highlights)
	_sp("curves_g_shadows",          curves_g_shadows)
	_sp("curves_g_midtones",         curves_g_midtones)
	_sp("curves_g_highlights",       curves_g_highlights)
	_sp("curves_b_shadows",          curves_b_shadows)
	_sp("curves_b_midtones",         curves_b_midtones)
	_sp("curves_b_highlights",       curves_b_highlights)
	_sp("mixer_on",                  mixer_on)
	_sp("mixer_opacity",             mixer_opacity)
	_sp("mixer_blend",               mixer_blend)
	_sp("mixer_rr",                  mixer_rr)
	_sp("mixer_rg",                  mixer_rg)
	_sp("mixer_rb",                  mixer_rb)
	_sp("mixer_gr",                  mixer_gr)
	_sp("mixer_gg",                  mixer_gg)
	_sp("mixer_gb",                  mixer_gb)
	_sp("mixer_br",                  mixer_br)
	_sp("mixer_bg",                  mixer_bg)
	_sp("mixer_bb",                  mixer_bb)
	_sp("debug_corners",             debug_corners)
	_sp("debug_corner_color",        debug_corner_color)
	_sp("debug_arm_length",          debug_arm_length)
	_sp("debug_thickness",           debug_thickness)
	_sp("debug_pivot",               debug_pivot)
	_sp("debug_pivot_color",         debug_pivot_color)
	_sp("debug_pivot_size",          debug_pivot_size)
	_sp("debug_pivot_thickness",     debug_pivot_thickness)
