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

viewport_capture_mouse :: () -> bool {
    if io().WantCaptureMouse || !ImGui.IsMousePosValid(*io().MousePos) {
        return false;
    }
    return true;
}

mouse_toggle_in_selection :: () -> bool {
    return ImGui.IsMouseClicked(.Left) &&
        io().KeyCtrl &&
        !io().KeyShift &&
        !io().KeyAlt;
}

mouse_set_selection :: () -> bool {
    return ImGui.IsMouseClicked(.Left) &&
        !io().KeyCtrl &&
        !io().KeyShift &&
        !io().KeyAlt;
}

mouse_toggle_in_geometry_selection :: () -> bool {
    return mouse_toggle_in_selection() && app.select_tool.entity.display_info.is_visible;
}

mouse_set_geometry_selection :: () -> bool {
    return mouse_set_selection() && app.select_tool.entity.display_info.is_visible;
}

mouse_toggle_in_item_selection :: () -> bool {
    return mouse_toggle_in_selection() && !app.select_tool.entity.display_info.is_visible;
}

mouse_set_item_selection :: () -> bool {
    return mouse_set_selection() && !app.select_tool.entity.display_info.is_visible;
}

mouse_reposition_camera :: () -> bool {
    if io().WantCaptureMouse || !ImGui.IsMousePosValid(*io().MousePos) {
        return false;
    }
    return ImGui.IsMouseClicked(.Right) && io().KeyCtrl;
}
mouse_init_clip_center :: () -> bool {
    if io().WantCaptureMouse || !ImGui.IsMousePosValid(*io().MousePos) {
        return false;
    }
    return ImGui.IsMouseClicked(.Left) && io().KeyShift;
}

mouse_set_clip_radius :: () -> bool {
    if io().WantCaptureMouse || !ImGui.IsMousePosValid(*io().MousePos) {
        return false;
    }
    return ImGui.IsMouseDown(.Left) && io().KeyShift;
}

