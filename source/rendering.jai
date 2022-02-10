// Copyright Epic Games, Inc. All Rights Reserved.

// @Refactor rename this Label_Theme, and use it for triangle labels (at centroid, so you can see centroids, too)
Label_Theme :: struct {
    show_position := false;
    show_index := false;

    format_float : FormatFloat; // We ignore the `value` field
    format_float.trailing_width = 8;
    format_float.zero_removal = .NO;

    label_scale := .3;
    label_color : Vector4 = .{0., 0., .75, 1.}; // Blue, works well on both grey and white backgrounds
}

Display_Mode :: enum #specified {
    NORMALS ::     0;
    SOLID_COLOR :: 1;
    BLINN_PHONG :: 2;
}

cycle_display_mode :: (mode : *Display_Mode) {
    if #complete <<mode == {
        case .NORMALS;     <<mode = .BLINN_PHONG;
        case .SOLID_COLOR; <<mode = .NORMALS;
        case .BLINN_PHONG; <<mode = .NORMALS;
    }
}

Clip_Mode :: enum #specified {
    HIDDEN ::  0;
    BLACKEN :: 1;
    DARKEN ::  2;
}

// Things that needs updating when the geometry changes
Render_Info :: struct {
    is_dirty := true;

    vbo : GLuint;
    ibo : GLuint;

    bounding_sphere : Sphere; // In world space
    bounding_aabb : AxisBox3; // In world space
}

// @Volatile Keep synced with shaders
Clip_Range :: struct {
    normal : Vector3;
    is_active : bool;
    min : float = 0hFF800000; // -inf
    max : float = 0h7F800000; // +inf
}

is_clipped :: (clip_ranges : []Clip_Range, point : Point3) -> bool {
    for clip : clip_ranges if clip.is_active {
        plane := make_hyperplane3(clip.normal, Vector3.{0, 0, 0});
        dist := signed_distance_point3_plane3(point, plane);
        if (dist <= clip.min || dist >= clip.max) {
            return true;
        }
    }
    return false;
}

// @Volatile Keep synced with shaders
Clip_Sphere :: struct {
    using sphere : Sphere;
    radius = 0h7F800000; // +inf
    is_active : bool = false;
}

is_clipped :: (clip_sphere : Clip_Sphere, point : Point3) -> bool {
    if clip_sphere.is_active {
        if !contains(clip_sphere, point) {
            return true;
        }
    }
    return false;
}


// Things that should be preserved when the geometry changes
Display_Info :: struct {

    flash_wave_dt : float = 0.; @NoSync

    points_visible := false;
    points_color := Vector4.{.5, .5, .5, 1.};
    points_size : s32 = 0;
    vertex_label_style : Label_Theme;
    element_label_theme : Label_Theme;

    normals_visible := false;
    normals_color := Vector4.{0., 0., .8, 1.};
    normals_length : float = 1.;

    wireframe_visible := false;
    wireframe_color := Vector4.{0., 0., 0., 1.};
    wireframe_width : float = 0.;

    surface_visible := true;
    surface_color := Vector4.{1., 1., 1., 1.};

    display_mode := Display_Mode.BLINN_PHONG;
    screentone_backfaces := true;
    flat_shading := true;

    aabb_visible := false; @NoSync

    clip_ranges : [3]Clip_Range;
    clip_ranges[0] = .{normal=.{1,0,0}};
    clip_ranges[1] = .{normal=.{0,1,0}};
    clip_ranges[2] = .{normal=.{0,0,1}};
    clip_sphere, clip_sphere_prev : Clip_Sphere;
    clip_mode := Clip_Mode.HIDDEN;
}

is_clipped :: (display_info : Display_Info, point : Point3, test_sphere := true, test_ranges := true) -> bool {
    if test_sphere && is_clipped(display_info.clip_sphere, point) {
        return true;
    }

    if test_ranges && is_clipped(display_info.clip_ranges, point) {
        return true;
    }

    return false;
}

