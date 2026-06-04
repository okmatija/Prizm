#version 450
// Generates 24 LINELIST vertices (12 edges × 2) from gl_VertexIndex.
// No vertex buffer — corner positions are computed from the AABB min/max uniforms.

layout(set = 1, binding = 0) uniform AABB_UBO {
    mat4 clip_from_view;
    mat4 view_from_world;
    mat4 world_from_model;
    vec4 aabb_min;   // xyz = min point
    vec4 aabb_max;   // xyz = max point
    vec4 color;
};

layout(location = 0) out vec4 frag_color;

void main() {
    vec3 mn = aabb_min.xyz;
    vec3 mx = aabb_max.xyz;

    // 8 corners labelled 0-7 as in the original aabb.vert
    vec4 v[8];
    v[0] = vec4(mn.x, mn.y, mn.z, 1.0);
    v[1] = vec4(mx.x, mn.y, mn.z, 1.0);
    v[2] = vec4(mn.x, mx.y, mn.z, 1.0);
    v[3] = vec4(mx.x, mx.y, mn.z, 1.0);
    v[4] = vec4(mn.x, mn.y, mx.z, 1.0);
    v[5] = vec4(mx.x, mn.y, mx.z, 1.0);
    v[6] = vec4(mn.x, mx.y, mx.z, 1.0);
    v[7] = vec4(mx.x, mx.y, mx.z, 1.0);

    // 12 edges × 2 endpoints = 24 vertex indices
    vec4 p;
    switch (gl_VertexIndex) {
        case  0: p = v[0]; break; case  1: p = v[1]; break;
        case  2: p = v[1]; break; case  3: p = v[3]; break;
        case  4: p = v[3]; break; case  5: p = v[2]; break;
        case  6: p = v[2]; break; case  7: p = v[0]; break;
        case  8: p = v[0]; break; case  9: p = v[4]; break;
        case 10: p = v[1]; break; case 11: p = v[5]; break;
        case 12: p = v[3]; break; case 13: p = v[7]; break;
        case 14: p = v[2]; break; case 15: p = v[6]; break;
        case 16: p = v[4]; break; case 17: p = v[5]; break;
        case 18: p = v[5]; break; case 19: p = v[7]; break;
        case 20: p = v[7]; break; case 21: p = v[6]; break;
        case 22: p = v[6]; break; default: p = v[4]; break;
    }

    gl_Position = clip_from_view * view_from_world * world_from_model * p;
    frag_color  = color;
}
