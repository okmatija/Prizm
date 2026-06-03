#version 450

// Frontface modes — must match Frontface_Style.Color_Mode in display_info.jai
const uint FM_PICKED = 0;
const uint FM_VERTEX = 1;
const uint FM_NORMAL = 2;

// Backface modes — must match Backface_Style.Color_Mode in display_info.jai
const uint BM_PICKED = 0;
const uint BM_COPIED = 1;
const uint BM_DARKEN = 2;
const uint BM_DITHER = 3;

// Fragment uniform buffer slot 0 (set = 3 per SDL3 GPU SPIR-V convention)
layout(set = 3, binding = 0) uniform Clip_UBO {
    vec4  clip_sphere;           // xyz=center, w=radius
    vec4  clip_sphere_prev;      // xyz=center, w=radius
    uvec4 clip_flags;            // x=sphere_active, y=clip_radius_mode
    vec4  range_normal[3];       // xyz=normal, w=unused
    vec4  range_min_max[3];      // x=min, y=max, z=1.0 if active else 0.0, w=unused
};

// Fragment uniform buffer slot 1
layout(set = 3, binding = 1) uniform Triangle_Style_UBO {
    vec4  color;                          // rgba
    vec4  edges_color;                    // rgba
    vec4  backface_color_wave;            // xyz=backface_rgb, w=wave
    vec4  look_dir_edges_width;           // xyz=look_direction, w=edges_width
    uvec4 style_flags;   // x=frontface_mode, y=backface_mode, z=flat_shading, w=backface_visible
};

layout(location = 0) in vec3 frag_position_ws;
layout(location = 1) in vec3 frag_smooth_normal_ws;
layout(location = 2) in vec3 frag_face_normal_ws;
layout(location = 3) noperspective in vec3 frag_barycentric;
layout(location = 4) in vec3 frag_color;

layout(location = 0) out vec4 out_color;

const float EPSILON = 1e-10;

// ---- colour helpers (same as original triangles.frag) ----

vec3 HUEtoRGB(float hue) {
    vec3 rgb = abs(hue * 6.0 - vec3(3.0, 2.0, 4.0)) * vec3(1.0, -1.0, -1.0) + vec3(-1.0, 2.0, 2.0);
    return clamp(rgb, 0.0, 1.0);
}

vec3 RGBtoHCV(vec3 rgb) {
    vec4 p = (rgb.g < rgb.b) ? vec4(rgb.bg, -1.0, 2.0/3.0) : vec4(rgb.gb, 0.0, -1.0/3.0);
    vec4 q = (rgb.r < p.x)  ? vec4(p.xyw, rgb.r)          : vec4(rgb.r, p.yzx);
    float c = q.x - min(q.w, q.y);
    float h = abs((q.w - q.y) / (6.0 * c + EPSILON) + q.z);
    return vec3(h, c, q.x);
}

vec3 HSVtoRGB(vec3 hsv) {
    return ((HUEtoRGB(hsv.x) - 1.0) * hsv.y + 1.0) * hsv.z;
}

vec3 RGBtoHSV(vec3 rgb) {
    vec3 hcv = RGBtoHCV(rgb);
    return vec3(hcv.x, hcv.y / (hcv.z + EPSILON), hcv.z);
}

vec3 darken(vec3 col, float factor) {
    vec3 hsv = RGBtoHSV(col);
    hsv.z *= factor;
    return HSVtoRGB(hsv);
}

// ---- lighting ----

vec3 blinn_phong(vec3 N, vec3 V, vec3 L, vec3 diff_col) {
    const vec3  light_color = vec3(1.0);
    const float light_power = 1.0;
    const vec3  spec_color  = vec3(1.0);
    const float shininess   = 16.0;

    float n_dot_l = clamp(dot(N, L), 0.0, 1.0);
    float spec    = 0.0;
    if (n_dot_l > 0.0) {
        float n_dot_h = clamp(dot(N, normalize(V + L)), 0.0, 1.0);
        spec = pow(n_dot_h, shininess);
    }
    return light_color * light_power * (diff_col * n_dot_l + spec_color * spec);
}

