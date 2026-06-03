#version 450

// Color modes — must match Color_Mode in display_info.jai
const uint COLOR_PICKED = 0;
const uint COLOR_VERTEX = 1;

// Clip modes — must match Clip_Mode in display_info.jai
const uint CLIP_HIDDEN  = 0;
const uint CLIP_BLACKEN = 1;
const uint CLIP_DARKEN  = 2;

layout(set = 3, binding = 0) uniform Clip_UBO {
    vec4  clip_sphere;      // xyz=center, w=radius
    vec4  clip_sphere_prev; // unused here
    uvec4 clip_flags;       // x=sphere_active, y=clip_radius_mode (unused for lines)
    vec4  range_normal[3];
    vec4  range_min_max[3]; // x=min, y=max, z=active_as_float
};

layout(set = 3, binding = 1) uniform PL_Style_UBO {
    vec4  color;        // rgba
    uvec4 style_flags;  // x=color_mode, y=clip_mode
    vec4  wave_pad;     // x=wave
};

layout(location = 0) in vec3 frag_position_ws;
layout(location = 1) in vec3 frag_color;

layout(location = 0) out vec4 out_color;

void main() {
    float wave      = wave_pad.x;
    uint  color_mode = style_flags.x;
    uint  clip_mode  = style_flags.y;
    bool  sphere_active = clip_flags.x != 0u;

    vec4 used_color = (color_mode == COLOR_VERTEX) ? vec4(frag_color, 1.0) : color;

    // ---- clip ranges ----
    for (int i = 0; i < 3; ++i) {
        if (range_min_max[i].z > 0.5) {
            float d = dot(range_normal[i].xyz, frag_position_ws);
            if (d <= range_min_max[i].x || d >= range_min_max[i].y) {
                if      (clip_mode == CLIP_HIDDEN)  discard;
                else if (clip_mode == CLIP_BLACKEN) { used_color = vec4(0.0, 0.0, 0.0, 1.0); break; }
            }
        }
    }

    // ---- clip sphere ----
    if (sphere_active) {
        float dist = distance(clip_sphere.xyz, frag_position_ws);
        if (dist > clip_sphere.w) {
            if      (clip_mode == CLIP_HIDDEN)  discard;
            else if (clip_mode == CLIP_BLACKEN) used_color = vec4(0.0, 0.0, 0.0, 1.0);
        }
    }

    out_color   = mix(used_color, vec4(1.0), wave * 0.5 + 0.5);
    out_color.w = used_color.w;
}
