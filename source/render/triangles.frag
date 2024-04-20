#version 330 core

struct Camera {
    vec3 look_direction;
};

struct Clip_Range {
    vec3 normal;
    bool is_active;
    float min;
    float max;
};

struct Clip_Sphere {
    vec3 center;
    float radius;
    bool is_active;
};

// @Cleanup Use these structs rather than having data floating around
//struct Edge_Style {
//    vec4 color;
//    float width;
//};
//
//struct Triangle_Style {
//    vec4 color;
//    int display_mode;
//    int backface_mode;
//    bool flat_shading;
//    Edge_Style edge_style;
//};

const int Display_Mode_NORMALS = 0;
const int Display_Mode_BLINN_PHONG = 1;

const int Backface_Mode_NONE = 0;
const int Backface_Mode_CULL = 1;
const int Backface_Mode_FIXED = 2;
const int Backface_Mode_DARKEN = 3;
const int Backface_Mode_SCREENTONE_1 = 4;
const int Backface_Mode_SCREENTONE_2 = 5;

uniform float wave; // time varying value in range [-1,1]
uniform Camera camera;

uniform int display_mode = Display_Mode_NORMALS;
uniform int backface_mode = Backface_Mode_FIXED;
uniform bool flat_shading = true;
uniform vec4 color; // rgba
uniform vec4 edges_color; // rgba
uniform float edges_width;

uniform vec4 backface_color = vec4(130./255, 63./255, 122./255, 1.); // rgba

uniform Clip_Range clip_range[3];
uniform Clip_Sphere clip_sphere;
uniform Clip_Sphere clip_sphere_prev;
uniform bool clip_radius_mode = false;

in vec3 vertex_normal_ws;
in vec3 triangle_normal_ws;
in vec3 fragment_position_ws;
noperspective in vec3 dist;

out vec4 out_color;

const float EPSILON = 1e-10;

vec3 ambient_color   = vec3(0.0);
vec3 diffuse_color   = color.xyz;
vec3 specular_color  = vec3(1.0);
float shininess      = 16.;
float gamma          = 2.2;

vec3 blinn_phong_brdf(vec3 N, vec3 V, vec3 L, vec3 light_color, float light_power) {
    float n_dot_l = clamp(dot(N, L), 0., 1.);

    float specular = 0;
    if (n_dot_l > 0.) {
        vec3 H = normalize(V + L);
        float n_dot_h = clamp(dot(N, H), 0., 1.);
        specular = pow(n_dot_h, shininess);
    }

    return light_color * light_power * (diffuse_color * n_dot_l + specular_color * specular);
}

vec3 get_normal() {
    vec3 N = vertex_normal_ws;
    if (flat_shading) {
        N = triangle_normal_ws;
    }
    if (!gl_FrontFacing) {
        N *= -1;
    }
    return N;
}

vec3 HUEtoRGB(in float hue)
{
    // Hue [0..1] to RGB [0..1]
    // See http://www.chilliant.com/rgb2hsv.html
    vec3 rgb = abs(hue * 6. - vec3(3, 2, 4)) * vec3(1, -1, -1) + vec3(-1, 2, 2);
    return clamp(rgb, 0., 1.);
}

vec3 RGBtoHCV(in vec3 rgb)
{
    // RGB [0..1] to Hue-Chroma-Value [0..1]
    // Based on work by Sam Hocevar and Emil Persson
    vec4 p = (rgb.g < rgb.b) ? vec4(rgb.bg, -1., 2. / 3.) : vec4(rgb.gb, 0., -1. / 3.);
    vec4 q = (rgb.r < p.x) ? vec4(p.xyw, rgb.r) : vec4(rgb.r, p.yzx);
    float c = q.x - min(q.w, q.y);
    float h = abs((q.w - q.y) / (6. * c + EPSILON) + q.z);
    return vec3(h, c, q.x);
}

vec3 HSVtoRGB(in vec3 hsv)
{
    // Hue-Saturation-Value [0..1] to RGB [0..1]
    vec3 rgb = HUEtoRGB(hsv.x);
    return ((rgb - 1.) * hsv.y + 1.) * hsv.z;
}

vec3 RGBtoHSV(in vec3 rgb)
{
    // RGB [0..1] to Hue-Saturation-Value [0..1]
    vec3 hcv = RGBtoHCV(rgb);
    float s = hcv.y / (hcv.z + EPSILON);
    return vec3(hcv.x, s, hcv.z);
}

vec3 darken(in vec3 color, float darken_factor)
{
    vec3 hsv = RGBtoHSV(color);
    hsv.z *= darken_factor;
    return HSVtoRGB(hsv);
}

