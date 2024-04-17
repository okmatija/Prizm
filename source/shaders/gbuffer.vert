#version 330 core

layout (location = 0) in vec3 position_model;
layout (location = 1) in vec3 normal_model;

out vec3 frag_position_world;
out vec3 normal_world;

uniform mat4 world_from_model;
uniform mat4 view_from_world;
uniform mat4 clip_from_view;

void main() {

    vec4 position_world = world_from_model * vec4(position_model, 1.0);

    frag_position_world = position_world.xyz; 
    
    normal_world = transpose(inverse(mat3(world_from_model))) * normal_model;

    gl_Position = clip_from_view * view_from_world * position_world;
}