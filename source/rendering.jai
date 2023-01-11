// Fixed! ISSUE_004 :: "The text rendering implementation currently sucks and is very slow (hence disabled) for large numbers of glyphs. To render text on large meshes use a clipping volume to reduce the number of visible elements and the text should show up."; @KnownIssue;

DEFAULT_LABEL_SCALE :: .4;

Labelling_Mode :: enum {
    RAY_CAST;  // Labels are shown on the intersection/closest preferred point to the camera ray
    SPOTLIGHT; // Labels are shown if query positions are within some (pixel) distance of the cursor
}

Vertex_Label_Theme :: struct {
    // @Cleanup replace with a combo box
    show_index := false;
    show_position := false;

    label_scale := DEFAULT_LABEL_SCALE;
    label_color : Vector4 = .{0., 0., .75, 1.}; // Blue, works well on both grey and white backgrounds

    // world_space : bool = false; // @Incomplete
}

// For mesh topology/geometry labels
Element_Label_Theme :: struct {
    show_index := false;
    label_scale := DEFAULT_LABEL_SCALE;
    label_color := Vector4.{1., 1., 0, 1};
}


is_visible :: (theme : Vertex_Label_Theme) -> bool {
    return theme.show_position || theme.show_index;
}

is_visible :: (theme : Element_Label_Theme) -> bool {
    return theme.show_index;
}

Annotation_Label_Theme :: struct {
    visible := false;
    label_scale := DEFAULT_LABEL_SCALE;
    label_color : Vector4 = .{0., 0., .75, 1.}; // Blue, works well on both grey and white backgrounds
}

is_visible :: (theme : Annotation_Label_Theme) -> bool {
    return theme.visible;
}

Attribute_Theme :: struct {
    visible := false;
    label_scale := DEFAULT_LABEL_SCALE;
    label_color : Vector4 = .{0., 0., .75, 1.}; // Blue, works well on both grey and white backgrounds
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
// @Cleanup Consider moving the is_dirty flag and bounding geometry data into the entity or mesh
Render_Info :: struct {
    is_dirty := true;

    vbo : GLuint;

    points_ibo : GLuint;
    segments_ibo : GLuint;
    triangles_ibo : GLuint;

    // Important: These are in the entity's model space (a.k.a., entity.mesh model space) 
    // @Cleanup Use a Box_Sphere here
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
    display_mode := Display_Mode.BLINN_PHONG;
    backface_mode := Backface_Mode.FIXED;
    flat_shading := true;

    //
    // Labeling members
    //

    vertex_label_theme : Vertex_Label_Theme;
    point_label_theme : Element_Label_Theme;
    segment_label_theme : Element_Label_Theme;
    triangle_label_theme : Element_Label_Theme;
    annotation_label_theme : Annotation_Label_Theme;
    // attribute_theme : [..]Attribute_Theme;

    point_label_theme.label_color = .{1., 1., 0, 1};
    segment_label_theme.label_color = .{.6, .6, 0, 1};

    //
    // Vertex/Element members
    //

    // Separate position display parameters from point display parameters. Make the position color black by default
    positions_visible := false;
    positions_color : Vector4 = BLACK;
    positions_size : s32 = 4;

    points_visible := false;
    points_color := Vector4.{.5, .5, .5, 1.};
    points_size : s32 = 4;

    normals_visible := false;
    normals_color := Vector4.{0., 0., .8, 1.};
    normals_length : float = 1.;

    segments_visible := false;
    segments_color : Vector4 = BLACK;
    segments_width : float = 1.;

    triangles_visible := false;
    triangles_color := Vector4.{1., 1., 1., 1.};

    // These can be used for tetrahedra edges when those are supported
    edges_visible := false;
    edges_color : Vector4 = BLACK;
    edges_width : float = 1.;

    //
    // Clipping
    //

    // These are all in world space
    clip_mode := Clip_Mode.HIDDEN;
    clip_ranges : [3]Clip_Range;
    clip_sphere : Clip_Sphere;

    clip_ranges[0] = .{normal=.{1,0,0}};
    clip_ranges[1] = .{normal=.{0,1,0}};
    clip_ranges[2] = .{normal=.{0,0,1}};

    //
    // Transient data
    //

    flash_wave_dt : float = 0.;
    aabb_visible := false;
    clip_sphere_prev : Clip_Sphere;
}

is_any_label_theme_visible :: (using,except(is_visible) display_info : Display_Info) -> bool {
    return is_visible(vertex_label_theme) ||
           is_visible(point_label_theme) ||
           is_visible(segment_label_theme) ||
           is_visible(triangle_label_theme) ||
           is_visible(annotation_label_theme);
}

is_clipped :: (display_info : Display_Info, point_world : Point3, test_sphere := true, test_ranges := true) -> bool {
    if test_sphere && is_clipped(display_info.clip_sphere, point_world) {
        return true;
    }

    if test_ranges && is_clipped(display_info.clip_ranges, point_world) {
        return true;
    }

    return false;
}

maybe_update_render_info :: (info : *Render_Info, mesh : Simple_Mesh) {
    if info.is_dirty {
        // nocommit Handle this case
        /*
        if mesh.geometry_format == .TRIANGLES && !mesh.normals.count {
            // log("Computing and assigning triangle normals to vertices\n");
            success, failure_reason := compute_vertex_normals_from_triangles(mesh);
            if !success {
                log_warning("Computing and assigning triangle normals to vertices, reason: \"%\"", failure_reason);
            }
        }
        */

        // Note: We do _not_ apply the mesh.world_from_model transform here, that is
        // stored separately to the raw position data so it can be changed efficiently
        // i.e., bounding geometry is defined in the mesh model space
        info.bounding_sphere = ifx mesh.positions.count then bounding_sphere_ritter(mesh.positions) else .{};
        info.bounding_aabb = make_axis_box3(..mesh.positions);

        NP := size_of(Vector3) * mesh.positions.count;
        NN := 0; // size_of(Vector3) * mesh.normals.count;

        if !info.vbo glGenBuffers(1, *info.vbo);

        glBindBuffer(GL_ARRAY_BUFFER, info.vbo);
        glBufferData(GL_ARRAY_BUFFER, NP + NN, null, GL_STATIC_DRAW);
        glBufferSubData(GL_ARRAY_BUFFER, 0, NP, mesh.positions.data);
        // glBufferSubData(GL_ARRAY_BUFFER, NP, NN, mesh.normals.data);

        if !info.points_ibo glGenBuffers(1, *info.points_ibo);
        if !info.segments_ibo glGenBuffers(1, *info.segments_ibo);
        if !info.triangles_ibo glGenBuffers(1, *info.triangles_ibo);

        // @Cleanup consider doing something like, or putting a explicit type alias within Simple_Mesh e.g., Point :: u32 rather than hard coding the types here
        // point_type : Type = get_type(type_info(mesh.points).element_type);

        size_points := size_of(u32) * mesh.points.count;
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, info.points_ibo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_points, mesh.points.data, GL_STATIC_DRAW);

        size_segments := size_of(Tuple2(u32)) * mesh.segments.count;
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, info.segments_ibo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_segments, mesh.segments.data, GL_STATIC_DRAW);

        size_triangles := size_of(Tuple3(u32)) * mesh.triangles.count;
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, info.triangles_ibo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_triangles, mesh.triangles.data, GL_STATIC_DRAW);

        info.is_dirty = false;
    }
}

