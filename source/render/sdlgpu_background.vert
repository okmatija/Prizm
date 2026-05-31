#version 450

// Full-screen covering triangle — no vertex buffer, driven by gl_VertexIndex.
void main() {
    // Three positions that together cover the entire [-1,1]x[-1,1] viewport.
    // Works in both GL and Vulkan NDC (the triangle just needs to cover the clip square).
    vec2 pos;
    if      (gl_VertexIndex == 0) pos = vec2(-1.0, -1.0);
    else if (gl_VertexIndex == 1) pos = vec2( 3.0, -1.0);
    else                          pos = vec2(-1.0,  3.0);
    gl_Position = vec4(pos, 0.0, 1.0);
}
