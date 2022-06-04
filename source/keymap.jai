Keymap_Proc_Info :: struct {
    name: string;
    proc: #type () -> ();
}

Modifier_Flags :: struct {
    shift_pressed   := false;
    control_pressed := false;
    alt_pressed     := false;
}

current_modifier_flags :: () -> Modifier_Flags {
    result : Modifier_Flags;
    result.shift_pressed = io().KeyShift;
    result.control_pressed = io().KeyCtrl;
    result.alt_pressed = io().KeyAlt;
    return result;
}

operator== :: (a : Modifier_Flags, b : Modifier_Flags) -> bool {
    // @Cleanup: reimplement using reflection
    control_equal := (a.control_pressed == b.control_pressed);
    shift_equal   := (a.shift_pressed   == b.shift_pressed);
    alt_equal     := (a.alt_pressed     == b.alt_pressed);
    return control_equal && shift_equal && alt_equal;
}

Single_Key_Mapping :: struct {
    key_code :       u32; // ASCII if key_code >= 32, Special_Key_Code otherwise
    modifier_flags : Modifier_Flags;
    proc_info_index : int;
    override_WantCaptureKeyboard : bool;
}

// Compile-time check to ensure we don't stomp the ASCII key codes we want
#assert(enum_highest_value(Special_Key_Code) < 32);

Special_Key_Code :: enum u32 #specified {
    EMPTY  :: 0;
    ESCAPE :: 1;
    ENTER  :: 2; // unused
    TAB    :: 3; // unused
    DELETE :: 4;
    F1     :: 11; // unused
    F2     :: 12; // unused
    F3     :: 13; // unused
    F4     :: 14; // unused
    F5     :: 15;
    F6     :: 16; // unused
    F7     :: 17; // unused
    F8     :: 18; // unused
    F9     :: 19; // unused
    F10     :: 20; // unused
    F11     :: 21;
    F12     :: 22; // unused
}

to_string :: (key_code : u32, modifier_flags : Modifier_Flags) -> string {
    builder : String_Builder;
    defer free_buffers(*builder);
    if modifier_flags.control_pressed print_to_builder(*builder, "Ctrl ");
    if modifier_flags.alt_pressed     print_to_builder(*builder, "Alt ");
    if modifier_flags.shift_pressed   print_to_builder(*builder, "Shift ");
    if key_code == 32 {
        print_to_builder(*builder, "Space");
    } else if key_code > 32 {
        // upper_case := to_upper(cast(u8) key_code);
        upper_case := cast(u8) key_code;
        cstr: string;   // This is a dumb way to make a one-character string so you can print it.
        cstr.data  = xx *upper_case;
        cstr.count = 1;
        print_to_builder(*builder, "%", cstr);
    } else if #complete cast(Special_Key_Code)key_code == {
        case .EMPTY;  // Do nothing
        case .ESCAPE; print_to_builder(*builder, "Esc");
        case .ENTER;  print_to_builder(*builder, "Enter");
        case .TAB;    print_to_builder(*builder, "Tab");
        case .DELETE; print_to_builder(*builder, "Del");
        case .F1;     print_to_builder(*builder, "F1");
        case .F2;     print_to_builder(*builder, "F2");
        case .F3;     print_to_builder(*builder, "F3");
        case .F4;     print_to_builder(*builder, "F4");
        case .F5;     print_to_builder(*builder, "F5");
        case .F6;     print_to_builder(*builder, "F6");
        case .F7;     print_to_builder(*builder, "F7");
        case .F8;     print_to_builder(*builder, "F8");
        case .F9;     print_to_builder(*builder, "F9");
        case .F10;    print_to_builder(*builder, "F10");
        case .F11;    print_to_builder(*builder, "F11");
        case .F12;    print_to_builder(*builder, "F12");
    }

    return builder_to_string(*builder); // @Leak pass temp??
}

Keymap :: struct {
    // These are fixed at startup. When you load a keymap, we bind keys to procedures from this array.
    procs : [..] Keymap_Proc_Info;

    mappings : [..] Single_Key_Mapping;
}

Operation :: struct {
    proc : ()->();
    desc : string;
    key : u32;
    mod : Modifier_Flags = .{};
    override_WantCaptureKeyboard := false;
}

any_active_false :: (target : Target_Items) -> bool {return false;}

Fraction :: struct {
    numer : int;
    denom : int;
}

