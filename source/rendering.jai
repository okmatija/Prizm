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
    SCREENTONE_2 :: 5; // TODOOO Replace this with an outline mode where we discard all the fragments which aren't near the triangle edge
}

cycle_display_mode :: (mode : *Display_Mode) {
    if #complete mode.* == {
        case .NORMALS;     mode.* = .BLINN_PHONG;
        case .SOLID_COLOR; mode.* = .NORMALS;
        case .BLINN_PHONG; mode.* = .NORMALS;
    }
}

Clip_Mode :: enum #specified {
    HIDDEN ::  0;
    BLACKEN :: 1;
    DARKEN ::  2;
}

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
    visible := false;
    color := Vector4.{0., 0., .8, 1.};
    scale : float = 1.; // Multiplies the obj normal. If normalized is true then this value is the length
    normalized : bool = true; // If true the obj normal is normalized before scale is applied
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

    normal_style : Normal_Style;
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
    display_mode := Display_Mode.BLINN_PHONG;
    backface_mode := Backface_Mode.FIXED;
    flat_shading := true;

    edge_style : Edge_Style;
    normal_style : Normal_Style;
}


// Things that should be preserved when the geometry changes
Display_Info :: struct {

    // Set overall visibility without clobbering the individual settings. Considers both geometry and labels
    is_visible := true;

    //
    // Labeling members
    //

    show_labels := true; // @Think Use this to sets overall text labels visibility without clobbering more granular settings?
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

    vertex_style : Vertex_Style;
    point_style : Point_Style;
    segment_style : Segment_Style;
    triangle_style : Triangle_Style;

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

is_clipped :: (display_info : Display_Info, point_world : Point3, test_sphere := true, test_ranges := true) -> bool {
    if test_sphere && is_clipped(display_info.clip_sphere, point_world) {
        return true;
    }

    if test_ranges && is_clipped(display_info.clip_ranges, point_world) {
        return true;
    }

    return false;
}

maybe_update_render_info :: (info : *Render_Info, mesh : *Simple_Mesh) {
    if mesh.positions.count == 0 {
        // Nothing to do in this case @Think is this correct??
        return;
    }

    if info.is_dirty {
        defer info.is_dirty = false;

        // @Cleanup consider doing something like this, or putting a explicit type alias within Simple_Mesh e.g., Point :: u32 rather than hard coding the types here
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
