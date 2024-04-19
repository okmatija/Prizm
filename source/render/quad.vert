#version 330 core

out vec2 tex_coords;

void main() {

    // vertex attributes for a quad that fills the entire screen in Normalized Device Coordinates.
    switch(gl_VertexID) {
        case 0:
            gl_Position = vec4(-1, 1, 0, 1);
            tex_coords = vec2(0, 1);
            break;

        case 1:
            gl_Position = vec4(-1, -1, 0, 1);
            tex_coords = vec2(0, 0);
            break;

        case 2:
            gl_Position = vec4( 1, -1, 0, 1);
            tex_coords = vec2(1, 0);
            break;

        case 3:
            gl_Position = vec4(-1,  1, 0, 1);
            tex_coords = vec2(0, 1);
            break;

        case 4:
            gl_Position = vec4( 1, -1, 0, 1);
            tex_coords = vec2(1, 0);
            break;

        case 5:
            gl_Position = vec4( 1,  1, 0, 1);
            tex_coords = vec2(1, 1);
            break;
    }
}