maybe_update_render_info :: (info : *Render_Info, mesh : *Mesh) {
    if info.is_dirty {
        if mesh.geometry_format == .TRIANGLES && !mesh.normals.count {
            // log("Computing and assigning triangle normals to vertices\n");
            success, failure_reason := compute_vertex_normals_from_triangles(mesh);
            if !success {
                log_error("Computing and assigning triangle normals to vertices, reason: \"%\"", failure_reason);
            }
        }

        info.bounding_sphere = bounding_sphere_ritter(mesh.positions);
        info.bounding_aabb = make_axis_box3(..mesh.positions);

        NP := size_of(Vector3) * mesh.positions.count;
        NN := size_of(Vector3) * mesh.normals.count;
        NI := size_of(u32) * mesh.indices.count;

        if !info.vbo glGenBuffers(1, *info.vbo);

        glBindBuffer(GL_ARRAY_BUFFER, info.vbo);
        glBufferData(GL_ARRAY_BUFFER, NP + NN, null, GL_STATIC_DRAW);
        glBufferSubData(GL_ARRAY_BUFFER, 0, NP, mesh.positions.data);
        glBufferSubData(GL_ARRAY_BUFFER, NP, NN, mesh.normals.data);

        if !info.ibo glGenBuffers(1, *info.ibo);

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, info.ibo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, NI, mesh.indices.data, GL_STATIC_DRAW);

        info.is_dirty = false;
    }
}

// @Cleanup consolidate this
render_normals :: (mesh : *Mesh, using render_info : *Render_Info, using display_info : Display_Info) {
    if !normals_visible return;

    maybe_update_render_info(render_info, mesh);

    glUseProgram(app.normals_program);

    // @Incomplete handle wave?
    set_model_view_projection_uniforms(app.normals_program, <<mesh);
    glUniform4f(glGetUniformLocation(app.normals_program, "normals_color"), normals_color.x, normals_color.y, normals_color.z, normals_color.w);
    glUniform1f(glGetUniformLocation(app.normals_program, "normal_length"), normals_length);

    {
        for 0..clip_ranges.count-1 {
            // @Cleanup We could use run directive here to get constant strings
            using clip_ranges[it];
            glUniform3f(glGetUniformLocation(app.normals_program, to_c_string(tprint("clip_range[%].normal", it))), normal.x, normal.y, normal.z);
            glUniform1f(glGetUniformLocation(app.normals_program, to_c_string(tprint("clip_range[%].min", it))), xx min);
            glUniform1f(glGetUniformLocation(app.normals_program, to_c_string(tprint("clip_range[%].max", it))), xx max);
            glUniform1f(glGetUniformLocation(app.normals_program, to_c_string(tprint("clip_range[%].is_active", it))), xx is_active);
        }

        glUniform3f(glGetUniformLocation(app.normals_program, "clip_sphere.center"), clip_sphere.center.x, clip_sphere.center.y, clip_sphere.center.z);
        glUniform1f(glGetUniformLocation(app.normals_program, "clip_sphere.radius"), xx clip_sphere.radius);
        glUniform1f(glGetUniformLocation(app.normals_program, "clip_sphere.is_active"), xx clip_sphere.is_active);
    }

    glBindVertexArray(app.normals_vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);

    ATTRIB_POSITION  :: 0;
    ATTRIB_NORMAL    :: 1;

    glEnableVertexAttribArray(ATTRIB_POSITION);
    glEnableVertexAttribArray(ATTRIB_NORMAL);

    NP := size_of(Vector3) * mesh.positions.count;

    glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), null);
    glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)(NP));

    glLineWidth(2); // 1, 2, 3... See also glEnable(GL_LINE_SMOOTH);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glDrawArrays(GL_POINTS, 0, xx mesh.positions.count);
}

render_aabb :: (mesh : *Mesh, using render_info : *Render_Info, using display_info : Display_Info) {
    if !aabb_visible {
        return;
    }

    maybe_update_render_info(render_info, mesh);

    glUseProgram(app.aabb_program);
    set_model_view_projection_uniforms(app.aabb_program, <<mesh);

    r, g, b, a : float = 0, 0, 1, 1;
    glUniform4f(glGetUniformLocation(app.aabb_program, "color"), r, g, b, a);
    min := bounding_aabb.min_point;
    max := bounding_aabb.max_point;
    glUniform3f(glGetUniformLocation(app.aabb_program, "min"), min.x, min.y, min.z);
    glUniform3f(glGetUniformLocation(app.aabb_program, "max"), max.x, max.y, max.z);

    glDrawArrays(GL_LINES, 0, 24);
}

