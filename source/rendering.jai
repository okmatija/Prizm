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
    return false;
}

// @Volatile Keep synced with shaders
Clip_Sphere :: struct {
    using #as sphere : Sphere;
    radius := 0h7F800000; // +inf
    is_active : bool = false;
}

// Note: all arguments must be in the same space e.g., world/model coordinates
is_clipped :: (clip_sphere : Clip_Sphere, point : Point3) -> bool {
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
    return false;
}

maybe_update_render_info :: (info : *Render_Info, mesh : *Simple_Mesh) {
}
