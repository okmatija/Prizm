#version 330 core
layout (location = 0) out vec4 gbuffer_position;
layout (location = 1) out vec4 gbuffer_normal;

in vec3 frag_position_world;
in vec3 normal_world;

void main() {    

    gbuffer_position.rgb = frag_position_world;
    gbuffer_position.a = 1;

    gbuffer_normal.rgb = normalize(normal_world); // nocommit Move normalize to vertex shader??
    gbuffer_normal.a = 1;

    // nocommit Set the color here to check..?
}