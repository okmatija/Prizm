// Fixed! ISSUE_004 :: "The text rendering implementation currently sucks and is very slow (hence disabled) for large numbers of glyphs. To render text on large meshes use a clipping volume to reduce the number of visible elements and the text should show up."; @KnownIssue;

DEFAULT_LABEL_SCALE :: .4;

Labelling_Mode :: enum {
    RAY_CAST;  // Labels are shown on the intersection/closest preferred point to the camera ray
    SPOTLIGHT; // Labels are shown if query positions are within some (pixel) distance of the cursor
}

Annotation_Label_Theme :: struct {
    visible := false;
    label_scale := DEFAULT_LABEL_SCALE;
    label_color : Vector4 = .{0., 0., .75, 1.}; // Blue, works well on both grey and white backgrounds
}

// @Think Perhaps this should be in the Element_Label_Theme too so you can visualize only the vertices associated with the elements, maybe Simple_Mesh should store vertices referenced by each element type separately?
Vertex_Label_Theme :: struct {
    // @Cleanup replace with a combo box
    show_index := false;
    show_position := false;

    label_scale := DEFAULT_LABEL_SCALE;
    label_color : Vector4 = .{0., 0., .75, 1.}; // Blue, works well on both grey and white backgrounds

    annotation_label_theme : Annotation_Label_Theme;

    // world_space : bool = false; // @Incomplete
}

