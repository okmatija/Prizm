#version 330 core

out vec4 frag_color;

in vec2 tex_coords;

const int GBuffer_Channel_BASE_COLOR = 0;
const int GBuffer_Channel_NORMAL = 1;
const int GBuffer_Channel_POSITION = 2;

uniform int channel = GBuffer_Channel_NORMAL;
uniform sampler2D screen_texture;

void main() {
    //frag_color = vec4(tex_coords.x, tex_coords.y, 0, 1);

    if (channel == GBuffer_Channel_BASE_COLOR) {

        vec3 sample = texture(screen_texture, tex_coords).rgb;
        frag_color = vec4(sample,1);

    } else if (channel == GBuffer_Channel_NORMAL) {

        vec3 sample = texture(screen_texture, tex_coords).xyz;
        if (sample.x == 0 && sample.y == 0 && sample.z == 0) {
            discard;
        } else {
            vec3 visualized_normal = sample * 0.5 + 0.5; // Map from [-1, 1] to [0, 1]
            frag_color = vec4(visualized_normal, 1.0);
        }

    } else if (channel == GBuffer_Channel_POSITION) {

        // Positions (Clip Space)
        vec3 sample = texture(screen_texture, tex_coords).xyz;
        // vec3 visualized_color = (sample + 10)/20; // Map from [-10, 10] to [0, 1]
        vec3 visualized_color = sample;
        // frag_color = vec4(vec3(visualized_color.z), 1.0);
        frag_color = vec4(visualized_color, 1);

    }
}