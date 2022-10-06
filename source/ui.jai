WINDOW_BORDER_UI_OFFSET :: ImGui.ImVec2.{10, 10};

// @Cleanup Remove usages of helper functions BeginPopupContextItem when there is a function boundary between the imgui widget which is rmb clicked and the function rendering the UI

// @Refactor This function is too long (especially the top level for loop). Break it up.
show_main_panel :: () {

    // Set window border color to match the selection/RMB target item color
    original_border_color, original_border_size := ScopedWindowBorderTheme(ITEM_LIST_BORDER_COLOR, ITEM_LIST_BORDER_SIZE);

    ImGui.PushStyleVar(xx ImGui.StyleVar.IndentSpacing, 8);
    defer ImGui.PopStyleVar();

    ImGui.SetNextWindowPos(WINDOW_BORDER_UI_OFFSET);
    ImGui.Begin("Main Panel", flags = ImGui.WindowFlags.AlwaysAutoResize | .NoTitleBar);
    defer ImGui.End();

    ScopedWindowBorderTheme(original_border_color, original_border_size);

    if ImGui.BeginTabBar("##ItemsTab", flags=ImGui.TabBarFlags.None) {
        defer ImGui.EndTabBar();

        if ImGui.BeginTabItem("Items") {
            defer ImGui.EndTabItem();

            // ImGui.ColorEdit4("debug_color", *app.debug_color.component, ImGui.ColorEditFlags.NoInputs);
            show_tools_ui();
            if app.entities.count ImGui.Separator();
            show_item_list_ui();
        }

        if ImGui.BeginTabItem("Options") {
            defer ImGui.EndTabItem();

            show_options();
        }

        if ImGui.BeginTabItem("Help") {
            defer ImGui.EndTabItem();

            show_help_ui();
        }
    }
}

show_tools_ui :: () {
    indent := ImGui.GetTreeNodeToLabelSpacing();

    if ImGui.TreeNodeEx("Tools", ImGui.TreeNodeFlags.SpanAvailWidth | .DefaultOpen) {
        defer ImGui.TreePop();

        indent2 := ImGui.GetTreeNodeToLabelSpacing();
        ImGui.Unindent(indent2 - indent);
        defer ImGui.Indent(indent2 - indent);

        Action_Button("Reload", *RELOAD_ITEMS_ACTION_SET);
        ImGui.SameLine();
        Action_Button("Focus", *FOCUS_ITEMS_ACTION_SET);
        ImGui.SameLine();
        show_add_item_ui();
        show_selection_ui();
    }
}


show_item_list_ui :: () {

    indent := ImGui.GetTreeNodeToLabelSpacing();

    { // @Cleanup Remove this scope?
        entity_to_remove := -1;
        any_visibility_changed : bool;
        show_entity_index := app.console.visible || app.user_selection.display_info.is_visible;

        for *folder : app.directories {

            Local_Entity :: struct {
                entity : *Entity;
                global_index : int;
            }

            // The list clipper works on lots of evenly spaced items, which means we need to group entities by folder before we use it
            entities_in_folder : [..]Local_Entity;
            entities_in_folder.allocator = temp;
            for entity, entity_index : app.entities {
                if get_directory(entity.fully_pathed_name) == folder.path {
                    local_entity : Local_Entity;
                    local_entity.entity = entity;
                    local_entity.global_index = entity_index;
                    array_add(*entities_in_folder, local_entity);
                }
            }

            if entities_in_folder.count == 0 && !folder_exists_on_disk(folder.path) {
                continue; // We don't want to show tree nodes for empty folders unless they exists on disk (its handy to watch a currently empty folder in Prism and then have files dumped there be autoloaded)
            }

            // Using this boolean allows us to have BeginPopupContextItem (within show_folder_context_menu) use the TreeNodeEx imgui id
            // @Incomplete Abbreviate this name e.g., C:/.../folder etc
            do_tree : bool = ImGui.TreeNodeEx(imgui_label(folder.path, *folder), ImGui.TreeNodeFlags.SpanAvailWidth | .DefaultOpen);
            show_folder_context_menu(folder.path, *folder.auto_load_new_files);
            if do_tree {
                defer ImGui.TreePop();

                // Use Ctrl LMB to select all items in the folder
                if ImGui.IsItemClicked() && io().KeyCtrl {
                    state := false;
                    if entities_in_folder.count {
                        state = entities_in_folder[0].entity.is_selected;
                    }
                    for entities_in_folder {
                        it.entity.is_selected = !state;
                    }
                }

                indent2 := ImGui.GetTreeNodeToLabelSpacing();
                ImGui.Unindent(indent2 - indent);
                defer ImGui.Indent(indent2 - indent);

                if entities_in_folder.count {
                    table_flags := ImGui.TableFlags.NoBordersInBody | .ScrollY;
                    outer_size :=  make_ImVec2(0, app.settings.item_list_max_size_before_scroll_px);

                    show_scrollbar := folder.last_frame_item_list_height_px >= outer_size.y;
                    if !show_scrollbar {
                        table_flags &= ~.ScrollY;
                        outer_size.y = 0; // Not really necessary, since its ignored unless flags include ScrollY
                    }

                    // @Hack Include an extra empty padding column so the filename is not trucated when we use a scrolling region
                    if ImGui.BeginTable(imgui_label("Item List Table", xx folder), xx (ifx show_entity_index then 6 else 5), flags=table_flags, outer_size=outer_size) {
                        defer ImGui.EndTable();

                        // @Volatile Using ListClipperIterator here is important since we'll issue checkbox_press_or_sweep_to_toggle commands in this loop, see the comment for that function

                        folder.last_frame_item_list_height_px = 0.;
                        for :ListClipperIterator local_entity : entities_in_folder {
                            folder.last_frame_item_list_height_px = clipper.ItemsHeight;
                            update : Item_Entry_Update = show_item_list_entry(local_entity.entity, local_entity.global_index, show_entity_index, show_scrollbar);
                            if update.entity_to_remove >= 0 entity_to_remove = update.entity_to_remove; 
                            if update.visibility_changed    any_visibility_changed = true;
                        }
                        folder.last_frame_item_list_height_px *= entities_in_folder.count;
                    }
                } else {
                    ImGui.TextDisabled("(none)");
                }
            }
        }

        // This block implements the feature where if you toggle visibility, editing colors and cycling/resetting display modes on a selected item it changes it on all selected items
        // This is similar to how editing the context menu of an item selection changes the corresponding field in all selected items
        {
            if g_this_frame_state.index_of_selected_item_where_color_was_changed != -1 {
                source : *Entity = app.entities[g_this_frame_state.index_of_selected_item_where_color_was_changed];
                for app.entities if it.is_selected {
                    <<entity_primary_color(it) = <<entity_primary_color(source);
                }
            }
            if g_this_frame_state.index_of_selected_item_where_mode_was_cycled != -1 {
                source : *Entity = app.entities[g_this_frame_state.index_of_selected_item_where_mode_was_cycled];
                for app.entities if it.is_selected {
                    it.display_info.display_mode = source.display_info.display_mode;
                }
            }
            if g_this_frame_state.index_of_selected_item_where_color_was_reset != -1 {
                for app.entities if it.is_selected {
                    it.display_info.display_mode = Display_Info.{}.display_mode;
                    reset_entity_primary_color(it);
                }
            }
            if g_this_frame_state.index_of_selected_item_where_visibility_changed_by_click != -1 {
                source : *Entity =app.entities[g_this_frame_state.index_of_selected_item_where_visibility_changed_by_click];
                for app.entities if it.is_selected {
                    it.display_info.is_visible = source.display_info.is_visible;
                }
            }
        }

        if entity_to_remove >= 0 && entity_to_remove < app.entities.count {
            remove_entity_by_index(entity_to_remove);
        }

        if app.settings.fit_to_screen_on_visibility_change && any_visibility_changed {
            fit_scene_on_screen();
        }
    }
}

Item_Entry_Update :: struct {
    visibility_changed := false;
    entity_to_remove := -1;
}