render_mesh_points :: (mesh : *Mesh, using render_info : *Render_Info, using display_info : Display_Info) {
    if !points_visible return;
    render_simple_mesh_common(mesh, render_info, display_info);

    glUniform4f(glGetUniformLocation(app.simple_mesh_program, "color"), points_color.x, points_color.y, points_color.z, points_color.w);

    glDrawArrays(GL_POINTS, 0, xx mesh.positions.count);
}

render_mesh_lines :: (mesh : *Mesh, using render_info : *Render_Info, using display_info : Display_Info) {
    if !wireframe_visible return;
    render_simple_mesh_common(mesh, render_info, display_info);

    glUniform4f(glGetUniformLocation(app.simple_mesh_program, "color"), wireframe_color.x, wireframe_color.y, wireframe_color.z, wireframe_color.w);

    if mesh.geometry_format == .LINES {
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL); // @Cleanup doesn this affect a GL_LINES call?
        glDrawElements(GL_LINES, xx mesh.indices.count, GL_UNSIGNED_INT, null);
    } else if mesh.geometry_format == .TRIANGLES {
        glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
        glDrawElements(GL_TRIANGLES, xx mesh.indices.count, GL_UNSIGNED_INT, null);
    }
}

render_mesh_triangles :: (mesh : *Mesh, using render_info : *Render_Info, using display_info : Display_Info) {
    if !surface_visible return;

    render_mesh_common(mesh, render_info, display_info);

    glUniform1i(glGetUniformLocation(app.mesh_program, "display_mode"), xx display_mode);
    glUniform1ui(glGetUniformLocation(app.mesh_program, "screentone_backfaces"), xx screentone_backfaces);
    glUniform1ui(glGetUniformLocation(app.mesh_program, "flat_shading"), xx flat_shading);
    glUniform4f(glGetUniformLocation(app.mesh_program, "color"), surface_color.x, surface_color.y, surface_color.z, surface_color.w);
    glUniform4f(glGetUniformLocation(app.mesh_program, "wireframe_color"), wireframe_color.x, wireframe_color.y, wireframe_color.z, wireframe_color.w);
    glUniform1f(glGetUniformLocation(app.mesh_program, "wireframe_width"), ifx wireframe_visible then wireframe_width else 0);
    glUniform2f(glGetUniformLocation(app.mesh_program, "window_size"), xx app.current_window_width, xx app.current_window_height);

    if mesh.geometry_format == .TRIANGLES {
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
        glDrawElements(GL_TRIANGLES, xx mesh.indices.count, GL_UNSIGNED_INT, null);
    }
}

set_model_view_projection_uniforms :: (program : GLuint, mesh : Mesh) {
    {
        loc := glGetUniformLocation(program, "world_from_model");
        glUniformMatrix4fv(loc, 1, true, *mesh.world_from_model._11);
    }

    {
        loc := glGetUniformLocation(program, "view_from_world");
        view_from_world := make_look_at_matrix(app.camera);
        glUniformMatrix4fv(loc, 1, true, *view_from_world._11);
    }

    {
        loc := glGetUniformLocation(program, "clip_from_view");
        clip_from_view := make_orthographic_projection_matrix(app.camera);
        glUniformMatrix4fv(loc, 1, true, *clip_from_view._11);
    }
}

