// Things with no clear file to go in just get shoved under the carpet.jai

// Returns a string in temporary storage
filetime_to_readable_date :: (filetime : u64) -> string {
    lt := filetime_to_local_time(filetime);
    // return tprint("%:%:% on %-%-%",
    //               formatInt(lt.hour, minimum_digits=2), formatInt(lt.minute,   minimum_digits=2), formatInt(lt.second, minimum_digits=2),
    //               formatInt(lt.year, minimum_digits=4), formatInt(lt.month_starting_at_0, minimum_digits=2), formatInt(lt.day_starting_at_0, minimum_digits=2));
    return tprint("%:%:%", formatInt(lt.hour, minimum_digits=2), formatInt(lt.minute, minimum_digits=2), formatInt(lt.second, minimum_digits=2));
}

maybe_trim_leading_dot_forwardslash :: (_s : string) -> string {
    s := _s;
    #if OS == .WINDOWS {
        if s.count >= 2 && s.data[0] == #char "." && s.data[1] == #char "/" {
            s.data += 2;
            s.count -= 2;
        }
    }
    return s;
}

canonically_formatted_path_string :: (_path : string) -> string {
    path := _path;
    path_overwrite_separators(path, #char "/");
    path = maybe_trim_leading_dot_forwardslash(path);
    return path;
}

get_ident_name :: (code : Code) -> string {
    root := compiler_get_nodes(code);
    assert(root.kind == .IDENT);
    ident := cast(*Code_Ident) root;
    return ident.name;
}

printv :: (a : Code, loc := #caller_location) #expand {
#if true {
    print("%:% % = %\n", loc.fully_pathed_filename, loc.line_number, #run get_ident_name(a), #insert a);
} else {
    print("% = %\n", #run get_ident_name(a), #insert a);
}
}

printd :: (fmt : string, args : ..Any, loc := #caller_location) {
    print("%:% ", loc.fully_pathed_filename, loc.line_number);
    print(fmt, ..args);
} @PrintLike

die :: (loc := #caller_location) {
    print("exit(1) at %:%\n", loc.fully_pathed_filename, loc.line_number);
    exit(1);
}

make_Vector2 :: inline (v : ImGui.ImVec2) -> Vector2 {
    result : Vector2 = ---;
    result.x = v.x;
    result.y = v.y;
    return result;
}

hack_char_to_string :: (c : *u8) -> string {
    result : string;
    result.data = c;
    result.count = 1;
    return result;
}

to_radians :: (degrees : float) -> float {
    scale :: PI / 180;
    return degrees * scale;
}

to_degrees :: (radians : float) -> float {
    scale :: 180 / PI;
    return radians * scale;
}

ensure_2d_or_3d :: (T : Type, loc := #caller_location) {
    dim := dimension_of(T, loc);
    if dim == 2 || dim == 3 return;
    compiler_report(loc.fully_pathed_filename, loc.line_number, 0, tprint("Expected Vector2 or Vector3, got %", T));
}

// Returns a signed int so we can write dim-1 in loops and things just work
dimension_of :: (T : Type, loc := #caller_location) -> int {
    if T == Vector2 return 2;
    if T == Vector3 return 3;
    compiler_report(loc.fully_pathed_filename, loc.line_number, 0, tprint("Expected Vector2 or Vector3, got %", T));
    return -1;
}

log_warning :: (format_string: string, args: .. Any, loc := #caller_location, flags := Log_Flags.NONE, user_flags : u32 = 0) {
    // In case people prefer to say log_warning instead of putting a flags argument on the end,
    // we provide this for convenience. Not really sure if it's worth it, but here you go.
    new_flags := flags | .WARNING;
    log(format_string, ..args, loc, new_flags, user_flags);
} @PrintLike


//
// ImGui Widgets
//


io :: () -> *ImGui.IO {return ImGui.GetIO(); }


imgui_label :: (label : string, ptr : *void) -> *u8 {
    push_allocator(temp);
    return to_c_string(join(label, tprint("##%", ptr)));
}

// Combo box to select display mode enum value
// @Cleanup Deduce the info_enum from the data
combo_box :: (label : string, data: *void, info_enum: *Type_Info_Enum) -> bool {
    changed := false;
    value := get_enum_value(data, info_enum);
    value_name := "";
    for info_enum.names {
        if value == info_enum.values[it_index]  value_name = it;
    }
    if ImGui.BeginCombo(imgui_label(label, data), temp_c_string(value_name)) {
        for info_enum.names {
            is_selected := value == info_enum.values[it_index];
            if ImGui.Selectable(temp_c_string(it), is_selected) {
                set_enum_value(data, info_enum, info_enum.values[it_index]);
                changed = true;
            }
            if is_selected ImGui.SetItemDefaultFocus();
        }

        ImGui.EndCombo();
    }
    return changed;
}

// See https://github.com/ocornut/imgui/issues/4719
// Note that the colors used for the selection until 1.87 are: ImGuiCol_HeaderActive, ImGuiCol_HeaderHovered and ImGuiCol_Header
// See the implementation of the Selectable function in imgui_widgets.cpp
selectable_with_bg_color :: (label : string, p_selected : *bool, bg_color : ImGui.ImU32, flags : ImGui.SelectableFlags = .None, size_arg : ImGui.ImVec2 = .{0, 0}) -> bool {
    draw_list : *ImGui.ImDrawList = ImGui.GetWindowDrawList();
    draw_list._Splitter.Split(*draw_list._Splitter, draw_list, 2);

    // Channel number is like z-order. Widgets in higher channels are rendered above widgets in lower channels.
    draw_list._Splitter.SetCurrentChannel(*draw_list._Splitter, draw_list, 1);

    result : bool = ImGui.Selectable(temp_c_string(label), p_selected, flags, size_arg);

    if (!ImGui.IsItemHovered() && !ImGui.IsItemActive() && !(<<p_selected))
    {
        // Render background behind Selectable().
        draw_list._Splitter.SetCurrentChannel(*draw_list._Splitter, draw_list, 0);
        p_min : ImGui.ImVec2 = ImGui.GetItemRectMin();
        p_max : ImGui.ImVec2 = ImGui.GetItemRectMax();
        draw_list.AddRectFilled(draw_list, p_min, p_max, bg_color);
    }

    // Commit changes.
    draw_list._Splitter.Merge(*draw_list._Splitter, draw_list);
    return result;
}

Checkbox_Sweep_Mode_State :: struct {
    sweep_active := false;
    state_to_set := false;
    mouse_min_x : s32;
    mouse_max_x : s32;
}

// Toggle visibility if the checkbox was pressed or if we swept over it with the LMB down
checkbox_press_or_sweep_to_toggle :: (state : *bool, label : *u8, sweep_state : *Checkbox_Sweep_Mode_State, window : *SDL_Window) -> bool {

    old_state := <<state;
    if ImGui.Checkbox(label, *old_state) { // @Hack Why do we need to pass old_state? To mimic a PressedOnClick checkbox? Explain this better/reimplement it
        // Get here when the LMB is released after going down while hovering the checkbox
        // So we don't get stuck in a state where this mode is on we don't reach the toggle off in IsMouseReleased branch. @Cleanup
        sweep_state.sweep_active = false;
        return true;
    }

    // ImGui Rects position min in upper left and max in lower right
    checkbox_upper_left := make_Vector2(ImGui.GetItemRectMin());
    checkbox_lower_right := make_Vector2(ImGui.GetItemRectMax());

    // Enter checkbox sweep mode on lmb down
    if ImGui.IsItemClicked(.Left) {
        sweep_state.sweep_active = true;
        sweep_state.state_to_set = <<state;
        sweep_state.mouse_min_x = xx checkbox_upper_left.x;
        sweep_state.mouse_max_x = xx checkbox_lower_right.x;
    }

    // Exit checkbox sweep mode on lmb release
    if ImGui.IsMouseReleased(.Left) {
        sweep_state.sweep_active = false;
    }

    if sweep_state.sweep_active {
        // When in checkbox sweep mode, provide a nice UX

        assert(ImGui.IsMouseDown(.Left), "Expected checkbox sweep mode only when lmb is down");

        // Issue an SDL event to warps the mouse cursor position to keep it from
        // drifting outside the checkbox column. We snap to the middle half of
        // the checkbox since using the whole checkbox means you can sometimes
        // skip around the checkbox boundary.
        //
        // @Cleanup This code is currently disabled since it was broken in build_gui,
        //   also it requires this function know about SDL, we should rethink the
        //   implementation to avoid that dependency
        //
        // margin : s32 = (sweep_state.mouse_max_x - sweep_state.mouse_min_x) / 4;
        // if io().MousePos.x < xx (sweep_state.mouse_min_x + margin) {
        //     SDL_WarpMouseInWindow(window, sweep_state.mouse_min_x + margin, xx io().MousePos.y);
        // }
        // if io().MousePos.x > xx (sweep_state.mouse_max_x - margin) {
        //     SDL_WarpMouseInWindow(window, sweep_state.mouse_max_x - margin, xx io().MousePos.y);
        // }

        mouse_prev, mouse_curr := make_Vector2(io().MousePos) - make_Vector2(io().MouseDelta), io().MousePos;
        prev_frame_hovered     := mouse_prev.y < checkbox_lower_right.y && mouse_prev.y > checkbox_upper_left.y;
        curr_frame_hovered     := mouse_curr.y < checkbox_lower_right.y && mouse_curr.y > checkbox_upper_left.y;

        if io().KeyCtrl || io().KeyShift {
            // When control/shift are pressed make the focus the y-hovered item, hiding others that are swept through
            if !prev_frame_hovered && curr_frame_hovered {
                <<state = true;
            } else if prev_frame_hovered && !curr_frame_hovered {
                <<state = false;
            }
            if io().KeyShift {
                fit_scene_on_screen(); // Also update the camera when shift is pressed
            }
        } else {
            // Update any checkbox intersecting the mouse sweep so none are missed if the mouse is moved a lot in a single frame
            swept_down := mouse_prev.y < checkbox_lower_right.y && mouse_curr.y > checkbox_upper_left.y;
            swept_up   := mouse_prev.y > checkbox_upper_left.y  && mouse_curr.y < checkbox_lower_right.y;
            if swept_up || swept_down {
                <<state = !sweep_state.state_to_set;
            }
        }
    }

    return old_state != <<state;
}


// @Incomplete add a delay before popup, see https://github.com/ocornut/imgui/issues/1485
Show_Tooltip :: (description : string) #expand {
    if (ImGui.IsItemHovered()) {
        ImGui.BeginTooltip();
        // ImGui.PushTextWrapPos(450);
        ImGui.TextUnformatted(description);
        // ImGui.PopTextWrapPos();
        ImGui.EndTooltip();
    }
}

Show_Tooltip_Binding :: (description : string, binding : string) #expand {
    if (ImGui.IsItemHovered()) {
        ImGui.BeginTooltip();
        ImGui.TextColored(KEYBINDING_COLOR, binding);
        ImGui.SameLine();
        ImGui.Text(description);
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

Show_Tooltip_Binding :: (bindings_with_descriptions : ..Binding_With_Description, header_text := "") #expand {
    if bindings_with_descriptions.count == 0 return;

    if (ImGui.IsItemHovered()) {
        ImGui.BeginTooltip();
        if header_text ImGui.Text(header_text);

        ImGui.BeginTable("", xx bindings_with_descriptions.count, flags=ImGui.TableFlags.NoBordersInBody);
        for bindings_with_descriptions {
            ImGui.TableNextRow(); ImGui.TableNextColumn();
            ImGui.TextColored(KEYBINDING_COLOR, it.binding);
            ImGui.TableNextColumn();
            ImGui.Text(it.description);
        }
        ImGui.EndTable();

        ImGui.EndTooltip();
    }
}


make_ImVec2 :: inline (a: float, b: float) -> ImGui.ImVec2 {
    v: ImGui.ImVec2 = ---;
    v.x = a;
    v.y = b;
    return v;
}

make_ImVec4 :: inline (a: float, b: float, c: float, d: float) -> ImGui.ImVec4 {
    v: ImGui.ImVec4 = ---;
    v.x = a;
    v.y = b;
    v.z = c;
    v.w = d;
    return v;
}


// See: https://github.com/ocornut/imgui/blob/0f14933577a1de01d90f8e87622296c466146f21/misc/cpp/imgui_stdlib.cpp#L38-L48
InputText :: (label: string, str : *string, flags: ImGui.InputTextFlags = .None, callback: ImGui.InputTextCallback = null, user_data: *void = null) -> bool {

    string_resize :: (s : *string, new_count: s64) {
        old_count := s.count;
        if old_count == new_count return;
        s.data = cast(*u8) realloc(s.data, new_count * size_of(u8), old_count * size_of(u8));
        s.count = new_count;
    }

    InputTextCallback_UserData :: struct {
        Str : *string;
        ChainCallback : ImGui.InputTextCallback;
        ChainCallbackUserData : *void;
    };

    InputTextCallback :: (data : *ImGui.InputTextCallbackData) -> s32 #c_call {
        new_context : Context;
        push_context new_context {
            user_data := cast(*InputTextCallback_UserData)data.UserData;
            if data.EventFlag == .CallbackResize {
                // Resize string callback
                // If for some reason we refuse the new length (BufTextLen) and/or capacity (BufSize) we need to set them back to what we want.
                s := cast(*string)user_data.Str;
                string_resize(s, data.BufSize);
                // Ensure that we can use user_data.Str.data as a c-string too
                s.count = data.BufTextLen;
                s.data[s.count] = 0;
                data.Buf = s.data;
            } else if user_data.ChainCallback {
                // Forward to user callback, if any
                data.UserData = user_data.ChainCallbackUserData;
                return user_data.ChainCallback(data);
            }

            return 0;
        }
    }

    assert((flags & .CallbackResize) == 0);
    flags |= .CallbackResize;

    cb_user_data : InputTextCallback_UserData;
    cb_user_data.Str = str;
    cb_user_data.ChainCallback = callback;
    cb_user_data.ChainCallbackUserData = user_data;

    str_c := temp_c_string(<<str);
    label_c := temp_c_string(label); // @Incomplete only do this if label is not constant
    return ImGui.InputText(label_c, str_c, xx (str.count + 1), flags, InputTextCallback, *cb_user_data);
}