show_item_list_entry :: (entity : *Entity, entity_index : int, show_entity_index : bool, hack_pad_last_column_to_fix_truncation : bool) -> Item_Entry_Update {
    result : Item_Entry_Update;

    // Remove button
    ImGui.TableNextColumn();
    if ImGui.Button(imgui_label("Remove", entity)) {
        result.entity_to_remove = entity_index;
    }

    // Color selection
    ImGui.TableNextColumn();
    {
        color_changed := false; // Edited by widget
        color_reset :=   false; // Reset with MMB
        mode_cycled :=   false; // Cycled with RMB

        if entity.display_info.display_mode == .NORMALS {
            ImGui.TextDisabled("NR."); // @Design Replace this with a image with a normal gradient
        } else {
            color := entity_primary_color(entity);
            if color {
                color_changed = ImGui.ColorEdit4(imgui_label("##color", entity), *color.component, ImGui.ColorEditFlags.NoInputs);
            }
        }
        if ImGui.IsItemClicked(.Middle) {
            entity.display_info.display_mode = Display_Info.{}.display_mode; // Reset to default
            reset_entity_primary_color(entity);
            color_reset = true;
        }
        if ImGui.IsItemClicked(.Right) {
            cycle_display_mode(*entity.display_info.display_mode);
            mode_cycled = true;
        }

        if entity.is_selected {
            if color_changed g_next_frame_state.index_of_selected_item_where_color_was_changed = entity_index;
            if color_reset   g_next_frame_state.index_of_selected_item_where_color_was_reset =   entity_index;
            if mode_cycled   g_next_frame_state.index_of_selected_item_where_mode_was_cycled =    entity_index;
        }
    }

    // Toggle visibility checkbox
    ImGui.TableNextColumn();
    {
        was_visible := entity.display_info.is_visible;
        visibility_changed, changed_by_click := checkbox_press_or_sweep_to_toggle(*entity.display_info.is_visible, imgui_label("##Visible", entity), *item_list_sweep_state, app.window);
        result.visibility_changed = visibility_changed;
        Show_Tooltip("Visible");

        if !was_visible && entity.display_info.is_visible {
            // @Think We should probably have some kind of function list/hook/delegate feature so we can add code to be executed when visibility changes etc
            // Make sure we see something when turning on visibility. We don't consider normals here since there might not be any, or they might have zero length
            color, element_visibility := entity_primary_color(entity);
            <<element_visibility = true;
        }

        if entity.is_selected {
            if changed_by_click g_next_frame_state.index_of_selected_item_where_visibility_changed_by_click = entity_index;
        }
    }

    // Toggle clipping checkbox?

    // Entity index used to refer to geometry in console or annotate the text following ther cursor when adding to the user selection
    if show_entity_index {
        ImGui.TableNextColumn();
        if entity.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity {
            ImGui.Text("#%", entity_index);
            Show_Tooltip("Entity index for console commands\nand user selection cursor labels");
        } else {
            ImGui.TextDisabled("#%", entity_index);
            Show_Tooltip("Entity index for console commands\nand user selection cursor labels\nIncrease max point count to select this entity");
        }
    }

    // Write filename
    ImGui.TableNextColumn();
    // ImGui.SetNextItemWidth(-FLOAT32_MIN);
    if entity_name(entity).count {
        text : string = tprint("%1%2", entity_description(entity, with_creation_time=false), ifx is_changed_on_disk(entity) then "*" else "");
        label : *u8 =   imgui_label(text, entity);

        // Note that the ImGui.Selectable widget has this line to set the colors:
        //    const ImU32 col = GetColorU32((held && hovered) ? ImGuiCol_HeaderActive : hovered ? ImGuiCol_HeaderHovered : ImGuiCol_Header);

        // Indicate that the popup will be opened for this item if its hovered with RMB down
        if io_mouse_right_down() ImGui.PushStyleColor(xx ImGui.Col.HeaderHovered, CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR);
        defer if io_mouse_right_down() ImGui.PopStyleColor();

        if g_this_frame_state.index_of_context_menu_popup_item == -1 { // No context menu popup
            // Use the default Selectable widget
            if ImGui.Selectable(label, *entity.is_selected) {
                if !io().KeyCtrl entity.is_selected = !entity.is_selected;
            }
        } else { // Have context menu popup: set colors to indicate what the popup will be editing
            if app.entities[g_this_frame_state.index_of_context_menu_popup_item].is_selected {
                // Use the default Selectable widget, but customize the selected color
                ImGui.PushStyleColor(xx ImGui.Col.Header, CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR);
                ImGui.PushStyleColor(xx ImGui.Col.HeaderActive, CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR);
                if ImGui.Selectable(label, *entity.is_selected) {
                    if !io().KeyCtrl entity.is_selected = !entity.is_selected;
                }
                ImGui.PopStyleColor();
                ImGui.PopStyleColor();
            } else {
                if g_this_frame_state.index_of_context_menu_popup_item == entity_index {
                    // Use a custom Selectable widget, so we can change the background color even though as of 1.87 imgui does not expose a ImGuiCol enum for this
                    if selectable_with_bg_color(text, *entity.is_selected, ImGui.GetColorU32(CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR)) {
                        if !io().KeyCtrl entity.is_selected = !entity.is_selected;
                    }
                } else {
                    // Use the default Selectable widget
                    if ImGui.Selectable(label, *entity.is_selected) {
                        if !io().KeyCtrl entity.is_selected = !entity.is_selected;
                    }
                }
            }
        }
    } else {
        ImGui.Selectable("---", *entity.is_selected); // This should never happen
    }

    // No tooltip for this behaviour since we reserve the tooltip for annotations
    if ImGui.IsItemClicked() {
        if is_empty(entity) == false {
            if io().KeyCtrl {
                // Do nothing, this selects the item
            } else if io().KeyShift {
                // This is similar but a bit different to the behaviour when sweeping visibility checkboxes but its fine, I think that that code should not know about entities..?
                fit_on_screen_filled(entity);
            } else {
                // Fit all visible items on the screen
                fit_on_screen(entity);
            }
        }
    }
    was_hovered := entity.is_hovered;
    entity.is_hovered = ImGui.IsItemHovered();
    if ImGui.IsItemHovered() {
        entity.display_info.flash_wave_dt += io().DeltaTime;
    } else if was_hovered {
        entity.display_info.flash_wave_dt = 0;
    }

    header_annotation : *Annotation = find_header_annotation(entity);
    if app.settings.show_header_annotation_tooltips && header_annotation {
        Show_Tooltip(to_string(header_annotation));
    }

    /*
    compiler_report("Enable when we have tooltip delays");
    if (entity.is_hovered) {
        ImGui.BeginTooltip();
        if ImGui.BeginTable("", 2, flags=ImGui.TableFlags.NoBordersInBody) {
            defer ImGui.EndTable();
            ImGui.TableNextRow(); ImGui.TableNextColumn();
            ImGui.TextColored(KEYBINDING_COLOR, "RMB");
            ImGui.TableNextColumn();
            ImGui.Text("Open context menu for the current %", ifx entity.is_selected then "item selection" else "item");
            ImGui.TableNextRow(); ImGui.TableNextColumn();
            ImGui.TextColored(KEYBINDING_COLOR, "Ctrl LMB");
            ImGui.TableNextColumn();
            ImGui.Text("Toggle selected state of the hovered item");
        }
        ImGui.EndTooltip();
    }
    */

    // @Cleanup This is a horrible way to do this...
    entity.display_info.aabb_visible = false; // Turned on only while context menu > clipping is on

    show_item_context_menu(entity, entity_index);

    // @Hack Write empty padding column so filename is not truncated
    ImGui.TableNextColumn();
    if hack_pad_last_column_to_fix_truncation {
        ImGui.Text("  ");
    }

    return result;
} // end show_item_list_entry()



show_add_item_ui :: () {
    ImGui.Button(" Add ");
    Show_Tooltip("LMB to access preset shape menu, or\nDrag and Drop files/directories, or\nRestart with file/directory arguments");

    current_pos := ImGui.GetWindowPos();
    current_size := ImGui.GetWindowSize();
    window_pos := make_ImVec2(current_pos.x + current_size.x + WINDOW_BORDER_UI_OFFSET.x, ImGui.GetCursorScreenPos().y);
    ImGui.SetNextWindowPos(pos=window_pos, cond=.ImGuiCond_Appearing);

    // Set popup border color to match the selection/RMB target item color
    original_border_color, original_border_size := ScopedPopupBorderTheme(CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR, CONTEXT_MENU_POPUP_TARGET_BORDER_SIZE);

    if ImGui.BeginPopupContextItem("##Presets", popup_flags=.MouseButtonLeft) {
        defer ImGui.EndPopup();

        // Undo the previous thing so internals don't have this color
        ScopedPopupBorderTheme(original_border_color, original_border_size);

        ImGui.Text("Preset Shapes");
        ImGui.Separator();

        if ImGui.Button("Cube    ") { add_preset_cube(); }
        Show_Tooltip("A basic cube. Hold Alt to fix position");
        ImGui.SameLine(); 
        if ImGui.Button("Widget  ") { add_preset_widget(); }
        Show_Tooltip("A part autonomously machined by CloudNC");

        if ImGui.Button("BooleanB") { add_preset_boolean_b(); }
        Show_Tooltip("A failed cylinder/cone mesh boolean");
    }
}


show_options :: () {

    if ImGui.TreeNodeEx("Basic", ImGui.TreeNodeFlags.SpanAvailWidth | .DefaultOpen) {
        defer ImGui.TreePop();

        combo_box("Background", *app.background_style, type_info(app.Background_Style));
        if app.background_style == .SOLID_COLOR {
            ImGui.ColorEdit4("Background Color", *app.background_solid_color.component, ImGui.ColorEditFlags.NoInputs);
        }
        ImGui.DragFloat("Font Scale", *io().FontGlobalScale, .001, format="%.3f");
        ImGui.DragFloat3(imgui_label("Invalid Point", *app.invalid_point), *app.invalid_point.component, .05, format="%.3f");
        Show_Tooltip("Used to handle invalid .obj files:\nInvalid `f` directive references (missing points) use this position\nInvalid point components (inf/nan) get the corresponding component value");

        ImGui.Checkbox(imgui_label(tprint("Disable reload via % when file unchanged", to_string(RELOAD_ITEMS_ACTION_SET.key))), *app.settings.disable_reload_key_if_file_unchanged);
        ImGui.Checkbox("Show World Axes", *app.triad.visible);
        ImGui.Checkbox("Show Header Annotation Tooltips", *app.settings.show_header_annotation_tooltips);

        disable_window_resize_button := (app.current_window_width == app.INITIAL_WINDOW_WIDTH && app.current_window_height == app.INITIAL_WINDOW_HEIGHT);
        if disable_window_resize_button ImGui.BeginDisabled();
        if ImGui.Button("Reset OS Window Size") SDL_SetWindowSize(app.window, app.INITIAL_WINDOW_WIDTH, app.INITIAL_WINDOW_HEIGHT);
        if disable_window_resize_button ImGui.EndDisabled();
    }

    // :UserConfig add a button to overwrite the user settings file with new defaults here?
    inspect("Advanced", *app.settings);
    clamp_user_settings();

}

// nocommit Remove one level of indent here
show_selection_ui :: () {
        // ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing());

        // Selection Mode UI
        if ImGui.BeginTable("Mode Table", 5, flags=ImGui.TableFlags.NoBordersInBody) {
            defer ImGui.EndTable();

            it := *app.user_selection; // nocommit @Cleanup remove this

            ImGui.TableNextRow();

            // Remove button
            ImGui.TableNextColumn();
            {
                disable_cache_button := is_empty(app.user_selection);
                if disable_cache_button       ImGui.BeginDisabled();
                defer if disable_cache_button ImGui.EndDisabled();

                if ImGui.Button(imgui_label("Cache ", *app.user_selection)) {
                    if !is_empty(app.user_selection) {
                        new_entity : *Entity = New(Point_Cloud_Entity);

                        merge(new_entity.mesh, app.user_selection.mesh); // nocommit Make this work properly, accounting for transforms etc
                        counter : *Preset_Counter = find_or_add(*g_preset_name_to_counter, "Point Selection");
                        set_entity_source_from_selection(new_entity, tprint("% %", "Point Selection", counter.count), point_count(new_entity.mesh));
                        set_entity_display_info(new_entity, new_entity.mesh.geometry_format);
                        counter.count += 1;

                        add_entity(new_entity, app.settings.duplicate_file_behaviour);

                        deinit(*app.user_selection);

                        log("Point Selection cached: Created item #% %", app.entities.count-1, entity_name(new_entity));
                    } else {
                        log("Point Selection caching omitted: Point Selection is empty");
                    }
                }
                Show_Tooltip("Adds a new item based on this selection\nand resets the Point Selection");
            }

            // Color selection
            {
                ImGui.TableNextColumn();
                if ImGui.ColorEdit4(imgui_label("##color", it), *it.display_info.points_color.component, ImGui.ColorEditFlags.NoInputs) {
                    // This checkbox also sets the font color, to address feedback from BK: Black text on black wireframe is hard to read
                    it.display_info.vertex_label_style.label_color = darken(it.display_info.points_color, .8);
                }
            }

            // Enable checkbox. @Think Consider making this a radio button, if we always have a selection option, but maybe we don't want that...
            {
                ImGui.TableNextColumn();
                visibility_changed := ImGui.Checkbox(imgui_label("##Enabled", it), *it.display_info.is_visible); // @Important is_visible here is actually is_enabled
                Show_Tooltip("If enabled Ctrl LMB selects points");
                // any_visibility_changed = any_visibility_changed || visibility_changed; // @Cleanup This was left over from a refactoring, we probably caused a regression, but... fix it later??
            }

            ImGui.TableNextColumn();
            ImGui.Text("Point Selection");
            if it.display_info.is_visible {
                bindings : [..]Binding_With_Description;
                bindings.allocator = temp;
                array_add(*bindings, make_Binding_With_Description( "RMB",       "Open context menu for the current Selection"));
                array_add(*bindings, make_Binding_With_Description( "Ctrl RMB",  "Set camera orbit on nearest unclipped vertex"));
                array_add(*bindings, make_Binding_With_Description( "Ctrl LMB",  "Add nearest unclipped vertex to Selection item"));
                array_add(*bindings, make_Binding_With_Description( "Shift LMB", "Click-drag to set clipping sphere on selected items"));
                Show_Tooltip_Binding(..bindings);
            } else {
                Show_Tooltip("Show Selection\nEnable Selection and Clipping Modes");
            }
            if ImGui.IsItemClicked() && is_empty(it) == false {
                fit_on_screen(it);
            }
            was_hovered := it.is_hovered;
            it.is_hovered = ImGui.IsItemHovered();
            if it.is_hovered {
                it.display_info.flash_wave_dt += io().DeltaTime;
            } else if was_hovered {
                it.display_info.flash_wave_dt = 0;
            }

            current_pos := ImGui.GetWindowPos();
            current_size := ImGui.GetWindowSize();
            window_pos := make_ImVec2(current_pos.x + current_size.x + WINDOW_BORDER_UI_OFFSET.x, ImGui.GetCursorScreenPos().y);
            ImGui.SetNextWindowPos(pos=window_pos, cond=.ImGuiCond_Appearing);
            
            // Set popup border color to match the selection/RMB target item color
            original_border_color, original_border_size := ScopedPopupBorderTheme(CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR, CONTEXT_MENU_POPUP_TARGET_BORDER_SIZE);

            if ImGui.BeginPopupContextItem(imgui_label("##selection_context_menu", it)) {
                defer ImGui.EndPopup();

                // Undo the previous thing so internals don't have this color
                ScopedPopupBorderTheme(original_border_color, original_border_size);

                // combo_box("", *it.display_info.display_mode, type_info(type_of(it.display_info.display_mode)));
                // ImGui.SameLine();
                // ImGui.PushItemWidth(70);
                // ImGui.DragFloat(imgui_label("##Opacity", it), *it.display_info.color.w, v_speed=.005, v_min=0., v_max=1.);
                // ImGui.PopItemWidth();
                // Show_Tooltip("Opacity");

                vertex_label_style := *it.display_info.vertex_label_style;

                ImGui.Checkbox("Position labels", *vertex_label_style.show_position);
                ImGui.SameLine();
                ImGui.ColorEdit4("Label color", *vertex_label_style.label_color.component, ImGui.ColorEditFlags.NoInputs);
                ImGui.InputInt("Point size", *it.display_info.points_size);
                it.display_info.points_size = clamp(it.display_info.points_size, 2, 10);

                trailing_width : s32 = xx vertex_label_style.format_float.trailing_width;
                ImGui.InputInt("Float decimals", *trailing_width);
                vertex_label_style.format_float.trailing_width = clamp(trailing_width, 0, 12);
                Show_Tooltip("Number of digits following the decimal point");

                combo_box("Float format", *vertex_label_style.format_float.mode, type_info(FormatFloat.Mode));
                ImGui.DragFloat("Label scale", *vertex_label_style.label_scale, .005, .2, 1., format="%.3f");

                ImGui.Checkbox("Dynamic closest vertex result at cursor", *app.user_selection_cursor_text_shown);
                Show_Tooltip("Format is '#E,I {X,Y,Z}'\n E is entity index to which it belongs\n I is the vertex index within the entity\n X,Y,Z are the coordinates of the closest vertex");
                ImGui.DragFloat("Cursor text scale", *app.user_selection_cursor_text_scale, .005, .2, 1., format="%.3f");
                ImGui.InputInt("Max #points for selectable entities", xx *app.user_selection_max_point_count_for_selectable_entity);

                ImGui.Separator();

                ImGui.Text("#points = %", it.mesh.positions.count);

                maybe_update_render_info(*it.render_info, *it.mesh);
                aabb := it.render_info.bounding_aabb;
                imgui_text_for_aabb(it.render_info.bounding_aabb);
            }

            ImGui.TableNextRow();
            ImGui.TableNextColumn();
        }
}

