shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx;

// ── Blend utility ─────────────────────────────────────────────────────────────
// Blend modes: 0=Normal  1=Multiply  2=Screen  3=Overlay  4=Add  5=Subtract
vec3 blend_rgb(vec3 base, vec3 over, int mode) {
	if (mode == 1) return base * over;
	if (mode == 2) return 1.0 - (1.0 - base) * (1.0 - over);
	if (mode == 3) return mix(2.0 * base * over,
	                          1.0 - 2.0 * (1.0 - base) * (1.0 - over),
	                          step(0.5, base));
	if (mode == 4) return clamp(base + over, 0.0, 1.0);
	if (mode == 5) return clamp(base - over, 0.0, 1.0);
	return over; // Normal
}

// ── UV transform ──────────────────────────────────────────────────────────────
// Order: rotate around UV centre (0.5, 0.5), then scale, then offset.
// rotation is in degrees. The sin/cos are skipped entirely when rotation is 0
// because rotation_deg is a uniform — all fragments take the same branch, so
// the GPU can skip the trig unit for the whole draw call.
vec2 transform_uv(vec2 uv, float rotation_deg, vec2 scale, vec2 offset) {
	if (rotation_deg != 0.0) {
		float r = radians(rotation_deg);
		float s = sin(r), c = cos(r);
		uv -= 0.5;
		uv  = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
		uv += 0.5;
	}
	return uv * scale + offset;
}

// ── UV wrapping ───────────────────────────────────────────────────────────────
// Wrap modes: 0=Repeat  1=Clamp  2=Mirror  3=Border (transparent outside 0-1)
vec2 wrap_uv(vec2 uv, int mode) {
	if (mode == 1) return clamp(uv, 0.0, 1.0);
	if (mode == 2) {
		vec2 f = fract(uv);
		return mix(f, 1.0 - f, mod(floor(uv), 2.0));
	}
	return uv; // Repeat: hardware tiles via repeat_enable sampler; Border: uv already in [0,1]
}

bool outside_uv(vec2 uv) {
	return uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
}

// ── Colour composite ──────────────────────────────────────────────────────────
void composite(inout vec4 result, vec4 layer, int mode, float weight) {
	float alpha   = layer.a * weight;
	vec3  blended = blend_rgb(result.rgb, layer.rgb, mode);
	result.rgb    = mix(result.rgb, blended, alpha);
	result.a      = result.a + alpha * (1.0 - result.a);
}

// ── Normal map blending ───────────────────────────────────────────────────────
// Textures are stored in [0,1]; decode to signed [-1,1] tangent-space normals.
vec3 decode_normal(vec4 s) {
	return s.rgb * 2.0 - 1.0;
}

// Reoriented Normal Blending (Pettineo / Colin Barré-Brisebois).
// Correct at all blend strengths — preserves unit length and avoids the
// direction errors that simple mix() produces when both normals are strong.
//
//   n1 = base/accumulated normal (tangent space, unit length)
//   n2 = incoming detail normal  (tangent space, unit length)
vec3 rnb(vec3 n1, vec3 n2) {
	vec3 t = n1 + vec3(0.0, 0.0, 1.0);
	vec3 u = n2 * vec3(-1.0, -1.0, 1.0);
	return normalize(t * dot(t, u) - u * t.z);
}

// Scale a detail normal toward flat (0,0,1) by weight before feeding into RNB.
// At weight=0 the base normal is unchanged; at weight=1 full RNB is applied.
// Because RNB(n, flat) == n exactly, this gives smooth and correct interpolation
// without needing a separate lerp pass after the blend.
vec3 blend_normal(vec3 base, vec3 detail, float weight) {
	vec3 scaled = normalize(mix(vec3(0.0, 0.0, 1.0), detail, weight));
	return rnb(base, scaled);
}

// ══ GLOBAL ════════════════════════════════════════════════════════════════════
// Overall opacity of the colour result.
uniform float global_opacity         : hint_range(0.0, 1.0)  = 1.0;
// Depth/strength of the accumulated normal map output.
uniform float global_normal_depth    : hint_range(0.0, 4.0)  = 1.0;
// Base metallic value. ORM layers blend on top of this.
uniform float global_metallic        : hint_range(0.0, 1.0)  = 0.0;
// Base roughness value. ORM layers blend on top of this.
uniform float global_roughness       : hint_range(0.0, 1.0)  = 1.0;
// Specular reflectance at normal incidence (0.5 = 4% reflectance, physically-based default).
uniform float global_specular        : hint_range(0.0, 1.0)  = 0.5;
// How strongly AO affects indirect light. 0.0 = AO only shadows direct; 1.0 = full effect.
uniform float global_ao_light_affect : hint_range(0.0, 1.0)  = 1.0;
// Multiplier on the accumulated emission colour from Emission-type layers.
uniform float global_emission_energy : hint_range(0.0, 16.0) = 1.0;