void main() {
    float wave            = backface_color_wave.w;
    vec3  look_direction  = look_dir_edges_width.xyz;
    float edges_width     = look_dir_edges_width.w;
    uint  frontface_mode  = style_flags.x;
    uint  backface_mode   = style_flags.y;
    bool  flat_shading    = style_flags.z != 0u;
    bool  backface_visible = style_flags.w != 0u;
    bool  sphere_active   = clip_flags.x != 0u;
    bool  clip_radius_mode = clip_flags.y != 0u;

    // ---- backface culling ----
    if (!gl_FrontFacing && !backface_visible) discard;

    // ---- clip ranges ----
    for (int i = 0; i < 3; ++i) {
        if (range_min_max[i].z > 0.5) {
            float d = dot(range_normal[i].xyz, frag_position_ws);
            if (d <= range_min_max[i].x || d >= range_min_max[i].y) discard;
        }
    }

    // ---- clip sphere ----
    float clip_darken = 1.0;
    if (sphere_active) {
        float d     = distance(clip_sphere.xyz,      frag_position_ws);
        float d_prev = distance(clip_sphere_prev.xyz, frag_position_ws);
        bool outside      = d      > clip_sphere.w;
        bool outside_prev = d_prev > clip_sphere_prev.w;
        if (outside) {
            if (clip_radius_mode) {
                if (outside_prev) discard;
                else clip_darken = 0.4;
            } else {
                discard;
            }
        }
    }

    // ---- shading ----
    vec3 N = flat_shading ? frag_face_normal_ws : frag_smooth_normal_ws;
    if (!gl_FrontFacing) N = -N;

    vec4 fill_color = color;

    vec3 V = normalize(look_direction);
    vec3 L = normalize(-look_direction);
    const float gamma = 2.2;

    if (frontface_mode == FM_PICKED) {
        vec3 diff = fill_color.xyz;
        if (!gl_FrontFacing && backface_mode == BM_PICKED) {
            diff = backface_color_wave.xyz;
            fill_color = vec4(diff, 1.0);
        }
        vec3 lit = blinn_phong(N, V, L, diff);
        vec4 gamma_corrected = vec4(pow(lit, vec3(1.0/gamma)), 1.0);
        fill_color = mix(gamma_corrected, vec4(0.8), wave * 0.5 + 0.5);

    } else if (frontface_mode == FM_VERTEX) {
        vec3 diff = frag_color;
        if (!gl_FrontFacing && backface_mode == BM_PICKED) {
            diff = backface_color_wave.xyz;
            fill_color = vec4(diff, 1.0);
        }
        vec3 lit = blinn_phong(N, V, L, diff);
        vec4 gamma_corrected = vec4(pow(lit, vec3(1.0/gamma)), 1.0);
        fill_color = mix(gamma_corrected, vec4(0.8), wave * 0.5 + 0.5);

    } else { // FM_NORMAL
        if (!gl_FrontFacing && backface_mode == BM_PICKED) {
            vec3 diff = backface_color_wave.xyz;
            vec3 lit  = blinn_phong(N, V, L, diff);
            vec4 gc   = vec4(pow(lit, vec3(1.0/gamma)), 1.0);
            fill_color = mix(gc, vec4(0.8), wave * 0.5 + 0.5);
        } else {
            fill_color = mix(vec4(N * 0.5 + 0.5, 1.0), vec4(1.0), wave * 0.5 + 0.5);
        }
    }

    // ---- backface modifiers ----
    if (!gl_FrontFacing) {
        float darken_factor = (frontface_mode == FM_PICKED) ? 0.5 : 0.6;
        if (backface_mode == BM_DARKEN) {
            fill_color.xyz = darken(fill_color.xyz, darken_factor);
        } else if (backface_mode == BM_DITHER) {
            fill_color.xyz = darken(fill_color.xyz, darken_factor);
            if (int(gl_FragCoord.x) % 3 == 0 && int(gl_FragCoord.y) % 3 == 0)
                fill_color.xyz = darken(fill_color.xyz, 1.0 / darken_factor);
        }
    }

    // ---- solid wireframe via barycentric fwidth ----
    if (edges_width > 0.0) {
        float min_bary = min(frag_barycentric.x, min(frag_barycentric.y, frag_barycentric.z));
        float fw = fwidth(min_bary);
        float d  = min_bary / (fw * max(1.0, edges_width));
        float I  = exp2(-2.0 * d * d);
        vec4 line_color = mix(edges_color, vec4(1.0), wave * 0.5 + 0.5);
        fill_color = I * line_color + (1.0 - I) * fill_color;
    }

    out_color   = fill_color;
    out_color.xyz = darken(out_color.xyz, clip_darken);
    out_color.w = color.w; // respect input alpha for blending
}
