Shader_Lighting :: struct {
    using #as base : Shader;

    use_ssao : bool;

    init_shader :: (shader : *Shader) {

        shader.program = get_shader_program(LIGHTING_VERT, LIGHTING_FRAG);

        //debug_print_active_uniforms(shader.program); // nocommit

        // cache_shader_uniform_location(shader, "camera.eye_position", .Float3);
        cache_shader_uniform_location(shader, "camera.look_direction", .Float3);
        // cache_shader_uniform_location(shader, "gbuffer_position", .Texture);
        cache_shader_uniform_location(shader, "gbuffer_normal", .Texture);
        cache_shader_uniform_location(shader, "gbuffer_base_color", .Texture);
        cache_shader_uniform_location(shader, "ssao", .Texture);
        cache_shader_uniform_location(shader, "use_ssao", .Bool);

    }

    // nocommit This should be Shader_Lighting... Fix all similar functions as well
    use_shader :: (shader : Shader_Lighting) {

        // nocommit I think the following is better in a use_pass function??

        glUseProgram(shader.program);
        assert(glIsProgram(shader.program) == GL_TRUE);

        // @TODO @Speed These could all be set in uniform buffers just once per frame
        look_direction := current_look_direction();
        position_uniform := Texture_Uniform.{*app.geometry_pass.position, 0, "position"};
        normal_uniform := Texture_Uniform.{*app.geometry_pass.normal, 1, "normal"};
        base_color_uniform := Texture_Uniform.{*app.geometry_pass.base_color, 2, "base_color"};
        ssao_uniform := Texture_Uniform.{*app.ssao_blur_pass.ssao_blurred, 3, "ssao"};

        // set_shader_uniform_value(shader, "camera.eye_position", app.camera.eye_position.component);
        set_shader_uniform_value(shader, "camera.look_direction", look_direction.component);

        // set_shader_uniform_value(shader, "gbuffer_position", position_uniform);
        set_shader_uniform_value(shader, "gbuffer_normal", normal_uniform);
        set_shader_uniform_value(shader, "gbuffer_base_color", base_color_uniform);
        set_shader_uniform_value(shader, "ssao", ssao_uniform);
        set_shader_uniform_value(shader, "use_ssao", shader.use_ssao);

    }
}

#scope_file

LIGHTING_VERT, LIGHTING_VERT_OK :: #run read_entire_file("source/render/quad.vert"); #assert(LIGHTING_VERT_OK);
LIGHTING_FRAG, LIGHTING_FRAG_OK :: #run read_entire_file("source/render/triangles_deferred.frag"); #assert(LIGHTING_FRAG_OK);