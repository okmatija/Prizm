// @Cleanup replace this with: postion_loc = glGetAttribLocation()
ATTRIB_POSITION  :: 0;
ATTRIB_NORMAL    :: 1;
// ATTRIB_TEXCOORDS :: 2;
// ATTRIB_COLOR     :: 3;

// Things that needs updating when the geometry changes
Render_Info :: struct {
    is_dirty := true; // @Think Maybe this should be an enum saying what buffers need updating

    // For rendering obj v-directive data
    // @Cleanup Remove the positions_vbo. It doubles the memory requirement and adds complexity. We can just add points for unreferenced vertices. When we do this we should also move VertexLabelTheme into ElementLabelTheme
    positions_vbo : GLuint;
    positions_vao : GLuint;

    // For rendering obj p-directive data
    points_vbo : GLuint;
    points_vao : GLuint;
    points_normals_vao : GLuint;

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


maybe_update_render_info :: (info : *Render_Info, mesh : *Simple_Mesh) {
    if mesh.positions.count == 0 {
        // Nothing to do in this case @Think is this correct??
        return;
    }

    if info.is_dirty {
        defer info.is_dirty = false;

        // @Cleanup consider doing something like this, or putting a explicit type alias within Simple_Mesh e.g., Point :: u32 rather than hard coding the types her
        // point_type : Type = get_type(type_info(mesh.points).element_type);

        // Note: We do _not_ apply the mesh.world_from_model transform here, that is
        // stored separately to the raw position data so it can be changed efficiently
        // i.e., bounding geometry is defined in the mesh model space
        info.bounding_sphere = ifx mesh.positions.count then bounding_sphere_ritter(mesh.positions) else .{};
        info.bounding_aabb = make_axis_box3(..mesh.positions);

        if mesh.triangles.count {
            // Vertex Buffer will be filled with triangle soup data so that we can represent hard normals etc. For example:
            //
            //  f 1//1 2//2 3//3
            //  f 1//4 2//5 4//6
            //
            // Note we also use glDrawArrays rather than glDrawElements. A glDrawElements call on triangle (1,2,3) and (1,2,4) would draw normals 1,2,3 and 6 but not 4 and 5

            {
                if !info.triangles_vbo glGenBuffers(1, *info.triangles_vbo);

                triangle_positions : [..]Vector3 = temp_array(Vector3);
                array_reserve(*triangle_positions, 3 * mesh.triangles.count);
                for :ModelTriangleIterator mesh {
                    array_add(*triangle_positions, it.a);
                    array_add(*triangle_positions, it.b);
                    array_add(*triangle_positions, it.c);
                }

                normals : *Simple_Mesh_Triangle_Normals = find_or_add_mesh_attribute(mesh, TRIANGLE_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Triangle_Normals);
                assert(normals != null);
                if mesh.triangles.count && (normals.values.count == 0) {
                    // log("Computing and assigning triangle normals to vertices\n");
                    // @Think Maybe this should happen in a tool so that the user is not confused when they look at normals created automatically on an item whose obj had no normals
                    success, failure_reason := compute_vertex_normals_from_triangles(mesh, normals);
                    if !success {
                        log_warning("Failed to assign per-triangle normals. Reason: \"%\"", failure_reason);
                    }
                }

                NP := 3 * size_of(Vector3) * mesh.triangles.count;
                NN := size_of(Matrix3) * normals.values.count;

                glBindBuffer(GL_ARRAY_BUFFER, info.triangles_vbo);
                glBufferData(GL_ARRAY_BUFFER, NP + NN, null, GL_STATIC_DRAW);
                glBufferSubData(GL_ARRAY_BUFFER, 0, NP, triangle_positions.data);
                glBufferSubData(GL_ARRAY_BUFFER, NP, NN, normals.values.data);
            }

            {
                if !info.triangles_vao glGenVertexArrays(1, *info.triangles_vao);

                glBindVertexArray(info.triangles_vao);
                glBindBuffer(GL_ARRAY_BUFFER, info.triangles_vbo);

                NP := 3 * size_of(Vector3) * mesh.triangles.count;

                glEnableVertexAttribArray(ATTRIB_POSITION);
                glEnableVertexAttribArray(ATTRIB_NORMAL);
                glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
                glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)(NP));
            }

            {
                if !info.triangles_edges_vao glGenVertexArrays(1, *info.triangles_edges_vao);

                glBindVertexArray(info.triangles_edges_vao);
                glBindBuffer(GL_ARRAY_BUFFER, info.triangles_vbo);

                glEnableVertexAttribArray(ATTRIB_POSITION);
                glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
            }

            {
                if !info.triangles_normals_vao glGenVertexArrays(1, *info.triangles_normals_vao);

                glBindVertexArray(info.triangles_normals_vao);
                glBindBuffer(GL_ARRAY_BUFFER, info.triangles_vbo);

                NP := 3 * size_of(Vector3) * mesh.triangles.count;

                glEnableVertexAttribArray(ATTRIB_POSITION);
                glEnableVertexAttribArray(ATTRIB_NORMAL);
                glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
                glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)NP);
            }
        }

        if mesh.segments.count {
            {
                if !info.segments_vbo glGenBuffers(1, *info.segments_vbo);

                segment_positions : [..]Vector3 = temp_array(Vector3);
                array_reserve(*segment_positions, 2 * mesh.segments.count);
                for :ModelSegmentIterator mesh {
                    array_add(*segment_positions, it.start);
                    array_add(*segment_positions, it.end);
                }

                normals : *Simple_Mesh_Segment_Normals = find_or_add_mesh_attribute(mesh, SEGMENT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Segment_Normals);
                assert(normals != null);

                NP := 2 * size_of(Vector3) * mesh.segments.count;
                NN := size_of(Matrix3x2) * normals.values.count;

                glBindBuffer(GL_ARRAY_BUFFER, info.segments_vbo);
                glBufferData(GL_ARRAY_BUFFER, NP + NN, null, GL_STATIC_DRAW);
                glBufferSubData(GL_ARRAY_BUFFER, 0, NP, segment_positions.data);
                glBufferSubData(GL_ARRAY_BUFFER, NP, NN, normals.values.data);
            }

            {
                if !info.segments_vao glGenVertexArrays(1, *info.segments_vao);

                glBindVertexArray(info.segments_vao);
                glBindBuffer(GL_ARRAY_BUFFER, info.segments_vbo);
                glEnableVertexAttribArray(ATTRIB_POSITION);
                glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
            }

            {
                if !info.segments_normals_vao glGenVertexArrays(1, *info.segments_normals_vao);

                glBindVertexArray(info.segments_normals_vao);
                glBindBuffer(GL_ARRAY_BUFFER, info.segments_vbo);

                NP := 2 * size_of(Vector3) * mesh.segments.count;

                glEnableVertexAttribArray(ATTRIB_POSITION);
                glEnableVertexAttribArray(ATTRIB_NORMAL);
                glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
                glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)NP);
            }
        }

        if mesh.points.count {
            {
                if !info.points_vbo glGenBuffers(1, *info.points_vbo);

                point_positions : [..]Vector3 = temp_array(Vector3);
                array_reserve(*point_positions, mesh.points.count);
                for :ModelPointIterator mesh {
                    array_add(*point_positions, it);
                }

                normals : *Simple_Mesh_Point_Normals = find_or_add_mesh_attribute(mesh, POINT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Point_Normals);
                assert(normals != null);

                NP := size_of(Vector3) * mesh.points.count;
                NN := size_of(Vector3) * normals.values.count;

                glBindBuffer(GL_ARRAY_BUFFER, info.points_vbo);
                glBufferData(GL_ARRAY_BUFFER, NP + NN, null, GL_STATIC_DRAW);
                glBufferSubData(GL_ARRAY_BUFFER, 0, NP, point_positions.data);
                glBufferSubData(GL_ARRAY_BUFFER, NP, NN, normals.values.data);
            }

            {
                if !info.points_vao glGenVertexArrays(1, *info.points_vao);

                glBindVertexArray(info.points_vao);
                glBindBuffer(GL_ARRAY_BUFFER, info.points_vbo);
                glEnableVertexAttribArray(ATTRIB_POSITION);
                glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
            }

            {
                if !info.points_normals_vao glGenVertexArrays(1, *info.points_normals_vao);

                glBindVertexArray(info.points_normals_vao);
                glBindBuffer(GL_ARRAY_BUFFER, info.points_vbo);

                NP := size_of(Vector3) * mesh.points.count;
                glEnableVertexAttribArray(ATTRIB_POSITION);
                glEnableVertexAttribArray(ATTRIB_NORMAL);
                glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
                glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)NP);
            }
        }

        if mesh.positions.count {
            {
                if !info.positions_vbo glGenBuffers(1, *info.positions_vbo);

                NP := size_of(Vector3) * mesh.positions.count;
                glBindBuffer(GL_ARRAY_BUFFER, info.positions_vbo);
                glBufferData(GL_ARRAY_BUFFER, NP, null, GL_STATIC_DRAW);
                glBufferSubData(GL_ARRAY_BUFFER, 0, NP, mesh.positions.data);
            }

            {
                if !info.positions_vao glGenVertexArrays(1, *info.positions_vao);

                glBindVertexArray(info.positions_vao);
                glBindBuffer(GL_ARRAY_BUFFER, info.positions_vbo);
                glEnableVertexAttribArray(ATTRIB_POSITION);
                glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, false, size_of(Vector3), cast(*void)0);
            }
        }

    } // end if info.is_dirty
}





