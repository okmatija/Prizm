// @Incomplete Autogenerate this file!
// - Sometimes we want just a single bool for an entire struct?
// - Could make some of the functions private in an automatic way?

get_update :: inline (old : $T, new : T) -> bool {
    return old != new;
}

apply_update :: inline (update : bool, source : $T, target : *T) {
    if update {
        <<target = source;
    }
}

//
// Vector3
//

Vector3_Update :: struct {
    x : bool = false;
    y : bool = false;
    z : bool = false;

#place x;
    component: [3]bool = ---;
}

get_update :: (old : Vector3, new : Vector3) -> Vector3_Update {
    result : Vector3_Update;

    result.x = get_update(old.x, new.x);
    result.y = get_update(old.y, new.y);
    result.z = get_update(old.z, new.z);

    return result;
}

apply_update :: (update : Vector3_Update, source : Vector3, target : *Vector3) {
    apply_update(update.x, source.x, *target.x);
    apply_update(update.y, source.y, *target.y);
    apply_update(update.z, source.z, *target.z);
}

//
// Vector4
//

Vector4_Update :: struct {
    x : bool = false;
    y : bool = false;
    z : bool = false;
    w : bool = false;

#place x;
    component: [4]bool = ---;
}

get_update :: (old : Vector4, new : Vector4) -> Vector4_Update {
    result : Vector4_Update;

    result.x = get_update(old.x, new.x);
    result.y = get_update(old.y, new.y);
    result.z = get_update(old.z, new.z);
    result.w = get_update(old.w, new.w);

    return result;
}

apply_update :: (update : Vector4_Update, source : Vector4, target : *Vector4) {
    apply_update(update.x, source.x, *target.x);
    apply_update(update.y, source.y, *target.y);
    apply_update(update.z, source.z, *target.z);
    apply_update(update.w, source.w, *target.w);
}

//
// Sphere
//

Sphere_Update :: struct {
    center : Vector3_Update;
    radius : bool = false;
}

get_update :: (old : Sphere, new : Sphere) -> Sphere_Update {
    result : Sphere_Update;

    result.center = get_update(old.center, new.center);
    result.radius = get_update(old.radius, new.radius);

    return result;
}

apply_update :: (update : Sphere_Update, source : Sphere, target : *Sphere) {
    apply_update(update.center, source.center, *target.center);
    apply_update(update.radius, source.radius, *target.radius);
}

//
// Clip_Sphere
//

Clip_Sphere_Update :: struct {
    sphere : Sphere_Update;
    is_active : bool = false;
}

get_update :: (old : Clip_Sphere, new : Clip_Sphere) -> Clip_Sphere_Update {
    result : Clip_Sphere_Update;

    result.sphere = get_update(old.sphere, new.sphere);
    result.is_active = get_update(old.is_active, new.is_active);

    return result;
}

apply_update :: (update : Clip_Sphere_Update, source : Clip_Sphere, target : *Clip_Sphere) {
    apply_update(update.sphere, source.sphere, *target.sphere);
    apply_update(update.is_active, source.is_active, *target.is_active);
}

//
// Clip_Range
//

Clip_Range_Update :: struct {
    normal : Vector3_Update;
    is_active : bool = false;
    min : bool = false;
    max : bool = false;
}

get_update :: (old : Clip_Range, new : Clip_Range) -> Clip_Range_Update {
    result : Clip_Range_Update;

    result.normal = get_update(old.normal, new.normal);
    result.is_active = get_update(old.is_active, new.is_active);
    result.min = get_update(old.min, new.min);
    result.max = get_update(old.max, new.max);

    return result;
}

apply_update :: (update : Clip_Range_Update, source : Clip_Range, target : *Clip_Range) {
    apply_update(update.normal, source.normal, *target.normal);
    apply_update(update.is_active, source.is_active, *target.is_active);
    apply_update(update.min, source.min, *target.min);
    apply_update(update.max, source.max, *target.max);
}

//
// Vertex_Label_Theme
//

Vertex_Label_Theme_Update :: struct {
    show_position : bool;
    show_index : bool;
    label_scale : bool;
    label_color : Vector4_Update;
}

get_update :: (old : Vertex_Label_Theme, new : Vertex_Label_Theme) -> Vertex_Label_Theme_Update {
    result : Vertex_Label_Theme_Update;

    result.show_position = get_update(old.show_position, new.show_position);
    result.show_index =    get_update(old.show_index, new.show_index);
    result.label_scale =   get_update(old.label_scale, new.label_scale);
    result.label_color =   get_update(old.label_color, new.label_color);

    return result;
}