// For mesh topology/geometry labels
Element_Label_Theme :: struct {
    show_index := false;
    label_scale := DEFAULT_LABEL_SCALE;
    label_color := Vector4.{1., 1., 0, 1};

    annotation_label_theme : Annotation_Label_Theme;
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
Render_Info :: struct {
    is_dirty := true;

    // For rendering obj v-directive data
    // @Cleanup Remove the positions_vbo. It doubles the memory requirement and adds complexity. We can just add points for unreferenced vertices. When we do this we should also move VertexLabelTheme into ElementLabelTheme
    positions_vbo : GLuint;
    positions_vao : GLuint;

    // For rendering obj p-directive data
    points_vbo : GLuint;
    points_vao : GLuint;

    // For rendering obj l-directive data
    segments_vbo : GLuint;
    segments_vao : GLuint;
    segments_normals_vao : GLuint;

    // For rendering obj f-directive data
    triangles_vbo : GLuint;
    triangles_vao : GLuint;
    triangles_edges_vao : GLuint;
    triangles_normals_vao : GLuint;

    // Important: These are in the entity's model space (a.k.a., entity.mesh model space) 
    // @Cleanup Use a Box_Sphere here
    // @Cleanup Consider moving this into the mesh
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

Normal_Style :: struct {
    normals_visible := false;
    normals_color := Vector4.{0., 0., .8, 1.};
    normals_length : float = 1.; // nocommittt rename to scale, which multiplies the length, if normalized then the scale is the length
    //normalized : bool = false;
}

// Could also be used for tetrahedra edges when/if those are supported
Edge_Style :: struct {
    visible := false;
    color : Vector4 = BLACK;
    width : float = 1.;
}


Vertex_Style :: struct {
    visible : bool;
    color : Vector4 = BLACK;
    size : s32 = 4; // @Cleanup Use float when we generate quads from coordinates
}

Point_Style :: struct {
    using vertex_style : Vertex_Style;
    vertex_style.color = Vector4.{.5, .5, .5, 1.};

    normal_style : Normal_Style; // nocommitttt Use this
}

Segment_Style :: struct {
    visible := false;
    color : Vector4 = BLACK;
    width : float = 1.;

    normal_style : Normal_Style;
}

Triangle_Style :: struct {
    visible := false;
    color := Vector4.{1., 1., 1., 1.};

    edge_style : Edge_Style;
    normal_style : Normal_Style;
}


// Things that should be preserved when the geometry changes
Display_Info :: struct {

    // Set overall visibility without clobbering the individual settings. Considers both geometry and labels
    is_visible := true;

    // nocommittt: move into Triangle_Style
    display_mode := Display_Mode.BLINN_PHONG;
    backface_mode := Backface_Mode.FIXED;
    flat_shading := true;

    //
    // Labeling members
    //

    show_labels := true; // Sets overall text labels visibility without clobbering more granular settings. nocommit implement this
    vertex_label_theme : Vertex_Label_Theme;
    point_label_theme : Element_Label_Theme;
    segment_label_theme : Element_Label_Theme;
    triangle_label_theme : Element_Label_Theme;

    // These should be stored outside the vertex/point/segment/triangle_label_theme structs
    // attribute_theme : [..]Attribute_Theme;

    point_label_theme.label_color = .{1., 1., 0, 1};
    segment_label_theme.label_color = .{.6, .6, 0, 1};

    //
    // Vertex/Element members
    //

    // Separate position display parameters from point display parameters. Make the position color black by default
    vertex_style : Vertex_Style;

    points_visible := false;
    points_color := Vector4.{.5, .5, .5, 1.};
    points_size : s32 = 4;

    // @Cleanup These should go into some base attribute render theme?
    // nocommitttt These need to be associated with points, segments, triangles...
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

// Clipping and camera position are not checked here

any_vertex_label_visible :: (entity : Entity, $geometry_labels := true, $annotation_labels := true) -> bool {
    // We do NOT check entity.display_info.vertex_style.visible here, this option is usually off and we still want to see vertex labels
    return entity.display_info.is_visible && entity.display_info.show_labels /*&& entity.display_info.vertex_style.visible*/ && entity.mesh.positions.count && (
        (geometry_labels   && (entity.display_info.vertex_label_theme.show_index || entity.display_info.vertex_label_theme.show_position)) ||
        (annotation_labels && entity.display_info.vertex_label_theme.annotation_label_theme.visible && entity.vertex_annotations.count)
    );
}

any_point_label_visible :: (entity : Entity, $geometry_labels := true, $annotation_labels := true) -> bool {
    // Also checking mesh.positions.count
    return entity.display_info.is_visible && entity.display_info.show_labels && entity.display_info.points_visible && entity.mesh.positions.count && entity.mesh.points.count && (
        (geometry_labels   && entity.display_info.point_label_theme.show_index) ||
        (annotation_labels && entity.display_info.point_label_theme.annotation_label_theme.visible && entity.point_annotations.count)
    );
}

any_segment_label_visible :: (entity : Entity, $geometry_labels := true, $annotation_labels := true) -> bool {
    // Also checking mesh.positions.count
    return entity.display_info.is_visible && entity.display_info.show_labels && entity.display_info.segments_visible && entity.mesh.positions.count && entity.mesh.segments.count && (
        (geometry_labels   && entity.display_info.segment_label_theme.show_index) ||
        (annotation_labels && entity.display_info.segment_label_theme.annotation_label_theme.visible && entity.line_annotations.count)
    );
}

any_triangle_label_visible :: (entity : Entity, $geometry_labels := true, $annotation_labels := true) -> bool {
    // @Think Maybe we should also check opacity here too
    // @Think Maybe we should check edges_visible here?
    // Also checking mesh.positions.count
    return entity.display_info.is_visible && entity.display_info.show_labels && entity.display_info.triangles_visible && entity.mesh.positions.count && entity.mesh.triangles.count && (
        (geometry_labels   && entity.display_info.triangle_label_theme.show_index) ||
        (annotation_labels && entity.display_info.triangle_label_theme.annotation_label_theme.visible && entity.face_annotations.count)
    );
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

// nocommit Only set the GLuints when something may be drawn, also update the rendering code to only render things which are non-empty as well
maybe_update_render_info :: (info : *Render_Info, mesh : *Simple_Mesh) {
    if info.is_dirty {
        defer info.is_dirty = false;

        // @Cleanup consider doing something like this, or putting a explicit type alias within Simple_Mesh e.g., Point :: u32 rather than hard coding the types here
        // point_type : Type = get_type(type_info(mesh.points).element_type);

        // Note: We do _not_ apply the mesh.world_from_model transform here, that is
        // stored separately to the raw position data so it can be changed efficiently
        // i.e., bounding geometry is defined in the mesh model space
        info.bounding_sphere = ifx mesh.positions.count then bounding_sphere_ritter(mesh.positions) else .{};
        info.bounding_aabb = make_axis_box3(..mesh.positions);

        {
            // Vertex Buffer will be filled with triangle soup data so that we can represent hard normals etc. For example:
            //
            //  f 1//1 2//2 3//3
            //  f 1//4 2//5 4//6
            //
            // Note we also use glDrawArrays rather than glDrawElements. A glDrawElements call on triangle (1,2,3) and (1,2,4) would draw normals 1,2,3 and 6 but not 4 and 5

            if !info.triangles_vbo glGenBuffers(1, *info.triangles_vbo);

            triangle_positions : [..]Vector3 = temp_array(Vector3);
            array_reserve(*triangle_positions, 3 * mesh.triangles.count);
            for :ModelTriangleIterator mesh {
                array_add(*triangle_positions, it.a);
                array_add(*triangle_positions, it.b);
                array_add(*triangle_positions, it.c);
            }

            vn : *Simple_Mesh_Normals = find_or_add_mesh_attribute(mesh, "vn", Simple_Mesh_Normals);
            assert(vn != null);
            if mesh.triangles.count && !vn.values.count {
                // log("Computing and assigning triangle normals to vertices\n");
                success, failure_reason := compute_vertex_normals_from_triangles(mesh);
                if !success {
                    log_warning("Computing and assigning triangle normals to vertices, reason: \"%\"", failure_reason);
                }
            }

            NP := 3 * size_of(Vector3) * mesh.triangles.count;
            NN := size_of(Matrix3) * mesh.triangles.count;

            glBindBuffer(GL_ARRAY_BUFFER, info.triangles_vbo);
            glBufferData(GL_ARRAY_BUFFER, NP + NN, null, GL_STATIC_DRAW);
            glBufferSubData(GL_ARRAY_BUFFER, 0, NP, triangle_positions.data);
            glBufferSubData(GL_ARRAY_BUFFER, NP, NN, vn.values.data);
        }
        
        {
            if !info.segments_vbo glGenBuffers(1, *info.segments_vbo);

            segment_positions : [..]Vector3 = temp_array(Vector3);
            array_reserve(*segment_positions, 2 * mesh.segments.count);
            for :ModelSegmentIterator mesh {
                array_add(*segment_positions, it.start);
                array_add(*segment_positions, it.end);
            }

            // @Incomplete Add normals to segments

            vn : *Simple_Mesh_Segment_Normals = find_or_add_mesh_attribute(mesh, SEGMENT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Segment_Normals);
            assert(vn != null);

            NP := 2 * size_of(Vector3) * mesh.segments.count;
            NN := size_of(Matrix3x2) * mesh.segments.count;

            glBindBuffer(GL_ARRAY_BUFFER, info.segments_vbo);
            glBufferData(GL_ARRAY_BUFFER, NP + NN, null, GL_STATIC_DRAW);
            glBufferSubData(GL_ARRAY_BUFFER, 0, NP, segment_positions.data);
            glBufferSubData(GL_ARRAY_BUFFER, NP, NN, vn.values.data);
        }

        {
            if !info.points_vbo glGenBuffers(1, *info.points_vbo);

            point_positions : [..]Vector3 = temp_array(Vector3);
            array_reserve(*point_positions, mesh.points.count);
            for :ModelPointIterator mesh {
                array_add(*point_positions, it);
            }

            // @Incomplete Does obj format support oriented points? I guess we can just support that anyway. 

            // nocommit Support oriented point clouds p 1//2 2//3 4//5 ...

            NP := size_of(Vector3) * mesh.points.count;

            glBindBuffer(GL_ARRAY_BUFFER, info.points_vbo);
            glBufferData(GL_ARRAY_BUFFER, NP, null, GL_STATIC_DRAW);
            glBufferSubData(GL_ARRAY_BUFFER, 0, NP, point_positions.data);
        }

        {
            if !info.positions_vbo glGenBuffers(1, *info.positions_vbo);
            NP := size_of(Vector3) * mesh.positions.count;
            glBindBuffer(GL_ARRAY_BUFFER, info.positions_vbo);
            glBufferData(GL_ARRAY_BUFFER, NP, null, GL_STATIC_DRAW);
            glBufferSubData(GL_ARRAY_BUFFER, 0, NP, mesh.positions.data);
        }
    
        if !info.positions_vao {
            glGenVertexArrays(1, *info.positions_vao);
            glBindVertexArray(info.positions_vao);
            glBindBuffer(GL_ARRAY_BUFFER, info.positions_vbo);
            glEnableVertexAttribArray(ATTRIB_POSITION);
            glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
        }

        if !info.points_vao {
            glGenVertexArrays(1, *info.points_vao);
            glBindVertexArray(info.points_vao);
            glBindBuffer(GL_ARRAY_BUFFER, info.points_vbo);
            glEnableVertexAttribArray(ATTRIB_POSITION);
            glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
        }

        if !info.segments_vao {
            glGenVertexArrays(1, *info.segments_vao);
            glBindVertexArray(info.segments_vao);
            glBindBuffer(GL_ARRAY_BUFFER, info.segments_vbo);
            glEnableVertexAttribArray(ATTRIB_POSITION);
            glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
        }

        if !info.segments_normals_vao {
            glGenVertexArrays(1, *info.segments_normals_vao);
            glBindVertexArray(info.segments_normals_vao);
            glBindBuffer(GL_ARRAY_BUFFER, info.segments_vbo);

            NP := 2 * size_of(Vector3) * mesh.segments.count;
            glEnableVertexAttribArray(ATTRIB_POSITION);
            glEnableVertexAttribArray(ATTRIB_NORMAL);
            glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
            glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)NP);
        }

        if !info.triangles_vao {
            glGenVertexArrays(1, *info.triangles_vao);
            glBindVertexArray(info.triangles_vao);
            glBindBuffer(GL_ARRAY_BUFFER, info.triangles_vbo);

            NP := size_of(Vector3) * mesh.positions.count;
            glEnableVertexAttribArray(ATTRIB_POSITION);
            glEnableVertexAttribArray(ATTRIB_NORMAL);
            glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
            glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)(NP));
        }

        if !info.triangles_edges_vao {
            glGenVertexArrays(1, *info.triangles_edges_vao);
            glBindVertexArray(info.triangles_edges_vao);
            glBindBuffer(GL_ARRAY_BUFFER, info.triangles_vbo);
            glEnableVertexAttribArray(ATTRIB_POSITION);
            glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
        }

        if !info.triangles_normals_vao {
            glGenVertexArrays(1, *info.triangles_normals_vao);
            glBindVertexArray(info.triangles_normals_vao);
            glBindBuffer(GL_ARRAY_BUFFER, info.triangles_vbo);

            NP := 3 * size_of(Vector3) * mesh.triangles.count;
            glEnableVertexAttribArray(ATTRIB_POSITION);
            glEnableVertexAttribArray(ATTRIB_NORMAL);
            glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
            glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)NP);
        }

    } // end if info.is_dirty
}