ScopedPopupBorderTheme :: (color : ImGui.ImVec4, size : float) -> ImGui.ImVec4, float #expand {
    prev_color := ImGui.GetStyle().Colors[ImGui.Col.Border];
    prev_size :=  ImGui.GetStyle().PopupBorderSize;
    ImGui.PushStyleColor(xx ImGui.Col.Border, color);
    ImGui.PushStyleVar(xx ImGui.StyleVar.PopupBorderSize, size);
    `defer ImGui.PopStyleColor();
    `defer ImGui.PopStyleVar();
    return prev_color, prev_size;
}

ScopedWindowBorderTheme :: (color : ImGui.ImVec4, size : float) -> ImGui.ImVec4, float #expand {
    prev_color := ImGui.GetStyle().Colors[ImGui.Col.Border];
    prev_size :=  ImGui.GetStyle().WindowBorderSize;
    ImGui.PushStyleColor(xx ImGui.Col.Border, color);
    ImGui.PushStyleVar(xx ImGui.StyleVar.WindowBorderSize, size);
    `defer ImGui.PopStyleColor();
    `defer ImGui.PopStyleVar();
    return prev_color, prev_size;
}

Action_Button :: (_label : string, action_set : *Action_Set) #expand {
    label := copy_string(_label, temp);
    mod := current_modifier_flags(); 
    found, target := modifier_to_target(mod);

    has_target := false;
    if found {
        if #complete target == {
            case .ALL_ITEMS;
                has_target = app.entities.count != 0;
            case .VISIBLE;
                for :Visible app.entities {
                    has_target = true;
                    break;
                }
            case .SELECTED;
                for :Selected app.entities {
                    has_target = true;
                    break;
                }
        }
    }

    base_color := ImGui.GetStyle().Colors[ImGui.Col.ButtonActive];
    button_color := base_color;

    if has_target {
        action : Action;
        for action_set.target_action {
            if it.target == target {
                action = it;
                break;
            }
        }


        do_style := !action_set.regular_button ; // && progress.denom != 0;

        if do_style {
            progress := action.progress_proc();

            delta_time_s := to_float64_seconds(current_time_consensus() - action_set.last_interaction_time);
            fade :: FADE_TIME_SECS / 2;
            if delta_time_s < fade {
                using button_color;

                // alpha fades with time
                alpha := clamp(delta_time_s / fade, 0., 1.);
                w = lerp(base_color.w, 0., xx alpha);

                // hue cycles with progress @Cleanup I think this code is slightly incorrect but its not noticabl
                hsva := color_convert_RGB_to_HSV(x, y, z, w);
                hue := cast(u16)(hsva.x * 255);
                hue = (hue + cast(u16)(255 * progress.numer / (progress.denom + 1))) % 256;
                button_color = color_convert_HSV_to_RGB(xx hue / 255., hsva.y, hsva.z, hsva.w);

                // Show the text "Default" when we're back to the default setting
                if progress.numer == 0 {
                    default := "Default";
                    for 0..label.count-1 {
                        if it < default.count {
                            label.data[it] = default[it];
                        } else {
                            label.data[it] = #char " ";
                        }
                    }
                }
            } else {
                button_color.w = 0.;
            }

            ImGui.PushStyleColor(xx ImGui.Col.Button,        button_color);
            ImGui.PushStyleColor(xx ImGui.Col.ButtonActive,  button_color);
            ImGui.PushStyleColor(xx ImGui.Col.ButtonHovered, button_color);
            ImGui.PushStyleColor(xx ImGui.Col.Text, BLACK);
        }

        if ImGui.Button(imgui_label(label, *action_set)) {
            action_set.last_interaction_time = current_time_consensus();
            action.proc(xx *action_set.last_interaction_time);
            // action_set.hovered_duration_secs = 0.; // so we can click it without looking at the tooltip
        }

        if ImGui.IsItemHovered() {
            action_set.hovered_duration_secs += io().DeltaTime;
        } else {
            action_set.hovered_duration_secs = 0.;
        }

        if do_style {
            ImGui.PopStyleColor();
            ImGui.PopStyleColor();
            ImGui.PopStyleColor();
            ImGui.PopStyleColor();
        }

        if action_set.hovered_duration_secs > 0.5 {
            push_allocator(temp);

            #if false {
                // Just show one of the bindings
                desc := get_action_description(action_set, action.target);
                Show_Tooltip_Binding(desc, to_string(action_set.key, mod));
            } else {
                // Show all the bindings
                bindings : [..]Binding_With_Description;
                bindings.allocator = temp;
                array_add(*bindings, make_Binding_With_Description( to_string(action_set.key, VISIBLE_MOD),   get_action_description(action_set, .VISIBLE)));
                array_add(*bindings, make_Binding_With_Description( to_string(action_set.key, SELECTED_MOD),  get_action_description(action_set, .SELECTED)));
                array_add(*bindings, make_Binding_With_Description( to_string(action_set.key, ALL_ITEMS_MOD), get_action_description(action_set, .ALL_ITEMS)));
                Show_Tooltip_Binding(..bindings);
            }
        }

    } else {
        if !action_set.regular_button {
            button_color.w = 0;
            ImGui.PushStyleColor(xx ImGui.Col.Button,        button_color);
            ImGui.PushStyleColor(xx ImGui.Col.ButtonActive,  button_color);
            ImGui.PushStyleColor(xx ImGui.Col.ButtonHovered, button_color);
            ImGui.PushStyleColor(xx ImGui.Col.Text, BLACK);
        }
        ImGui.BeginDisabled();

        if ImGui.Button(imgui_label(label, *action_set)) {
            // Do nothing, this is a disabled button, only here for rendering
        }

        if !action_set.regular_button {
            ImGui.PopStyleColor();
            ImGui.PopStyleColor();
            ImGui.PopStyleColor();
            ImGui.PopStyleColor();
        }
        ImGui.EndDisabled();
    }
}


show_item_list_actions_ui :: () {
    if app.console.visible {
        return;
    }

    // @CompilerBug how to specify types with multiple return values
    target_exists, target_items := modifier_to_target(current_modifier_flags());

    // Try actions buttons on the bottom by the console
    {
        window_pivot := make_ImVec2(0, 1); // SetNextWindowPos will refer to the bottom left corner of the window

        console_top_y := app.current_window_height * .6;
        ImGui.SetNextWindowPos(make_ImVec2(0, xx app.current_window_height), pivot=window_pivot);
        // ImGui.SetNextWindowSize(make_ImVec2(xx app.current_window_width, -1), .Always); // Full width of OS window
        ImGui.SetNextWindowSize(make_ImVec2(-1, -1), .Always); // Just wide enough to fit all the buttons---better since mouse can interact with viewport where there are no buttons

        window_flags := ImGui.WindowFlags.NoTitleBar | .NoResize | .NoDecoration;
        if true {
            window_flags |= .NoBringToFrontOnFocus; // Prioritize drawing item list if it covers the console
            // window_flags |= .NoInputs;              // So we can interact with the scene behind the console output window
            window_flags |= .NoFocusOnAppearing;    // So we dont clobber the reclaim_focus stuff in the console input window
            window_flags |= .NoBackground;          // Makes the console log transparent
        }

        ImGui.Begin("target_items_ribbon", flags=window_flags);
        defer ImGui.End();

        // show_action_target_text(target_items);
        // ImGui.SameLine();
        Action_Button("Backface", *CYCLE_BACKFACE_MODE_ACTION_SET);
        ImGui.SameLine();
        Action_Button("Opacity", *CYCLE_OPACITY_ACTION_SET);
        ImGui.SameLine();
        Action_Button("Clipping", *TOGGLE_CLIPPING_ACTION_SET);
        ImGui.SameLine();
        Action_Button("Normals", *TOGGLE_NORMALS_ACTION_SET);
        ImGui.SameLine();
        Action_Button("Line Width", *CYCLE_LINE_WIDTH_ACTION_SET);
        ImGui.SameLine();
        Action_Button("Point Size", *CYCLE_POINT_SIZE_ACTION_SET);
        ImGui.SameLine();
        Action_Button("Face Labels", *CYCLE_ELEMENT_LABEL_ACTION_SET);
        ImGui.SameLine();
        Action_Button("Vertex Labels", *CYCLE_VERTEX_LABEL_ACTION_SET);
        ImGui.SameLine();
        Action_Button("Annotations", *CYCLE_ANNOTATION_ACTION_SET);
    }
}

