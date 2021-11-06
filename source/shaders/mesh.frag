#version 330 core

struct Camera {
    vec3 eye_position;
};

uniform float wave; // time varying value in range [-1,1]
uniform Camera camera;
uniform int display_mode = 0;
uniform vec4 color; // rgba
uniform bool screentone_backfaces = true;
uniform bool flat_shading = true;
uniform vec4 wireframe_color; // rgba
uniform float wireframe_width;

// @Volatile Keep synced with Jai
struct Clip_Range {
    vec3 normal;
    bool is_active;
    float min;
    float max;
};
uniform Clip_Range clip_range[3];

// @Volatile Keep synced with Jai
struct Clip_Sphere {
    vec3 center;
    float radius;
    bool is_active;
};
uniform Clip_Sphere clip_sphere;

uniform bool clipping_sphere_mode;

in vec3 vertex_normal_ws;
in vec3 fragment_position_ws;
noperspective in vec3 dist;

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

vec3 HSLtoRGB(in vec3 hsl)
{
    // Hue-Saturation-Lightness [0..1] to RGB [0..1]
    vec3 rgb = HUEtoRGB(hsl.x);
    float c = (1. - abs(2. * hsl.z - 1.)) * hsl.y;
    return (rgb - 0.5) * c + hsl.z;
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

    float clipping_sphere_darken_factor = 1.;
    if (clip_sphere.is_active) {
        float dist = distance(clip_sphere.center, fragment_position_ws);
        if (dist > clip_sphere.radius) {
            if (clipping_sphere_mode) {
                clipping_sphere_darken_factor = .4;
            } else {
                discard;
            }
        }
    }

    vec3 N = vertex_normal_ws;
    if (flat_shading) {
        vec3 x_tangent = dFdx(fragment_position_ws);
        vec3 y_tangent = dFdy(fragment_position_ws);
        N = normalize(cross(x_tangent, y_tangent));
        if (!gl_FrontFacing) {
            N *= -1;
        }
    }

    vec4 fill_color = vec4(1, 1, 1, 1);
    vec4 line_color = mix(wireframe_color, vec4(1.f), wave * .5f + .5f);
    switch (display_mode) {

        // Normal shading
        case 0: {

            fill_color = mix(vec4(N, 1.f) * .5f + .5f, vec4(1.f), wave * .5f + .5f);

        } break;

        // Solid color
        case 1: {

            fill_color = mix(color, vec4(1.f), wave * .5f + .5f);

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
            fill_color = mix(color_gamma_corrected, vec4(.8,.8,.8,1), wave * .5f + .5f);

        } break;
    }

    if (wireframe_width > 0.) {
        float d = min(dist[0], min(dist[1], dist[2]));
        d /= max(1., wireframe_width);
        float I = exp2(-2*d*d);
        out_color = I*line_color + (1. - I)*fill_color;
    } else {
        out_color = fill_color;
    }

    // TODO: modify the input color instead so we get lighting on the screentone pixels too

    if (!gl_FrontFacing) {
        float darken_factor = (display_mode == 0 ? .5 : .6);

        // Darken backfaces
        vec3 hsv = RGBtoHSV(out_color.xyz);
        hsv.z *= darken_factor;
        out_color.xyz = HSVtoRGB(hsv);

        if (screentone_backfaces) {
            if (int(gl_FragCoord.x) % 3 == 0 && int(gl_FragCoord.y) % 3 == 0) {
                vec3 hsv = RGBtoHSV(out_color.xyz);
                hsv.z *= darken_factor;
                out_color.xyz = HSVtoRGB(hsv);
            }
        }
    }

    if (clipping_sphere_mode) {
        // Darken
        vec3 hsv = RGBtoHSV(out_color.xyz);
        hsv.z *= clipping_sphere_darken_factor;
        out_color.xyz = HSVtoRGB(hsv);
    }

    // Respect blending of input color
    out_color.w = color.w;
}