// @Cleanup consolidate this
render_mesh_triangle_normals :: (mesh : *Simple_Mesh, using render_info : *Render_Info, using display_info : Display_Info) {
    if !normals_visible return;

    maybe_update_render_info(render_info, mesh);

    glUseProgram(app.triangles_normal_program);

    // @Incomplete handle wave?
    set_model_view_projection_uniforms(app.triangles_normal_program, mesh.world_from_model);
    set_clip_ranges_uniforms(app.triangles_normal_program, display_info);
    set_clip_sphere_uniforms(app.triangles_normal_program, display_info, prev_sphere=false);
    glUniform4f(glGetUniformLocation(app.triangles_normal_program, "normals_color"), normals_color.x, normals_color.y, normals_color.z, normals_color.w);
    glUniform1f(glGetUniformLocation(app.triangles_normal_program, "normal_length"), normals_length);

    glLineWidth(2); // 1, 2, 3... See also glEnable(GL_LINE_SMOOTH);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glBindVertexArray(render_info.triangles_normals_vao);
    glDrawArrays(GL_TRIANGLES, 0, xx (3 * mesh.triangles.count));
}

render_mesh_segment_normals :: (mesh : *Simple_Mesh, using render_info : *Render_Info, using display_info : Display_Info) {
    // @CompilerBug Add a return here and observe a compilation failure with message:
    // Error: Unable to open output file "C:/Users/matija.kecman/Dropbox/Prism/.build/Prism_1_w3.obj" for LLVM code generation: The process cannot access the file because it is being used by another process.

    if !normals_visible return;


    maybe_update_render_info(render_info, mesh);

    program := app.segments_normal_program;
    glUseProgram(program);

    // @Incomplete handle wave?
    set_model_view_projection_uniforms(program, mesh.world_from_model);
    set_clip_ranges_uniforms(program, display_info);
    set_clip_sphere_uniforms(program, display_info, prev_sphere=false);
    glUniform4f(glGetUniformLocation(program, "normals_color"), normals_color.x, normals_color.y, normals_color.z, normals_color.w);
    glUniform1f(glGetUniformLocation(program, "normal_length"), normals_length);

    glLineWidth(2); // 1, 2, 3... See also glEnable(GL_LINE_SMOOTH);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glBindVertexArray(render_info.segments_normals_vao);
    glDrawArrays(GL_LINES, 0, xx (2 * mesh.segments.count));
}

