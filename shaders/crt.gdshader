shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float scanline_intensity : hint_range(0.0, 0.5) = 0.08;
uniform float scanline_count : hint_range(100.0, 1080.0) = 540.0;
uniform float curvature : hint_range(0.0, 0.05) = 0.01;
uniform float chromatic_aberration : hint_range(0.0, 3.0) = 0.5;

vec2 curve(vec2 uv) {
	uv = (uv - 0.5) * 2.0;
	uv *= 1.0 + dot(uv, uv) * curvature;
	uv = (uv / 2.0) + 0.5;
	return uv;
}

void fragment() {
	vec2 uv = curve(SCREEN_UV);
	vec2 ps = SCREEN_PIXEL_SIZE;

	// Chromatic aberration (RGB offset)
	float r = texture(screen_texture, uv + vec2(chromatic_aberration * ps.x, 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(chromatic_aberration * ps.x, 0.0)).b;
	vec3 color = vec3(r, g, b);

	// Scanlines
	float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
	color *= 1.0 - scanline_intensity * (1.0 - scanline);

	// Out of bounds (from curvature) — black edges
	float in_bounds = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	color *= in_bounds;

	COLOR = vec4(color, 1.0);
}