get_enum_count :: ($enum_type : Type) -> s64 {
    info := type_info(enum_type);
    assert(info.type == Type_Info_Tag.ENUM);
    info_enum := cast(*Type_Info_Enum) info;
    return info_enum.values.count;
}

temp_array :: ($Element_Type : Type) -> [..]Element_Type {
    result : [..]Element_Type;
    result.allocator = temp;
    return result;
}

PushAllocator :: push_allocator; // An alias so we match our macro convention

#if 1 { // This just delimits a block of code related to noting entry/exit from function

NoteEntryExit :: () #expand {
    // #this is the pointer to the procedure calling this macro
    note_entry(#this, #location(#this));
    `defer note_exit(#this);
}

#add_context note_entry_exit_depth: s32;

note_entry :: (proc: $T, location: Source_Code_Location) {
    for 0..context.note_entry_exit_depth-1 print("  ");
    context.note_entry_exit_depth += 1;

    if context.stack_trace {
        proc_name := context.stack_trace.info.name;
        print("--> Entering '%' at %:%\n", proc_name, location.fully_pathed_filename, location.line_number);
    } else {
        print("--> Entering '%' at %:%\n", proc, location.fully_pathed_filename, location.line_number);
    }
}

note_exit :: (proc: $T) {
    context.note_entry_exit_depth -= 1;
    for 0..context.note_entry_exit_depth-1 print("  ");

    if context.stack_trace {
        proc_name := context.stack_trace.info.name;
        print("<-- Exiting %\n", proc_name);
    } else {
        print("<-- Exiting %\n", cast(*void) proc);  // Cast to *void to make the print shorter.
    }
}

}