Action :: struct {
    target : Target_Items;
    proc : ()->();

    // Actions cycle/toggle item state, this function returns a fraction representing the progress of the state cycling so you can e.g., change the color of the action buttons according to how far along the cycle you are
    progress_proc : ()->Fraction = ()=>Fraction.{0,0};
}

Action_Set :: struct {
    target_action : [3]Action; #assert(TARGET_ITEMS_COUNT == 3);
    desc : string; // Important: A target-specific postfix is added by get_action_description
    key : u32;
    regular_button := false; // If true a simple ImGui.Button, otherwise a button which cycles/toggles state and changes color accordingly
    override_WantCaptureKeyboard := false;
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

toggle_clipping_progress_proc :: (target : Target_Items) -> Fraction {
    if any_active_clipping(target) {
        return .{1,1};
    }
    return .{0,1};
}

TOGGLE_CLIPPING_ACTION_SET :: Action_Set.{
    target_action=.[
        // @Cleanup We repeat the target here because we need constant procs with zero inputs/ouputs so the body of add_key below works
        .{
            target=.VISIBLE,
            proc=()=>{toggle_clipping(.VISIBLE);},
            progress_proc=()=>toggle_clipping_progress_proc(.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=()=>{toggle_clipping(.SELECTED);},
            progress_proc=()=>toggle_clipping_progress_proc(.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=()=>{toggle_clipping(.ALL_ITEMS);},
            progress_proc=()=>toggle_clipping_progress_proc(.ALL_ITEMS),
            // progress_proc=()=>{return ifx any_active_clipping(.ALL_ITEMS) then Fraction.{1,1} else .{0,1};} // @CompilerBug?
        },
    ],
    desc="Toggle clipping on",
    key=#char "c",
};

cycle_point_size_progress_proc :: (target : Target_Items) -> Fraction {
    app_info_copy := app.selection_display_info;
    return cycle_point_size_progress_proc(*app_info_copy);
}

CYCLE_POINT_SIZE_ACTION_SET :: Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=()=>{cycle_point_size(.VISIBLE);},
            progress_proc=()=>cycle_point_size_progress_proc(.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=()=>{cycle_point_size(.SELECTED);},
            progress_proc=()=>cycle_point_size_progress_proc(.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=()=>{cycle_point_size(.ALL_ITEMS);},
            progress_proc=()=>cycle_point_size_progress_proc(.ALL_ITEMS),
        },
    ],
    desc="Cycle point size for",
    key=#char "p",
};

cycle_wireframe_width_progress_proc :: (target : Target_Items) -> Fraction {
    app_info_copy := app.selection_display_info;
    return cycle_wireframe_width_progress_proc(*app_info_copy);
}

CYCLE_LINE_WIDTH_ACTION_SET :: Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=()=>{cycle_wireframe_width(.VISIBLE);},
            progress_proc=()=>cycle_wireframe_width_progress_proc(.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=()=>{cycle_wireframe_width(.SELECTED);},
            progress_proc=()=>cycle_wireframe_width_progress_proc(.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=()=>{cycle_wireframe_width(.ALL_ITEMS);},
            progress_proc=()=>cycle_wireframe_width_progress_proc(.ALL_ITEMS),
        },
    ],
    desc="Cycle line width for",
    key=#char "l",
};

toggle_normals_visibility_progress_proc :: (target : Target_Items) -> Fraction {
    app_info_copy := app.selection_display_info;
    return toggle_normals_visibility_progress_proc(*app_info_copy);
}

TOGGLE_NORMALS_ACTION_SET :: Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=()=>{toggle_normals_visibility(.VISIBLE);},
            progress_proc=()=>toggle_normals_visibility_progress_proc(.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=()=>{toggle_normals_visibility(.SELECTED);},
            progress_proc=()=>toggle_normals_visibility_progress_proc(.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=()=>{toggle_normals_visibility(.ALL_ITEMS);},
            progress_proc=()=>toggle_normals_visibility_progress_proc(.ALL_ITEMS),
        },
    ],
    desc="Toggle normals visibility for",
    key=#char "n",
};

cycle_vertex_label_progress_proc :: (target : Target_Items) -> Fraction {
    app_info_copy := app.selection_display_info;
    return cycle_label_theme(target, *app_info_copy.vertex_label_style);
}

