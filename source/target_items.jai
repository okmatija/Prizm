Fraction :: struct {
    numer : int;
    denom : int;
}

operator== :: (a : Fraction, b : Fraction) -> bool {
    return a.numer == b.numer && a.denom == b.denom;
}


// Actions cycle/toggle item state
Action_Set :: struct {
    using keymap_proc : Keymap_Proc_Info;
    using mapping : Single_Key_Mapping;

    // Returns a fraction representing the progress of the state toggling/cycling
    query_progress : (info : Display_Info) -> Fraction;
}

// @Cleanup decapitalize non-constant action sets

TOGGLE_CLIPPING_ACTION_SET := Action_Set.{
    proc=update_clipping,
    name="Toggle clipping",
    key_code=#char "c",
    query_progress=query_progress_clipping,
};

CYCLE_VERTEX_SIZE_ACTION_SET := Action_Set.{
    proc=update_vertex_size,
    name="Cycle vertex radius",
    key_code=#char "v",
    query_progress=query_progress_vertex_size,
};

CYCLE_LINE_WIDTH_ACTION_SET := Action_Set.{
    proc=update_thickness,
    name="Cycle line thickness",
    key_code=#char "l",
    query_progress=query_progress_thickness,
};

TOGGLE_NORMALS_ACTION_SET := Action_Set.{
    proc=update_normals,
    name="Toggle normals",
    key_code=#char "n",
    query_progress=query_progress_normals,
};

CYCLE_VERTEX_LABEL_ACTION_SET := Action_Set.{
    proc=update_vertex_labels,
    name="Cycle vertex labels",
    key_code=#char "x",
    query_progress=query_progress_vertex_labels,
};

CYCLE_ELEMENT_LABEL_ACTION_SET := Action_Set.{
    proc=update_element_labels,
    name="Toggle point/segment/triangle labels",
    key_code=#char "i",
    query_progress=query_progress_element_labels,
};

CYCLE_ANNOTATION_LABEL_ACTION_SET := Action_Set.{
    proc=update_annotation_labels,
    name="Toggle annotations",
    key_code=#char "a",
    query_progress=query_progress_annotation_labels,
};

CYCLE_OPACITY_ACTION_SET := Action_Set.{
    proc=update_opacity,
    name="Cycle opacity",
    key_code=#char "o",
    query_progress=query_progress_opacity,
};

CYCLE_BACKFACE_MODE_ACTION_SET := Action_Set.{
    proc=update_backface_mode,
    name="Cycle backface rendering mode",
    key_code=#char "b",
    query_progress=query_progress_backface_mode,
};


// @TODO Add some visual feedback for when an item has state updated?

#scope_file


Cycle_Display_Info_Proc :: #type (state : *Display_Info) -> Fraction;

Apply_Display_Info_Proc :: #type (from : Display_Info, onto : *Display_Info) -> ();

update_display_info :: (cycle : Cycle_Display_Info_Proc, apply : Apply_Display_Info_Proc) {

    selected : [..]*Entity = temp_selected_entities();

    display_info : *Display_Info;
    if selected.count == 1 {
        display_info = *selected[0].display_info;
        cycle(display_info);
    } else if selected.count > 1 { 
        display_info = *app.template_display_info;
        cycle(display_info);
    }

    for selected {
        apply(display_info.*, *it.display_info);
    }
}


//
// Toggle clipping
//


cycle_clipping :: (using display_info : *Display_Info) -> Fraction {
    // Start with the triangle normal visibility 
    active : bool = clip_sphere.is_active;

    result : Fraction;
    result.numer = cast(int)active;
    result.denom = 1;

    // Toggle the normals on all elements with normals
    clip_sphere.is_active = !active;
    for * clip_ranges {
        it.is_active = !active;
    }

    return result;
}

apply_clipping_update :: (from : Display_Info, to : *Display_Info) {
    to.clip_sphere.is_active = from.clip_sphere.is_active;
    for i : 0..to.clip_ranges.count-1 {
        to.clip_ranges[i].is_active = from.clip_ranges[i].is_active;
    }
}

update_clipping :: () {
    update_display_info(cycle_clipping, apply_clipping_update);
}

query_progress_clipping :: (info : Display_Info) -> Fraction {
    info_copy : Display_Info = info;
    return cycle_clipping(*info_copy);
}






//
// Cycle vertex/position size
//


cycle_vertex_size :: (using display_info : *Display_Info) -> Fraction {
    // Handle full range of points_size
    if !vertex_style.visible {
        vertex_style.visible = true;
        vertex_style.size = 2;
        return .{0,3};
    } else if vertex_style.size <= 2 {
        vertex_style.size = 4;
        return .{1,3};
    } else if vertex_style.size <= 4 {
        vertex_style.size = 6;
        return .{2,3};
    } else {
        vertex_style.visible = false;
        return .{3,3};
    }
}