apply_display_info_update :: (set : Display_Info_Update, target : Target_Items) {
    for app.entities if Is_Target(it) {
        other := *app.selection_display_info;
        using it.display_info;

        // @Cleanup Use reflection here

        if set.vertex_label_style_update.show_position     vertex_label_style.show_position     = other.vertex_label_style.show_position;
        if set.vertex_label_style_update.show_index        vertex_label_style.show_index        = other.vertex_label_style.show_index;
        if set.vertex_label_style_update.format_float      vertex_label_style.format_float      = other.vertex_label_style.format_float;
        if set.vertex_label_style_update.label_scale       vertex_label_style.label_scale       = other.vertex_label_style.label_scale;
        if set.vertex_label_style_update.label_color       vertex_label_style.label_color       = other.vertex_label_style.label_color;
        if set.vertex_label_style_update.show_backfacing   vertex_label_style.show_backfacing   = other.vertex_label_style.show_backfacing;
        if set.vertex_label_style_update.visible_radius_px vertex_label_style.visible_radius_px = other.vertex_label_style.visible_radius_px;

        if set.element_label_theme_update.show_position     element_label_theme.show_position     = other.element_label_theme.show_position;
        if set.element_label_theme_update.show_index        element_label_theme.show_index        = other.element_label_theme.show_index;
        if set.element_label_theme_update.format_float      element_label_theme.format_float      = other.element_label_theme.format_float;
        if set.element_label_theme_update.label_scale       element_label_theme.label_scale       = other.element_label_theme.label_scale;
        if set.element_label_theme_update.label_color       element_label_theme.label_color       = other.element_label_theme.label_color;
        if set.element_label_theme_update.show_backfacing   element_label_theme.show_backfacing   = other.element_label_theme.show_backfacing;
        if set.element_label_theme_update.visible_radius_px element_label_theme.visible_radius_px = other.element_label_theme.visible_radius_px;

        if set.annotation_theme_update.visible           annotation_theme.visible           = other.annotation_theme.visible;
        if set.annotation_theme_update.visible_radius_px annotation_theme.visible_radius_px = other.annotation_theme.visible_radius_px;
        if set.annotation_theme_update.label_scale       annotation_theme.label_scale       = other.annotation_theme.label_scale;
        if set.annotation_theme_update.label_color       annotation_theme.label_color       = other.annotation_theme.label_color;

        if set.is_visible           is_visible           = other.is_visible;
        if set.wireframe_visible    wireframe_visible    = other.wireframe_visible;
        if set.wireframe_width      wireframe_width      = other.wireframe_width;
        if set.surface_visible      surface_visible      = other.surface_visible;
        if set.display_mode         display_mode         = other.display_mode;
        if set.backface_mode        backface_mode        = other.backface_mode;
        if set.flat_shading         flat_shading         = other.flat_shading;
        if set.normals_visible      normals_visible      = other.normals_visible;
        if set.normals_length       normals_length       = other.normals_length;
        if set.points_visible       points_visible       = other.points_visible;
        if set.points_size          points_size          = other.points_size;

        for 0..3 {
            if set.wireframe_color[it]   wireframe_color.component[it]   = other.wireframe_color.component[it];
            if set.surface_color[it]     surface_color.component[it]     = other.surface_color.component[it];
            if set.normals_color[it]     normals_color.component[it]     = other.normals_color.component[it];
            if set.points_color[it]      points_color.component[it]      = other.points_color.component[it];
        }

        if set.color_reset {
            reset_entity_primary_color(it);
        }

        for i : 0..clip_ranges.count-1 {
            if set.clip_ranges[i] clip_ranges[i] = other.clip_ranges[i];
        }
        if set.clip_sphere clip_sphere = other.clip_sphere;
    }
}

show_folder_context_menu :: (path : string, auto_load_new_files : *bool = null) {
    current_pos := ImGui.GetWindowPos();
    current_size := ImGui.GetWindowSize();
    window_pos := make_ImVec2(current_pos.x + current_size.x + WINDOW_BORDER_UI_OFFSET.x, ImGui.GetCursorScreenPos().y);
    ImGui.SetNextWindowPos(pos=window_pos, cond=.ImGuiCond_Appearing);

    // Set popup border color to match the selection/RMB target item color
    original_border_color, original_border_size := ScopedPopupBorderTheme(CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR, CONTEXT_MENU_POPUP_TARGET_BORDER_SIZE);

    if ImGui.BeginPopupContextItem(imgui_label("Folder Options", xx *path)) {
        defer ImGui.EndPopup();

        // Undo the previous thing so internals don't have this color
        ScopedPopupBorderTheme(original_border_color, original_border_size);

        ImGui.Text(path);
        ImGui.Separator();
        if (path != PRESET_SHAPE_FOLDER && path != COMMAND_OUTPUT_FOLDER && path != SELECTION_FOLDER) && auto_load_new_files {
            ImGui.Checkbox("Auto-load new files", auto_load_new_files);
        }

        // These are disabled since the user can Ctrl LMB on folder names to select all the items and then press delete to remove them, or click on visibility to toggle visibility
        /*
        if ImGui.Button("Toggle folder selection") {
            selected_state := false;
            for app.entities if get_directory(it.fully_pathed_name) == path {
                selected_state = !it.is_selected;
                break;
            }

            for app.entities if get_directory(it.fully_pathed_name) == path {
                it.is_selected = selected_state;
            }
        }

        if ImGui.Button("Toggle folder visibility") {
            visible_state := false;
            for app.entities if get_directory(it.fully_pathed_name) == path {
                visible_state = !it.display_info.is_visible;
                break;
            }

            for app.entities if get_directory(it.fully_pathed_name) == path {
                it.display_info.is_visible = visible_state;
            }
        }
        */

        if ImGui.Button("Remove folder") {
            for app.entities if get_directory(it.fully_pathed_name) == path {
                remove it;
            }
            remove_directory(path);
        }
    }
}

show_item_context_menu :: (entity : *Entity, entity_index : s64) {
    current_pos := ImGui.GetWindowPos();
    current_size := ImGui.GetWindowSize();
    window_pos := make_ImVec2(current_pos.x + current_size.x + WINDOW_BORDER_UI_OFFSET.x, ImGui.GetCursorScreenPos().y);
    ImGui.SetNextWindowPos(pos=window_pos, cond=.ImGuiCond_Appearing);

    // Set popup border color to match the selection/RMB target item color
    original_border_color, original_border_size := ScopedPopupBorderTheme(CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR, CONTEXT_MENU_POPUP_TARGET_BORDER_SIZE);

    if ImGui.BeginPopupContextItem(imgui_label("##context_menu", xx entity_index)) {
        defer ImGui.EndPopup();

        g_next_frame_state.index_of_context_menu_popup_item = entity_index;

        // Undo the previous thing so internals don't have this color
        ScopedPopupBorderTheme(original_border_color, original_border_size);

        if (ImGui.BeginTabBar("##AnnotationTab", flags=ImGui.TabBarFlags.None)) {

            if (ImGui.BeginTabItem("Display")) {
                if !entity.is_selected {
                    if entity_name(entity).count {

                        if ImGui.Button(imgui_label("Reload", entity)) reload_entity(entity);
                        if is_changed_on_disk(entity) == false {
                            Show_Tooltip("This file has NOT changed on disk\nsince the last time it was loaded");
                        }

                        ImGui.SameLine();
                        ImGui.Checkbox(imgui_label("", entity), *entity.auto_reload);
                        Show_Tooltip("Auto-reload if file changes on disk");

                        ImGui.SameLine();
                        text := entity_description(entity, with_creation_time=true);
                        ImGui.TextUnformatted(text);
                        entity_source_tooltip(entity);
                    }

                    display_information(entity);
                    display_transform(entity);

                    normals_ui :=  entity.type == .MESH || entity.type == .POINT_CLOUD || entity.type == .POLYLINE_SOUP3;
                    lines_ui   := (entity.type == .MESH && entity.mesh.geometry_format != .POINTS) || entity.type == .POLYLINE_SOUP2 || entity.type == .POLYLINE_SOUP3;
                    faces_ui   := (entity.type == .MESH && entity.mesh.geometry_format == .TRIANGLES) || entity.type == .POLYGON_SOUP;
                    maybe_update_render_info(*entity.render_info, *entity.mesh);

                    aabb_world := transform_axis_box3(entity.mesh.world_from_model, entity.render_info.bounding_aabb);
                    set := display_info_ui(*entity.display_info, aabb_world, normals_ui=normals_ui, lines_ui=lines_ui, faces_ui=faces_ui);
                    if set.color_reset {
                        reset_entity_primary_color(entity);
                    }

                } else {
                    if ImGui.TreeNodeEx(to_c_string(tprint("Selection (% item%)", num_selected_entities(), ifx num_selected_entities() == 1 then "" else "s")), .SpanAvailWidth) {
                        defer ImGui.TreePop();

                        for :Selected entity : app.entities {
                            if entity_name(entity).count {

                                if ImGui.Button(imgui_label("Reload", entity)) reload_entity(entity);
                                if is_changed_on_disk(entity) == false {
                                    Show_Tooltip("This file has NOT changed on disk\nsince the last time it was loaded");
                                }

                                ImGui.SameLine();
                                ImGui.Checkbox(imgui_label("", entity), *entity.auto_reload);
                                Show_Tooltip("Auto-reload if file changes on disk");

                                ImGui.SameLine();
                                text := entity_description(entity, with_creation_time=true);
                                ImGui.TextUnformatted(text);
                                entity_source_tooltip(entity);
                            }
                        }

                        if ImGui.Button("Reload Selection  ") {
                            for :Selected entity : app.entities {
                                reload_entity(entity);
                            }
                            // ImGui.CloseCurrentPopup();
                        }

                        if ImGui.Button(imgui_label("Toggle Auto-Reload", *app.entities)) {
                            // Find the state to toggle
                            state := false;
                            for :Selected app.entities {
                                state = !it.auto_reload;
                                break;
                            }

                            for :Selected app.entities {
                                it.auto_reload = state;
                            }
                        }
                        Show_Tooltip("Toggle auto-reload state on selected items");

                        // This isn't actually very useful, user should use the Ctrl-a binding instead
                        //ImGui.SameLine();
                        //if ImGui.Button("Deselect All") {
                        //    for :Selected entity : app.entities {
                        //        entity.is_selected = false;
                        //    }
                        //    ImGui.CloseCurrentPopup();
                        //}
                    }

                    selection_aabb : AxisBox3;
                    for :Selected app.entities {
                        maybe_update_render_info(*it.render_info, *it.mesh);
                        // @Volatile @Cleanup only works for a shift
                        aabb := it.render_info.bounding_aabb;
                        aabb.min_point = (it.mesh.world_from_model * make_vector4(aabb.min_point, 1)).xyz;
                        aabb.max_point = (it.mesh.world_from_model * make_vector4(aabb.max_point, 1)).xyz;
                        expand(*selection_aabb, aabb);
                    }

                    set := display_info_ui(*app.selection_display_info, selection_aabb);

                    apply_display_info_update(set, .SELECTED);
                }
                ImGui.EndTabItem();
            }

            if (ImGui.BeginTabItem("Annotations")) {

                set : Display_Info_Update;
                display_info : *Display_Info;
                if entity.is_selected {
                    display_info = *app.selection_display_info;
                } else {
                    display_info = *entity.display_info;
                }
                if ImGui.TreeNodeEx("Annotation Labels", .SpanAvailWidth) {
                    defer ImGui.TreePop();

                    theme :  *Annotation_Theme = *display_info.annotation_theme;
                    update : *Annotation_Theme_Update = *set.annotation_theme_update;

                    update.visible = ImGui.Checkbox("Visible", *theme.visible);

                    // @Cleanup consider the checkbox next to a color idiom here, with separate colors for index and position labels
                    update.label_color     = ImGui.ColorEdit4("Label color", *theme.label_color.component, ImGui.ColorEditFlags.NoInputs);
                    update.label_scale     = ImGui.DragFloat("Label scale", *theme.label_scale, .005, .2, 1., format="%.3f");

                    // Visible radius
                    radius_max_px : float = max(cast(float)app.current_window_width, cast(float)app.current_window_height);
                    radius_px := cast(float) theme.visible_radius_px;
                    update.visible_radius_px  = ImGui.DragFloat("Visible Radius (px)", *radius_px, 1, 25, radius_max_px, format="%.0f");
                    theme.visible_radius_px = cast(int) radius_px;
                }
                if entity.is_selected {
                    apply_display_info_update(set, .SELECTED);
                }

                // Only display the annotations for the RMB'd entity, even if its selected. @Think Maybe this is just confusing?
                display_annotations(entity, entity_index);

                ImGui.EndTabItem();
            }
            ImGui.EndTabBar();
        }
    }
}

