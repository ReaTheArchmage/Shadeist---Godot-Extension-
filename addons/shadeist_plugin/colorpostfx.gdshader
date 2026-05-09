shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

// ── Blend utility ─────────────────────────────────────────────────────────────
// Blend modes: 0=Normal  1=Multiply  2=Screen  3=Overlay  4=Add  5=Subtract
vec3 blend_layer(vec3 base, vec3 layer, int mode, float opacity) {
	vec3 r;
	if      (mode == 1) r = base * layer;
	else if (mode == 2) r = 1.0 - (1.0 - base) * (1.0 - layer);
	else if (mode == 3) r = mix(2.0 * base * layer,
	                            1.0 - 2.0 * (1.0 - base) * (1.0 - layer),
	                            step(0.5, base));
	else if (mode == 4) r = clamp(base + layer, 0.0, 1.0);
	else if (mode == 5) r = clamp(base - layer, 0.0, 1.0);
	else                r = layer;
	return mix(base, r, opacity);
}

// ── HSL conversion ────────────────────────────────────────────────────────────
float _hue_to_rgb(float p, float q, float t) {
	if (t < 0.0) t += 1.0;
	if (t > 1.0) t -= 1.0;
	if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
	if (t < 0.5)        return q;
	if (t < 2.0 / 3.0)  return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
	return p;
}

vec3 rgb_to_hsl(vec3 c) {
	float mx = max(max(c.r, c.g), c.b);
	float mn = min(min(c.r, c.g), c.b);
	float d  = mx - mn;
	float l  = (mx + mn) * 0.5;
	float h  = 0.0;
	float s  = 0.0;
	if (d > 0.0001) {
		s = l > 0.5 ? d / (2.0 - mx - mn) : d / (mx + mn);
		if      (mx == c.r) h = (c.g - c.b) / d + (c.g < c.b ? 6.0 : 0.0);
		else if (mx == c.g) h = (c.b - c.r) / d + 2.0;
		else                h = (c.r - c.g) / d + 4.0;
		h /= 6.0;
	}
	return vec3(h, s, l);
}

vec3 hsl_to_rgb(vec3 hsl) {
	float h = hsl.x, s = hsl.y, l = hsl.z;
	if (s < 0.0001) return vec3(l);
	float q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
	float p = 2.0 * l - q;
	return vec3(
		_hue_to_rgb(p, q, h + 1.0 / 3.0),
		_hue_to_rgb(p, q, h),
		_hue_to_rgb(p, q, h - 1.0 / 3.0)
	);
}

// ── Tone curve ────────────────────────────────────────────────────────────────
// Quadratic bezier guaranteed to pass through (0,sh), (0.5,mid), (1,hi).
// At neutral (sh=0, mid=0.5, hi=1) the curve is the identity y=x.
float apply_curve(float x, float sh, float mid, float hi) {
	float ctrl = 2.0 * mid - 0.5 * (sh + hi);
	float mt   = 1.0 - x;
	return clamp(mt * mt * sh + 2.0 * mt * x * ctrl + x * x * hi, 0.0, 1.0);
}

// ── Global ────────────────────────────────────────────────────────────────────
uniform float global_opacity : hint_range(0.0, 1.0) = 1.0;
uniform int   global_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;

// ══════════════════════════════════════════════════════════════════════════════
// EXPOSURE
// Overall brightness in EV stops, gamma power, and S-curve contrast.
// ══════════════════════════════════════════════════════════════════════════════
group_uniforms Exposure;
uniform bool  exposure_on      = false;
uniform float exposure_opacity : hint_range(0.0, 1.0) = 1.0;
uniform int   exposure_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform float exposure_ev       : hint_range(-4.0, 4.0) = 0.0;
uniform float exposure_gamma    : hint_range(0.1, 5.0) = 1.0;
uniform float exposure_contrast : hint_range(-1.0, 1.0) = 0.0;
group_uniforms;

