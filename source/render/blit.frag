// nocommit rename this file 

#version 330 core

out vec4 frag_color;

in vec2 tex_coords;
const int Debug_Channel_GBUFFER_BASE_COLOR = 0;
const int Debug_Channel_GBUFFER_NORMAL = 1;
const int Debug_Channel_GBUFFER_POSITION = 2;
const int Debug_Channel_SSAO_COLOR = 3;
const int Debug_Channel_SSAO_COLOR_BLURRED = 4;


uniform int channel = Debug_Channel_GBUFFER_NORMAL;
uniform sampler2D screen_texture;

void main() {
    //frag_color = vec4(tex_coords.x, tex_coords.y, 0, 1);

    if (channel == Debug_Channel_GBUFFER_BASE_COLOR) {

        vec3 sample = texture(screen_texture, tex_coords).rgb;
        frag_color = vec4(sample,1);

    } else if (channel == Debug_Channel_GBUFFER_NORMAL) {

        vec3 sample = texture(screen_texture, tex_coords).xyz;
        if (sample.x == 0 && sample.y == 0 && sample.z == 0) {
            discard;
        } else {
            vec3 visualized_normal = sample * 0.5 + 0.5; // Map from [-1, 1] to [0, 1]
            frag_color = vec4(visualized_normal, 1.0);
        }

    } else if (channel == Debug_Channel_GBUFFER_POSITION) {

        // Positions (World Space)
        vec3 sample = texture(screen_texture, tex_coords).xyz;
        vec3 visualized_color = sample;
        frag_color = vec4(visualized_color, 1);

    } else if (channel == Debug_Channel_SSAO_COLOR) {

        float sample = texture(screen_texture, tex_coords).r;
        frag_color = vec4(sample,sample,sample,1);

    } else if (channel == Debug_Channel_SSAO_COLOR_BLURRED) {

        float sample = texture(screen_texture, tex_coords).r;
        frag_color = vec4(sample,sample,sample,1);

    }

}