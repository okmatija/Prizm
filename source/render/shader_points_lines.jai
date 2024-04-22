Shader_Points :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {

        shader.program = get_shader_program(POINTS_VERT, FRAG);

        cache_uniform_locations(shader);
        cache_shader_uniform_location(shader, "point_size", .Float1);
    }

    use_shader :: (
        shader : Shader,
        using mesh : Simple_Mesh,
        using display_info : Display_Info,
        clip_radius_mode : bool,
        style : Vertex_Style) {

        glUseProgram(shader.program);
        assert(glIsProgram(shader.program) == GL_TRUE);

        set_uniform_values(shader, mesh, flash_wave_dt, clip_sphere, clip_ranges, clip_radius_mode, style.color);

        used_point_size : float = ifx clip_radius_mode then 2. else cast(float)vertex_style.size;
        set_shader_uniform_value(shader, "point_size", used_point_size);
    }
}

Shader_Lines :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {

        shader.program = get_shader_program(LINES_VERT, FRAG);

        // @Cleanup See :LinesShaderCompilation
        cache_uniform_locations(shader);
    }

    use_shader :: (
        shader : Shader,
        using mesh : Simple_Mesh,
        using display_info : Display_Info,
        clip_radius_mode : bool,
        color : Vector4) {

        glUseProgram(shader.program);
        assert(glIsProgram(shader.program) == GL_TRUE);

        set_uniform_values(shader, mesh, flash_wave_dt, clip_sphere, clip_ranges, clip_radius_mode, color);
    }
}

#scope_file

cache_uniform_locations :: (shader : *Shader) {

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
}

set_uniform_values :: (
    shader : Shader,
    using mesh : Simple_Mesh,
    flash_wave_dt : float,
    clip_sphere : Clip_Sphere,
    clip_ranges : [3]Clip_Range,
    clip_radius_mode : bool,
    color : Vector4) {

    view_from_world := make_look_at_matrix(app.camera);
    clip_from_view := make_orthographic_projection_matrix(app.camera);
    wave := ifx flash_wave_dt == 0 then -1 else cos(5 * flash_wave_dt);

    set_shader_uniform_value(shader, "world_from_model", world_from_model.floats);
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
    set_shader_uniform_value(shader, "color", color.component);

    // @Cleanup Why is this different to e.g., normals
    used_clip_mode := ifx clip_radius_mode then Clip_Mode.BLACKEN else Clip_Mode.HIDDEN;
    set_shader_uniform_value(shader, "clip_mode", used_clip_mode);
}

POINTS_VERT, POINTS_VERT_OK :: #run read_entire_file("source/render/points.vert"); #assert(POINTS_VERT_OK);
LINES_VERT, LINES_VERT_OK :: #run read_entire_file("source/render/lines.vert"); #assert(LINES_VERT_OK);
FRAG, FRAG_OK :: #run read_entire_file("source/render/points_lines.frag"); #assert(FRAG_OK);