apply_update :: (update : Vertex_Label_Theme_Update, source : Vertex_Label_Theme, target : *Vertex_Label_Theme) {
    apply_update(update.show_position, source.show_position, *target.show_position);
    apply_update(update.show_index, source.show_index, *target.show_index);
    apply_update(update.label_scale, source.label_scale, *target.label_scale);
    apply_update(update.label_color, source.label_color, *target.label_color);
}

//
// Element_Label_Theme
//

Element_Label_Theme_Update :: struct {
    show_index : bool;
    label_scale : bool;
    label_color : Vector4_Update;
}

get_update :: (old : Element_Label_Theme, new : Element_Label_Theme) -> Element_Label_Theme_Update {
    result : Element_Label_Theme_Update;

    result.show_index =    get_update(old.show_index, new.show_index);
    result.label_scale =   get_update(old.label_scale, new.label_scale);
    result.label_color =   get_update(old.label_color, new.label_color);

    return result;
}

apply_update :: (update : Element_Label_Theme_Update, source : Element_Label_Theme, target : *Element_Label_Theme) {
    apply_update(update.show_index, source.show_index, *target.show_index);
    apply_update(update.label_scale, source.label_scale, *target.label_scale);
    apply_update(update.label_color, source.label_color, *target.label_color);
}



//
// Annotation_Label_Theme
//

Annotation_Label_Theme_Update :: struct {
    visible : bool;
    label_scale : bool;
    label_color : Vector4_Update;
}

get_update :: (old : Annotation_Label_Theme, new : Annotation_Label_Theme) -> Annotation_Label_Theme_Update {
    result : Annotation_Label_Theme_Update;

    result.visible = get_update(old.visible, new.visible);
    result.label_scale = get_update(old.label_scale, new.label_scale);
    result.label_color = get_update(old.label_color, new.label_color);

    return result;
}

apply_update :: (update : Annotation_Label_Theme_Update, source : Annotation_Label_Theme, target : *Annotation_Label_Theme) {
    apply_update(update.visible, source.visible, *target.visible);
    apply_update(update.label_scale, source.label_scale, *target.label_scale);
    apply_update(update.label_color, source.label_color, *target.label_color);
}

//
// Attribute_Theme
//

// @Think Do we even want this? The XXX_Update stucts are used to apply changes to multiple items. We can use it to apply changes to multiple items with the same attribute
Attribute_Theme_Update :: struct {
    visible : bool;
    label_scale : bool;
    label_color : Vector4_Update;
}

get_update :: (old : Attribute_Theme, new : Attribute_Theme) -> Attribute_Theme_Update {
    result : Attribute_Theme_Update;

    result.visible = get_update(old.visible, new.visible);
    result.label_scale = get_update(old.label_scale, new.label_scale);
    result.label_color = get_update(old.label_color, new.label_color);

    return result;
}

apply_update :: (update : Attribute_Theme_Update, source : Attribute_Theme, target : *Attribute_Theme) {
    apply_update(update.visible, source.visible, *target.visible);
    apply_update(update.label_scale, source.label_scale, *target.label_scale);
    apply_update(update.label_color, source.label_color, *target.label_color);
}

//
// Display_Info
//

// @TODO Implment a compile-time check that the entries here match Display_Mode, use annotations to selectively ignore stuff
Display_Info_Update :: struct {

    is_visible : bool;
    display_mode : bool;
    backface_mode : bool;
    flat_shading : bool;

    vertex_label_theme : Vertex_Label_Theme_Update;
    point_label_theme : Element_Label_Theme_Update;
    segment_label_theme : Element_Label_Theme_Update;
    triangle_label_theme : Element_Label_Theme_Update;
    annotation_label_theme : Annotation_Label_Theme_Update;

    points_visible : bool;
    points_color : Vector4_Update;
    points_size : bool;

    normals_visible : bool;
    normals_color : Vector4_Update;
    normals_length : bool;

    segments_visible : bool;
    segments_color : Vector4_Update;
    segments_width : bool;

    triangles_visible : bool;
    triangles_color : Vector4_Update;

    edges_visible : bool;
    edges_color : Vector4_Update;
    edges_width : bool;

    clip_ranges : [3]Clip_Range_Update;
    clip_sphere : Clip_Sphere_Update;
}