void main() {

    if (!gl_FrontFacing) {
        if (backface_mode == Backface_Mode_CULL) {
            discard;
        }
    }

    for (int i = 0; i < 3; ++i) {
        if (clip_range[i].is_active) {
            float dist = dot(clip_range[i].normal, fragment_position_ws);
            float min = clip_range[i].min;
            float max = clip_range[i].max;
            if (dist <= min || dist >= max) {
                discard;
            }
        }
    }

    float clip_mode_darken_factor = 1.;

    if (clip_sphere.is_active) {
        float dist = distance(clip_sphere.center, fragment_position_ws);
        bool outside_clip_sphere = dist > clip_sphere.radius;

        float dist_prev = distance(clip_sphere_prev.center, fragment_position_ws);
        bool outside_clip_sphere_prev = dist_prev > clip_sphere_prev.radius;

        if (outside_clip_sphere) {
            if (clip_radius_mode) {
                if (outside_clip_sphere_prev) {
                    discard;
                } else {
                    clip_mode_darken_factor = .4;
                }
            } else {
                discard;
            }
        }
    }


    vec4 fill_color = color;

    switch (display_mode) {

        case Display_Mode_NORMALS: {

            if (!gl_FrontFacing && backface_mode == Backface_Mode_FIXED) {
                // @Volatile @CopyPasta from BLINN_PHONG
                vec3 N = get_normal();
                vec3 V = normalize(camera.look_direction);
                vec3 L = normalize(-camera.look_direction);
                vec3 light_color = vec3(1);
                float light_power = 1.;

                if (!gl_FrontFacing && (backface_mode == Backface_Mode_FIXED)) {
                    fill_color = backface_color;
                }
                diffuse_color = fill_color.xyz;
                vec4 color_linear = vec4(0, 0, 0, 1);
                color_linear.xyz += blinn_phong_brdf(N, V, L, light_color, light_power);
                vec4 color_gamma_corrected = vec4(pow(ambient_color + color_linear.xyz, vec3(1 / gamma)), 1);

                fill_color = mix(color_gamma_corrected, vec4(.8,.8,.8,1), wave * .5f + .5f);
            } else {
                vec3 N = get_normal();
                fill_color = mix(vec4(N, 1.f) * .5f + .5f, vec4(1.f), wave * .5f + .5f);
                if (!gl_FrontFacing && (backface_mode == Backface_Mode_FIXED)) {
                    fill_color = backface_color;
                }
            }

        } break;

        case Display_Mode_BLINN_PHONG: {

            // @Volatile @CopyPasta from NORMALS
            vec3 N = get_normal();
            vec3 V = normalize(camera.look_direction);
            vec3 L = normalize(-camera.look_direction);
            vec3 light_color = vec3(1);
            float light_power = 1.;

            if (!gl_FrontFacing && (backface_mode == Backface_Mode_FIXED)) {
                fill_color = backface_color;
            }
            diffuse_color = fill_color.xyz;
            vec4 color_linear = vec4(0, 0, 0, 1);
            color_linear.xyz += blinn_phong_brdf(N, V, L, light_color, light_power);
            vec4 color_gamma_corrected = vec4(pow(ambient_color + color_linear.xyz, vec3(1 / gamma)), 1);

            fill_color = mix(color_gamma_corrected, vec4(.8,.8,.8,1), wave * .5f + .5f);

        } break;

    }

    if (!gl_FrontFacing) {
        float darken_factor = (display_mode == 0 ? .5 : .6);

        switch (backface_mode) {

            // Darken frontface color
            case Backface_Mode_DARKEN: {
                fill_color.xyz = darken(fill_color.xyz, darken_factor);
                break;
            }

            // Darken frontface color and screentone dark
            case Backface_Mode_SCREENTONE_1: {
                fill_color.xyz = darken(fill_color.xyz, darken_factor);
                if (int(gl_FragCoord.x) % 3 == 0 && int(gl_FragCoord.y) % 3 == 0) {
                    fill_color.xyz = darken(fill_color.xyz, darken_factor);
                }
                break;
            }

            // Darken frontface color and screentone light
            case Backface_Mode_SCREENTONE_2: {
                fill_color.xyz = darken(fill_color.xyz, darken_factor);
                if (int(gl_FragCoord.x) % 3 == 0 && int(gl_FragCoord.y) % 3 == 0) {
                    fill_color.xyz = darken(fill_color.xyz, 1/darken_factor);
                }
                break;
            }

        }
    }

    if (edges_width > 0.) {
        float d = min(dist[0], min(dist[1], dist[2]));
        d /= max(1., edges_width);
        float I = exp2(-2*d*d);
        vec4 line_color = mix(edges_color, vec4(1.f), wave * .5f + .5f);
        out_color = I*line_color + (1. - I)*fill_color;
    } else {
        out_color = fill_color;
    }

    // Maybe Darken
    out_color.xyz = darken(out_color.xyz, clip_mode_darken_factor);

    // Respect blending of input color
    out_color.w = color.w;
}