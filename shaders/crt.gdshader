shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

group_uniforms crt;
uniform float scanline_intensity : hint_range(0.0, 0.5) = 0.08;
uniform float scanline_count : hint_range(100.0, 1080.0) = 540.0;
uniform float curvature : hint_range(0.0, 0.05) = 0.02;
uniform float chromatic_aberration : hint_range(0.0, 5.0) = 0.8;

group_uniforms glitch;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0; // 0.0 = normal, 1.0 = heavy glitch
uniform float glitch_time : hint_range(0.0, 1000.0) = 0.0; // Drive this from a script

// Random function for noise
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec2 curve(vec2 uv) {
	uv = (uv - 0.5) * 2.0;
	uv *= 1.0 + dot(uv, uv) * curvature;
	uv = (uv / 2.0) + 0.5;
	return uv;
}

void fragment() {
	vec2 base_uv = SCREEN_UV;
	
	// Glitch logic (horizontal slice shifting based on time and intensity)
	if (glitch_intensity > 0.0) {
		float noise = rand(vec2(floor(base_uv.y * 20.0), glitch_time)) * 2.0 - 1.0;
		float shift = noise * glitch_intensity * 0.05;
		// Only affect random bands
		if (rand(vec2(floor(base_uv.y * 10.0), glitch_time * 2.1)) > 0.8) {
			base_uv.x += shift;
		}
	}
	
	vec2 uv = curve(base_uv);
	vec2 ps = SCREEN_PIXEL_SIZE;

	// Chromatic aberration (RGB offset) + glitch multiplier
	float ca_active = chromatic_aberration + (glitch_intensity * 10.0);
	float r = texture(screen_texture, uv + vec2(ca_active * ps.x, 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(ca_active * ps.x, 0.0)).b;
	
	// Glitch color scrambling (occasional RGB channel swap or noise)
	vec3 color = vec3(r, g, b);
	if (glitch_intensity > 0.5 && rand(vec2(uv.x, glitch_time)) > 0.9) {
		color = vec3(b, r, g); // Swap channels randomly during heavy glitches
	}

	// Scanlines + Glitch flicker
	float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
	float flicker = 1.0 - (rand(vec2(glitch_time, 0.0)) * glitch_intensity * 0.5);
	color *= (1.0 - scanline_intensity * (1.0 - scanline)) * flicker;

	// Out of bounds (from curvature) — black edges
	float in_bounds = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	color *= in_bounds;

	COLOR = vec4(color, 1.0);
}
