shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// Bloom settings
group_uniforms bloom;
uniform float bloom_intensity : hint_range(0.0, 5.0) = 1.2;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.4;
uniform float bloom_spread : hint_range(1.0, 10.0) = 4.0;

// Vignette settings
group_uniforms vignette;
uniform float vignette_focus : hint_range(0.1, 2.0) = 1.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.5;
uniform vec3 vignette_color : source_color = vec3(0.02, 0.05, 0.1);

// Chromatic Aberration (camera shake feedback)
group_uniforms chromatic;
uniform float chromatic_aberration : hint_range(0.0, 10.0) = 0.0;

// Tilt-shift / Depth of Field settings (Macro Photography)
group_uniforms tilt_shift;
uniform float tilt_shift_focus_y : hint_range(0.0, 1.0) = 0.5;
uniform float tilt_shift_focus_height : hint_range(0.0, 1.0) = 0.35;
uniform float tilt_shift_blur_amount : hint_range(0.0, 10.0) = 3.0;

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

	// Tilt-shift (Depth of Field) calculation based on Y position
	// How far are we from the focus area?
	float dist_from_focus = abs(uv.y - tilt_shift_focus_y);
	// Smoothstep creates a soft transition around the focus area bounds
	float blur_factor = smoothstep(tilt_shift_focus_height / 2.0, (tilt_shift_focus_height / 2.0) + 0.3, dist_from_focus);
	
	vec4 dof_blur = vec4(0.0);
	float dof_weight = 0.0;
	
	// Only calculate blur if we're outside the sharp focus area to save performance
	if (blur_factor > 0.0) {
		for (float dx = -2.0; dx <= 2.0; dx += 1.0) {
			for (float dy = -2.0; dy <= 2.0; dy += 1.0) {
				float weight = 1.0 - (length(vec2(dx, dy)) / 3.0);
				weight = max(weight, 0.01);
				dof_blur += texture(screen_texture, uv + vec2(dx, dy) * ps * tilt_shift_blur_amount * blur_factor) * weight;
				dof_weight += weight;
			}
		}
		dof_blur /= dof_weight;
	} else {
		dof_blur = original;
	}

	// Mix original with DoF based on blur factor
	vec3 dof_result = mix(original.rgb, dof_blur.rgb, blur_factor);

	// Bloom (weighted 5x5 using the depth-of-field blurred result as a base)
	vec4 blur_bloom = vec4(0.0);
	float total_weight = 0.0;
	for (float x = -2.0; x <= 2.0; x++) {
		for (float y = -2.0; y <= 2.0; y++) {
			float weight = 1.0 - length(vec2(x, y)) / 3.5;
			weight = max(weight, 0.0);
			// Sample from original unblurred texture for sharp bloom highlights
			vec4 s = texture(screen_texture, uv + vec2(x, y) * ps * bloom_spread);
			float lum = dot(s.rgb, vec3(0.299, 0.587, 0.114));
			vec4 bright = s * smoothstep(bloom_threshold, bloom_threshold + 0.3, lum);
			blur_bloom += bright * weight;
			total_weight += weight;
		}
	}
	blur_bloom /= total_weight;

	// Add Bloom to DoF result
	vec3 result = dof_result + blur_bloom.rgb * bloom_intensity;

	// Add Vignette
	float d = distance(uv, vec2(0.5));
	d = smoothstep(1.0 - vignette_focus, 1.0, d);
	result = mix(result, vignette_color, d * vignette_intensity);

	COLOR = vec4(result, 1.0);
}
