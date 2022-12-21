// Specfied since we use the values as an index into an array
Target_Items :: enum int #specified {
    // @Volatile Don't change ordering, it will desync the descriptions etc in the keymap
    ALL_ITEMS :: 0;
    VISIBLE ::   1;
    SELECTED ::  2;
}
TARGET_ITEMS_COUNT :: #run get_enum_count(Target_Items);

show_action_target_text :: (target_items : Target_Items) {
    ImGui.PushStyleColor(xx ImGui.Col.Text, BLACK);
    defer ImGui.PopStyleColor();
    if app.entities.count {
        if #complete target_items == {
            case .ALL_ITEMS;
                count := app.entities.count;
                ImGui.Text("Target all items (%)", count);
            case .VISIBLE;
                count := 0; for :Visible app.entities count += 1;
                ImGui.Text("Target % visible item%", count, ifx count == 1 then "" else "s");
            case .SELECTED;
                count := 0; for :Selected app.entities count += 1;
                ImGui.Text("Target % selected item%", count, ifx count == 1 then "" else "s");
        }
    } else {
        ImGui.Text("No items to target");
    }
}

Is_Target :: (e : *Entity) -> bool #expand {
    if #complete `target == {
        case .SELECTED;  return (e.is_selected == true);
        case .VISIBLE;   return (e.display_info.is_visible  == true);
        case .ALL_ITEMS; return true;
    }
}

Fraction :: struct {
    numer : int;
    denom : int;
}

Action :: struct {
    target : Target_Items;
    proc : (data : *void)->();

    // Actions cycle/toggle item state, this function returns a fraction representing the progress of the state cycling so you can e.g., change the color of the action buttons according to how far along the cycle you are
    progress_proc : ()->Fraction = ()=>Fraction.{0,0};
}

Action_Set :: struct {
    target_action : [3]Action; #assert(TARGET_ITEMS_COUNT == 3);
    desc : string; // Important: A target-specific postfix is added by get_action_description
    key : u32;
    regular_button := false; // If true a simple ImGui.Button, otherwise a button which cycles/toggles state and changes color accordingly
    override_WantCaptureKeyboard := false;
    
    last_interaction_time : Apollo_Time;
    hovered_duration_secs : float; // @Cleanup When switching to ImGui 1.88 which natively supports timed tooltips
}

get_action_description :: (action_set : Action_Set, action_target : Target_Items) -> string {
    desc : string;
    if #complete action_target == {
        case .VISIBLE; desc = sprint("% %", action_set.desc, "visible items");
        case .SELECTED; desc = sprint("% %", action_set.desc, "selected items");
        case .ALL_ITEMS; desc = sprint("% %", action_set.desc, "all items");
    }
    return desc;
}

ALL_ITEMS_MOD :: Modifier_Flags.{shift_pressed=true};
SELECTED_MOD :: Modifier_Flags.{control_pressed=true};
VISIBLE_MOD :: Modifier_Flags.{};

modifier_to_target :: (mod : Modifier_Flags) -> bool, Target_Items {
    if mod == VISIBLE_MOD   return true, .VISIBLE;
    if mod == SELECTED_MOD  return true, .SELECTED;
    if mod == ALL_ITEMS_MOD return true, .ALL_ITEMS;
    return false, .VISIBLE;
}

target_to_modifier :: (target : Target_Items) -> Modifier_Flags {
    if #complete target == {
        case .VISIBLE; return VISIBLE_MOD;
        case .SELECTED; return SELECTED_MOD;
        case .ALL_ITEMS; return ALL_ITEMS_MOD;
    }
}



//
// Toggle clipping
//

