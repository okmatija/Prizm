Fraction :: struct {
    numer : int;
    denom : int;
}

Action_Set :: struct {
    proc : (data : *void)->();

    // Actions cycle/toggle item state, this function returns a fraction representing the progress of the state cycling so you can e.g., change the color of the action buttons according to how far along the cycle you are
    progress_proc : ()->Fraction = ()=>Fraction.{0,0};

    desc : string;
    key : u32;
    regular_button := false; // If true a simple ImGui.Button, otherwise a button which cycles/toggles state and changes color accordingly
    override_WantCaptureKeyboard := false;

    //
    // Transient data
    //
    
    last_interaction_time : Apollo_Time;
    hovered_duration_secs : float; // @Cleanup When switching to ImGui 1.88 which natively supports timed tooltips
}

//
// Toggle clipping
//

any_active_clipping :: () -> bool {
    clip_active := false;
    for :Selected app.entities {
        if it.display_info.clip_sphere.is_active {
            clip_active = true;
            break;
        }
        for it.display_info.clip_ranges if it.is_active {
            clip_active = true;
            break;
        }
    }
    return clip_active;
}

toggle_clipping :: () {

    clip_active := *app.template_display_info.clip_sphere.is_active;
    <<clip_active = !<<clip_active;

    for :Selected app.entities {
        it.display_info.clip_sphere.is_active = <<clip_active;
        for * it.display_info.clip_ranges {
            it.is_active = <<clip_active;
        }
    }
}

toggle_clipping_proc :: (last_interaction_time : *void) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    toggle_clipping();
}


toggle_clipping_progress_proc :: () -> Fraction {
    if any_active_clipping() {
        return .{1,1};
    }
    return .{0,1};
}

TOGGLE_CLIPPING_ACTION_SET := Action_Set.{
    proc=toggle_clipping_proc,
    progress_proc=()=>toggle_clipping_progress_proc(),
    desc="Toggle clipping on selected items",
    key=#char "c",
};





//
// Cycle vertex/position size
//

cycle_vertex_size :: () {

    app_info := *app.template_display_info;
    cycle_vertex_size_progress_proc(app_info);

    for :Selected app.entities {
        it.display_info.positions_visible = app_info.positions_visible;
        it.display_info.positions_size    = app_info.positions_size;
    }
}

cycle_vertex_size_proc :: (last_interaction_time : *void) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_vertex_size();
}


cycle_vertex_size_progress_proc :: (using app_info : *Display_Info) -> Fraction {
    // Handle full range of points_size
    if !positions_visible {
        positions_visible = true;
        positions_size = 2;
        return .{0,3};
    } else if positions_size <= 2 {
        positions_size = 4;
        return .{1,3};
    } else if positions_size <= 4 {
        positions_size = 6;
        return .{2,3};
    } else {
        positions_visible = false;
        return .{3,3};
    }
}

cycle_vertex_size_progress_proc_const :: () -> Fraction {
    app_info_copy := app.template_display_info;
    return cycle_vertex_size_progress_proc(*app_info_copy);
}


CYCLE_VERTEX_SIZE_ACTION_SET := Action_Set.{
    proc=cycle_vertex_size_proc,
    progress_proc=cycle_vertex_size_progress_proc_const,
    desc="Cycle vertex/positions size for selected items",
    key=#char "v",
};






//
// Cycle wireframe width
//

cycle_wireframe_width :: () {

    app_info := *app.template_display_info;
    cycle_wireframe_width_progress_proc(app_info);

    for :Selected app.entities {
        it.display_info.segments_visible = app_info.segments_visible;
        it.display_info.segments_width   = app_info.segments_width;
        it.display_info.edges_visible = app_info.edges_visible;
        it.display_info.edges_width   = app_info.edges_width;
    }
}

// @Cleanup could auto generate this
cycle_wireframe_width_proc :: (last_interaction_time : *void) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_wireframe_width();
}

cycle_wireframe_width_progress_proc :: (using app_info : *Display_Info) -> Fraction {

    // We need to use edges_* rather than segments_* in the if conditions because segment visibility doesn't change in the else so the cycling would get stuck after we reach the else for first time
    if !edges_visible {
        segments_visible = true;
        segments_width = 1;
        edges_visible = true; // May as well let the cycling shortcut turn this on
        edges_width = 1;
        return .{0,3};
    } else if edges_width <= 1 {
        segments_width = 2;
        edges_width = 2;
        return .{1,3};
    } else if edges_width <= 2 {
        segments_width = 3;
        edges_width = 3;
        return .{2,3};
    } else {
        // segments_visible = false; // Intentionally leave segments visible, we don't want the cycling shortcut to affect visiblity of segments
        segments_width = 1; // Duplicate the default state, it just feels better doing this
        edges_visible = false;
        return .{3,3};
    }
}