render_aabb :: (aabb_model : AxisBox3, world_from_model : Matrix4) {
    glUseProgram(app.aabb_program);

    r, g, b, a : float = 0, 0, 1, 1;
    min := aabb_model.min_point;
    max := aabb_model.max_point;

    set_model_view_projection_uniforms(app.aabb_program, world_from_model);
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

    if !vertex_style.visible && !clip_radius_mode_show_wireframe {
        return;
    }

    maybe_update_render_info(render_info, mesh);
    render_simple_mesh_common(mesh, display_info, clip_radius_mode_show_wireframe);

    size := ifx clip_radius_mode_show_wireframe then 2 else vertex_style.size;
    glUniform1f(glGetUniformLocation(app.points_lines_program, "point_size"), xx size);

    color := ifx clip_radius_mode_show_wireframe then BLACK else vertex_style.color;
    glUniform4f(glGetUniformLocation(app.points_lines_program, "color"), color.x, color.y, color.z, color.w);

    glBindVertexArray(render_info.positions_vao);
    glDrawArrays(GL_POINTS, 0, xx mesh.positions.count);
}

render_mesh_points :: (
    mesh : *Simple_Mesh,
    using render_info : *Render_Info,
    using display_info : Display_Info,
    clip_radius_mode_show_wireframe : bool) {
    if !mesh.points.count {
        return;
    }

    if !points_visible && !clip_radius_mode_show_wireframe {
        return;
    }

    maybe_update_render_info(render_info, mesh);
    render_simple_mesh_common(mesh, display_info, clip_radius_mode_show_wireframe);

    used_points_size := ifx clip_radius_mode_show_wireframe then 2 else points_size;
    glUniform1f(glGetUniformLocation(app.points_lines_program, "point_size"), xx used_points_size);

    used_points_color := ifx clip_radius_mode_show_wireframe then BLACK else points_color;
    glUniform4f(glGetUniformLocation(app.points_lines_program, "color"), used_points_color.x, used_points_color.y, used_points_color.z, used_points_color.w);

    glBindVertexArray(render_info.points_vao);
    glDrawArrays(GL_POINTS, 0, xx mesh.points.count);
}

