#version 330 core
layout (location = 0) in vec4 vertex; // xy is pos, zw are texture coords

out vec2 TextureCoords;

uniform mat4 clip_from_view;

void main()
{
    gl_Position = clip_from_view * vec4(vertex.xy, 0.0, 1.0);
    TextureCoords = vertex.zw;
}