// ══════════════════════════════════════════════════════════════════════════════
// WHITE BALANCE
// Temperature slides cool (blue) ↔ warm (yellow).
// Tint slides green ↔ magenta.
// ══════════════════════════════════════════════════════════════════════════════
group_uniforms WhiteBalance;
uniform bool  wb_on      = false;
uniform float wb_opacity : hint_range(0.0, 1.0) = 1.0;
uniform int   wb_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform float wb_temperature : hint_range(-1.0, 1.0) = 0.0;
uniform float wb_tint        : hint_range(-1.0, 1.0) = 0.0;
group_uniforms;

// ══════════════════════════════════════════════════════════════════════════════
// COLOR WHEELS  (Lift / Gamma / Gain)
// Each wheel is a source_color vec4: RGB sets the tint direction, A the strength.
// Neutral is (0.5, 0.5, 0.5, 1.0) — center of the wheel, no colour shift.
//
//   Lift  → shadows (dark regions pulled toward the chosen colour)
//   Gamma → midtones (power-curve per-channel push)
//   Gain  → highlights (bright regions scaled toward the chosen colour)
// ══════════════════════════════════════════════════════════════════════════════
group_uniforms ColorWheels;
uniform bool  wheels_on      = false;
uniform float wheels_opacity : hint_range(0.0, 1.0) = 1.0;
uniform int   wheels_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform vec4  wheels_lift  : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4  wheels_gamma : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4  wheels_gain  : source_color = vec4(0.5, 0.5, 0.5, 1.0);
group_uniforms;

// ══════════════════════════════════════════════════════════════════════════════
// HSL
// Hue shift, saturation multiplier, lightness offset, and vibrance
// (vibrance is smart saturation — affects already-desaturated pixels more).
// ══════════════════════════════════════════════════════════════════════════════
group_uniforms HSL;
uniform bool  hsl_on      = false;
uniform float hsl_opacity : hint_range(0.0, 1.0) = 1.0;
uniform int   hsl_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform float hsl_hue        : hint_range(-180.0, 180.0) = 0.0;
uniform float hsl_saturation : hint_range(0.0, 3.0) = 1.0;
uniform float hsl_lightness  : hint_range(-1.0, 1.0) = 0.0;
uniform float hsl_vibrance   : hint_range(-1.0, 1.0) = 0.0;
group_uniforms;

// ══════════════════════════════════════════════════════════════════════════════
// CURVES
// Four independent tone curves (Master, R, G, B), each defined by three
// control points — shadows (x=0), midtones (x=0.5), highlights (x=1) —
// whose Y values are adjustable.  Default (0, 0.5, 1) is the identity line.
// Master curve is applied first, then per-channel curves on top.
// ══════════════════════════════════════════════════════════════════════════════
group_uniforms Curves;
uniform bool  curves_on      = false;
uniform float curves_opacity : hint_range(0.0, 1.0) = 1.0;
uniform int   curves_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform float curves_master_shadows    : hint_range(0.0, 1.0) = 0.0;
uniform float curves_master_midtones   : hint_range(0.0, 1.0) = 0.5;
uniform float curves_master_highlights : hint_range(0.0, 1.0) = 1.0;
uniform float curves_r_shadows    : hint_range(0.0, 1.0) = 0.0;
uniform float curves_r_midtones   : hint_range(0.0, 1.0) = 0.5;
uniform float curves_r_highlights : hint_range(0.0, 1.0) = 1.0;
uniform float curves_g_shadows    : hint_range(0.0, 1.0) = 0.0;
uniform float curves_g_midtones   : hint_range(0.0, 1.0) = 0.5;
uniform float curves_g_highlights : hint_range(0.0, 1.0) = 1.0;
uniform float curves_b_shadows    : hint_range(0.0, 1.0) = 0.0;
uniform float curves_b_midtones   : hint_range(0.0, 1.0) = 0.5;
uniform float curves_b_highlights : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