any_active_clipping :: (target : Target_Items) -> bool {
    clip_active := false;
    for app.entities if Is_Target(it) {
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

toggle_clipping :: (target : Target_Items) {

    clip_active := *app.edit_display_info.clip_sphere.is_active;
    <<clip_active = !<<clip_active;

    for app.entities if Is_Target(it) {
        it.display_info.clip_sphere.is_active = <<clip_active;
        for * it.display_info.clip_ranges {
            it.is_active = <<clip_active;
        }
    }
}

toggle_clipping_proc :: (last_interaction_time : *void, target : Target_Items) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    toggle_clipping(target);
}


toggle_clipping_progress_proc :: (target : Target_Items) -> Fraction {
    if any_active_clipping(target) {
        return .{1,1};
    }
    return .{0,1};
}

TOGGLE_CLIPPING_ACTION_SET := Action_Set.{
    target_action=.[
        // @Cleanup We repeat the target here because we need constant procs with zero inputs/ouputs so the body of add_key below works
        .{
            target=.VISIBLE,
            proc=#bake_arguments toggle_clipping_proc(target=.VISIBLE),
            progress_proc=()=>toggle_clipping_progress_proc(.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=#bake_arguments toggle_clipping_proc(target=.SELECTED),
            progress_proc=()=>toggle_clipping_progress_proc(.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=#bake_arguments toggle_clipping_proc(target=.ALL_ITEMS),
            progress_proc=()=>toggle_clipping_progress_proc(.ALL_ITEMS),
            // progress_proc=()=>{return ifx any_active_clipping(.ALL_ITEMS) then Fraction.{1,1} else .{0,1};} // @CompilerBug?
        },
    ],
    desc="Toggle clipping on",
    key=#char "c",
};





//
// Cycle point size
//

cycle_point_size :: (target : Target_Items) {

    app_info := *app.edit_display_info;
    cycle_point_size_progress_proc(app_info);

    for app.entities if Is_Target(it) {
        it.display_info.points_visible = app_info.points_visible;
        it.display_info.points_size    = app_info.points_size;
    }
}

cycle_point_size_proc :: (last_interaction_time : *void, target : Target_Items) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_point_size(target);
}


cycle_point_size_progress_proc :: (using app_info : *Display_Info) -> Fraction {
    // Handle full range of points_size
    if !points_visible {
        points_visible = true;
        points_size = 2;
        return .{0,3};
    } else if points_size <= 2 {
        points_size = 4;
        return .{1,3};
    } else if points_size <= 4 {
        points_size = 6;
        return .{2,3};
    } else {
        points_visible = false;
        return .{3,3};
    }
}

cycle_point_size_progress_proc_const :: () -> Fraction {
    app_info_copy := app.edit_display_info;
    return cycle_point_size_progress_proc(*app_info_copy);
}


CYCLE_POINT_SIZE_ACTION_SET := Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=#bake_arguments cycle_point_size_proc(target=.VISIBLE),
            progress_proc=cycle_point_size_progress_proc_const,
        },
        .{
            target=.SELECTED,
            proc=#bake_arguments cycle_point_size_proc(target=.SELECTED),
            progress_proc=cycle_point_size_progress_proc_const,
        },
        .{
            target=.ALL_ITEMS,
            proc=#bake_arguments cycle_point_size_proc(target=.ALL_ITEMS),
            progress_proc=cycle_point_size_progress_proc_const,
        },
    ],
    desc="Cycle point size for",
    key=#char "p",
};






//
// Cycle wireframe width
//

cycle_wireframe_width :: (target : Target_Items) {

    app_info := *app.edit_display_info;
    cycle_wireframe_width_progress_proc(app_info);

    for app.entities if Is_Target(it) {
        it.display_info.wireframe_visible = app_info.wireframe_visible;
        it.display_info.wireframe_width   = app_info.wireframe_width;
    }
}

// @Cleanup could auto generate this
cycle_wireframe_width_proc :: (last_interaction_time : *void, target : Target_Items) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_wireframe_width(target);
}

cycle_wireframe_width_progress_proc :: (using app_info : *Display_Info) -> Fraction {

    // Handle full range of wireframe_width
    if !wireframe_visible {
        wireframe_visible = true;
        wireframe_width = 1;
        return .{0,3};
    } else if wireframe_width <= 1 {
        wireframe_width = 2;
        return .{1,3};
    } else if wireframe_width <= 2 {
        wireframe_width = 3;
        return .{2,3};
    } else {
        wireframe_visible = false;
        return .{3,3};
    }
}

cycle_wireframe_width_progress_proc_const :: () -> Fraction {
    app_info_copy := app.edit_display_info;
    return cycle_wireframe_width_progress_proc(*app_info_copy);
}

