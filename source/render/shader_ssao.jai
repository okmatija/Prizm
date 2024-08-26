Shader_Ssao :: struct {
    using #as base : Shader;

    Ssao_Kernel_Kind :: enum {
        DISABLED; // Disable SSAO. nocommit Implement this!
        SPHERE;
        HEMISPHERE;
    };

    SAMPLES_MAX : s32 : 64; // @Volatile In the shader samples.count == SAMPLES_MAX
    samples_count : s32 = SAMPLES_MAX;
    kernel_kind : Ssao_Kernel_Kind = .SPHERE;
    kernel_radius := 1.5;
    bias : float = .05;

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
        cache_shader_uniform_location(shader, "samples_count", .Int1);
        cache_shader_uniform_location(shader, "radius", .Float1);
        cache_shader_uniform_location(shader, "bias", .Float1);

        for app.render_info.ssao_pass.ssao_kernel {
            cache_shader_uniform_location(shader, tprint("samples[%]", it_index), .Float3);
        }

    }

    use_shader :: (shader : *Shader_Ssao) { // nocommit Why pointer? change the use_shader helper as well

        // @TODOOO Improve abstraction a bit here: calling glUseProgram should be separate from setting uniforms, we can do it once before rendering each item
        glUseProgram(shader.program);
        //assert(glIsProgram(shader.program) == GL_TRUE);

        clip_from_view := make_orthographic_projection_matrix(app.camera);
        view_from_world := make_look_at_matrix(app.camera);

        position := Texture_Uniform.{*app.render_info.geometry_pass.position, 0, "tex_position"}; // @Speed @TODOOO Use unprojected depth buffer here instead!   
        normal := Texture_Uniform.{*app.render_info.geometry_pass.normal, 1, "tex_normal"};
        noise := Texture_Uniform.{*app.render_info.ssao_pass.ssao_noise, 2, "tex_noise"};

        set_shader_uniform_value(shader, "tex_position", position);
        set_shader_uniform_value(shader, "tex_normal", normal);
        set_shader_uniform_value(shader, "tex_noise", noise);
        set_shader_uniform_value(shader, "window_width", cast(float)app.window_size.width);
        set_shader_uniform_value(shader, "window_height", cast(float)app.window_size.height);
        set_shader_uniform_value(shader, "clip_from_view", clip_from_view.floats);
        set_shader_uniform_value(shader, "view_from_world", view_from_world.floats);
        set_shader_uniform_value(shader, "hemisphere_kernel", shader.kernel_kind == .HEMISPHERE);
        assert(shader.samples_count >= 0);
        assert(shader.samples_count <= SAMPLES_MAX);
        set_shader_uniform_value(shader, "samples_count", shader.samples_count);
        set_shader_uniform_value(shader, "radius", shader.kernel_radius);
        set_shader_uniform_value(shader, "bias", shader.bias);

        for app.render_info.ssao_pass.ssao_kernel {
            set_shader_uniform_value(shader, tprint("samples[%]", it_index), it.component);
        }

    }
}

Shader_Ssao_Blur :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {

        shader.program = get_shader_program(SSAO_VERT, SSAO_BLUR_FRAG);

        cache_shader_uniform_location(shader, "occlusion_input", .Texture);
    }

    use_shader :: (shader : *Shader_Ssao_Blur) { // nocommit Why pointer? change the use_shader helper as well

        // @TODOOO Improve abstraction a bit here: calling glUseProgram should be separate from setting uniforms, we can do it once before rendering each item
        glUseProgram(shader.program);
        //assert(glIsProgram(shader.program) == GL_TRUE);

        ssao := Texture_Uniform.{app.render_info.ssao_blur_pass.ssao, 0, "occlusion_input"};
        set_shader_uniform_value(shader, "occlusion_input", ssao);
    }
}


#scope_file

SSAO_VERT, SSAO_VERT_OK :: #run read_entire_file("source/render/quad.vert"); #assert(SSAO_VERT_OK);
SSAO_FRAG, SSAO_FRAG_OK :: #run read_entire_file("source/render/ssao.frag"); #assert(SSAO_FRAG_OK);
SSAO_BLUR_FRAG, SSAO_BLUR_FRAG_OK :: #run read_entire_file("source/render/ssao_blur.frag"); #assert(SSAO_BLUR_FRAG_OK);