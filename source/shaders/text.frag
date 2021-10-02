#version 330 core

in vec2 TextureCoords;
out vec4 color;

uniform sampler2D text;
uniform vec4 text_color;

void main () {
    vec4 sample = vec4(1.0, 1.0, 1.0, texture(text, TextureCoords).r);
    color = text_color * sample;
    // color = vec4(TextureCoords, 0.0, 1.0);
    // color = vec4(texture(text, TextureCoords).rrr, 1.0);
}