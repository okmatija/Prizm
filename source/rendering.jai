// Copyright Epic Games, Inc. All Rights Reserved.

Vertex_Label_Style :: struct {
    show_position := false;
    show_index := false;

    format_float : FormatFloat;
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

// @Volatile Keep synced with shaders
Clip_Sphere :: struct {
    using sphere : Sphere;
    radius = 0;
    is_active : bool = false;
}

// Things that should be preserved when the geometry changes
Display_Info :: struct {

    flash_wave_dt : float = 0.;

    points_visible := false;
    points_color := Vector4.{.5, .5, .5, 1.}; // RGBA
    points_size : s32 = 0;
    vertex_label_style : Vertex_Label_Style;

    normals_visible := false;
    normals_color := Vector4.{0., 0., .8, 1.}; // RGBA
    normals_length : float = 1.;

    wireframe_visible := false;
    wireframe_color := Vector4.{0., 0., 0., 1.}; // RGBA
    wireframe_width : float = 0.;

    surface_visible := true;
    surface_color := Vector4.{1., 1., 1., 1.}; // RGBA

    display_mode := Display_Mode.BLINN_PHONG;
    screentone_backfaces := true;
    flat_shading := true;

    aabb_visible := false;

    clip_ranges : [3]Clip_Range;
    clip_ranges[0] = .{normal=.{1,0,0}};
    clip_ranges[1] = .{normal=.{0,1,0}};
    clip_ranges[2] = .{normal=.{0,0,1}};

    clip_sphere : Clip_Sphere;
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
    if !normals_visible {
        return;
    }

    maybe_update_render_info(render_info, mesh);

    glUseProgram(app.normals_program);

    set_model_view_projection_uniforms(app.normals_program, <<mesh);
    glUniform4f(glGetUniformLocation(app.normals_program, "normals_color"), normals_color.x, normals_color.y, normals_color.z, normals_color.w);
    glUniform1f(glGetUniformLocation(app.normals_program, "normal_length"), normals_length);

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
    render_mesh_common(mesh, render_info, display_info);

    glUniform1i(glGetUniformLocation(app.mesh_program, "display_mode"), xx Display_Mode.BLINN_PHONG);
    glUniform1ui(glGetUniformLocation(app.mesh_program, "screentone_backfaces"), xx false);
    glUniform4f(glGetUniformLocation(app.mesh_program, "color"), points_color.x, points_color.y, points_color.z, points_color.w);

    glDrawArrays(GL_POINTS, 0, xx mesh.positions.count);
}

render_mesh_lines :: (mesh : *Mesh, using render_info : *Render_Info, using display_info : Display_Info) {
    if !wireframe_visible return;
    render_mesh_common(mesh, render_info, display_info);

    glUniform1i(glGetUniformLocation(app.mesh_program, "display_mode"), xx Display_Mode.SOLID_COLOR);
    glUniform1ui(glGetUniformLocation(app.mesh_program, "screentone_backfaces"), xx false);
    glUniform4f(glGetUniformLocation(app.mesh_program, "color"), wireframe_color.x, wireframe_color.y, wireframe_color.z, wireframe_color.w);

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

    {
        loc := glGetUniformLocation(app.mesh_program, "wave");
        wave := ifx flash_wave_dt == 0 then -1 else cos(5 * flash_wave_dt);
        glUniform1f(loc, wave);
    }

    {
        loc := glGetUniformLocation(app.mesh_program, "point_size");
        glUniform1f(loc, xx points_size);
    }

    {
        loc := glGetUniformLocation(app.mesh_program, "camera.eye_position");
        glUniform3f(loc, app.camera.eye_position.x, app.camera.eye_position.y, app.camera.eye_position.z);
    }

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

    glEnable(GL_PROGRAM_POINT_SIZE);
}

render_vertex_labels :: (points : []$T, world_from_model : Matrix4, style : Vertex_Label_Style, label_index_offset : int = 0) {
    #assert(T == Vector2 || T == Vector3);
    dim :: #run dimension_of(T);

    if !style.show_index && !style.show_position {
        return;
    }

    glEnable(GL_BLEND);
    defer glDisable(GL_BLEND);
    // Culling is unhelpful for polygon meshes @Cleanup make this a property on the mesh
    // glDisable(GL_CULL_FACE);
    // defer glEnable(GL_CULL_FACE);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    projection_from_model := make_projection_from_world(app.camera) * world_from_model;

    new_context := context;
    push_context new_context {
        format_float := *context.print_style.default_format_float;
        <<format_float = style.format_float;

        // @TODO call render_text_quad once with a list of points
        for points {
            text : string;
#if dim == 2 {
            if  style.show_index && style.show_position text = tprint("% (%, %)", label_index_offset + it_index, it.x, it.y);
            if !style.show_index && style.show_position text = tprint("(%, %)", it.x, it.y);
} else {
            if  style.show_index && style.show_position text = tprint("% (%, %, %)", label_index_offset + it_index, it.x, it.y, it.z);
            if !style.show_index && style.show_position text = tprint("(%, %, %)", it.x, it.y, it.z);
}
            if  style.show_index && !style.show_position text = tprint("%", label_index_offset + it_index);
            if !style.show_index && !style.show_position break;

            text_w := get_text_width_in_pixels(text, 1.0);

            // [-1, 1]x[-1,1] -> [0, current_window_width]x[0, current_window_height]
#if dim == 2 {
            text_position_px := projection_from_model * make_vector4(it.x, it.y, 0, 1.);
} else {
            text_position_px := projection_from_model * make_vector4(it.x, it.y, it.z, 1.);
}
            text_position_px.x = cast(float)app.current_window_width * (text_position_px.x + 1) / 2;
            text_position_px.y = cast(float)app.current_window_height * (text_position_px.y + 1) / 2;

            render_text_quad(app.text_program, text, text_position_px.xy, style.label_scale, style.label_color);
        }
    }
}

