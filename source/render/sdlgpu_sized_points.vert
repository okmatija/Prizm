#version 450
// Sized-point quad expansion via instance drawing.
//
// Vertex (VERTEX rate, slot 0): corner ∈ {-1,+1}² — unit-square corner.
// Instance data (INSTANCE rate, slots 1 and 2):
//   in_center — point centre in model space.
//   in_color  — point colour.
//
// Six vertices per instance form two triangles covering the square.

layout(location = 0) in vec2 corner;    // (x, y) ∈ {-1,+1}²
layout(location = 1) in vec3 in_center;
layout(location = 2) in vec3 in_color;

layout(set = 1, binding = 0) uniform Sized_Point_Vert_UBO {
    mat4  clip_from_view;
    mat4  view_from_world;
    mat4  world_from_model;
    float prim_size_px; // point size in pixels
    float viewport_w;
    float viewport_h;
    float _pad;
};

layout(location = 0) out vec3 frag_position_ws;
layout(location = 1) out vec3 frag_color;

void main() {
    mat4 clip_from_model = clip_from_view * view_from_world * world_from_model;
    vec4 clip_center     = clip_from_model * vec4(in_center, 1.0);

    // Expand to screen-aligned square in clip space
    float half_px_ndc_x = (prim_size_px * 0.5) / viewport_w * 2.0;
    float half_px_ndc_y = (prim_size_px * 0.5) / viewport_h * 2.0;

    vec4 pos = clip_center;
    pos.x   += corner.x * half_px_ndc_x * pos.w;
    pos.y   += corner.y * half_px_ndc_y * pos.w;

    gl_Position      = pos;
    frag_position_ws = (world_from_model * vec4(in_center, 1.0)).xyz;
    frag_color       = in_color;
}
