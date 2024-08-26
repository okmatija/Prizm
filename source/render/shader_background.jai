// TODO Hot reload this shader to allow the user to customize the background
Shader_Background :: struct {
    using #as base : Shader;

    // @Cleanup Add a vbo here... I think RenderDoc can't see the quad mesh otherwise...?
    vao : GLuint; // @Cleanup I think this should be elsewhere... in a pass? This background thing is currently more than a shader..
    // I think I actually need a far_plane_quad Simple_Mesh, which will store the vbo/vao
    // Move Render_Info into mesh

    init_shader :: (shader : *Shader_Background) {

        shader.program = get_shader_program(VERT, FRAG);

        glGenVertexArrays(1, *shader.vao);

        // TODO Add more Shadertoy input variables
        cache_shader_uniform_location(shader, "iResolution", .Float3);
        cache_shader_uniform_location(shader, "iTime", .Float1);
    }

    use_shader :: (shader : Shader_Background) {

        glUseProgram(shader.program);
        //assert(glIsProgram(shader.program) == GL_TRUE); // @Speed This call is very slow!

        resolution : Vector3 = .{cast(float)app.window_size.width, cast(float)app.window_size.height, 1.};
        set_shader_uniform_value(shader, "iResolution", resolution.component);
        set_shader_uniform_value(shader, "iTime", cast(float)ImGui.GetTime());
    }
}

#scope_file

VERT, VERT_OK :: #run read_entire_file("source/render/background.vert"); #assert(VERT_OK);
FRAG, FRAG_OK :: #run read_entire_file("source/render/background.frag"); #assert(FRAG_OK);