cycle_wireframe_width_progress_proc_const :: () -> Fraction {
    app_info_copy := app.template_display_info;
    return cycle_wireframe_width_progress_proc(*app_info_copy);
}

CYCLE_LINE_WIDTH_ACTION_SET := Action_Set.{
    proc=cycle_wireframe_width_proc,
    progress_proc=cycle_wireframe_width_progress_proc_const,
    desc="Cycle line width (triangle edges and segments) for selected items",
    key=#char "l",
};



//
// Toggle normals visibility
//


toggle_normals_visibility :: () {

    app_info := *app.template_display_info;
    toggle_normals_visibility_progress_proc(app_info);

    for :Selected app.entities {
        it.display_info.normals_visible = app_info.normals_visible;
    }
}

toggle_normals_visibility_proc :: (last_interaction_time : *void) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    toggle_normals_visibility();
}

toggle_normals_visibility_progress_proc :: (using app_info : *Display_Info) -> Fraction {
    result : Fraction;
    result.numer = xx normals_visible;
    result.denom = 1;
    normals_visible = !normals_visible;
    return result;
}


toggle_normals_visibility_progress_proc_const :: () -> Fraction {
    app_info_copy := app.template_display_info;
    return toggle_normals_visibility_progress_proc(*app_info_copy);
}

TOGGLE_NORMALS_ACTION_SET := Action_Set.{
    proc=toggle_normals_visibility_proc,
    progress_proc=toggle_normals_visibility_progress_proc_const,
    desc="Toggle normals visibility for selected items",
    key=#char "n",
};





//
// Cycle vertex labels
//

cycle_vertex_label_theme :: (theme : *Vertex_Label_Theme) -> Fraction {

    result : Fraction;
    result.denom = 3;

    State :: enum {
        INDEX_OFF_POSITION_OFF :: 0b00;
        INDEX_ON_POSITION_OFF ::  0b01;
        INDEX_OFF_POSITION_ON ::  0b10;
        INDEX_ON_POSITION_ON ::   0b11;
    }

    // Get State from theme
    state : State = xx (xx theme.show_index + 2 * xx theme.show_position);

    // Cycle State (always add/remove one bit of text)
    if #complete state == {
        case .INDEX_OFF_POSITION_OFF; result.numer = 0; state = .INDEX_ON_POSITION_OFF;
        case .INDEX_ON_POSITION_OFF;  result.numer = 1; state = .INDEX_ON_POSITION_ON;
        case .INDEX_ON_POSITION_ON;   result.numer = 2; state = .INDEX_OFF_POSITION_ON;
        case .INDEX_OFF_POSITION_ON;  result.numer = 3; state = .INDEX_OFF_POSITION_OFF;
    }

    // Set theme from State
    theme.show_index, theme.show_position = (xx state & 0b01), (xx state & 0b10);
    return result;
}

cycle_vertex_label :: () {

    theme := *app.template_display_info.vertex_label_theme;
    cycle_vertex_label_theme(theme);

    for :Selected app.entities {
        it.display_info.vertex_label_theme.show_position = theme.show_position;
        it.display_info.vertex_label_theme.show_index = theme.show_index;
    }
}


cycle_vertex_label_proc :: (last_interaction_time : *void) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_vertex_label();
}


cycle_vertex_label_progress_proc :: () -> Fraction {
    app_info_copy := app.template_display_info; // We just want to get the fraction, not modify the display info
    return cycle_vertex_label_theme(*app_info_copy.vertex_label_theme);
}

// @Cleanup decapitalize non-constant action sets

CYCLE_VERTEX_LABEL_ACTION_SET := Action_Set.{
    proc=cycle_vertex_label_proc,
    progress_proc=()=>cycle_vertex_label_progress_proc(),
    desc="Cycle vertex labels for selected items",
    key=#char "j",
};





//
// Cycle element/face labels
//