// @Cleanup consolidate this
// @Incomplete handle wave?
render_mesh_triangle_normals :: (
    mesh : *Simple_Mesh,
    using render_info : *Render_Info,
    using display_info : Display_Info) {

    if !mesh.triangles.count return;
    if !triangle_style.normal_style.visible return;

    maybe_update_render_info(render_info, mesh);

    use_shader(*app.shader_triangle_normal_vectors, mesh, display_info);

    glLineWidth(2); // 1, 2, 3... See also glEnable(GL_LINE_SMOOTH);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glBindVertexArray(render_info.triangles_normals_vao);
    glDrawArrays(GL_TRIANGLES, 0, xx (3 * mesh.triangles.count));
}

// @Incomplete handle wave?
render_mesh_segment_normals :: (
    mesh : *Simple_Mesh,
    using render_info : *Render_Info,
    using display_info : Display_Info) {

    // @CompilerBug Add a return here and observe a compilation failure with message:
    // Error: Unable to open output file "C:/Users/matija.kecman/Dropbox/Prizm/.build/Prizm_1_w3.obj" for LLVM code generation: The process cannot access the file because it is being used by another process.

    if !mesh.segments.count return;
    if !segment_style.normal_style.visible return;

    maybe_update_render_info(render_info, mesh);

    use_shader(*app.shader_segment_normal_vectors, mesh, display_info);

    glLineWidth(2); // 1, 2, 3... See also glEnable(GL_LINE_SMOOTH);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glBindVertexArray(render_info.segments_normals_vao);
    glDrawArrays(GL_LINES, 0, xx (2 * mesh.segments.count));
}

