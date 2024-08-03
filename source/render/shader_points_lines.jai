Shader_Points_Lines :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {

        shader.program = get_shader_program(VERT, FRAG);

        cache_shader_uniform_location(shader, "world_from_model", .Matrix4);
        cache_shader_uniform_location(shader, "view_from_world", .Matrix4);
        cache_shader_uniform_location(shader, "clip_from_view", .Matrix4);

        cache_shader_uniform_location(shader, "clip_sphere.center", .Float3);
        cache_shader_uniform_location(shader, "clip_sphere.radius", .Float1);
        cache_shader_uniform_location(shader, "clip_sphere.is_active", .Bool);
        for 0..2 {
            cache_shader_uniform_location(shader, tprint("clip_range[%].is_active", it), .Bool);
            cache_shader_uniform_location(shader, tprint("clip_range[%].normal", it), .Float3);
            cache_shader_uniform_location(shader, tprint("clip_range[%].max", it), .Float1);
            cache_shader_uniform_location(shader, tprint("clip_range[%].min", it), .Float1);
        }

        cache_shader_uniform_location(shader, "wave", .Float1);
        cache_shader_uniform_location(shader, "clip_mode", .Enum);
        cache_shader_uniform_location(shader, "color", .Float4);

        // We don't set the value for this uniform if we use this shader for rendering segments/triangle edges
        cache_shader_uniform_location(shader, "point_size", .Float1);
    }

    use_shader :: (shader : Shader, entity : Entity) {
        using entity.display_info;

        glUseProgram(shader.program);
        //assert(glIsProgram(shader.program) == GL_TRUE);

        view_from_world := make_look_at_matrix(app.camera);
        clip_from_view := make_orthographic_projection_matrix(app.camera);
        wave := ifx flash_wave_dt == 0 then -1 else cos(5 * flash_wave_dt);

        set_shader_uniform_value(shader, "world_from_model", entity.mesh.world_from_model.floats);
        set_shader_uniform_value(shader, "view_from_world", view_from_world.floats);
        set_shader_uniform_value(shader, "clip_from_view", clip_from_view.floats);

        set_shader_uniform_value(shader, "clip_sphere.center", clip_sphere.center.component);
        set_shader_uniform_value(shader, "clip_sphere.radius", clip_sphere.radius);
        set_shader_uniform_value(shader, "clip_sphere.is_active", clip_sphere.is_active);

        for 0..2 {
            set_shader_uniform_value(shader, tprint("clip_range[%].is_active", it), clip_ranges[it].is_active);
            set_shader_uniform_value(shader, tprint("clip_range[%].normal", it), clip_ranges[it].normal.component);
            set_shader_uniform_value(shader, tprint("clip_range[%].max", it), clip_ranges[it].max);
            set_shader_uniform_value(shader, tprint("clip_range[%].min", it), clip_ranges[it].min);
        }

        set_shader_uniform_value(shader, "wave", wave);

        // @Cleanup Why is this different to e.g., normals
        used_clip_mode := ifx clip_radius_mode then Clip_Mode.BLACKEN else Clip_Mode.HIDDEN;
        set_shader_uniform_value(shader, "clip_mode", used_clip_mode);
    }
}

#scope_file

VERT, VERT_OK :: #run read_entire_file("source/render/points_lines.vert"); #assert(VERT_OK);
FRAG, FRAG_OK :: #run read_entire_file("source/render/points_lines.frag"); #assert(FRAG_OK);