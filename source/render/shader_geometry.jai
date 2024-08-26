// G-buffer shader
Shader_Geometry :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {

        shader.program = get_shader_program(GBUFFER_VERT, GBUFFER_FRAG);

        cache_shader_uniform_location(shader, "world_from_model", .Matrix4);
        cache_shader_uniform_location(shader, "view_from_world", .Matrix4);
        cache_shader_uniform_location(shader, "clip_from_view", .Matrix4);
        cache_shader_uniform_location(shader, "base_color", .Float4);

    }

    use_shader :: (shader : Shader, entity : Entity) {

        // @TODOOO Improve abstraction a bit here: calling glUseProgram should be separate from setting uniforms, we can do it once before rendering each item
        glUseProgram(shader.program);
        //assert(glIsProgram(shader.program) == GL_TRUE);

        view_from_world := make_look_at_matrix(app.camera);
        clip_from_view := make_orthographic_projection_matrix(app.camera);

        set_shader_uniform_value(shader, "world_from_model", entity.mesh.world_from_model.floats);
        set_shader_uniform_value(shader, "view_from_world", view_from_world.floats);
        set_shader_uniform_value(shader, "clip_from_view", clip_from_view.floats);
        set_shader_uniform_value(shader, "base_color", entity.display_info.triangle_style.color.component);

    }
}

#scope_file

GBUFFER_VERT, GBUFFER_VERT_OK :: #run read_entire_file("source/render/gbuffer.vert"); #assert(GBUFFER_VERT_OK);
GBUFFER_FRAG, GBUFFER_FRAG_OK :: #run read_entire_file("source/render/gbuffer.frag"); #assert(GBUFFER_FRAG_OK);