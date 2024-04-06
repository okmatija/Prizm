// @Volatile If you change any keybinds make sure to update all documentation, including the github wiki!

Keymap_Proc_Info :: struct {
    name: string;
    proc: #type () -> ();
}

// @Think Maybe we shouldn't allow more than one modifier ever, because they are horrible to press!
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

KEYBIND_TABLE_FLAGS :: ImGui.TableFlags.BordersOuter | .BordersInnerV | .RowBg;

ScopeKeyBindTable :: (table_id : string) -> ImGui.TableFlags #expand {
    `ImGui.BeginTable(temp_c_string(table_id), 2, flags=KEYBIND_TABLE_FLAGS);
    `defer ImGui.EndTable();
}

ShowBinding :: (binding : string, description : string) #expand { // @CompilerBug??? Why does this need to be a macro
    ImGui.TableNextColumn();
    ImGui.TextColored(app.theme.keymap_color, binding);
    ImGui.TableNextColumn();
    ImGui.Text(description);
}

// @CompilerBug{"0.1.049"} This does not compile if its not a macro, there is an error about 'Undeclared identifier 'app''
show_tooltip_binding :: (description : string, binding : string, header_text := "", footer_text := "", flags := ImGui.HoveredFlags.DelayNormal) #expand {
    if (ImGui.IsItemHovered(flags)) {
        ImGui.BeginTooltip();
        if header_text ImGui.Text(header_text);
        ImGui.TextColored(app.theme.keymap_color, binding);
        ImGui.SameLine();
        ImGui.Text(description);
        if footer_text ImGui.Text(footer_text);
        ImGui.EndTooltip();
    }
}

Binding_With_Description :: struct {
    binding : string;
    description : string;
}

make_Binding_With_Description :: (binding : string, description : string) -> Binding_With_Description {
    result : Binding_With_Description = ---;
    result.binding = binding;
    result.description = description;
    return result;
}

show_tooltip_binding :: (bindings_with_descriptions : ..Binding_With_Description, header_text := "", footer_text := "", flags := ImGui.HoveredFlags.DelayNormal) #expand {
    if bindings_with_descriptions.count == 0 return;

    if (ImGui.IsItemHovered(flags)) {
        ImGui.BeginTooltip();
        if header_text ImGui.Text(header_text);

        ImGui.BeginTable("##", 2, flags=KEYBIND_TABLE_FLAGS);
        for bindings_with_descriptions {
            ImGui.TableNextColumn();
            ImGui.TextColored(app.theme.keymap_color, it.binding);
            ImGui.TableNextColumn();
            ImGui.Text(it.description);
        }
        ImGui.EndTable();

        if footer_text ImGui.Text(footer_text);
        ImGui.EndTooltip();
    }
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

to_sdl_keycode :: (key_code : u32) -> SDL_Keycode {
    if key_code >= 32 return xx key_code;

    special_key_code : Special_Key_Code = xx key_code;
    if #complete special_key_code == {
        case Special_Key_Code.EMPTY;  return SDLK_UNKNOWN;
        case Special_Key_Code.ESCAPE; return SDLK_ESCAPE;
        case Special_Key_Code.ENTER;  return SDLK_RETURN;
        case Special_Key_Code.TAB;    return SDLK_TAB;
        case Special_Key_Code.DELETE; return SDLK_DELETE;
        case Special_Key_Code.F1;     return SDLK_F1;
        case Special_Key_Code.F2;     return SDLK_F2;
        case Special_Key_Code.F3;     return SDLK_F3;
        case Special_Key_Code.F4;     return SDLK_F4;
        case Special_Key_Code.F5;     return SDLK_F5;
        case Special_Key_Code.F6;     return SDLK_F6;
        case Special_Key_Code.F7;     return SDLK_F7;
        case Special_Key_Code.F8;     return SDLK_F8;
        case Special_Key_Code.F9;     return SDLK_F9;
        case Special_Key_Code.F10;    return SDLK_F10;
        case Special_Key_Code.F11;    return SDLK_F11;
        case Special_Key_Code.F12;    return SDLK_F12;
    }
    return SDLK_UNKNOWN;
}