apply_vertex_size :: (from : Display_Info, to : *Display_Info) {
    to.vertex_style.visible = from.vertex_style.visible;
    to.vertex_style.size    = from.vertex_style.size;
    // We could set point size to vertex size since they are rendered at the same position but this doesn't really feel good...
    //to.point_style.size     = from.vertex_style.size;
    // ... We shouldn't change point visibility though since doing that can make point cloud shapes entirely disappear which is bad.
    //to.point_style.visible  = from.vertex_style.visible;
}

update_vertex_size :: () {
    update_display_info(cycle_vertex_size, apply_vertex_size);
}

query_progress_vertex_size :: (info : Display_Info) -> Fraction {
    info_copy : Display_Info = info;
    return cycle_vertex_size(*info_copy);
}




//
// Cycle wireframe width
//


cycle_thickness :: (using display_info : *Display_Info) -> Fraction {
    // We need to use edges_* rather than segments_* in the if conditions because segment visibility doesn't change in the else so the cycling would get stuck after we reach the else for first time
    if !triangle_style.edge_style.visible {
        segment_style.visible = true;
        segment_style.width = 1;
        triangle_style.edge_style.visible = true; // May as well let the cycling shortcut turn this on
        triangle_style.edge_style.width = 1;
        return .{0,3};
    } else if triangle_style.edge_style.width <= 1 {
        segment_style.width = 2;
        triangle_style.edge_style.width = 2;
        return .{1,3};
    } else if triangle_style.edge_style.width <= 2 {
        segment_style.width = 3;
        triangle_style.edge_style.width = 3;
        return .{2,3};
    } else {
        // segment_style.visible = false; // Intentionally leave segments visible, we don't want the cycling shortcut to affect visiblity of segments (because then that geometry totally disappears---which is not the case when you turn off visibility for triangle edges)
        segment_style.width = 1; // Duplicate the default state, it just feels better doing this
        triangle_style.edge_style.visible = false;
        return .{3,3};
    }
}

apply_thickness :: (from : Display_Info, to : *Display_Info) {
    to.segment_style.visible             = from.segment_style.visible;
    to.segment_style.width               = from.segment_style.width;
    to.triangle_style.edge_style.visible = from.triangle_style.edge_style.visible;
    to.triangle_style.edge_style.width   = from.triangle_style.edge_style.width;
}

update_thickness :: () {
    update_display_info(cycle_thickness, apply_thickness);
}

query_progress_thickness :: (info : Display_Info) -> Fraction {
    info_copy : Display_Info = info;
    return cycle_thickness(*info_copy);
}






//
// Toggle normals visibility
//

cycle_normals :: (using display_info : *Display_Info) -> Fraction {
    // Start with the triangle normal visibility 
    normals_visible : bool = triangle_style.normal_style.visible;

    result : Fraction;
    result.numer = xx normals_visible;
    result.denom = 1;

    // Toggle the normals on all elements with normals
    triangle_style.normal_style.visible = !normals_visible;
    segment_style.normal_style.visible = !normals_visible;
    point_style.normal_style.visible = !normals_visible;

    return result;
}

apply_normals :: (from : Display_Info, to : *Display_Info) {
    to.triangle_style.normal_style.visible = from.triangle_style.normal_style.visible;
    to.segment_style.normal_style.visible  = from.segment_style.normal_style.visible;
    to.point_style.normal_style.visible    = from.point_style.normal_style.visible;
}

update_normals :: () {
    update_display_info(cycle_normals, apply_normals);
}

query_progress_normals :: (info : Display_Info) -> Fraction {
    info_copy := info;
    return cycle_normals(*info_copy);
}







//
// Cycle vertex labels
//

cycle_vertex_labels :: (display_info : *Display_Info) -> Fraction {
    using display_info.vertex_label_theme;

    result : Fraction;
    result.denom = 3;

    State :: enum {
        INDEX_OFF_POSITION_OFF :: 0b00;
        INDEX_ON_POSITION_OFF ::  0b01;
        INDEX_OFF_POSITION_ON ::  0b10;
        INDEX_ON_POSITION_ON ::   0b11;
    }

    // Get State from theme
    state : State = cast(State)(cast(int)show_index + 2 * cast(int)show_position);

    // Cycle State (always add/remove one bit of text)
    if #complete state == {
        case .INDEX_OFF_POSITION_OFF; result.numer = 0; state = .INDEX_ON_POSITION_OFF;
        case .INDEX_ON_POSITION_OFF;  result.numer = 1; state = .INDEX_ON_POSITION_ON;
        case .INDEX_ON_POSITION_ON;   result.numer = 2; state = .INDEX_OFF_POSITION_ON;
        case .INDEX_OFF_POSITION_ON;  result.numer = 3; state = .INDEX_OFF_POSITION_OFF;
    }

    // Set theme from State
    show_index, show_position = cast(bool)(cast(int)state & 0b01), cast(bool)(cast(int)state & 0b10);

    return result;
}

apply_vertex_labels :: (from : Display_Info, to : *Display_Info) {
    to.vertex_label_theme.show_position = from.vertex_label_theme.show_position;
    to.vertex_label_theme.show_index    = from.vertex_label_theme.show_index;
}