// @Cleanup consolidate this
render_normals :: (mesh : *Simple_Mesh, using render_info : *Render_Info, using display_info : Display_Info) {
    if !normals_visible return;

    maybe_update_render_info(render_info, mesh);

    glUseProgram(app.normals_program);

    // @Incomplete handle wave?
    set_model_view_projection_uniforms(app.normals_program, mesh.world_from_model);
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

render_aabb :: (aabb_model : AxisBox3, world_from_model : Matrix4) {
    glUseProgram(app.aabb_program);
    set_model_view_projection_uniforms(app.aabb_program, world_from_model);

    r, g, b, a : float = 0, 0, 1, 1;
    min := aabb_model.min_point;
    max := aabb_model.max_point;

    glUniform4f(glGetUniformLocation(app.aabb_program, "color"), r, g, b, a);
    glUniform3f(glGetUniformLocation(app.aabb_program, "min"), min.x, min.y, min.z);
    glUniform3f(glGetUniformLocation(app.aabb_program, "max"), max.x, max.y, max.z);

    glDrawArrays(GL_LINES, 0, 24);
}

render_mesh_positions :: (
    mesh : *Simple_Mesh,
    using render_info : *Render_Info,
    using,except(points_visible, points_color, points_size) display_info : Display_Info,
    clip_radius_mode_show_wireframe : bool) {

    if !mesh.positions.count {
        return;
    }

    if !positions_visible && !clip_radius_mode_show_wireframe {
        return;
    }

    render_simple_mesh_common(mesh, render_info, display_info, clip_radius_mode_show_wireframe);

    size := ifx clip_radius_mode_show_wireframe then 2 else positions_size;
    glUniform1f(glGetUniformLocation(app.simple_mesh_program, "point_size"), xx size);

    color := ifx clip_radius_mode_show_wireframe then BLACK else positions_color;
    glUniform4f(glGetUniformLocation(app.simple_mesh_program, "color"), color.x, color.y, color.z, color.w);

    glDrawArrays(GL_POINTS, 0, xx mesh.positions.count);
}

render_mesh_points :: (
    mesh : *Simple_Mesh,
    using render_info : *Render_Info,
    using,except(positions_visible, positions_color, positions_size) display_info : Display_Info,
    clip_radius_mode_show_wireframe : bool) {
    if !mesh.points.count {
        return;
    }

    if !points_visible && !clip_radius_mode_show_wireframe {
        return;
    }

    render_simple_mesh_common(mesh, render_info, display_info, clip_radius_mode_show_wireframe);

    used_points_size := ifx clip_radius_mode_show_wireframe then 2 else points_size;
    glUniform1f(glGetUniformLocation(app.simple_mesh_program, "point_size"), xx used_points_size);

    used_points_color := ifx clip_radius_mode_show_wireframe then BLACK else points_color;
    glUniform4f(glGetUniformLocation(app.simple_mesh_program, "color"), used_points_color.x, used_points_color.y, used_points_color.z, used_points_color.w);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, points_ibo);
    glDrawElements(GL_POINTS, cast(GLsizei)(mesh.points.count), GL_UNSIGNED_INT, null);
}

