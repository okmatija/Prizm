Shader_Triangles :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {
        shader.program = get_shader_program(VERT, FRAG, GEOM);

        cache_shader_uniform_location(shader, "camera.look_direction", .Float3);
        cache_shader_uniform_location(shader, "window_size", .Float2);
        
        cache_shader_uniform_location(shader, "world_from_model", .Matrix4);
        cache_shader_uniform_location(shader, "view_from_world", .Matrix4);
        cache_shader_uniform_location(shader, "clip_from_view", .Matrix4);
        
        cache_shader_uniform_location(shader, "clip_sphere.center", .Float3);
        cache_shader_uniform_location(shader, "clip_sphere.radius", .Float1);
        cache_shader_uniform_location(shader, "clip_sphere.is_active", .Bool);
        cache_shader_uniform_location(shader, "clip_sphere_prev.center", .Float3);
        cache_shader_uniform_location(shader, "clip_sphere_prev.radius", .Float1);
        //cache_shader_uniform_location(shader, "clip_sphere_prev.is_active", .Bool); // Not used in the shader

        for 0..2 {
            cache_shader_uniform_location(shader, tprint("clip_range[%].is_active", it), .Bool);
            cache_shader_uniform_location(shader, tprint("clip_range[%].normal", it), .Float3);
            cache_shader_uniform_location(shader, tprint("clip_range[%].max", it), .Float1);
            cache_shader_uniform_location(shader, tprint("clip_range[%].min", it), .Float1);
        }

        cache_shader_uniform_location(shader, "clip_radius_mode", .Bool);

        // Triangle_Style stuff, maybe we should make a struct in the shader for this..?
        cache_shader_uniform_location(shader, "display_mode", .Enum);
        cache_shader_uniform_location(shader, "backface_mode", .Enum);
        cache_shader_uniform_location(shader, "flat_shading", .Bool);
        cache_shader_uniform_location(shader, "color", .Float4);
        cache_shader_uniform_location(shader, "edges_color", .Float4);
        cache_shader_uniform_location(shader, "edges_width", .Float1);

        cache_shader_uniform_location(shader, "wave", .Float1);
    }

    use_shader :: (shader : Shader, using mesh : Simple_Mesh, using display_info : Display_Info) {

        glUseProgram(shader.program);
        assert(glIsProgram(shader.program) == GL_TRUE);

        view_from_world := make_look_at_matrix(app.camera);
        clip_from_view := make_orthographic_projection_matrix(app.camera);
        window_size_vector2 := Vector2.{cast(float)app.window_size.width, cast(float)app.window_size.height};
        look_direction := current_look_direction();
        wave := ifx flash_wave_dt == 0 then -1 else cos(5 * flash_wave_dt);

        set_shader_uniform_value(shader, "camera.look_direction", look_direction.component);

        set_shader_uniform_value(shader, "window_size", window_size_vector2.component);

        set_shader_uniform_value(shader, "world_from_model", world_from_model.floats);
        set_shader_uniform_value(shader, "view_from_world", view_from_world.floats);
        set_shader_uniform_value(shader, "clip_from_view", clip_from_view.floats);

        set_shader_uniform_value(shader, "clip_sphere.center", clip_sphere.center.component);
        set_shader_uniform_value(shader, "clip_sphere.radius", clip_sphere.radius);
        set_shader_uniform_value(shader, "clip_sphere.is_active", clip_sphere.is_active);
        set_shader_uniform_value(shader, "clip_sphere_prev.center", clip_sphere_prev.center.component);
        set_shader_uniform_value(shader, "clip_sphere_prev.radius", clip_sphere_prev.radius);
        // set_shader_uniform_value(shader, "clip_sphere_prev.is_active", clip_sphere_prev.is_active); // Not used in the shader

        for 0..2 {
            set_shader_uniform_value(shader, tprint("clip_range[%].is_active", it), clip_ranges[it].is_active);
            set_shader_uniform_value(shader, tprint("clip_range[%].normal", it), clip_ranges[it].normal.component);
            set_shader_uniform_value(shader, tprint("clip_range[%].max", it), clip_ranges[it].max);
            set_shader_uniform_value(shader, tprint("clip_range[%].min", it), clip_ranges[it].min);
        }

        // Triangle_Style stuff, maybe we should make a struct in the shader for this..?
        set_shader_uniform_value(shader, "display_mode", triangle_style.display_mode);
        set_shader_uniform_value(shader, "backface_mode", triangle_style.backface_mode);
        set_shader_uniform_value(shader, "flat_shading", triangle_style.flat_shading);
        set_shader_uniform_value(shader, "color", triangle_style.color.component);
        set_shader_uniform_value(shader, "edges_color", triangle_style.edge_style.color.component);
        set_shader_uniform_value(shader, "edges_width", triangle_style.edge_style.width); // @Volatile :ClipRadiusModeEdgeWidth This should be overwritten by clip_radius_mode requirements

        set_shader_uniform_value(shader, "wave", wave);
    }

    // See :ClipRadiusModeEdgeWidth
    set_shader_clip_radius_uniforms :: (shader : Shader, triangle_style : Triangle_Style, clip_radius_mode : bool, clip_radius_mode_show_wireframe : bool) {
        set_shader_uniform_value(shader, "clip_radius_mode", clip_radius_mode);

        used_edges_width := max(triangle_style.edge_style.width, MIN_EDGES_WIDTH_GL_FILL); // See :NiceTriangleEdgesRendering
        used_edges_width = ifx clip_radius_mode_show_wireframe then MIN_EDGES_WIDTH_GL_FILL else used_edges_width;
        used_edges_visible := ifx clip_radius_mode_show_wireframe then true else triangle_style.edge_style.visible;
        set_shader_uniform_value(shader, "edges_width", ifx used_edges_visible then used_edges_width else 0);
    }
}

#scope_file

VERT, VERT_OK :: #run read_entire_file("source/render/triangles.vert"); #assert(VERT_OK);
GEOM, GEOM_OK :: #run read_entire_file("source/render/triangles.geom"); #assert(GEOM_OK);
FRAG, FRAG_OK :: #run read_entire_file("source/render/triangles.frag"); #assert(FRAG_OK);