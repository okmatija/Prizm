WINDOW_BORDER_UI_OFFSET :: ImGui.ImVec2.{10, 10};

// @Refactor This function is too long (especially the top level for loop). Break it up.
show_item_list_ui :: () {
    using app;

    if !entities.count return;

    ImGui.SetNextWindowPos(WINDOW_BORDER_UI_OFFSET);
    ImGui.Begin("Main Panel", flags = ImGui.WindowFlags.AlwaysAutoResize | .NoTitleBar);
    defer ImGui.End();

    // ImGui.ColorEdit4("debug_color", *app.debug_color.component, ImGui.ColorEditFlags.NoInputs);

    any_visibility_changed := false;

    {
        show_entity_index := app.console.visible || app.user_selection.is_visible;

        ImGui.BeginTable("Item List Table", xx (ifx show_entity_index then 5 else 4), flags=ImGui.TableFlags.NoBordersInBody);
        defer ImGui.EndTable();

        entity_to_remove := -1;
        for entities {
            ImGui.TableNextRow();

            // Remove button
            ImGui.TableNextColumn();
            if ImGui.Button(imgui_label("Remove", it)) {
                entity_to_remove = it_index;
            }

            // Color selection
            {
                ImGui.TableNextColumn();
                if it.display_info.display_mode == .NORMALS {
                    ImGui.TextDisabled("NR.");
                } else {
                    color := entity_primary_color(it);
                    if color {
                        ImGui.ColorEdit4(imgui_label("##color", it), *color.component, ImGui.ColorEditFlags.NoInputs);
                    }
                }
                if ImGui.IsItemClicked(.Right) {
                    cycle_display_mode(*it.display_info.display_mode);
                } else if ImGui.IsItemClicked(.Middle) {
                    if it.display_info.display_mode != .NORMALS {
                        color := entity_primary_color(it);
                        <<color = color_from_path(it.fully_pathed_filename);
                    }
                }
            }

            // Toggle visibility checkbox
            {
                ImGui.TableNextColumn();
                was_visible := it.is_visible;
                visibility_changed := checkbox_press_or_sweep_to_toggle(*it.is_visible, imgui_label("##Visible", it), *app.sweep_state, app.window);
                any_visibility_changed = any_visibility_changed || visibility_changed;
                Show_Tooltip("Visible");

                if !was_visible && it.is_visible {
                    // Make sure we see something when turning on visibility. We don't consider normals here since there might not be any, or they might have zero length
                    if !it.display_info.surface_visible && !it.display_info.wireframe_visible && !it.display_info.points_visible {
                        it.display_info.surface_visible = true;
                    }
                }
            }

            // Toggle clipping checkbox?

            // Entity index used to refer to geometry in console or annotate the text following ther cursor when adding to the user selection
            if show_entity_index {
                ImGui.TableNextColumn();
                if it.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity {
                    ImGui.Text("#%", it_index);
                    Show_Tooltip("Entity index for console commands\nand user selection cursor labels");
                } else {
                    ImGui.TextDisabled("#%", it_index);
                    Show_Tooltip("Entity index for console commands\nand user selection cursor labels\nIncrease max point count to select this entity");
                }
            }

            // Write filename
            ImGui.TableNextColumn();
            // ImGui.SetNextItemWidth(-FLOAT32_MIN);
            if it.fully_pathed_filename.count {
                text := entity_filename(it, with_short_filename=true, with_generation_index=true, with_loaded_time=false);

                delta_time := get_current_file_time() - it.loaded_filetime;
                FADE_TIME_SECS := 1;
                base_color := ifx is_empty(it) then Vector4.{.5, .5, .5, 1} else Vector4.{1, 1, 1, 1};
                color := make_ImVec4(base_color.x, base_color.x, base_color.z, base_color.w);
                if delta_time < xx (FADE_TIME_SECS * 10_000_000.) {
                    alpha := clamp(delta_time / (FADE_TIME_SECS * 10_000_000.), 0., 1.);
                    color4 := lerp(Vector4.{0, 1, 0, 1}, base_color, xx alpha);
                    color = make_ImVec4(color4.x, color4.y, color4.z, color4.w);
                }

                ImGui.PushStyleColor(xx ImGui.Col.Text, color);
                defer ImGui.PopStyleColor();
                {
                    push_allocator(temp); // to free the join'd string

                    // @Cleanup Add these aliases to make the following code easier to understand
                    // Note that the ImGui.Selectable widget has this line to set the colors:
                    //    const ImU32 col = GetColorU32((held && hovered) ? ImGuiCol_HeaderActive : hovered ? ImGuiCol_HeaderHovered : ImGuiCol_Header);
                    // selectable_selected_color :: ImGui.Col.Header;
                    // selectable_hovered_color :: ImGui.Col.Header;
                    // selectable_hovered_held_color :: ImGui.Col.Header;

                    get_context_menu_target_item :: () -> int {
                        for app.entities {
                            // @Volatile Search usages before changing label here
                            if ImGui.IsPopupOpen(imgui_label("##context_menu", xx it_index)) {
                                return it_index;
                            }
                        }
                        return -1;
                    }

                    // Indicate that the popup will be opened for this item if its hovered with RMB down
                    if io_mouse_right_down() ImGui.PushStyleColor(xx ImGui.Col.HeaderHovered, CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR);
                    defer if io_mouse_right_down() ImGui.PopStyleColor();

                    popup_item := get_context_menu_target_item();
                    if popup_item == -1 {
                        // Use the default Selectable widget
                        if ImGui.Selectable(to_c_string(join(text, tprint("##%", it))), *it.is_selected) {
                            if !io().KeyCtrl it.is_selected = !it.is_selected;
                        }
                    } else { // Need to fiddle with some colors to indicate what the popup is editing
                        if app.entities[popup_item].is_selected {
                            // Use the default Selectable widget, but customize the selected color
                            ImGui.PushStyleColor(xx ImGui.Col.Header, CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR);
                            ImGui.PushStyleColor(xx ImGui.Col.HeaderActive, CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR);
                            if ImGui.Selectable(to_c_string(join(text, tprint("##%", it))), *it.is_selected) {
                                if !io().KeyCtrl it.is_selected = !it.is_selected;
                            }
                            ImGui.PopStyleColor();
                            ImGui.PopStyleColor();
                        } else {
                            if popup_item == it_index {
                                // Use a custom Selectable widget, so we can change the background color even though as of 1.87 imgui does not expose a ImGuiCol enum for this
                                if selectable_with_bg_color(join(text, tprint("##%", it)), *it.is_selected, ImGui.GetColorU32(CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR)) {
                                    if !io().KeyCtrl it.is_selected = !it.is_selected;
                                }
                            } else {
                                // Use the default Selectable widget
                                if ImGui.Selectable(to_c_string(join(text, tprint("##%", it))), *it.is_selected) {
                                    if !io().KeyCtrl it.is_selected = !it.is_selected;
                                }
                            }
                        }
                    }
                }
            } else {
                ImGui.Selectable("---", *it.is_selected);
            }
            if ImGui.IsItemClicked() {
                if !io().KeyCtrl && !is_empty(it) {
                    fit_on_screen(it);
                }
            }
            was_hovered := it.is_hovered;
            it.is_hovered = ImGui.IsItemHovered();
            if ImGui.IsItemHovered() {
                it.display_info.flash_wave_dt += io().DeltaTime;
            } else if was_hovered {
                it.display_info.flash_wave_dt = 0;
            }

            /*
            compiler_report("Enable when we have tooltip delays");
            if (it.is_hovered) {
                ImGui.BeginTooltip();
                ImGui.BeginTable("", 2, flags=ImGui.TableFlags.NoBordersInBody);
                ImGui.TableNextRow(); ImGui.TableNextColumn();
                ImGui.TextColored(KEYBINDING_COLOR, "RMB");
                ImGui.TableNextColumn();
                ImGui.Text("Open context menu for the current %", ifx it.is_selected then "item selection" else "item");
                ImGui.TableNextRow(); ImGui.TableNextColumn();
                ImGui.TextColored(KEYBINDING_COLOR, "Ctrl LMB");
                ImGui.TableNextColumn();
                ImGui.Text("Toggle selected state of the hovered item");
                ImGui.EndTable();
                ImGui.EndTooltip();
            }
            */

            // @Cleanup This is a horrible way to do this...
            it.display_info.aabb_visible = false; // Turned on only while context menu > clipping is on

            show_item_context_menu(it, it_index);
        }

        if app.settings.fit_to_screen_on_visibility_change && any_visibility_changed {
            fit_scene_on_screen();
        }

        if entity_to_remove >= 0 && entity_to_remove < entities.count {
            deinit(entities[entity_to_remove]);
            free(entities[entity_to_remove]);
            array_ordered_remove_by_index(*entities, entity_to_remove);
        }
    }

    ImGui.Separator();

    // Selection Mode UI
    if ImGui.BeginTable("Mode Table", 5, flags=ImGui.TableFlags.NoBordersInBody) {
        defer ImGui.EndTable();

        it := *app.user_selection;

        ImGui.TableNextRow();

        // Remove button
        ImGui.TableNextColumn();
        if ImGui.Button(imgui_label("Clear ", it)) {
            deinit(it);
        }

        // Color selection
        {
            ImGui.TableNextColumn();
            ImGui.ColorEdit4(imgui_label("##color", it), *it.display_info.points_color.component, ImGui.ColorEditFlags.NoInputs);
        }

        // Toggle visibility checkbox
        {
            ImGui.TableNextColumn();
            visibility_changed := ImGui.Checkbox(imgui_label("##Visible", it), *it.is_visible);
            any_visibility_changed = any_visibility_changed || visibility_changed;
        }

        ImGui.TableNextColumn();
        ImGui.Text("Selection");
        if it.is_visible {
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
        if ImGui.IsItemClicked() {
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
        window_pos := make_ImVec2(current_pos.x + current_size.x + WINDOW_BORDER_UI_OFFSET.x, ImGui.GetCursorPos().y);
        ImGui.SetNextWindowPos(pos=window_pos, cond=.ImGuiCond_Appearing);
        if ImGui.BeginPopupContextItem(imgui_label("##context_menu", it)) {
            defer ImGui.EndPopup();

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
            ImGui.Text("AABB [%, %, %], [%, %, %]", aabb.min_point.x, aabb.min_point.y, aabb.min_point.z, aabb.max_point.x, aabb.max_point.y, aabb.max_point.z);
        }
    }

    show_item_list_actions_ui();
}

ScopedBorderTheme :: (color : ImGui.ImVec4, size : float) #expand {
    ImGui.PushStyleColor(xx ImGui.Col.Border, color);
    ImGui.PushStyleVar(xx ImGui.StyleVar.PopupBorderSize, size);
    `defer ImGui.PopStyleColor();
    `defer ImGui.PopStyleVar();
}

show_item_list_actions_ui :: () {

    ImGui.Separator();

    do_actions_tree := ImGui.TreeNodeEx("Actions", .DefaultOpen); // We do this so we can have the tooltip below appear when the tree is open AND closed
    {
        bindings : [..]Binding_With_Description;
        bindings.allocator = temp;
        array_add(*bindings, make_Binding_With_Description(to_string(0, ALL_ITEMS_MOD), "Target all items"));
        array_add(*bindings, make_Binding_With_Description(to_string(0, SELECTED_MOD),  "Target selected items"));
        Show_Tooltip_Binding(..bindings, header_text="Change Action targets with modifier keys");
    }

    if do_actions_tree {
        defer ImGui.TreePop();

        ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing());
        defer ImGui.Indent(ImGui.GetTreeNodeToLabelSpacing());

        target_items := Target_Items.VISIBLE;
        if current_modifier_flags() == VISIBLE_MOD   target_items = .VISIBLE;
        if current_modifier_flags() == SELECTED_MOD  target_items = .SELECTED;
        if current_modifier_flags() == ALL_ITEMS_MOD target_items = .ALL_ITEMS;
        // combo_box("##Target", *app.target_items, type_info(type_of(app.target_items)));

        // TODO make item list collapsable
        // TODO add some separators
        // TODO Make tooltips over item color square show the shortcuts
        // TODO Make UI look nice when there are no items loaded, probably we should still show operations
        // @Maybe Change the button colors depending on what modifier is pressed
        // @Maybe Make these button cycle forward with LMB and backward with RMB? or maybe if you scroll while on them

        Action_Button :: (label : string, action_set : Action_Set, disabled_tooltip := "", has_options_menu := false, options_visible := false) #expand {
            mod := current_modifier_flags(); 
            found, target := modifier_to_target(mod);
            if found {
                action := action_set.target_action[cast(int) target];

                progress := action.progress_proc();
                base_color := ImGui.GetStyle().Colors[ImGui.Col.ButtonActive];
                button_color := darken(base_color, cast(float)progress.numer / progress.denom);

                pop_style := false;
                if options_visible {
                    assert(has_options_menu);
                    ImGui.PushStyleColor(xx ImGui.Col.Button, CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR);
                    ImGui.PushStyleColor(xx ImGui.Col.ButtonActive, CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR);
                    ImGui.PushStyleColor(xx ImGui.Col.ButtonHovered, CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR);
                    pop_style = true;
                } else if progress.denom != 0 {
                    ImGui.PushStyleColor(xx ImGui.Col.Button, button_color);
                    ImGui.PushStyleColor(xx ImGui.Col.ButtonActive, button_color);
                    if has_options_menu && io_mouse_right_down() {
                        ImGui.PushStyleColor(xx ImGui.Col.ButtonHovered, CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR);
                    } else {
                        ImGui.PushStyleColor(xx ImGui.Col.ButtonHovered, button_color);
                    }
                    pop_style = true;
                }
                if ImGui.Button(imgui_label(label, *action_set)) {
                    action.proc();
                }
                if pop_style {
                    ImGui.PopStyleColor();
                    ImGui.PopStyleColor();
                    ImGui.PopStyleColor();
                }

                if has_options_menu {
                    push_allocator(temp);
                    binding1, binding2 : Binding_With_Description = ---;
                    binding1.description, binding1.binding = action.desc, to_string(action_set.key, mod);
                    binding2.description, binding2.binding = "Action options menu", "RMB";
                    Show_Tooltip_Binding(binding1, binding2);
                } else {
                    push_allocator(temp);
                    Show_Tooltip_Binding(action.desc, to_string(action_set.key, mod));
                }

            } else {
                DISABLED_COLOR :: ImGui.ImVec4.{.5, .5, .5, 1.};
                // // ImGui.PushStyleColor(xx ImGui.Col.Button | .ButtonHovered | .ButtonActive, DISABLED_COLOR);
                // ImGui.PushStyleColor(xx ImGui.Col.Button, DISABLED_COLOR);
                ImGui.BeginDisabled();
                ImGui.Button(imgui_label(label, *action_set));
                ImGui.EndDisabled();
                // ImGui.PopStyleColor();
                if disabled_tooltip Show_Tooltip(disabled_tooltip);
            }
        }

        Action_Button("Cyc BFace Mode", CYCLE_BACKFACE_MODE_ACTION_SET);
        ImGui.SameLine();
        Action_Button("Cyc Opacity   ", CYCLE_OPACITY_ACTION_SET);

        Action_Button("Cyc Line Width", CYCLE_LINE_WIDTH_ACTION_SET);
        ImGui.SameLine();
        Action_Button("Cyc Vert Size ", CYCLE_POINT_SIZE_ACTION_SET);

        Action_Button("Cyc Elem Label", CYCLE_ELEMENT_LABEL_ACTION_SET, has_options_menu=true, options_visible=ImGui.IsPopupOpen("##Cyc_Elem_Label_context_menu"));
        {
            current_pos := ImGui.GetWindowPos();
            current_size := ImGui.GetWindowSize();
            window_pos := make_ImVec2(current_pos.x + current_size.x + WINDOW_BORDER_UI_OFFSET.x, ImGui.GetCursorPos().y);
            ImGui.SetNextWindowPos(pos=window_pos, cond=.ImGuiCond_Appearing);

            // Set popup border color to match the selection/RMB target item color
            original_border_color := ImGui.GetStyle().Colors[ImGui.Col.Border];
            original_border_size :=  ImGui.GetStyle().PopupBorderSize;
            ScopedBorderTheme(CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR, CONTEXT_MENU_POPUP_TARGET_BORDER_SIZE);

            if ImGui.BeginPopupContextItem("##Cyc_Elem_Label_context_menu") {
                defer ImGui.EndPopup();

                // Undo the previous thing so internals don't have this color
                ScopedBorderTheme(original_border_color, original_border_size);

                update : Display_Info_Update;
                ImGui.Text("Cyc Elem Label Options");
                ImGui.Separator();
                show_label_theme_ui(*update.element_label_theme_update, *app.selection_display_info.element_label_theme);
                apply_display_info_update(update, target_items);
            }
        }
        ImGui.SameLine();
        Action_Button("Cyc Vert Label", CYCLE_VERTEX_LABEL_ACTION_SET, has_options_menu=true, options_visible=ImGui.IsPopupOpen("##Cyc_Vert_Label_context_menu"));
        {
            current_pos := ImGui.GetWindowPos();
            current_size := ImGui.GetWindowSize();
            window_pos := make_ImVec2(current_pos.x + current_size.x + WINDOW_BORDER_UI_OFFSET.x, ImGui.GetCursorPos().y);
            ImGui.SetNextWindowPos(pos=window_pos, cond=.ImGuiCond_Appearing);

            // Set popup border color to match the selection/RMB target item color
            original_border_color := ImGui.GetStyle().Colors[ImGui.Col.Border];
            original_border_size :=  ImGui.GetStyle().PopupBorderSize;
            ScopedBorderTheme(CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR, CONTEXT_MENU_POPUP_TARGET_BORDER_SIZE);

            if ImGui.BeginPopupContextItem("##Cyc_Vert_Label_context_menu") {
                defer ImGui.EndPopup();

                // Undo the previous thing so internals don't have this color
                ScopedBorderTheme(original_border_color, original_border_size);

                update : Display_Info_Update;
                ImGui.Text("Cyc Vert Label Options");
                ImGui.Separator();
                show_label_theme_ui(*update.vertex_label_style_update, *app.selection_display_info.vertex_label_style);
                apply_display_info_update(update, target_items);
            }
        }

        Action_Button("Tgl Clipping  ", TOGGLE_CLIPPING_ACTION_SET);
        ImGui.SameLine();
        Action_Button("Tgl Normals   ", TOGGLE_NORMALS_ACTION_SET);

        Action_Button("Focus Items   ", FOCUS_ITEMS_ACTION_SET);
        ImGui.SameLine();
        Action_Button("Reload Items  ", RELOAD_ITEMS_ACTION_SET);

        if app.entities.count {
            if #complete target_items == {
                case .ALL_ITEMS;
                    count := app.entities.count;
                    ImGui.Text("Operating on all items (%)", count);
                case .VISIBLE;
                    count := 0; for :Visible app.entities count += 1;
                    ImGui.Text("Operating on % visible item%", count, ifx count == 1 then "" else "s");
                case .SELECTED;
                    count := 0; for :Selected app.entities count += 1;
                    ImGui.Text("Operating on % selected item%", count, ifx count == 1 then "" else "s");
            }
        }

        // ImGui.Separator();
        // if ImGui.Button("Tgl Console   ") { }
        // ImGui.SameLine();
        // if ImGui.Button("Tgl Help Menu") { }
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
            color  := entity_primary_color(it);
            <<color = color_from_path(it.fully_pathed_filename);
        }

        for i : 0..clip_ranges.count-1 {
            if set.clip_ranges[i] clip_ranges[i] = other.clip_ranges[i];
        }
        if set.clip_sphere clip_sphere = other.clip_sphere;
    }
}