render_mesh_segments :: (mesh : *Simple_Mesh, using render_info : *Render_Info, using display_info : Display_Info, clip_radius_mode : bool) {
    if mesh.segments.count == 0 {
        return;
    }

    if !segments_visible && !clip_radius_mode {
        return;
    }

    render_simple_mesh_common(mesh, render_info, display_info, clip_radius_mode);

    used_segments_width := ifx clip_radius_mode then 1. else segments_width; // ifx ensures that the min width is chosen for clip_radius_mode
    if (used_segments_width > 0) {
        // See also glEnable(GL_LINE_SMOOTH);
        glLineWidth(xx used_segments_width);
    }

    glUniform4f(glGetUniformLocation(app.simple_mesh_program, "color"), segments_color.x, segments_color.y, segments_color.z, segments_color.w);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, segments_ibo);
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL); // @Cleanup doesnt this affect a GL_LINES call?
    glDrawElements(GL_LINES, cast(GLsizei)(2 * mesh.segments.count), GL_UNSIGNED_INT, null);
}


// :NiceTriangleEdgesRendering
// We render triangle edges are rendered by rendering the triangle data twice using different polygon modes:
// 1. With mode GL_FILL to achieve smooth/with anti-aliased edges within the triangle face (supports floating point edges_width)
// 2. With mode GL_LINE to ensure that degenerate triangles with no area are visible when edges are rendered (requires integral edges_width)
// In order not to spoil the smoothness of the edges within a triangle face we ensure a smaller width is used in the GL_LINE call
MIN_EDGES_WIDTH_GL_LINE :: 1.;
MIN_EDGES_WIDTH_GL_FILL :: 1.2;

// Render the triangles using GL_LINE polygon mode so that degenerate triangles are visible when triangle edges are visible
render_mesh_triangles_as_lines :: (mesh : *Simple_Mesh, using render_info : *Render_Info, using display_info : Display_Info, clip_radius_mode_show_wireframe : bool) {
    if mesh.triangles.count == 0 {
        return;
    }

    if !edges_visible && !clip_radius_mode_show_wireframe {
        return;
    }

    render_simple_mesh_common(mesh, render_info, display_info, clip_radius_mode_show_wireframe);

    used_edges_width := max(edges_width - 1, MIN_EDGES_WIDTH_GL_LINE); // See :NiceTriangleEdgesRendering
    used_edges_width = ifx clip_radius_mode_show_wireframe then MIN_EDGES_WIDTH_GL_LINE else used_edges_width;

    // See also glEnable(GL_LINE_SMOOTH);
    glLineWidth(xx used_edges_width);

    glUniform4f(glGetUniformLocation(app.simple_mesh_program, "color"), edges_color.x, edges_color.y, edges_color.z, edges_color.w);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, triangles_ibo);
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    glDrawElements(GL_TRIANGLES, cast(GLsizei)(3 * mesh.triangles.count), GL_UNSIGNED_INT, null);
}

render_mesh_triangles :: (
    mesh : *Simple_Mesh,
    using render_info : *Render_Info,
    using display_info : Display_Info,
    clip_radius_mode : bool,
    clip_radius_mode_show_wireframe : bool) {
 
    if !triangles_visible || mesh.triangles.count == 0 {
        return;
    }

    render_mesh_common(mesh, render_info, display_info, clip_radius_mode);

    glUniform1i(glGetUniformLocation(app.mesh_program, "display_mode"), xx display_mode);
    glUniform1i(glGetUniformLocation(app.mesh_program, "backface_mode"), xx backface_mode);
    glUniform1ui(glGetUniformLocation(app.mesh_program, "flat_shading"), xx flat_shading);
    // @Cleanup Maybe colors should be passed to the shader program as vertex attributes rather than uniforms to make rendering triangle attributes using colors a bit easier
    glUniform4f(glGetUniformLocation(app.mesh_program, "color"), triangles_color.x, triangles_color.y, triangles_color.z, triangles_color.w);
    glUniform4f(glGetUniformLocation(app.mesh_program, "edges_color"), edges_color.x, edges_color.y, edges_color.z, edges_color.w);
    glUniform2f(glGetUniformLocation(app.mesh_program, "window_size"), xx app.current_window_width, xx app.current_window_height);

    used_edges_width := max(edges_width, MIN_EDGES_WIDTH_GL_FILL); // See :NiceTriangleEdgesRendering
    used_edges_width = ifx clip_radius_mode_show_wireframe then MIN_EDGES_WIDTH_GL_FILL else used_edges_width;
    used_edges_visible := ifx clip_radius_mode_show_wireframe then true else edges_visible;
    glUniform1f(glGetUniformLocation(app.mesh_program, "edges_width"), ifx used_edges_visible then used_edges_width else 0);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, triangles_ibo);
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    glDrawElements(GL_TRIANGLES, cast(GLsizei) (3 * mesh.triangles.count), GL_UNSIGNED_INT, null);
}

