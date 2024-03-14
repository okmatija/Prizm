
//
// ImGui Widgets
//


io :: () -> *ImGui.IO {return ImGui.GetIO(); }

make_Vector2 :: inline (v : ImGui.ImVec2) -> Vector2 {
    result : Vector2 = ---;
    result.x = v.x;
    result.y = v.y;
    return result;
}

imgui_label :: (label : string, ptr : *void = null) -> *u8 {
    return temp_c_string(tprint("%##%", label, ptr));
}

begin_box_section :: () {
    table_flags := ImGui.TableFlags.BordersOuter;
        // .NoHostExtendX; // Can be useful
    ImGui.BeginTable("", 1, flags=table_flags);
}

end_box_section :: () {
    ImGui.EndTable();
}

// Note: You need to use the ImGui.TableNextColumn apis after doing this
BoxSection :: () #expand {
    table_flags := ImGui.TableFlags.BordersOuter;
        // .NoHostExtendX; // Can be useful
    ImGui.BeginTable("", 1, flags=table_flags);
    `defer ImGui.EndTable();
}

// Used to make the rows of tables close together
ScopeZeroCellPaddingY :: () #expand {
    padding := ImGui.GetStyle().CellPadding;
    padding.y = 0;
    ImGui.PushStyleVar(xx ImGui.StyleVar.CellPadding, padding);
    `defer ImGui.PopStyleVar();
}

// Combo box to select display mode enum value
// @Cleanup Deduce the info_enum from the data
combo_box :: (label : string, data: *void, info_enum: *Type_Info_Enum, flags : ImGui.ComboFlags = .None) -> bool {
    changed := false;
    value := get_enum_value(data, info_enum);
    value_name := "";
    for info_enum.names {
        if value == info_enum.values[it_index]  value_name = it;
    }
    if ImGui.BeginCombo(imgui_label(label, data), temp_c_string(value_name), flags) {
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

    if (!ImGui.IsItemHovered() && !ImGui.IsItemActive() && !(p_selected.*))
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
// @Volatile Note that if you issue a checkbox with this function and its clipped/not visible in the UI (e.g., submitting to a scrolling region _without_ using a list clipper) you will still be able to edit its state since we do this based on the mouse position
// @Incomplete Add flags for what sweep behaviours are acceptable e.g., control down variations are weird in some cases
checkbox_press_or_sweep_to_toggle :: (state : *bool, label : *u8, sweep_state : *Checkbox_Sweep_Mode_State) -> changed : bool, changed_by_click : bool {

    old_state := state.*;
    if ImGui.Checkbox(label, *old_state) { // @Hack Why do we need to pass old_state? To mimic a PressedOnClick checkbox? Explain this better/reimplement it
        // Get here when the LMB is released after going down while hovering the checkbox
        // So we don't get stuck in a state where this mode is on we don't reach the toggle off in IsMouseReleased branch. @Cleanup
        sweep_state.sweep_active = false;
        return true, true;
    }

    changed_by_click := false;

    // ImGui Rects position min in upper left and max in lower right
    checkbox_upper_left := make_Vector2(ImGui.GetItemRectMin());
    checkbox_lower_right := make_Vector2(ImGui.GetItemRectMax());

    // Enter checkbox sweep mode on lmb down
    if ImGui.IsItemClicked(.Left) {
        sweep_state.sweep_active = true;
        sweep_state.state_to_set = state.*;
        sweep_state.mouse_min_x = xx checkbox_upper_left.x;
        sweep_state.mouse_max_x = xx checkbox_lower_right.x;
        changed_by_click = true;
    }

    // Exit checkbox sweep mode on lmb release
    if ImGui.IsMouseReleased(.Left) {
        sweep_state.sweep_active = false;
    }

    if sweep_state.sweep_active {
        // When in checkbox sweep mode, provide a nice UX

        assert(ImGui.IsMouseDown(.Left), "Expected checkbox sweep mode only when lmb is down");

        mouse_prev, mouse_curr := make_Vector2(io().MousePos) - make_Vector2(io().MouseDelta), io().MousePos;
        prev_frame_hovered     := mouse_prev.y < checkbox_lower_right.y && mouse_prev.y > checkbox_upper_left.y;
        curr_frame_hovered     := mouse_curr.y < checkbox_lower_right.y && mouse_curr.y > checkbox_upper_left.y;

        if io().KeyCtrl || io().KeyShift {
            // When control/shift are pressed make the focus the y-hovered item, hiding others that are swept through
            if !prev_frame_hovered && curr_frame_hovered {
                state.* = true;
                changed_by_click = false;
            } else if prev_frame_hovered && !curr_frame_hovered {
                state.* = false;
                changed_by_click = false;
            }
            if io().KeyShift {
                fit_scene_on_screen(); // Also update the camera when shift is pressed
            }
        } else {
            // Update any checkbox intersecting the mouse sweep so none are missed if the mouse is moved a lot in a single frame
            swept_down := mouse_prev.y < checkbox_lower_right.y && mouse_curr.y > checkbox_upper_left.y;
            swept_up   := mouse_prev.y > checkbox_upper_left.y  && mouse_curr.y < checkbox_lower_right.y;
            if swept_up || swept_down {
                state.* = !sweep_state.state_to_set;
                changed_by_click = false;
            }
        }
    }

    if old_state != state.* {
        return true, changed_by_click;
    }

    return false, false;
}

//  @Cleanup Rename show_tooltip* since these dont need to be macros

show_tooltip :: (description : string, flags := ImGui.HoveredFlags.DelayNormal) {
    if (ImGui.IsItemHovered(flags)) {
        ImGui.BeginTooltip();
        // ImGui.PushTextWrapPos(450);
        ImGui.TextUnformatted(description);
        // ImGui.PopTextWrapPos();
        ImGui.EndTooltip();
    }
}

ListClipperIterator :: (array : *[..]$T, body : Code, flags : For_Flags) #expand {
    BY_POINTER :: cast(bool)(flags & .POINTER);

    `clipper : ImGui.ListClipper; // Exposed so that you can access ItemsHeight, which is useful to size scrolling regions
    ImGui.ListClipper.Constructor(*clipper);
    ImGui.ListClipper.Begin(*clipper, xx array.count);
    while outer := ImGui.ListClipper.Step(*clipper) {
        for row : clipper.DisplayStart..clipper.DisplayEnd-1 {
            `it_index := row;

            #if flags & .POINTER {
            `it : *T = *(array.*)[row];
            } else {
            `it : T = (array.*)[row];
            }

            #insert body;
        }
    }
    ImGui.ListClipper.Destructor(*clipper);
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

    str_c := temp_c_string(str.*);
    label_c := temp_c_string(label); // @Incomplete only do this if label is not constant
    return ImGui.InputText(label_c, str_c, xx (str.count + 1), flags, InputTextCallback, *cb_user_data);
}

