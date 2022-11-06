// Fixed! ISSUE_004 :: "The text rendering implementation currently sucks and is very slow (hence disabled) for large numbers of glyphs. To render text on large meshes use a clipping volume to reduce the number of visible elements and the text should show up."; @KnownIssue;

// @Refactor rename this Label_Theme, and use it for triangle labels (at centroid, so you can see centroids, too)
Label_Theme :: struct {
    show_position := false;
    show_index := false;

    visible_radius_px : int = 50;
    show_backfacing : bool = true;

    // world_space : bool = false; // @Incomplete
    format_float : FormatFloat; // We ignore the `value` field
    format_float.mode = .SHORTEST;
    format_float.trailing_width = 8;
    format_float.zero_removal = .NO;

    label_scale := .3;
    label_color : Vector4 = .{0., 0., .75, 1.}; // Blue, works well on both grey and white backgrounds
}

is_visible :: (theme : Label_Theme) -> bool {
    return theme.show_position || theme.show_index;
}

Annotation_Theme :: struct {
    // // @Incomplete Implement this
    // show_point_annotation := false;
    // show_centroid_annotation := false;

    visible := false;
    visible_radius_px : int = 50;
    label_scale := .3;
    label_color : Vector4 = .{0., 0., .75, 1.}; // Blue, works well on both grey and white backgrounds
}

is_visible :: (theme : Annotation_Theme) -> bool {
    return theme.visible;
}

Attribute_Theme :: struct {
    visible := false;
    visible_radius_px : int = 50;
    label_scale := .3;
    label_color : Vector4 = .{0., 0., .75, 1.}; // Blue, works well on both grey and white backgrounds

    format_float : FormatFloat; // We ignore the `value` field
    format_float.mode = .SHORTEST;
    format_float.trailing_width = 8;
    format_float.zero_removal = .NO;

    format_struct : FormatStruct; // We ignore the `value` field
}

Attribute_Theme_Update :: struct {
    // @Incomplete
}

Display_Mode :: enum #specified {
    NORMALS ::     0;
    SOLID_COLOR :: 1;
    BLINN_PHONG :: 2;
}

Backface_Mode :: enum #specified {
    NONE :: 0;
    CULL :: 1;
    FIXED :: 2;
    DARKEN :: 3;
    SCREENTONE_1 :: 4; // Maybe a screentone option where tone-aligned pixels are culled, so its kindof like the transparency hack
    SCREENTONE_2 :: 5;
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

    // Important: In the entity (a.k.a., entity.mesh) model space
    bounding_sphere : Sphere;
    bounding_aabb : AxisBox3;
}

// @Volatile Keep synced with shaders
Clip_Range :: struct {
    normal : Vector3; // @Cleanup Is this unit???
    is_active : bool;
    min : float = 0hFF800000; // -inf
    max : float = 0h7F800000; // +inf
}

// Note: all arguments must be in the same space e.g., world/model coordinates
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
    using #as sphere : Sphere;
    radius = 0h7F800000; // +inf
    is_active : bool = false;
}

// Note: all arguments must be in the same space e.g., world/model coordinates
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

    is_visible := true; // Is the item visible overall?

    flash_wave_dt : float = 0.; @NoSync

    points_visible := false;
    points_color := Vector4.{.5, .5, .5, 1.};
    points_size : s32 = 0;
    vertex_label_style : Label_Theme;
    element_label_theme : Label_Theme;
    annotation_theme : Annotation_Theme;
    normals_visible := false;
    normals_color := Vector4.{0., 0., .8, 1.};
    normals_length : float = 1.;

    wireframe_visible := false;
    wireframe_color := Vector4.{0., 0., 0., 1.};
    wireframe_width : float = 0.;

    surface_visible := true;
    surface_color := Vector4.{1., 1., 1., 1.};

    display_mode := Display_Mode.BLINN_PHONG;
    backface_mode := Backface_Mode.FIXED;
    flat_shading := true;

    aabb_visible := false; @NoSync

    // These are all in world space
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
                log_warning("Computing and assigning triangle normals to vertices, reason: \"%\"", failure_reason);
            }
        }

        // Note: We do _not_ apply the mesh.world_from_model transform here, that is
        // stored separately to the raw position data so it can be changed efficiently
        // i.e., bounding geometry is defined in the mesh model space
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
    set_model_view_projection_uniforms(app.normals_program, mesh);
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
    set_model_view_projection_uniforms(app.aabb_program, mesh);

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

