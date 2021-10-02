#version 330 core

uniform vec4 normals_color = vec4(0., 0., .8, 1.); // rgba

out vec4 out_color;

void main() {
    out_color = normals_color;
}