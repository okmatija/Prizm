#version 330 core

layout (triangles) in;
layout (line_strip, max_vertices = 6) out;

in VERTEX_SHADER_OUT {
    vec3 normal;
    vec3 fragment_position_ws;
} gs_in[];

uniform float normal_style_scale = 1.;
uniform mat4 clip_from_view;

out vec3 fragment_position_ws;

void normal_segment(int index) {
    vec4 base = gl_in[index].gl_Position;
    vec4 tip = base + vec4(gs_in[index].normal * normal_style_scale, 0.);

    gl_Position = clip_from_view * base;
    fragment_position_ws = gs_in[index].fragment_position_ws;
    EmitVertex();
    gl_Position = clip_from_view * tip;
    fragment_position_ws = gs_in[index].fragment_position_ws;
    EmitVertex();
    EndPrimitive();
}

void main() {
    normal_segment(0);
    normal_segment(1);
    normal_segment(2);
}