#version 450

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_color;

layout(set = 1, binding = 0) uniform Transform_UBO {
    mat4 clip_from_view;
    mat4 view_from_world;
    mat4 world_from_model;
};

layout(location = 0) out vec3 frag_position_ws;
layout(location = 1) out vec3 frag_color;

void main() {
    mat4 clip_from_model = clip_from_view * view_from_world * world_from_model;
    frag_position_ws     = (world_from_model * vec4(in_position, 1.0)).xyz;
    frag_color           = in_color;
    gl_Position          = clip_from_model * vec4(in_position, 1.0);
}
