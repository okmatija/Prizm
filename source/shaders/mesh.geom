#version 330 core

uniform vec2 window_size;

in VS_Out {
    vec3 vertex_normal_ws;
    vec3 fragment_position_ws;
} gs_in[];

out vec3 vertex_normal_ws;
out vec3 fragment_position_ws;
noperspective out vec3 dist;

layout (triangles) in;
layout (triangle_strip, max_vertices = 3) out;

void main() {
    vec2 p0 = window_size * gl_in[0].gl_Position.xy / gl_in[0].gl_Position.w;
    vec2 p1 = window_size * gl_in[1].gl_Position.xy / gl_in[1].gl_Position.w;
    vec2 p2 = window_size * gl_in[2].gl_Position.xy / gl_in[2].gl_Position.w;

    vec2 v0 = p2 - p1;
    vec2 v1 = p2 - p0;
    vec2 v2 = p1 - p0;

    float area = abs(v1.x * v2.y - v1.y * v2.x);

    dist = vec3(area / length(v0), 0, 0);
    gl_Position = gl_in[0].gl_Position;
    vertex_normal_ws = gs_in[0].vertex_normal_ws;
    fragment_position_ws = gs_in[0].fragment_position_ws;
    EmitVertex();

    dist = vec3(0, area / length(v1), 0);
    gl_Position = gl_in[1].gl_Position;
    vertex_normal_ws = gs_in[1].vertex_normal_ws;
    fragment_position_ws = gs_in[1].fragment_position_ws;
    EmitVertex();

    dist = vec3(0, 0, area / length(v2));
    gl_Position = gl_in[2].gl_Position;
    vertex_normal_ws = gs_in[2].vertex_normal_ws;
    fragment_position_ws = gs_in[2].fragment_position_ws;
    EmitVertex();

    EndPrimitive();
}