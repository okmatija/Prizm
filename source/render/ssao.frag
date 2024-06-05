#version 330 core

out float frag_color;

in vec2 tex_coords;

uniform sampler2D tex_position;
uniform sampler2D tex_normal;
uniform sampler2D tex_noise;
uniform float window_width;
uniform float window_height;
uniform mat4 clip_from_view;
uniform mat4 view_from_world;
uniform bool hemisphere_kernel;

uniform vec3 samples[64]; // @Volatile samples.count == SAMPLES_MAX
uniform int samples_count;
uniform float bias;
uniform float radius;

void main()
{
    // Tile noise texture over screen based on screen dimensions divided by noise size
    vec2 noise_scale = vec2(window_width/4.0, window_height/4.0); 

    // get input for SSAO algorithm
    vec4 frag_position_world = vec4(texture(tex_position, tex_coords).xyz, 1.);
    vec3 frag_position = (view_from_world * frag_position_world).xyz;
    vec3 normal_world = normalize(texture(tex_normal, tex_coords).rgb);
    vec3 normal = (transpose(inverse(view_from_world)) * vec4(normal_world, 0.)).xyz;
    vec3 noise_offset = normalize(texture(tex_noise, tex_coords * noise_scale).xyz);

    // create TBN change-of-basis matrix: from tangent-space to view-space
    vec3 tangent = normalize(noise_offset - normal * dot(noise_offset, normal));
    vec3 bi_tangent = cross(normal, tangent);
    mat3 TBN = mat3(tangent, bi_tangent, normal);
    
    // iterate over the sample kernel and calculate occlusion factor
    float occlusion = 0.0;
    for(int i = 0; i < samples_count; ++i)
    {
        // Get sample position
        vec3 sample = samples[i];
        if (hemisphere_kernel && sample.z < 0.) {
            sample.z *= -1;
        }
        vec3 sample_position = TBN * sample; // from tangent to view-space
        sample_position = frag_position + sample_position * radius; 

        // Project sample position (to sample texture) (to get position on screen/texture)
        vec4 offset = vec4(sample_position, 1.0);
        offset = clip_from_view * offset; // From view to clip-space
        offset.xyz /= offset.w; // Perspective divide
        offset.xyz = offset.xyz * 0.5 + 0.5; // Transform to range [0, 1]

        // Get sample depth
        vec4 sample_position_world = vec4(texture(tex_position, offset.xy).xyz, 1.);
        float sample_depth = (view_from_world * sample_position_world).z; // get depth value of kernel sample

        // Range check and accumulate
        float range_check = smoothstep(0.0, 1.0, radius / abs(frag_position.z - sample_depth));
        occlusion += (sample_depth >= sample_position.z + bias ? 1.0 : 0.0) * range_check;           
    }
    occlusion = 1.0 - (occlusion / samples_count);
    
    frag_color = occlusion;
}