render_mesh_common :: (mesh : *Mesh, using render_info : *Render_Info, using display_info : Display_Info) {

    maybe_update_render_info(render_info, mesh);

    glUseProgram(app.mesh_program);

    set_model_view_projection_uniforms(app.mesh_program, <<mesh);

    wave := ifx flash_wave_dt == 0 then -1 else cos(5 * flash_wave_dt);
    glUniform1f(glGetUniformLocation(app.mesh_program, "wave"), wave);
    glUniform3f(glGetUniformLocation(app.mesh_program, "camera.eye_position"), app.camera.eye_position.x, app.camera.eye_position.y, app.camera.eye_position.z);

    {
        for 0..clip_ranges.count-1 {
            // @Cleanup We could use run directive here to get constant strings
            using clip_ranges[it];
            glUniform3f(glGetUniformLocation(app.mesh_program, to_c_string(tprint("clip_range[%].normal", it))), normal.x, normal.y, normal.z);
            glUniform1f(glGetUniformLocation(app.mesh_program, to_c_string(tprint("clip_range[%].min", it))), xx min);
            glUniform1f(glGetUniformLocation(app.mesh_program, to_c_string(tprint("clip_range[%].max", it))), xx max);
            glUniform1f(glGetUniformLocation(app.mesh_program, to_c_string(tprint("clip_range[%].is_active", it))), xx is_active);
        }

        glUniform3f(glGetUniformLocation(app.mesh_program, "clip_sphere.center"), clip_sphere.center.x, clip_sphere.center.y, clip_sphere.center.z);
        glUniform1f(glGetUniformLocation(app.mesh_program, "clip_sphere.radius"), xx clip_sphere.radius);
        glUniform1f(glGetUniformLocation(app.mesh_program, "clip_sphere.is_active"), xx clip_sphere.is_active);

        glUniform3f(glGetUniformLocation(app.mesh_program, "clip_sphere_prev.center"), clip_sphere_prev.center.x, clip_sphere_prev.center.y, clip_sphere_prev.center.z);
        glUniform1f(glGetUniformLocation(app.mesh_program, "clip_sphere_prev.radius"), xx clip_sphere_prev.radius);
        glUniform1f(glGetUniformLocation(app.mesh_program, "clip_sphere_prev.is_active"), xx clip_sphere_prev.is_active);

        // Also check the entity index here so we only render the previous sphere when we're resizing the sphere
        glUniform1ui(glGetUniformLocation(app.mesh_program, "clip_radius_mode"), xx (do_clip_radius_mode() && app.clipping_sphere_mode_entity_index >=0));
    }

    glBindVertexArray(app.mesh_vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);

    ATTRIB_POSITION  :: 0;
    ATTRIB_NORMAL    :: 1;

    glEnableVertexAttribArray(ATTRIB_POSITION);
    glEnableVertexAttribArray(ATTRIB_NORMAL);

    // ATTRIB_TEXCOORDS :: 1;
    // ATTRIB_COLOR     :: 2;

    NP := size_of(Vector3) * mesh.positions.count;

    glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), null);
    glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)(NP));

    // @Cleanup only set when mode==.LINE
    last_line_width: float;
    glGetFloatv(GL_LINE_WIDTH, xx *last_line_width);
    if (wireframe_width > 0) {
        glLineWidth(xx wireframe_width); // See also glEnable(GL_LINE_SMOOTH);
    }

    last_polygon_mode: [2]GLuint;
    glGetIntegerv(GL_POLYGON_MODE, xx last_polygon_mode.data);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);
}

render_simple_mesh_common :: (mesh : *Mesh, using render_info : *Render_Info, using display_info : Display_Info) {

    maybe_update_render_info(render_info, mesh);

    glUseProgram(app.simple_mesh_program);

    set_model_view_projection_uniforms(app.simple_mesh_program, <<mesh);

    wave := ifx flash_wave_dt == 0 then -1 else cos(5 * flash_wave_dt);
    glUniform1f(glGetUniformLocation(app.simple_mesh_program, "wave"), wave);
    glUniform1f(glGetUniformLocation(app.simple_mesh_program, "point_size"), xx points_size);

    {
        for 0..clip_ranges.count-1 {
            // @Cleanup We could use run directive here to get constant strings
            using clip_ranges[it];
            glUniform3f(glGetUniformLocation(app.simple_mesh_program, to_c_string(tprint("clip_range[%].normal", it))), normal.x, normal.y, normal.z);
            glUniform1f(glGetUniformLocation(app.simple_mesh_program, to_c_string(tprint("clip_range[%].min", it))), xx min);
            glUniform1f(glGetUniformLocation(app.simple_mesh_program, to_c_string(tprint("clip_range[%].max", it))), xx max);
            glUniform1f(glGetUniformLocation(app.simple_mesh_program, to_c_string(tprint("clip_range[%].is_active", it))), xx is_active);
        }

        glUniform3f(glGetUniformLocation(app.simple_mesh_program, "clip_sphere.center"), clip_sphere.center.x, clip_sphere.center.y, clip_sphere.center.z);
        glUniform1f(glGetUniformLocation(app.simple_mesh_program, "clip_sphere.radius"), xx clip_sphere.radius);
        glUniform1f(glGetUniformLocation(app.simple_mesh_program, "clip_sphere.is_active"), xx clip_sphere.is_active);

        // @Refactor move the clip_radius_mode stuff to the shader, do switching there
        clip_mode := ifx do_clip_radius_mode() then Clip_Mode.BLACKEN else Clip_Mode.HIDDEN;
        glUniform1i(glGetUniformLocation(app.simple_mesh_program, "clip_mode"), xx clip_mode);
    }

    glBindVertexArray(app.simple_mesh_vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);

    ATTRIB_POSITION  :: 0;
    ATTRIB_NORMAL    :: 1;

    glEnableVertexAttribArray(ATTRIB_POSITION);
    glEnableVertexAttribArray(ATTRIB_NORMAL);

    // ATTRIB_TEXCOORDS :: 1;
    // ATTRIB_COLOR     :: 2;

    NP := size_of(Vector3) * mesh.positions.count;

    glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), null);
    glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)(NP));

    // @Cleanup only set when mode==.LINE
    last_line_width: float;
    glGetFloatv(GL_LINE_WIDTH, xx *last_line_width);
    if (wireframe_width > 0) {
        glLineWidth(xx wireframe_width); // See also glEnable(GL_LINE_SMOOTH);
    }

    last_polygon_mode: [2]GLuint;
    glGetIntegerv(GL_POLYGON_MODE, xx last_polygon_mode.data);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glEnable(GL_PROGRAM_POINT_SIZE);
}

