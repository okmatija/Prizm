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

// @Think Perhaps this should be in the Element_Label_Theme too so you can visualize only the vertices associated with the elements, maybe Simple_Mesh should store vertices referenced by each element type separately?
Vertex_Label_Theme :: struct {
    // @Cleanup replace with a combo box
    show_index := false;
    show_position := false;

    label_scale := Font_Size.LARGE;
    label_color : Vector4 = .{0., 0., .75, 1.}; // Blue, works well on both grey and white backgrounds

    annotation_label_theme : Annotation_Label_Theme;

    // world_space : bool = false; // @Incomplete
}

// For mesh topology/geometry labels
Element_Label_Theme :: struct {
    show_index := false;
    label_scale := Font_Size.LARGE;
    label_color := INDEX_LABEL_COLOR;

    annotation_label_theme : Annotation_Label_Theme;
}

Attribute_Theme :: struct {
    visible := false;
    label_scale := Font_Size.LARGE;
    label_color : Vector4 = .{0., 0., .75, 1.}; // Blue, works well on both grey and white backgrounds
}

// nocommit rename Annotation_Theme
Annotation_Label_Theme :: struct {
    visible := false;
    label_scale := Font_Size.LARGE;
    label_color : Vector4 = .{0., 0., .75, 1.}; // Blue, works well on both grey and white backgrounds
}

// nocommit Move this into Triangle_Style (rename that to Triangle_Theme)
Display_Mode :: enum #specified {
    NORMALS ::     0;
    SOLID_COLOR :: 1; // nocommit remove this, its totally useless
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





is_clipped :: (display_info : Display_Info, point_world : Point3, test_sphere := true, test_ranges := true) -> bool {
    if test_sphere && is_clipped(display_info.clip_sphere, point_world) {
        return true;
    }

    if test_ranges && is_clipped(display_info.clip_ranges, point_world) {
        return true;
    }

    return false;
}


