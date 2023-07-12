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

// @Cleanup decapitalize non-constant action sets

// Note: no action button
CLEAR_LABELS_ACTION_SET :: Action_Set.{
    proc=clear_all_labels_proc,
    desc="Clear labels for selected items",
    key=#char "x"
};

TOGGLE_CLIPPING_ACTION_SET := Action_Set.{
    proc=toggle_clipping_proc,
    progress_proc=()=>toggle_clipping_progress_proc(),
    desc="Toggle clipping on selected items",
    key=#char "c",
};

CYCLE_VERTEX_SIZE_ACTION_SET := Action_Set.{
    proc=cycle_vertex_size_proc,
    progress_proc=cycle_vertex_size_progress_proc_const,
    desc="Cycle vertex/positions size for selected items",
    key=#char "v",
};

CYCLE_LINE_WIDTH_ACTION_SET := Action_Set.{
    proc=cycle_wireframe_width_proc,
    progress_proc=cycle_wireframe_width_progress_proc_const,
    desc="Cycle line width (triangle edges and segments) for selected items",
    key=#char "l",
};

TOGGLE_NORMALS_ACTION_SET := Action_Set.{
    proc=toggle_normals_visibility_proc,
    progress_proc=toggle_normals_visibility_progress_proc_const,
    desc="Toggle normals visibility for selected items",
    key=#char "n",
};

CYCLE_VERTEX_LABEL_ACTION_SET := Action_Set.{
    proc=cycle_vertex_label_proc,
    progress_proc=()=>cycle_vertex_label_progress_proc(),
    desc="Cycle vertex labels for selected items",
    key=#char "j",
};

CYCLE_ELEMENT_LABEL_ACTION_SET := Action_Set.{
    proc=cycle_element_label_proc,
    progress_proc=()=>cycle_element_label_progress_proc(),
    desc="Toggle point/segment/triangle labels for selected items",
    key=#char "i",
};

CYCLE_OPACITY_ACTION_SET := Action_Set.{
    proc=cycle_opacity_proc,
    progress_proc=cycle_opacity_progress_proc_const,
    desc="Cycle opacity for selected items",
    key=#char "o",
};

CYCLE_ANNOTATION_ACTION_SET := Action_Set.{
    proc=cycle_annotation_proc,
    progress_proc=cycle_annotation_progress_proc,
    desc="Toggle annotations for selected items",
    key=#char "k",
};

CYCLE_BACKFACE_MODE_ACTION_SET := Action_Set.{
    proc=cycle_backface_mode_proc,
    progress_proc=cycle_backface_mode_progress_proc_const,
    desc="Cycle backface rendering mode for selected items",
    key=#char "b",
};

RELOAD_ITEMS_ACTION_SET := Action_Set.{
    proc=reload_items_proc,
    desc="Reload selected items",
    key=cast(u32) Special_Key_Code.F5,
    regular_button=true,
    override_WantCaptureKeyboard=true,
};

FOCUS_ITEMS_ACTION_SET := Action_Set.{
    proc=focus_items_proc,
    desc="Focus camera on selected items",
    key=#char "f",
    regular_button=true,
};

// @TODO Add some visual feedback for when an item has state updated?

#scope_file

//
// Toggle clipping
//

// @FIXME This does not cycle as expected since template state is always cycled even with no selection and when one item is selected the template changes

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





//
// Cycle vertex/position size
//

get_display_info :: () -> *Display_Info, int {
    selected : [..]*Entity = temp_selected_entities();

    info : *Display_Info = *app.template_display_info;

    // Don't modify template state if exactly one item is selected
    if selected.count == 1 {
        info = *selected[0].display_info;
    }

    return info, selected.count;
}

maybe_cycle_state :: (progress_proc : (*Display_Info) -> Fraction) -> *Display_Info {

    app_info, selected_count : /*Display_Info, int*/ = get_display_info();

     // We dont want to change the template state if nothing will change
    if selected_count > 0 {
        progress_proc(app_info);
    }

    return app_info;
}


