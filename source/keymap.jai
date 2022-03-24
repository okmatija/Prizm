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

ALL_ITEMS_MOD :: Modifier_Flags.{shift_pressed=true};
SELECTED_MOD :: Modifier_Flags.{control_pressed=true};
VISIBLE_MOD :: Modifier_Flags.{};

TOGGLE_CLIPPING_SELECTED_OP ::  Operation.{proc=()=>{toggle_clipping(.SELECTED);},  desc="Toggle clipping on selected items", key=#char "c", mod=SELECTED_MOD};
TOGGLE_CLIPPING_ALL_ITEMS_OP :: Operation.{proc=()=>{toggle_clipping(.ALL_ITEMS);}, desc="Toggle clipping on all items",      key=#char "c", mod=ALL_ITEMS_MOD};
TOGGLE_CLIPPING_VISIBLE_OP ::   Operation.{proc=()=>{toggle_clipping(.VISIBLE);},   desc="Toggle clipping on visible items",  key=#char "c", mod=VISIBLE_MOD};
TOGGLE_CLIPPING_OPS :: Operation.[TOGGLE_CLIPPING_SELECTED_OP, TOGGLE_CLIPPING_ALL_ITEMS_OP, TOGGLE_CLIPPING_VISIBLE_OP];

TOGGLE_NORMALS_SELECTED_OP ::  Operation.{proc=()=>{toggle_normals_visibility(.SELECTED);},  desc="Toggle normals visibility for selected items", key=#char "n", mod=SELECTED_MOD};
TOGGLE_NORMALS_ALL_ITEMS_OP :: Operation.{proc=()=>{toggle_normals_visibility(.ALL_ITEMS);}, desc="Toggle normals visibility for all items",      key=#char "n", mod=ALL_ITEMS_MOD};
TOGGLE_NORMALS_VISIBLE_OP ::   Operation.{proc=()=>{toggle_normals_visibility(.VISIBLE);},   desc="Toggle normals visibility for visible items",  key=#char "n", mod=VISIBLE_MOD};
TOGGLE_NORMALS_OPS :: Operation.[TOGGLE_NORMALS_SELECTED_OP, TOGGLE_NORMALS_ALL_ITEMS_OP, TOGGLE_NORMALS_VISIBLE_OP];

CYCLE_POINT_SIZE_SELECTED_OP ::  Operation.{proc=()=>{cycle_point_size(.SELECTED);},  desc="Cycle point size for selected items", key=#char "p", mod=SELECTED_MOD};
CYCLE_POINT_SIZE_ALL_ITEMS_OP :: Operation.{proc=()=>{cycle_point_size(.ALL_ITEMS);}, desc="Cycle point size for all items",      key=#char "p", mod=ALL_ITEMS_MOD};
CYCLE_POINT_SIZE_VISIBLE_OP ::   Operation.{proc=()=>{cycle_point_size(.VISIBLE);},   desc="Cycle point size for visible items",  key=#char "p", mod=VISIBLE_MOD};
CYCLE_POINT_SIZE_OPS :: Operation.[CYCLE_POINT_SIZE_SELECTED_OP, CYCLE_POINT_SIZE_ALL_ITEMS_OP, CYCLE_POINT_SIZE_VISIBLE_OP];

CYCLE_LINE_WIDTH_SELECTED_OP ::  Operation.{proc=()=>{cycle_wireframe_width(.SELECTED);},  desc="Cycle line width for selected items", key=#char "l", mod=SELECTED_MOD};
CYCLE_LINE_WIDTH_ALL_ITEMS_OP :: Operation.{proc=()=>{cycle_wireframe_width(.ALL_ITEMS);}, desc="Cycle line width for all items",      key=#char "l", mod=ALL_ITEMS_MOD};
CYCLE_LINE_WIDTH_VISIBLE_OP ::   Operation.{proc=()=>{cycle_wireframe_width(.VISIBLE);},   desc="Cycle line width for visible items",  key=#char "l", mod=VISIBLE_MOD};
CYCLE_LINE_WIDTH_OPS :: Operation.[CYCLE_LINE_WIDTH_SELECTED_OP, CYCLE_LINE_WIDTH_ALL_ITEMS_OP, CYCLE_LINE_WIDTH_VISIBLE_OP];

RELOAD_ITEMS_SELECTED_OP ::  Operation.{proc=()=>{reload_items(.SELECTED);},  desc="Reload selected items", key=cast(u32) Special_Key_Code.F5, mod=SELECTED_MOD, override_WantCaptureKeyboard=true};
RELOAD_ITEMS_ALL_ITEMS_OP :: Operation.{proc=()=>{reload_items(.ALL_ITEMS);}, desc="Reload all items",      key=cast(u32) Special_Key_Code.F5, mod=ALL_ITEMS_MOD, override_WantCaptureKeyboard=true};
RELOAD_ITEMS_VISIBLE_OP ::   Operation.{proc=()=>{reload_items(.VISIBLE);},   desc="Reload visible items",  key=cast(u32) Special_Key_Code.F5, mod=VISIBLE_MOD, override_WantCaptureKeyboard=true};
RELOAD_ITEMS_OPS :: Operation.[RELOAD_ITEMS_SELECTED_OP, RELOAD_ITEMS_ALL_ITEMS_OP, RELOAD_ITEMS_VISIBLE_OP];

CYCLE_ELEMENT_LABEL_SELECTED_OP ::  Operation.{proc=()=>{cycle_element_label(.SELECTED);},  desc="Cycle element labels for selected items", key=#char "i", mod=SELECTED_MOD};
CYCLE_ELEMENT_LABEL_ALL_ITEMS_OP :: Operation.{proc=()=>{cycle_element_label(.ALL_ITEMS);}, desc="Cycle element labels for all items",      key=#char "i", mod=ALL_ITEMS_MOD};
CYCLE_ELEMENT_LABEL_VISIBLE_OP ::   Operation.{proc=()=>{cycle_element_label(.VISIBLE);},   desc="Cycle element labels for visible items",  key=#char "i", mod=VISIBLE_MOD};
CYCLE_ELEMENT_LABEL_OPS :: Operation.[CYCLE_ELEMENT_LABEL_SELECTED_OP, CYCLE_ELEMENT_LABEL_ALL_ITEMS_OP, CYCLE_ELEMENT_LABEL_VISIBLE_OP];

CYCLE_VERTEX_LABEL_SELECTED_OP ::  Operation.{proc=()=>{cycle_vertex_label(.SELECTED);},  desc="Cycle vertex labels for selected items", key=#char "j", mod=SELECTED_MOD};
CYCLE_VERTEX_LABEL_ALL_ITEMS_OP :: Operation.{proc=()=>{cycle_vertex_label(.ALL_ITEMS);}, desc="Cycle vertex labels for all items",      key=#char "j", mod=ALL_ITEMS_MOD};
CYCLE_VERTEX_LABEL_VISIBLE_OP ::   Operation.{proc=()=>{cycle_vertex_label(.VISIBLE);},   desc="Cycle vertex labels for visible items",  key=#char "j", mod=VISIBLE_MOD};
CYCLE_VERTEX_LABEL_OPS :: Operation.[CYCLE_VERTEX_LABEL_SELECTED_OP, CYCLE_VERTEX_LABEL_ALL_ITEMS_OP, CYCLE_VERTEX_LABEL_VISIBLE_OP];

CYCLE_OPACITY_SELECTED_OP ::  Operation.{proc=()=>{cycle_opacity(.SELECTED);},  desc="Cycle opacity 20%%/50%%/100%% for selected items", key=#char "o", mod=SELECTED_MOD};
CYCLE_OPACITY_ALL_ITEMS_OP :: Operation.{proc=()=>{cycle_opacity(.ALL_ITEMS);}, desc="Cycle opacity 20%%/50%%/100%% for all items",      key=#char "o", mod=ALL_ITEMS_MOD};
CYCLE_OPACITY_VISIBLE_OP ::   Operation.{proc=()=>{cycle_opacity(.VISIBLE);},   desc="Cycle opacity 20%%/50%%/100%% for visible items",  key=#char "o", mod=VISIBLE_MOD};
CYCLE_OPACITY_OPS :: Operation.[CYCLE_OPACITY_SELECTED_OP, CYCLE_OPACITY_ALL_ITEMS_OP, CYCLE_OPACITY_VISIBLE_OP];

EDIT_VISIBILITY_SELECTED_OP ::  Operation.{proc=()=>{kinda_toggle_is_visible(.SELECTED);},  desc="Toggle visibility on selected items", key=#char "v", mod=SELECTED_MOD};
EDIT_VISIBILITY_ALL_ITEMS_OP :: Operation.{proc=()=>{kinda_toggle_is_visible(.ALL_ITEMS);}, desc="Toggle visibility on all items",      key=#char "v", mod=ALL_ITEMS_MOD};
EDIT_VISIBILITY_VISIBLE_OP ::   Operation.{proc=()=>{kinda_toggle_is_visible(.VISIBLE);},   desc="Hide all visible items",              key=#char "v", mod=VISIBLE_MOD};
EDIT_VISIBILITY_OPS :: Operation.[EDIT_VISIBILITY_SELECTED_OP, EDIT_VISIBILITY_ALL_ITEMS_OP, EDIT_VISIBILITY_VISIBLE_OP];

FOCUS_ITEMS_SELECTED_OP ::  Operation.{proc=()=>{focus_items(.SELECTED);},  desc="Focus camera on selected items", key=#char "f", mod=SELECTED_MOD};
FOCUS_ITEMS_ALL_ITEMS_OP :: Operation.{proc=()=>{focus_items(.ALL_ITEMS);}, desc="Focus camera on all items",      key=#char "f", mod=ALL_ITEMS_MOD};
FOCUS_ITEMS_VISIBLE_OP ::   Operation.{proc=()=>{focus_items(.VISIBLE);},   desc="Focus camera on visible items",  key=#char "f", mod=VISIBLE_MOD};
FOCUS_ITEMS_OPS :: Operation.[FOCUS_ITEMS_SELECTED_OP, FOCUS_ITEMS_ALL_ITEMS_OP, FOCUS_ITEMS_VISIBLE_OP];

CYCLE_BACKFACE_MODE_SELECTED_OP ::  Operation.{proc=()=>{cycle_backface_mode(.SELECTED);},  desc="Cycle backface rendering mode for selected items", key=#char "b", mod=SELECTED_MOD};
CYCLE_BACKFACE_MODE_ALL_ITEMS_OP :: Operation.{proc=()=>{cycle_backface_mode(.ALL_ITEMS);}, desc="Cycle backface rendering mode for all items",      key=#char "b", mod=ALL_ITEMS_MOD};
CYCLE_BACKFACE_MODE_VISIBLE_OP ::   Operation.{proc=()=>{cycle_backface_mode(.VISIBLE);},   desc="Cycle backface rendering mode for visible items",  key=#char "b", mod=VISIBLE_MOD};
CYCLE_BACKFACE_MODE_OPS :: Operation.[CYCLE_BACKFACE_MODE_SELECTED_OP, CYCLE_BACKFACE_MODE_ALL_ITEMS_OP, CYCLE_BACKFACE_MODE_VISIBLE_OP];

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
    add_key(*app.keymap, quit_application, "Quit application", xx #char "q", .{shift_pressed=true, control_pressed=true}, override_WantCaptureKeyboard=true);

    add_key(*app.keymap_actions, ..EDIT_VISIBILITY_OPS);
    add_key(*app.keymap_actions, ..CYCLE_OPACITY_OPS);
    add_key(*app.keymap_actions, ..CYCLE_LINE_WIDTH_OPS);
    add_key(*app.keymap_actions, ..CYCLE_POINT_SIZE_OPS);
    add_key(*app.keymap_actions, ..CYCLE_ELEMENT_LABEL_OPS);
    add_key(*app.keymap_actions, ..CYCLE_VERTEX_LABEL_OPS);
    add_key(*app.keymap_actions, ..TOGGLE_CLIPPING_OPS);
    add_key(*app.keymap_actions, ..TOGGLE_NORMALS_OPS);
    add_key(*app.keymap_actions, ..FOCUS_ITEMS_OPS);
    add_key(*app.keymap_actions, ..RELOAD_ITEMS_OPS);

    // @Volatile button text in camera control pane should be kept in sync with keymap!
    add_key(*app.keymap, rotate_look_direction_5_cw,   "Rotate  15 deg about selected rotation axis", xx #char "]");
    add_key(*app.keymap, rotate_look_direction_5_ccw,  "Rotate -15 deg about selected rotation axis", xx #char "[");
    add_key(*app.keymap, rotate_look_direction_15_cw,  "Rotate  5  deg about selected rotation axis", xx #char "]", .{alt_pressed=true});
    add_key(*app.keymap, rotate_look_direction_15_ccw, "Rotate -5  deg about selected rotation axis", xx #char "[", .{alt_pressed=true});

    // Reserved! Do not change this binding
    add_key(*app.keymap, my_debug_function, "Call my_debug_function", xx #char " ");

    add_key :: (keymap : *Keymap,
                ops : ..Operation, 
                loc := #caller_location) {
        for op : ops {
            add_key(keymap, op.proc, op.desc, op.key, op.mod, op.override_WantCaptureKeyboard, loc);
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
        case .VISIBLE;   return (e.is_visible  == true);
        case .ALL_ITEMS; return true;
    }
}

focus_items :: (target : Target_Items) {

    sphere : Sphere;

    if #complete target == {
        case .ALL_ITEMS;
            sphere = entities_bounding_sphere();
        case .VISIBLE;
            sphere = entities_bounding_sphere((e)=>(e.is_visible));
        case .SELECTED;
            sphere = entities_bounding_sphere((e)=>(e.is_selected));
    }

    if sphere.radius > 0 {
        fit_sphere_on_screen(sphere, sphere.radius);
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

cycle_label_theme :: (target : Target_Items, theme : *Label_Theme) {

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
        case .INDEX_OFF_POSITION_OFF; state = .INDEX_ON_POSITION_OFF;
        case .INDEX_ON_POSITION_OFF;  state = .INDEX_ON_POSITION_ON;
        case .INDEX_ON_POSITION_ON;   state = .INDEX_OFF_POSITION_ON;
        case .INDEX_OFF_POSITION_ON;  state = .INDEX_OFF_POSITION_OFF;
    }

    // Set theme from State
    theme.show_index, theme.show_position = (xx state & 0b01), (xx state & 0b10);
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

cycle_point_size :: (target : Target_Items) {
    app_info := *app.selection_display_info;
    {
        using app_info;
        if !points_visible {
            points_visible = true;
            points_size = 2;
        } else if points_size == 2 {
            points_size += 2;
        } else if points_size == 4 {
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

cycle_backface_mode :: (target : Target_Items) {

    mode := *app.selection_display_info.backface_mode;
    if #complete <<mode == {
        case .NONE;         <<mode = .CULL;
        case .CULL;         <<mode = .FIXED;
        case .FIXED;        <<mode = .DARKEN; 
        case .DARKEN;       <<mode = .SCREENTONE_1;
        case .SCREENTONE_1; <<mode = .SCREENTONE_2;
        case .SCREENTONE_2; <<mode = .NONE;
    }

    for app.entities if Is_Target(it) {
        it.display_info.backface_mode = <<mode;
    }
}

toggle_normals_visibility :: (target : Target_Items) {

    app_info := *app.selection_display_info;
    app_info.normals_visible = !app_info.normals_visible;

    for app.entities if Is_Target(it) {
        it.display_info.normals_visible = app_info.normals_visible;
    }
}


kinda_toggle_is_visible :: (target : Target_Items) {

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