show_camera_controls :: () {
    window_pos := make_ImVec2(ImGui.GetIO().DisplaySize.x - WINDOW_BORDER_UI_OFFSET.x, WINDOW_BORDER_UI_OFFSET.y);
    window_pivot := make_ImVec2(1, 0);

    using ImGui.WindowFlags;

    ImGui.PushStyleColor(xx ImGui.Col.Border, .{0, 0, 0, 1});
    defer ImGui.PopStyleColor();

    ImGui.PushStyleVar(xx ImGui.StyleVar.CellPadding, .{0, 0});
    ImGui.PushStyleVar(xx ImGui.StyleVar.CellPadding, .{0, 0});
    defer ImGui.PopStyleVar();
    defer ImGui.PopStyleVar();

    // Set window border color to match the selection/RMB target item color
    original_border_color, original_border_size := ScopedWindowBorderTheme(CAMERA_UI_BORDER_COLOR, CAMERA_UI_BORDER_SIZE);

    ImGui.SetNextWindowPos(window_pos, .Always, window_pivot);
    ImGui.Begin("Camera shortcuts", flags = NoTitleBar | AlwaysAutoResize | NoMove /*| NoNav*/);
    defer ImGui.End();

    ScopedWindowBorderTheme(original_border_color, original_border_size);

    X_AXIS :: Vector3.{1, 0, 0};
    Y_AXIS :: Vector3.{0, 1, 0};
    Z_AXIS :: Vector3.{0, 0, 1};

    keep_up := app.settings.camera_controls_keep_up_when_setting_look_along;

    if ImGui.BeginTable("##ViewCube", 3) {
        defer ImGui.EndTable();
        ImGui.TableNextRow();
        ImGui.TableNextColumn();
        if ImGui.Button("+X ") {
            set_look_direction(direction=X_AXIS, up=ifx keep_up then app.camera.up_direction else Z_AXIS);
        }
        ImGui.TableNextColumn();
        if ImGui.Button("+Y ") {
            set_look_direction(direction=Y_AXIS, up=ifx keep_up then app.camera.up_direction else Z_AXIS);
        }
        ImGui.TableNextColumn();
        if ImGui.Button("+Z ") {
            set_look_direction(direction=Z_AXIS, up=ifx keep_up then app.camera.up_direction else Y_AXIS);
        }
        // ImGui.TableNextColumn();
        ImGui.SameLine();
        ImGui.DragFloat( "##Near ", *app.camera.near, .05);
        Show_Tooltip("Near plane offset");

        ImGui.TableNextRow();
        ImGui.TableNextColumn();
        if ImGui.Button("-X ") {
            set_look_direction(direction=-X_AXIS, up=ifx keep_up then app.camera.up_direction else Z_AXIS);
        }
        ImGui.TableNextColumn();
        if ImGui.Button("-Y ") {
            set_look_direction(direction=-Y_AXIS, up=ifx keep_up then app.camera.up_direction else Z_AXIS);
        }
        ImGui.TableNextColumn();
        if ImGui.Button("-Z ") {
            set_look_direction(direction=-Z_AXIS, up=ifx keep_up then app.camera.up_direction else Y_AXIS);
        }
        // ImGui.TableNextColumn();
        ImGui.SameLine();
        ImGui.DragFloat( "##Far  ", *app.camera.far, .05);
        Show_Tooltip("Far plane offset");

        ImGui.TableNextRow();
        ImGui.TableNextColumn();

        // @Volatile button text in camera control pane should be kept in sync with keymap!
        right_label, left_label, amount := "<< ", ">> ", 5.;
        if io().KeyShift {
            right_label, left_label, amount = "<<<", ">>>", 15.;
        } else if io().KeyAlt {
            right_label, left_label, amount = " < ", " > ", 1.;
        }
        if ImGui.Button(to_c_string(right_label)) {
            axis := camera_rotation_axis();
            rotate_look_direction(axis, amount);
        }
        ImGui.TableNextColumn();
        if ImGui.Button("XYZ") {
            up := normalize(cross(.{-1, 1, 0}, .{-1, -1, -1}));
            set_look_direction(direction=.{-1, -1, -1}, up=up);
        }
        ImGui.TableNextColumn();
        if ImGui.Button(to_c_string(left_label)) {
            axis := camera_rotation_axis();
            rotate_look_direction(axis, -amount);
        }
        // ImGui.TableNextColumn();
        ImGui.SameLine();
        combo_box("##Alt Axis", *app.camera.rotation_axis, type_info(type_of(app.camera.rotation_axis)));
        Show_Tooltip_Binding("Camera Rotation Axis", "Alt RMB");
    }

    // @FIXME Having this combo box here screws up the UI when you close the Settings tree :(
    // ImGui.SetNextItemWidth(-FLOAT32_MIN);
    // combo_box("", *app.camera.rotation_axis, type_info(type_of(app.camera.rotation_axis)));
    // Show_Tooltip("Alt RMB Camera Rotation Axis");

    // compiler_report("Move this menu next to the other buttons and update the changelog")

    /*
    if ImGui.TreeNodeEx("Advanced") {
        defer ImGui.TreePop();

        ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing());
        defer ImGui.Indent(ImGui.GetTreeNodeToLabelSpacing());

        // @TODO Would be better to set the look direction vector I think
        ImGui.DragFloat( "##Near ", *app.camera.near, .05);
        Show_Tooltip("Near plane offset");
        ImGui.DragFloat( "##Far  ", *app.camera.far, .05);
        Show_Tooltip("Far plane offset");
        // ImGui.DragFloat3("Orbit", *app.camera.look_position.component);
        // ImGui.DragFloat3("Eye  ", *app.camera.eye_position.component);
        // ImGui.DragFloat3("Up   ", *app.camera.up_direction.component);

        combo_box("##Alt Axis", *app.camera.rotation_axis, type_info(type_of(app.camera.rotation_axis)));
        Show_Tooltip_Binding("Camera Rotation Axis", "Alt RMB");

        // Not really needed if you can explicitly set the orbit position
        // if app.camera.look_position != Vector3.{0, 0, 0} {
        //     size_of_last_item := ImGui.GetItemRectSize();
        //     if ImGui.Button("Reset Orbit", size=size_of_last_item) {
        //         look_direction := current_look_direction();
        //         app.camera.look_position = .{0, 0, 0};
        //         app.camera.eye_position = app.camera.look_position - look_direction;
        //     }
        // }
    }
    */

    // @Incomplete add perspective/orthographic toggle
    // @Incomplete add button to reset look position

    if app.show_fps {
        ImGui.Text(tprint("% fps", formatFloat(1. / io().DeltaTime, trailing_width=2)));
    }
}

show_help_ui :: () {
    table_flags := ImGui.TableFlags.BordersInnerV;

    if ImGui.TreeNodeEx("About") {
        defer ImGui.TreePop();

        ImGui.PushStyleColor(xx ImGui.Col.Text, NICE_YELLOW);
        ImGui.Text("Prism is a tool for debugging computational geometry algorithms.");
        ImGui.PopStyleColor();

        COMPILER_VERSION_INFO :: #run tprint("Compiled with Jai version %.", compiler_get_version_info(null));
        ImGui.Text(COMPILER_VERSION_INFO);
    }

    // @Cleaup name it like a macro
    ShowBinding :: (binding : string, description : string) #expand {
        ImGui.TableNextColumn();
        ImGui.TextColored(KEYBINDING_COLOR, binding);
        ImGui.TableNextColumn();
        ImGui.Text(description);
    }

    if ImGui.TreeNodeEx("Key Bindings for Viewport") {
        defer ImGui.TreePop();
        ImGui.BeginTable("", 2, flags=table_flags);
        defer ImGui.EndTable();

        ShowBinding("MMB", "Pan the camera");
        ShowBinding("Scroll", "Zoom the camera into the position under the cursor");
        ShowBinding("Alt   Scroll", "Zoom the camera into the position under the cursor slowly");
        ShowBinding("Shift Scroll", "Zoom the camera into the camera look position");
        ShowBinding("RMB", "Rotate the camera");
        ShowBinding("Alt RMB", "Rotate about selected axis in the camera control pane");
    }

    // Needed to make sure the tooltip is visible regardless of whether the tree node is open or closed
    Tree_Node_With_Tooltip :: (label : *u8, tooltip : string) -> bool #expand {
        result := ImGui.TreeNodeEx(label);
        Show_Tooltip(tooltip);
        return result;
    }

    if ImGui.TreeNodeEx("Key Bindings for Items Tab") {
        defer ImGui.TreePop();
        ImGui.BeginTable("", 2, flags=table_flags);
        defer ImGui.EndTable();

        ShowBinding("LMB", "(on a filename) Focus an item");
        ShowBinding("Ctrl LMB", "(on a filename) Select an item");
        ShowBinding("Shift LMB", "(on a filename) Focus an item and zoom in");
        ShowBinding("RMB", "(on a filename) Open context menu which modifies only the clicked item");
        ShowBinding("RMB", "(on a selected filename) Open context menu which modifies all selected items");
        ShowBinding("RMB", "(on a color) Cycle shading styles");
        ShowBinding("MMB", "(on a color) Reset color from the filename");
        ShowBinding("LMB", "(sweep over visibility checkbox) Update item visibility");
        ShowBinding("Ctrl LMB", "(sweep over visibility checkbox) Focus hovered item");
        ShowBinding("Shift LMB", "(sweep over visibility checkbox) Focus hovered item and update camera");
    }

    if Tree_Node_With_Tooltip("Key Bindings for Selection Mode",
                              "Enable selection mode by toggling visibility\non the 'Selection' item") {
        defer ImGui.TreePop();
        ImGui.BeginTable("", 2, flags=table_flags);
        defer ImGui.EndTable();

        ShowBinding("Ctrl LMB", "Add nearest unclipped vertex to 'Selection' item");
        ShowBinding("Shift LMB", "Click-drag to set clipping sphere");
        ShowBinding("Ctrl RMB", "Place camera orbit");
    }

    if ImGui.TreeNodeEx("Key Bindings for Item Set Updates") {
        defer ImGui.TreePop();
        ImGui.BeginTable("", 2, flags=table_flags);
        defer ImGui.EndTable();

        for app.keymap_actions.mappings {
            push_allocator(temp);
            ShowBinding(to_string(it.key_code, it.modifier_flags), app.keymap_actions.procs[it.proc_info_index].name);
        }
    }

    if ImGui.TreeNodeEx("Miscellaneous Key Bindings") {
        defer ImGui.TreePop();
        ImGui.BeginTable("", 2, flags=table_flags);
        defer ImGui.EndTable();

        for app.keymap_keydown.mappings {
            push_allocator(temp);
            ShowBinding(to_string(it.key_code, it.modifier_flags), app.keymap_keydown.procs[it.proc_info_index].name);
        }
        for app.keymap.mappings {
            push_allocator(temp);
            ShowBinding(to_string(it.key_code, it.modifier_flags), app.keymap.procs[it.proc_info_index].name);
        }
    }

    outer_size : ImGui.ImVec2;
    outer_size.x = min(800., app.current_window_width * .75);
    outer_size.y = 0;

    if ImGui.TreeNodeEx("Changelog") {
        defer ImGui.TreePop();

        if ImGui.Button("Save to CHANGELOG.md") {
            contents : string;
            defer free(contents);
            time := filetime_to_readable_date(current_time_consensus(), true);
            contents = join(contents, tprint("This Changelog was saved at % via a button in the Prism application\n", time));
            contents = join(contents, "Press 'h' for the help window and find the button in the Changelog subsection\n\n\n\n");
            for app.changelog {
                entry := tprint("# Version %, %\n%\n\n\n", it.name, it.date, it.description);
                contents = join(contents, entry);
            }
            write_entire_file_to_cwd("CHANGELOG.md", contents);
        }
        Show_Tooltip("Write the changelog to CHANGELOG.md\nHandy if you want to search the changelog");

        latest := app.changelog[0];
        if ImGui.TreeNodeEx(temp_c_string(tprint("Version %, % (latest)", latest.name, latest.date))) {
            defer ImGui.TreePop();

            ImGui.PushStyleColor(xx ImGui.Col.Text, CHANGELOG_COLOR);
            ImGui.TextWrapped(latest.description);
            // ImGui.Text(latest.description); // @Bug This truncated the changelog for PRISM_VERSION_0_2_1
            ImGui.PopStyleColor();
        }

        for 1..app.changelog.count-1 {
            version := app.changelog[it];
            if ImGui.TreeNodeEx(temp_c_string(tprint("Version %, %", version.name, version.date))) {
                defer ImGui.TreePop();

                ImGui.PushStyleColor(xx ImGui.Col.Text, CHANGELOG_COLOR);
                ImGui.TextWrapped(version.description);
                // ImGui.Text(version.description);
                ImGui.PopStyleColor();
            }
        }
    }

    if ImGui.TreeNodeEx("Known Issues") {
        defer ImGui.TreePop();

        if ImGui.BeginTable("", 2, flags=table_flags | .ScrollX, outer_size=outer_size) {
            defer ImGui.EndTable();
            for app.known_issues {
                ShowBinding(it.name, it.description);
            }
        }
    }

    // @Incomplete add a message about where the keymap is for editing
}


