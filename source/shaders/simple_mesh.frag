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

uniform float wave; // time varying value in range [-1,1]
uniform vec4 color; // rgba
uniform Clip_Range clip_range[3];
uniform Clip_Sphere clip_sphere;

const int Clip_Mode_HIDDEN =  0;
const int Clip_Mode_BLACKEN = 1;
const int Clip_Mode_DARKEN =  2;
uniform int clip_mode = Clip_Mode_HIDDEN;

in vec3 fragment_position_ws;

out vec4 out_color;

void main() {
    vec4 used_color = color;

    for (int i = 0; i < 3; ++i) {
        if (clip_range[i].is_active) {
            float dist = dot(clip_range[i].normal, fragment_position_ws);
            float min = clip_range[i].min;
            float max = clip_range[i].max;
            if (dist <= min || dist >= max) {
                switch (clip_mode) {
                    case Clip_Mode_HIDDEN: {
                        discard;
                    } break;
                    case Clip_Mode_BLACKEN: {
                        used_color = vec4(0, 0, 0, 1);
                    } break;
                    case Clip_Mode_DARKEN: {
                        // @Incomplete
                    } break;
                }
            }
        }
    }

    if (clip_sphere.is_active) {
        float dist = distance(clip_sphere.center, fragment_position_ws);
        if (dist > clip_sphere.radius) {
            switch (clip_mode) {
                case Clip_Mode_HIDDEN: {
                    discard;
                } break;
                case Clip_Mode_BLACKEN: {
                    used_color = vec4(0, 0, 0, 1);
                } break;
                case Clip_Mode_DARKEN: {
                    // @Incomplete
                } break;
            }
        }
    }

    out_color = mix(used_color, vec4(1.f), wave * .5f + .5f);

    // Respect blending of input color
    out_color.w = used_color.w;
}