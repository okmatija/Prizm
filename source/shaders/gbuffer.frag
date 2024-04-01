#version 330 core
layout (location = 0) out vec3 gbuffer_position;
layout (location = 1) out vec3 gbuffer_normal;
layout (location = 2) out vec4 gbuffer_albedo;

in vec2 TexCoords;
in vec3 frag_position_world;
in vec3 normal_world;

uniform sampler2D texture_diffuse1;
uniform sampler2D texture_specular1;

void main()
{    
    gbuffer_position = frag_position_world;
    gbuffer_normal = normalize(normal_world); // nocommit Move normalize to vertex shader??
    gbuffer_albedo.rgb = texture(texture_diffuse1, TexCoords).rgb;
}