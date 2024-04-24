Shader_AABB :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {

        shader.program = get_shader_program(VERT, FRAG);

        cache_shader_uniform_location(shader, "world_from_model", .Matrix4);
        cache_shader_uniform_location(shader, "view_from_world", .Matrix4);
        cache_shader_uniform_location(shader, "clip_from_view", .Matrix4);
        cache_shader_uniform_location(shader, "max", .Float3);
        cache_shader_uniform_location(shader, "min", .Float3);
        cache_shader_uniform_location(shader, "color", .Float4);
    }

    use_shader :: (
        shader : Shader,
        aabb_model : AxisBox3,
        world_from_model : Matrix4) {

        glUseProgram(shader.program);
        assert(glIsProgram(shader.program) == GL_TRUE);

        view_from_world := make_look_at_matrix(app.camera);
        clip_from_view := make_orthographic_projection_matrix(app.camera);

        set_shader_uniform_value(shader, "world_from_model", world_from_model.floats);
        set_shader_uniform_value(shader, "view_from_world", view_from_world.floats);
        set_shader_uniform_value(shader, "clip_from_view", clip_from_view.floats);
        set_shader_uniform_value(shader, "max", aabb_model.max_point.component);
        set_shader_uniform_value(shader, "min", aabb_model.min_point.component);
        set_shader_uniform_value(shader, "color", BLUE.component);
    }
}

#scope_file

VERT, VERT_OK :: #run read_entire_file("source/render/aabb.vert"); #assert(VERT_OK);
FRAG, FRAG_OK :: #run read_entire_file("source/render/aabb.frag"); #assert(FRAG_OK);