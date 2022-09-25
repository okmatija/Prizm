Keymap_Proc_Info :: struct {
    name: string;

    // @Cleanup Bundle these into a type
    proc: #type (data : *void) -> ();
    data : *void;
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

to_string :: (key_code : u32, modifier_flags : Modifier_Flags = .{}) -> string {
    push_allocator(temp);

    builder : String_Builder;
    init_string_builder(*builder);
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

    return builder_to_string(*builder);
}

Keymap :: struct {
    // These are fixed at startup. When you load a keymap, we bind keys to procedures from this array.
    procs : [..] Keymap_Proc_Info;

    mappings : [..] Single_Key_Mapping;
}

init_keymap :: () {

    // TODO Add options here for behaviour customizations?

    add_key(*app.keymap_keydown, (unused)=>{toggle_fullscreen();}, "Toggle fullscreen", xx Special_Key_Code.F11, override_WantCaptureKeyboard=true);
    add_key(*app.keymap_keydown, (unused)=>{toggle_show_help_ui();}, "Toggle help UI",  xx #char "h");
    add_key(*app.keymap_keydown, (unused)=>{toggle_show_ui();}, "Toggle entire UI",  xx #char "`", .{control_pressed=true});
    add_key(*app.keymap_keydown, (unused)=>{toggle_show_console_ui();}, "Toggle console UI",  xx #char "`", override_WantCaptureKeyboard=true);

    add_key(*app.keymap, (unused)=>{select_or_deselect_all();}, "Select/deselect all items", xx #char "a", .{control_pressed=true});
    add_key(*app.keymap, (unused)=>{toggle_current_selection_if_visible();}, "Toggle/complement visible item selection", xx #char "a", .{shift_pressed=true});
    add_key(*app.keymap, (unused)=>{toggle_current_selection();}, "Toggle/complement current item selection", xx #char "a", .{alt_pressed=true});
    add_key(*app.keymap, (unused)=>{remove_entities_if_selected();}, "Remove selected items", xx Special_Key_Code.DELETE);
    add_key(*app.keymap, (unused)=>{add_preset_cube();}, "Add preset shape - cube", xx Special_Key_Code.F1);
    add_key(*app.keymap, (unused)=>{add_preset_widget();}, "Add preset shape - widget", xx Special_Key_Code.F2);
    add_key(*app.keymap, (unused)=>{quit_application();}, "Quit application", xx #char "q", .{shift_pressed=true, control_pressed=true}, override_WantCaptureKeyboard=true);

    add_key(*app.keymap_actions, CYCLE_OPACITY_ACTION_SET);
    add_key(*app.keymap_actions, CYCLE_LINE_WIDTH_ACTION_SET);
    add_key(*app.keymap_actions, CYCLE_POINT_SIZE_ACTION_SET);
    add_key(*app.keymap_actions, CYCLE_ELEMENT_LABEL_ACTION_SET);
    add_key(*app.keymap_actions, CYCLE_VERTEX_LABEL_ACTION_SET);
    add_key(*app.keymap_actions, CYCLE_ANNOTATION_ACTION_SET);
    add_key(*app.keymap_actions, CLEAR_LABELS_ACTION_SET);
    add_key(*app.keymap_actions, CYCLE_BACKFACE_MODE_ACTION_SET);
    add_key(*app.keymap_actions, TOGGLE_CLIPPING_ACTION_SET);
    add_key(*app.keymap_actions, TOGGLE_NORMALS_ACTION_SET);
    add_key(*app.keymap_actions, FOCUS_ITEMS_ACTION_SET);
    add_key(*app.keymap_actions, RELOAD_ITEMS_ACTION_SET);

    // @Volatile button text in camera control pane should be kept in sync with keymap!
    add_key(*app.keymap, (unused)=>{rotate_look_direction_5_cw();},   "Rotate  15 deg about selected rotation axis", xx #char "]");
    add_key(*app.keymap, (unused)=>{rotate_look_direction_5_ccw();},  "Rotate -15 deg about selected rotation axis", xx #char "[");
    add_key(*app.keymap, (unused)=>{rotate_look_direction_15_cw();},  "Rotate  5  deg about selected rotation axis", xx #char "]", .{alt_pressed=true});
    add_key(*app.keymap, (unused)=>{rotate_look_direction_15_ccw();}, "Rotate -5  deg about selected rotation axis", xx #char "[", .{alt_pressed=true});

    // Reserved! Do not change this binding
    add_key(*app.keymap, (unused)=>{my_debug_function();}, "Call my_debug_function", xx #char " ");

    add_key :: (keymap : *Keymap, action_set : Action_Set, loc := #caller_location) {
        for action : action_set.target_action {
            mod := target_to_modifier(action.target);
            desc := get_action_description(action_set, action.target);
            add_key(keymap, action.proc, desc, action_set.key, mod, action_set.override_WantCaptureKeyboard, loc, xx *action_set.last_interaction_time);
        }
    }

    add_key :: (keymap : *Keymap,
                proc : (*void)->(),
                desc : string,
                key_code : u32,
                modifier_flags : Modifier_Flags = .{},
                override_WantCaptureKeyboard := false, // @Refactor, remove this boolean and have a separate array of bindings with this bool as true
                loc := #caller_location,
                data : *void = null) {

        // Check that the binding is available
        for keymap.mappings {
            if it.key_code == key_code && it.modifier_flags == modifier_flags {
                assert(false, tprint("\nError at %:%:%: Key binding for \"%\" already exists!", loc.fully_pathed_filename, loc.line_number, loc.character_number, desc));
            }
        }

        info := array_add(*keymap.procs);
        info.name = desc;
        info.proc = proc;
        info.data = data;

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

toggle_fullscreen :: () {
    app.fullscreen = !app.fullscreen;
    flags : u32 = ifx app.fullscreen then cast(u32) 0 else xx SDL_WindowFlags.SDL_WINDOW_FULLSCREEN_DESKTOP;
    ok := SDL_SetWindowFullscreen(app.window, flags); // @Robustness handle error
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
    assert(result.source == .FILE_ON_DISK); // because we loaded a file
    free(result.fully_pathed_name);

    result.source = .PRESET_SHAPE;
    result.fully_pathed_name = copy_string(tprint("%/%", PRESET_SHAPE_FOLDER, NAME));
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