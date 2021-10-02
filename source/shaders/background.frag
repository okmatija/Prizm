#version 330 core

// @Incomplete Add all Shadertoy inputs
uniform vec3      iResolution;           // viewport resolution (in pixels)
uniform float     iTime;                 // shader playback time (in seconds)
// uniform float     iTimeDelta;            // render time (in seconds)
// uniform int       iFrame;                // shader playback frame
// uniform float     iChannelTime[4];       // channel playback time (in seconds)
// uniform vec3      iChannelResolution[4]; // channel resolution (in pixels)
// uniform vec4      iMouse;                // mouse pixel coords. xy: current (if MLB down), zw: click
// uniform samplerXX iChannel0..3;          // input channel. XX = 2D/Cube
// uniform vec4      iDate;                 // (year, month, day, time in seconds)
// uniform float     iSampleRate;           // sound sample rate (i.e., 44100)

const float PI = 3.1415926535897932;
const float gradient  = 1.0;
const float intensity = 8.0;

float gaussian( in vec2 p )
{
    float denom = gradient * gradient * 2.0;
    float val1 = 1.0 / (denom * PI);
    float val2 = exp(-dot(p, p) / denom);
    return val1 * val2;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {

    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;

    // Time varying pixel color
    vec3 col = 0.5 + 0.5*cos(iTime+uv.xyx+vec3(0,2,4));

    // Wash out the center
    vec2  p = uv * 2.0 - 1.0;
    float t = intensity * gaussian(.8 * p);
    col = mix(vec3(1.0), col, 1.0 - t);
    col = min(vec3(1.0), col);

    // Output to screen
    fragColor = vec4(col,1.0);
}

out vec4 fragColor;

void main() {
    mainImage(fragColor, gl_FragCoord.xy);
}