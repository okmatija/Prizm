Shader_Ssao :: struct {
    using #as base : Shader;

    Ssao_Kernel_Kind :: enum {
        DISABLED; // Disable SSAO. nocommit Implement this!
        SPHERE;
        HEMISPHERE;
    };

    kernel_kind : Ssao_Kernel_Kind = .SPHERE;

    init_shader :: (shader : *Shader) {

        shader.program = get_shader_program(SSAO_VERT, SSAO_FRAG);

        cache_shader_uniform_location(shader, "tex_position", .Texture);
        cache_shader_uniform_location(shader, "tex_normal", .Texture);
        cache_shader_uniform_location(shader, "tex_noise", .Texture);
        cache_shader_uniform_location(shader, "window_width", .Float1);
        cache_shader_uniform_location(shader, "window_height", .Float1);
        cache_shader_uniform_location(shader, "clip_from_view", .Matrix4);
        cache_shader_uniform_location(shader, "view_from_world", .Matrix4);
        cache_shader_uniform_location(shader, "hemisphere_kernel", .Bool);

        for app.ssao_pass.ssao_kernel {
            cache_shader_uniform_location(shader, tprint("samples[%]", it_index), .Float3);
        }

    }

    use_shader :: (shader : *Shader_Ssao) { // nocommit Why pointer? change the use_shader helper as well

        // @TODOOO Improve abstraction a bit here: calling glUseProgram should be separate from setting uniforms, we can do it once before rendering each item
        glUseProgram(shader.program);
        assert(glIsProgram(shader.program) == GL_TRUE);

        clip_from_view := make_orthographic_projection_matrix(app.camera);
        view_from_world := make_look_at_matrix(app.camera);

        position := Texture_Uniform.{*app.geometry_pass.position, 0, "tex_position"};
        normal := Texture_Uniform.{*app.geometry_pass.normal, 1, "tex_normal"};
        noise := Texture_Uniform.{*app.ssao_pass.ssao_noise, 2, "tex_noise"};

        set_shader_uniform_value(shader, "tex_position", position);
        set_shader_uniform_value(shader, "tex_normal", normal);
        set_shader_uniform_value(shader, "tex_noise", noise);
        set_shader_uniform_value(shader, "window_width", cast(float)app.window_size.width);
        set_shader_uniform_value(shader, "window_height", cast(float)app.window_size.height);
        set_shader_uniform_value(shader, "clip_from_view", clip_from_view.floats);
        set_shader_uniform_value(shader, "view_from_world", view_from_world.floats);
        set_shader_uniform_value(shader, "hemisphere_kernel", shader.kernel_kind == .HEMISPHERE);

        for app.ssao_pass.ssao_kernel {
            set_shader_uniform_value(shader, tprint("samples[%]", it_index), it.component);
        }

    }
}

#scope_file

SSAO_VERT, SSAO_VERT_OK :: #run read_entire_file("source/render/quad.vert"); #assert(SSAO_VERT_OK);
SSAO_FRAG, SSAO_FRAG_OK :: #run read_entire_file("source/render/ssao.frag"); #assert(SSAO_FRAG_OK);