show_pending_directories_ui :: () {
    if app.pending_directories.count == 0 {
        return;
    }

    dir : app.Pending_Directory = app.pending_directories[app.pending_directories.count - 1];

    if dir.loadable_files.count == 0 {
        // Just watch the directory
        new_folder : *app.Folder = add_directory(dir.path);
        new_folder.auto_load_new_files = dir.auto_load_new_files;
        new_folder.set_auto_reload_on_newly_loaded_files = dir.set_auto_reload_on_newly_loaded_files;
        app.pending_directories.count -= 1; // We were handling the last directory, so can just decrement the array count
        return;
    }

    ImGui.SetNextWindowPos(make_ImVec2(app.current_window_width / 2., app.current_window_height / 2.), pivot=.{.5, .5}, cond=.ImGuiCond_Appearing);
    // ImGui.SetNextWindowSizeConstraints(make_ImVec2(app.current_window_width * .6, app.current_window_height * .75),
    //                                    make_ImVec2(app.current_window_width * .6, app.current_window_height * .75));
    window_flags := ImGui.WindowFlags.NoTitleBar | .NoCollapse | .AlwaysAutoResize;

    // @Incomplete Could have a policy to just load everything rather than ask?

    ImGui.Begin(imgui_label(tprint("Handle Directory 1 of %", app.pending_directories.count), xx *app.pending_directories), flags=window_flags);
    defer ImGui.End();

    // ScopedWindowBorderTheme(original_border_color, original_border_size);

    ImGui.Text("Select files to load in:");
    ImGui.SameLine();
    ImGui.PushStyleColor(xx ImGui.Col.Text, GREEN);
    ImGui.Text(dir.path);
    ImGui.PopStyleColor();

    table_flags := ImGui.TableFlags.RowBg | .Resizable | .Reorderable | .Hideable | .Sortable
     | .PreciseWidths // Maybe (?) helps fix a ugly clipping problem next to the vertical scrollbar
     | .ScrollY; // Without this option the outer_size argument is ignored

    // outer_size := make_ImVec2(0, min(cast(float)(FONT_SIZE * dir.loadable_files.count), 200));
    outer_size := make_ImVec2(0, 400);
    if ImGui.BeginTable(imgui_label("##loadable_file_table"), 4, flags=table_flags, outer_size=outer_size) {
        defer ImGui.EndTable();

        ImGui.TableSetupColumn("File",     ImGui.TableColumnFlags.WidthFixed | .DefaultSort, 0);
        ImGui.TableSetupColumn("Modtime",  ImGui.TableColumnFlags.WidthFixed, 0);
        ImGui.TableSetupColumn("Size",     ImGui.TableColumnFlags.WidthFixed, 0);
        ImGui.TableSetupColumn("Notes",    ImGui.TableColumnFlags.WidthFixed, 60);
        ImGui.TableSetupScrollFreeze(0, 1); // Make row always visible
        ImGui.TableHeadersRow();

        // Sort our data if sort specs have been changed!
        sort_specs : *ImGui.TableSortSpecs = ImGui.TableGetSortSpecs();
        if sort_specs && sort_specs.SpecsDirty {
            if sort_specs.SpecsCount > 0 {
                specs : []ImGui.TableColumnSortSpecs;
                specs.data = sort_specs.Specs;
                specs.count = sort_specs.SpecsCount;
                for spec : specs { // @CompilerBug Should using work on a for loop?
                    // @Cleanup Use a enum id here, ImGui has support for it
                    direction := spec.SortDirection_;
                    if spec.SortDirection_ == .Ascending {
                        if spec.ColumnIndex == {
                            case 0; quick_sort(dir.loadable_files, (a,b) => (compare_strings(a.fully_pathed_filename, b.fully_pathed_filename)));
                            case 1; quick_sort(dir.loadable_files, (a,b) => (compare_apollo_times(a.modtime, b.modtime)));
                            case 2; quick_sort(dir.loadable_files, (a,b) => (compare_floats(xx a.size_in_bytes, xx b.size_in_bytes)));
                        }
                    } else {
                        if spec.ColumnIndex == {
                            case 0; quick_sort(dir.loadable_files, (a,b) => (-compare_strings(a.fully_pathed_filename, b.fully_pathed_filename)));
                            case 1; quick_sort(dir.loadable_files, (a,b) => (-compare_apollo_times(a.modtime, b.modtime)));
                            case 2; quick_sort(dir.loadable_files, (a,b) => (-compare_floats(xx a.size_in_bytes, xx b.size_in_bytes)));
                        }
                    }
                }
            }
            sort_specs.SpecsDirty = false; // Make sure we don't sort on every frame
        }

        for * :ListClipperIterator loadable_file : dir.loadable_files {
            using loadable_file;

            ImGui.TableNextColumn();
            checkbox_press_or_sweep_to_toggle(*is_selected, imgui_label(fully_pathed_filename, loadable_file), *pending_directories_sweep_state, app.window);

            ImGui.TableNextColumn();
            ImGui.Text(tprint("%", filetime_to_readable_date(modtime)));

            size, unit := readable_memory_size_decimal(size_in_bytes);
            size_with_unit : string;
            if      size < 10  size_with_unit = tprint("  % %", size, unit);
            else if size < 100 size_with_unit = tprint( " % %", size, unit);
            else               size_with_unit = tprint(  "% %", size, unit);
            ImGui.TableNextColumn();
            ImGui.Text(size_with_unit);

            message : string;
            ImGui.TableNextColumn();
            if loadable_file.is_loaded {
                ImGui.PushStyleColor(xx ImGui.Col.Text, NICE_YELLOW);
                message = "Already loaded";
                ImGui.Text(message);
                ImGui.PopStyleColor();
            } else {
                message = "(none)";
                ImGui.TextDisabled(message);
            }
            Show_Tooltip(message);
        }
    }

    if dir.unloadable_file_count {
        ImGui.Text(tprint("Found % files without loadable extension (obj, wkt)", dir.unloadable_file_count)); // :PluginFileFormats
    } 
    
    if ImGui.Button(imgui_label("Accept", xx *dir)) {

        new_folder : *app.Folder = add_directory(dir.path);
        new_folder.auto_load_new_files = dir.auto_load_new_files;
        new_folder.set_auto_reload_on_newly_loaded_files = dir.set_auto_reload_on_newly_loaded_files;

        for file : dir.loadable_files {
            if !file.is_selected {
                continue;
            }

            if file.is_loaded {
                entity := find_entity(file.fully_pathed_filename, -1);
                assert(entity != null);
                reload_entity(entity);
            } else {
                // Note we use .IGNORE rather than app.settings.duplicate_file_behaviour here, the user can get the latter behaviour by dragging in files individually
                entity := load_one_file(file.fully_pathed_filename, .IGNORE);
                if entity {
                    add_entity(entity, .IGNORE); 
                    entity.auto_reload = dir.set_auto_reload_on_newly_loaded_files;
                }
            }
        }

        if app.settings.fit_to_screen_on_file_drop_event {
            fit_scene_on_screen();
        }

        deinit(dir);
        app.pending_directories.count -= 1; // We were handling the last directory, so can just decrement the array count
    }
    Show_Tooltip("Load all selected/checked files");

    ImGui.SameLine();

    if ImGui.Button(imgui_label("Ignore", xx *dir)) {
        deinit(dir);
        app.pending_directories.count -= 1; // We were handling the last directory, so can just decrement the array count
    }
    Show_Tooltip("Do not load any files");

    ImGui.SameLine();

    if app.pending_directories.count > 1 {
        if ImGui.Button(imgui_label("Ignore All", xx *dir)) {
            for *dir : app.pending_directories {
                deinit(dir);
            }
            array_reset(*app.pending_directories);
        }
        Show_Tooltip(tprint("Do not load any files from all % pending directories", app.pending_directories.count));
    }
}



show_imgui_demo_window :: () {
    if app.settings.show_imgui_demo_window {
        ImGui.ShowDemoWindow(*app.settings.show_imgui_demo_window);
    }
}

#scope_file

Label_Theme_Update :: struct {
    show_position : bool;
    show_index : bool;
    format_float : bool;
    label_scale : bool;
    label_color : bool;

    visible_radius_px : bool;
    show_backfacing : bool;
}

Annotation_Theme_Update :: struct {
    visible : bool;
    visible_radius_px : bool;
    label_scale : bool;
    label_color : bool;
}

// @TODO Implment a compile-time check that the entries here match Display_Mode, use annotations to selectively ignore stuff
Display_Info_Update :: struct {

    is_visible : bool;

    points_visible : bool;
    points_color : [4]bool;
    points_size : bool;
    vertex_label_style_update : Label_Theme_Update;
    element_label_theme_update : Label_Theme_Update;
    annotation_theme_update : Annotation_Theme_Update;

    normals_visible : bool;
    normals_color : [4]bool;
    normals_length : bool;

    wireframe_visible : bool;
    wireframe_color : [4]bool;
    wireframe_width : bool;

    surface_visible : bool;
    surface_color : [4]bool;

    display_mode : bool;
    backface_mode : bool;
    flat_shading : bool;

    color_reset : bool; @NoSync

    clip_ranges : [3]bool;
    clip_sphere : bool;
}

#run {
    info :   Display_Info;
    update : Display_Info_Update;
    if info.clip_ranges.count != update.clip_ranges.count {
        error_message := tprint("Expected clip_ranges arrays to have equal sizes (% != %)", info.clip_ranges.count, update.clip_ranges.count);
        compiler_report(#file, #line, 0, error_message);
    }
}

show_label_theme_ui :: (update : *Label_Theme_Update, theme : *Label_Theme) {
    // @Cleanup consider the checkbox next to a color idiom here, with separate colors for index and position labels
    update.show_index      = ImGui.Checkbox("Label indices", *theme.show_index);
    update.show_position   = ImGui.Checkbox("Label coordinates (model space)", *theme.show_position);
    update.label_color     = ImGui.ColorEdit4("Label color", *theme.label_color.component, ImGui.ColorEditFlags.NoInputs);
    update.show_backfacing = ImGui.Checkbox("Label backfacing", *theme.show_backfacing);
    update.label_scale     = ImGui.DragFloat("Label scale", *theme.label_scale, .005, .2, 1., format="%.3f");

    // Float format options
    trailing_width : s32 = xx theme.format_float.trailing_width;
    update.format_float |= ImGui.InputInt("Float decimals", *trailing_width);
    theme.format_float.trailing_width = clamp(trailing_width, 0, 12);
    Show_Tooltip("Number of digits following the decimal point");
    update.format_float |= combo_box("Float format", *theme.format_float.mode, type_info(FormatFloat.Mode));

    // Visible radius
    radius_max_px : float = max(cast(float)app.current_window_width, cast(float)app.current_window_height);
    radius_px := cast(float) theme.visible_radius_px;
    update.visible_radius_px  = ImGui.DragFloat("Visible Radius (px)", *radius_px, 1, 25, radius_max_px, format="%.0f");
    theme.visible_radius_px = cast(int) radius_px;
}

