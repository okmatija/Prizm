#version 330 core

out float occlusion_output;

in vec2 tex_coords;

uniform sampler2D occlusion_input;

void main() {

    vec2 texel_size = 1. / vec2(textureSize(occlusion_input, 0));
    float result = 0.0;
    for (int x = -2; x < 2; ++x) {
        for (int y = -2; y < 2; ++y) {

            vec2 offset = vec2(float(x), float(y)) * texel_size;
            result += texture(occlusion_input, tex_coords + offset).r;

        }
    }
    
    occlusion_output = result / (4.0 * 4.0);
}