// @Incomplete handle wave?
render_mesh_point_normals :: (
    mesh : *Simple_Mesh,
    using render_info : *Render_Info,
    using display_info : Display_Info) {

    if !mesh.points.count return;
    if !point_style.normal_style.visible return;

    maybe_update_render_info(render_info, mesh);

    use_shader(*app.shader_point_normal_vectors, mesh, display_info);

    glLineWidth(2); // 1, 2, 3... See also glEnable(GL_LINE_SMOOTH);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glBindVertexArray(render_info.points_normals_vao);
    glDrawArrays(GL_POINTS, 0, xx mesh.points.count);
}

render_aabb :: (aabb_model : AxisBox3, world_from_model : Matrix4) {

    app.shader_aabb.use_shader(*app.shader_aabb, aabb_model, world_from_model);

    glDrawArrays(GL_LINES, 0, 24);
}

render_mesh_positions :: (
    mesh : *Simple_Mesh,
    using render_info : *Render_Info,
    using display_info : Display_Info,
    clip_radius_mode_show_wireframe : bool) {

    if !mesh.positions.count return;
    if !vertex_style.visible && !clip_radius_mode_show_wireframe return;

    shader := *app.shader_points_lines;
    shader.use_shader(shader, mesh, display_info, clip_radius_mode_show_wireframe, vertex_style.color);
    used_point_size : float = ifx clip_radius_mode_show_wireframe then 2. else cast(float)vertex_style.size;
    set_shader_uniform_value(shader, "point_size", used_point_size);

    last_polygon_mode: [2]GLuint;
    glGetIntegerv(GL_POLYGON_MODE, xx last_polygon_mode.data);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);
    glEnable(GL_PROGRAM_POINT_SIZE); // This is needed so we can assign to gl_PointSize in the shader

    glBindVertexArray(render_info.positions_vao);
    glDrawArrays(GL_POINTS, 0, xx mesh.positions.count);
}