init_keymap :: () {

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

    add_key :: (keymap : *Keymap, using action_set : Action_Set, loc := #caller_location) {
        add_key(keymap, proc, desc, key, .{}, override_WantCaptureKeyboard, loc, xx *last_interaction_time);
    }

    // TODO Add options here for behaviour customizations?

    add_key(*app.keymap_keydown, (_)=>{toggle_fullscreen();}, "Toggle fullscreen", xx Special_Key_Code.F11, override_WantCaptureKeyboard=true);
    add_key(*app.keymap_keydown, (_)=>{toggle_show_ui();}, "Toggle entire UI",  xx #char "`", .{control_pressed=true});
    add_key(*app.keymap_keydown, (_)=>{toggle_show_console_ui();}, "Toggle console UI",  xx #char "`", override_WantCaptureKeyboard=true);

    // :SelectionKeybindTooltip @Volatile @Cleanup Keep this in sync with the tooltip
    add_key(*app.keymap, (_)=>{quit_application();}, "Quit application", xx #char "q", .{shift_pressed=true, control_pressed=true}, override_WantCaptureKeyboard=true);
    add_key(*app.keymap, (_)=>{select_or_deselect_all();}, "Select/deselect all items", xx #char "a", .{control_pressed=true});
    add_key(*app.keymap, (_)=>{select_or_deselect_visible();}, "Select/deselect visible items", xx #char "a", .{shift_pressed=true});
    add_key(*app.keymap, (_)=>{toggle_current_selection();}, "Toggle/complement current item selection", xx #char "a", .{alt_pressed=true});

    add_key(*app.keymap, (_)=>{remove_entities_if_selected();}, "Remove selected items", xx Special_Key_Code.DELETE);
    // @FIXME Make these presets work with the alt key like the button
    add_key(*app.keymap, (_)=>{add_preset_cube();}, "Add Preset Cube", xx Special_Key_Code.F1); // @Cleanup Hidden modifier alt makes this fixed
    add_key(*app.keymap, (_)=>{add_preset_widget();}, "Add Preset Widget", xx Special_Key_Code.F2); // @Cleanup Hidden modifier alt makes this fixed
    add_key(*app.keymap, (_)=>{add_preset_boolean_a();}, "Add Preset BooleanA", xx Special_Key_Code.F3); // @Cleanup Hidden modifier alt makes this fixed
    add_key(*app.keymap, (_)=>{add_preset_boolean_b();}, "Add Preset BooleanB", xx Special_Key_Code.F4); // @Cleanup Hidden modifier alt makes this fixed

    add_key(*app.keymap_actions, CYCLE_OPACITY_ACTION_SET);
    add_key(*app.keymap_actions, CYCLE_LINE_WIDTH_ACTION_SET);
    add_key(*app.keymap_actions, CYCLE_VERTEX_SIZE_ACTION_SET);
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
    add_key(*app.keymap, (_)=>{rotate_look_direction_5_cw();},   "Rotate  15 deg about selected rotation axis", xx #char "]");
    add_key(*app.keymap, (_)=>{rotate_look_direction_5_ccw();},  "Rotate -15 deg about selected rotation axis", xx #char "[");
    add_key(*app.keymap, (_)=>{rotate_look_direction_15_cw();},  "Rotate  5  deg about selected rotation axis", xx #char "]", .{alt_pressed=true});
    add_key(*app.keymap, (_)=>{rotate_look_direction_15_ccw();}, "Rotate -5  deg about selected rotation axis", xx #char "[", .{alt_pressed=true});

    // Reserved! Do not change this binding
    add_key(*app.keymap, (_)=>{my_debug_function();}, "Call my_debug_function", xx #char " ");
}

//
// Bindable procedures
//

quit_application               :: () { app.closing_application = true; }
toggle_show_ui                 :: () { app.show_ui = !app.show_ui; }
rotate_look_direction_5_cw     :: () { rotate_look_direction(camera_rotation_axis(),  -5); }
rotate_look_direction_5_ccw    :: () { rotate_look_direction(camera_rotation_axis(),   5); }
rotate_look_direction_15_cw    :: () { rotate_look_direction(camera_rotation_axis(), -15); }
rotate_look_direction_15_ccw   :: () { rotate_look_direction(camera_rotation_axis(),  15); }
rotate_look_direction_45_cw    :: () { rotate_look_direction(camera_rotation_axis(), -45); }
rotate_look_direction_45_ccw   :: () { rotate_look_direction(camera_rotation_axis(),  45); }

toggle_show_console_ui :: () {
    app.show_ui, app.console.show_ui = true, !app.console.show_ui;
}

toggle_fullscreen :: () {
    app.fullscreen = !app.fullscreen;
    flags : u32 = ifx app.fullscreen then cast(u32) 0 else xx SDL_WindowFlags.SDL_WINDOW_FULLSCREEN_DESKTOP;
    ok := SDL_SetWindowFullscreen(app.window, flags); // @Robustness handle error
}

select_or_deselect_all :: () {
    // Two options for state transitionse:
    //
    //       any selected -> none selected <-> all selected
    //       any selected -> all selected  <-> none selected
    //
    // The second is better because first time we do Ctrl-a we want to select everything!
    count := 0;
    for :Selected app.entities {
        count += 1;
    }

    for :All app.entities {
        if      count == 0                  it.is_selected = true;
        else if count  < app.entities.count it.is_selected = true;
        else                                it.is_selected = false;
    }
}

// Deselects items which are not visible and toggles selection of visible items
select_or_deselect_visible :: () {
    select := false;
    for :Visible app.entities {
        if !it.is_selected {
            select = true;
        }
    }

    for :All app.entities {
        if it.display_info.is_visible {
            it.is_selected = select;
        } else {
            it.is_selected = false;
        }
    }
}

toggle_current_selection :: () {
    for :All app.entities {
        it.is_selected = !it.is_selected;
    }
}

reset_camera :: () { init_camera(); }

my_debug_function :: () {
    log(#run join("\nYou pressed SPACE!\n",
                  "This is a binding which will always be reserved for user debug functions.\n",
                  tprint("You can edit the implementation at %:%\n\n", #file, #line)));

    app.debug_frame = true;
    app.debug_mode = !app.debug_mode;
    // Write your debug code here
}

Preset_Counter :: struct {
    count : int = 1; // 1 because I prefer the colors that get generated when we start at 1 :/
}
g_preset_name_to_counter : Table(string, Preset_Counter);

preset_shape_proc :: ($NAME : string, $FILENAME : string, $RANDOMIZE : ()->bool) -> *Entity {
    CONTENTS, OK :: #run read_entire_file(FILENAME);
    #assert(OK); // If this fails then FILENAME is probably invalid

    results : [..]*Entity = load_one_file_from_memory(FILENAME, CONTENTS, NAME, app.settings.duplicate_file_behaviour);
    if !results.count {
        return null;
    }

    // @Incomplete Think about how to handle presets that generate more than one output??
    result : *Entity = results[0]; 

    // Update the source to be a preset
    assert(result.source.kind == .Entity_Source_File); // because we loaded a file
    free(get_entity_source(result).path);


    // Set a null preset_proc, which we'll initialize properly later
    counter : *Preset_Counter = find_or_add(*g_preset_name_to_counter, NAME);
    set_entity_source_from_preset(result, tprint("% %", NAME, counter.count), null, result.mesh.positions.count);
    counter.count += 1;
    set_entity_display_info(result);

    // If we're not holding control then we apply a random tranformation in 10x the preset bounding box
    if RANDOMIZE() {
        bbox : AxisBox3 = bounding_box(result.mesh);
        center, extent := get_centered_form(bbox);
        shift : Vector3;
        shift.x = random_get_within_range(0, 10 * extent.x);
        shift.y = random_get_within_range(0, 10 * extent.y);
        shift.z = random_get_within_range(0, 10 * extent.z);
        update_entity_transform(result, shift);
    }

    return result;
}

add_preset :: (preset_proc : #type ()->*Entity) {
    entity : *Entity = preset_proc();
    assert(entity != null); // Expected an entity
    source := isa(entity.source, Entity_Source_Preset);
    assert(source != null); // Expected a preset
    source.preset_proc = preset_proc;
    add_entity(entity, app.settings.duplicate_file_behaviour);
    fit_scene_on_screen();
}

add_preset_cube :: () {
    preset_proc :: #bake_arguments preset_shape_proc(NAME="Preset Cube", FILENAME="shapes/cube.obj", RANDOMIZE=()=>(!io().KeyAlt));
    add_preset(preset_proc);
}

add_preset_widget :: () {
    preset_proc :: #bake_arguments preset_shape_proc(NAME="Preset Widget", FILENAME="shapes/widget.obj", RANDOMIZE=()=>(!io().KeyAlt));
    add_preset(preset_proc);
}

add_preset_boolean_a :: () {
    preset_proc :: #bake_arguments preset_shape_proc(NAME="Preset BooleanA", FILENAME="shapes/failed_boolean_a.obj", RANDOMIZE=()=>(!io().KeyAlt));
    add_preset(preset_proc);
}

add_preset_boolean_b :: () {
    preset_proc :: #bake_arguments preset_shape_proc(NAME="Preset BooleanB", FILENAME="shapes/failed_boolean_b.obj", RANDOMIZE=()=>(!io().KeyAlt));
    add_preset(preset_proc);
}