CYCLE_LINE_WIDTH_ACTION_SET := Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=#bake_arguments cycle_wireframe_width_proc(target=.VISIBLE),
            progress_proc=cycle_wireframe_width_progress_proc_const,
        },
        .{
            target=.SELECTED,
            proc=#bake_arguments cycle_wireframe_width_proc(target=.SELECTED),
            progress_proc=cycle_wireframe_width_progress_proc_const,
        },
        .{
            target=.ALL_ITEMS,
            proc=#bake_arguments cycle_wireframe_width_proc(target=.ALL_ITEMS),
            progress_proc=cycle_wireframe_width_progress_proc_const,
        },
    ],
    desc="Cycle line width for",
    key=#char "l",
};



//
// Toggle normals visibility
//


toggle_normals_visibility :: (target : Target_Items) {

    app_info := *app.edit_display_info;
    toggle_normals_visibility_progress_proc(app_info);

    for app.entities if Is_Target(it) {
        it.display_info.normals_visible = app_info.normals_visible;
    }
}

toggle_normals_visibility_proc :: (last_interaction_time : *void, target : Target_Items) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    toggle_normals_visibility(target);
}

toggle_normals_visibility_progress_proc :: (using app_info : *Display_Info) -> Fraction {
    result : Fraction;
    result.numer = xx normals_visible;
    result.denom = 1;
    normals_visible = !normals_visible;
    return result;
}


toggle_normals_visibility_progress_proc_const :: () -> Fraction {
    app_info_copy := app.edit_display_info;
    return toggle_normals_visibility_progress_proc(*app_info_copy);
}

TOGGLE_NORMALS_ACTION_SET := Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=#bake_arguments toggle_normals_visibility_proc(target=.VISIBLE),
            progress_proc=toggle_normals_visibility_progress_proc_const,
        },
        .{
            target=.SELECTED,
            proc=#bake_arguments toggle_normals_visibility_proc(target=.SELECTED),
            progress_proc=toggle_normals_visibility_progress_proc_const,
        },
        .{
            target=.ALL_ITEMS,
            proc=#bake_arguments toggle_normals_visibility_proc(target=.ALL_ITEMS),
            progress_proc=toggle_normals_visibility_progress_proc_const,
        },
    ],
    desc="Toggle normals visibility for",
    key=#char "n",
};





//
// Cycle vertex labels
//

cycle_vertex_label_theme :: (target : Target_Items, theme : *Vertex_Label_Theme) -> Fraction {

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

cycle_vertex_label :: (target : Target_Items) {
    theme := *app.edit_display_info.vertex_label_style;

    cycle_vertex_label_theme(target, theme);

    for app.entities if Is_Target(it) {
        it.display_info.vertex_label_style.show_position = theme.show_position;
        it.display_info.vertex_label_style.show_index = theme.show_index;
    }
}


cycle_vertex_label_proc :: (last_interaction_time : *void, target : Target_Items) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_vertex_label(target);
}


cycle_vertex_label_progress_proc :: (target : Target_Items) -> Fraction {
    app_info_copy := app.edit_display_info; // We just want to get the fraction, not modify the display info
    return cycle_vertex_label_theme(target, *app_info_copy.vertex_label_style);
}

// @Cleanup decapitalize non-constant action sets

CYCLE_VERTEX_LABEL_ACTION_SET := Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=#bake_arguments cycle_vertex_label_proc(target=.VISIBLE),
            progress_proc=()=>cycle_vertex_label_progress_proc(.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=#bake_arguments cycle_vertex_label_proc(target=.SELECTED),
            progress_proc=()=>cycle_vertex_label_progress_proc(.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=#bake_arguments cycle_vertex_label_proc(target=.ALL_ITEMS),
            progress_proc=()=>cycle_vertex_label_progress_proc(.ALL_ITEMS),
        },
    ],
    desc="Cycle vertex labels for",
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

cycle_element_label :: (target : Target_Items) {
    // All element types are kept in sync with the point one
    theme := *app.edit_display_info.point_label_theme;

    cycle_element_label_theme(theme);

    for app.entities if Is_Target(it) {
        it.display_info.point_label_theme.show_index = theme.show_index;
        it.display_info.segment_label_theme.show_index = theme.show_index;
        it.display_info.triangle_label_theme.show_index = theme.show_index;
    }
}

