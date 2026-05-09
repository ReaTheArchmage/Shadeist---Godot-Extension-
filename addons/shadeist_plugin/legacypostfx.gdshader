shader_type canvas_item;
render_mode unshaded;

// Place this shader on a ShaderMaterial assigned to a full-screen ColorRect
// inside a CanvasLayer above your scene.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

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

// Hash without Sine (Dave Hoskins) — trig-free, ~2x faster than sin-based hash
float rand(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

uniform float global_opacity : hint_range(0.0, 1.0) = 1.0;
uniform int   global_blend  : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;

// ============================================================
// QUALITY
// Scales per-fragment texture samples and ALU complexity.
// Note: all paths are compiled into one shader binary — this
// reduces bandwidth/ALU, not register count or binary size.
//
//   Very Low : 5-tap blur/bloom, 2-sample chroma,
//              hue rotation skipped, step scanlines,
//              linear vignette falloff (no smoothstep)
//   Low      : 5-tap, full math for all effects
//   Mid      : 9-tap, 3-sample chroma with green shift
//   High     : 13-tap (approximate Gaussian weights)
//   Very High: 13-tap (accurate Gaussian σ=1 weights)
// ============================================================
group_uniforms Quality;
uniform int quality : hint_enum("Very Low,Low,Mid,High,Very High") = 2;
group_uniforms;

// ============================================================
// PIXELATION
// ============================================================
group_uniforms LegacyEffects.Pixelation;
uniform bool   pixel_on      = false;
uniform float  pixel_opacity : hint_range(0.0, 1.0) = 1.0;
uniform int    pixel_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform float  pixel_size    : hint_range(1.0, 64.0) = 6.0;
group_uniforms;

// ============================================================
// CHROMATIC ABERRATION
// ============================================================
group_uniforms LegacyEffects.ChromaticAberration;
uniform bool   chroma_on      = false;
uniform float  chroma_opacity : hint_range(0.0, 1.0) = 1.0;
uniform int    chroma_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform float  chroma_size    : hint_range(0.0, 0.02) = 0.003;
group_uniforms;

// ============================================================
// BLUR  (5 / 9 / 13-tap depending on quality)
// ============================================================
group_uniforms LegacyEffects.Blur;
uniform bool   blur_on      = false;
uniform float  blur_opacity : hint_range(0.0, 1.0) = 1.0;
uniform int    blur_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform float  blur_size    : hint_range(0.0, 10.0) = 2.0;
group_uniforms;

// ============================================================
// COLOR CORRECTION
// ============================================================
group_uniforms LegacyEffects.ColorCorrection;
uniform bool   colorcorrect_on      = false;
uniform float  colorcorrect_opacity : hint_range(0.0, 1.0) = 1.0;
uniform int    colorcorrect_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform float  brightness    : hint_range(-1.0, 1.0) = 0.0;
uniform float  contrast      : hint_range(0.0, 3.0) = 1.0;
uniform float  saturation    : hint_range(0.0, 3.0) = 1.0;
uniform float  hue_shift     : hint_range(-180.0, 180.0) = 0.0;
group_uniforms;

// ============================================================
// BLOOM  (5 / 9 / 13-tap depending on quality)
// ============================================================
group_uniforms LegacyEffects.Bloom;
uniform bool   bloom_on        = false;
uniform float  bloom_opacity   : hint_range(0.0, 1.0) = 0.5;
uniform int    bloom_blend     : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 4;
uniform float  bloom_threshold : hint_range(0.0, 1.0) = 0.65;
uniform float  bloom_size      : hint_range(0.5, 8.0) = 2.5;
group_uniforms;

// ============================================================
// SCANLINES
// ============================================================
group_uniforms LegacyEffects.Scanlines;
uniform bool   scan_on      = false;
uniform float  scan_opacity : hint_range(0.0, 1.0) = 0.3;
uniform int    scan_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 1;
uniform float  scan_speed   : hint_range(-5.0, 5.0) = 0.5;
uniform float  scan_size    : hint_range(1.0, 32.0) = 3.0;
group_uniforms;

// ============================================================
// FILM GRAIN
// ============================================================
group_uniforms LegacyEffects.FilmGrain;
uniform bool   grain_on      = false;
uniform float  grain_opacity : hint_range(0.0, 1.0) = 0.15;
uniform int    grain_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 3;
uniform float  grain_speed   : hint_range(0.0, 30.0) = 10.0;
uniform float  grain_size    : hint_range(0.5, 8.0) = 1.0;
group_uniforms;

// ============================================================
// VIGNETTE
// ============================================================
group_uniforms LegacyEffects.Vignette;
uniform bool   vignette_on       = false;
uniform float  vignette_opacity  : hint_range(0.0, 1.0) = 0.7;
uniform int    vignette_blend    : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform float  vignette_size     : hint_range(0.1, 2.0) = 1.0;
uniform float  vignette_softness : hint_range(0.0, 1.0) = 0.45;
group_uniforms;

// ============================================================
// COLOR TINT
// ============================================================
group_uniforms LegacyEffects.ColorTint;
uniform bool   tint_on      = false;
uniform float  tint_opacity : hint_range(0.0, 1.0) = 0.4;
uniform int    tint_blend   : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 1;
uniform vec4   tint_color   : source_color = vec4(1.0, 0.85, 0.65, 1.0);
group_uniforms;

// ============================================================
// DEBUG
// ============================================================
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
	vec2 uv  = UV;
	vec2 suv = UV;

	vec3 col      = texture(screen_tex, uv).rgb;
	vec3 original = col;

	// Phase 1: Spatial effects
	if (pixel_on) {
		vec2 ps = SCREEN_PIXEL_SIZE * pixel_size;
		suv = (floor(uv / ps) + 0.5) * ps;
		col = blend_layer(col, texture(screen_tex, suv).rgb, pixel_blend, pixel_opacity);
	}

	if (chroma_on) {
		vec2 co = vec2(chroma_size, 0.0);
		vec3 chroma;
		if (quality <= 1) {
			// 2 samples — R and B shifted, G reused from current pixel
			chroma = vec3(
				texture(screen_tex, suv + co).r,
				col.g,
				texture(screen_tex, suv - co).b
			);
		} else {
			// 3 samples — G shifted slightly for realistic spectral separation
			chroma = vec3(
				texture(screen_tex, suv + co        ).r,
				texture(screen_tex, suv + co * 0.333).g,
				texture(screen_tex, suv - co        ).b
			);
		}
		col = blend_layer(col, chroma, chroma_blend, chroma_opacity);
	}

	if (blur_on && blur_size > 0.0) {
		vec2 ps = SCREEN_PIXEL_SIZE * blur_size;
		vec3 b;
		if (quality <= 1) {
			// 5-tap cross
			b  = texture(screen_tex, suv                    ).rgb * 0.400;
			b += texture(screen_tex, suv + vec2(-1, 0) * ps).rgb * 0.150;
			b += texture(screen_tex, suv + vec2( 1, 0) * ps).rgb * 0.150;
			b += texture(screen_tex, suv + vec2( 0,-1) * ps).rgb * 0.150;
			b += texture(screen_tex, suv + vec2( 0, 1) * ps).rgb * 0.150;
		} else if (quality == 2) {
			// 9-tap 3x3 Gaussian
			b  = texture(screen_tex, suv + vec2(-1,-1) * ps).rgb * 0.075;
			b += texture(screen_tex, suv + vec2( 0,-1) * ps).rgb * 0.124;
			b += texture(screen_tex, suv + vec2( 1,-1) * ps).rgb * 0.075;
			b += texture(screen_tex, suv + vec2(-1, 0) * ps).rgb * 0.124;
			b += texture(screen_tex, suv               ).rgb * 0.204;
			b += texture(screen_tex, suv + vec2( 1, 0) * ps).rgb * 0.124;
			b += texture(screen_tex, suv + vec2(-1, 1) * ps).rgb * 0.075;
			b += texture(screen_tex, suv + vec2( 0, 1) * ps).rgb * 0.124;
			b += texture(screen_tex, suv + vec2( 1, 1) * ps).rgb * 0.075;
		} else if (quality == 3) {
			// 13-tap: approximate weights (sum = 1.0)
			b  = texture(screen_tex, suv               ).rgb * 0.200;
			b += texture(screen_tex, suv + vec2(-1, 0) * ps).rgb * 0.120;
			b += texture(screen_tex, suv + vec2( 1, 0) * ps).rgb * 0.120;
			b += texture(screen_tex, suv + vec2( 0,-1) * ps).rgb * 0.120;
			b += texture(screen_tex, suv + vec2( 0, 1) * ps).rgb * 0.120;
			b += texture(screen_tex, suv + vec2(-2, 0) * ps).rgb * 0.040;
			b += texture(screen_tex, suv + vec2( 2, 0) * ps).rgb * 0.040;
			b += texture(screen_tex, suv + vec2( 0,-2) * ps).rgb * 0.040;
			b += texture(screen_tex, suv + vec2( 0, 2) * ps).rgb * 0.040;
			b += texture(screen_tex, suv + vec2(-1,-1) * ps).rgb * 0.040;
			b += texture(screen_tex, suv + vec2( 1,-1) * ps).rgb * 0.040;
			b += texture(screen_tex, suv + vec2(-1, 1) * ps).rgb * 0.040;
			b += texture(screen_tex, suv + vec2( 1, 1) * ps).rgb * 0.040;
		} else {
			// 13-tap: accurate Gaussian σ=1 weights (sum ≈ 1.0)
			b  = texture(screen_tex, suv               ).rgb * 0.184;
			b += texture(screen_tex, suv + vec2(-1, 0) * ps).rgb * 0.111;
			b += texture(screen_tex, suv + vec2( 1, 0) * ps).rgb * 0.111;
			b += texture(screen_tex, suv + vec2( 0,-1) * ps).rgb * 0.111;
			b += texture(screen_tex, suv + vec2( 0, 1) * ps).rgb * 0.111;
			b += texture(screen_tex, suv + vec2(-2, 0) * ps).rgb * 0.025;
			b += texture(screen_tex, suv + vec2( 2, 0) * ps).rgb * 0.025;
			b += texture(screen_tex, suv + vec2( 0,-2) * ps).rgb * 0.025;
			b += texture(screen_tex, suv + vec2( 0, 2) * ps).rgb * 0.025;
			b += texture(screen_tex, suv + vec2(-1,-1) * ps).rgb * 0.068;
			b += texture(screen_tex, suv + vec2( 1,-1) * ps).rgb * 0.068;
			b += texture(screen_tex, suv + vec2(-1, 1) * ps).rgb * 0.068;
			b += texture(screen_tex, suv + vec2( 1, 1) * ps).rgb * 0.068;
		}
		col = blend_layer(col, b, blur_blend, blur_opacity);
	}

	if (bloom_on) {
		vec2 ps = SCREEN_PIXEL_SIZE * bloom_size;
		vec3 acc;
		if (quality <= 1) {
			// 5-tap cross
			acc  = max(texture(screen_tex, suv                    ).rgb - bloom_threshold, 0.0) * 0.400;
			acc += max(texture(screen_tex, suv + vec2(-1, 0) * ps).rgb - bloom_threshold, 0.0) * 0.150;
			acc += max(texture(screen_tex, suv + vec2( 1, 0) * ps).rgb - bloom_threshold, 0.0) * 0.150;
			acc += max(texture(screen_tex, suv + vec2( 0,-1) * ps).rgb - bloom_threshold, 0.0) * 0.150;
			acc += max(texture(screen_tex, suv + vec2( 0, 1) * ps).rgb - bloom_threshold, 0.0) * 0.150;
		} else if (quality == 2) {
			// 9-tap 3x3 Gaussian
			acc  = max(texture(screen_tex, suv + vec2(-1,-1) * ps).rgb - bloom_threshold, 0.0) * 0.075;
			acc += max(texture(screen_tex, suv + vec2( 0,-1) * ps).rgb - bloom_threshold, 0.0) * 0.124;
			acc += max(texture(screen_tex, suv + vec2( 1,-1) * ps).rgb - bloom_threshold, 0.0) * 0.075;
			acc += max(texture(screen_tex, suv + vec2(-1, 0) * ps).rgb - bloom_threshold, 0.0) * 0.124;
			acc += max(texture(screen_tex, suv               ).rgb - bloom_threshold, 0.0) * 0.204;
			acc += max(texture(screen_tex, suv + vec2( 1, 0) * ps).rgb - bloom_threshold, 0.0) * 0.124;
			acc += max(texture(screen_tex, suv + vec2(-1, 1) * ps).rgb - bloom_threshold, 0.0) * 0.075;
			acc += max(texture(screen_tex, suv + vec2( 0, 1) * ps).rgb - bloom_threshold, 0.0) * 0.124;
			acc += max(texture(screen_tex, suv + vec2( 1, 1) * ps).rgb - bloom_threshold, 0.0) * 0.075;
		} else if (quality == 3) {
			// 13-tap: approximate weights
			acc  = max(texture(screen_tex, suv               ).rgb - bloom_threshold, 0.0) * 0.200;
			acc += max(texture(screen_tex, suv + vec2(-1, 0) * ps).rgb - bloom_threshold, 0.0) * 0.120;
			acc += max(texture(screen_tex, suv + vec2( 1, 0) * ps).rgb - bloom_threshold, 0.0) * 0.120;
			acc += max(texture(screen_tex, suv + vec2( 0,-1) * ps).rgb - bloom_threshold, 0.0) * 0.120;
			acc += max(texture(screen_tex, suv + vec2( 0, 1) * ps).rgb - bloom_threshold, 0.0) * 0.120;
			acc += max(texture(screen_tex, suv + vec2(-2, 0) * ps).rgb - bloom_threshold, 0.0) * 0.040;
			acc += max(texture(screen_tex, suv + vec2( 2, 0) * ps).rgb - bloom_threshold, 0.0) * 0.040;
			acc += max(texture(screen_tex, suv + vec2( 0,-2) * ps).rgb - bloom_threshold, 0.0) * 0.040;
			acc += max(texture(screen_tex, suv + vec2( 0, 2) * ps).rgb - bloom_threshold, 0.0) * 0.040;
			acc += max(texture(screen_tex, suv + vec2(-1,-1) * ps).rgb - bloom_threshold, 0.0) * 0.040;
			acc += max(texture(screen_tex, suv + vec2( 1,-1) * ps).rgb - bloom_threshold, 0.0) * 0.040;
			acc += max(texture(screen_tex, suv + vec2(-1, 1) * ps).rgb - bloom_threshold, 0.0) * 0.040;
			acc += max(texture(screen_tex, suv + vec2( 1, 1) * ps).rgb - bloom_threshold, 0.0) * 0.040;
		} else {
			// 13-tap: accurate Gaussian σ=1 weights
			acc  = max(texture(screen_tex, suv               ).rgb - bloom_threshold, 0.0) * 0.184;
			acc += max(texture(screen_tex, suv + vec2(-1, 0) * ps).rgb - bloom_threshold, 0.0) * 0.111;
			acc += max(texture(screen_tex, suv + vec2( 1, 0) * ps).rgb - bloom_threshold, 0.0) * 0.111;
			acc += max(texture(screen_tex, suv + vec2( 0,-1) * ps).rgb - bloom_threshold, 0.0) * 0.111;
			acc += max(texture(screen_tex, suv + vec2( 0, 1) * ps).rgb - bloom_threshold, 0.0) * 0.111;
			acc += max(texture(screen_tex, suv + vec2(-2, 0) * ps).rgb - bloom_threshold, 0.0) * 0.025;
			acc += max(texture(screen_tex, suv + vec2( 2, 0) * ps).rgb - bloom_threshold, 0.0) * 0.025;
			acc += max(texture(screen_tex, suv + vec2( 0,-2) * ps).rgb - bloom_threshold, 0.0) * 0.025;
			acc += max(texture(screen_tex, suv + vec2( 0, 2) * ps).rgb - bloom_threshold, 0.0) * 0.025;
			acc += max(texture(screen_tex, suv + vec2(-1,-1) * ps).rgb - bloom_threshold, 0.0) * 0.068;
			acc += max(texture(screen_tex, suv + vec2( 1,-1) * ps).rgb - bloom_threshold, 0.0) * 0.068;
			acc += max(texture(screen_tex, suv + vec2(-1, 1) * ps).rgb - bloom_threshold, 0.0) * 0.068;
			acc += max(texture(screen_tex, suv + vec2( 1, 1) * ps).rgb - bloom_threshold, 0.0) * 0.068;
		}
		col = blend_layer(col, acc, bloom_blend, bloom_opacity);
	}

	// Phase 2: Tone / colour effects
	if (colorcorrect_on) {
		vec3 cc = clamp(col + brightness, 0.0, 1.0);
		cc = clamp((cc - 0.5) * contrast + 0.5, 0.0, 1.0);
		float lum = dot(cc, vec3(0.299, 0.587, 0.114));
		cc = clamp(mix(vec3(lum), cc, saturation), 0.0, 1.0);
		// Hue rotation skipped at Very Low — Rodrigues formula is the most ALU-heavy
		// operation in the shader; at quality 0 the trade-off is acceptable.
		if (quality > 0 && abs(hue_shift) > 0.001) {
			float rad   = radians(hue_shift);
			float cos_h = cos(rad);
			float sin_h = sin(rad);
			vec3 k = vec3(0.57735);
			cc = cc * cos_h + cross(k, cc) * sin_h + k * dot(k, cc) * (1.0 - cos_h);
			cc = clamp(cc, 0.0, 1.0);
		}
		col = blend_layer(col, cc, colorcorrect_blend, colorcorrect_opacity);
	}

	if (scan_on) {
		float phase = uv.y / (SCREEN_PIXEL_SIZE.y * scan_size) + TIME * scan_speed;
		float sv;
		if (quality == 0) {
			// Step-based: no sin, hard-edged scanline bars
			sv = step(0.5, fract(phase));
		} else {
			sv = sin(phase * TAU) * 0.5 + 0.5;
		}
		col = blend_layer(col, col * sv, scan_blend, scan_opacity);
	}

	if (grain_on) {
		float t     = floor(TIME * grain_speed);
		vec2 gc     = floor(uv / (SCREEN_PIXEL_SIZE * grain_size));
		float noise = rand(gc + vec2(t * 0.131, t * 0.237));
		col = blend_layer(col, vec3(noise), grain_blend, grain_opacity);
	}

	if (vignette_on) {
		vec2 c = uv * 2.0 - 1.0;
		float vig;
		if (quality == 0) {
			// Linear falloff — no smoothstep polynomial, vignette_softness ignored
			vig = clamp(1.0 - length(c) / vignette_size, 0.0, 1.0);
		} else {
			vig = 1.0 - smoothstep(1.0 - vignette_softness, 1.0, length(c) / vignette_size);
		}
		col = blend_layer(col, col * vig, vignette_blend, vignette_opacity);
	}

	if (tint_on) {
		col = blend_layer(col, col * tint_color.rgb, tint_blend, tint_opacity);
	}

	col = blend_layer(original, col, global_blend, global_opacity);

	// Debug: drawn in raw UV space
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
