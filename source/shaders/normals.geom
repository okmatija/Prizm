#version 330 core

layout (points) in;
layout (line_strip, max_vertices = 2) out;

in VERTEX_SHADER_OUT {
    vec3 normal;
} geom_in[];

uniform float normal_length = 1.;
uniform mat4 clip_from_view;

void normal_segment(int index) {
    vec4 base = gl_in[index].gl_Position;
    vec4 tip = base + vec4(geom_in[index].normal, 0.) * normal_length;

    gl_Position = clip_from_view * base;
    EmitVertex();
    gl_Position = clip_from_view * tip;
    EmitVertex();
    EndPrimitive();
}

void main() {
    normal_segment(0);
}