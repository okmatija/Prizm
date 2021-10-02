#version 330 core

struct Camera {
    vec3 eye_position;
};

uniform float wave; // time varying value in range [-1,1]
uniform Camera camera;
uniform int display_mode = 0;
uniform vec4 color; // rgba
uniform bool screentone_backfaces = true;

// @Volatile Keep synced with Jai
struct Clip_Range {
    vec3 normal;
    bool is_active;
    float min;
    float max;
};
uniform Clip_Range clip_range[3];

in vec3 vertex_normal_ws;
in vec3 fragment_position_ws;

out vec4 out_color;

struct Point_Light {
    vec3  position;
    vec3  color;
    float power;
};

const int POINT_LIGHT_COUNT = 4;
Point_Light point_lights[POINT_LIGHT_COUNT] = Point_Light[POINT_LIGHT_COUNT](
    Point_Light(vec3( 500,  500,  500), vec3(1), .1),
    Point_Light(vec3(-500, -500,  250), vec3(1), .1),
    Point_Light(vec3( 250, -500, -500), vec3(1), .1),
    Point_Light(vec3(   0,  500, -500), vec3(1), .1)
);

struct Directional_Light {
    vec3  direction;
    vec3  color;
    float power;
};

const int DIRECTIONAL_LIGHT_COUNT = 1;
Directional_Light directional_lights[DIRECTIONAL_LIGHT_COUNT] = Directional_Light[DIRECTIONAL_LIGHT_COUNT](
    Directional_Light(vec3(0,  0,  1), vec3(1), .2)
);

vec3 ambient_color   = 0.5 * color.xyz;
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

    vec3 N = vertex_normal_ws;

    switch (display_mode) {

        // Normal shading
        case 0: {

            out_color = mix(vec4(N, 1.f) * .5f + .5f, vec4(1.f), wave * .5f + .5f);

        } break;

        // Solid color
        case 1: {

            out_color = mix(color, vec4(1.f), wave * .5f + .5f);

        } break;

        // Blinn-Phong shading
        case 2: {

            vec4 color_linear = vec4(0, 0, 0, 1);

            vec3 V = normalize(camera.eye_position - fragment_position_ws);

            for (int light_index = 0; light_index < DIRECTIONAL_LIGHT_COUNT; ++light_index) {
                Directional_Light light = directional_lights[light_index];
                vec3 L = normalize(-light.direction);
                color_linear.xyz += blinn_phong_brdf(N, V, L, light.color, light.power);
            }

            for (int light_index = 0; light_index < POINT_LIGHT_COUNT; ++light_index) {
                Point_Light light = point_lights[light_index];
                vec3 L = normalize(light.position - fragment_position_ws);
                color_linear.xyz += blinn_phong_brdf(N, V, L, light.color, light.power);
            }

            // // TODO: When changing shaders render the previous settings on half of the screen with the following:
            // if(gl_FragCoord.x < 400) { // e.g., for 800x600 viewport
            //     FragColor = vec4(1.0, 0.0, 0.0, 1.0);
            // } else {
            //     FragColor = vec4(0.0, 1.0, 0.0, 1.0);
            // }

            vec4 color_gamma_corrected = vec4(pow(ambient_color + color_linear.xyz, vec3(1 / gamma)), 1);
            out_color = mix(color_gamma_corrected, vec4(.8,.8,.8,1), wave * .5f + .5f);

        } break;
    }

    // TODO: modify the input color instead so we get lighting on the screentone pixels too
    if (screentone_backfaces && !gl_FrontFacing) {
        if (int(gl_FragCoord.x) % 3 == 0 && int(gl_FragCoord.y) % 3 == 0) {
            out_color = vec4(.3, .3, .3, .0);
        }
    }

    // Respect blending of input color
    out_color.w = color.w;
}