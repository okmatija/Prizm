Shader_Point_Normal_Vectors :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {
        shader.program = get_shader_program(VERT, FRAG, POINTS_GEOM);
        cache_uniform_locations(shader);
    }

    use_shader :: (shader : Shader, entity : Entity) {
        using entity.display_info;
        glUseProgram(shader.program);
        //assert(glIsProgram(shader.program) == GL_TRUE);
        set_uniform_values(shader, entity.mesh, point_style.normal_style, clip_sphere, clip_ranges);
    }
}

Shader_Segment_Normal_Vectors :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {
        shader.program = get_shader_program(VERT, FRAG, SEGMENTS_GEOM);
        cache_uniform_locations(shader);
    }

    use_shader :: (shader : Shader, entity : Entity) {
        using entity.display_info;
        glUseProgram(shader.program);
        //assert(glIsProgram(shader.program) == GL_TRUE);
        set_uniform_values(shader, entity.mesh, segment_style.normal_style, clip_sphere, clip_ranges);
    }
}

Shader_Triangle_Normal_Vectors :: struct {
    using #as base : Shader;

    init_shader :: (shader : *Shader) {
        shader.program = get_shader_program(VERT, FRAG, TRIANGLES_GEOM);
        cache_uniform_locations(shader);
    }

    use_shader :: (shader : Shader, entity : Entity) {
        using entity.display_info;
        glUseProgram(shader.program);
        //assert(glIsProgram(shader.program) == GL_TRUE);
        set_uniform_values(shader, entity.mesh, triangle_style.normal_style, clip_sphere, clip_ranges);
    }
}

#scope_file

cache_uniform_locations :: (shader : *Shader) {

    cache_shader_uniform_location(shader, "world_from_model", .Matrix4);
    cache_shader_uniform_location(shader, "view_from_world", .Matrix4);
    cache_shader_uniform_location(shader, "clip_from_view", .Matrix4);

    cache_shader_uniform_location(shader, "normal_style_color", .Float4);
    cache_shader_uniform_location(shader, "normal_style_scale", .Float1);
    cache_shader_uniform_location(shader, "normal_style_normalized", .Bool);

    cache_shader_uniform_location(shader, "clip_sphere.center", .Float3);
    cache_shader_uniform_location(shader, "clip_sphere.radius", .Float1);
    cache_shader_uniform_location(shader, "clip_sphere.is_active", .Bool);

    for 0..2 {
        cache_shader_uniform_location(shader, tprint("clip_range[%].is_active", it), .Bool);
        cache_shader_uniform_location(shader, tprint("clip_range[%].normal", it), .Float3);
        cache_shader_uniform_location(shader, tprint("clip_range[%].max", it), .Float1);
        cache_shader_uniform_location(shader, tprint("clip_range[%].min", it), .Float1);
    }
}

set_uniform_values :: (shader : Shader, using mesh : Simple_Mesh, normal_style : Normal_Style, clip_sphere : Clip_Sphere, clip_ranges : [3]Clip_Range) {

    view_from_world := make_look_at_matrix(app.camera);
    clip_from_view := make_orthographic_projection_matrix(app.camera);

    set_shader_uniform_value(shader, "world_from_model", world_from_model.floats);
    set_shader_uniform_value(shader, "view_from_world", view_from_world.floats);
    set_shader_uniform_value(shader, "clip_from_view", clip_from_view.floats);

    set_shader_uniform_value(shader, "normal_style_color", normal_style.color.component);
    set_shader_uniform_value(shader, "normal_style_scale", normal_style.scale);
    set_shader_uniform_value(shader, "normal_style_normalized", normal_style.normalized);

    set_shader_uniform_value(shader, "clip_sphere.center", clip_sphere.center.component);
    set_shader_uniform_value(shader, "clip_sphere.radius", clip_sphere.radius);
    set_shader_uniform_value(shader, "clip_sphere.is_active", clip_sphere.is_active);

    for 0..2 {
        set_shader_uniform_value(shader, tprint("clip_range[%].is_active", it), clip_ranges[it].is_active);
        set_shader_uniform_value(shader, tprint("clip_range[%].normal", it), clip_ranges[it].normal.component);
        set_shader_uniform_value(shader, tprint("clip_range[%].max", it), clip_ranges[it].max);
        set_shader_uniform_value(shader, tprint("clip_range[%].min", it), clip_ranges[it].min);
    }
}

VERT, VERT_OK :: #run read_entire_file("source/render/normals.vert"); #assert(VERT_OK);
FRAG, FRAG_OK :: #run read_entire_file("source/render/normals.frag"); #assert(FRAG_OK);
POINTS_GEOM, POINTS_GEOM_OK :: #run read_entire_file("source/render/normals_points.geom"); #assert(POINTS_GEOM_OK);
SEGMENTS_GEOM, SEGMENTS_GEOM_OK :: #run read_entire_file("source/render/normals_segments.geom"); #assert(SEGMENTS_GEOM_OK);
TRIANGLES_GEOM, TRIANGLES_GEOM_OK :: #run read_entire_file("source/render/normals_triangles.geom"); #assert(TRIANGLES_GEOM_OK);