cycle_element_label_proc :: (last_interaction_time : *void, target : Target_Items) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_element_label(target);
}

cycle_element_label_progress_proc :: (target : Target_Items) -> Fraction {
    app_info_copy := app.edit_display_info; // We just want to get the fraction, not modify the display info
    return cycle_element_label_theme(*app_info_copy.point_label_theme);
}

CYCLE_ELEMENT_LABEL_ACTION_SET := Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=#bake_arguments cycle_element_label_proc(target=.VISIBLE),
            progress_proc=()=>cycle_element_label_progress_proc(.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=#bake_arguments cycle_element_label_proc(target=.SELECTED),
            progress_proc=()=>cycle_element_label_progress_proc(.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=#bake_arguments cycle_element_label_proc(target=.ALL_ITEMS),
            progress_proc=()=>cycle_element_label_progress_proc(.ALL_ITEMS),
        },
    ],
    desc="Toggle face labels for",
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

cycle_annotation :: (target : Target_Items) {
    theme := *app.edit_display_info.annotation_label_theme;

    cycle_annotation_theme(theme);

    for app.entities if Is_Target(it) {
        it.display_info.annotation_label_theme.visible = theme.visible;
    }
}

cycle_annotation_proc :: (last_interaction_time : *void, target : Target_Items) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_annotation(target);
}

cycle_annotation_progress_proc :: () -> Fraction {
    app_info_copy := app.edit_display_info;
    return cycle_annotation_theme(*app_info_copy.annotation_label_theme);
}

CYCLE_ANNOTATION_ACTION_SET := Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=#bake_arguments cycle_annotation_proc(target=.VISIBLE),
            progress_proc=cycle_annotation_progress_proc,
        },
        .{
            target=.SELECTED,
            proc=#bake_arguments cycle_annotation_proc(target=.SELECTED),
            progress_proc=cycle_annotation_progress_proc,
        },
        .{
            target=.ALL_ITEMS,
            proc=#bake_arguments cycle_annotation_proc(target=.ALL_ITEMS),
            progress_proc=cycle_annotation_progress_proc,
        },
    ],
    desc="Toggle annotations for",
    key=#char "k",
};





//
// Cycle opacity
//

cycle_opacity :: (target : Target_Items) {

    app_info := *app.edit_display_info;
    cycle_opacity_progress_proc(app_info);

    for app.entities if Is_Target(it) {
        it.display_info.surface_color.w = app_info.surface_color.w;
    }
}

cycle_opacity_proc :: (last_interaction_time : *void, target : Target_Items) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_opacity(target);
}

cycle_opacity_progress_proc :: (using app_info : *Display_Info) -> Fraction {
    if surface_color.w == 1.  {
        surface_color.w = .5;
        return .{0, 2};
    } else if surface_color.w >= .5 {
        surface_color.w = .2;
        return .{1, 2};
    } else {
        surface_color.w = 1.;
        return .{2, 2};
    }
}

cycle_opacity_progress_proc_const :: () -> Fraction {
    app_info_copy := app.edit_display_info;
    return cycle_opacity_progress_proc(*app_info_copy);
}

CYCLE_OPACITY_ACTION_SET := Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=#bake_arguments cycle_opacity_proc(target=.VISIBLE),
            progress_proc=cycle_opacity_progress_proc_const,
        },
        .{
            target=.SELECTED,
            proc=#bake_arguments cycle_opacity_proc(target=.SELECTED),
            progress_proc=cycle_opacity_progress_proc_const,
        },
        .{
            target=.ALL_ITEMS,
            proc=#bake_arguments cycle_opacity_proc(target=.ALL_ITEMS),
            progress_proc=cycle_opacity_progress_proc_const,
        },
    ],
    desc="Cycle opacity for",
    key=#char "o",
};





//
// Cycle backface mode
//

cycle_backface_mode :: (target : Target_Items) {

    mode := *app.edit_display_info.backface_mode;
    cycle_backface_mode_progress_proc(mode);

    for app.entities if Is_Target(it) {
        it.display_info.backface_mode = <<mode;
    }
}