display_info_ui :: (
    display_info : *Display_Info,
    aabb :         AxisBox3,
    normals_ui :   bool = true,
    lines_ui :     bool = true,
    faces_ui :     bool = true,
    clipping_ui :  bool = true) -> Display_Info_Update {

    set : Display_Info_Update;

    if ImGui.TreeNodeEx("Rendering", .SpanAvailWidth) {
        defer ImGui.TreePop();

        ImGui.Text("Visible    ");
        ImGui.SameLine();
        set.is_visible = ImGui.Checkbox(imgui_label("##item_visible", display_info), *display_info.is_visible);
        Show_Tooltip("Overall item visibility");

        // FIXME FIXME: opacity should control wireframe??
        ImGui.Text("Render Mode");
        ImGui.SameLine();
        ImGui.PushItemWidth(120);
        set.display_mode = combo_box("##display_mode", *display_info.display_mode, type_info(type_of(display_info.display_mode)));
        ImGui.PopItemWidth();

        // This doesn't seem very useful so I removed it
        //ImGui.SameLine();
        //set.color_reset = ImGui.Button(imgui_label("Reset Colors##color_reset", display_info));
        //Show_Tooltip("Deduce item primary colors from the file path");

        {
            ImGui.Text("Points     ");
            ImGui.SameLine();
            set.points_visible = ImGui.Checkbox(imgui_label("##points_visible", display_info), *display_info.points_visible);
            Show_Tooltip("Points visibility");
            ImGui.SameLine();
            old_color := display_info.points_color;
            ImGui.ColorEdit4(imgui_label("##points_color", display_info), *display_info.points_color.component, ImGui.ColorEditFlags.NoInputs);
            for 0..3 set.points_color[it] = old_color.component[it] != display_info.points_color.component[it];
            ImGui.SameLine();
            ImGui.SameLine();
            ImGui.PushItemWidth(70);
            set.points_size = ImGui.InputInt("##points_size", *display_info.points_size);
            Show_Tooltip("Size");
            display_info.points_size = clamp(display_info.points_size, 1, 10);
            ImGui.PopItemWidth();
        }

        if normals_ui {
            ImGui.Text("Normals    ");
            ImGui.SameLine();
            set.normals_visible = ImGui.Checkbox(imgui_label("##normals_visible", display_info), *display_info.normals_visible);
            Show_Tooltip("Normals visibility");
            ImGui.SameLine();
            old_color := display_info.normals_color;
            ImGui.ColorEdit4(imgui_label("##normals_color", display_info), *display_info.normals_color.component, ImGui.ColorEditFlags.NoInputs);
            for 0..3 set.normals_color[it] = old_color.component[it] != display_info.normals_color.component[it];
            ImGui.SameLine();
            ImGui.PushItemWidth(70);
            set.normals_length = ImGui.DragFloat(imgui_label("##normals_length", display_info), *display_info.normals_length, .05);
            Show_Tooltip("Length");
            ImGui.PopItemWidth();
        }

        if lines_ui {
            ImGui.Text("Lines      ");
            ImGui.SameLine();
            set.wireframe_visible = ImGui.Checkbox(imgui_label("##wireframe_visible", display_info), *display_info.wireframe_visible);
            Show_Tooltip("Lines visibility");
            ImGui.SameLine();
            old_color := display_info.wireframe_color;
            ImGui.ColorEdit4(imgui_label("##wireframe_color", display_info), *display_info.wireframe_color.component, ImGui.ColorEditFlags.NoInputs);
            for 0..3 set.wireframe_color[it] = old_color.component[it] != display_info.wireframe_color.component[it];
            ImGui.SameLine();
            ImGui.PushItemWidth(70);
            set.wireframe_width = ImGui.DragFloat(imgui_label("##wireframe_width", display_info), *display_info.wireframe_width, .05);
            Show_Tooltip("Width");
            display_info.wireframe_width = clamp(display_info.wireframe_width, 1, 5);
            ImGui.PopItemWidth();
        }

        if faces_ui {
            ImGui.Text("Triangles  ");
            ImGui.SameLine();
            set.surface_visible = ImGui.Checkbox(imgui_label("##surface_visible", display_info), *display_info.surface_visible);
            Show_Tooltip("Triangles visibility");
            {
                ImGui.SameLine();
                old_color := display_info.surface_color;
                ImGui.ColorEdit4(imgui_label("##surface_color", display_info), *display_info.surface_color.component, ImGui.ColorEditFlags.NoInputs);
                Show_Tooltip("Frontface Color");
                for 0..3 set.surface_color[it] = old_color.component[it] != display_info.surface_color.component[it];
            }
            ImGui.SameLine();
            ImGui.PushItemWidth(70);
            set.backface_mode = combo_box("##Backface Mode", *display_info.backface_mode, type_info(Backface_Mode));
            Show_Tooltip("Backface Render Mode");
            ImGui.PopItemWidth();
            ImGui.SameLine();
            set.flat_shading = ImGui.Checkbox(imgui_label("##Flat Shading", display_info), *display_info.flat_shading);
            Show_Tooltip("Flat Shading");
        }
    }

    if clipping_ui {
        show_clipping_ui(*set, display_info, aabb);
    }

    if ImGui.TreeNodeEx("Point Labels", .SpanAvailWidth) {
        defer ImGui.TreePop();
        show_label_theme_ui(*set.vertex_label_style_update, *display_info.vertex_label_style);
    }

    // @TODO Rename element to triangle/segment/segment for meshes/polylines/polygons
    if ImGui.TreeNodeEx("Element Labels", .SpanAvailWidth) {
        defer ImGui.TreePop();
        show_label_theme_ui(*set.element_label_theme_update, *display_info.element_label_theme);
    }

    return set;
}

display_information :: (entity : *Entity) {
    if ImGui.TreeNodeEx("Information", .SpanAvailWidth) {
        defer ImGui.TreePop();
        ImGui.PushStyleColor(xx ImGui.Col.Text, NICE_YELLOW);
        defer ImGui.PopStyleColor();

        if #complete entity.type == {
            case .POLYLINE_SOUP2;

                using soup := cast(*Polyline_Soup2_Entity)entity;
                ImGui.Text("PolylineSoup2 #points, #polylines = %, %", point_count(shape), shape.polylines.count);

            case .POLYLINE_SOUP3;

                using soup := cast(*Polyline_Soup3_Entity)entity;
                ImGui.Text("PolyineSoup3 #points, #polylines = %, %", point_count(shape), shape.polylines.count);

            case .SEGMENT_SOUP3;

                using soup := cast(*Segment_Soup3_Entity)entity;
                ImGui.Text("SegmentSoup3 #points, #polylines = %, %", soup.mesh.positions.count, soup.mesh.indices.count / 2);

            case .POLYGON_SOUP;

                using soup := cast(*Polygon_Soup_Entity)entity;
                ImGui.Text("PolygonSoup #points, #polygons = %, %", point_count(shape), shape.polygons.count);

            case .POINT_CLOUD;

                cloud := cast(*Point_Cloud_Entity)entity;
                ImGui.Text("PointCloud #points = %", cloud.mesh.positions.count);

            case .UNKNOWN;     #through;
            case .MESH;

                mesh := cast(*Mesh_Entity)entity;
                if #complete mesh.mesh.geometry_format == {
                    case .UNKNOWN; #through;
                    case .POINTS;
                        // @Cleanup: This never happens, its handled in .POINT_
                        ImGui.Text("Mesh #points = %", mesh.mesh.positions.count);
                    case .LINES;
                        ImGui.Text("Mesh #points, #lines = %, %", mesh.mesh.positions.count, mesh.mesh.indices.count / 2);
                    case .TRIANGLES;
                        ImGui.Text("Mesh #points, #triangles = %, %", mesh.mesh.positions.count, mesh.mesh.indices.count / 3);
                }
        }
        maybe_update_render_info(*entity.render_info, *entity.mesh);

        imgui_text_for_aabb(entity.render_info.bounding_aabb);
    }
}

display_transform :: (entity : *Entity) {
    if ImGui.TreeNodeEx("Transform", .SpanAvailWidth) {
        defer ImGui.TreePop();
        ImGui.PushStyleColor(xx ImGui.Col.Text, NICE_YELLOW);
        ImGui.Text("This is a \"world from model\" transform");
        ImGui.PopStyleColor();
        shift := make_vector3(entity.mesh.world_from_model._14, entity.mesh.world_from_model._24, entity.mesh.world_from_model._34);
        prev_shift := shift;
        if ImGui.DragFloat3(imgui_label("Offset", entity), *shift.component, .05) {
            update_entity_transform(entity, shift - prev_shift);
        }
    }
}

