#version 330 core

layout (location = 0) in vec3 in_vertex;
layout (location = 3) in vec3 in_color;

uniform mat4 world_from_model;
uniform mat4 view_from_world;
uniform mat4 clip_from_view;
uniform float point_size;

out vec3 fragment_position_ws;
out vec3 fragment_color;

void main() {
    mat4 clip_from_model = clip_from_view * view_from_world * world_from_model;

    fragment_position_ws = (world_from_model * vec4(in_vertex, 1.)).xyz;
    fragment_color = in_color;

    gl_Position = clip_from_model * vec4(in_vertex, 1.);
    gl_PointSize = point_size;
}