set_model_view_projection_uniforms :: (program : GLuint, world_from_model : Matrix4 = Matrix4_Identity) {
    {
        loc := glGetUniformLocation(program, "world_from_model");
        glUniformMatrix4fv(loc, 1, true, *world_from_model._11);
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

// @Cleanup
render_mesh_common :: (mesh : *Simple_Mesh, using render_info : *Render_Info, using display_info : Display_Info, clip_radius_mode := false) {

    maybe_update_render_info(render_info, mesh);

    glUseProgram(app.mesh_program);

    set_model_view_projection_uniforms(app.mesh_program, mesh.world_from_model);

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

    ATTRIB_POSITION  :: 0;
    ATTRIB_NORMAL    :: 1;

    glEnableVertexAttribArray(ATTRIB_POSITION);
    glEnableVertexAttribArray(ATTRIB_NORMAL);

    // ATTRIB_TEXCOORDS :: 1;
    // ATTRIB_COLOR     :: 2;

    NP := size_of(Vector3) * mesh.positions.count;

    glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), null);
    glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)(NP));

    last_polygon_mode: [2]GLuint;
    glGetIntegerv(GL_POLYGON_MODE, xx last_polygon_mode.data);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);
}

// nocommit Rename this function and the corresponding shaders and program variable names in App to something that indicates that the variables are used for segment/point rendering
render_simple_mesh_common :: (mesh : *Simple_Mesh, using render_info : *Render_Info, using display_info : Display_Info, clip_radius_mode : bool) {

    maybe_update_render_info(render_info, mesh);

    glUseProgram(app.simple_mesh_program);

    set_model_view_projection_uniforms(app.simple_mesh_program, mesh.world_from_model);

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

        clip_mode := ifx clip_radius_mode then Clip_Mode.BLACKEN else Clip_Mode.HIDDEN;
        glUniform1i(glGetUniformLocation(app.simple_mesh_program, "clip_mode"), xx clip_mode);
    }

    glBindVertexArray(app.simple_mesh_vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);

    ATTRIB_POSITION  :: 0;
    ATTRIB_NORMAL    :: 1;

    glEnableVertexAttribArray(ATTRIB_POSITION);
    glEnableVertexAttribArray(ATTRIB_NORMAL);

    // ATTRIB_TEXCOORDS :: 1;
    // ATTRIB_COLOR     :: 2;

    NP := size_of(Vector3) * mesh.positions.count;

    glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), null);
    glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)(NP));

    last_polygon_mode: [2]GLuint;
    glGetIntegerv(GL_POLYGON_MODE, xx last_polygon_mode.data);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glEnable(GL_PROGRAM_POINT_SIZE);
}

// @Volatile!!! This function MUST be inlined, we do that right now with expand, but we SHOULD be able to use inline but right now that doesn't work @CompilerBug (see the comment about this in the Any how_to) also do ti
get_point_text_format_float :: (v : float) -> FormatFloat #expand {
    f := app.label_format.format_float;
    f.value = v;
    return f;
}

get_point_text :: (point : Vector2, point_index : int, theme : Vertex_Label_Theme, label_index_offset : int = 0) -> string {
    result : string;
    f :: get_point_text_format_float;
    if  theme.show_index &&  theme.show_position result = tprint("% (%, %)", label_index_offset + point_index, f(point.x), f(point.y));
    if !theme.show_index &&  theme.show_position result = tprint("(%, %)", f(point.x), f(point.y));
    if  theme.show_index && !theme.show_position result = tprint("%", label_index_offset + point_index);
    return result;
}

get_point_text :: (point : Vector3, point_index : int, theme : Vertex_Label_Theme, label_index_offset : int = 0) -> string {
    result : string;
    f :: get_point_text_format_float;
    if  theme.show_index &&  theme.show_position result = tprint("% (%, %, %)", label_index_offset + point_index, f(point.x), f(point.y), f(point.z));
    if !theme.show_index &&  theme.show_position result = tprint("(%, %, %)", f(point.x), f(point.y), f(point.z));
    if  theme.show_index && !theme.show_position result = tprint("%", label_index_offset + point_index);
    return result;
}

get_point_text :: (index : int, theme : Element_Label_Theme, label_index_offset : int = 0) -> string {
    result : string;
    if  theme.show_index result = tprint("%", label_index_offset + index);
    return result;
}

// _space is model or world but it could be whatever else
to_screen_position :: (point_space : Vector3, projection_from_space : Matrix4) -> Tuple2i {
    result : Tuple2i = ---;

    // [-1, 1]x[-1,1] -> [0, current_window_width]x[0, current_window_height]
    transformed : Vector3 = transform_point(projection_from_space, point_space);
    result.x = xx (app.current_window_width *  (transformed.x + 1) / 2);
    result.y = xx (app.current_window_height * (transformed.y + 1) / 2);

    return result;
}

on_screen_in_disk :: (text_position_px : Tuple2i, visible_radius_px : int) -> bool {
    if io().MousePos == make_ImVec2(-FLOAT32_MAX,-FLOAT32_MAX) {
        return false;
    }

    if text_position_px.x < 0 ||
       text_position_px.y < 0 ||
       text_position_px.x > xx app.current_window_width ||
       text_position_px.y > xx app.current_window_height {
        return false;
    }

    mouse_position := make_vector2(io().MousePos.x, app.current_window_height - io().MousePos.y);
    text_position :=  make_vector2(xx text_position_px.x, xx text_position_px.y);
    if distance(mouse_position, text_position) > xx visible_radius_px {
        return false;
    }

    return true;
}

