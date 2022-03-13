Keymap_Proc_Info :: struct {
    name: string;
    proc: #type () -> ();
}

Modifier_Flags :: struct {
    shift_pressed   := false;
    control_pressed := false;
    alt_pressed     := false;
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

TOGGLE_CLIPPING_SELECTED_OP ::  Operation.{proc=()=>{toggle_clipping(.SELECTED);},  desc="Toggle clipping on selected items", key=#char "c"};
TOGGLE_CLIPPING_ALL_ITEMS_OP :: Operation.{proc=()=>{toggle_clipping(.ALL_ITEMS);}, desc="Toggle clipping on all items",      key=#char "c", mod=.{control_pressed=true}};
TOGGLE_CLIPPING_VISIBLE_OP ::   Operation.{proc=()=>{toggle_clipping(.VISIBLE);},   desc="Toggle clipping on visible items",  key=#char "c", mod=.{shift_pressed=true}};
TOGGLE_CLIPPING_OPS :: Operation.[TOGGLE_CLIPPING_SELECTED_OP, TOGGLE_CLIPPING_ALL_ITEMS_OP, TOGGLE_CLIPPING_VISIBLE_OP];

TOGGLE_NORMALS_SELECTED_OP ::  Operation.{proc=()=>{toggle_normals_visibility(.SELECTED);},  desc="Toggle normals visibility for selected items", key=#char "n"};
TOGGLE_NORMALS_ALL_ITEMS_OP :: Operation.{proc=()=>{toggle_normals_visibility(.ALL_ITEMS);}, desc="Toggle normals visibility for all items",      key=#char "n", mod=.{control_pressed=true}};
TOGGLE_NORMALS_VISIBLE_OP ::   Operation.{proc=()=>{toggle_normals_visibility(.VISIBLE);},   desc="Toggle normals visibility for visible items",  key=#char "n", mod=.{shift_pressed=true}};
TOGGLE_NORMAL_OPS :: Operation.[TOGGLE_NORMALS_SELECTED_OP, TOGGLE_NORMALS_ALL_ITEMS_OP, TOGGLE_NORMALS_VISIBLE_OP];

CYCLE_POINT_SIZE_SELECTED_OP ::  Operation.{proc=()=>{cycle_point_size(.SELECTED);},  desc="Cycle point size for selected items", key=#char "p"};
CYCLE_POINT_SIZE_ALL_ITEMS_OP :: Operation.{proc=()=>{cycle_point_size(.ALL_ITEMS);}, desc="Cycle point size for all items",      key=#char "p", mod=.{control_pressed=true}};
CYCLE_POINT_SIZE_VISIBLE_OP ::   Operation.{proc=()=>{cycle_point_size(.VISIBLE);},   desc="Cycle point size for visible items",  key=#char "p", mod=.{shift_pressed=true}};
CYCLE_POINT_SIZE_OPS :: Operation.[CYCLE_POINT_SIZE_SELECTED_OP, CYCLE_POINT_SIZE_ALL_ITEMS_OP, CYCLE_POINT_SIZE_VISIBLE_OP];

CYCLE_LINE_WIDTH_SELECTED_OP ::  Operation.{proc=()=>{cycle_wireframe_width(.SELECTED);},  desc="Cycle line width for selected items", key=#char "l"};
CYCLE_LINE_WIDTH_ALL_ITEMS_OP :: Operation.{proc=()=>{cycle_wireframe_width(.ALL_ITEMS);}, desc="Cycle line width for all items",      key=#char "l", mod=.{control_pressed=true}};
CYCLE_LINE_WIDTH_VISIBLE_OP ::   Operation.{proc=()=>{cycle_wireframe_width(.VISIBLE);},   desc="Cycle line width for visible items",  key=#char "l", mod=.{shift_pressed=true}};
CYCLE_LINE_WIDTH_OPS :: Operation.[CYCLE_LINE_WIDTH_SELECTED_OP, CYCLE_LINE_WIDTH_ALL_ITEMS_OP, CYCLE_LINE_WIDTH_VISIBLE_OP];

RELOAD_ITEMS_SELECTED_OP ::  Operation.{proc=()=>{reload_items(.SELECTED);},  desc="Reload selected items", key=cast(u32) Special_Key_Code.F5, override_WantCaptureKeyboard=true};
RELOAD_ITEMS_ALL_ITEMS_OP :: Operation.{proc=()=>{reload_items(.ALL_ITEMS);}, desc="Reload all items",      key=cast(u32) Special_Key_Code.F5, mod=.{control_pressed=true}, override_WantCaptureKeyboard=true};
RELOAD_ITEMS_VISIBLE_OP ::   Operation.{proc=()=>{reload_items(.VISIBLE);},   desc="Reload selected items", key=cast(u32) Special_Key_Code.F5, mod=.{shift_pressed=true}, override_WantCaptureKeyboard=true};
RELOAD_ITEMS_OPS :: Operation.[RELOAD_ITEMS_SELECTED_OP, RELOAD_ITEMS_ALL_ITEMS_OP, RELOAD_ITEMS_VISIBLE_OP];

TOGGLE_ELEMENT_IDS_SELECTED_OP ::  Operation.{proc=()=>{toggle_element_ids(.SELECTED);},  desc="Toggle element ids for selected items", key=#char "i"};
TOGGLE_ELEMENT_IDS_ALL_ITEMS_OP :: Operation.{proc=()=>{toggle_element_ids(.ALL_ITEMS);}, desc="Toggle element ids for all items",      key=#char "i", mod=.{control_pressed=true}};
TOGGLE_ELEMENT_IDS_VISIBLE_OP ::   Operation.{proc=()=>{toggle_element_ids(.VISIBLE);},   desc="Toggle element ids for visible items",  key=#char "i", mod=.{shift_pressed=true}};
TOGGLE_ELEMENT_IDS_OPS :: Operation.[TOGGLE_ELEMENT_IDS_SELECTED_OP, TOGGLE_ELEMENT_IDS_ALL_ITEMS_OP, TOGGLE_ELEMENT_IDS_VISIBLE_OP];

TOGGLE_ELEMENT_POSITIONS_SELECTED_OP ::  Operation.{proc=()=>{toggle_element_positions(.SELECTED);},  desc="Toggle element positions for selected items", key=#char "o"};
TOGGLE_ELEMENT_POSITIONS_ALL_ITEMS_OP :: Operation.{proc=()=>{toggle_element_positions(.ALL_ITEMS);}, desc="Toggle element positions for all items",      key=#char "o", mod=.{control_pressed=true}};
TOGGLE_ELEMENT_POSITIONS_VISIBLE_OP ::   Operation.{proc=()=>{toggle_element_positions(.VISIBLE);},   desc="Toggle element positions for visible items",  key=#char "o", mod=.{shift_pressed=true}};
TOGGLE_ELEMENT_POSITIONS_OPS :: Operation.[TOGGLE_ELEMENT_POSITIONS_SELECTED_OP, TOGGLE_ELEMENT_POSITIONS_ALL_ITEMS_OP, TOGGLE_ELEMENT_POSITIONS_VISIBLE_OP];

TOGGLE_VERTEX_IDS_SELECTED_OP ::  Operation.{proc=()=>{toggle_vertex_ids(.SELECTED);},  desc="Toggle vertex ids for selected items", key=#char "j"};
TOGGLE_VERTEX_IDS_ALL_ITEMS_OP :: Operation.{proc=()=>{toggle_vertex_ids(.ALL_ITEMS);}, desc="Toggle vertex ids for all items",      key=#char "j", mod=.{control_pressed=true}};
TOGGLE_VERTEX_IDS_VISIBLE_OP ::   Operation.{proc=()=>{toggle_vertex_ids(.VISIBLE);},   desc="Toggle vertex ids for visible items",  key=#char "j", mod=.{shift_pressed=true}};
TOGGLE_VERTEX_IDS_OPS :: Operation.[TOGGLE_VERTEX_IDS_SELECTED_OP, TOGGLE_VERTEX_IDS_ALL_ITEMS_OP, TOGGLE_VERTEX_IDS_VISIBLE_OP];

TOGGLE_VERTEX_POSITIONS_SELECTED_OP ::  Operation.{proc=()=>{toggle_vertex_positions(.SELECTED);},  desc="Toggle vertex positions for selected items", key=#char "k"};
TOGGLE_VERTEX_POSITIONS_ALL_ITEMS_OP :: Operation.{proc=()=>{toggle_vertex_positions(.ALL_ITEMS);}, desc="Toggle vertex positions for all items",      key=#char "k", mod=.{control_pressed=true}};
TOGGLE_VERTEX_POSITIONS_VISIBLE_OP ::   Operation.{proc=()=>{toggle_vertex_positions(.VISIBLE);},   desc="Toggle vertex positions for visible items",  key=#char "k", mod=.{shift_pressed=true}};
TOGGLE_VERTEX_POSITIONS_OPS :: Operation.[TOGGLE_VERTEX_POSITIONS_SELECTED_OP, TOGGLE_VERTEX_POSITIONS_ALL_ITEMS_OP, TOGGLE_VERTEX_POSITIONS_VISIBLE_OP];

init_keymap :: () {

    // TODO Add options here for behaviour customizations?

    add_key(*app.keymap_keydown, toggle_fullscreen, "Toggle fullscreen", xx Special_Key_Code.F11, override_WantCaptureKeyboard=true);
    add_key(*app.keymap_keydown, toggle_show_help_ui, "Toggle help UI",  xx #char "h");
    add_key(*app.keymap_keydown, toggle_show_ui, "Toggle entire UI",  xx #char "`");
    add_key(*app.keymap_keydown, toggle_show_console_ui, "Toggle console UI",  xx #char "`", .{control_pressed=true}, override_WantCaptureKeyboard=true);
    add_key(*app.keymap_keydown, toggle_selection_mode, "Toggle Selection Mode",  xx #char "s"); // @Volatile keep synced with SELECTION_MODE_TOOLTIP

    add_key(*app.keymap, quit_application, "Quit application", xx #char "q", .{shift_pressed=true, control_pressed=true}, override_WantCaptureKeyboard=true);
    add_key(*app.keymap, call_fit_on_screen, "Fit on screen", xx #char "r");
    add_key(*app.keymap, reset_camera, "Reset camera", xx #char "r", .{shift_pressed=true});

    // @Incomplete Refactor these to fit the k, C-k, S-k pattern?
    add_key(*app.keymap, select_or_deselect_all, "Select/deselect all items", xx #char "a", .{control_pressed=true});
    add_key(*app.keymap, toggle_current_selection_if_visible, "Toggle/complement visible item selection", xx #char "a", .{shift_pressed=true});
    add_key(*app.keymap, toggle_current_selection, "Toggle/complement current item selection", xx #char "a", .{alt_pressed=true});

    add_key(*app.keymap, remove_selection, "Remove selected items", xx Special_Key_Code.DELETE);

    add_key(*app.keymap, TOGGLE_CLIPPING_SELECTED_OP);
    add_key(*app.keymap, TOGGLE_CLIPPING_ALL_ITEMS_OP);
    add_key(*app.keymap, TOGGLE_CLIPPING_VISIBLE_OP);

    add_key(*app.keymap, TOGGLE_NORMALS_SELECTED_OP);
    add_key(*app.keymap, TOGGLE_NORMALS_ALL_ITEMS_OP);
    add_key(*app.keymap, TOGGLE_NORMALS_VISIBLE_OP);

    add_key(*app.keymap, CYCLE_POINT_SIZE_SELECTED_OP);
    add_key(*app.keymap, CYCLE_POINT_SIZE_ALL_ITEMS_OP);
    add_key(*app.keymap, CYCLE_POINT_SIZE_VISIBLE_OP);

    add_key(*app.keymap, CYCLE_LINE_WIDTH_SELECTED_OP);
    add_key(*app.keymap, CYCLE_LINE_WIDTH_ALL_ITEMS_OP);
    add_key(*app.keymap, CYCLE_LINE_WIDTH_VISIBLE_OP);

    add_key(*app.keymap, RELOAD_ITEMS_SELECTED_OP);
    add_key(*app.keymap, RELOAD_ITEMS_ALL_ITEMS_OP);
    add_key(*app.keymap, RELOAD_ITEMS_VISIBLE_OP);

    add_key(*app.keymap, TOGGLE_ELEMENT_IDS_SELECTED_OP);
    add_key(*app.keymap, TOGGLE_ELEMENT_IDS_ALL_ITEMS_OP);
    add_key(*app.keymap, TOGGLE_ELEMENT_IDS_VISIBLE_OP);

    add_key(*app.keymap, TOGGLE_VERTEX_IDS_SELECTED_OP);
    add_key(*app.keymap, TOGGLE_VERTEX_IDS_ALL_ITEMS_OP);
    add_key(*app.keymap, TOGGLE_VERTEX_IDS_VISIBLE_OP);

    add_key(*app.keymap, TOGGLE_ELEMENT_POSITIONS_SELECTED_OP);
    add_key(*app.keymap, TOGGLE_ELEMENT_POSITIONS_ALL_ITEMS_OP);
    add_key(*app.keymap, TOGGLE_ELEMENT_POSITIONS_VISIBLE_OP);

    add_key(*app.keymap, TOGGLE_VERTEX_POSITIONS_SELECTED_OP);
    add_key(*app.keymap, TOGGLE_VERTEX_POSITIONS_ALL_ITEMS_OP);
    add_key(*app.keymap, TOGGLE_VERTEX_POSITIONS_VISIBLE_OP);

    add_key(*app.keymap, ()=>{toggle_is_visible(.SELECTED);},  "Toggle visibility on selected items", xx #char "v");
    add_key(*app.keymap, ()=>{toggle_is_visible(.ALL_ITEMS);}, "Toggle visibility on all items", xx #char "v", .{control_pressed=true});
    add_key(*app.keymap, ()=>{toggle_is_visible(.VISIBLE);},   "Toggle visibility on visible items (Hide all items)", xx #char "v", .{shift_pressed=true});

    add_key(*app.keymap, ()=>{cycle_opacity(.SELECTED);},  "Cycle opacity 20%%/50%%/100%% for selected items", xx #char "t");
    add_key(*app.keymap, ()=>{cycle_opacity(.ALL_ITEMS);}, "Cycle opacity 20%%/50%%/100%% for all items", xx #char "t", .{control_pressed=true});
    add_key(*app.keymap, ()=>{cycle_opacity(.VISIBLE);},   "Cycle opacity 20%%/50%%/100%% for visible items", xx #char "t", .{shift_pressed=true});

    // @Volatile button text in camera control pane should be kept in sync with keymap!
    add_key(*app.keymap, rotate_look_direction_5_cw,   "Rotate  15 deg about selected rotation axis", xx #char "]");
    add_key(*app.keymap, rotate_look_direction_5_ccw,  "Rotate -15 deg about selected rotation axis", xx #char "[");
    add_key(*app.keymap, rotate_look_direction_15_cw,  "Rotate  5  deg about selected rotation axis", xx #char "]", .{alt_pressed=true});
    add_key(*app.keymap, rotate_look_direction_15_ccw, "Rotate -5  deg about selected rotation axis", xx #char "[", .{alt_pressed=true});

    // Reserved! Do not change this binding
    add_key(*app.keymap, my_debug_function, "Call my_debug_function", xx #char " ");

    add_key :: (keymap : *Keymap,
                op : Operation, 
                loc := #caller_location) {
        add_key(keymap, op.proc, op.desc, op.key, op.mod, op.override_WantCaptureKeyboard, loc);
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
toggle_show_console_ui         :: () { app.show_ui, app.show_console_ui = true, !app.show_console_ui; }
toggle_selection_mode          :: () { app.user_selection.is_visible = !app.user_selection.is_visible; }
rotate_look_direction_5_cw     :: () { rotate_look_direction(camera_rotation_axis(),  -5); }
rotate_look_direction_5_ccw    :: () { rotate_look_direction(camera_rotation_axis(),   5); }
rotate_look_direction_15_cw    :: () { rotate_look_direction(camera_rotation_axis(), -15); }
rotate_look_direction_15_ccw   :: () { rotate_look_direction(camera_rotation_axis(),  15); }
rotate_look_direction_45_cw    :: () { rotate_look_direction(camera_rotation_axis(), -45); }
rotate_look_direction_45_ccw   :: () { rotate_look_direction(camera_rotation_axis(),  45); }

Is_Target :: (e : *Entity) -> bool #expand {
    if #complete `target == {
        case .SELECTED;  return (e.is_selected == true);
        case .VISIBLE;   return (e.is_visible  == true);
        case .ALL_ITEMS; return true;
    }
}

toggle_clipping :: (target : Target_Items) {

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
        it.display_info.vertex_label_style.show_index = false;
        it.display_info.element_label_theme.show_index = false;
        it.display_info.element_label_theme.show_index = false;
    }
}

toggle_vertex_ids :: (target : Target_Items) {
    app_style := *app.selection_display_info.vertex_label_style;
    app_style.show_index = !app_style.show_index;
    for app.entities if Is_Target(it) {
        it.display_info.vertex_label_style.show_index = app_style.show_index;
    }
}

toggle_element_ids :: (target : Target_Items) {
    app_style := *app.selection_display_info.element_label_theme;
    app_style.show_index = !app_style.show_index;
    for app.entities if Is_Target(it) {
        it.display_info.element_label_theme.show_index = app_style.show_index;
    }
}

toggle_vertex_positions :: (target : Target_Items) {
    app_style := *app.selection_display_info.vertex_label_style;
    app_style.show_position = !app_style.show_position;
    for app.entities if Is_Target(it) {
        it.display_info.vertex_label_style.show_position = app_style.show_position;
    }
}

toggle_element_positions :: (target : Target_Items) {
    app_style := *app.selection_display_info.element_label_theme;
    app_style.show_position = !app_style.show_position;
    for app.entities if Is_Target(it) {
        it.display_info.element_label_theme.show_position = app_style.show_position;
    }
}

cycle_point_size :: (target : Target_Items) {
    app_info := *app.selection_display_info;
    {
        using app_info;
        if !points_visible {
            points_visible = true;
            points_size = 2;
        } else if points_size == 2 {
            points_size += 2;
        } else {
            points_visible = false;
        }
    }

    for app.entities if Is_Target(it) {
        it.display_info.points_visible = app_info.points_visible;
        it.display_info.points_size    = app_info.points_size;
    }
}

cycle_wireframe_width :: (target : Target_Items) {
    app_info := *app.selection_display_info;
    {
        using app_info;
        if !wireframe_visible {
            wireframe_visible = true;
            wireframe_width = 1;
        } else if wireframe_width == 1 {
            wireframe_width += 1;
        } else if wireframe_width == 2 {
            wireframe_width += 1;
        } else {
            wireframe_visible = false;
        }
    }

    for app.entities if Is_Target(it) {
        it.display_info.wireframe_visible = app_info.wireframe_visible;
        it.display_info.wireframe_width   = app_info.wireframe_width;
    }
}

cycle_opacity :: (target : Target_Items) {

    app_info := *app.selection_display_info;
    if      app_info.surface_color.w == 1.  app_info.surface_color.w = .5;
    else if app_info.surface_color.w == .5  app_info.surface_color.w = .2;
    else    app_info.surface_color.w =  1.;

    for app.entities if Is_Target(it) {
        it.display_info.surface_color.w = app_info.surface_color.w;
    }
}

toggle_normals_visibility :: (target : Target_Items) {

    app_info := *app.selection_display_info;
    app_info.normals_visible = !app_info.normals_visible;

    for app.entities if Is_Target(it) {
        it.display_info.normals_visible = app_info.normals_visible;
    }
}


toggle_is_visible :: (target : Target_Items) {

    visible := false;
    for app.entities if Is_Target(it) {
        if it.is_visible {
            visible = true;
            break;
        }
    }

    // Toggle and apply it to all visible entities
    visible = !visible;
    for app.entities if Is_Target(it) {
        it.is_visible = visible;
    }
}

reload_items :: (target : Target_Items) {
    for app.entities if Is_Target(it) {
        app.entities[it_index] = reload_entity(it);
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
        if it.is_visible {
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

    // Write your debug code here
}
