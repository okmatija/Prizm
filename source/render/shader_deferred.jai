// G-buffer shader
Shader_Geometry :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {

        shader.program = get_shader_program(GBUFFER_VERT, GBUFFER_FRAG);

        cache_shader_uniform_location(shader, "world_from_model", .Matrix4);
        cache_shader_uniform_location(shader, "view_from_world", .Matrix4);
        cache_shader_uniform_location(shader, "clip_from_view", .Matrix4);

    }

    use_shader :: (shader : Shader, using mesh : Simple_Mesh) {

        glUseProgram(shader.program);
        assert(glIsProgram(shader.program) == GL_TRUE);

        view_from_world := make_look_at_matrix(app.camera);
        clip_from_view := make_orthographic_projection_matrix(app.camera);

        set_shader_uniform_value(shader, "world_from_model", world_from_model.floats);
        set_shader_uniform_value(shader, "view_from_world", view_from_world.floats);
        set_shader_uniform_value(shader, "clip_from_view", clip_from_view.floats);

    }
}

Shader_Lighting :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {

        shader.program = get_shader_program(LIGHTING_VERT, LIGHTING_FRAG);

        //debug_print_active_uniforms(shader.program); // nocommit

        cache_shader_uniform_location(shader, "camera.eye_position", .Float3);
        cache_shader_uniform_location(shader, "camera.look_direction", .Float3);
        cache_shader_uniform_location(shader, "gbuffer_position", .Texture);
        cache_shader_uniform_location(shader, "gbuffer_normal", .Texture);
        // nocommit Albedo is needed...!

    }

    use_shader :: (shader : Shader) {

        glUseProgram(shader.program);
        assert(glIsProgram(shader.program) == GL_TRUE);

        // @TODO @Speed These could all be set in uniform buffers just once per frame
        look_direction := current_look_direction();
        position_uniform := Texture_Uniform.{*app.geometry_pass.position, GL_TEXTURE0};
        normal_uniform := Texture_Uniform.{*app.geometry_pass.normal, GL_TEXTURE1};

        set_shader_uniform_value(shader, "camera.eye_position", app.camera.eye_position.component);
        set_shader_uniform_value(shader, "camera.look_direction", look_direction.component);
        set_shader_uniform_value(shader, "gbuffer_position", position_uniform);
        set_shader_uniform_value(shader, "gbuffer_normal", normal_uniform);

    }
}



#scope_file

GBUFFER_VERT, GBUFFER_VERT_OK :: #run read_entire_file("source/render/gbuffer.vert"); #assert(GBUFFER_VERT_OK);
GBUFFER_FRAG, GBUFFER_FRAG_OK :: #run read_entire_file("source/render/gbuffer.frag"); #assert(GBUFFER_FRAG_OK);

LIGHTING_VERT, LIGHTING_VERT_OK :: #run read_entire_file("source/render/quad.vert"); #assert(LIGHTING_VERT_OK);
LIGHTING_FRAG, LIGHTING_FRAG_OK :: #run read_entire_file("source/render/triangles_deferred.frag"); #assert(LIGHTING_FRAG_OK);