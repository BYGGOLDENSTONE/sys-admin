shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float bloom_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.35;
uniform float bloom_spread : hint_range(1.0, 10.0) = 3.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 ps = SCREEN_PIXEL_SIZE;

	// Original color
	vec4 original = texture(screen_texture, uv);

	// Bloom: multi-sample blur (5x5 weighted kernel)
	vec4 blur = vec4(0.0);
	float total_weight = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float weight = 1.0 - length(vec2(float(x), float(y))) / 3.5;
			weight = max(weight, 0.0);
			vec4 s = texture(screen_texture, uv + vec2(float(x), float(y)) * ps * bloom_spread);
			float lum = dot(s.rgb, vec3(0.299, 0.587, 0.114));
			vec4 bright = s * smoothstep(bloom_threshold, bloom_threshold + 0.3, lum);
			blur += bright * weight;
			total_weight += weight;
		}
	}
	blur /= total_weight;

	vec3 result = original.rgb + blur.rgb * bloom_intensity;

	COLOR = vec4(result, 1.0);
}
