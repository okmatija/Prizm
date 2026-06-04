#version 450

layout(set = 3, binding = 0) uniform Normals_Frag_UBO {
    vec4  color;
    vec4  clip_sphere;      // xyz=center, w=radius
    uvec4 clip_flags;       // x=sphere_active
    vec4  range_normal[3];
    vec4  range_min_max[3]; // x=min, y=max, z=active_as_float
};

// NOTE: frag_position_ws is not passed from the vertex shader here —
// the original normals shader DID pass it for clipping. In the SDL GPU
// version we keep the logic but the clipping uses the base position
// (passed through as a varying from the vertex shader).
layout(location = 0) in  vec3 frag_position_ws;
layout(location = 0) out vec4 out_color;

void main() {
    // Clip ranges
    for (int i = 0; i < 3; ++i) {
        if (range_min_max[i].z > 0.5) {
            float d = dot(range_normal[i].xyz, frag_position_ws);
            if (d <= range_min_max[i].x || d >= range_min_max[i].y) discard;
        }
    }
    // Clip sphere
    if (clip_flags.x != 0u) {
        float d = distance(clip_sphere.xyz, frag_position_ws);
        if (d > clip_sphere.w) discard;
    }

    out_color = color;
}
