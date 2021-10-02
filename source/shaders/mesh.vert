#version 330 core

layout (location = 0) in vec3 in_vertex;
layout (location = 1) in vec3 in_normal;

uniform mat4 world_from_model;
uniform mat4 view_from_world;
uniform mat4 clip_from_view;
uniform float point_size;

out vec3 vertex_normal_ws;
out vec3 fragment_position_ws;

void main() {
    mat4 clip_from_model = clip_from_view * view_from_world * world_from_model;

    vertex_normal_ws = normalize((transpose(inverse(world_from_model)) * vec4(in_normal, 0.)).xyz);
    fragment_position_ws = (world_from_model * vec4(in_vertex, 1.)).xyz;

    gl_Position = clip_from_model * vec4(in_vertex, 1.);
    gl_PointSize = point_size;
}