render_mesh_points :: (
    mesh : *Simple_Mesh,
    using render_info : *Render_Info,
    using display_info : Display_Info,
    clip_radius_mode_show_wireframe : bool) {

    if !mesh.points.count return;
    if !point_style.visible && !clip_radius_mode_show_wireframe return;

    maybe_update_render_info(render_info, mesh);

    shader := *app.shader_points_lines;
    shader.use_shader(shader, mesh, display_info, clip_radius_mode_show_wireframe, point_style.vertex_style.color);
    used_point_size : float = ifx clip_radius_mode_show_wireframe then 2. else cast(float)point_style.vertex_style.size;
    set_shader_uniform_value(shader, "point_size", used_point_size);

    last_polygon_mode: [2]GLuint;
    glGetIntegerv(GL_POLYGON_MODE, xx last_polygon_mode.data);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);
    glEnable(GL_PROGRAM_POINT_SIZE); // This is needed so we can assign to gl_PointSize in the shader

    glBindVertexArray(render_info.points_vao);
    glDrawArrays(GL_POINTS, 0, xx mesh.points.count);
}

render_mesh_segments :: (
    mesh : *Simple_Mesh,
    using render_info : *Render_Info,
    using display_info : Display_Info,
    clip_radius_mode : bool) {

    if !mesh.segments.count return;
    if !segment_style.visible && !clip_radius_mode return;

    maybe_update_render_info(render_info, mesh);

    shader := *app.shader_points_lines;
    shader.use_shader(shader, mesh, display_info, clip_radius_mode, segment_style.color);

    used_segments_width := ifx clip_radius_mode then 1. else segment_style.width; // ifx ensures that the min width is chosen for clip_radius_mode
    if (used_segments_width > 0) {
        // See also glEnable(GL_LINE_SMOOTH);
        glLineWidth(xx used_segments_width);
    }
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
// TODOO Maybe note the degenerate triangles when we parse the obj file and store them so we don't render all edges here... rendering all the edges with lines is ugly (it would be less ugly if we used quads strips to render lines).
render_mesh_triangles_as_lines :: (
    mesh : *Simple_Mesh,
    using render_info : *Render_Info,
    using display_info : Display_Info,
    clip_radius_mode_show_wireframe : bool) {

    if !mesh.triangles.count return;
    if !triangle_style.edge_style.visible && !clip_radius_mode_show_wireframe return;

    maybe_update_render_info(render_info, mesh);

    shader := *app.shader_points_lines;
    shader.use_shader(shader, mesh, display_info, clip_radius_mode_show_wireframe, triangle_style.edge_style.color);

    used_edges_width := max(triangle_style.edge_style.width - 1, MIN_EDGES_WIDTH_GL_LINE); // See :NiceTriangleEdgesRendering
    used_edges_width = ifx clip_radius_mode_show_wireframe then MIN_EDGES_WIDTH_GL_LINE else used_edges_width;
    glLineWidth(xx used_edges_width); // See also glEnable(GL_LINE_SMOOTH);
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
 
    if !mesh.triangles.count return;
    if !triangle_style.visible return;

    maybe_update_render_info(render_info, mesh);

    use_shader(*app.shader_triangles, mesh, display_info);

    // @Volatile :ClipRadiusModeEdgeWidth
    app.shader_triangles.set_shader_clip_radius_uniforms(app.shader_triangles, triangle_style, clip_radius_mode, clip_radius_mode_show_wireframe);

    // nocommit Remove this
    last_polygon_mode: [2]GLuint;
    glGetIntegerv(GL_POLYGON_MODE, xx last_polygon_mode.data);

    // nocommit Extract this
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendEquation(GL_FUNC_ADD);

    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    glBindVertexArray(render_info.triangles_vao);
    glDrawArrays(GL_TRIANGLES, 0, xx (3 * mesh.triangles.count));
}

// @TODOOOO @Speedddd We should order operations to minimize OpenGL state changes ie we should
// set shaders and then loop over all items, currently for each item we set a bunch of different
// shaders
render_entities :: () {

    ScopeGlState();

    for :VisibleOpaque      app.entities render_entity_geometry(it, it_index);
    for :VisibleTransparent app.entities render_entity_geometry(it, it_index);

    // :RenderingSelectionAABB Here we also render the AABB for a selection of entities, which is a bit of a hack
    if app.template_display_info.aabb_visible {
        render_aabb(app.template_aabb_world, Matrix4_Identity);
    }

    glClear(GL_DEPTH_BUFFER_BIT); // Render the text labels and flash hovered item over everything else

    for :VisibleHovered     app.entities render_entity_geometry(it, it_index);
}

set_gbuffer_program :: () {

}

render_entities_gbuffer :: () {

    DebugScopeGLGroup("render_entities_gbuffer");

    //glViewport(0, 0, xx app.window_size.width, xx app.window_size.height);

    {
        DebugScopeGLGroup("geometry pass");

        use_geometry_pass();

        for :VisibleOpaque app.entities {
            ri := *it.render_info;
            di :=  it.display_info;

            if !it.mesh.triangles.count continue;
            if !di.triangle_style.visible continue;

            maybe_update_render_info(ri, *it.mesh);

            app.shader_geometry.use_shader(*app.shader_geometry, it.mesh, di.triangle_style.color);
            //debug_print_active_uniforms(app.shader_geometry.program);

            // nocommit I pass in a color with components in the range [0., 1.] but I specify a RGBA8 texture with components in the range [0,255]

            glBindVertexArray(ri.triangles_vao);
            glDrawArrays(GL_TRIANGLES, 0, xx (3 * it.mesh.triangles.count));
        }
    }

    {
        DebugScopeGLGroup("SSAO pass");

        use_ssao_pass();
        use_shader(*app.shader_ssao);

        glBindVertexArray(app.quad_vao);
        glDrawArrays(GL_TRIANGLES, 0, 6);  
    }

    debug_blit_texture();


    //{
    //    DebugScopeGLGroup("SSAO blur pass");
    //}

    if false {
        DebugScopeGLGroup("lighting pass");

        // Lighting pass
        glBindFramebuffer(GL_FRAMEBUFFER, 0); // back to default
        glClearColor(0., 0., 0., 1.); 
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        use_shader(*app.shader_lighting);

        glBindVertexArray(app.quad_vao);
        glDrawArrays(GL_TRIANGLES, 0, 6);  
    }

}



render_selections :: () {
    if !app.select_tool.entity.display_info.is_visible {
        return;
    }

    ScopeGlState();

    // nocommit Remove this, can it even be triggered???
    if app.select_tool.entity.is_hovered {
        glClear(GL_DEPTH_BUFFER_BIT);
    }

    entity := *app.select_tool.entity;
    mesh := *app.select_tool.entity.mesh;

    dummy_clip_radius_mode := false; // @Incomplete Support this for the selection item when its the 0-th item?
    dummy_clip_radius_mode_show_wireframe := false; // @Incomplete Support this for the selection item when its the 0-th item?

    render_mesh_positions(mesh, *entity.render_info, entity.display_info, dummy_clip_radius_mode);
    render_mesh_points(mesh, *entity.render_info, entity.display_info, dummy_clip_radius_mode);
    render_mesh_point_normals(*entity.mesh, *entity.render_info, entity.display_info); // Probably we want to pass clip_radius_mode here too?
    render_mesh_segments(mesh, *entity.render_info, entity.display_info, dummy_clip_radius_mode);
    render_mesh_segment_normals(mesh, *entity.render_info, entity.display_info);
    render_mesh_triangles_as_lines(mesh, *entity.render_info, entity.display_info, dummy_clip_radius_mode);
    render_mesh_triangles(mesh, *entity.render_info, entity.display_info, dummy_clip_radius_mode, dummy_clip_radius_mode_show_wireframe);
    render_mesh_triangle_normals(mesh, *entity.render_info, entity.display_info);

    // projection_from_model := make_projection_from_world(app.camera) * mesh.world_from_model;
    //
    // // We intentionally always all the text for selections since there usually aren't lots
    // // of overlapping ones and its annoying not to see everything. We also don't consider
    // // the clipping sphere (there is no way to set it right now, anyway) since this is also
    // // annoying in the case of selections
    //
    // // Disabled text rendering while selecting, that can be done after caching the selection
    // vertex_theme := entity.display_info.vertex_label_theme;
    // for mesh.positions {
    //     text := get_point_text(it, it_index, vertex_theme);
    //
    //     // @CompilerBug When I move this to a better place I got an undeclared identifier error for Tuple2i.
    //     to_imgui_position :: (position_screen : Tuple2i) -> ImGui.ImVec2 {
    //         return .{cast(float) position_screen.x, cast(float)app.window_size.height - cast(float) position_screen.y};
    //     }
    //
    //     window_position : ImGui.ImVec2 = to_imgui_position(to_screen_position(it, projection_from_model));
    //
    //     font, color := get_label_font(entity, .VERTEX);
    //     ImGui.PushFont(font);
    //     window_size := ImGui.CalcTextSize(text);
    //     LabelWindow(window_position, window_size);
    //     ImGui.TextColored(vertex_theme.label_color, "%", text);
    //     ImGui.PopFont();
    // }
}


render_background :: () {

    ScopeGlState();

    if #complete app.background_style == {
        case .SOLID_COLOR;

            using app.background_solid_color;
            glClearColor(x, y, z, w);

        case .CUSTOM_SHADER;

            // FIXMEEE We can remove this is we put the quad on the far plan..!?
            // FIXMEEE When I remove this the depth tests for other shaders gets screwed up... I should add that!
            glDisable(GL_DEPTH_TEST);
            defer glEnable(GL_DEPTH_TEST);

            app.shader_background.use_shader(*app.shader_background);

            glBindVertexArray(app.shader_background.vao);
            glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
            /* TODOOO This line triggers, will it go away if we use GL_TRIANGLES? But why??

OGL: type = performance; source = API; id = 131218; severity = medium
OGL: message = Program/shader state performance warning: Fragment shader in program 19 is being recompiled based on GL state.

            */
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
}


#scope_file

entity_in_clip_radius_mode :: (entity_index : int) -> bool {
    return mouse_set_clip_radius() && app.clipping_sphere_mode_entity_index >= 0 &&
    (
        ( app.entities[app.clipping_sphere_mode_entity_index].is_selected && app.entities[entity_index].is_selected) ||
        (!app.entities[app.clipping_sphere_mode_entity_index].is_selected && app.clipping_sphere_mode_entity_index == entity_index)
    );
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

not_visible_opaque ::      #code !(is_visible(it) && !it.is_hovered && it.display_info.triangle_style.color.w == 1.);
not_visible_transparent :: #code !(is_visible(it) && !it.is_hovered && it.display_info.triangle_style.color.w != 1.);
not_visible_hovered ::     #code !(is_visible(it) &&  it.is_hovered);

VisibleOpaque ::      #bake_arguments EntitiesIterator(entity_filter=not_visible_opaque);
VisibleTransparent :: #bake_arguments EntitiesIterator(entity_filter=not_visible_transparent);
VisibleHovered ::     #bake_arguments EntitiesIterator(entity_filter=not_visible_hovered);

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
    render_mesh_point_normals(*entity.mesh, ri, di); // Probably we want to pass clip_radius_mode here too?
    render_mesh_positions(*entity.mesh, ri, di, clip_radius_mode_show_wireframe);

    if di.aabb_visible {
        render_aabb(ri.bounding_aabb, entity.mesh.world_from_model);
    }
}

