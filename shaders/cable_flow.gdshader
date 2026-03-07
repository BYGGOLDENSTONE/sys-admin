shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.0, 1.0, 0.5, 1.0);
uniform float flow_speed : hint_range(-5.0, 5.0) = 1.0;
uniform float intensity : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_frequency : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec2 uv = UV;
	
	// Create scrolling effect for the flow
	float flow = fract(uv.x - TIME * flow_speed);
	
	// Data packets: glowing dashed pulses along the line
	// Multiplied by sine wave to create distinct packets
	float packets = step(0.6, (sin(flow * 30.0) * 0.5 + 0.5));
	
	// Overall pulsing glow of the entire cable
	float pulse = (sin(TIME * pulse_frequency) * 0.2 + 0.8);
	
	// Smooth edges for the cable
	float edge = smoothstep(0.0, 0.2, uv.y) * smoothstep(1.0, 0.8, uv.y);
	
	// Base cable color (faint)
	vec3 final_color = base_color.rgb * intensity * edge * 0.3 * pulse;
	
	// Add bright data packets
	final_color += base_color.rgb * packets * intensity * 2.0 * edge;
	
	// Make packets whiter at the core
	vec3 core = vec3(1.0) * packets * smoothstep(0.3, 0.7, uv.y) * smoothstep(0.7, 0.3, uv.y);
	final_color += core * intensity;

	COLOR = vec4(final_color, base_color.a * edge);
}
