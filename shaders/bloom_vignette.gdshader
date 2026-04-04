shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// Bloom settings — cyberpunk neon glow
group_uniforms bloom;
uniform float bloom_intensity : hint_range(0.0, 8.0) = 2.0;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.28;
uniform float bloom_spread : hint_range(1.0, 20.0) = 6.0;
uniform float bloom_softness : hint_range(0.0, 1.0) = 0.45;

// Vignette settings
group_uniforms vignette;
uniform float vignette_focus : hint_range(0.1, 2.0) = 1.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec3 vignette_color : source_color = vec3(0.02, 0.04, 0.07);

// Chromatic Aberration (camera shake feedback)
group_uniforms chromatic;
uniform float chromatic_aberration : hint_range(0.0, 10.0) = 0.0;

// CRT scanline effect
group_uniforms crt;
uniform bool scanlines_enabled = true;
uniform float scanline_alpha : hint_range(0.0, 0.3) = 0.06;
uniform float noise_alpha : hint_range(0.0, 0.1) = 0.02;

// Kawase-style multi-sample bloom (13 taps — much richer than 3x3)
vec3 sample_bloom(sampler2D tex, vec2 uv, vec2 ps, float spread) {
	vec3 sum = vec3(0.0);
	float tw = 0.0;

	// Center (weight 4)
	vec4 c = texture(tex, uv);
	float lc = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 bc = c.rgb * smoothstep(bloom_threshold, bloom_threshold + bloom_softness, lc);
	sum += bc * 4.0;
	tw += 4.0;

	// 4 diagonal samples at 1x spread
	for (float x = -1.0; x <= 1.0; x += 2.0) {
		for (float y = -1.0; y <= 1.0; y += 2.0) {
			vec4 s = texture(tex, uv + vec2(x, y) * ps * spread);
			float l = dot(s.rgb, vec3(0.299, 0.587, 0.114));
			sum += s.rgb * smoothstep(bloom_threshold, bloom_threshold + bloom_softness, l) * 2.0;
			tw += 2.0;
		}
	}

	// 4 axis samples at 2x spread (wider glow)
	vec2 offsets[4] = {vec2(2.0, 0.0), vec2(-2.0, 0.0), vec2(0.0, 2.0), vec2(0.0, -2.0)};
	for (int i = 0; i < 4; i++) {
		vec4 s = texture(tex, uv + offsets[i] * ps * spread);
		float l = dot(s.rgb, vec3(0.299, 0.587, 0.114));
		sum += s.rgb * smoothstep(bloom_threshold, bloom_threshold + bloom_softness, l) * 1.5;
		tw += 1.5;
	}

	// 4 far diagonal samples at 3x spread (outer halo)
	for (float x = -1.0; x <= 1.0; x += 2.0) {
		for (float y = -1.0; y <= 1.0; y += 2.0) {
			vec4 s = texture(tex, uv + vec2(x, y) * ps * spread * 2.5);
			float l = dot(s.rgb, vec3(0.299, 0.587, 0.114));
			sum += s.rgb * smoothstep(bloom_threshold, bloom_threshold + bloom_softness, l) * 0.8;
			tw += 0.8;
		}
	}

	return sum / tw;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 ps = SCREEN_PIXEL_SIZE;

	// Chromatic aberration — offset R and B channels during camera shake
	vec4 original;
	if (chromatic_aberration > 0.0) {
		vec2 ca = vec2(chromatic_aberration * ps.x * 2.0, 0.0);
		original = vec4(
			texture(screen_texture, uv + ca).r,
			texture(screen_texture, uv).g,
			texture(screen_texture, uv - ca).b,
			1.0
		);
	} else {
		original = texture(screen_texture, uv);
	}

	// Multi-tap bloom with wide spread
	vec3 bloom = sample_bloom(screen_texture, uv, ps, bloom_spread);

	// Combine: additive bloom preserves neon pop
	vec3 result = original.rgb + bloom * bloom_intensity;

	// Subtle tone-mapping to prevent blowout (Reinhard soft)
	result = result / (1.0 + result * 0.15);

	// Vignette
	float d = distance(uv, vec2(0.5));
	d = smoothstep(1.0 - vignette_focus, 1.0, d);
	result = mix(result, vignette_color, d * vignette_intensity);

	// CRT scanline + noise
	if (scanlines_enabled) {
		float scan = sin(uv.y / ps.y * 0.5) * 0.5 + 0.5;
		result *= 1.0 - scan * scanline_alpha;
		float grain = fract(sin(dot(uv + vec2(TIME * 0.17, TIME * 0.31), vec2(12.9898, 78.233))) * 43758.5453);
		result += (grain - 0.5) * noise_alpha;
	}

	COLOR = vec4(result, 1.0);
}