cycle_vertex_size :: () {

    app_info : *Display_Info = maybe_cycle_state(cycle_vertex_size_progress_proc);

    for :Selected app.entities {
        it.display_info.vertex_style.visible = app_info.vertex_style.visible;
        it.display_info.vertex_style.size    = app_info.vertex_style.size;
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

cycle_vertex_size_progress_proc_const :: () -> Fraction {
    app_info, selected_count := get_display_info();
    app_info_copy := <<app_info;
    return cycle_vertex_size_progress_proc(*app_info_copy);
}





//
// Cycle wireframe width
//

cycle_wireframe_width :: () {

    app_info : *Display_Info = maybe_cycle_state(cycle_wireframe_width_progress_proc);

    for :Selected app.entities {
        it.display_info.segment_style.visible = app_info.segment_style.visible;
        it.display_info.segment_style.width   = app_info.segment_style.width;
        it.display_info.triangle_style.edge_style.visible = app_info.triangle_style.edge_style.visible;
        it.display_info.triangle_style.edge_style.width   = app_info.triangle_style.edge_style.width;
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
        // segment_style.visible = false; // Intentionally leave segments visible, we don't want the cycling shortcut to affect visiblity of segments
        segment_style.width = 1; // Duplicate the default state, it just feels better doing this
        triangle_style.edge_style.visible = false;
        return .{3,3};
    }
}

cycle_wireframe_width_progress_proc_const :: () -> Fraction {
    app_info, selected_count := get_display_info();
    app_info_copy := <<app_info;
    return cycle_wireframe_width_progress_proc(*app_info_copy);
}



//
// Toggle normals visibility
//


toggle_normals_visibility :: () {

    app_info : *Display_Info = maybe_cycle_state(toggle_normals_visibility_progress_proc);

    for :Selected app.entities {
        it.display_info.triangle_style.normal_style.visible  = app_info.triangle_style.normal_style.visible;
        it.display_info.segment_style.normal_style.visible  = app_info.segment_style.normal_style.visible;
        it.display_info.point_style.normal_style.visible  = app_info.point_style.normal_style.visible;
    }
}

toggle_normals_visibility_proc :: (last_interaction_time : *void) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    toggle_normals_visibility();
}

toggle_normals_visibility_progress_proc :: (app_info : *Display_Info) -> Fraction {
    // Start with the triangle normal visibility 
    normals_visible : bool = app_info.triangle_style.normal_style.visible;

    result : Fraction;
    result.numer = xx normals_visible;
    result.denom = 1;

    // Toggle the normals on all elements with normals
    app_info.triangle_style.normal_style.visible = !normals_visible;
    app_info.segment_style.normal_style.visible = !normals_visible;
    app_info.point_style.normal_style.visible = !normals_visible;

    return result;
}


toggle_normals_visibility_progress_proc_const :: () -> Fraction {
    app_info, selected_count := get_display_info();
    app_info_copy := <<app_info;
    return toggle_normals_visibility_progress_proc(*app_info_copy);
}





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

maybe_cycle_vertex_theme :: () -> *Vertex_Label_Theme {

    selected : [..]*Entity = temp_selected_entities();

    theme : *Vertex_Label_Theme = *app.template_display_info.vertex_label_theme;

    // Don't modify template state if exactly one item is selected
    if selected.count == 1 {
        theme = *selected[0].display_info.vertex_label_theme;
    }

     // We dont want to change the template state if nothing will change
    if selected.count > 0 {
        cycle_vertex_label_theme(theme);
    }

    return theme;
}

cycle_vertex_label :: () {

    theme : *Vertex_Label_Theme = maybe_cycle_vertex_theme();

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
    app_info, selected_count := get_display_info();
    app_info_copy := <<app_info; // We just want to get the fraction, not modify the display info
    return cycle_vertex_label_theme(*app_info_copy.vertex_label_theme);
}





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

maybe_cycle_element_label_theme :: () -> *Element_Label_Theme {

    selected : [..]*Entity = temp_selected_entities();

    theme : *Element_Label_Theme = *app.template_display_info.point_label_theme;

    // Don't modify template state if exactly one item is selected
    if selected.count == 1 {
        theme = *selected[0].display_info.point_label_theme;
    }

     // We dont want to change the template state if nothing will change
    if selected.count > 0 {
        cycle_element_label_theme(theme);
        // All element types are kept in sync with the point one
        app.template_display_info.segment_label_theme.show_index = theme.show_index;
        app.template_display_info.triangle_label_theme.show_index = theme.show_index;
    }

    return theme;
}

cycle_element_label :: () {
    // All element types are kept in sync with the point one
    theme := maybe_cycle_element_label_theme();

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
    app_info, selected_count := get_display_info();
    app_info_copy := <<app_info; // We just want to get the fraction, not modify the display info
    return cycle_element_label_theme(*app_info_copy.point_label_theme);
}






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

maybe_cycle_annotation_label_theme :: () -> *Annotation_Label_Theme {

    selected : [..]*Entity = temp_selected_entities();

    log_warning("nocommit @Incomplete: Handle all annotations in %", #this);
    theme : *Annotation_Label_Theme = *app.template_display_info.vertex_label_theme.annotation_label_theme; // nocommit Handle all these

    // Don't modify template state if exactly one item is selected
    if selected.count == 1 {
        theme = *selected[0].display_info.vertex_label_theme.annotation_label_theme;
    }

     // We dont want to change the template state if nothing will change
    if selected.count > 0 {
        cycle_annotation_theme(theme);
    }

    return theme;
}

cycle_annotation :: () {
    theme := maybe_cycle_annotation_label_theme();

    for :Selected app.entities {
        // @Cleanup Rename the cycle function to mention only visibility is cycled?
        log_warning("nocommit @Incomplete: Handle all annotations in %", #this);
        it.display_info.vertex_label_theme.annotation_label_theme.visible = theme.visible;
    }
}

cycle_annotation_proc :: (last_interaction_time : *void) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_annotation();
}

cycle_annotation_progress_proc :: () -> Fraction {
    log_warning("nocommit @Incomplete: This should go through all the existing annotations in turn and default to off %", #this);
    app_info, selected_count := get_display_info();
    app_info_copy := <<app_info; // We just want to get the fraction, not modify the display info
    return cycle_annotation_theme(*app_info_copy.vertex_label_theme.annotation_label_theme);
}




//
// Cycle opacity @Think should this apply to elements other than triangles as well? Maybe when we make point/segment elements into quads
//

cycle_opacity :: () {

    app_info : *Display_Info = maybe_cycle_state(cycle_opacity_progress_proc);

    for :Selected app.entities {
        it.display_info.triangle_style.color.w = app_info.triangle_style.color.w;
    }
}

cycle_opacity_proc :: (last_interaction_time : *void) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_opacity();
}

cycle_opacity_progress_proc :: (using app_info : *Display_Info) -> Fraction {
    if triangle_style.color.w == 1.  {
        triangle_style.color.w = .5; // This affects is_occluder
        return .{0, 2};
    } else if triangle_style.color.w >= .5 {
        triangle_style.color.w = .2;
        return .{1, 2};
    } else {
        triangle_style.color.w = 1.;
        return .{2, 2};
    }
}

cycle_opacity_progress_proc_const :: () -> Fraction {
    app_info, selected_count := get_display_info();
    app_info_copy := <<app_info; // We just want to get the fraction, not modify the display info
    return cycle_opacity_progress_proc(*app_info_copy);
}






//
// Cycle backface mode
//

// @FIXME This does not cycle as expected since template state is always cycled even with no selection and when one item is selected the template changes

cycle_backface_mode :: () {

    mode := *app.template_display_info.triangle_style.backface_mode;
    cycle_backface_mode_progress_proc(mode);

    for :Selected app.entities {
        it.display_info.triangle_style.backface_mode = <<mode;
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
    app_info, selected_count := get_display_info();
    app_info_copy := <<app_info; // We just want to get the fraction, not modify the display info
    return cycle_backface_mode_progress_proc(*app_info_copy.triangle_style.backface_mode);
}







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

    tmp : [..]*Entity = temp_selected_entities();
    quick_sort(tmp, no_dependencies_first_then_chronological);
    for tmp {
        reload_entity(it);
    }
}






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






//
// Clear labels
//

clear_all_labels_proc :: (unused : *void) {
    for :Selected app.entities {
        // @Cleanup Add a label theme iterator?
        it.display_info.vertex_label_theme.show_index = false;
        it.display_info.vertex_label_theme.show_position = false;
        it.display_info.vertex_label_theme.annotation_label_theme.visible = false;

        it.display_info.point_label_theme.show_index = false;
        it.display_info.point_label_theme.annotation_label_theme.visible = false;

        it.display_info.segment_label_theme.show_index = false;
        it.display_info.segment_label_theme.annotation_label_theme.visible = false;

        it.display_info.triangle_label_theme.show_index = false;
        it.display_info.triangle_label_theme.annotation_label_theme.visible = false;
    }

    // Also clear the display info used to set action button state
    display_info : *Display_Info = *app.template_display_info;
    display_info.vertex_label_theme.show_index = false;
    display_info.vertex_label_theme.show_position = false;
    display_info.vertex_label_theme.annotation_label_theme.visible = false;

    display_info.point_label_theme.show_index = false;
    display_info.point_label_theme.annotation_label_theme.visible = false;

    display_info.segment_label_theme.show_index = false;
    display_info.segment_label_theme.annotation_label_theme.visible = false;

    display_info.triangle_label_theme.show_index = false;
    display_info.triangle_label_theme.annotation_label_theme.visible = false;
}