render_mesh_segments :: (mesh : *Simple_Mesh, using render_info : *Render_Info, using display_info : Display_Info, clip_radius_mode : bool) {
    if mesh.segments.count == 0 {
        return;
    }

    if !segments_visible && !clip_radius_mode {
        return;
    }

    maybe_update_render_info(render_info, mesh);
    render_simple_mesh_common(mesh, display_info, clip_radius_mode);

    used_segments_width := ifx clip_radius_mode then 1. else segments_width; // ifx ensures that the min width is chosen for clip_radius_mode
    if (used_segments_width > 0) {
        // See also glEnable(GL_LINE_SMOOTH);
        glLineWidth(xx used_segments_width);
    }

    glUniform4f(glGetUniformLocation(app.points_lines_program, "color"), segments_color.x, segments_color.y, segments_color.z, segments_color.w);

    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL); // @Cleanup doesnt this affect a GL_LINES call?

    glBindVertexArray(render_info.segments_vao);
    glDrawArrays(GL_LINES, 0, xx (2 * mesh.segments.count));
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

    maybe_update_render_info(render_info, mesh);
    render_simple_mesh_common(mesh, display_info, clip_radius_mode_show_wireframe);

    used_edges_width := max(edges_width - 1, MIN_EDGES_WIDTH_GL_LINE); // See :NiceTriangleEdgesRendering
    used_edges_width = ifx clip_radius_mode_show_wireframe then MIN_EDGES_WIDTH_GL_LINE else used_edges_width;

    // See also glEnable(GL_LINE_SMOOTH);
    glLineWidth(xx used_edges_width);

    glUniform4f(glGetUniformLocation(app.points_lines_program, "color"), edges_color.x, edges_color.y, edges_color.z, edges_color.w);

    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    glBindVertexArray(render_info.triangles_edges_vao);
    glDrawArrays(GL_TRIANGLES, 0, xx (3 * mesh.triangles.count));
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

    maybe_update_render_info(render_info, mesh);

    program := app.triangles_program;
    glUseProgram(program);

    set_model_view_projection_uniforms(program, mesh.world_from_model);
    set_hover_flash_uniform(program, display_info);
    set_clip_ranges_uniforms(program, display_info);
    set_clip_sphere_uniforms(program, display_info);

    look_direction := current_look_direction();
    used_edges_width := max(edges_width, MIN_EDGES_WIDTH_GL_FILL); // See :NiceTriangleEdgesRendering
    used_edges_width = ifx clip_radius_mode_show_wireframe then MIN_EDGES_WIDTH_GL_FILL else used_edges_width;
    used_edges_visible := ifx clip_radius_mode_show_wireframe then true else edges_visible;

    glUniform1ui(glGetUniformLocation(program, "clip_radius_mode"), xx clip_radius_mode);
    glUniform3f(glGetUniformLocation(program, "camera.eye_position"), app.camera.eye_position.x, app.camera.eye_position.y, app.camera.eye_position.z);
    glUniform3f(glGetUniformLocation(program, "camera.look_direction"), look_direction.x, look_direction.y, look_direction.z);
    glUniform1i(glGetUniformLocation(program, "display_mode"), xx display_mode);
    glUniform1i(glGetUniformLocation(program, "backface_mode"), xx backface_mode);
    glUniform1ui(glGetUniformLocation(program, "flat_shading"), xx flat_shading);
    glUniform4f(glGetUniformLocation(program, "color"), triangles_color.x, triangles_color.y, triangles_color.z, triangles_color.w);
    glUniform4f(glGetUniformLocation(program, "edges_color"), edges_color.x, edges_color.y, edges_color.z, edges_color.w);
    glUniform2f(glGetUniformLocation(program, "window_size"), xx app.current_window_width, xx app.current_window_height);
    glUniform1f(glGetUniformLocation(program, "edges_width"), ifx used_edges_visible then used_edges_width else 0);


    last_polygon_mode: [2]GLuint;
    glGetIntegerv(GL_POLYGON_MODE, xx last_polygon_mode.data);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    glBindVertexArray(render_info.triangles_vao);
    glDrawArrays(GL_TRIANGLES, 0, xx (3 * mesh.triangles.count));
}