cycle_backface_mode_proc :: (last_interaction_time : *void, target : Target_Items) {
    if last_interaction_time {
        <<cast(*Apollo_Time)last_interaction_time = current_time_consensus();
    }
    cycle_backface_mode(target);
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
    app_info_copy := app.edit_display_info;
    return cycle_backface_mode_progress_proc(*app_info_copy.backface_mode);
}

CYCLE_BACKFACE_MODE_ACTION_SET := Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=#bake_arguments cycle_backface_mode_proc(target=.VISIBLE),
            progress_proc=cycle_backface_mode_progress_proc_const,
        },
        .{
            target=.SELECTED,
            proc=#bake_arguments cycle_backface_mode_proc(target=.SELECTED),
            progress_proc=cycle_backface_mode_progress_proc_const,
        },
        .{
            target=.ALL_ITEMS,
            proc=#bake_arguments cycle_backface_mode_proc(target=.ALL_ITEMS),
            progress_proc=cycle_backface_mode_progress_proc_const,
        },
    ],
    desc="Cycle backface rendering mode for",
    key=#char "b",
};






//
// Reload items
//

reload_items :: (unused : *void, target : Target_Items) {

    no_dependencies_first_then_chronological :: (a : *Entity, b : *Entity) -> s64 {
        // FILE_ON_DISK and PRESET_SHAPE sources do not depend on other entities, but command outputs can, so we load those last and in order of 
        if a.source.kind > b.source.kind return  1;
        if a.source.kind < b.source.kind return -1;
        assert(a.source.kind == b.source.kind);
        if get_entity_source(a).creation_time > get_entity_source(b).creation_time return  1;
        if get_entity_source(a).creation_time < get_entity_source(b).creation_time return -1;
        return 0;
    }

    tmp := array_copy(app.entities);
    defer array_free(tmp);
    quick_sort(tmp, no_dependencies_first_then_chronological);

    for tmp if Is_Target(it) {
        reload_entity(it);
    }
}

RELOAD_ITEMS_ACTION_SET := Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=#bake_arguments reload_items(target=.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=#bake_arguments reload_items(target=.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=#bake_arguments reload_items(target=.ALL_ITEMS),
        },
    ],
    desc="Reload",
    key=cast(u32) Special_Key_Code.F5,
    regular_button=true,
    override_WantCaptureKeyboard=true,
};





//
// Focus items
//

focus_items :: (unused : *void, target : Target_Items) {

    sphere : Sphere;

    if #complete target == {
        case .ALL_ITEMS;
            sphere = entities_bounding_sphere();
        case .VISIBLE;
            sphere = entities_bounding_sphere((e)=>(e.display_info.is_visible));
        case .SELECTED;
            sphere = entities_bounding_sphere((e)=>(e.is_selected));
    }

    if sphere.radius > 0 {
        fit_sphere_on_screen(sphere, sphere.radius);
    }
}

FOCUS_ITEMS_ACTION_SET := Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=#bake_arguments focus_items(target=.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=#bake_arguments focus_items(target=.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=#bake_arguments focus_items(target=.ALL_ITEMS),
        },
    ],
    desc="Focus camera on",
    key=#char "f",
    regular_button=true,
};





//
// Clear labels
//

clear_all_labels :: (unused : *void, target : Target_Items) {
    for app.entities if Is_Target(it) {
        it.display_info.vertex_label_style.show_index = false;
        it.display_info.vertex_label_style.show_position = false;
        it.display_info.point_label_theme.show_index = false;
        it.display_info.segment_label_theme.show_index = false;
        it.display_info.triangle_label_theme.show_index = false;
        it.display_info.annotation_label_theme.visible = false;
    }

    // Also clear the display info used to set action button state
    display_info : *Display_Info = *app.edit_display_info;
    display_info.vertex_label_style.show_index = false;
    display_info.vertex_label_style.show_position = false;
    display_info.point_label_theme.show_index = false;
    display_info.segment_label_theme.show_index = false;
    display_info.triangle_label_theme.show_index = false;
    display_info.annotation_label_theme.visible = false;
}


// Note: no action button
CLEAR_LABELS_ACTION_SET :: Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=#bake_arguments clear_all_labels(target=.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=#bake_arguments clear_all_labels(target=.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=#bake_arguments clear_all_labels(target=.ALL_ITEMS),
        },
    ],
    desc="Clear labels for",
    key=#char "x"
};