CYCLE_VERTEX_LABEL_ACTION_SET :: Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=()=>{cycle_vertex_label(.VISIBLE);},
            progress_proc=()=>cycle_vertex_label_progress_proc(.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=()=>{cycle_vertex_label(.SELECTED);},
            progress_proc=()=>cycle_vertex_label_progress_proc(.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=()=>{cycle_vertex_label(.ALL_ITEMS);},
            progress_proc=()=>cycle_vertex_label_progress_proc(.ALL_ITEMS),
        },
    ],
    desc="Cycle vertex labels for",
    key=#char "j",
};

cycle_element_label_progress_proc :: (target : Target_Items) -> Fraction {
    app_info_copy := app.selection_display_info;
    return cycle_label_theme(target, *app_info_copy.element_label_theme);
}

CYCLE_ELEMENT_LABEL_ACTION_SET :: Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=()=>{cycle_element_label(.VISIBLE);},
            progress_proc=()=>cycle_element_label_progress_proc(.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=()=>{cycle_element_label(.SELECTED);},
            progress_proc=()=>cycle_element_label_progress_proc(.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=()=>{cycle_element_label(.ALL_ITEMS);},
            progress_proc=()=>cycle_element_label_progress_proc(.ALL_ITEMS),
        },
    ],
    desc="Cycle element labels for",
    key=#char "i",
};

cycle_opacity_progress_proc :: (target : Target_Items) -> Fraction {
    app_info_copy := app.selection_display_info;
    return cycle_opacity_progress_proc(*app_info_copy);
}

CYCLE_OPACITY_ACTION_SET :: Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=()=>{cycle_opacity(.VISIBLE);},
            progress_proc=()=>cycle_opacity_progress_proc(.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=()=>{cycle_opacity(.SELECTED);},
            progress_proc=()=>cycle_opacity_progress_proc(.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=()=>{cycle_opacity(.ALL_ITEMS);},
            progress_proc=()=>cycle_opacity_progress_proc(.ALL_ITEMS),
        },
    ],
    desc="Cycle opacity for",
    key=#char "o",
};

cycle_backface_mode_progress_proc :: (target : Target_Items) -> Fraction {
    app_info_copy := app.selection_display_info;
    return cycle_backface_mode_progress_proc(*app_info_copy.backface_mode);
}

CYCLE_BACKFACE_MODE_ACTION_SET :: Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=()=>{cycle_backface_mode(.VISIBLE);},
            progress_proc=()=>cycle_backface_mode_progress_proc(.VISIBLE),
        },
        .{
            target=.SELECTED,
            proc=()=>{cycle_backface_mode(.SELECTED);},
            progress_proc=()=>cycle_backface_mode_progress_proc(.SELECTED),
        },
        .{
            target=.ALL_ITEMS,
            proc=()=>{cycle_backface_mode(.ALL_ITEMS);},
            progress_proc=()=>cycle_backface_mode_progress_proc(.ALL_ITEMS),
        },
    ],
    desc="Cycle backface rendering mode for",
    key=#char "b",
};

RELOAD_ITEMS_ACTION_SET :: Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=()=>{reload_items(.VISIBLE);},
        },
        .{
            target=.SELECTED,
            proc=()=>{reload_items(.SELECTED);},
        },
        .{
            target=.ALL_ITEMS,
            proc=()=>{reload_items(.ALL_ITEMS);},
        },
    ],
    desc="Reload",
    key=cast(u32) Special_Key_Code.F5,
    regular_button=true,
    override_WantCaptureKeyboard=true,
};

FOCUS_ITEMS_ACTION_SET :: Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=()=>{focus_items(.VISIBLE);},
        },
        .{
            target=.SELECTED,
            proc=()=>{focus_items(.SELECTED);},
        },
        .{
            target=.ALL_ITEMS,
            proc=()=>{focus_items(.ALL_ITEMS);},
        },
    ],
    desc="Focus camera on",
    key=#char "f",
    regular_button=true,
};

// Note: no action button
CLEAR_LABELS_ACTION_SET :: Action_Set.{
    target_action=.[
        .{
            target=.VISIBLE,
            proc=()=>{clear_all_labels(.VISIBLE);},
        },
        .{
            target=.SELECTED,
            proc=()=>{clear_all_labels(.SELECTED);},
        },
        .{
            target=.ALL_ITEMS,
            proc=()=>{clear_all_labels(.ALL_ITEMS);},
        },
    ],
    desc="Clear labels for",
    key=#char "x"
};