entity_in_clip_radius_mode :: (entity_index : int) -> bool {
    return mouse_set_clip_radius() && app.clipping_sphere_mode_entity_index >= 0 &&
    (
        ( app.entities[app.clipping_sphere_mode_entity_index].is_selected && app.entities[entity_index].is_selected) ||
        (!app.entities[app.clipping_sphere_mode_entity_index].is_selected && app.clipping_sphere_mode_entity_index == entity_index)
    );
}

render_entities :: () {

    Scope_GL_State();

    render_entity_geometry :: (entity : *Entity, entity_index : int) {
        ri := *entity.render_info;
        di :=  entity.display_info;

        clip_radius_mode := entity_in_clip_radius_mode(entity_index);
        clip_radius_mode_show_wireframe := mouse_set_clip_radius() && array_find(app.clipping_sphere_mode_last_entity_index_set, entity_index);

        render_mesh_triangles(*entity.mesh, ri, di, clip_radius_mode, clip_radius_mode_show_wireframe);
        render_mesh_triangles_as_lines(*entity.mesh, ri, di, clip_radius_mode_show_wireframe);
        render_mesh_segments(*entity.mesh, ri, di, clip_radius_mode_show_wireframe);
        render_mesh_points(*entity.mesh, ri, di, clip_radius_mode_show_wireframe);
        render_mesh_positions(*entity.mesh, ri, di, clip_radius_mode_show_wireframe);
        render_normals(*entity.mesh, ri, di); // Probably we want to pass clip_radius_mode here too?

        if di.aabb_visible {
            render_aabb(ri.bounding_aabb, entity.mesh.world_from_model);
        }
    }

    render_entity_text_spotlight :: ($entity_filter : Code) {

        Simp.ScopeContext();
        glEnable(GL_BLEND);
        defer glDisable(GL_BLEND);
        // Culling is unhelpful for polygon meshes @Cleanup make this a property on the mesh
        // glDisable(GL_CULL_FACE);
        // defer glEnable(GL_CULL_FACE);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

        projection_from_world : Matrix4 = make_projection_from_world(app.camera);

        FilterIterator :: #bake_arguments Entities_Iterator(entity_filter=entity_filter);
        for :FilterIterator entity, entity_index : app.entities {

            // Caches for glyph quads @TODO pull these arrays out of the entity loop so that label overlapping can be fixed across entities e.g., if mesh A and B have a coincident vertex we'd like the text labels for that vertex not to overlap
            vertex_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
            point_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
            segment_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
            triangle_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
            annotation_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);

            using,except(is_visible) entity.display_info;

            //
            // Annotation labels
            //

            {
                // @Speed this should use the spatial index?? since annotations are sparse, maybe not
                if is_visible(annotation_label_theme) for :AnnotationIterator annotation : entity {
                    point_world, point_model : Vector3 = ---;
                    if #complete annotation.kind == {
                        case .VERTEX;
                            point_model = mesh_point_model(entity.mesh, annotation.id);
                            point_world = mesh_point_world(entity.mesh, annotation.id);
                        case .LINE;
                            point_model = centroid(mesh_segment3_model(entity.mesh, annotation.id));
                            point_world = centroid(mesh_segment3_world(entity.mesh, annotation.id));
                        case .TRIANGLE;
                            point_model = compute_centroid(mesh_triangle_model(entity.mesh, annotation.id));
                            point_world = transform_point(entity.mesh.world_from_model, point_model);
                        case .BLOCK; #through;
                        case .COMMAND;
                            continue;
                    }

                    if !is_clipped(entity.display_info, point_world) {
                        text_position_px : Tuple2i = to_screen_position(point_world, projection_from_world);
                        if on_screen_in_disk(text_position_px, app.settings.labelling_radius_px) {
                            text : string = to_string(annotation);
                            array_add(*annotation_labels, make_Label_Info(text_position_px, text));
                        }
                    }
                }
            }

            //
            // Vertex labels
            //

// @continue Remove this and instead show the position data for vertices connected to displayed elements
            {
                // @Speed this should use the spatial index??
                if is_visible(vertex_label_theme) for :ModelVertexIterator position_model, position_index : entity.mesh {
                    position_world := mesh_point_world(entity.mesh, position_index);
                    if !is_clipped(entity.display_info, position_world) {
                        text_position_px : Tuple2i = to_screen_position(position_world, projection_from_world);
                        if on_screen_in_disk(text_position_px, app.settings.labelling_radius_px) {
                            // @Incomplete Add option to render points in world coordinates? Model is probably mostly useful for 2D shapes
                            text : string = get_point_text(position_model, position_index, vertex_label_theme);
                            array_add(*vertex_labels, make_Label_Info(text_position_px, text));
                        }
                    }
                }
            }

            //
            // Point labels
            //

            {
                if is_visible(point_label_theme) for :ModelPointIterator position_model, point_index : entity.mesh {
                    position_world : Vector3 = transform_point(entity.mesh.world_from_model, position_model);

                    if !is_clipped(entity.display_info, position_world) {
                        text_position_px : Tuple2i = to_screen_position(position_world, projection_from_world);
                        if on_screen_in_disk(text_position_px, app.settings.labelling_radius_px) {
                            text : string = get_point_text(point_index, point_label_theme);
                            array_add(*point_labels, make_Label_Info(text_position_px, text));
                        }
                    }
                }
            }

            //
            // Segment labels
            //

            {
                if is_visible(segment_label_theme) for :ModelSegmentIterator segment : entity.mesh {
                    point_model : Vector3 = centroid(segment);
                    point_world : Vector3 = transform_point(entity.mesh.world_from_model, point_model);

                    if !is_clipped(entity.display_info, point_world) {
                        text_position_px : Tuple2i = to_screen_position(point_world, projection_from_world);
                        if on_screen_in_disk(text_position_px, app.settings.labelling_radius_px) {
                            text : string = get_point_text(it_index, segment_label_theme);
                            array_add(*segment_labels, make_Label_Info(text_position_px, text));
                        }
                    }
                }
            }

            //
            // Triangle labels
            //

            {
                ProcessTriangle :: (triangle_model : Triangle3, triangle_index : int) #expand {
                    point_model : Vector3 = compute_centroid(triangle_model);
                    point_world : Vector3 = transform_point(entity.mesh.world_from_model, point_model);
                    if !is_clipped(entity.display_info, point_world) {
                        text_position_px : Tuple2i = to_screen_position(point_world, projection_from_world);
                        if on_screen_in_disk(text_position_px, app.settings.labelling_radius_px) {
                            text : string = get_point_text(triangle_index, triangle_label_theme);
                            array_add(*triangle_labels, make_Label_Info(text_position_px, text));
                        }
                    }
                }

                if entity.spatial == null {
                    // log_error("Use brute force");

                    if is_visible(triangle_label_theme) {
                        for :ModelTriangleIterator entity.mesh {
                            ProcessTriangle(it, it_index);
                        }
                    }
                } else {
                    // log_error("Use spatial index");

                    if is_visible(triangle_label_theme) {
                        ray_world : Ray3 = make_camera_ray();
                        ray_model : Ray3 = transform_ray(inverse(entity.mesh.world_from_model), ray_world);
                        distance : float = get_model_space_query_radius(entity.render_info.bounding_aabb, app.settings.labelling_radius_px);

                        VisitPrimitivesNearRay(entity.spatial, ray_model, distance,
                            #code ProcessTriangle(primitive, primitive_id)
                        );
                    }
                }
            }

            // TODO Store the pixel->label table per item to resolve overlaps between all these? Probably we don't care about overlaps between items
            draw_label_infos(vertex_labels, vertex_label_theme);
            draw_label_infos(point_labels, point_label_theme);
            draw_label_infos(segment_labels, segment_label_theme);
            draw_label_infos(triangle_labels, triangle_label_theme);
            draw_label_infos(annotation_labels, annotation_label_theme);
        }
    }

    render_entity_text_ray_cast :: ($entity_filter : Code) {

        closest_world : Closest_Point_Ray_Entity = find_closest_element(entity_filter);

        if closest_world.entity_index == -1 {
            return;
        }

        entity : *Entity = app.entities[closest_world.entity_index];
        if !entity.display_info.is_visible {
            return;
        }

        closest_point_world : Vector3 = get_closest_point_on_element(closest_world);
        if is_clipped(entity.display_info, closest_point_world) {
            return;
        }

        Simp.ScopeContext();
        glEnable(GL_BLEND);
        defer glDisable(GL_BLEND);
        // Culling is unhelpful for polygon meshes @Cleanup make this a property on the mesh
        // glDisable(GL_CULL_FACE);
        // defer glEnable(GL_CULL_FACE);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

        // Caches for glyph quads
        vertex_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
        point_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
        segment_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
        triangle_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
        annotation_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);

        projection_from_world : Matrix4 = make_projection_from_world(app.camera);

        using,except(is_visible) entity.display_info;

        // position_index is an index into the array of mesh.positions, which is filled with v-directive data
        AddVertexAndAnnotationLabels :: (position_world : Vector3, position_model : Vector3, position_index : int) #expand {
            // Note: Since we don't have a mapping from mesh.positions to mesh.points we can't easily add to the point_labels array in this function, but this is kindof an unusual case anyhow: it only occurs if you have a triangle element where the connected positions are also point elements
            //if is_visible(`point_label_theme) {...}

            if is_visible(`vertex_label_theme) {
                text_position_px : Tuple2i = to_screen_position(position_world, `projection_from_world);
                text : string = get_point_text(position_model, position_index, `vertex_label_theme);
                array_add(*`vertex_labels, make_Label_Info(text_position_px, text));
            }

            // @Speed this should use the spatial index?? since annotations are sparse, maybe not
            if is_visible(`annotation_label_theme) for :AnnotationIterator annotation : entity {
                if annotation.kind == .VERTEX && annotation.id == position_index {
                    text_position_px : Tuple2i = to_screen_position(position_world, `projection_from_world);
                    text : string = to_string(annotation);
                    array_add(*`annotation_labels, make_Label_Info(text_position_px, text));
                }
            }
        }


        if #complete closest_world.closest_point_element == {
        case .VERTEX; // aka position

            // nocommit closest_world may never return this actually, perhaps we should compute this will a find_closest_element function (and change the obj loading code to convert unreferenced positions into point elements)

            // Position and annotation label
            {
                position_world := closest_point_world;
                position_model := transform_point(inverse(entity.mesh.world_from_model), closest_point_world);
                position_index := closest_world.element_index;

                AddVertexAndAnnotationLabels(position_world, position_model, position_index);
            }

        case .POINT;

            // Point label
            if is_visible(point_label_theme) {
                text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                text : string = get_point_text(closest_world.element_index, point_label_theme);
                array_add(*point_labels, make_Label_Info(text_position_px, text));
            }

            // nocommit @continue Enable this when we add .POINT to Annotation.Kind
            //// Point annotation label
            //if is_visible(annotation_label_theme) for :AnnotationIterator annotation : entity {
            //    if annotation.kind == .POINT && annotation.id == index {
            //        text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
            //        text : string = to_string(annotation);
            //        array_add(*annotation_labels, make_Label_Info(text_position_px, text));
            //    }
            //}

            // Point position and position annotation labels
            {
                position_world := closest_point_world;
                position_model := transform_point(inverse(entity.mesh.world_from_model), closest_point_world);
                position_index := entity.mesh.points[closest_world.element_index];

                AddVertexAndAnnotationLabels(position_world, position_model, position_index);
            }

        case .SEGMENT;

            // Segment label
            if is_visible(segment_label_theme) {
                text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                text : string = get_point_text(closest_world.element_index, segment_label_theme);
                array_add(*segment_labels, make_Label_Info(text_position_px, text));
            }

            // Segment annotation label
            if is_visible(annotation_label_theme) for :AnnotationIterator annotation : entity {
                if annotation.kind == .LINE && annotation.id == closest_world.element_index {
                    text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                    text : string = to_string(annotation);
                    array_add(*annotation_labels, make_Label_Info(text_position_px, text));
                }
            }

            // Segment position and position annotation labels
            segment_tuple : Tuple2(u32) = mesh_segment3_tuple(entity.mesh, closest_world.element_index);
            segment_model : Segment3 = mesh_segment3_model(entity.mesh, closest_world.element_index);
            segment_world : Segment3 = mesh_segment3_world(entity.mesh, closest_world.element_index);
            for 0..1 {
                position_world := segment_world.p[it];
                position_model := segment_model.p[it];
                position_index := segment_tuple.component[it];

                AddVertexAndAnnotationLabels(position_world, position_model, position_index);
            }

        case .TRIANGLE;

            // Triangle label
            if is_visible(triangle_label_theme) {
                text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                text : string = get_point_text(closest_world.element_index, triangle_label_theme);
                array_add(*triangle_labels, make_Label_Info(text_position_px, text));
            }

            // Triangle annotation label
            if is_visible(annotation_label_theme) for :AnnotationIterator annotation : entity {
                if annotation.kind == .TRIANGLE && annotation.id == closest_world.element_index {
                    text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                    text : string = to_string(annotation);
                    array_add(*annotation_labels, make_Label_Info(text_position_px, text));
                }
            }

            // Triangle position and position annotation labels
            triangle_tuple : Tuple3(u32) = mesh_triangle_tuple(entity.mesh, closest_world.element_index);
            triangle_model : Triangle3 = mesh_triangle_model(entity.mesh, closest_world.element_index);
            triangle_world : Triangle3 = mesh_triangle_world(entity.mesh, closest_world.element_index);
            for 0..2 {
                position_world := triangle_world.v[it];
                position_model := triangle_model.v[it];
                position_index := triangle_tuple.component[it];

                AddVertexAndAnnotationLabels(position_world, position_model, position_index);
            }

        case .MESH;

            //  Do nothing

        }

        // TODO Store the pixel->label table per item to resolve overlaps between all these? Probably we don't care about overlaps between items
        draw_label_infos(vertex_labels, vertex_label_theme);
        draw_label_infos(point_labels, point_label_theme);
        draw_label_infos(segment_labels, segment_label_theme);
        draw_label_infos(triangle_labels, triangle_label_theme);
        draw_label_infos(annotation_labels, annotation_label_theme);
    }

    not_visible_opaque ::      #code !(is_visible(it) && !it.is_hovered && it.display_info.triangles_color.w == 1.);
    not_visible_transparent :: #code !(is_visible(it) && !it.is_hovered && it.display_info.triangles_color.w != 1.);
    not_visible_hovered ::     #code !(is_visible(it) &&  it.is_hovered);

    Visible_Opaque ::      #bake_arguments Entities_Iterator(entity_filter=not_visible_opaque);
    Visible_Transparent :: #bake_arguments Entities_Iterator(entity_filter=not_visible_transparent);
    Visible_Hovered ::     #bake_arguments Entities_Iterator(entity_filter=not_visible_hovered);

    for :Visible_Opaque      app.entities render_entity_geometry(it, it_index);
    for :Visible_Transparent app.entities render_entity_geometry(it, it_index);

    // :RenderingSelectionAABB Here we also render the AABB for a selection of entities, which is a bit of a hack
    if app.template_display_info.aabb_visible {
        render_aabb(app.template_aabb_world, Matrix4_Identity);
    }

    glClear(GL_DEPTH_BUFFER_BIT); // Render the text labels and flash hovered item over everything else

    // @Incomplete Add option to render points in world coordinates? Model is probably mostly useful for 2D shapes

    no_labels :: #code !is_visible(it) || !is_any_label_theme_visible(it.display_info);

    if #complete app.settings.labelling_mode == {
        case .RAY_CAST;

            render_entity_text_ray_cast(entity_filter=no_labels);

        case .SPOTLIGHT;

            render_entity_text_spotlight(entity_filter=no_labels);
    }

    for :Visible_Hovered     app.entities render_entity_geometry(it, it_index);
}


render_selections :: () {
    Scope_GL_State();

    if app.select_tool.entity.is_hovered {
        glClear(GL_DEPTH_BUFFER_BIT);
    }

    entity := *app.select_tool.entity;
    mesh := *app.select_tool.entity.mesh;

    dummy_clip_radius_mode := false; // @Incomplete Support this for the selection item when its the 0-th item?
    dummy_clip_radius_mode_show_wireframe := false; // @Incomplete Support this for the selection item when its the 0-th item?

    // @Cleanup use ri and di aliases here
    render_mesh_positions(mesh, *entity.render_info, entity.display_info, dummy_clip_radius_mode);
    render_mesh_points(mesh, *entity.render_info, entity.display_info, dummy_clip_radius_mode);
    render_mesh_segments(mesh, *entity.render_info, entity.display_info, dummy_clip_radius_mode);
    render_mesh_triangles_as_lines(mesh, *entity.render_info, entity.display_info, dummy_clip_radius_mode);
    render_mesh_triangles(mesh, *entity.render_info, entity.display_info, dummy_clip_radius_mode, dummy_clip_radius_mode_show_wireframe);
    render_normals(mesh, *entity.render_info, entity.display_info);

    projection_from_model := make_projection_from_world(app.camera) * mesh.world_from_model;

    // We intentionally always all the text for selections since there usually aren't lots
    // of overlapping ones and its annoying not to see everything. We also don't consider
    // the clipping sphere (there is no way to set it right now, anyway) since this is also
    // annoying in the case of selections

    // Disabled text rendering while selecting, that can be done after caching the selection

    //Simp.ScopeContext();
    //vertex_theme := entity.display_info.vertex_label_theme;
    //for mesh.positions {
    //    text := get_point_text(it, it_index, vertex_theme);
    //    text_position_px : Tuple2i = to_screen_position(it, projection_from_model);
    //    Simp.draw_text(app.simp_font, xx text_position_px.x, xx text_position_px.y, text, vertex_theme.label_color, scale=vertex_theme.label_scale);
    //}
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

    // @Incomplete Get and set relevant/all float variables too e.g., :
    last_line_width : GLfloat; glGetFloatv(GL_LINE_WIDTH, xx *last_line_width);

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
            glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
}


// Generate and cache quad data before its lost on the next call to prepare_text
cache_text_quads :: (cache : *[..]Simp.Font_Quad, text : string, text_position_px : Tuple2i, scale : float) {
    Simp.prepare_text(app.simp_font, text);
    Simp.generate_quads_for_prepared_text(app.simp_font, text_position_px.x, text_position_px.y, 0, scale);
    for app.simp_font.current_quads array_add(cache, it);
}

Label_Info :: struct {
    position_px : Tuple2i;
    label : string;
}

make_Label_Info :: (position_px : Tuple2i, label : string) -> Label_Info {
    result : Label_Info = ---;
    result.position_px = position_px;
    result.label = label;
    return result;
}

Label_Theme_Interface :: struct {
    label_color : Vector4;
    label_scale : float;
}

draw_label_infos :: (label_infos : []Label_Info, theme : $T/interface Label_Theme_Interface) {

    if !label_infos.count return;

    // @CompilerBug why is operator== not found??
    compare_Tuple2i :: (a : Tuple2i, b : Tuple2i) -> bool {
        return a == b;
    }

    label_table : Table(Tuple2i, [..]string, hash_Tuple2i, compare_Tuple2i);
    init(*label_table, label_infos.count);
    defer uninit(*label_table);

    for label_info : label_infos {
        overlapping_labels : *[..]string = find_or_add(*label_table, label_info.position_px);
        array_add(overlapping_labels, label_info.label);
    }

    character_height_px : s32 = xx (app.simp_font.character_height * theme.label_scale);

    quads : [..]Simp.Font_Quad = temp_array(Element_Type=Simp.Font_Quad);
    for overlapping_labels, position_px : label_table {
        for overlapping_labels {
            // Compute the label label position, we currently draw overlapping labels in a vertical stack
            label_position_px : Tuple2i = position_px;
            label_position_px.y -= it_index * character_height_px;

            // If the current label won't be on the screen skip it and also skip all remaining overlapping labels
            margin : s32 = 2 * character_height_px;
            if ((label_position_px.y > app.current_window_height + margin) || label_position_px.y < -margin) {
                break;
            }

            cache_text_quads(*quads, it, label_position_px, theme.label_scale);
        }
    }

    draw_cached_text_quads(quads, theme.label_color);
}

draw_cached_text_quads :: (quads : [..]Simp.Font_Quad, color : Vector4) {
    if !quads.count return;
    cached_font : Simp.Dynamic_Font = <<app.simp_font;
    cached_font.current_quads = quads;
    Simp.draw_generated_quads(*cached_font, color);
}




