#version 450

// Hardcoded RGB triangle — no vertex buffers, driven entirely by gl_VertexIndex.
// Vulkan NDC: Y=-1 is screen top, Y=+1 is screen bottom.

const vec2 positions[3] = vec2[3](
    vec2( 0.0, -0.5),   // top centre
    vec2(-0.5,  0.5),   // bottom left
    vec2( 0.5,  0.5)    // bottom right
);

const vec3 colors[3] = vec3[3](
    vec3(1.0, 0.0, 0.0),    // red
    vec3(0.0, 1.0, 0.0),    // green
    vec3(0.0, 0.0, 1.0)     // blue
);

layout(location = 0) out vec3 frag_color;

void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    frag_color  = colors[gl_VertexIndex];
}