// ══════════════════════════════════════════════════════════════════════════════
// CHANNEL MIXER
// Each output channel is a weighted sum of the three input channels.
// Default is the identity matrix (rr=1, rg=0, rb=0, etc.).
// ══════════════════════════════════════════════════════════════════════════════
group_uniforms Mixer;
uniform bool  mixer_on      = false;
uniform float mixer_opacity : hint_range(0.0, 1.0) = 1.0;
uniform int   mixer_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform float mixer_rr : hint_range(-2.0, 2.0) = 1.0;
uniform float mixer_rg : hint_range(-2.0, 2.0) = 0.0;
uniform float mixer_rb : hint_range(-2.0, 2.0) = 0.0;
uniform float mixer_gr : hint_range(-2.0, 2.0) = 0.0;
uniform float mixer_gg : hint_range(-2.0, 2.0) = 1.0;
uniform float mixer_gb : hint_range(-2.0, 2.0) = 0.0;
uniform float mixer_br : hint_range(-2.0, 2.0) = 0.0;
uniform float mixer_bg : hint_range(-2.0, 2.0) = 0.0;
uniform float mixer_bb : hint_range(-2.0, 2.0) = 1.0;
group_uniforms;

// ══════════════════════════════════════════════════════════════════════════════
// DEBUG
// ══════════════════════════════════════════════════════════════════════════════
group_uniforms Debug;
uniform bool  debug_corners         = false;
uniform vec4  debug_corner_color    : source_color = vec4(1.0, 0.2, 0.0, 1.0);
uniform float debug_arm_length      : hint_range(0.01, 0.2) = 0.06;
uniform float debug_thickness       : hint_range(0.001, 0.05) = 0.005;
uniform bool  debug_pivot           = false;
uniform vec4  debug_pivot_color     : source_color = vec4(0.0, 1.0, 0.5, 1.0);
uniform float debug_pivot_size      : hint_range(0.005, 0.15) = 0.03;
uniform float debug_pivot_thickness : hint_range(0.001, 0.02) = 0.003;
group_uniforms;


