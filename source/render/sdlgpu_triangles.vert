#version 450

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_smooth_normal;
layout(location = 2) in vec3 in_face_normal;
layout(location = 3) in vec3 in_barycentric;
layout(location = 4) in vec3 in_color;

// Vertex uniform buffer slot 0 (set = 1 per SDL3 GPU SPIR-V convention)
layout(set = 1, binding = 0) uniform Transform_UBO {
    mat4 clip_from_view;
    mat4 view_from_world;
    mat4 world_from_model;
};

layout(location = 0) out vec3 frag_position_ws;
layout(location = 1) out vec3 frag_smooth_normal_ws;
layout(location = 2) out vec3 frag_face_normal_ws;
layout(location = 3) noperspective out vec3 frag_barycentric;
layout(location = 4) out vec3 frag_color;

void main() {
    mat4 clip_from_model  = clip_from_view * view_from_world * world_from_model;
    mat4 normal_matrix    = transpose(inverse(world_from_model));

    frag_position_ws      = (world_from_model * vec4(in_position, 1.0)).xyz;
    frag_smooth_normal_ws = normalize((normal_matrix * vec4(in_smooth_normal, 0.0)).xyz);
    frag_face_normal_ws   = normalize((normal_matrix * vec4(in_face_normal,   0.0)).xyz);
    frag_barycentric      = in_barycentric;
    frag_color            = in_color;

    gl_Position = clip_from_model * vec4(in_position, 1.0);
}