// @Cleanup Rename this function and the corresponding shaders and program variable names in App to something that indicates that the variables are used for segment/point rendering
render_simple_mesh_common :: (mesh : *Simple_Mesh, using display_info : Display_Info, clip_radius_mode : bool) {

    program := app.points_lines_program;
    glUseProgram(program);

    // @Cleanup Why is this different to e.g., normals
    used_clip_mode := ifx clip_radius_mode then Clip_Mode.BLACKEN else Clip_Mode.HIDDEN;

    set_model_view_projection_uniforms(program, mesh.world_from_model);
    set_hover_flash_uniform(program, display_info);
    set_clip_ranges_uniforms(program, display_info);
    set_clip_sphere_uniforms(program, display_info, prev_sphere=false);
    glUniform1i(glGetUniformLocation(program, "clip_mode"), xx used_clip_mode);
    glUniform1f(glGetUniformLocation(program, "point_size"), xx points_size);

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
        render_mesh_triangle_normals(*entity.mesh, ri, di); // Probably we want to pass clip_radius_mode here too?
        render_mesh_segments(*entity.mesh, ri, di, clip_radius_mode_show_wireframe);
        render_mesh_segment_normals(*entity.mesh, ri, di); // Probably we want to pass clip_radius_mode here too?
        render_mesh_points(*entity.mesh, ri, di, clip_radius_mode_show_wireframe);
        render_mesh_positions(*entity.mesh, ri, di, clip_radius_mode_show_wireframe);

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

        FilterIterator :: #bake_arguments EntitiesIterator(entity_filter=entity_filter);
        for :FilterIterator entity, entity_index : app.entities {

            // Caches for glyph quads @TODO pull these arrays out of the entity loop so that label overlapping can be fixed across entities e.g., if mesh A and B have a coincident vertex we'd like the text labels for that vertex not to overlap
            vertex_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
            point_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
            segment_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
            triangle_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);

            vertex_annotation_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
            point_annotation_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
            segment_annotation_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
            triangle_annotation_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);

            using,except(is_visible) entity.display_info;

            //
            // Annotation labels
            //

            {
                AddAnnotation :: (point_world : Vector3, annotation_labels : *[..]Label_Info) #expand {
                    if !is_clipped(`entity.display_info, point_world) {
                        text_position_px : Tuple2i = to_screen_position(point_world, projection_from_world);
                        if on_screen_in_disk(text_position_px, app.settings.labelling_radius_px) {
                            text : string = to_string(`annotation);
                            array_add(annotation_labels, make_Label_Info(text_position_px, text));
                        }
                    }
                }

                // @Speed this should use the spatial index?? since annotations are sparse, maybe not
                if any_vertex_label_visible(entity, geometry_labels=false) for annotation : entity.vertex_annotations {
                    point_model := mesh_position_model(entity.mesh, annotation.id);
                    point_world := mesh_position_world(entity.mesh, annotation.id);
                    AddAnnotation(point_world, *vertex_annotation_labels);
                }

                if any_point_label_visible(entity, geometry_labels=false) for annotation : entity.point_annotations {
                    point_model := mesh_point_model(entity.mesh, annotation.id);
                    point_world := mesh_point_world(entity.mesh, annotation.id);
                    AddAnnotation(point_world, *point_annotation_labels);
                }

                if any_segment_label_visible(entity, geometry_labels=false) for annotation : entity.line_annotations {
                    point_model := centroid(mesh_segment3_model(entity.mesh, annotation.id));
                    point_world := centroid(mesh_segment3_world(entity.mesh, annotation.id));
                    AddAnnotation(point_world, *segment_annotation_labels);
                }

                if any_triangle_label_visible(entity, geometry_labels=false) for annotation : entity.face_annotations {
                    point_model := compute_centroid(mesh_triangle_model(entity.mesh, annotation.id));
                    point_world := transform_point(entity.mesh.world_from_model, point_model);
                    AddAnnotation(point_world, *triangle_annotation_labels);
                }
            }

            //
            // Vertex labels
            //

            // @continue FIXME Remove this and instead show the position data for vertices connected to displayed elements
            {
                // @Speed this should use the spatial index??
                if any_vertex_label_visible(entity, annotation_labels=false) for :ModelVertexIterator position_model, position_index : entity.mesh {
                    position_world := mesh_position_world(entity.mesh, position_index);
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
                if any_point_label_visible(entity, annotation_labels=false) for :ModelPointIterator position_model, point_index : entity.mesh {
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
                if any_segment_label_visible(entity, annotation_labels=false) for :ModelSegmentIterator segment : entity.mesh {
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
                Process_Triangle_Data :: struct {
                    entity : *Entity;
                    projection_from_world : *Matrix4;
                    triangle_label_theme : *Element_Label_Theme;
                    triangle_labels : *[..]Label_Info;
                };

                process_triangle_data : Process_Triangle_Data = ---;
                process_triangle_data.entity                = entity;
                process_triangle_data.projection_from_world = *projection_from_world;
                process_triangle_data.triangle_label_theme  = *triangle_label_theme;
                process_triangle_data.triangle_labels       = *triangle_labels;

                process_triangle :: (triangle_model : Triangle3, triangle_index : int, data : *void) {
                    using process_triangle_data := cast(*Process_Triangle_Data) data;
                    point_model : Vector3 = compute_centroid(triangle_model);
                    point_world : Vector3 = transform_point(entity.mesh.world_from_model, point_model);
                    if !is_clipped(entity.display_info, point_world) {
                        text_position_px : Tuple2i = to_screen_position(point_world, projection_from_world);
                        if on_screen_in_disk(text_position_px, app.settings.labelling_radius_px) {
                            text : string = get_point_text(triangle_index, triangle_label_theme);
                            array_add(triangle_labels, make_Label_Info(text_position_px, text));
                        }
                    }
                }

                if any_triangle_label_visible(entity, annotation_labels=false) {
                    if entity.spatial == null {

                        // log_error("Use brute force");
                        for :ModelTriangleIterator entity.mesh {
                            process_triangle(it, it_index, *process_triangle_data);
                        }

                    } else {

                        ray_world : Ray3 = make_camera_ray();
                        ray_model : Ray3 = transform_ray(inverse(entity.mesh.world_from_model), ray_world);
                        distance : float = get_model_space_query_radius(entity.render_info.bounding_aabb, app.settings.labelling_radius_px);

                        // log_error("Use spatial index");
                        visit_elements_near_ray(entity.spatial, ray_model, distance, process_triangle, *process_triangle_data);

                    }
                }
            }

            // TODO Store the pixel->label table per item to resolve overlaps between all these? Probably we don't care about overlaps between items
            draw_label_infos(vertex_labels, vertex_label_theme);
            draw_label_infos(vertex_annotation_labels, vertex_label_theme.annotation_label_theme);

            draw_label_infos(point_labels, point_label_theme);
            draw_label_infos(point_annotation_labels, point_label_theme.annotation_label_theme);

            draw_label_infos(segment_labels, segment_label_theme);
            draw_label_infos(segment_annotation_labels, segment_label_theme.annotation_label_theme);

            draw_label_infos(triangle_labels, triangle_label_theme);
            draw_label_infos(triangle_annotation_labels, triangle_label_theme.annotation_label_theme);
        }
    }

    render_entity_text_ray_cast :: ($entity_filter : Code) {

        should_target_points :: (entity : Entity) -> bool {
            return (any_vertex_label_visible(entity) || any_point_label_visible(entity));
        }

        should_target_segments :: (entity : Entity) -> bool {
            return (any_vertex_label_visible(entity) || any_segment_label_visible(entity));
        }

        should_target_triangles :: (entity : Entity) -> bool {
            return (any_vertex_label_visible(entity) || any_triangle_label_visible(entity));
        }

        closest_world : Closest_Point_Ray_Entity = find_closest_element(
            target_points    = should_target_points,
            target_segments  = should_target_segments,
            target_triangles = should_target_triangles
        );

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

        vertex_annotation_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
        point_annotation_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
        segment_annotation_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);
        triangle_annotation_labels : [..]Label_Info = temp_array(Element_Type=Label_Info);

        projection_from_world : Matrix4 = make_projection_from_world(app.camera);

        using,except(is_visible) entity.display_info;

        // position_index is an index into the array of mesh.positions, which is filled with v-directive data
        AddVertexAndVertexAnnotationLabels :: (position_world : Vector3, position_model : Vector3, position_index : int) #expand {
            // Note: Since we don't have a mapping from mesh.positions to mesh.points we can't easily add to the point_labels array in this function, but this is kindof an unusual case anyhow: it only occurs if you have a triangle element where the connected positions are also point elements
            //if is_visible(`point_label_theme) {...}

            if any_vertex_label_visible(`entity, annotation_labels=false) {
                text_position_px : Tuple2i = to_screen_position(position_world, `projection_from_world);
                text : string = get_point_text(position_model, position_index, `vertex_label_theme);
                array_add(*`vertex_labels, make_Label_Info(text_position_px, text));
            }

            // @Speed this should use the spatial index?? since annotations are sparse, maybe not
            if any_vertex_label_visible(`entity, geometry_labels=false) for :AnnotationIterator annotation : entity {
                if annotation.kind == .VERTEX && annotation.id == position_index {
                    text_position_px : Tuple2i = to_screen_position(position_world, `projection_from_world);
                    text : string = to_string(annotation);
                    array_add(*`vertex_annotation_labels, make_Label_Info(text_position_px, text));
                }
            }
        }


        if #complete closest_world.closest_point_element == {
        case .VERTEX; // aka position

            // @Think closest_world may never return this case actually?

            // Position and annotation label
            {
                position_world := closest_point_world;
                position_model := transform_point(inverse(entity.mesh.world_from_model), closest_point_world);
                position_index := closest_world.element_index;

                AddVertexAndVertexAnnotationLabels(position_world, position_model, position_index);
            }

        case .POINT;

            // Point label
            if any_point_label_visible(entity, annotation_labels=false) {
                text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                text : string = get_point_text(closest_world.element_index, point_label_theme);
                array_add(*point_labels, make_Label_Info(text_position_px, text));
            }

            // Point annotation label
            if any_point_label_visible(entity, geometry_labels=false) for :AnnotationIterator annotation : entity {
               if annotation.kind == .POINT && annotation.id == closest_world.element_index {
                   text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                   text : string = to_string(annotation);
                   array_add(*point_annotation_labels, make_Label_Info(text_position_px, text));
               }
            }

            // Point position and position annotation labels
            {
                position_world := closest_point_world;
                position_model := transform_point(inverse(entity.mesh.world_from_model), closest_point_world);
                position_index := entity.mesh.points[closest_world.element_index];

                AddVertexAndVertexAnnotationLabels(position_world, position_model, position_index);
            }

        case .SEGMENT;

            // Segment label
            if any_segment_label_visible(entity, annotation_labels=false) {
                text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                text : string = get_point_text(closest_world.element_index, segment_label_theme);
                array_add(*segment_labels, make_Label_Info(text_position_px, text));
            }

            // Segment annotation label
            if any_segment_label_visible(entity, geometry_labels=false) for :AnnotationIterator annotation : entity {
                if annotation.kind == .LINE && annotation.id == closest_world.element_index {
                    text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                    text : string = to_string(annotation);
                    array_add(*segment_annotation_labels, make_Label_Info(text_position_px, text));
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

                AddVertexAndVertexAnnotationLabels(position_world, position_model, position_index);
            }

        case .TRIANGLE;

            // Triangle label
            if any_triangle_label_visible(entity, annotation_labels=false) {
                text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                text : string = get_point_text(closest_world.element_index, triangle_label_theme);
                array_add(*triangle_labels, make_Label_Info(text_position_px, text));
            }

            // Triangle annotation label
            if any_triangle_label_visible(entity, geometry_labels=false) for :AnnotationIterator annotation : entity {
                if annotation.kind == .TRIANGLE && annotation.id == closest_world.element_index {
                    text_position_px : Tuple2i = to_screen_position(closest_point_world, projection_from_world);
                    text : string = to_string(annotation);
                    array_add(*triangle_annotation_labels, make_Label_Info(text_position_px, text));
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

                AddVertexAndVertexAnnotationLabels(position_world, position_model, position_index);
            }

        case .MESH;

            //  Do nothing

        }

        // @Cleanup The following block is duplicated in the labelling_mode functions

        // TODO Store the pixel->label table per item to resolve overlaps between all these? Probably we don't care about overlaps between items
        draw_label_infos(vertex_labels, vertex_label_theme);
        draw_label_infos(vertex_annotation_labels, vertex_label_theme.annotation_label_theme);

        draw_label_infos(point_labels, point_label_theme);
        draw_label_infos(point_annotation_labels, point_label_theme.annotation_label_theme);

        draw_label_infos(segment_labels, segment_label_theme);
        draw_label_infos(segment_annotation_labels, segment_label_theme.annotation_label_theme);

        draw_label_infos(triangle_labels, triangle_label_theme);
        draw_label_infos(triangle_annotation_labels, triangle_label_theme.annotation_label_theme);
    }

    not_visible_opaque ::      #code !(is_visible(it) && !it.is_hovered && it.display_info.triangles_color.w == 1.);
    not_visible_transparent :: #code !(is_visible(it) && !it.is_hovered && it.display_info.triangles_color.w != 1.);
    not_visible_hovered ::     #code !(is_visible(it) &&  it.is_hovered);

    VisibleOpaque ::      #bake_arguments EntitiesIterator(entity_filter=not_visible_opaque);
    VisibleTransparent :: #bake_arguments EntitiesIterator(entity_filter=not_visible_transparent);
    VisibleHovered ::     #bake_arguments EntitiesIterator(entity_filter=not_visible_hovered);

    for :VisibleOpaque      app.entities render_entity_geometry(it, it_index);
    for :VisibleTransparent app.entities render_entity_geometry(it, it_index);

    // :RenderingSelectionAABB Here we also render the AABB for a selection of entities, which is a bit of a hack
    if app.template_display_info.aabb_visible {
        render_aabb(app.template_aabb_world, Matrix4_Identity);
    }

    glClear(GL_DEPTH_BUFFER_BIT); // Render the text labels and flash hovered item over everything else

    // @Incomplete Add option to render points in world coordinates? Model is probably mostly useful for 2D shapes

    if #complete app.settings.labelling_mode == {
        case .RAY_CAST;

            render_entity_text_ray_cast(visit_visible);

        case .SPOTLIGHT;

            render_entity_text_spotlight(visit_visible);
    }

    for :VisibleHovered     app.entities render_entity_geometry(it, it_index);
}


render_selections :: () {
    if !app.select_tool.entity.display_info.is_visible {
        return;
    }

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
    render_mesh_segment_normals(mesh, *entity.render_info, entity.display_info);
    render_mesh_triangles_as_lines(mesh, *entity.render_info, entity.display_info, dummy_clip_radius_mode);
    render_mesh_triangles(mesh, *entity.render_info, entity.display_info, dummy_clip_radius_mode, dummy_clip_radius_mode_show_wireframe);
    render_mesh_triangle_normals(mesh, *entity.render_info, entity.display_info);

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
            /* nocommit This line triggers, will it go away if we use GL_TRIANGLES? But why??

OGL: type = performance; source = API; id = 131218; severity = medium
OGL: message = Program/shader state performance warning: Fragment shader in program 19 is being recompiled based on GL state.

            */
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
    defer deinit(*label_table);

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


#scope_file

set_hover_flash_uniform :: (shader : GLuint, using display_info : Display_Info) {
    wave := ifx flash_wave_dt == 0 then -1 else cos(5 * flash_wave_dt);
    glUniform1f(glGetUniformLocation(shader, "wave"), wave);
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

set_clip_ranges_uniforms :: (shader : GLuint, using display_info : Display_Info) {
    for 0..clip_ranges.count-1 {
        // @Cleanup We could use run directive here to get constant strings
        using clip_ranges[it];
        glUniform3f(glGetUniformLocation(shader, to_c_string(tprint("clip_range[%].normal", it))), normal.x, normal.y, normal.z);
        glUniform1f(glGetUniformLocation(shader, to_c_string(tprint("clip_range[%].min", it))), xx min);
        glUniform1f(glGetUniformLocation(shader, to_c_string(tprint("clip_range[%].max", it))), xx max);
        glUniform1f(glGetUniformLocation(shader, to_c_string(tprint("clip_range[%].is_active", it))), xx is_active);
    }
}

set_clip_sphere_uniforms :: (shader : GLuint, using display_info : Display_Info, prev_sphere := true) {
    {
        using clip_sphere;
        glUniform3f(glGetUniformLocation(shader, "clip_sphere.center"), center.x, center.y, center.z);
        glUniform1f(glGetUniformLocation(shader, "clip_sphere.radius"), xx radius);
        glUniform1f(glGetUniformLocation(shader, "clip_sphere.is_active"), xx is_active);
    }

    if prev_sphere {
        using clip_sphere_prev;
        glUniform3f(glGetUniformLocation(shader, "clip_sphere_prev.center"), center.x, center.y, center.z);
        glUniform1f(glGetUniformLocation(shader, "clip_sphere_prev.radius"), xx radius);
        glUniform1f(glGetUniformLocation(shader, "clip_sphere_prev.is_active"), xx is_active);
    }
}

// @Cleanup replace this with: postion_loc = glGetAttribLocation()
ATTRIB_POSITION  :: 0;
ATTRIB_NORMAL    :: 1;
// ATTRIB_TEXCOORDS :: 2;
// ATTRIB_COLOR     :: 3;