cycle_element_label_theme :: (theme : *Element_Label_Theme) -> Fraction {

    result : Fraction;
    result.denom = 1;

    State :: enum {
        OFF :: 0b00;
        ON ::  0b01;
    }

    // Get State from theme
    state : State = xx theme.show_index;

    // Cycle State (always add/remove one bit of text)
    if #complete state == {
        case .OFF; result.numer = 0; state = .ON;
        case .ON;  result.numer = 1; state = .OFF;
    }

    // Set theme from State
    theme.show_index = xx state & 0b01;
    return result;
}

cycle_element_label :: () {
    // All element types are kept in sync with the point one
    theme := *app.template_display_info.point_label_theme;
    cycle_element_label_theme(theme);

    for :Selected app.entities {
        it.display_info.point_label_theme.show_index = theme.show_index;
        it.display_info.segment_label_theme.show_index = theme.show_index;
        it.display_info.triangle_label_theme.show_index = theme.show_index;
    }
}

cycle_element_label_proc :: (last_interaction_time : *void) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_element_label();
}

cycle_element_label_progress_proc :: () -> Fraction {
    app_info_copy := app.template_display_info; // We just want to get the fraction, not modify the display info
    return cycle_element_label_theme(*app_info_copy.point_label_theme);
}

CYCLE_ELEMENT_LABEL_ACTION_SET := Action_Set.{
    proc=cycle_element_label_proc,
    progress_proc=()=>cycle_element_label_progress_proc(),
    desc="Toggle point/segment/triangle labels for selected items",
    key=#char "i",
};






//
// Cycle annotation labels
//


cycle_annotation_theme :: (theme : *Annotation_Label_Theme) -> Fraction {

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
    theme.visible = xx state & 0b01;
    return result;
}

cycle_annotation :: () {
    theme := *app.template_display_info.annotation_label_theme;

    cycle_annotation_theme(theme);

    for :Selected app.entities {
        it.display_info.annotation_label_theme.visible = theme.visible;
    }
}

cycle_annotation_proc :: (last_interaction_time : *void) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_annotation();
}

cycle_annotation_progress_proc :: () -> Fraction {
    app_info_copy := app.template_display_info;
    return cycle_annotation_theme(*app_info_copy.annotation_label_theme);
}

CYCLE_ANNOTATION_ACTION_SET := Action_Set.{
    proc=cycle_annotation_proc,
    progress_proc=cycle_annotation_progress_proc,
    desc="Toggle annotations for selected items",
    key=#char "k",
};





//
// Cycle opacity
//

cycle_opacity :: () {

    app_info := *app.template_display_info;
    cycle_opacity_progress_proc(app_info);

    for :Selected app.entities {
        it.display_info.triangles_color.w = app_info.triangles_color.w;
    }
}

cycle_opacity_proc :: (last_interaction_time : *void) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_opacity();
}

cycle_opacity_progress_proc :: (using app_info : *Display_Info) -> Fraction {
    if triangles_color.w == 1.  {
        triangles_color.w = .5;
        return .{0, 2};
    } else if triangles_color.w >= .5 {
        triangles_color.w = .2;
        return .{1, 2};
    } else {
        triangles_color.w = 1.;
        return .{2, 2};
    }
}

cycle_opacity_progress_proc_const :: () -> Fraction {
    app_info_copy := app.template_display_info;
    return cycle_opacity_progress_proc(*app_info_copy);
}

CYCLE_OPACITY_ACTION_SET := Action_Set.{
    proc=cycle_opacity_proc,
    progress_proc=cycle_opacity_progress_proc_const,
    desc="Cycle opacity for selected items",
    key=#char "o",
};





//
// Cycle backface mode
//

cycle_backface_mode :: () {

    mode := *app.template_display_info.backface_mode;
    cycle_backface_mode_progress_proc(mode);

    for :Selected app.entities {
        it.display_info.backface_mode = <<mode;
    }
}

cycle_backface_mode_proc :: (last_interaction_time : *void) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_backface_mode();
}

cycle_backface_mode_progress_proc :: (using mode : *Backface_Mode) -> Fraction {
    result : Fraction;
    result.denom = 5;
    if #complete <<mode == {
        case .FIXED;        result.numer = 0; <<mode = .DARKEN; 
        case .DARKEN;       result.numer = 1; <<mode = .SCREENTONE_1;
        case .SCREENTONE_1; result.numer = 2; <<mode = .SCREENTONE_2;
        case .SCREENTONE_2; result.numer = 3; <<mode = .NONE;
        case .NONE;         result.numer = 4; <<mode = .CULL;
        case .CULL;         result.numer = 5; <<mode = .FIXED;
    }
    return result;
}