// ══ LAYER 0 ══════════════════════════════════════════════════════════════════
// Note: textures have no source_color hint so the same slot works for colour
// layers (import as sRGB) and data layers (import as Linear/Normal/ORM).
group_uniforms Layer0;
uniform bool      l0_on         = true;
uniform float     l0_weight     : hint_range(0.0, 1.0) = 1.0;
// Albedo: composited into the colour result.
// Normal: blended into the normal map via Reoriented Normal Blending.
// ORM: standard ORM map — R=AO, G=Roughness, B=Metallic — blended by weight.
// Emission: RGB added to the emission channel (weighted, multiplied by global_emission_energy).
uniform int       l0_type       : hint_enum("Albedo,Normal,ORM,Emission") = 0;
uniform int       l0_blend      : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform sampler2D l0_tex        : hint_default_white, repeat_enable, filter_linear_mipmap;
// ── UV modifiers ──
uniform vec2      l0_offset     = vec2(0.0, 0.0);
uniform vec2      l0_scale      = vec2(1.0, 1.0);
// Rotation in degrees, applied around the UV centre (0.5, 0.5) before scale/offset.
uniform float     l0_rotation   : hint_range(-180.0, 180.0) = 0.0;
// Which UV channel to read from. UV2 is useful for lightmaps or a second tiling set.
uniform int       l0_uv_channel : hint_enum("UV,UV2") = 0;
uniform int       l0_wrap       : hint_enum("Repeat,Clamp,Mirror,Border") = 0;
group_uniforms;

// ══ LAYER 1 ══════════════════════════════════════════════════════════════════
group_uniforms Layer1;
uniform bool      l1_on         = false;
uniform float     l1_weight     : hint_range(0.0, 1.0) = 1.0;
uniform int       l1_type       : hint_enum("Albedo,Normal,ORM,Emission") = 0;
uniform int       l1_blend      : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform sampler2D l1_tex        : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec2      l1_offset     = vec2(0.0, 0.0);
uniform vec2      l1_scale      = vec2(1.0, 1.0);
uniform float     l1_rotation   : hint_range(-180.0, 180.0) = 0.0;
uniform int       l1_uv_channel : hint_enum("UV,UV2") = 0;
uniform int       l1_wrap       : hint_enum("Repeat,Clamp,Mirror,Border") = 0;
group_uniforms;

// ══ LAYER 2 ══════════════════════════════════════════════════════════════════
group_uniforms Layer2;
uniform bool      l2_on         = false;
uniform float     l2_weight     : hint_range(0.0, 1.0) = 1.0;
uniform int       l2_type       : hint_enum("Albedo,Normal,ORM,Emission") = 0;
uniform int       l2_blend      : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform sampler2D l2_tex        : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec2      l2_offset     = vec2(0.0, 0.0);
uniform vec2      l2_scale      = vec2(1.0, 1.0);
uniform float     l2_rotation   : hint_range(-180.0, 180.0) = 0.0;
uniform int       l2_uv_channel : hint_enum("UV,UV2") = 0;
uniform int       l2_wrap       : hint_enum("Repeat,Clamp,Mirror,Border") = 0;
group_uniforms;

// ══ LAYER 3 ══════════════════════════════════════════════════════════════════
group_uniforms Layer3;
uniform bool      l3_on         = false;
uniform float     l3_weight     : hint_range(0.0, 1.0) = 1.0;
uniform int       l3_type       : hint_enum("Albedo,Normal,ORM,Emission") = 0;
uniform int       l3_blend      : hint_enum("Normal,Multiply,Screen,Overlay,Add,Subtract") = 0;
uniform sampler2D l3_tex        : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec2      l3_offset     = vec2(0.0, 0.0);
uniform vec2      l3_scale      = vec2(1.0, 1.0);
uniform float     l3_rotation   : hint_range(-180.0, 180.0) = 0.0;
uniform int       l3_uv_channel : hint_enum("UV,UV2") = 0;
uniform int       l3_wrap       : hint_enum("Repeat,Clamp,Mirror,Border") = 0;
group_uniforms;


