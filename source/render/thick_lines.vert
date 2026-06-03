#version 450
// Thick-line quad expansion via instance drawing.
//
// Vertex (VERTEX rate, slot 0): (t, side) — a 2-float corner descriptor.
//   t    ∈ {0, 1} selects endpoint A (segment start) or B (segment end).
//   side ∈ {-1, +1} selects which side of the line the quad corner sits on.
//
// Instance data (INSTANCE rate, slots 1 and 2):
//   in_pos_a / in_pos_b  — segment endpoints in model space.
//   in_color_a / in_color_b — per-endpoint colours for VERTEX colour mode.
//
// Six vertices per instance form two triangles that cover the line rectangle.

layout(location = 0) in vec2 corner;       // (t, side)
layout(location = 1) in vec3 in_pos_a;     // model-space segment start
layout(location = 2) in vec3 in_pos_b;     // model-space segment end
layout(location = 3) in vec3 in_color_a;
layout(location = 4) in vec3 in_color_b;

layout(set = 1, binding = 0) uniform Thick_Vert_UBO {
    mat4  clip_from_view;
    mat4  view_from_world;
    mat4  world_from_model;
    float prim_size_px; // line width in pixels
    float viewport_w;
    float viewport_h;
    float _pad;
};

layout(location = 0) out vec3 frag_position_ws;
layout(location = 1) out vec3 frag_color;

void main() {
    float t    = corner.x;
    float side = corner.y;

    mat4 clip_from_model = clip_from_view * view_from_world * world_from_model;

    vec4 clip_a = clip_from_model * vec4(in_pos_a, 1.0);
    vec4 clip_b = clip_from_model * vec4(in_pos_b, 1.0);

    // NDC positions for direction computation
    vec2 ndc_a = clip_a.xy / clip_a.w;
    vec2 ndc_b = clip_b.xy / clip_b.w;

    // Direction in screen (pixel) space to get correct angle
    vec2 screen_dir = (ndc_b - ndc_a) * vec2(viewport_w, viewport_h);
    float len = length(screen_dir);
    if (len > 0.001) screen_dir /= len;
    else             screen_dir  = vec2(1.0, 0.0);

    vec2 perp_screen = vec2(-screen_dir.y, screen_dir.x);

    // Perpendicular offset in NDC units
    vec2 perp_ndc = perp_screen / vec2(viewport_w, viewport_h);
    float half_w  = prim_size_px * 0.5;
    perp_ndc     *= half_w;

    vec4 clip_base = mix(clip_a, clip_b, t);
    // Apply offset in clip space (multiply by w to cancel perspective divide)
    clip_base.xy  += perp_ndc * 2.0 * side * clip_base.w;

    gl_Position      = clip_base;
    frag_position_ws = (world_from_model * vec4(mix(in_pos_a, in_pos_b, t), 1.0)).xyz;
    frag_color       = mix(in_color_a, in_color_b, t);
}