// @Cleanup add a version of this function which also works with mouse buttons, or share the code for adding the modifier
to_string :: (key_code : u32, using modifier_flags : Modifier_Flags = .{}, pad_unmodified := true) -> string {
    push_allocator(temp);

    builder : String_Builder;
    init_string_builder(*builder);
    defer free_buffers(*builder);

    if control_pressed {
        print_to_builder(*builder, "Ctrl  ");
    }
    if alt_pressed {
        print_to_builder(*builder, "Alt   ");
    }
    if shift_pressed {
        print_to_builder(*builder, "Shift ");
    }
    if pad_unmodified && !control_pressed && !alt_pressed && !shift_pressed {
        print_to_builder(*builder, "      ");
    }

    if key_code == 32 {
        print_to_builder(*builder, "Space");
    } else if key_code > 32 {
        upper_case := to_upper(cast(u8) key_code);
        // upper_case := cast(u8) key_code;
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

// @Cleanup We need a better way to determine which tool captures the clicks, checking app.select_tool.entity.display_info.is_visible sucks

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

mouse_move_valid :: () -> bool {
    // Mouse delta is zero when current or previous mouse positions were invalid
    return !(io().MouseDelta.x == 0 && io().MouseDelta.y == 0);
}

mouse_pan_camera :: () -> bool {
    return io_mouse_middle_down() && mouse_move_valid();
}

mouse_orbit_camera :: () -> bool {
    return ImGui.IsMouseDragging(.Right, 0.) && !io().KeyCtrl && mouse_move_valid;
}

mouse_zoom_camera :: () -> bool {
    return io().MouseWheel != 0.;
}

mouse_init_clip_center :: () -> bool {
    if app.select_tool.entity.display_info.is_visible {
        return false;
    }
    if io().WantCaptureMouse || !ImGui.IsMousePosValid(*io().MousePos) {
        return false;
    }
    return ImGui.IsMouseClicked(.Left) && io().KeyShift;
}

mouse_set_clip_radius :: () -> bool {
    if app.select_tool.entity.display_info.is_visible {
        return false;
    }
    if io().WantCaptureMouse || !ImGui.IsMousePosValid(*io().MousePos) {
        return false;
    }
    return ImGui.IsMouseDown(.Left) && io().KeyShift;
}

init_keymap :: () {

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

    // TODO Add options here for behaviour customizations?

    add_key(*app.keymap_keydown, toggle_fullscreen, "Toggle fullscreen", xx Special_Key_Code.F11, override_WantCaptureKeyboard=true);
    add_key(*app.keymap_keydown, toggle_show_ui, "Toggle entire UI",  xx #char "`", .{control_pressed=true});
    add_key(*app.keymap_keydown, toggle_show_console_ui, "Toggle console UI",  xx #char "`", override_WantCaptureKeyboard=true);

    // @Volatile Sync with :SelectionKeybindTooltip 
    // add_key(*app.keymap, quit_application, "Quit application", xx #char "q", .{shift_pressed=true, control_pressed=true}, override_WantCaptureKeyboard=true);
    add_key(*app.keymap, select_or_deselect_all, "Select/deselect all items", xx #char "a", .{control_pressed=true});
    add_key(*app.keymap, select_or_deselect_visible, "Select/deselect visible items", xx #char "a", .{shift_pressed=true});
    add_key(*app.keymap, toggle_current_selection, "Toggle/complement current item selection", xx #char "a", .{alt_pressed=true});

    add_key(*app.keymap, clear_all_labels, "Clear labels", #char "z");
    add_key(*app.keymap, reload_items, "Reload", cast(u32) Special_Key_Code.F5); // @Volatile Sync with :ReloadItemsKey
    add_key(*app.keymap, focus_items, "Focus", #char "f");  // @Volatile Sync with :FocusItemsKey

    add_key(*app.keymap, remove_entities_if_selected, "Remove selected items", xx Special_Key_Code.DELETE);
    // @FIXME Make these presets work with the alt key like the button
    add_key(*app.keymap, add_preset_demo, "Add shapes/Demo.obj", xx Special_Key_Code.F1); // @Cleanup Hidden modifier alt makes this fixed
    add_key(*app.keymap, add_preset_widget, "Add shapes/Widget.obj", xx Special_Key_Code.F2); // @Cleanup Hidden modifier alt makes this fixed
    add_key(*app.keymap, add_preset_boolean_a, "Add shapes/BooleanA.obj", xx Special_Key_Code.F3); // @Cleanup Hidden modifier alt makes this fixed
    add_key(*app.keymap, add_preset_boolean_b, "Add shapes/BooleanB.obj", xx Special_Key_Code.F4); // @Cleanup Hidden modifier alt makes this fixed

    // @Volatile Sync with :RotateLookDirectionUI
    add_key(*app.keymap, rotate_look_direction_1_cw,   "Rotate  1  deg about selected rotation axis", xx #char "]", .{alt_pressed=true});
    add_key(*app.keymap, rotate_look_direction_5_cw,   "Rotate  5  deg about selected rotation axis", xx #char "]");
    add_key(*app.keymap, rotate_look_direction_15_cw,  "Rotate  15 deg about selected rotation axis", xx #char "]", .{shift_pressed=true});
    add_key(*app.keymap, rotate_look_direction_1_ccw,  "Rotate -1  deg about selected rotation axis", xx #char "[", .{alt_pressed=true});
    add_key(*app.keymap, rotate_look_direction_5_ccw,  "Rotate -5  deg about selected rotation axis", xx #char "[");
    add_key(*app.keymap, rotate_look_direction_15_ccw, "Rotate -15 deg about selected rotation axis", xx #char "[", .{shift_pressed=true});

    // Reserved! Do not change this binding
    add_key(*app.keymap, my_debug_function, "Call my_debug_function", xx #char " ");

    add_action_key :: (keymap : *Keymap, using action_set : Action_Set, loc := #caller_location) {
        add_key(keymap, proc, name, key_code, .{}, override_WantCaptureKeyboard, loc);
    }

    add_action_key(*app.keymap_actions, CYCLE_OPACITY_ACTION_SET);
    add_action_key(*app.keymap_actions, CYCLE_LINE_WIDTH_ACTION_SET);
    add_action_key(*app.keymap_actions, CYCLE_VERTEX_SIZE_ACTION_SET);
    add_action_key(*app.keymap_actions, CYCLE_ELEMENT_LABEL_ACTION_SET);
    add_action_key(*app.keymap_actions, CYCLE_VERTEX_LABEL_ACTION_SET);
    add_action_key(*app.keymap_actions, CYCLE_ANNOTATION_LABEL_ACTION_SET);
    add_action_key(*app.keymap_actions, CYCLE_BACKFACE_MODE_ACTION_SET);
    add_action_key(*app.keymap_actions, TOGGLE_CLIPPING_ACTION_SET);
    add_action_key(*app.keymap_actions, TOGGLE_NORMALS_ACTION_SET);

}

// @Cleanup Use a to_string function for the bindings in the following functions

show_window_key_bindings :: () {
    ScopeKeyBindTable("##WindowControlsKeys");

    // @Volatile :EasyResizeModeKeybind
    ShowBinding("Alt   LMB", "(near window border) Resize the window");
    ShowBinding("Alt   LMB", "(near window center) Move the window");
}

show_camera_key_bindings :: () {
    ScopeKeyBindTable("##CameraControlsKeys");

    ShowBinding("      MMB", "Pan the camera");
    ShowBinding("      RMB", "Rotate the camera");
    ShowBinding("Shift RMB", "Rotate about selected axis in the camera control pane");
    ShowBinding("Ctrl  RMB", "Place camera look position (rotation center)");
    ShowBinding("      Scroll", "Zoom into the position under the cursor");
    ShowBinding("Alt   Scroll", "Zoom into the position under the cursor slowly");
    ShowBinding("Shift Scroll", "Zoom into the camera look position");
}

show_items_list_key_bindings :: () {
    ScopeKeyBindTable("##ItemsListKeys");

    ShowBinding("      RMB", "(on a color) Cycle shading styles");
    ShowBinding("      MMB", "(on a color) Reset color from the filename");
    ShowBinding("      LMB", "(sweep over visibility checkbox) Update visibility");
    ShowBinding("Ctrl  LMB", "(sweep over visibility checkbox) Focus item");
    ShowBinding("Shift LMB", "(sweep over visibility checkbox) Focus item, update camera");
    ShowBinding("      LMB", "(on a filename) Select an item");
    ShowBinding("Ctrl  LMB", "(on a filename) Add an item to selection");
}

show_viewport_key_bindings :: () {
    ScopeKeyBindTable("##ViewportKeys");

    for app.keymap_actions.mappings {
        push_allocator(temp);
        ShowBinding(to_string(it.key_code, it.modifier_flags), app.keymap_actions.procs[it.proc_info_index].name);
    }

    ShowBinding("Ctrl  LMB", "Add nearest unclipped element to 'Selection' item");
    ShowBinding("Shift LMB", "Click-drag to set clipping sphere");
}

show_miscellaneous_key_bindings :: () {
    ScopeKeyBindTable("##MiscellaneousKeys");

    for app.keymap.mappings {
        push_allocator(temp);
        ShowBinding(to_string(it.key_code, it.modifier_flags), app.keymap.procs[it.proc_info_index].name);
    }
    for app.keymap_keydown.mappings {
        push_allocator(temp);
        ShowBinding(to_string(it.key_code, it.modifier_flags), app.keymap_keydown.procs[it.proc_info_index].name);
    }
}


//
// Bindable procedures
//

quit_application               :: () { app.closing_application = true; }
toggle_show_ui                 :: () { app.show_ui = !app.show_ui; }
rotate_look_direction_1_cw     :: () { rotate_look_direction(camera_rotation_axis(),  -1); }
rotate_look_direction_1_ccw    :: () { rotate_look_direction(camera_rotation_axis(),   1); }
rotate_look_direction_5_cw     :: () { rotate_look_direction(camera_rotation_axis(),  -5); }
rotate_look_direction_5_ccw    :: () { rotate_look_direction(camera_rotation_axis(),   5); }
rotate_look_direction_15_cw    :: () { rotate_look_direction(camera_rotation_axis(), -15); }
rotate_look_direction_15_ccw   :: () { rotate_look_direction(camera_rotation_axis(),  15); }

toggle_show_console_ui :: () {
    app.show_ui, app.console.show_ui = true, !app.console.show_ui;
}

toggle_fullscreen :: () {
    app.window_size.fullscreen = !app.window_size.fullscreen;

#if OS == .WINDOWS {
    // @FIXME The other branch is the correct thing to do but it causes a black screen on windows..!
    // Perhaps there is useful info here: https://github.com/libsdl-org/SDL/issues/5788
    if app.window_size.fullscreen {
        SDL_MaximizeWindow(app.window);
    } else {
        SDL_RestoreWindow(app.window);
    }
} else {
    flags : u32 = ifx app.window_size.fullscreen then cast(u32) 0 else xx SDL_WindowFlags.SDL_WINDOW_FULLSCREEN_DESKTOP;
    ok := SDL_SetWindowFullscreen(app.window, flags); // @Robustness handle error
}
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

reload_items :: () {

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

// @Volatile :FocusItemBehavior Sync with focus button
focus_items :: () {

    prev_camera := app.camera;

    fit_on_screen_multiple(visit_visible_selected);

    // Not a exactly equal check becuase I think there is a feedback mechanism when the camera is computed from the sphere where we essentially have an operation like `camera = f(sphere, camera)` which with the "same" inputs the camera would change a bit FIXME There is still some bug here: load a lot of items and select all of them, the fit_on_screen and fit_on_screen_filled should give the same results but they are slightly different
    if almost_equal(app.camera, prev_camera) {
        fit_on_screen_filled_multiple(visit_visible_selected);
    }
}

clear_all_labels :: () {
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

reset_camera :: () {
    init_camera();
}

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

    results : []*Entity = load_one_file_from_memory(FILENAME, CONTENTS, NAME, app.settings.duplicate_file_behaviour);
    if !results.count {
        return null;
    }

    // @Incomplete Think about how to handle presets that generate more than one output??
    result : *Entity = results[0]; 

    // Update the source to be a preset
    assert(result.source.kind == ._Entity_Source_File); // because we loaded a file
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

add_preset_demo :: () {
    preset_proc :: #bake_arguments preset_shape_proc(NAME="Preset Demo", FILENAME="shapes/Demo.obj", RANDOMIZE=()=>(!io().KeyAlt));
    add_preset(preset_proc);
}

add_preset_widget :: () {
    preset_proc :: #bake_arguments preset_shape_proc(NAME="Preset Widget", FILENAME="shapes/Widget.obj", RANDOMIZE=()=>(!io().KeyAlt));
    add_preset(preset_proc);
}

add_preset_boolean_a :: () {
    preset_proc :: #bake_arguments preset_shape_proc(NAME="Preset BooleanA", FILENAME="shapes/BooleanA.obj", RANDOMIZE=()=>(!io().KeyAlt));
    add_preset(preset_proc);
}

add_preset_boolean_b :: () {
    preset_proc :: #bake_arguments preset_shape_proc(NAME="Preset BooleanB", FILENAME="shapes/BooleanB.obj", RANDOMIZE=()=>(!io().KeyAlt));
    add_preset(preset_proc);
}