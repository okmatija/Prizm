// @Incompleteeee Autogenerate this file!
// - Sometimes we want just a single bool for an entire struct?
// - Could make some of the functions private in an automatic way?

get_update :: inline (old : $T, new : T) -> bool {
    return old != new;
}

apply_update :: inline (update : bool, source : $T, target : *T) {
    if update {
        target.* = source;
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
    center : Vector3_Update;
    radius : bool = false;
    is_active : bool = false;
}

get_update :: (old : Clip_Sphere, new : Clip_Sphere) -> Clip_Sphere_Update {
    result : Clip_Sphere_Update;

    result.center = get_update(old.center, new.center);
    result.radius = get_update(old.radius, new.radius);
    result.is_active = get_update(old.is_active, new.is_active);

    return result;
}

apply_update :: (update : Clip_Sphere_Update, source : Clip_Sphere, target : *Clip_Sphere) {
    apply_update(update.center, source.center, *target.center);
    apply_update(update.radius, source.radius, *target.radius);
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
    annotation_label_theme : Annotation_Theme_Update;
}

get_update :: (old : Vertex_Label_Theme, new : Vertex_Label_Theme) -> Vertex_Label_Theme_Update {
    result : Vertex_Label_Theme_Update;

    result.show_position = get_update(old.show_position, new.show_position);
    result.show_index =    get_update(old.show_index, new.show_index);
    result.label_scale =   get_update(old.label_scale, new.label_scale);
    result.label_color =   get_update(old.label_color, new.label_color);
    result.annotation_label_theme = get_update(old.annotation_label_theme, new.annotation_label_theme);

    return result;
}

apply_update :: (update : Vertex_Label_Theme_Update, source : Vertex_Label_Theme, target : *Vertex_Label_Theme) {
    apply_update(update.show_position, source.show_position, *target.show_position);
    apply_update(update.show_index, source.show_index, *target.show_index);
    apply_update(update.label_scale, source.label_scale, *target.label_scale);
    apply_update(update.label_color, source.label_color, *target.label_color);
    apply_update(update.annotation_label_theme, source.annotation_label_theme, *target.annotation_label_theme);
}

//
// Element_Label_Theme
//

Element_Label_Theme_Update :: struct {
    show_index : bool;
    label_scale : bool;
    label_color : Vector4_Update;
    annotation_label_theme : Annotation_Theme_Update;
}

get_update :: (old : Element_Label_Theme, new : Element_Label_Theme) -> Element_Label_Theme_Update {
    result : Element_Label_Theme_Update;

    result.show_index =    get_update(old.show_index, new.show_index);
    result.label_scale =   get_update(old.label_scale, new.label_scale);
    result.label_color =   get_update(old.label_color, new.label_color);
    result.annotation_label_theme = get_update(old.annotation_label_theme, new.annotation_label_theme);

    return result;
}

apply_update :: (update : Element_Label_Theme_Update, source : Element_Label_Theme, target : *Element_Label_Theme) {
    apply_update(update.show_index, source.show_index, *target.show_index);
    apply_update(update.label_scale, source.label_scale, *target.label_scale);
    apply_update(update.label_color, source.label_color, *target.label_color);
    apply_update(update.annotation_label_theme, source.annotation_label_theme, *target.annotation_label_theme);
}



//
// Annotation_Theme
//

Annotation_Theme_Update :: struct {
    visible : bool;
    label_scale : bool;
    label_color : Vector4_Update;
}

get_update :: (old : Annotation_Theme, new : Annotation_Theme) -> Annotation_Theme_Update {
    result : Annotation_Theme_Update;

    result.visible = get_update(old.visible, new.visible);
    result.label_scale = get_update(old.label_scale, new.label_scale);
    result.label_color = get_update(old.label_color, new.label_color);

    return result;
}

apply_update :: (update : Annotation_Theme_Update, source : Annotation_Theme, target : *Annotation_Theme) {
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
// Normal_Style
//

Normal_Style_Update :: struct {
    visible : bool;
    color : Vector4_Update;
    scale : bool;
}

get_update :: (old : Normal_Style, new : Normal_Style) -> Normal_Style_Update {
    result : Normal_Style_Update;

    result.visible = get_update(old.visible, new.visible);
    result.color = get_update(old.color, new.color);
    result.scale = get_update(old.scale, new.scale);

    return result;
}

apply_update :: (update : Normal_Style_Update, source : Normal_Style, target : *Normal_Style) {
    apply_update(update.visible, source.visible, *target.visible);
    apply_update(update.color, source.color, *target.color);
    apply_update(update.scale, source.scale, *target.scale);
}

//
// Edge_Style
//

Edge_Style_Update :: struct {
    visible : bool;
    color : Vector4_Update;
    width : bool;
}

get_update :: (old : Edge_Style, new : Edge_Style) -> Edge_Style_Update {
    result : Edge_Style_Update;

    result.visible = get_update(old.visible, new.visible);
    result.color = get_update(old.color, new.color);
    result.width = get_update(old.width, new.width);

    return result;
}

apply_update :: (update : Edge_Style_Update, source : Edge_Style, target : *Edge_Style) {
    apply_update(update.visible, source.visible, *target.visible);
    apply_update(update.color, source.color, *target.color);
    apply_update(update.width, source.width, *target.width);
}

//
// Vertex_Style
//

Vertex_Style_Update :: struct {
    visible : bool;
    color : Vector4_Update;
    color_mode : bool;
    size : bool;
}

get_update :: (old : Vertex_Style, new : Vertex_Style) -> Vertex_Style_Update {
    result : Vertex_Style_Update;

    result.visible = get_update(old.visible, new.visible);
    result.color = get_update(old.color, new.color);
    result.color_mode = get_update(old.color_mode, new.color_mode);
    result.size = get_update(old.size, new.size);

    return result;
}

apply_update :: (update : Vertex_Style_Update, source : Vertex_Style, target : *Vertex_Style) {
    apply_update(update.visible, source.visible, *target.visible);
    apply_update(update.color, source.color, *target.color);
    apply_update(update.color_mode, source.color_mode, *target.color_mode);
    apply_update(update.size, source.size, *target.size);
}

//
// Point_Style
//

Point_Style_Update :: struct {
    vertex_style : Vertex_Style_Update;
    normal_style : Normal_Style_Update;
}

get_update :: (old : Point_Style, new : Point_Style) -> Point_Style_Update {
    result : Point_Style_Update;

    result.vertex_style = get_update(old.vertex_style, new.vertex_style);
    result.normal_style = get_update(old.normal_style, new.normal_style);

    return result;
}

apply_update :: (update : Point_Style_Update, source : Point_Style, target : *Point_Style) {
    apply_update(update.vertex_style, source.vertex_style, *target.vertex_style);
    apply_update(update.normal_style, source.normal_style, *target.normal_style);
}

//
// Segment_Style
//

Segment_Style_Update :: struct {
    visible : bool;
    color : Vector4_Update;
    color_mode : bool;
    width : bool;
    normal_style : Normal_Style_Update;
}

get_update :: (old : Segment_Style, new : Segment_Style) -> Segment_Style_Update {
    result : Segment_Style_Update;

    result.visible = get_update(old.visible, new.visible);
    result.color = get_update(old.color, new.color);
    result.color_mode = get_update(old.color_mode, new.color_mode);
    result.width = get_update(old.width, new.width);
    result.normal_style = get_update(old.normal_style, new.normal_style);

    return result;
}

apply_update :: (update : Segment_Style_Update, source : Segment_Style, target : *Segment_Style) {
    apply_update(update.visible, source.visible, *target.visible);
    apply_update(update.color, source.color, *target.color);
    apply_update(update.color_mode, source.color_mode, *target.color_mode);
    apply_update(update.width, source.width, *target.width);
    apply_update(update.normal_style, source.normal_style, *target.normal_style);
}

//
// Triangle_Style
//

Triangle_Style_Update :: struct {
    visible : bool;
    color : Vector4_Update;
    display_mode : bool;
    backface_mode : bool;
    flat_shading : bool;
    edge_style : Edge_Style_Update;
    normal_style : Normal_Style_Update;
}

get_update :: (old : Triangle_Style, new : Triangle_Style) -> Triangle_Style_Update {
    result : Triangle_Style_Update;

    result.visible = get_update(old.visible, new.visible);
    result.color = get_update(old.color, new.color);
    result.display_mode = get_update(old.display_mode, new.display_mode);
    result.backface_mode = get_update(old.backface_mode, new.backface_mode);
    result.flat_shading = get_update(old.flat_shading, new.flat_shading);
    result.edge_style = get_update(old.edge_style, new.edge_style);
    result.normal_style = get_update(old.normal_style, new.normal_style);

    return result;
}

apply_update :: (update : Triangle_Style_Update, source : Triangle_Style, target : *Triangle_Style) {
    apply_update(update.visible, source.visible, *target.visible);
    apply_update(update.color, source.color, *target.color);
    apply_update(update.display_mode, source.display_mode, *target.display_mode);
    apply_update(update.backface_mode, source.backface_mode, *target.backface_mode);
    apply_update(update.flat_shading, source.flat_shading, *target.flat_shading);
    apply_update(update.edge_style, source.edge_style, *target.edge_style);
    apply_update(update.normal_style, source.normal_style, *target.normal_style);
}

//
// Display_Info
//

// @TODO Implment a compile-time check that the entries here match Display_Mode, use annotations to selectively ignore stuff
Display_Info_Update :: struct {

    is_visible : bool;

    vertex_label_theme : Vertex_Label_Theme_Update;
    point_label_theme : Element_Label_Theme_Update;
    segment_label_theme : Element_Label_Theme_Update;
    triangle_label_theme : Element_Label_Theme_Update;
    annotation_label_theme : Annotation_Theme_Update;

    vertex_style : Vertex_Style_Update;
    point_style : Point_Style_Update;
    segment_style : Segment_Style_Update;
    triangle_style : Triangle_Style_Update;

    clip_ranges : [3]Clip_Range_Update;
    clip_sphere : Clip_Sphere_Update;
}

get_update :: (old : Display_Info, new : Display_Info) -> Display_Info_Update {
    result : Display_Info_Update;

    result.is_visible = get_update(old.is_visible, new.is_visible);

    result.vertex_label_theme = get_update(old.vertex_label_theme, new.vertex_label_theme);
    result.point_label_theme = get_update(old.point_label_theme, new.point_label_theme);
    result.segment_label_theme = get_update(old.segment_label_theme, new.segment_label_theme);
    result.triangle_label_theme = get_update(old.triangle_label_theme, new.triangle_label_theme);

    result.vertex_style = get_update(old.vertex_style, new.vertex_style);
    result.point_style = get_update(old.point_style, new.point_style);
    result.segment_style = get_update(old.segment_style, new.segment_style);
    result.triangle_style = get_update(old.triangle_style, new.triangle_style);

    result.clip_ranges[0] = get_update(old.clip_ranges[0], new.clip_ranges[0]);
    result.clip_ranges[1] = get_update(old.clip_ranges[1], new.clip_ranges[1]);
    result.clip_ranges[2] = get_update(old.clip_ranges[2], new.clip_ranges[2]);
    result.clip_sphere = get_update(old.clip_sphere, new.clip_sphere);

    return result;
}

apply_update :: (update : Display_Info_Update, source : Display_Info, target : *Display_Info) {
    apply_update(update.is_visible, source.is_visible, *target.is_visible);

    apply_update(update.vertex_label_theme, source.vertex_label_theme, *target.vertex_label_theme);
    apply_update(update.point_label_theme, source.point_label_theme, *target.point_label_theme);
    apply_update(update.segment_label_theme, source.segment_label_theme, *target.segment_label_theme);
    apply_update(update.triangle_label_theme, source.triangle_label_theme, *target.triangle_label_theme);

    apply_update(update.vertex_style, source.vertex_style, *target.vertex_style);
    apply_update(update.point_style, source.point_style, *target.point_style);
    apply_update(update.segment_style, source.segment_style, *target.segment_style);
    apply_update(update.triangle_style, source.triangle_style, *target.triangle_style);

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