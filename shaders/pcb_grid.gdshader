shader_type canvas_item;

// Camera uniforms — set every frame from GDScript
uniform vec2 camera_pos;     // Camera center in world pixels
uniform vec2 viewport_size;  // Viewport size in world pixels (already zoom-divided)
uniform float zoom_level;    // Camera zoom.x
uniform float tile_size = 64.0;

// Underglow texture — GPU-driven building/cable underglow
uniform sampler2D underglow_tex : filter_nearest, hint_default_black;
uniform float underglow_tex_size = 512.0;

// Colors — dark teal bg + cyberpunk red grid/PCB
const vec3 BG_COLOR = vec3(0.06, 0.16, 0.20);           // Dark teal
const vec3 GRID_COLOR = vec3(0.60, 0.12, 0.30);        // Brighter cyberpunk red
const vec3 PCB_TRACE = vec3(0.48, 0.10, 0.24);
const vec3 PCB_VIA = vec3(0.65, 0.15, 0.35);
const vec3 PCB_PAD = vec3(0.40, 0.08, 0.20);

// Hash function — deterministic pseudo-random per cell
int pcb_hash(int x, int y, int seed_val) {
    return ((x * 73856093) ^ (y * 19349663) ^ (seed_val * 83492791)) & 0x7FFFFFFF;
}

// Distance from point to nearest grid line
float grid_line_dist(vec2 world_pos, float step) {
    vec2 cell = world_pos / (tile_size * step);
    vec2 f = fract(cell);
    vec2 d = min(f, 1.0 - f) * tile_size * step;
    return min(d.x, d.y);
}

void fragment() {
    // Map UV (0-1) to world coordinates
    vec2 world_pos = camera_pos - viewport_size * 0.5 + UV * viewport_size;

    // Grid cell coordinates
    vec2 cell_f = world_pos / tile_size;
    ivec2 cell = ivec2(floor(cell_f));
    vec2 cell_fract = fract(cell_f);

    // Start with background color
    vec3 col = BG_COLOR;
    float alpha_out = 1.0;

    // === PCB PATTERN (zoom > 0.15) ===
    if (zoom_level > 0.15) {
        float pcb_fade = clamp((zoom_level - 0.15) / 0.25, 0.0, 1.0);

        // Determine LOD step for PCB (skip cells at low zoom)
        int step = 1;
        if (zoom_level < 0.3) step = 4;
        else if (zoom_level < 0.5) step = 2;

        // Align cell to step grid
        ivec2 aligned = ivec2(cell.x - ((cell.x % step + step) % step),
                              cell.y - ((cell.y % step + step) % step));

        // --- Horizontal traces ---
        int hx = aligned.x;
        int hy = aligned.y;
        int h = pcb_hash(hx, hy, 1);
        if (h % 11 == 0) {
            int len = (1 + (h >> 4) % 3) * step;
            // Check if this pixel is on the trace line (y near cell edge)
            float dy = abs(cell_fract.y) * tile_size;
            if (dy < 1.5) {
                // Check x range
                float trace_start = float(hx) * tile_size;
                float trace_end = float(hx + len) * tile_size;
                if (world_pos.x >= trace_start && world_pos.x <= trace_end) {
                    col = mix(col, PCB_TRACE, 0.04 * pcb_fade);
                }
            }
        }
        // Also check trace from cell above (y = cell.y, trace starts at cell above)
        int hy2 = aligned.y - step;
        int h2 = pcb_hash(aligned.x, hy2, 1);
        if (h2 % 11 == 0) {
            int len2 = (1 + (h2 >> 4) % 3) * step;
            float dy2 = abs(1.0 - cell_fract.y) * tile_size;
            if (dy2 < 1.5) {
                float ts = float(aligned.x) * tile_size;
                float te = float(aligned.x + len2) * tile_size;
                if (world_pos.x >= ts && world_pos.x <= te) {
                    col = mix(col, PCB_TRACE, 0.04 * pcb_fade);
                }
            }
        }

        // --- Vertical traces ---
        int hv = pcb_hash(aligned.x, aligned.y, 2);
        if (hv % 13 == 0) {
            int vlen = (1 + (hv >> 4) % 3) * step;
            float dx = abs(cell_fract.x) * tile_size;
            if (dx < 1.5) {
                float ts = float(aligned.y) * tile_size;
                float te = float(aligned.y + vlen) * tile_size;
                if (world_pos.y >= ts && world_pos.y <= te) {
                    col = mix(col, PCB_TRACE, 0.04 * pcb_fade);
                }
            }
        }

        // --- Via points (zoom > 0.3) ---
        if (zoom_level > 0.3) {
            // Check nearest grid vertex
            vec2 nearest_vertex = round(cell_f) * tile_size;
            ivec2 nv = ivec2(round(cell_f));
            int vh = pcb_hash(nv.x, nv.y, 3);
            if (vh % 19 == 0) {
                float dist = length(world_pos - nearest_vertex);
                if (dist < 3.5) {
                    col = mix(col, PCB_VIA, 0.06 * pcb_fade);
                } else if (dist < 6.0 && dist > 4.5) {
                    col = mix(col, PCB_VIA, 0.035 * pcb_fade);
                }
            }
        }

        // --- Component pads (zoom > 0.25) ---
        if (zoom_level > 0.25) {
            int ph = pcb_hash(cell.x, cell.y, 4);
            if (ph % 29 == 0) {
                vec2 pad_center = (vec2(cell) + 0.5) * tile_size;
                vec2 pad_d = abs(world_pos - pad_center);
                if (pad_d.x < 5.0 && pad_d.y < 5.0) {
                    col = mix(col, PCB_PAD, 0.035 * pcb_fade);
                    // Border
                    if (pad_d.x > 4.0 || pad_d.y > 4.0) {
                        col = mix(col, PCB_PAD, 0.05 * pcb_fade);
                    }
                }
            }
        }
    }

    // === GRID LINES ===
    // Adaptive grid step based on zoom
    float grid_step = 1.0;
    if (zoom_level < 0.1) grid_step = 16.0;
    else if (zoom_level < 0.2) grid_step = 8.0;
    else if (zoom_level < 0.4) grid_step = 4.0;
    else if (zoom_level < 0.8) grid_step = 2.0;

    float line_dist = grid_line_dist(world_pos, grid_step);
    // Line width in world pixels — bold grid lines
    float line_width = clamp(3.5 / zoom_level, 2.5, 90.0);

    if (line_dist < line_width * 0.5) {
        float t = 1.0 - smoothstep(0.0, line_width * 0.5, line_dist);
        col = mix(col, GRID_COLOR, t * 0.95);
    }

    // === UNDERGLOW (GPU-driven building/cable glow) ===
    vec2 ug_uv = mod(cell_f, underglow_tex_size) / underglow_tex_size;
    vec4 ug = texture(underglow_tex, ug_uv);
    if (ug.a > 0.01) {
        float ug_scale = clamp(1.0 / zoom_level, 1.0, 3.0);
        float ug_intensity = 0.06 * ug_scale * ug.a;
        col = mix(col, ug.rgb, min(ug_intensity, 0.2));
        if (zoom_level > 0.4 && ug.a > 0.8) {
            vec2 cf = fract(cell_f);
            float border = max(
                smoothstep(0.04, 0.0, cf.x) + smoothstep(0.96, 1.0, cf.x),
                smoothstep(0.04, 0.0, cf.y) + smoothstep(0.96, 1.0, cf.y)
            );
            col = mix(col, ug.rgb, min(border * 0.04, 0.1));
        }
    }

    COLOR = vec4(col, alpha_out);
}