update_vertex_labels :: () {
    update_display_info(cycle_vertex_labels, apply_vertex_labels);
}

query_progress_vertex_labels :: (info : Display_Info) -> Fraction {
    info_copy := info;
    return cycle_vertex_labels(*info_copy);
}





//
// Cycle element/face labels
//


cycle_element_labels :: (display_info : *Display_Info) -> Fraction {
    using display_info.point_label_theme;

    result : Fraction;
    result.denom = 1;

    State :: enum {
        OFF :: 0b00;
        ON ::  0b01;
    }

    // Get State from theme
    state : State = cast(State)show_index;

    // Cycle State (always add/remove one bit of text)
    if #complete state == {
        case .OFF; result.numer = 0; state = .ON;
        case .ON;  result.numer = 1; state = .OFF;
    }

    // Set theme from State
    show_index = cast(bool)(cast(int)state & 0b01);

    return result;
}

apply_element_labels :: (from : Display_Info, to : *Display_Info) {
    show_index := from.point_label_theme.show_index;
    to.point_label_theme.show_index    = show_index;
    to.segment_label_theme.show_index  = show_index;
    to.triangle_label_theme.show_index = show_index;
}

update_element_labels :: () {
    update_display_info(cycle_element_labels, apply_element_labels);
}

query_progress_element_labels :: (info : Display_Info) -> Fraction {
    info_copy := info;
    return cycle_element_labels(*info_copy);
}






//
// Cycle annotation labels
//


// This currently only toggles visibility but it could cycle through styles?
cycle_annotation_labels :: (display_info : *Display_Info) -> Fraction {
    theme : *Annotation_Theme = *display_info.vertex_label_theme.annotation_label_theme;

    result : Fraction;
    result.denom = 1;

    State :: enum {
        OFF :: 0b00;
        ON ::  0b01;
    }

    // Get State from theme
    state : State = xx theme.visible;

    // Cycle State (always add/remove one bit of text)
    if #complete state == {
        case .OFF; result.numer = 0; state = .ON;
        case .ON;  result.numer = 1; state = .OFF;
    }

    // Set theme from State
    theme.visible = cast(bool)(state & 0b01);

    return result;
}

apply_annotation_labels :: (from : Display_Info, to : *Display_Info) {
    visible := from.vertex_label_theme.annotation_label_theme.visible;
    to.vertex_label_theme.annotation_label_theme.visible   = visible;
    to.point_label_theme.annotation_label_theme.visible    = visible;
    to.segment_label_theme.annotation_label_theme.visible  = visible;
    to.triangle_label_theme.annotation_label_theme.visible = visible;
}

update_annotation_labels :: () {
    update_display_info(cycle_annotation_labels, apply_annotation_labels);
}

query_progress_annotation_labels :: (info : Display_Info) -> Fraction {
    info_copy : Display_Info = info;
    return cycle_annotation_labels(*info_copy);
}




//
// Cycle opacity @Think should this apply to elements other than triangles as well? Maybe when we make point/segment elements into quads
//

cycle_opacity :: (using display_info : *Display_Info) -> Fraction {
    if triangle_style.color.w == 1.  {
        triangle_style.color.w = .5;
        return .{0, 2};
    } else if triangle_style.color.w >= .5 {
        triangle_style.color.w = .2;
        return .{1, 2};
    } else {
        triangle_style.color.w = 1.;
        return .{2, 2};
    }
}

apply_opacity :: (from : Display_Info, to : *Display_Info) {
    to.triangle_style.color.w = from.triangle_style.color.w;
}

update_opacity :: () {
    update_display_info(cycle_opacity, apply_opacity);
}

query_progress_opacity :: (info : Display_Info) -> Fraction {
    info_copy : Display_Info = info;
    return cycle_opacity(*info_copy);
}






//
// Cycle backface mode
//

cycle_backface_mode :: (display_info : *Display_Info) -> Fraction {
    mode : *Backface_Mode = *display_info.triangle_style.backface_mode;
    result : Fraction;
    result.denom = 5;
    if #complete mode.* == {
        case .FIXED;        result.numer = 0; mode.* = .DARKEN; 
        case .DARKEN;       result.numer = 1; mode.* = .SCREENTONE_1;
        case .SCREENTONE_1; result.numer = 2; mode.* = .SCREENTONE_2;
        case .SCREENTONE_2; result.numer = 3; mode.* = .NONE;
        case .NONE;         result.numer = 4; mode.* = .FIXED;
    }
    return result;
}

apply_backface_mode :: (from : Display_Info, to : *Display_Info) {
    to.triangle_style.backface_mode = from.triangle_style.backface_mode;
}

update_backface_mode :: () {
    update_display_info(cycle_backface_mode, apply_backface_mode);
}

query_progress_backface_mode :: (info : Display_Info) -> Fraction {
    info_copy : Display_Info = info;
    return cycle_backface_mode(*info_copy);
}