// Needed to make sure the tooltip is visible regardless of whether the tree node is open or closed
TreeNodeWithTooltip :: (label : *u8, tooltip : string) -> bool #expand {
    result := ImGui.TreeNodeEx(label, .SpanAvailWidth);
    show_tooltip(tooltip);
    return result;
}

/*
hold_lmb_and_hover_to_open_tree :: () -> bool {
    do_tree := ImGui.TreeNodeEx("Testing", ImGui.TreeNodeFlags.SpanAvailWidth | .DefaultOpen);
    if ImGui.IsItemHovered() {
        projection_from_world := make_projection_from_world(app.camera);

        // Compute warped position in projection coordinates Fd
        warped_ndc : Vector3 = transform_point(projection_from_world, app.camera.look_position);

        // Convert to screen coordinates
        warped_px : Vector2;
        warped_px.x = cast(float)app.current_window_width *  (warped_ndc.x + 1) / 2;
        warped_px.y = cast(float)app.current_window_height * (warped_ndc.y + 1) / 2;
        SDL_WarpMouseInWindow(app.window, xx warped_px.x, xx warped_px.y);

        rmb_down_pos = make_Vector2(warped_px);
        camera_at_mouse_down = app.camera;
    }

    if ImGui.TreeNodeEx("Tools", ImGui.TreeNodeFlags.SpanAvailWidth | .DefaultOpen) {
        defer ImGui.TreePop();
}
*/