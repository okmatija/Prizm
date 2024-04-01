#version 330 core

out float frag_color;

in vec2 tex_coords;

uniform sampler2D tex_position;
uniform sampler2D tex_normal;
uniform sampler2D tex_noise;

uniform vec3 samples[64]; // @Volatile samples <> kernel_size

uniform float window_width;
uniform float window_height;

// TODO make these uniforms
int kernel_size = 64; // @Volatile samples <> kernel_size
float radius = 0.5;
float bias = 0.025;

uniform mat4 projection;

void main()
{
    // Tile noise texture over screen based on screen dimensions divided by noise size
    vec2 noise_scale = vec2(window_width/4.0, window_height/4.0); 

    // get input for SSAO algorithm
    vec3 frag_position = texture(tex_position, tex_coords).xyz;
    vec3 normal = normalize(texture(tex_normal, tex_coords).rgb);
    vec3 noise_offset = normalize(texture(tex_noise, tex_coords * noise_scale).xyz);

    // create TBN change-of-basis matrix: from tangent-space to view-space
    vec3 tangent = normalize(noise_offset - normal * dot(noise_offset, normal));
    vec3 bi_tangent = cross(normal, tangent);
    mat3 TBN = mat3(tangent, bi_tangent, normal);
    
    // iterate over the sample kernel and calculate occlusion factor
    float occlusion = 0.0;
    for(int i = 0; i < kernel_size; ++i)
    {
        // Get sample position
        vec3 sample_position = TBN * samples[i]; // from tangent to view-space
        sample_position = frag_position + samplePos * radius; 
        
        // Project sample position (to sample texture) (to get position on screen/texture)
        vec4 offset = vec4(sample_position, 1.0);
        offset = projection * offset; // From view to clip-space
        offset.xyz /= offset.w; // Perspective divide
        offset.xyz = offset.xyz * 0.5 + 0.5; // Transform to range [0, 1]
        
        // Get sample depth
        float sample_depth = texture(tex_position, offset.xy).z; // get depth value of kernel sample
        
        // Range check and accumulate
        float range_check = smoothstep(0.0, 1.0, radius / abs(frag_position.z - sample_depth));
        occlusion += (sample_depth >= sample_position.z + bias ? 1.0 : 0.0) * range_check;           
    }
    occlusion = 1.0 - (occlusion / kernel_size);
    
    frag_color = occlusion;
}