render_mesh_triangles :: (mesh : *Mesh, using render_info : *Render_Info, using display_info : Display_Info, clip_radius_mode := false) {
    if !surface_visible return;

    render_mesh_common(mesh, render_info, display_info, clip_radius_mode);

    glUniform1i(glGetUniformLocation(app.mesh_program, "display_mode"), xx display_mode);
    glUniform1i(glGetUniformLocation(app.mesh_program, "backface_mode"), xx backface_mode);
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

render_mesh_common :: (mesh : *Mesh, using render_info : *Render_Info, using display_info : Display_Info, clip_radius_mode := false) {

    maybe_update_render_info(render_info, mesh);

    glUseProgram(app.mesh_program);

    set_model_view_projection_uniforms(app.mesh_program, mesh);

    wave := ifx flash_wave_dt == 0 then -1 else cos(5 * flash_wave_dt);
    glUniform1f(glGetUniformLocation(app.mesh_program, "wave"), wave);
    glUniform3f(glGetUniformLocation(app.mesh_program, "camera.eye_position"), app.camera.eye_position.x, app.camera.eye_position.y, app.camera.eye_position.z);
    look_direction := current_look_direction();
    glUniform3f(glGetUniformLocation(app.mesh_program, "camera.look_direction"), look_direction.x, look_direction.y, look_direction.z);

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
        glUniform1ui(glGetUniformLocation(app.mesh_program, "clip_radius_mode"), xx clip_radius_mode);
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

    set_model_view_projection_uniforms(app.simple_mesh_program, mesh);

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

get_point_text :: (point : Vector3, point_index : int, theme : Label_Theme, label_index_offset : int = 0) -> string {
    result : string;
    f :: get_point_text_format_float;
    if  theme.show_index &&  theme.show_position result = tprint("% (%, %, %)", label_index_offset + point_index, f(point.x), f(point.y), f(point.z));
    if !theme.show_index &&  theme.show_position result = tprint("(%, %, %)", f(point.x), f(point.y), f(point.z));
    if  theme.show_index && !theme.show_position result = tprint("%", label_index_offset + point_index);
    return result;
}

// [-1, 1]x[-1,1] -> [0, current_window_width]x[0, current_window_height]
get_text_screen_position :: (point : Vector3, projection_from_model : Matrix4) -> Vector2 {
    result := transform_point(projection_from_model, point);
    result.x = cast(float)app.current_window_width *  (result.x + 1) / 2;
    result.y = cast(float)app.current_window_height * (result.y + 1) / 2;
    return result.xy;
}

on_screen_in_disk :: (text_position_px : Vector2, visible_radius_px : int) -> bool {
    if io().MousePos == make_ImVec2(-FLOAT32_MAX,-FLOAT32_MAX) {
        return false;
    }

    if text_position_px.x < 0 ||
       text_position_px.y < 0 ||
       text_position_px.x > xx app.current_window_width ||
       text_position_px.y > xx app.current_window_height {
        return false;
    }

    mouse_position_px := make_vector2(io().MousePos.x, app.current_window_height - io().MousePos.y);
    if distance(mouse_position_px, text_position_px) > xx visible_radius_px {
        return false;
    }

    return true;
}

render_entities :: () {

    Scope_GL_State();

    render_entity_geometry :: (entity : *Entity, entity_index : int) {
        ri := *entity.render_info;
        di :=  entity.display_info;
        old_display_info := entity.display_info;
        defer entity.display_info = old_display_info;

        clip_radius_mode :=
            do_clip_radius_mode() && app.clipping_sphere_mode_entity_index >= 0 &&
            (
                ( app.entities[app.clipping_sphere_mode_entity_index].is_selected && app.entities[entity_index].is_selected) ||
                (!app.entities[app.clipping_sphere_mode_entity_index].is_selected && app.clipping_sphere_mode_entity_index == entity_index)
            );

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
                render_normals(*soup.mesh, ri, di);
                render_aabb(*soup.mesh, ri, di);

            case .SEGMENT_SOUP3;

                soup := cast(*Segment_Soup3_Entity) entity;
                render_mesh_points(*soup.mesh, ri, di);
                render_mesh_lines(*soup.mesh, ri, di);
                render_normals(*soup.mesh, ri, di);
                render_aabb(*soup.mesh, ri, di);

            case .POLYGON_SOUP;

                soup := cast(*Polygon_Soup_Entity) entity;
                render_mesh_points(*soup.mesh, ri, di);
                render_mesh_triangles(*soup.mesh, ri, di, clip_radius_mode);
                render_aabb(*soup.mesh, ri, di);

            case .POINT_CLOUD;

                cloud := cast(*Point_Cloud_Entity) entity;
                render_mesh_points(*cloud.mesh, ri, di);
                render_normals(*cloud.mesh, ri, di);
                render_aabb(*cloud.mesh, ri, di);

            case .MESH;

                mesh := cast(*Mesh_Entity) entity;
                render_mesh_points(*mesh.mesh, ri, di);
                if clip_radius_mode {
                    di.wireframe_visible, di.wireframe_width = true, 1.5; // @Incomplete make this optional in settings
                }
                render_mesh_triangles(*mesh.mesh, ri, di, clip_radius_mode);
                if clip_radius_mode {
                    di.wireframe_visible, di.wireframe_width = true, 1.0; // @Incomplete make this optional in settings
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

    render_entity_text :: (entity : *Entity) {
        Simp.ScopeContext();

        // @Cleanup We could just do using entity.display_info here
        point_theme := entity.display_info.vertex_label_style;
        element_theme := entity.display_info.element_label_theme;
        annotation_theme := entity.display_info.annotation_theme;
        if !is_visible(point_theme) && !is_visible(element_theme) && !is_visible(annotation_theme) {
            return;
        }

        glEnable(GL_BLEND);
        defer glDisable(GL_BLEND);
        // Culling is unhelpful for polygon meshes @Cleanup make this a property on the mesh
        // glDisable(GL_CULL_FACE);
        // defer glEnable(GL_CULL_FACE);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

        // Caches for glyph quads
        point_label_quads :   [..]Simp.Font_Quad = temp_array(Element_Type=Simp.Font_Quad);
        element_label_quads : [..]Simp.Font_Quad = temp_array(Element_Type=Simp.Font_Quad);
        annotation_quads :    [..]Simp.Font_Quad = temp_array(Element_Type=Simp.Font_Quad);

        projection_from_world := make_projection_from_world(app.camera);
        projection_from_model := projection_from_world * entity.mesh.world_from_model;

        // @Incomplete Use a macro to implement the option to render text in model/world coordinates. Model is probably mostly useful for 2D shapes?
        // @Incomplete Add option to render points in world coordinates?

        if #complete entity.type == {
            case .UNKNOWN;
            case .POLYLINE_SOUP2;

                // @Incomplete Annotations
                soup := cast(*Polyline_Soup2_Entity) entity;

                if is_visible(point_theme) for :Point_Iterator soup.shape {
                    point_model : Vector3 = make_vector3(it, 0);
                    point_world : Vector3 = transform_point(entity.mesh.world_from_model, point_model);
                    if is_clipped(entity.display_info, point_world) continue;

                    text_position_px := get_text_screen_position(point_world, projection_from_world);
                    if on_screen_in_disk(text_position_px, point_theme.visible_radius_px) {
                        text := get_point_text(it, it_index, point_theme);
                        cache_text_quads(*point_label_quads, text, text_position_px, point_theme.label_scale);
                    }
                }

                if is_visible(element_theme) for :PolylineSegmentIterator soup.shape {
                    // @Cleanup Use centroid(Edge) here
                    point_model : Vector3 = make_vector3((<<it.from_point + <<it.to_point) / 2, 0);
                    point_world : Vector3 = transform_point(entity.mesh.world_from_model, point_model);
                    if is_clipped(entity.display_info, point_world) continue;

                    text_position_px : Vector2 = get_text_screen_position(point_world, projection_from_world);
                    if on_screen_in_disk(text_position_px, element_theme.visible_radius_px) {
                        text := get_point_text(point_model, it_index, element_theme);
                        cache_text_quads(*element_label_quads, text, text_position_px, element_theme.label_scale);
                    }
                }

            case .POLYLINE_SOUP3;

                soup := cast(*Polyline_Soup3_Entity) entity;

                if is_visible(annotation_theme) for :AnnotationIterator entity {
                    if it.kind == .VERTEX {
                        point_model : Vector3 = soup.mesh.positions[it.id];
                        point_world : Vector3 = transform_point(entity.mesh.world_from_model, point_model);
                        if is_clipped(entity.display_info, point_world) {
                            continue;
                        }

                        text_position_px : Vector2 = get_text_screen_position(point_model, projection_from_model);
                        if on_screen_in_disk(text_position_px, annotation_theme.visible_radius_px) {
                            text : string = to_string(it);
                            cache_text_quads(*annotation_quads, text, text_position_px, annotation_theme.label_scale);
                        }
                    } else if it.kind == .LINE {

                        // @Incomplete
                    }
                }

                if is_visible(point_theme) for :Point_Iterator point_model, point_index : soup.shape {
                    point_world := transform_point(entity.mesh.world_from_model, point_model);
                    if is_clipped(entity.display_info, point_world) continue;

                    text_position_px : Vector2 = get_text_screen_position(point_model, projection_from_model);
                    if on_screen_in_disk(text_position_px, point_theme.visible_radius_px) {
                        text : string = get_point_text(point_model, point_index, point_theme);
                        cache_text_quads(*point_label_quads, text, text_position_px, point_theme.label_scale);
                    }
                }

                if is_visible(element_theme) for :PolylineSegmentIterator soup.shape {
                    point_model : Vector3 = (<<it.from_point + <<it.to_point) / 2;
                    point_world : Vector3 = transform_point(entity.mesh.world_from_model, point_model);
                    if is_clipped(entity.display_info, point_world) continue;

                    text_position_px := get_text_screen_position(point_model, projection_from_model);
                    if on_screen_in_disk(text_position_px, element_theme.visible_radius_px) {
                        text : string = get_point_text(point_model, it_index, element_theme);
                        cache_text_quads(*element_label_quads, text, text_position_px, element_theme.label_scale);
                    }
                }

            case .SEGMENT_SOUP3;

                soup := cast(*Segment_Soup3_Entity) entity;

                if is_visible(annotation_theme) for :AnnotationIterator entity {
                    text : string = to_string(it);
                    if it.kind == .VERTEX {
                        point_world : Vector3 = mesh_point_world(soup.mesh, it.id);
                        if is_clipped(entity.display_info, point_world) {
                            continue;
                        }

                        point_model : Vector3 = mesh_point_model(soup.mesh, it.id);
                        text_position_px : Vector2 = get_text_screen_position(point_model, projection_from_model);
                        if on_screen_in_disk(text_position_px, annotation_theme.visible_radius_px) {
                            cache_text_quads(*annotation_quads, text, text_position_px, annotation_theme.label_scale);
                        }
                    } else if it.kind == .LINE {
                        point_world : Vector3 = centroid(mesh_segment3_world(soup.mesh, it.id));
                        if is_clipped(entity.display_info, point_world) {
                            continue;
                        }

                        point_model : Vector3 = centroid(mesh_segment3_model(soup.mesh, it.id));
                        text_position_px : Vector2 = get_text_screen_position(point_model, projection_from_model);
                        if on_screen_in_disk(text_position_px, annotation_theme.visible_radius_px) {
                            cache_text_quads(*annotation_quads, text, text_position_px, annotation_theme.label_scale);
                        }
                    }
                }

                if is_visible(point_theme) for :ModelPointIterator point_model, point_index : soup.mesh {
                    point_world : Vector3 = transform_point(soup.mesh.world_from_model, point_model);
                    if is_clipped(entity.display_info, point_world) continue;

                    text_position_px := get_text_screen_position(point_model, projection_from_model);
                    if on_screen_in_disk(text_position_px, point_theme.visible_radius_px) {
                        text := get_point_text(point_model, point_index, point_theme);
                        cache_text_quads(*point_label_quads, text, text_position_px, point_theme.label_scale);
                    }
                }

                if is_visible(element_theme) for :ModelSegmentIterator segment : soup.mesh {
                    point_model : Vector3 = centroid(segment);
                    point_world : Vector3 = transform_point(soup.mesh.world_from_model, point_model);
                    if is_clipped(entity.display_info, point_world) continue;

                    text_position_px : Vector2 = get_text_screen_position(point_model, projection_from_model);
                    if on_screen_in_disk(text_position_px, element_theme.visible_radius_px) {
                        text : string = get_point_text(point_model, it_index, element_theme);
                        cache_text_quads(*element_label_quads, text, text_position_px, element_theme.label_scale);
                    }
                }

            case .POLYGON_SOUP;

                // @Incomplete annotations
                // @Incomplete segment labels
                // @Refactor use iterators and label segments
                soup := cast(*Polygon_Soup_Entity) entity;
                count := point_count(soup.shape);

                if is_visible(point_theme) for polygon : soup.shape.polygons {
                    for polygon.outer_ring.points {
                        point_world := transform_point(entity.mesh.world_from_model, make_vector3(it, 0));
                        if is_clipped(entity.display_info, point_world) continue;

                        text_position_px := get_text_screen_position(make_vector3(it, 0), projection_from_model);
                        if on_screen_in_disk(text_position_px, point_theme.visible_radius_px) {
                            text := get_point_text(it, it_index, point_theme);
                            cache_text_quads(*point_label_quads, text, text_position_px, point_theme.label_scale);
                        }
                    }

                    for inner_ring : polygon.inner_rings for inner_ring.points {
                        point_world := transform_point(entity.mesh.world_from_model, make_vector3(it, 0));
                        if is_clipped(entity.display_info, point_world) continue;

                        text_position_px := get_text_screen_position(make_vector3(it, 0), projection_from_model);
                        if on_screen_in_disk(text_position_px, point_theme.visible_radius_px) {
                            text := get_point_text(it, it_index, point_theme);
                            cache_text_quads(*point_label_quads, text, text_position_px, point_theme.label_scale);
                        }
                    }
                }

            case .POINT_CLOUD;

                cloud := cast(*Point_Cloud_Entity) entity;
                count := cloud.mesh.positions.count;

                if is_visible(annotation_theme) for :AnnotationIterator entity {
                    if it.kind == .VERTEX {
                        point_world : Vector3 = mesh_point_world(cloud.mesh, it.id);
                        if is_clipped(entity.display_info, point_world) {
                            continue;
                        }

                        point_model : Vector3 = mesh_point_model(cloud.mesh, it.id);
                        text_position_px : Vector2 = get_text_screen_position(point_model, projection_from_model);
                        if on_screen_in_disk(text_position_px, annotation_theme.visible_radius_px) {
                            text := to_string(it);
                            cache_text_quads(*annotation_quads, text, text_position_px, annotation_theme.label_scale);
                        }
                    }
                }

                inverse_transpose := transpose(inverse(cloud.mesh.world_from_model));
                if is_visible(point_theme) for :ModelPointIterator point_model, point_index : cloud.mesh {
                    if point_theme.show_backfacing == false && cloud.mesh.normals.count {
                        world_normal : Vector3 = transform_vector(inverse_transpose, cloud.mesh.normals[point_index]);
                        if dot_product(world_normal, current_look_direction()) > 0 {
                            continue;
                        }
                    }

                    point_world : Vector3 = mesh_point_world(entity.mesh, point_index);
                    if is_clipped(entity.display_info, point_world) {
                        continue;
                    }

                    text_position_px := get_text_screen_position(point_model, projection_from_model);
                    if on_screen_in_disk(text_position_px, point_theme.visible_radius_px) {
                        text := get_point_text(point_model, point_index, point_theme);
                        cache_text_quads(*point_label_quads, text, text_position_px, point_theme.label_scale);
                    }
                }

            case .MESH;

                mesh := cast(*Mesh_Entity) entity;
                count := mesh.mesh.positions.count;

                // @Speed this should use the spatial index??
                if is_visible(annotation_theme) for :AnnotationIterator entity {
                    text : string = to_string(it);
                    if it.kind == {
                        case .VERTEX;

                            point_model : Vector3 = mesh_point_model(mesh.mesh, it.id);
                            point_world : Vector3 = mesh_point_world(mesh.mesh, it.id);
                            if is_clipped(entity.display_info, point_world) {
                                continue;
                            }

                            text_position_px : Vector2 = get_text_screen_position(point_model, projection_from_model);
                            if on_screen_in_disk(text_position_px, annotation_theme.visible_radius_px) {
                                cache_text_quads(*annotation_quads, text, text_position_px, annotation_theme.label_scale);
                            }

                        case .TRIANGLE;

                            point_model : Vector3 = compute_centroid(mesh_triangle_model(mesh.mesh, it.id));
                            point_world : Vector3 = transform_point(entity.mesh.world_from_model, point_model);
                            if is_clipped(entity.display_info, point_world) {
                                continue;
                            }

                            text_position_px := get_text_screen_position(point_model, projection_from_model);
                            if on_screen_in_disk(text_position_px, annotation_theme.visible_radius_px) {
                                cache_text_quads(*annotation_quads, text, text_position_px, annotation_theme.label_scale);
                            }
                    }
                }

                // @Speed this should use the spatial index??
                inverse_transpose := transpose(inverse(mesh.mesh.world_from_model));
                if is_visible(point_theme) for :ModelPointIterator point_model, point_index : mesh.mesh {
                    if point_theme.show_backfacing == false && mesh.mesh.normals.count {
                        normal_world : Vector3 = transform_vector(inverse_transpose, mesh.mesh.normals[point_index]);
                        if dot_product(normal_world, current_look_direction()) > 0 {
                            continue;
                        }
                    }

                    point_world := transform_point(entity.mesh.world_from_model, point_model);
                    if is_clipped(entity.display_info, point_world) {
                        continue;
                    }

                    text_position_px : Vector2 = get_text_screen_position(point_model, projection_from_model);
                    if on_screen_in_disk(text_position_px, point_theme.visible_radius_px) {
                        text : string = get_point_text(point_model, point_index, point_theme);
                        cache_text_quads(*point_label_quads, text, text_position_px, point_theme.label_scale);
                    }
                }

                ProcessTriangle :: (triangle_model : Triangle3, triangle_index : int) #expand {
                    if element_theme.show_backfacing == false {
                        normal_world : Vector3 = transform_vector(`inverse_transpose, compute_normal(triangle_model));
                        if dot_product(normal_world, current_look_direction()) > 0 {
                            continue;
                        }
                    }

                    point_model : Vector3 = compute_centroid(triangle_model);
                    point_world : Vector3 = transform_point(entity.mesh.world_from_model, point_model);
                    if is_clipped(entity.display_info, point_world) {
                        continue;
                    }

                    text_position_px : Vector2 = get_text_screen_position(point_model, projection_from_model);
                    if on_screen_in_disk(text_position_px, element_theme.visible_radius_px) {
                        text : string = get_point_text(point_model, triangle_index, element_theme);
                        cache_text_quads(*element_label_quads, text, text_position_px, element_theme.label_scale);
                    }
                }

                if mesh.spatial == null {
                    // log_error("Use brute force");
                    if is_visible(element_theme) for :ModelTriangleIterator mesh.mesh {
                        ProcessTriangle(it, it_index);
                    }
                } else {
                    // log_error("Use spatial index");

                    ray_world : Ray3 = make_camera_ray();
                    ray_model : Ray3 = transform_ray(inverse(mesh.mesh.world_from_model), ray_world);

                    // @Incomplete Support perspective projection
                    distance := ((app.camera.right - app.camera.left) / app.current_window_width) * element_theme.visible_radius_px;

                    if is_visible(element_theme) Visit_Primitives_Near_Ray(mesh.spatial, ray_model, distance,
                        #code ProcessTriangle(primitive, primitive_id)
                    );
                }
        }

        draw_cached_text_quads(point_label_quads, point_theme.label_color);
        draw_cached_text_quads(element_label_quads, element_theme.label_color);
        draw_cached_text_quads(annotation_quads, annotation_theme.label_color);
    }

    is_visible_opaque ::      (e : *Entity) -> bool { return e.display_info.is_visible && !e.is_hovered && e.display_info.surface_color.w == 1.; }
    is_visible_transparent :: (e : *Entity) -> bool { return e.display_info.is_visible && !e.is_hovered && e.display_info.surface_color.w != 1.; }
    is_visible_hovered ::     (e : *Entity) -> bool { return e.display_info.is_visible &&  e.is_hovered; }

    Visible_Opaque ::      #bake_arguments Entities_Iterator(should_visit = is_visible_opaque);
    Visible_Transparent :: #bake_arguments Entities_Iterator(should_visit = is_visible_transparent);
    Visible_Hovered ::     #bake_arguments Entities_Iterator(should_visit = is_visible_hovered);

    for :Visible_Opaque      app.entities render_entity_geometry(it, it_index);
    for :Visible_Transparent app.entities render_entity_geometry(it, it_index);

    glClear(GL_DEPTH_BUFFER_BIT); // Render the text labels and flash hovered item over everything else

    for :Visible_Opaque      app.entities render_entity_text(it);
    for :Visible_Transparent app.entities render_entity_text(it);
    for :Visible_Hovered     app.entities render_entity_text(it);

    for :Visible_Hovered     app.entities render_entity_geometry(it, it_index);
}

// This function was added so that we could use Simp *when it was using the same context as the rest of the
// application*, we don't do this anymore so it's not really needed but rather than moving it from the call
// sites where it was needed I just commented the implementation. Anyway, the reason it was needed is because
// of the way Simp.immediate_set_shader works (when called from Simp.set_shader_for_color, tracking the state
// of the currently set shader separately to opengl) we can break it by getting opengl out of sync.  This
// happens when we set the shader program in gl, without simp/ knowing about it, so it doesn't know it needs
// to set the shader program again. Here, just to be safe/general, we set a bunch of other opengl state, too.
Scope_GL_State :: () #expand {
    /*
    // Backup GL state
    last_active_texture : GLenum; glGetIntegerv(GL_ACTIVE_TEXTURE, xx *last_active_texture);
    glActiveTexture(GL_TEXTURE0);
    last_program : GLuint; glGetIntegerv(GL_CURRENT_PROGRAM, xx *last_program);
    last_texture : GLuint; glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    last_array_buffer : GLuint; glGetIntegerv(GL_ARRAY_BUFFER_BINDING, xx *last_array_buffer);
    last_vertex_array_object : GLuint; glGetIntegerv(GL_VERTEX_ARRAY_BINDING, xx *last_vertex_array_object);
    last_viewport : [4]GLint; glGetIntegerv(GL_VIEWPORT, last_viewport.data);
    last_scissor_box : [4]GLint; glGetIntegerv(GL_SCISSOR_BOX, last_scissor_box.data);
    last_blend_src_rgb : GLenum; glGetIntegerv(GL_BLEND_SRC_RGB, xx *last_blend_src_rgb);
    last_blend_dst_rgb : GLenum; glGetIntegerv(GL_BLEND_DST_RGB, xx *last_blend_dst_rgb);
    last_blend_src_alpha : GLenum; glGetIntegerv(GL_BLEND_SRC_ALPHA, xx *last_blend_src_alpha);
    last_blend_dst_alpha : GLenum; glGetIntegerv(GL_BLEND_DST_ALPHA, xx *last_blend_dst_alpha);
    last_blend_equation_rgb : GLenum; glGetIntegerv(GL_BLEND_EQUATION_RGB, xx *last_blend_equation_rgb);
    last_blend_equation_alpha : GLenum; glGetIntegerv(GL_BLEND_EQUATION_ALPHA, xx *last_blend_equation_alpha);
    last_enable_blend := glIsEnabled(GL_BLEND);
    last_enable_cull_face := glIsEnabled(GL_CULL_FACE);
    last_enable_depth_test := glIsEnabled(GL_DEPTH_TEST);
    last_enable_stencil_test := glIsEnabled(GL_STENCIL_TEST);
    last_enable_scissor_test := glIsEnabled(GL_SCISSOR_TEST);

    `defer {
        // Restore modified GL state
        glUseProgram(last_program);
        glBindTexture(GL_TEXTURE_2D, last_texture);
        glActiveTexture(last_active_texture);
        glBindVertexArray(last_vertex_array_object);
        glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
        glBlendEquationSeparate(last_blend_equation_rgb, last_blend_equation_alpha);
        glBlendFuncSeparate(last_blend_src_rgb, last_blend_dst_rgb, last_blend_src_alpha, last_blend_dst_alpha);
        if (last_enable_blend)        glEnable(GL_BLEND);        else glDisable(GL_BLEND);
        if (last_enable_cull_face)    glEnable(GL_CULL_FACE);    else glDisable(GL_CULL_FACE);
        if (last_enable_depth_test)   glEnable(GL_DEPTH_TEST);   else glDisable(GL_DEPTH_TEST);
        if (last_enable_stencil_test) glEnable(GL_STENCIL_TEST); else glDisable(GL_STENCIL_TEST);
        if (last_enable_scissor_test) glEnable(GL_SCISSOR_TEST); else glDisable(GL_SCISSOR_TEST);
        glViewport(last_viewport[0], last_viewport[1], xx last_viewport[2], xx last_viewport[3]);
        glScissor(last_scissor_box[0], last_scissor_box[1], xx last_scissor_box[2], xx last_scissor_box[3]);
    }
    */
}

render_background :: () {

    Scope_GL_State();

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


// Generate and cache quad data before its lost on the next call to prepare_text
cache_text_quads :: (cache : *[..]Simp.Font_Quad, text : string, text_position_px : Vector2, scale : float) {
    Simp.prepare_text(app.simp_font, text);
    Simp.generate_quads_for_prepared_text(app.simp_font, xx text_position_px.x, xx text_position_px.y, 0, scale);
    for app.simp_font.current_quads array_add(cache, it);
}

draw_cached_text_quads :: (quads : [..]Simp.Font_Quad, color : Vector4) {
    if !quads.count return;
    cached_font : Simp.Dynamic_Font = <<app.simp_font;
    cached_font.current_quads = quads;
    Simp.draw_generated_quads(*cached_font, color);
}
