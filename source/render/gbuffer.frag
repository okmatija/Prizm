#version 330 core
layout (location = 0) out vec4 gbuffer_position;
layout (location = 1) out vec4 gbuffer_normal;
layout (location = 2) out vec4 gbuffer_base_color;

in vec3 frag_position_world;
in vec3 normal_world;

uniform vec4 base_color;

void main() {    

    gbuffer_position.rgb = frag_position_world;
    gbuffer_position.a = 1;

    gbuffer_normal.rgb = normalize(normal_world); // nocommit Move normalize to vertex shader??
    gbuffer_normal.a = 1;

    gbuffer_base_color = base_color;
}