cycle_backface_mode_progress_proc_const :: () -> Fraction {
    app_info_copy := app.template_display_info;
    return cycle_backface_mode_progress_proc(*app_info_copy.backface_mode);
}

CYCLE_BACKFACE_MODE_ACTION_SET := Action_Set.{
    proc=cycle_backface_mode_proc,
    progress_proc=cycle_backface_mode_progress_proc_const,
    desc="Cycle backface rendering mode for selected items",
    key=#char "b",
};






//
// Reload items
//

reload_items_proc :: (unused : *void) {

    no_dependencies_first_then_chronological :: (a : *Entity, b : *Entity) -> s64 {
        // FILE_ON_DISK and PRESET_SHAPE sources do not depend on other entities, but command outputs can, so we load those last and in order of 
        if a.source.kind > b.source.kind return  1;
        if a.source.kind < b.source.kind return -1;
        assert(a.source.kind == b.source.kind);
        if get_entity_source(a).creation_time > get_entity_source(b).creation_time return  1;
        if get_entity_source(a).creation_time < get_entity_source(b).creation_time return -1;
        return 0;
    }

    tmp : [..]*Entity;
    array_copy(*tmp, app.entities);
    defer array_free(tmp);
    quick_sort(tmp, no_dependencies_first_then_chronological);

    for :Selected tmp {
        reload_entity(it);
    }
}

RELOAD_ITEMS_ACTION_SET := Action_Set.{
    proc=reload_items_proc,
    desc="Reload selected items",
    key=cast(u32) Special_Key_Code.F5,
    regular_button=true,
    override_WantCaptureKeyboard=true,
};





//
// Focus items
//


// @Volatile :FocusItemBehavior Sync with focus button
focus_items_proc :: (unused : *void) {

    almost_equal :: (a : Camera, b : Camera) -> bool {
        return
            almost_equal(a.eye_position, b.eye_position) &&
            almost_equal(a.look_position, b.look_position) &&
            almost_equal(a.up_direction, b.up_direction) &&
            almost_equal(a.left, b.left) &&
            almost_equal(a.right, b.right) &&
            almost_equal(a.bottom, b.bottom) &&
            almost_equal(a.top, b.top) &&
            almost_equal(a.near, b.near) &&
            almost_equal(a.far, b.far);
    }

    prev_camera := app.camera;

    fit_on_screen(visit_visible_selected);

    // Not a exactly equal check becuase I think there is a feedback mechanism when the camera is computed from the sphere where we essentially have an operation like `camera = f(sphere, camera)` which with the "same" inputs the camera would change a bit FIXME There is still some bug here: load a lot of items and select all of them, the fit_on_screen and fit_on_screen_filled should give the same results but they are slightly different
    if almost_equal(app.camera, prev_camera) {
        fit_on_screen_filled(visit_visible_selected);
    }
}

FOCUS_ITEMS_ACTION_SET := Action_Set.{
    proc=focus_items_proc,
    desc="Focus camera on selected items",
    key=#char "f",
    regular_button=true,
};





//
// Clear labels
//

clear_all_labels_proc :: (unused : *void) {
    for :Selected app.entities {
        it.display_info.vertex_label_theme.show_index = false;
        it.display_info.vertex_label_theme.show_position = false;
        it.display_info.point_label_theme.show_index = false;
        it.display_info.segment_label_theme.show_index = false;
        it.display_info.triangle_label_theme.show_index = false;
        it.display_info.annotation_label_theme.visible = false;
    }

    // Also clear the display info used to set action button state
    display_info : *Display_Info = *app.template_display_info;
    display_info.vertex_label_theme.show_index = false;
    display_info.vertex_label_theme.show_position = false;
    display_info.point_label_theme.show_index = false;
    display_info.segment_label_theme.show_index = false;
    display_info.triangle_label_theme.show_index = false;
    display_info.annotation_label_theme.visible = false;
}


// Note: no action button
CLEAR_LABELS_ACTION_SET :: Action_Set.{
    proc=clear_all_labels_proc,
    desc="Clear labels for selected items",
    key=#char "x"
};