void fragment() {
	vec2 uv       = UV;
	vec3 col      = texture(screen_tex, uv).rgb;
	vec3 original = col;

	// ── 1. Exposure ───────────────────────────────────────────────────────────
	if (exposure_on) {
		vec3 ex = col * pow(2.0, exposure_ev);
		ex = pow(max(ex, 0.0), vec3(exposure_gamma));
		if (abs(exposure_contrast) > 0.001)
			ex = clamp((ex - 0.5) * (1.0 + exposure_contrast) + 0.5, 0.0, 1.0);
		col = blend_layer(col, clamp(ex, 0.0, 1.0), exposure_blend, exposure_opacity);
	}

	// ── 2. White Balance ──────────────────────────────────────────────────────
	if (wb_on) {
		vec3 wb = col;
		// Temperature: blue ↔ yellow axis (scale 0.3 keeps it perceptually gentle)
		wb.r = clamp(wb.r + wb_temperature * 0.3, 0.0, 1.0);
		wb.b = clamp(wb.b - wb_temperature * 0.3, 0.0, 1.0);
		// Tint: green ↔ magenta axis
		wb.g = clamp(wb.g - wb_tint * 0.15, 0.0, 1.0);
		wb.r = clamp(wb.r + wb_tint * 0.075, 0.0, 1.0);
		wb.b = clamp(wb.b + wb_tint * 0.075, 0.0, 1.0);
		col = blend_layer(col, wb, wb_blend, wb_opacity);
	}

	// ── 3. Color Wheels (Lift / Gamma / Gain) ─────────────────────────────────
	if (wheels_on) {
		vec3 wh = col;

		// Signed colour offset — center (0.5, 0.5, 0.5) = neutral, range [-1, 1]
		vec3 lift_dir  = (wheels_lift.rgb  - 0.5) * 2.0;
		vec3 gamma_dir = (wheels_gamma.rgb - 0.5) * 2.0;
		vec3 gain_dir  = (wheels_gain.rgb  - 0.5) * 2.0;

		// Lift: shift shadows (weight by darkness so bright areas are less affected)
		wh = clamp(wh + lift_dir * wheels_lift.a * (1.0 - wh), 0.0, 1.0);

		// Gain: scale highlights (weight by brightness)
		wh = clamp(wh * (1.0 + gain_dir * wheels_gain.a), 0.0, 1.0);

		// Gamma: per-channel power curve for midtones
		vec3 gamma_exp = vec3(1.0) / max(vec3(1.0) + gamma_dir * wheels_gamma.a, 0.001);
		wh = clamp(pow(max(wh, 0.0), gamma_exp), 0.0, 1.0);

		col = blend_layer(col, wh, wheels_blend, wheels_opacity);
	}

	// ── 4. HSL ────────────────────────────────────────────────────────────────
	if (hsl_on) {
		vec3 hsl = rgb_to_hsl(col);

		// Hue rotation
		hsl.x = fract(hsl.x + hsl_hue / 360.0);

		// Vibrance: boost desaturated colours more than already-saturated ones
		if (abs(hsl_vibrance) > 0.001) {
			float vib_mask = 1.0 - hsl.y;  // stronger on low-saturation pixels
			hsl.y = clamp(hsl.y + hsl_vibrance * vib_mask, 0.0, 1.0);
		}

		// Saturation multiplier
		hsl.y = clamp(hsl.y * hsl_saturation, 0.0, 1.0);

		// Lightness offset
		hsl.z = clamp(hsl.z + hsl_lightness, 0.0, 1.0);

		col = blend_layer(col, hsl_to_rgb(hsl), hsl_blend, hsl_opacity);
	}

	// ── 5. Curves ─────────────────────────────────────────────────────────────
	if (curves_on) {
		vec3 cv = col;

		cv.r = apply_curve(cv.r, curves_master_shadows, curves_master_midtones, curves_master_highlights);
		cv.g = apply_curve(cv.g, curves_master_shadows, curves_master_midtones, curves_master_highlights);
		cv.b = apply_curve(cv.b, curves_master_shadows, curves_master_midtones, curves_master_highlights);

		cv.r = apply_curve(cv.r, curves_r_shadows, curves_r_midtones, curves_r_highlights);
		cv.g = apply_curve(cv.g, curves_g_shadows, curves_g_midtones, curves_g_highlights);
		cv.b = apply_curve(cv.b, curves_b_shadows, curves_b_midtones, curves_b_highlights);

		col = blend_layer(col, cv, curves_blend, curves_opacity);
	}

	// ── 6. Channel Mixer ──────────────────────────────────────────────────────
	if (mixer_on) {
		vec3 mx = vec3(
			dot(col, vec3(mixer_rr, mixer_rg, mixer_rb)),
			dot(col, vec3(mixer_gr, mixer_gg, mixer_gb)),
			dot(col, vec3(mixer_br, mixer_bg, mixer_bb))
		);
		col = blend_layer(col, clamp(mx, 0.0, 1.0), mixer_blend, mixer_opacity);
	}

	// ── Global blend ──────────────────────────────────────────────────────────
	col = blend_layer(original, col, global_blend, global_opacity);

	// ── Debug ─────────────────────────────────────────────────────────────────
	vec2 _u = UV;
	vec2 _f = 1.0 - UV;

	if (debug_corners) {
		float a  = debug_arm_length;
		float th = debug_thickness;
		bool mark =
			(_u.x < a && _u.y < th) || (_u.y < a && _u.x < th) ||
			(_f.x < a && _u.y < th) || (_u.y < a && _f.x < th) ||
			(_u.x < a && _f.y < th) || (_f.y < a && _u.x < th) ||
			(_f.x < a && _f.y < th) || (_f.y < a && _f.x < th);
		if (mark) col = debug_corner_color.rgb;
	}

	if (debug_pivot) {
		vec2 c    = abs(UV - 0.5);
		bool mark = (c.x < debug_pivot_size && c.y < debug_pivot_thickness) ||
		            (c.y < debug_pivot_size && c.x < debug_pivot_thickness);
		if (mark) col = debug_pivot_color.rgb;
	}

	COLOR = vec4(col, 1.0);
}
