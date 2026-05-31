#version 450
// Normal-vector display shader: LINELIST where pairs of vertices share the same
// base_position and normal. gl_VertexIndex % 2 == 0 → base endpoint,
// gl_VertexIndex % 2 == 1 → tip endpoint (base + normal * scale).

layout(location = 0) in vec3 in_base;   // base position (model space)
layout(location = 1) in vec3 in_normal; // normal (model space)

layout(set = 1, binding = 0) uniform Normals_Vert_UBO {
    mat4  clip_from_view;
    mat4  view_from_world;
    mat4  world_from_model;
    float normal_scale;
    uint  do_normalize;   // 1 = normalize before scaling
    float _pad0;
    float _pad1;
};

layout(location = 0) out vec3 frag_position_ws;

void main() {
    float endpoint = float(gl_VertexIndex % 2);

    vec3 n = in_normal;
    if (do_normalize != 0u) n = normalize(n);

    vec3 pos     = in_base + endpoint * n * normal_scale;
    vec4 world   = world_from_model * vec4(pos, 1.0);
    frag_position_ws = world.xyz;
    gl_Position  = clip_from_view * view_from_world * world;
}
