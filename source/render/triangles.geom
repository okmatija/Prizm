#version 330 core

uniform vec2 window_size;

in VS_Out {
    vec3 vertex_normal_ws;
    vec3 fragment_position_ws;
    vec3 vertex_color;
} gs_in[];

out vec3 vertex_normal_ws;
out vec3 vertex_color;
out vec3 triangle_normal_ws; // Computed for flat shading
out vec3 fragment_position_ws;
noperspective out vec3 dist; // Distance from each triangle edge. Used to render anti-aliased triangle edges on the actual triangle

layout (triangles) in;
layout (triangle_strip, max_vertices = 3) out;

void main() {

    vec3 a = gs_in[0].fragment_position_ws;
    vec3 b = gs_in[1].fragment_position_ws;
    vec3 c = gs_in[2].fragment_position_ws;
    triangle_normal_ws = normalize(cross(b - a, c - a));

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
    vertex_color = gs_in[0].vertex_color;
    fragment_position_ws = gs_in[0].fragment_position_ws;
    EmitVertex();

    dist = vec3(0, area / length(v1), 0);
    gl_Position = gl_in[1].gl_Position;
    vertex_normal_ws = gs_in[1].vertex_normal_ws;
    vertex_color = gs_in[1].vertex_color;
    fragment_position_ws = gs_in[1].fragment_position_ws;
    EmitVertex();

    dist = vec3(0, 0, area / length(v2));
    gl_Position = gl_in[2].gl_Position;
    vertex_normal_ws = gs_in[2].vertex_normal_ws;
    vertex_color = gs_in[2].vertex_color;
    fragment_position_ws = gs_in[2].fragment_position_ws;
    EmitVertex();

    EndPrimitive();
}