void fragment() {
	vec4  albedo    = vec4(0.0, 0.0, 0.0, 0.0);
	// Flat tangent-space normal (0,0,1). Normal-type layers blend into this via RNB.
	vec3  normal    = vec3(0.0, 0.0, 1.0);
	// PBR accumulators seeded from global values; ORM layers overwrite via mix().
	float ao        = 1.0;
	float roughness = global_roughness;
	float metallic  = global_metallic;
	// Emission accumulates additively across Emission-type layers.
	vec3  emission  = vec3(0.0);

	// ── Layer 0 ───────────────────────────────────────────────────────────────
	if (l0_on) {
		vec2 base0 = (l0_uv_channel == 1) ? UV2 : UV;
		vec2 uv0   = transform_uv(base0, l0_rotation, l0_scale, l0_offset);
		vec4 c0    = (l0_wrap == 3 && outside_uv(uv0))
		             ? vec4(0.0)
		             : texture(l0_tex, wrap_uv(uv0, l0_wrap));
		if (l0_type == 1)
			normal = blend_normal(normal, decode_normal(c0), l0_weight);
		else if (l0_type == 2) {
			ao        = mix(ao,        c0.r, l0_weight);
			roughness = mix(roughness, c0.g, l0_weight);
			metallic  = mix(metallic,  c0.b, l0_weight);
		} else if (l0_type == 3)
			emission += c0.rgb * l0_weight;
		else
			composite(albedo, c0, l0_blend, l0_weight);
	}

	// ── Layer 1 ───────────────────────────────────────────────────────────────
	if (l1_on) {
		vec2 base1 = (l1_uv_channel == 1) ? UV2 : UV;
		vec2 uv1   = transform_uv(base1, l1_rotation, l1_scale, l1_offset);
		vec4 c1    = (l1_wrap == 3 && outside_uv(uv1))
		             ? vec4(0.0)
		             : texture(l1_tex, wrap_uv(uv1, l1_wrap));
		if (l1_type == 1)
			normal = blend_normal(normal, decode_normal(c1), l1_weight);
		else if (l1_type == 2) {
			ao        = mix(ao,        c1.r, l1_weight);
			roughness = mix(roughness, c1.g, l1_weight);
			metallic  = mix(metallic,  c1.b, l1_weight);
		} else if (l1_type == 3)
			emission += c1.rgb * l1_weight;
		else
			composite(albedo, c1, l1_blend, l1_weight);
	}

	// ── Layer 2 ───────────────────────────────────────────────────────────────
	if (l2_on) {
		vec2 base2 = (l2_uv_channel == 1) ? UV2 : UV;
		vec2 uv2   = transform_uv(base2, l2_rotation, l2_scale, l2_offset);
		vec4 c2    = (l2_wrap == 3 && outside_uv(uv2))
		             ? vec4(0.0)
		             : texture(l2_tex, wrap_uv(uv2, l2_wrap));
		if (l2_type == 1)
			normal = blend_normal(normal, decode_normal(c2), l2_weight);
		else if (l2_type == 2) {
			ao        = mix(ao,        c2.r, l2_weight);
			roughness = mix(roughness, c2.g, l2_weight);
			metallic  = mix(metallic,  c2.b, l2_weight);
		} else if (l2_type == 3)
			emission += c2.rgb * l2_weight;
		else
			composite(albedo, c2, l2_blend, l2_weight);
	}

	// ── Layer 3 ───────────────────────────────────────────────────────────────
	if (l3_on) {
		vec2 base3 = (l3_uv_channel == 1) ? UV2 : UV;
		vec2 uv3   = transform_uv(base3, l3_rotation, l3_scale, l3_offset);
		vec4 c3    = (l3_wrap == 3 && outside_uv(uv3))
		             ? vec4(0.0)
		             : texture(l3_tex, wrap_uv(uv3, l3_wrap));
		if (l3_type == 1)
			normal = blend_normal(normal, decode_normal(c3), l3_weight);
		else if (l3_type == 2) {
			ao        = mix(ao,        c3.r, l3_weight);
			roughness = mix(roughness, c3.g, l3_weight);
			metallic  = mix(metallic,  c3.b, l3_weight);
		} else if (l3_type == 3)
			emission += c3.rgb * l3_weight;
		else
			composite(albedo, c3, l3_blend, l3_weight);
	}

	ALBEDO           = albedo.rgb;
	ALPHA            = albedo.a * global_opacity;
	NORMAL_MAP       = normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = global_normal_depth;
	METALLIC         = metallic;
	ROUGHNESS        = roughness;
	SPECULAR         = global_specular;
	AO               = ao;
	AO_LIGHT_AFFECT  = global_ao_light_affect;
	EMISSION         = emission * global_emission_energy;
}