render_entities :: () {

    render_entity_geometry :: (entity : *Entity) {
        if entity.type == {
            case .POLYLINE_SOUP2;

                soup := cast(*Polyline_Soup2_Entity) entity;
                render_mesh_points(*soup.mesh, *entity.render_info, entity.display_info);
                render_mesh_lines(*soup.mesh, *entity.render_info, entity.display_info);
                render_aabb(*soup.mesh, *entity.render_info, entity.display_info);

            case .POLYLINE_SOUP3;

                soup := cast(*Polyline_Soup3_Entity) entity;
                render_mesh_points(*soup.mesh, *entity.render_info, entity.display_info);
                render_mesh_lines(*soup.mesh, *entity.render_info, entity.display_info);
                render_aabb(*soup.mesh, *entity.render_info, entity.display_info);

            case .POLYGON_SOUP;

                soup := cast(*Polygon_Soup_Entity) entity;
                render_mesh_points(*soup.mesh, *entity.render_info, entity.display_info);
                render_mesh_triangles(*soup.mesh, *entity.render_info, entity.display_info);
                render_aabb(*soup.mesh, *entity.render_info, entity.display_info);

            case .MESH;

                mesh := cast(*Mesh_Entity) entity;
                render_mesh_points(*mesh.mesh, *entity.render_info, entity.display_info);
                render_mesh_triangles(*mesh.mesh, *entity.render_info, entity.display_info);
                render_normals(*mesh.mesh, *entity.render_info, entity.display_info);
                render_aabb(*mesh.mesh, *entity.render_info, entity.display_info);
        }
    }

    render_entity_text :: (entity : *Entity, label_limit : *int) {
        style := entity.display_info.vertex_label_style;

        if !style.show_index && !style.show_position {
            return;
        }

        if entity.type == {
            case .POLYLINE_SOUP2;

                soup := cast(*Polyline_Soup2_Entity) entity;
                for polyline : soup.shape.polylines {
                    <<label_limit -= polyline.points.count;
                    if <<label_limit >= 0 {
                        render_vertex_labels(polyline.points, soup.mesh.world_from_model, style);
                    }
                }

            case .POLYLINE_SOUP3;

                soup := cast(*Polyline_Soup3_Entity) entity;
                for polyline : soup.shape.polylines {
                    <<label_limit -= polyline.points.count;
                    if <<label_limit >= 0 {
                        render_vertex_labels(polyline.points, soup.mesh.world_from_model, style);
                    }
                }

            case .POLYGON_SOUP;

                soup := cast(*Polygon_Soup_Entity) entity;
                for polygon : soup.shape.polygons {
                    <<label_limit -= point_count(polygon);
                    if <<label_limit >= 0 {
                        render_vertex_labels(polygon.outer_ring.points, soup.mesh.world_from_model, style);
                        for inner_ring : polygon.inner_rings {
                            render_vertex_labels(inner_ring.points, soup.mesh.world_from_model, style);
                        }
                    }
                }

            case .MESH;

                mesh := cast(*Mesh_Entity) entity;
                // @Cleanup so the transform is also available for text rendering
                <<label_limit -= mesh.mesh.positions.count;
                if <<label_limit >= 0 || (entity == *app.user_selection) {
                    render_vertex_labels(mesh.mesh.positions, mesh.mesh.world_from_model, style);
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
