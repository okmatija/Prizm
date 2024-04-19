#version 330 core

out vec4 frag_color;

in vec2 tex_coords;

uniform sampler2D screen_texture;

void main() {
    // Simple
    frag_color = texture(screen_texture, tex_coords);

    // Debug
    //frag_color = vec4(tex_coords.x, tex_coords.y, 0, 1);

    //// Positions (Clip Space)
    //vec3 sample = texture(screen_texture, tex_coords).xyz;
    //vec3 visualized_color = (sample + 10)/20; // Map from [-10, 10] to [0, 1]
    //frag_color = vec4(vec3(visualized_color.z), 1.0);

    // Normals
    vec3 sample = texture(screen_texture, tex_coords).xyz;
    if (sample.x == 0 && sample.y == 0 && sample.z == 0) {
        discard;
    } else {
        vec3 visualized_normal = sample * 0.5 + 0.5; // Map from [-1, 1] to [0, 1]
        frag_color = vec4(visualized_normal, 1.0);
    }
}