#version 330 core

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

uniform Clip_Range clip_range[3];
uniform Clip_Sphere clip_sphere;
uniform vec4 normals_color = vec4(0., 0., .8, 1.); // rgba

in vec3 fragment_position_ws;

out vec4 out_color;

const float EPSILON = 1e-10;

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

void main() {
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

    if (clip_sphere.is_active) {
        float dist = distance(clip_sphere.center, fragment_position_ws);
        if (dist > clip_sphere.radius) {
            discard;
        }
    }

    out_color = normals_color;
}