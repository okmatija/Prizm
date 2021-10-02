#version 330 core

layout (location = 0) in vec3 in_vertex;
layout (location = 1) in vec3 in_normal;

out VERTEX_SHADER_OUT {
    vec3 normal;
} vert_out;

uniform mat4 world_from_model;
uniform mat4 view_from_world;

void main() {
    mat4 view_from_model = view_from_world * world_from_model;
    gl_Position = view_from_model * vec4(in_vertex, 1.);
    vert_out.normal = normalize((transpose(inverse(view_from_model)) * vec4(in_normal, 0.)).xyz);
}