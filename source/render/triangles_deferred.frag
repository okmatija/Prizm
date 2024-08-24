#version 330 core

struct Camera {
    vec3 eye_position;
    vec3 look_direction;
};

out vec4 frag_color;

in vec2 tex_coords;

uniform Camera camera;

// GBuffer
// uniform sampler2D gbuffer_position;
uniform sampler2D gbuffer_normal;
uniform sampler2D gbuffer_base_color; // albedo
uniform sampler2D ssao;
uniform bool use_ssao;

vec3 ambient_color   = vec3(0.0);
vec3 specular_color  = vec3(1.0);
float shininess      = 16.;
float gamma          = 2.2;

vec3 blinn_phong_brdf(vec3 N, vec3 V, vec3 L, vec3 light_color, float light_power, vec3 diffuse_color) {
    float n_dot_l = clamp(dot(N, L), 0., 1.);

    float specular = 0;
    if (n_dot_l > 0.) {
        vec3 H = normalize(V + L);
        float n_dot_h = clamp(dot(N, H), 0., 1.);
        specular = pow(n_dot_h, shininess);
    }

    return light_color * light_power * (diffuse_color * n_dot_l + specular_color * specular);
}


void main()
{
    vec3 normal_world = texture(gbuffer_normal, tex_coords).rgb;

    if (normal_world == vec3(0)) {
        // nocommit Look up how to do #include type things
        discard; // nocommit Put the background shader in here!
    }

    // vec3 position_world = texture(gbuffer_position, tex_coords).rgb;

    float ambient_occlusion = 1.;
    if (use_ssao) {
        ambient_occlusion = texture(ssao, tex_coords).r;
    }

    //switch (display_mode)
    {
        //case Display_Mode_NORMAL:
        {
            // @Volatile @CopyPasta from NORMAL
            vec3 N = normal_world;
            // vec3 V = normalize(camera.eye_position - position_world);
            vec3 V = normalize(camera.look_direction); // This is the directional spotlight... Do we need the position texture in this shader then..???
            vec3 L = normalize(-camera.look_direction);
            vec3 light_color = vec3(1);
            float light_power = 1.;

            vec3 diffuse_color = texture(gbuffer_base_color, tex_coords).rgb; // nocommit vec4?
            ambient_color = .3 * diffuse_color * ambient_occlusion;
            vec4 color_linear = vec4(0, 0, 0, 1);
            color_linear.xyz += blinn_phong_brdf(N, V, L, light_color, light_power, diffuse_color);
            vec4 color_gamma_corrected = vec4(pow(ambient_color + color_linear.xyz, vec3(1 / gamma)), 1);
            frag_color = color_gamma_corrected;
        }
    }

}
