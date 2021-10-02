#version 330 core

uniform mat4 world_from_model;
uniform mat4 view_from_world;
uniform mat4 clip_from_view;

uniform vec3 min;
uniform vec3 max;

void main() {

    //    +z
    //     4 -------- 6
    //     |\         |\
    //     | \        | \
    //     |  5 -------- 7
    //     |  |       |  |
    //     0--|------ 2+y|
    //      \ |        \ |
    //       \|         \|
    //        1--------- 3
    //        +x

    vec4 v0 = vec4(min.x, min.y, min.z, 1.f);
    vec4 v1 = vec4(max.x, min.y, min.z, 1.f);
    vec4 v2 = vec4(min.x, max.y, min.z, 1.f);
    vec4 v3 = vec4(max.x, max.y, min.z, 1.f);
    vec4 v4 = vec4(min.x, min.y, max.z, 1.f);
    vec4 v5 = vec4(max.x, min.y, max.z, 1.f);
    vec4 v6 = vec4(min.x, max.y, max.z, 1.f);
    vec4 v7 = vec4(max.x, max.y, max.z, 1.f);

    vec4 p;
    switch(gl_VertexID) {
        case 0: p = v0; break;
        case 1: p = v1; break;

        case 2: p = v1; break;
        case 3: p = v3; break;

        case 4: p = v3; break;
        case 5: p = v2; break;

        case 6: p = v2; break;
        case 7: p = v0; break;

        case 8: p = v0; break;
        case 9: p = v4; break;

        case 10: p = v1; break;
        case 11: p = v5; break;

        case 12: p = v3; break;
        case 13: p = v7; break;

        case 14: p = v2; break;
        case 15: p = v6; break;

        case 16: p = v4; break;
        case 17: p = v5; break;

        case 18: p = v5; break;
        case 19: p = v7; break;

        case 20: p = v7; break;
        case 21: p = v6; break;

        case 22: p = v6; break;
        case 23: p = v4; break;
    }

    mat4 view_from_model = clip_from_view * view_from_world * world_from_model;
    gl_Position = view_from_model * p;
}