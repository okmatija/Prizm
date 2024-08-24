#version 330 core

layout (location = 0) in vec3 in_vertex;
layout (location = 1) in vec3 in_normal;
layout (location = 3) in vec3 in_color;

uniform mat4 world_from_model;
uniform mat4 view_from_world;
uniform mat4 clip_from_view;

out VS_Out {
    vec3 vertex_normal_ws;
    vec3 fragment_position_ws;
    vec3 vertex_color;
} vs_out;

void main() {
    mat4 clip_from_model = clip_from_view * view_from_world * world_from_model;

    vs_out.vertex_normal_ws = normalize((transpose(inverse(world_from_model)) * vec4(in_normal, 0.)).xyz);
    vs_out.fragment_position_ws = (world_from_model * vec4(in_vertex, 1.)).xyz;
    vs_out.vertex_color = in_color;

    gl_Position = clip_from_model * vec4(in_vertex, 1.);
}