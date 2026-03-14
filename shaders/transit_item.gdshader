shader_type canvas_item;

uniform sampler2D glyph_atlas : filter_linear, hint_default_black;
uniform float atlas_cols = 10.0;

varying vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
}

void fragment() {
	float glyph_idx = floor(v_custom.x * 10.0 + 0.5);
	float pulse_phase = v_custom.z * 40.0;
	float intensity = max(v_custom.w, 0.5);

	vec2 cuv = UV - 0.5;
	float dist = length(cuv) * 2.0;

	float glow_pulse = sin(TIME * 5.0 + pulse_phase) * 0.5 + 0.5;
	vec3 base = COLOR.rgb;

	// === GLOW — soft circular halo ===
	float glow = smoothstep(1.0, 0.0, dist);
	float glow_a = glow * (0.2 + glow_pulse * 0.12) * intensity;

	// === CHARACTER — fills center 70% of quad ===
	float char_hw = 0.35;
	float char_hh = 0.40;
	float cell_w = 1.0 / atlas_cols;
	float local_u = clamp((cuv.x + char_hw) / (char_hw * 2.0), 0.0, 1.0);
	float local_v = clamp(1.0 - (cuv.y + char_hh) / (char_hh * 2.0), 0.0, 1.0);
	vec2 atlas_uv = vec2((glyph_idx + local_u) * cell_w, local_v);
	vec4 glyph = texture(glyph_atlas, atlas_uv);

	// === COMPOSE ===
	vec3 result = base * glow_a * 2.0;
	float out_alpha = glow_a;

	// Character shadow (soft dark halo for readability)
	if (glyph.a > 0.01) {
		float shadow = glyph.a * 0.6;
		result = mix(result, vec3(0.0), shadow * 0.5);
		out_alpha = max(out_alpha, shadow * 0.4);
	}

	// Bright character
	if (glyph.a > 0.01) {
		vec3 bright = mix(base, vec3(1.0), 0.3) * 1.5;
		result = mix(result, bright, glyph.a * 0.95);
		result += vec3(1.0) * glyph.a * 0.2;
		out_alpha = max(out_alpha, glyph.a * 0.95);
	}

	if (out_alpha < 0.003) {
		discard;
	}

	COLOR = vec4(result, out_alpha * COLOR.a);
}