get_update :: (old : Display_Info, new : Display_Info) -> Display_Info_Update {
    result : Display_Info_Update;

    result.is_visible = get_update(old.is_visible, new.is_visible);
    result.display_mode = get_update(old.display_mode, new.display_mode);
    result.backface_mode = get_update(old.backface_mode, new.backface_mode);
    result.flat_shading = get_update(old.flat_shading, new.flat_shading);

    result.vertex_label_theme = get_update(old.vertex_label_theme, new.vertex_label_theme);
    result.point_label_theme = get_update(old.point_label_theme, new.point_label_theme);
    result.segment_label_theme = get_update(old.segment_label_theme, new.segment_label_theme);
    result.triangle_label_theme = get_update(old.triangle_label_theme, new.triangle_label_theme);
    result.annotation_label_theme = get_update(old.annotation_label_theme, new.annotation_label_theme);

    result.points_visible = get_update(old.points_visible, new.points_visible);
    result.points_color = get_update(old.points_color, new.points_color);
    result.points_size = get_update(old.points_size, new.points_size);

    result.normals_visible = get_update(old.normals_visible, new.normals_visible);
    result.normals_color = get_update(old.normals_color, new.normals_color);
    result.normals_length = get_update(old.normals_length, new.normals_length);

    result.segments_visible = get_update(old.segments_visible, new.segments_visible);
    result.segments_color = get_update(old.segments_color, new.segments_color);
    result.segments_width = get_update(old.segments_width, new.segments_width);

    result.triangles_visible = get_update(old.triangles_visible, new.triangles_visible);
    result.triangles_color = get_update(old.triangles_color, new.triangles_color);

    result.edges_visible = get_update(old.edges_visible, new.edges_visible);
    result.edges_color = get_update(old.edges_color, new.edges_color);
    result.edges_width = get_update(old.edges_width, new.edges_width);

    result.clip_ranges[0] = get_update(old.clip_ranges[0], new.clip_ranges[0]);
    result.clip_ranges[1] = get_update(old.clip_ranges[1], new.clip_ranges[1]);
    result.clip_ranges[2] = get_update(old.clip_ranges[2], new.clip_ranges[2]);
    result.clip_sphere = get_update(old.clip_sphere, new.clip_sphere);

    return result;
}

apply_update :: (update : Display_Info_Update, source : Display_Info, target : *Display_Info) {
    apply_update(update.is_visible, source.is_visible, *target.is_visible);
    apply_update(update.display_mode, source.display_mode, *target.display_mode);
    apply_update(update.backface_mode, source.backface_mode, *target.backface_mode);
    apply_update(update.flat_shading, source.flat_shading, *target.flat_shading);

    apply_update(update.vertex_label_theme, source.vertex_label_theme, *target.vertex_label_theme);
    apply_update(update.point_label_theme, source.point_label_theme, *target.point_label_theme);
    apply_update(update.segment_label_theme, source.segment_label_theme, *target.segment_label_theme);
    apply_update(update.triangle_label_theme, source.triangle_label_theme, *target.triangle_label_theme);
    apply_update(update.annotation_label_theme, source.annotation_label_theme, *target.annotation_label_theme);

    apply_update(update.points_visible, source.points_visible, *target.points_visible);
    apply_update(update.points_color, source.points_color, *target.points_color);
    apply_update(update.points_size, source.points_size, *target.points_size);

    apply_update(update.normals_visible, source.normals_visible, *target.normals_visible);
    apply_update(update.normals_color, source.normals_color, *target.normals_color);
    apply_update(update.normals_length, source.normals_length, *target.normals_length);

    apply_update(update.segments_visible, source.segments_visible, *target.segments_visible);
    apply_update(update.segments_color, source.segments_color, *target.segments_color);
    apply_update(update.segments_width, source.segments_width, *target.segments_width);

    apply_update(update.triangles_visible, source.triangles_visible, *target.triangles_visible);
    apply_update(update.triangles_color, source.triangles_color, *target.triangles_color);

    apply_update(update.edges_visible, source.edges_visible, *target.edges_visible);
    apply_update(update.edges_color, source.edges_color, *target.edges_color);
    apply_update(update.edges_width, source.edges_width, *target.edges_width);

    apply_update(update.clip_ranges[0], source.clip_ranges[0], *target.clip_ranges[0]);
    apply_update(update.clip_ranges[1], source.clip_ranges[1], *target.clip_ranges[1]);
    apply_update(update.clip_ranges[2], source.clip_ranges[2], *target.clip_ranges[2]);
    apply_update(update.clip_sphere, source.clip_sphere, *target.clip_sphere);
}

#run {
    info :   Display_Info;
    update : Display_Info_Update;
    if info.clip_ranges.count != update.clip_ranges.count {
        error_message := tprint("Expected clip_ranges arrays to have equal sizes (% != %)", info.clip_ranges.count, update.clip_ranges.count);
        compiler_report(#file, #line, 0, error_message);
    }
}