get_point_text_format_float :: (v : float) -> FormatFloat #expand {
    f := `theme.format_float;
    f.value = v;
    return f;
}

get_point_text :: (point : Vector2, point_index : int, theme : Label_Theme, label_index_offset : int = 0) -> string {
    result : string;
    f :: get_point_text_format_float;
    if  theme.show_index &&  theme.show_position result = tprint("% (%, %)", label_index_offset + point_index, f(point.x), f(point.y));
    if !theme.show_index &&  theme.show_position result = tprint("(%, %)", f(point.x), f(point.y));
    if  theme.show_index && !theme.show_position result = tprint("%", label_index_offset + point_index);
    return result;
}

get_point_text :: (point : Vector3, point_index : int, theme : Label_Theme, label_index_offset : int = 0) -> string #expand {
    result : string;
    f :: get_point_text_format_float;
    if  theme.show_index &&  theme.show_position result = tprint("% (%, %, %)", label_index_offset + point_index, f(point.x), f(point.y), f(point.z));
    if !theme.show_index &&  theme.show_position result = tprint("(%, %, %)", f(point.x), f(point.y), f(point.z));
    if  theme.show_index && !theme.show_position result = tprint("%", label_index_offset + point_index);
    return result;
}

// [-1, 1]x[-1,1] -> [0, current_window_width]x[0, current_window_height]
get_text_screen_position :: (point : Vector4, world_from_model : Matrix4) -> Vector2 {
    projection_from_model := make_projection_from_world(app.camera) * world_from_model;
    result := projection_from_model * point;
    result.x = cast(float)app.current_window_width *  (result.x + 1) / 2;
    result.y = cast(float)app.current_window_height * (result.y + 1) / 2;
    return result.xy;
}

render_entities :: () {

    render_entity_geometry :: (entity : *Entity) {
        ri := *entity.render_info;
        di :=  entity.display_info;
        old_display_info := entity.display_info;
        defer entity.display_info = old_display_info;

        if #complete entity.type == {
            case .POLYLINE_SOUP2;

                soup := cast(*Polyline_Soup2_Entity) entity;
                render_mesh_points(*soup.mesh, ri, di);
                render_mesh_lines(*soup.mesh, ri, di);
                render_aabb(*soup.mesh, ri, di);

            case .POLYLINE_SOUP3;

                soup := cast(*Polyline_Soup3_Entity) entity;
                render_mesh_points(*soup.mesh, ri, di);
                render_mesh_lines(*soup.mesh, ri, di);
                render_aabb(*soup.mesh, ri, di);

            case .POLYGON_SOUP;

                soup := cast(*Polygon_Soup_Entity) entity;
                render_mesh_points(*soup.mesh, ri, di);
                render_mesh_triangles(*soup.mesh, ri, di);
                render_aabb(*soup.mesh, ri, di);

            case .POINT_CLOUD;

                cloud := cast(*Point_Cloud_Entity) entity;
                render_mesh_points(*cloud.mesh, ri, di);
                render_normals(*cloud.mesh, ri, di);
                render_aabb(*cloud.mesh, ri, di);

            case .MESH;

                mesh := cast(*Mesh_Entity) entity;
                render_mesh_points(*mesh.mesh, ri, di);
                if do_clip_radius_mode() {
                    di.wireframe_visible, di.wireframe_width = true, 1.5;
                }
                render_mesh_triangles(*mesh.mesh, ri, di);
                if do_clip_radius_mode() {
                    di.wireframe_visible, di.wireframe_width = true, 1.0;
                } else if di.surface_visible && di.wireframe_width >= 1 {
                    // Always draw the wireframe with GL_LINES in render_mesh_lines but make it thinner than the
                    // smooth version drawn in the render_mesh_triangles call
                    di.wireframe_width = max(di.wireframe_width - 1, 1);
                }
                render_mesh_lines(*mesh.mesh, ri, di);
                render_normals(*mesh.mesh, ri, di);
                render_aabb(*mesh.mesh, ri, di);

            case .UNKNOWN;
        }
    }

    render_entity_text :: (entity : *Entity, label_limit : *int) {
        glEnable(GL_BLEND);
        defer glDisable(GL_BLEND);
        // Culling is unhelpful for polygon meshes @Cleanup make this a property on the mesh
        // glDisable(GL_CULL_FACE);
        // defer glEnable(GL_CULL_FACE);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

        // @TODO call render_text_quad once with a list of points?

        if #complete entity.type == {
            case .UNKNOWN;
            case .POLYLINE_SOUP2;

                soup := cast(*Polyline_Soup2_Entity) entity;
                point_theme := entity.display_info.vertex_label_style;
                segment_theme := entity.display_info.element_label_theme;

                for :point_iterator soup.shape {
                    if is_clipped(entity.display_info, make_vector3(it, 0)) continue;
                    if <<label_limit <= 0 continue; <<label_limit -= 1;

                    text := get_point_text(it, it_index, point_theme);
                    text_position_px := get_text_screen_position(make_vector4(it, 0, 1), soup.mesh.world_from_model);
                    render_text_quad(app.text_program, text, text_position_px, point_theme.label_scale, point_theme.label_color);
                }

                for :segment_iterator soup.shape {
                    centroid := (<<it.from_point + <<it.to_point) / 2;
                    if is_clipped(entity.display_info, make_vector3(centroid, 0)) continue;
                    if <<label_limit <= 0 continue; <<label_limit -= 1;

                    text := get_point_text(centroid, it_index, segment_theme);
                    text_position_px := get_text_screen_position(make_vector4(centroid, 0, 1), soup.mesh.world_from_model);
                    render_text_quad(app.text_program, text, text_position_px, segment_theme.label_scale, segment_theme.label_color);
                }

            case .POLYLINE_SOUP3;

                soup := cast(*Polyline_Soup3_Entity) entity;
                point_theme := entity.display_info.vertex_label_style;
                segment_theme := entity.display_info.element_label_theme;

                for :point_iterator soup.shape {
                    if is_clipped(entity.display_info, it) continue;
                    if <<label_limit <= 0 continue; <<label_limit -= 1;

                    text := get_point_text(it, it_index, point_theme);
                    text_position_px := get_text_screen_position(make_vector4(it, 1), soup.mesh.world_from_model);
                    render_text_quad(app.text_program, text, text_position_px, point_theme.label_scale, point_theme.label_color);
                }

                for :segment_iterator soup.shape {
                    centroid := (<<it.from_point + <<it.to_point) / 2;
                    if is_clipped(entity.display_info, centroid) continue;
                    if <<label_limit <= 0 continue; <<label_limit -= 1;

                    text := get_point_text(centroid, it_index, segment_theme);
                    text_position_px := get_text_screen_position(make_vector4(centroid, 1), soup.mesh.world_from_model);
                    render_text_quad(app.text_program, text, text_position_px, segment_theme.label_scale, segment_theme.label_color);
                }

            case .POLYGON_SOUP;

                // @Refactor use iterators and label segments
                soup := cast(*Polygon_Soup_Entity) entity;
                count := point_count(soup.shape);
                point_theme := entity.display_info.vertex_label_style;

                for polygon : soup.shape.polygons {
                    for polygon.outer_ring.points {
                        if is_clipped(entity.display_info, make_vector3(it, 0)) continue;
                        if <<label_limit <= 0 continue; <<label_limit -= 1;

                        text := get_point_text(it, it_index, point_theme);
                        text_position_px := get_text_screen_position(make_vector4(it, 0, 1), soup.mesh.world_from_model);
                        render_text_quad(app.text_program, text, text_position_px, point_theme.label_scale, point_theme.label_color);

                        for inner_ring : polygon.inner_rings for inner_ring.points {
                            if is_clipped(entity.display_info, make_vector3(it, 0)) continue;
                            if <<label_limit <= 0 continue; <<label_limit -= 1;

                            text := get_point_text(it, it_index, point_theme);
                            text_position_px := get_text_screen_position(make_vector4(it, 0, 1), soup.mesh.world_from_model);
                            render_text_quad(app.text_program, text, text_position_px, point_theme.label_scale, point_theme.label_color);
                        }
                    }
                }

            case .POINT_CLOUD;

                cloud := cast(*Point_Cloud_Entity) entity;
                count := cloud.mesh.positions.count;
                point_theme := entity.display_info.vertex_label_style;

               for cloud.mesh.positions {
                   if is_clipped(entity.display_info, it) continue;
                   if <<label_limit <= 0 && entity != *app.user_selection continue; <<label_limit -= 1;

                   text := get_point_text(it, it_index, point_theme);
                   text_position_px := get_text_screen_position(make_vector4(it, 1), cloud.mesh.world_from_model);
                   render_text_quad(app.text_program, text, text_position_px, point_theme.label_scale, point_theme.label_color);
               }

            case .MESH;

                mesh := cast(*Mesh_Entity) entity;
                count := mesh.mesh.positions.count;
                point_theme := entity.display_info.vertex_label_style;
                triangle_theme := entity.display_info.element_label_theme;

               for mesh.mesh.positions {
                   if is_clipped(entity.display_info, it) continue;
                   if <<label_limit <= 0 && entity != *app.user_selection continue; <<label_limit -= 1;

                   text := get_point_text(it, it_index, point_theme);
                   text_position_px := get_text_screen_position(make_vector4(it, 1), mesh.mesh.world_from_model);
                   render_text_quad(app.text_program, text, text_position_px, point_theme.label_scale, point_theme.label_color);
               }

               for :triangles_iterator mesh.mesh {
                   centroid := (it.a + it.b + it.c) / 3;
                   if is_clipped(entity.display_info, centroid) continue;
                   if <<label_limit <= 0 && entity != *app.user_selection continue; <<label_limit -= 1;

                   text := get_point_text(centroid, it_index, triangle_theme);
                   text_position_px := get_text_screen_position(make_vector4(centroid, 1), mesh.mesh.world_from_model);
                   render_text_quad(app.text_program, text, text_position_px, triangle_theme.label_scale, triangle_theme.label_color);
               }
        }
    }

    is_visible_opaque ::      (e : *Entity) -> bool { return e.is_visible && !e.is_hovered && e.display_info.surface_color.w == 1.; }
    is_visible_transparent :: (e : *Entity) -> bool { return e.is_visible && !e.is_hovered && e.display_info.surface_color.w != 1.; }
    is_visible_hovered ::     (e : *Entity) -> bool { return e.is_visible &&  e.is_hovered; }

    visible_opaque ::      #bake_arguments entities_iterator(should_visit = is_visible_opaque);
    visible_transparent :: #bake_arguments entities_iterator(should_visit = is_visible_transparent);
    visible_hovered ::     #bake_arguments entities_iterator(should_visit = is_visible_hovered);

    for :visible_opaque      app.entities render_entity_geometry(it);
    for :visible_transparent app.entities render_entity_geometry(it);

    glClear(GL_DEPTH_BUFFER_BIT); // Render the text labels and flash hovered item over everything else

    label_limit : int = app.label_limit;
    for :visible_opaque      app.entities render_entity_text(it, *label_limit);
    for :visible_transparent app.entities render_entity_text(it, *label_limit);
    for :visible_hovered     app.entities render_entity_text(it, *label_limit);

    for :visible_hovered     app.entities render_entity_geometry(it);
}

render_background :: () {
    if #complete app.background_style == {
        case .SOLID_COLOR;

            using app.background_solid_color;
            glClearColor(x, y, z, w);

        case .CUSTOM_SHADER;

            glDisable(GL_DEPTH_TEST);
            defer glEnable(GL_DEPTH_TEST);
            glUseProgram(app.background_program);
            x, y, z : float = xx app.current_window_width, xx app.current_window_height, 1.;
            glUniform3f(glGetUniformLocation(app.background_program, "iResolution"), x, y, z);
            glUniform1f(glGetUniformLocation(app.background_program, "iTime"), xx ImGui.GetTime());
            glBindVertexArray(app.background_vao);
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
}