display_annotations :: (entity : *Entity, entity_index : int) {

    header := "Annotations (none)";
    annotation_count := entity_annotation_count(entity);
    if annotation_count {
        header = tprint("Annotations (%)", annotation_count);
    } else {
        ImGui.BeginDisabled();
    }
    defer if annotation_count == 0 then ImGui.EndDisabled();

    if ImGui.TreeNodeEx(imgui_label(header, entity), .SpanAvailWidth) {
        defer ImGui.TreePop();

        DoRadioButton :: (name : string, annotations_kind : Annotation.Kind, annotations : [..]Annotation) #expand {
            if !annotations.count ImGui.BeginDisabled();
            ImGui.RadioButton(name, xx *`entity.annotation_info.show_kind, xx annotations_kind);
            if !annotations.count ImGui.EndDisabled();
        }

        DoRadioButton("Vertex", .VERTEX, entity.vertex_annotations);
        ImGui.SameLine();
        DoRadioButton("Edge", .LINE, entity.line_annotations);
        ImGui.SameLine();
        DoRadioButton("Face", .TRIANGLE, entity.face_annotations);
        ImGui.SameLine();
        DoRadioButton("Block", .BLOCK, entity.block_annotations);

        annotations : [..]Annotation;
        if entity.annotation_info.show_kind == {
            case .VERTEX;   annotations = entity.vertex_annotations;
            case .LINE;     annotations = entity.line_annotations;
            case .TRIANGLE; annotations = entity.face_annotations;
            case .BLOCK;    annotations = entity.block_annotations;
        }

        if annotations.count {

            table_flags := ImGui.TableFlags.RowBg | .ScrollY | .RowBg | .Resizable | .Reorderable | .Hideable | .Sortable;
            outer_size := make_ImVec2(0, app.settings.annotation_list_max_size_before_scroll_px);

            if last_frame_annotation_list_height_px < outer_size.y {
                table_flags &= ~.ScrollY;
                outer_size.y = 0; // Not really necessary, since its ignored unless flags include ScrollY
            }

            column_count : s32 = 4;
            if ImGui.BeginTable("##Annotations_Table", column_count, flags=table_flags, outer_size=outer_size) {
                defer ImGui.EndTable();

                ImGui.TableSetupColumn("UI",         ImGui.TableColumnFlags.WidthFixed | .NoSort);
                ImGui.TableSetupColumn("Index",      ImGui.TableColumnFlags.WidthFixed | .DefaultSort);
                ImGui.TableSetupColumn("Type",       ImGui.TableColumnFlags.WidthFixed | .NoSort);
                ImGui.TableSetupColumn("Annotation", ImGui.TableColumnFlags.WidthStretch);
                ImGui.TableSetupScrollFreeze(0, 1); // Make row always visible
                ImGui.TableHeadersRow();

                // Sort our data if sort specs have been changed!
                sort_specs : *ImGui.TableSortSpecs = ImGui.TableGetSortSpecs();
                if sort_specs && sort_specs.SpecsDirty {
                    if sort_specs.SpecsCount > 0 {
                        specs : []ImGui.TableColumnSortSpecs;
                        specs.data = sort_specs.Specs;
                        specs.count = sort_specs.SpecsCount;
                        for spec : specs { // @CompilerBug Should using work on a for loop?
                            // @Cleanup Use a enum id here, ImGui has support for it
                            if spec.SortDirection_ == .Ascending {
                                if spec.ColumnIndex == {
                                    case 1; quick_sort(annotations, (a,b) => (compare_annotation_ids(a,b)));
                                    case 3; quick_sort(annotations, (a,b) => (compare_annotation_values(a, b)));
                                }
                            } else {
                                if spec.ColumnIndex == {
                                    case 1; quick_sort(annotations, (a,b) => (-compare_annotation_ids(a,b)));
                                    case 3; quick_sort(annotations, (a,b) => (-compare_annotation_values(a, b)));
                                }
                            }
                        }
                    }
                    sort_specs.SpecsDirty = false; // Make sure we don't sort on every frame
                }

                last_frame_annotation_list_height_px = 0.;
                for * :ListClipperIterator annotation : annotations {
                    last_frame_annotation_list_height_px = clipper.ItemsHeight;

                    ImGui.TableNextRow();

                    ImGui.TableNextColumn();
                    if annotation.kind == .BLOCK {
                        // @Incomplete Add an show/hide button to fold multiline comments?
                    } else {
                        if ImGui.Button(imgui_label("Focus", xx annotation)) {
                            if annotation.kind == {
                                case .TRIANGLE;
                                    item_focus_triangle(entity_index, annotation.id, ifx io().KeyShift then 0. else -1.);
                                case .VERTEX;
                                    item_focus_vertex(entity_index, annotation.id, ifx io().KeyShift then 0. else -1.);
                                case .LINE;
                                    item_focus_segment(entity_index, annotation.id, ifx io().KeyShift then 0. else -1.);
                            }
                        }
                        bindings : [..]Binding_With_Description;
                        bindings.allocator = temp;
                        array_add(*bindings, make_Binding_With_Description( "LMB",       "Update camera to focus subject"));
                        array_add(*bindings, make_Binding_With_Description( "Shift LMB", "As above, with sphere clipping"));
                        Show_Tooltip_Binding(..bindings);
                    }

                    ImGui.TableNextColumn();
                    ImGui.Text(tprint("%", annotation.id));

                    ImGui.TableNextColumn();
                    ImGui.Text(tprint("%", annotation.value.tag));

                    ImGui.TableNextColumn();
                    ImGui.Text(to_string(annotation));
                }
                last_frame_annotation_list_height_px *= annotations.count; // FIXME This is wrong if string annotations have different numbers of lines
            }

        }
    }
}

last_frame_annotation_list_height_px : float;

show_clipping_ui :: (set : *Display_Info_Update, using display_info : *Display_Info, aabb : AxisBox3) {

    if ImGui.TreeNodeEx("Clipping", .SpanAvailWidth) {
        defer ImGui.TreePop();

        if ImGui.BeginTable("##Clipping UI Table", 7) { // , flags=ImGui.TableFlags.SizingFixedFit) {
            defer ImGui.EndTable();

            ImGui.TableSetupColumn("checkbox", .WidthFixed, user_id=0);
            ImGui.TableSetupColumn("center/normal", .WidthFixed, user_id=1);
            ImGui.TableSetupColumn("center/normal value", .WidthFixed, init_width_or_weight=200, user_id=2);
            ImGui.TableSetupColumn("radius/range", .WidthFixed, user_id=3);
            ImGui.TableSetupColumn("radius/range value", .WidthFixed, init_width_or_weight=200, user_id=4);
            ImGui.TableSetupColumn("reset", .WidthFixed, user_id=5);
            ImGui.TableSetupColumn("normalize", .WidthFixed, user_id=6);

            {
                ImGui.TableNextRow();
                changed := false;

                ImGui.TableSetColumnIndex(0);
                changed |= ImGui.Checkbox(imgui_label("Sphere##clip_sphere", *clip_sphere), *clip_sphere.is_active); Show_Tooltip("Enable clipping using distance from a point.\nKeep the region inside the sphere.");
                ImGui.TableSetColumnIndex(1);
                ImGui.Text("Center");
                ImGui.TableSetColumnIndex(2);
                ImGui.SetNextItemWidth(-FLOAT32_MIN);
                changed |= ImGui.DragFloat3(imgui_label("##clip_sphere.center", *clip_sphere), *clip_sphere.center.component, .05, format="%.3f");
                ImGui.TableSetColumnIndex(3);
                ImGui.Text("Radius");
                ImGui.TableSetColumnIndex(4);
                ImGui.SetNextItemWidth(-FLOAT32_MIN);
                changed |= ImGui.DragFloat(imgui_label("##clip_sphere.radius", *clip_sphere), *clip_sphere.radius, .01, 0., 0., format="%.3f");
                ImGui.TableSetColumnIndex(5);
                POSITIVE_INF :: 0h7F800000;
                uninitialized := (clip_sphere.radius == POSITIVE_INF);
                if ImGui.Button(imgui_label("Reset##sphere", *clip_sphere)) || uninitialized {
                    clip_sphere.center = .{0, 0, 0};
                    clip_sphere.radius = POSITIVE_INF;
                    changed = true;
                }
                Show_Tooltip("Reset sphere to contain the universe");

                set.clip_sphere = changed;
            }

            {
                clip_range_ui :: (p : *Clip_Range, aabb : AxisBox3) -> (changed : bool) {
                    ImGui.TableNextRow();
                    changed := false;

                    MIN_RANGE :: .1;

                    ImGui.TableSetColumnIndex(0);
                    changed |= ImGui.Checkbox(imgui_label("Slab##clip_plane", p), *p.is_active); Show_Tooltip("Enable clipping using a distance range from a plane passing through the origin.\nKeep the region bounded by the parallel planes positioned at the range min/max.");
                    ImGui.TableSetColumnIndex(1);
                    ImGui.Text("Normal");
                    ImGui.TableSetColumnIndex(2);
                    ImGui.SetNextItemWidth(-FLOAT32_MIN);
                    changed |= ImGui.DragFloat3(imgui_label("##normal", *p.normal.component), *p.normal.component, .05, format="%.3f");
                    ImGui.TableSetColumnIndex(3);
                    ImGui.Text("Range");
                    ImGui.TableSetColumnIndex(4);
                    range := make_vector2(p.min, p.max);
                    ImGui.SetNextItemWidth(-FLOAT32_MIN);
                    if ImGui.DragFloat2(imgui_label("##range", *p.min), *range.component, .05, format="%.3f") {
                        p.min, p.max = range.x, range.y;
                        p.min = min(p.min, p.max - MIN_RANGE);
                        p.max = max(p.min + MIN_RANGE, p.max);
                        changed = true;
                    }

                    NEGATIVE_INF :: 0hFF800000;
                    POSITIVE_INF :: 0h7F800000;

                    ImGui.TableSetColumnIndex(5);
                    uninitialized := (p.min == NEGATIVE_INF) || (p.max == POSITIVE_INF);
                    if ImGui.Button(imgui_label("Reset", p)) || uninitialized {
                        p.min = POSITIVE_INF;
                        p.max = NEGATIVE_INF;
                        for :CornersIterator aabb {
                            plane := make_hyperplane3(p.normal, Vector3.{0, 0, 0});
                            dist := signed_distance_point3_plane3(it, plane);
                            p.min = min(p.min, dist);
                            p.max = max(p.max, dist);
                        }
                        p.min -= .0001;
                        p.max += .0001;
                        changed = true;
                    }
                    Show_Tooltip("Reset the range min/max to keep the entire aabb");

                    ImGui.TableSetColumnIndex(6);
                    if ImGui.Button(imgui_label("Normalize", p)) {
                        normal_length := length(p.normal);
                        if normal_length != 0 {
                            p.min /= normal_length;
                            p.max /= normal_length;
                            p.normal /= normal_length;
                        }
                        changed = true;
                    }
                    Show_Tooltip("Make the normal unit and update the range min/max");

                    return changed;
                }

                display_info.aabb_visible = true;

                set.clip_ranges[0] = clip_range_ui(*clip_ranges[0], aabb);
                set.clip_ranges[1] = clip_range_ui(*clip_ranges[1], aabb);
                set.clip_ranges[2] = clip_range_ui(*clip_ranges[2], aabb);

                if almost_equal(length(clip_ranges[0].normal), 0.) clip_ranges[0].normal = .{1, 0, 0};
                if almost_equal(length(clip_ranges[1].normal), 0.) clip_ranges[1].normal = .{0, 1, 0};
                if almost_equal(length(clip_ranges[2].normal), 0.) clip_ranges[2].normal = .{0, 0, 1};
            }
        }
    }
}

// @Cleanup I think to_c_string leaks memory, perhaps we can fix by pushing the temporary allocator before calling it

#scope_file

display_action_buttons := true;

imgui_text_for_aabb :: (aabb : AxisBox3) {
    ImGui.Text("Model space AABB:");
    ImGui.Text("Max [%, %, %]", aabb.max_point.x, aabb.max_point.y, aabb.max_point.z);
    ImGui.Text("Min [%, %, %]", aabb.min_point.x, aabb.min_point.y, aabb.min_point.z);
}

entity_source_tooltip :: (entity : Entity) {
    if #complete entity.source == {
        case .UNKNOWN;        // Do nothing
        case .FILE_ON_DISK;   Show_Tooltip(tprint("File:    %\nCreated: %", entity.fully_pathed_name, filetime_to_readable_date(entity.creation_time)));
        case .COMMAND_OUTPUT; Show_Tooltip(tprint("Command: %\nCreated: %", entity.console_command, filetime_to_readable_date(entity.creation_time)));
        case .PRESET_SHAPE;   Show_Tooltip(tprint("Preset shape\nCreated: %", filetime_to_readable_date(entity.creation_time)));
        case .SELECTION;      Show_Tooltip(tprint("% Selection\nCreated: %", to_nice_string(entity.mesh.geometry_format), filetime_to_readable_date(entity.creation_time)));
    }
}

pending_directories_sweep_state : Checkbox_Sweep_Mode_State;

// Checkbox sweep mode is enabled while LMB is held down if it was clicked on a sweepable checkbox, the mouse will be constrained to move only up and down and the inverse of the state of the checkbox just before the click will be set on all the checkboxes that get swept
item_list_sweep_state : Checkbox_Sweep_Mode_State;

FADE_TIME_SECS :: 1.;


#scope_export // @CompilerBug without this scope_export the line below errors!
ISSUE_008 :: "Sphere clipping does not work if the Selection item is not visible"; @KnownIssue

// ImGui is immediate mode so we may have already drawn items which we want to change due to a UI interaction we're just drawing now.
// This stuct stores stuff we need to remember to use in the next render frame
ImGui_Frame_State :: struct {
    index_of_context_menu_popup_item : int = -1; // This is used to update the background color of item names which are being edited by the context menu popup
    index_of_selected_item_where_visibility_changed_by_click : int = -1; // This is used to implement show/hiding a selection using a selected checkbox
    index_of_selected_item_where_color_was_changed : int = -1;
    index_of_selected_item_where_color_was_reset : int = -1;
    index_of_selected_item_where_mode_was_cycled : int = -1;
}

// State relevant to the currently rendering frame
g_this_frame_state : ImGui_Frame_State;

// State relevant to the next rendering frame
// This will be reset at the start of the currently rendering frame
// Set fields whenever convenient in the currently rendering frame
g_next_frame_state : ImGui_Frame_State;
