#version 450
// Ported from background.frag — Shadertoy-style animated gradient.

layout(set = 3, binding = 0) uniform Background_UBO {
    vec4 resolution_time; // xyz=iResolution, w=iTime
};

layout(location = 0) out vec4 fragColor;

const float PI        = 3.1415926535897932;
const float gradient  = 1.0;
const float intensity = 8.0;

float gaussian(vec2 p) {
    float denom = gradient * gradient * 2.0;
    return (1.0 / (denom * PI)) * exp(-dot(p, p) / denom);
}

void main() {
    vec3 iResolution = resolution_time.xyz;
    float iTime      = resolution_time.w;

    vec2 uv = gl_FragCoord.xy / iResolution.xy;

    float f = 0.25;
    vec3 col = 0.5 + 0.5 * cos(f * (iTime + uv.xyx + vec3(0, 2, 4)));

    vec2  p = uv * 2.0 - 1.0;
    float t = intensity * gaussian(0.8 * p);
    col = mix(vec3(1.0), col, 1.0 - t);
    col = min(vec3(1.0), col);

    fragColor = vec4(col, 1.0);
}