show_item_context_menu :: (entity : *Entity, entity_index : s64) {
    current_pos := ImGui.GetWindowPos();
    current_size := ImGui.GetWindowSize();
    window_pos := make_ImVec2(current_pos.x + current_size.x + WINDOW_BORDER_UI_OFFSET.x, ImGui.GetCursorPos().y);
    ImGui.SetNextWindowPos(pos=window_pos, cond=.ImGuiCond_Appearing);

    // Set popup border color to match the selection/RMB target item color
    original_border_color := ImGui.GetStyle().Colors[ImGui.Col.Border];
    original_border_size :=  ImGui.GetStyle().PopupBorderSize;
    ScopedBorderTheme(CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR, CONTEXT_MENU_POPUP_TARGET_BORDER_SIZE);

    if ImGui.BeginPopupContextItem(imgui_label("##context_menu", xx entity_index)) {
        defer ImGui.EndPopup();

        // Undo the previous thing so internals don't have this color
        ScopedBorderTheme(original_border_color, original_border_size);

        if !entity.is_selected {
            if entity.fully_pathed_filename.count {
                if ImGui.Button(imgui_label("Reload", entity)) {
                    app.entities[entity_index] = reload_entity(entity);
                }
                ImGui.SameLine();
                text := entity_filename(entity, with_generation_index=true, with_short_filename=false, with_loaded_time=true);
                ImGui.TextUnformatted(text);
            }

            ImGui.Separator();

            normals_ui :=  entity.type == .MESH || entity.type == .POINT_CLOUD;
            lines_ui   := (entity.type == .MESH && entity.mesh.geometry_format != .POINTS) || entity.type == .POLYLINE_SOUP2 || entity.type == .POLYLINE_SOUP3;
            faces_ui   := (entity.type == .MESH && entity.mesh.geometry_format == .TRIANGLES) || entity.type == .POLYGON_SOUP;
            maybe_update_render_info(*entity.render_info, *entity.mesh);

            transformed_aabb := entity.render_info.bounding_aabb;
            {
                // @Volatile @Cleanup only works for a shift
                using transformed_aabb;
                min_point = (entity.mesh.world_from_model * make_vector4(min_point, 1)).xyz;
                max_point = (entity.mesh.world_from_model * make_vector4(max_point, 1)).xyz;
            }

            set := display_info_ui(*entity.display_info, transformed_aabb, normals_ui=normals_ui, lines_ui=lines_ui, faces_ui=faces_ui);
            if set.color_reset entity.display_info.surface_color = color_from_path(entity.fully_pathed_filename);

            display_stats(entity);

            display_transform(entity);

        } else {
            if ImGui.TreeNodeEx(to_c_string(tprint("Selection (% item%)", num_selected_entities(), ifx num_selected_entities() == 1 then "" else "s"))) {
                defer ImGui.TreePop();
                for :Selected app.entities {
                    if it.fully_pathed_filename.count {
                        if ImGui.Button(imgui_label("Reload", it)) {
                            app.entities[it_index] = reload_entity(it);
                        }
                        ImGui.SameLine();
                        text := entity_filename(it, with_generation_index=true, with_short_filename=false, with_loaded_time=true);
                        ImGui.TextUnformatted(text);
                    }
                }

                if ImGui.Button("Reload Selection") {
                    for :Selected app.entities {
                        app.entities[it_index] = reload_entity(it);
                    }
                    // ImGui.CloseCurrentPopup();
                }

                ImGui.SameLine();
                if ImGui.Button("Deselect All") {
                    for :Selected app.entities {
                        it.is_selected = false;
                    }
                    ImGui.CloseCurrentPopup();
                }
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
    }
}

show_camera_controls :: () {
    window_pos := make_ImVec2(ImGui.GetIO().DisplaySize.x - WINDOW_BORDER_UI_OFFSET.x, WINDOW_BORDER_UI_OFFSET.y);
    window_pivot := make_ImVec2(1, 0);

    using ImGui.WindowFlags;

    ImGui.SetNextWindowPos(window_pos, .Always, window_pivot);
    ImGui.Begin("Camera shortcuts", flags = NoTitleBar | AlwaysAutoResize | NoMove /*| NoNav*/);
    defer ImGui.End();

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
    world_axes := *app.triad;
    if !app.show_help_ui return;

    ImGui.SetNextWindowPos(make_ImVec2(app.current_window_width / 2., app.current_window_height / 2.), pivot=.{.5, .5},
    cond=.ImGuiCond_Appearing);
    ImGui.SetNextWindowSizeConstraints(make_ImVec2(app.current_window_width * .6, app.current_window_height * .75),
                                       make_ImVec2(app.current_window_width * .6, app.current_window_height * .75));
    flags := ImGui.WindowFlags.NoTitleBar | .AlwaysHorizontalScrollbar | .NoCollapse | .AlwaysAutoResize | .NoMove /*| .NoNav*/;

    ImGui.Begin("##show_help_ui", flags = flags);
    defer ImGui.End();

    COLUMN_WIDTH :: 100;

    Show_Binding :: (binding : string, description : string) #expand {
        ImGui.TextColored(KEYBINDING_COLOR, binding);
        ImGui.NextColumn();
        ImGui.Text(description);
        ImGui.NextColumn();
    }

    if ImGui.TreeNodeEx("Key bindings in the Viewport", .DefaultOpen) {
        defer ImGui.TreePop();
        ImGui.Columns(2);
        defer ImGui.Columns(1);
        ImGui.SetColumnWidth(-1, COLUMN_WIDTH);
        ImGui.NextColumn(); ImGui.NextColumn();
        Show_Binding("MMB", "Pan the camera");
        Show_Binding("Scroll", "Zoom the camera into the position under the cursor");
        Show_Binding("Alt   Scroll", "Zoom the camera into the position under the cursor slowly");
        Show_Binding("Shift Scroll", "Zoom the camera into the camera look position");
        Show_Binding("RMB", "Rotate the camera");
        Show_Binding("Alt RMB", "Rotate about selected axis in the camera control pane");
    }

    // Needed to make sure the tooltip is visible regardless of whether the tree node is open or closed
    Tree_Node_With_Tooltip :: (label : *u8, tooltip : string) -> bool #expand {
        result := ImGui.TreeNodeEx(label, .DefaultOpen);
        Show_Tooltip(tooltip);
        return result;
    }

    if Tree_Node_With_Tooltip("Key bindings for the Item List",
                              "The Item List is visible in the top left\nwhen at least one item has been loaded") {
        defer ImGui.TreePop();
        ImGui.Columns(2);
        defer ImGui.Columns(1);
        ImGui.SetColumnWidth(-1, COLUMN_WIDTH);
        ImGui.NextColumn(); ImGui.NextColumn();
        Show_Binding("LMB", "(on a filename) Focus an item");
        Show_Binding("Ctrl LMB", "(on a filename) Select an item");
        Show_Binding("RMB", "(on a filename) Open context menu which modifies only clicked item");
        Show_Binding("RMB", "(on a selected filename) Open context menu which modifies all selected items");
        Show_Binding("RMB", "(on a color) Cycle shading styles");
        Show_Binding("MMB", "(on a color) Reset color from the filename");
        Show_Binding("LMB", "(sweep over visibility checkbox) Update item visibility");
        Show_Binding("Ctrl LMB", "(sweep over visibility checkbox) Focus hovered item");
        Show_Binding("Shift LMB", "(sweep over visibility checkbox) Focus hovered item and update camera");
    }

    if Tree_Node_With_Tooltip("Key bindings for Selection Mode",
                              "Enable selection mode by toggling visibility\non the 'Selection' item") {
        defer ImGui.TreePop();
        ImGui.Columns(2);
        defer ImGui.Columns(1);
        ImGui.SetColumnWidth(-1, COLUMN_WIDTH);
        ImGui.NextColumn(); ImGui.NextColumn();
        Show_Binding("Ctrl LMB", "Add nearest unclipped vertex to 'Selection' item");
        Show_Binding("Shift LMB", "Click-drag to set clipping sphere");
        Show_Binding("Ctrl RMB", "Place camera orbit");
    }

    if ImGui.TreeNodeEx("General key bindings", .DefaultOpen) {
        defer ImGui.TreePop();
        ImGui.Columns(2);
        defer ImGui.Columns(1);
        ImGui.SetColumnWidth(-1, COLUMN_WIDTH);
        ImGui.NextColumn();
        ImGui.NextColumn();
        for app.keymap_keydown.mappings {
            push_allocator(temp);
            Show_Binding(to_string(it.key_code, it.modifier_flags), app.keymap_keydown.procs[it.proc_info_index].name);
        }
        for app.keymap.mappings {
            push_allocator(temp);
            Show_Binding(to_string(it.key_code, it.modifier_flags), app.keymap.procs[it.proc_info_index].name);
        }
    }

    if ImGui.TreeNodeEx("Key bindings for Actions", .DefaultOpen) {
        defer ImGui.TreePop();
        ImGui.Columns(2);
        defer ImGui.Columns(1);
        ImGui.SetColumnWidth(-1, COLUMN_WIDTH);
        ImGui.NextColumn();
        ImGui.NextColumn();
        for app.keymap_actions.mappings {
            push_allocator(temp);
            Show_Binding(to_string(it.key_code, it.modifier_flags), app.keymap_actions.procs[it.proc_info_index].name);
        }
    }

    if ImGui.TreeNode("%", "General Settings") {
        defer ImGui.TreePop();
        combo_box("Background", *app.background_style, type_info(app.Background_Style));
        if app.background_style == .SOLID_COLOR {
            ImGui.ColorEdit4("Background Color", *app.background_solid_color.component, ImGui.ColorEditFlags.NoInputs);
        }
        ImGui.Checkbox("World Axes", *world_axes.visible);

        if app.current_window_width != app.INITIAL_WINDOW_WIDTH || app.current_window_height != app.INITIAL_WINDOW_HEIGHT {
            if ImGui.Button("Reset OS Window Size") {
                SDL_SetWindowSize(app.window, app.INITIAL_WINDOW_WIDTH, app.INITIAL_WINDOW_HEIGHT);
            }
        }
    }

    // :UserConfig add a button to overwrite the user settings file with new defaults here?
    inspect("User Settings", *app.settings);
    clamp_user_settings();

    if ImGui.TreeNodeEx("Changelog") {
        defer ImGui.TreePop();

        COMPILER_VERSION_INFO :: #run tprint("Compiled with Jai version %", compiler_get_version_info(null));
        ImGui.Text(COMPILER_VERSION_INFO);

        if ImGui.Button("Save to CHANGELOG.md") {
            log_error("Incomplete");
        }
        Show_Tooltip("Handy if you want to search the changelog");

        latest := app.changelog[0];
        if ImGui.TreeNodeEx(temp_c_string(tprint("Version %, % (latest)", latest.name, latest.date)), .DefaultOpen) {
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
        for app.known_issues {
            ImGui.PushStyleColor(xx ImGui.Col.Text, CHANGELOG_COLOR);
            ImGui.TextWrapped(it.name);
            // ImGui.Text(it.name);
            ImGui.PopStyleColor();
            ImGui.SameLine();
            ImGui.TextWrapped(it.description);
            // ImGui.Text(it.description);
        }
    }

    // @Incomplete add a message about where the keymap is for editing
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

// @TODO Implment a compile-time check that the entries here match Display_Mode, use annotations to selectively ignore stuff
Display_Info_Update :: struct {

    points_visible : bool;
    points_color : [4]bool;
    points_size : bool;
    vertex_label_style_update : Label_Theme_Update;
    element_label_theme_update : Label_Theme_Update;

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
    update.show_position   = ImGui.Checkbox("Label coordinates", *theme.show_position);
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

display_info_ui :: (display_info : *Display_Info, aabb : AxisBox3, normals_ui : bool = true, lines_ui : bool = true, faces_ui : bool = true) -> Display_Info_Update {

    set : Display_Info_Update;

    if ImGui.TreeNodeEx("Rendering", .DefaultOpen) {
        defer ImGui.TreePop();

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
            Show_Tooltip("Visible");
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
            Show_Tooltip("Visible");
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
            Show_Tooltip("Visible");
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
            Show_Tooltip("Visible");
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
            Show_Tooltip("Backface Mode");
            ImGui.PopItemWidth();
            ImGui.SameLine();
            set.flat_shading = ImGui.Checkbox(imgui_label("##Flat Shading", display_info), *display_info.flat_shading);
            Show_Tooltip("Flat Shading");
        }
    }

    show_clipping_ui(*set, display_info, aabb);

    if ImGui.TreeNodeEx("Point Labels") {
        defer ImGui.TreePop();
        show_label_theme_ui(*set.vertex_label_style_update, *display_info.vertex_label_style);
    }

    // @TODO Rename element to triangle/segment/segment for meshes/polylines/polygons
    if ImGui.TreeNodeEx("Element Labels") {
        defer ImGui.TreePop();
        show_label_theme_ui(*set.element_label_theme_update, *display_info.element_label_theme);
    }

    return set;
}

display_stats :: (entity : *Entity) {
    if ImGui.TreeNodeEx("Stats") {
        defer ImGui.TreePop();

        if #complete entity.type == {
            case .POLYLINE_SOUP2;

                using soup := cast(*Polyline_Soup2_Entity)entity;
                ImGui.Text("PolylineSoup2 #points, #polylines = %, %", point_count(shape), shape.polylines.count);

            case .POLYLINE_SOUP3;

                using soup := cast(*Polyline_Soup3_Entity)entity;
                ImGui.Text("PolyineSoup3 #points, #polylines = %, %", point_count(shape), shape.polylines.count);

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
                        ImGui.Text("Mesh #points = %", mesh.mesh.positions.count);
                    case .LINES;
                        ImGui.Text("Mesh #points, #lines = %, %", mesh.mesh.positions.count, mesh.mesh.indices.count / 2);
                    case .TRIANGLES;
                        ImGui.Text("Mesh #points, #triangles = %, %", mesh.mesh.positions.count, mesh.mesh.indices.count / 3);
                }
        }
        maybe_update_render_info(*entity.render_info, *entity.mesh);
        aabb := entity.render_info.bounding_aabb;
        ImGui.Text("Model space AABB:");
        ImGui.Text("Max [%, %, %]", aabb.max_point.x, aabb.max_point.y, aabb.max_point.z);
        ImGui.Text("Min [%, %, %]", aabb.min_point.x, aabb.min_point.y, aabb.min_point.z);
    }
}

display_transform :: (entity : *Entity) {
    if ImGui.TreeNodeEx("Transform") {
        defer ImGui.TreePop();
        shift := make_vector3(entity.mesh.world_from_model._14, entity.mesh.world_from_model._24, entity.mesh.world_from_model._34);
        ImGui.DragFloat3(imgui_label("Offset", entity), *shift.component, .05);
        entity.mesh.world_from_model._14, entity.mesh.world_from_model._24, entity.mesh.world_from_model._34 = shift.x, shift.y, shift.z;
    }
}

show_clipping_ui :: (set : *Display_Info_Update, using display_info : *Display_Info, aabb : AxisBox3) {

    if ImGui.TreeNodeEx("Clipping", .None /*.DefaultOpen*/) {
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