// EDIT_VISIBILITY_SELECTED_OP ::  Operation.{proc=()=>{kinda_toggle_is_visible(.SELECTED);},  desc="Toggle visibility on selected items", key=#char "v", mod=SELECTED_MOD};
// EDIT_VISIBILITY_ALL_ITEMS_OP :: Operation.{proc=()=>{kinda_toggle_is_visible(.ALL_ITEMS);}, desc="Toggle visibility on all items",      key=#char "v", mod=ALL_ITEMS_MOD};
// EDIT_VISIBILITY_VISIBLE_OP ::   Operation.{proc=()=>{kinda_toggle_is_visible(.VISIBLE);},   desc="Hide all visible items",              key=#char "v", mod=VISIBLE_MOD};
// EDIT_VISIBILITY_OPS :: Operation.[EDIT_VISIBILITY_SELECTED_OP, EDIT_VISIBILITY_ALL_ITEMS_OP, EDIT_VISIBILITY_VISIBLE_OP];

init_keymap :: () {

    // TODO Add options here for behaviour customizations?

    add_key(*app.keymap_keydown, toggle_fullscreen, "Toggle fullscreen", xx Special_Key_Code.F11, override_WantCaptureKeyboard=true);
    add_key(*app.keymap_keydown, toggle_show_help_ui, "Toggle help UI",  xx #char "h");
    add_key(*app.keymap_keydown, toggle_show_ui, "Toggle entire UI",  xx #char "`", .{control_pressed=true});
    add_key(*app.keymap_keydown, toggle_show_console_ui, "Toggle console UI",  xx #char "`", override_WantCaptureKeyboard=true);

    add_key(*app.keymap, select_or_deselect_all, "Select/deselect all items", xx #char "a", .{control_pressed=true});
    add_key(*app.keymap, toggle_current_selection_if_visible, "Toggle/complement visible item selection", xx #char "a", .{shift_pressed=true});
    add_key(*app.keymap, toggle_current_selection, "Toggle/complement current item selection", xx #char "a", .{alt_pressed=true});
    add_key(*app.keymap, remove_selection, "Remove selected items", xx Special_Key_Code.DELETE);
    add_key(*app.keymap, add_preset_cube, "Add preset shape - cube", xx Special_Key_Code.F1);
    add_key(*app.keymap, add_preset_widget, "Add preset shape - widget", xx Special_Key_Code.F2);
    add_key(*app.keymap, quit_application, "Quit application", xx #char "q", .{shift_pressed=true, control_pressed=true}, override_WantCaptureKeyboard=true);

    add_key(*app.keymap_actions, CYCLE_OPACITY_ACTION_SET);
    add_key(*app.keymap_actions, CYCLE_LINE_WIDTH_ACTION_SET);
    add_key(*app.keymap_actions, CYCLE_POINT_SIZE_ACTION_SET);
    add_key(*app.keymap_actions, CYCLE_ELEMENT_LABEL_ACTION_SET);
    add_key(*app.keymap_actions, CYCLE_VERTEX_LABEL_ACTION_SET);
    add_key(*app.keymap_actions, CLEAR_LABELS_ACTION_SET);
    add_key(*app.keymap_actions, CYCLE_BACKFACE_MODE_ACTION_SET);
    add_key(*app.keymap_actions, TOGGLE_CLIPPING_ACTION_SET);
    add_key(*app.keymap_actions, TOGGLE_NORMALS_ACTION_SET);
    add_key(*app.keymap_actions, FOCUS_ITEMS_ACTION_SET);
    add_key(*app.keymap_actions, RELOAD_ITEMS_ACTION_SET);

    // @Volatile button text in camera control pane should be kept in sync with keymap!
    add_key(*app.keymap, rotate_look_direction_5_cw,   "Rotate  15 deg about selected rotation axis", xx #char "]");
    add_key(*app.keymap, rotate_look_direction_5_ccw,  "Rotate -15 deg about selected rotation axis", xx #char "[");
    add_key(*app.keymap, rotate_look_direction_15_cw,  "Rotate  5  deg about selected rotation axis", xx #char "]", .{alt_pressed=true});
    add_key(*app.keymap, rotate_look_direction_15_ccw, "Rotate -5  deg about selected rotation axis", xx #char "[", .{alt_pressed=true});

    // Reserved! Do not change this binding
    add_key(*app.keymap, my_debug_function, "Call my_debug_function", xx #char " ");

    add_key :: (keymap : *Keymap, action_set : Action_Set, loc := #caller_location) {
        for action : action_set.target_action {
            mod := target_to_modifier(action.target);
            desc := get_action_description(action_set, action.target);
            add_key(keymap, action.proc, desc, action_set.key, mod, action_set.override_WantCaptureKeyboard, loc);
        }
    }

    add_key :: (keymap : *Keymap,
                proc : ()->(),
                desc : string,
                key_code : u32,
                modifier_flags : Modifier_Flags = .{},
                override_WantCaptureKeyboard := false, // @Refactor, remove this boolean and have a separate array of bindings with this bool as true
                loc := #caller_location) {

        // Check that the binding is available
        for keymap.mappings {
            if it.key_code == key_code && it.modifier_flags == modifier_flags {
                assert(false, tprint("\nError at %:%:%: Key binding for \"%\" already exists!", loc.fully_pathed_filename, loc.line_number, loc.character_number, desc));
            }
        }

        info := array_add(*keymap.procs);
        info.name = desc;
        info.proc = proc;

        // @Incomplete: This should be read from a keymap file
        mapping := array_add(*keymap.mappings);
        mapping.key_code = key_code;
        mapping.modifier_flags = modifier_flags;
        mapping.proc_info_index = keymap.procs.count - 1;
        mapping.override_WantCaptureKeyboard = override_WantCaptureKeyboard;
    }
}

//
// Bindable procedures
//

call_fit_on_screen             :: () { fit_scene_on_screen(); } // @CompilerBug? why do we need this wrapper
quit_application               :: () { app.closing_application = true; }
toggle_show_ui                 :: () { app.show_ui = !app.show_ui; }
toggle_show_help_ui            :: () { app.show_ui, app.show_help_ui    = true, !app.show_help_ui; }
rotate_look_direction_5_cw     :: () { rotate_look_direction(camera_rotation_axis(),  -5); }
rotate_look_direction_5_ccw    :: () { rotate_look_direction(camera_rotation_axis(),   5); }
rotate_look_direction_15_cw    :: () { rotate_look_direction(camera_rotation_axis(), -15); }
rotate_look_direction_15_ccw   :: () { rotate_look_direction(camera_rotation_axis(),  15); }
rotate_look_direction_45_cw    :: () { rotate_look_direction(camera_rotation_axis(), -45); }
rotate_look_direction_45_ccw   :: () { rotate_look_direction(camera_rotation_axis(),  45); }

toggle_show_console_ui :: () {
    app.show_ui, app.console.visible = true, !app.console.visible;
}

Is_Target :: (e : *Entity) -> bool #expand {
    if #complete `target == {
        case .SELECTED;  return (e.is_selected == true);
        case .VISIBLE;   return (e.display_info.is_visible  == true);
        case .ALL_ITEMS; return true;
    }
}

focus_items :: (target : Target_Items) {

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

    clip_active := any_active_clipping(target);

    // Toggle and apply it to target entities
    clip_active = !clip_active;
    for app.entities if Is_Target(it) {
        it.display_info.clip_sphere.is_active = clip_active;
        for * it.display_info.clip_ranges {
            it.is_active = clip_active;
        }
    }
}

clear_all_labels :: (target : Target_Items) {
    for app.entities if Is_Target(it) {
        it.display_info.vertex_label_style.show_index = false;
        it.display_info.vertex_label_style.show_position = false;
        it.display_info.element_label_theme.show_index = false;
        it.display_info.element_label_theme.show_position = false;
    }

    // Also clear the display info used to set action button state
    app_info : *Display_Info = *app.selection_display_info;
    app_info.vertex_label_style.show_index = false;
    app_info.vertex_label_style.show_position = false;
    app_info.element_label_theme.show_index = false;
    app_info.element_label_theme.show_position = false;
}

cycle_label_theme :: (target : Target_Items, theme : *Label_Theme) -> Fraction {

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

cycle_element_label :: (target : Target_Items) {
    theme := *app.selection_display_info.element_label_theme;

    cycle_label_theme(target, theme);

    for app.entities if Is_Target(it) {
        it.display_info.element_label_theme.show_position = theme.show_position;
        it.display_info.element_label_theme.show_index = theme.show_index;
    }
}

cycle_vertex_label :: (target : Target_Items) {
    theme := *app.selection_display_info.vertex_label_style;

    cycle_label_theme(target, theme);

    for app.entities if Is_Target(it) {
        it.display_info.vertex_label_style.show_position = theme.show_position;
        it.display_info.vertex_label_style.show_index = theme.show_index;
    }
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

cycle_point_size :: (target : Target_Items) {

    app_info := *app.selection_display_info;
    cycle_point_size_progress_proc(app_info);

    for app.entities if Is_Target(it) {
        it.display_info.points_visible = app_info.points_visible;
        it.display_info.points_size    = app_info.points_size;
    }
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

cycle_wireframe_width :: (target : Target_Items) {

    app_info := *app.selection_display_info;
    cycle_wireframe_width_progress_proc(app_info);

    for app.entities if Is_Target(it) {
        it.display_info.wireframe_visible = app_info.wireframe_visible;
        it.display_info.wireframe_width   = app_info.wireframe_width;
    }
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

cycle_opacity :: (target : Target_Items) {

    app_info := *app.selection_display_info;
    cycle_opacity_progress_proc(app_info);

    for app.entities if Is_Target(it) {
        it.display_info.surface_color.w = app_info.surface_color.w;
    }
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

cycle_backface_mode :: (target : Target_Items) {

    mode := *app.selection_display_info.backface_mode;
    cycle_backface_mode_progress_proc(mode);

    for app.entities if Is_Target(it) {
        it.display_info.backface_mode = <<mode;
    }
}

toggle_normals_visibility_progress_proc :: (using app_info : *Display_Info) -> Fraction {
    result : Fraction;
    result.numer = xx normals_visible;
    result.denom = 1;
    normals_visible = !normals_visible;
    return result;
}

toggle_normals_visibility :: (target : Target_Items) {

    app_info := *app.selection_display_info;
    toggle_normals_visibility_progress_proc(app_info);

    for app.entities if Is_Target(it) {
        it.display_info.normals_visible = app_info.normals_visible;
    }
}


/*
kinda_toggle_is_visible :: (target : Target_Items) {

    visible := false;
    for app.entities if Is_Target(it) {
        if it.display_info.is_visible {
            visible = true;
            break;
        }
    }

    // Toggle and apply it to all visible entities
    visible = !visible;
    for app.entities if Is_Target(it) {
        it.display_info.is_visible = visible;
    }
}
*/

reload_items :: (target : Target_Items) {
    for app.entities if Is_Target(it) {
        reload_entity(it);
    }
}


toggle_fullscreen :: () {
    app.fullscreen = !app.fullscreen;
    flags : u32 = ifx app.fullscreen then cast(u32) 0 else xx SDL_WindowFlags.SDL_WINDOW_FULLSCREEN_DESKTOP;
    ok := SDL_SetWindowFullscreen(app.window, flags); // @Robustness handle error
}

remove_selection :: () {
    for app.entities if it.is_selected {
        deinit(it);
        free(it);
        remove it;
    }
}

select_or_deselect_all :: () {
    mode := false;
    for app.entities if it.is_selected mode = true;
    for app.entities    it.is_selected = !mode;
}

toggle_current_selection_if_visible :: () {
    for app.entities {
        if it.display_info.is_visible {
            it.is_selected = !it.is_selected;
        }
    }
}

toggle_current_selection :: () {
    for app.entities {
        it.is_selected = !it.is_selected;
    }
}

reset_camera :: () { init_camera(); }

my_debug_function :: () {
    log(#run join("\nYou pressed SPACE!\n",
                  "This is a binding which will always be reserved for user debug functions.\n",
                  tprint("You can edit the implementation at %:%\n\n", #file, #line)));

    app.debug_frame = true;
    // Write your debug code here
}

preset_shape_proc :: ($NAME : string, $FILENAME : string, $PROC : ()->*Entity) -> *Entity {
    CONTENTS, OK :: #run read_entire_file(FILENAME);
    #assert(OK); // If this fails then FILENAME is probably invalid

    result := load_one_file_from_memory(FILENAME, CONTENTS, NAME, app.settings.duplicate_file_behaviour);

    // Update the source to be a preset
    result.source = .PRESET_SHAPE;
    free(result.fully_pathed_filename); // Must do this before we overwrite the union memory on the next line!
    result.preset_proc = PROC;
    reset_entity_primary_color(result);

    return result;
}

preset_cube_proc :: () -> *Entity {
    return preset_shape_proc("preset cube", "shapes/cube.obj", preset_cube_proc);
}

preset_widget_proc :: () -> *Entity {
    return preset_shape_proc("preset widget", "shapes/widget.obj", preset_widget_proc);
}

add_preset_cube :: () {
    entity := preset_cube_proc();
    add_entity(entity, app.settings.duplicate_file_behaviour);
    fit_scene_on_screen();
}

add_preset_widget :: () {
    entity := preset_widget_proc();
    add_entity(entity, app.settings.duplicate_file_behaviour);
    fit_scene_on_screen();
}