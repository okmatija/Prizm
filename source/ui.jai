// Copyright Epic Games, Inc. All Rights Reserved.

WINDOW_BORDER_UI_OFFSET :: ImGui.ImVec2.{10, 10};

show_global_settings_ui :: (world_axes : *Axes_Triad)
{
    if !app.show_global_settings_ui return;

    using app;

    ImGui.SetNextWindowPos(WINDOW_BORDER_UI_OFFSET);
    ImGui.Begin("Main Panel", flags = ImGui.WindowFlags.AlwaysAutoResize | ImGui.WindowFlags.NoTitleBar);
    defer ImGui.End();
    defer if entities.count ImGui.Separator();

    // @TODO Default this to open
    if ImGui.TreeNode("%", "General Settings") {
        defer ImGui.TreePop();
        combo_box("Background", *app.background_style, type_info(Background_Style));
        if app.background_style == .SOLID_COLOR {
            ImGui.ColorEdit4("Background Color", *background_solid_color.component, ImGui.ColorEditFlags.NoInputs);
        }
        ImGui.Checkbox("World Axes", *world_axes.visible);

        ImGui.InputInt("Label limit", *app.label_limit);
        if app.label_limit > 2000 {
            color := ImGui.ImVec4.{1., .4, .4, 1.};
            ImGui.TextColored(color, "%", "Warning: label limit > 2000 may be slow");
        }
    }

    // :UserConfig add a button to overwrite the user settings file with new defaults here?
    inspect("User Settings", *app.settings);
    clamp_user_settings();

    if current_window_width != INITIAL_WINDOW_WIDTH && current_window_height != INITIAL_WINDOW_HEIGHT {
        if ImGui.Button("Reset Window") {
            SDL_SetWindowSize(window, app.INITIAL_WINDOW_WIDTH, app.INITIAL_WINDOW_HEIGHT);
        }
    }

    // #if true {
    //     ImGui.SetNextWindowPos(ImGui.make_ImVec2(650, 20), .FirstUseEver);
    //     ImGui.ShowDemoWindow(*app.show_imgui_demo_window);
    // }
}

// @Refactor This function is too long (especially the top level for loop). Break it up.
show_item_list_ui :: () {
    using app;

    if !entities.count return;

    ImGui.SetNextWindowPos(WINDOW_BORDER_UI_OFFSET);
    ImGui.Begin("Main Panel", flags = ImGui.WindowFlags.AlwaysAutoResize | ImGui.WindowFlags.NoTitleBar);
    defer ImGui.End();

    any_visibility_changed := false;

    entity_to_remove := -1;
    for entities {
        // Remove button
        if ImGui.Button(imgui_label("Remove", it)) {
            entity_to_remove = it_index;
        }

        // Toggle visibility and set color
        ImGui.SameLine();
        was_visible := it.is_visible;
        visibility_changed := checkbox_press_or_sweep_to_toggle(*it.is_visible, *it.is_visible_sweep_hovered, imgui_label("##Visible", it));
        // Show_Tooltip("Visible");

        if !was_visible && it.is_visible {
            // Make sure we see something when turning on visibility
            if !it.display_info.surface_visible && !it.display_info.wireframe_visible {
                it.display_info.surface_visible = true;
            }
        }

        any_visibility_changed = any_visibility_changed || visibility_changed;
        ImGui.SameLine();
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

        // // Entity index used to refer to geometry in console or annotate the text following ther cursor when adding to the user selection
        if app.show_console_ui || app.user_selection.is_visible {
            ImGui.SameLine();
            label := to_c_string(tprint("#%", it_index));
            if it.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity {
                ImGui.Text(label);
                Show_Tooltip("Entity index for console commands\nand user selection cursor labels");
            } else {
                ImGui.TextDisabled(label);
                Show_Tooltip("Entity index for console commands\nand user selection cursor labels\nIncrease max point count to select this entity");
            }
            ImGui.SameLine();
        }

        // Write filename
        ImGui.SameLine();
        if it.fully_pathed_filename.count {
            text := entity_filename(<<it, with_short_filename=true, with_generation_index=true, with_loaded_time=false);

            delta_time := get_current_file_time() - it.loaded_filetime;
            FADE_TIME_SECS := 1;
            base_color := ifx is_empty(<<it) then Vector4.{.5, .5, .5, 1} else Vector4.{1, 1, 1, 1};
            color := ImGui.make_ImVec4(base_color.x, base_color.x, base_color.z, base_color.w);
            if delta_time < xx (FADE_TIME_SECS * 10_000_000.) {
                alpha := clamp(delta_time / (FADE_TIME_SECS * 10_000_000.), 0., 1.);
                color4 := lerp(Vector4.{0, 1, 0, 1}, base_color, alpha);
                color = ImGui.make_ImVec4(color4.x, color4.y, color4.z, color4.w);
            }

            ImGui.PushStyleColor(xx ImGui.Col.Text, color);
            if ImGui.Selectable(to_c_string(join(text, tprint("##%", it))), *it.is_selected) { // @Leak? free the join'd string?
                if !io().KeyCtrl it.is_selected = !it.is_selected;
            }
            ImGui.PopStyleColor();
        } else {
            ImGui.Selectable("---", *it.is_selected);
        }
        if ImGui.IsItemClicked() {
            if !io().KeyCtrl && !is_empty(<<it) {
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

        // @Cleanup This is a horrible way to do this...
        it.display_info.aabb_visible = false; // Turned on only while context menu > clipping is on

        if ImGui.BeginPopupContextItem(imgui_label("##context_menu", xx it_index)) {
            defer ImGui.EndPopup();

            if !it.is_selected {
                if it.fully_pathed_filename.count {
                    if ImGui.Button(imgui_label("Reload", it)) {
                        app.entities[it_index] = reload_entity(it);
                    }
                    ImGui.SameLine();
                    text := entity_filename(<<it, with_generation_index=true, with_short_filename=false, with_loaded_time=true);
                    ImGui.TextUnformatted(text);
                }

                ImGui.Separator();

                normals_ui :=  it.type == .MESH;
                lines_ui   := (it.type == .MESH && it.mesh.geometry_format != .POINTS) || it.type == .POLYLINE_SOUP2 || it.type == .POLYLINE_SOUP3;
                faces_ui   := (it.type == .MESH && it.mesh.geometry_format == .TRIANGLES) || it.type == .POLYGON_SOUP;
                maybe_update_render_info(*it.render_info, *it.mesh);

                transformed_aabb := it.render_info.bounding_aabb;
                {
                    // @Volatile @Cleanup only works for a shift
                    using transformed_aabb;
                    min_point = (it.mesh.world_from_model * make_vector4(min_point, 1)).xyz;
                    max_point = (it.mesh.world_from_model * make_vector4(max_point, 1)).xyz;
                }

                set := display_info_ui(*it.display_info, transformed_aabb, normals_ui=normals_ui, lines_ui=lines_ui, faces_ui=faces_ui);
                if set.color_reset it.display_info.surface_color = color_from_path(it.fully_pathed_filename);

                ImGui.Separator();

                shift := make_vector3(it.mesh.world_from_model._14, it.mesh.world_from_model._24, it.mesh.world_from_model._34);
                // ImGui.PushItemWidth(-1);
                ImGui.DragFloat3(imgui_label("Shift", it), *shift.component, .05);
                // ImGui.PopItemWidth();
                it.mesh.world_from_model._14, it.mesh.world_from_model._24, it.mesh.world_from_model._34 = shift.x, shift.y, shift.z;

                ImGui.Separator();

                if #complete it.type == {
                    case .POLYLINE_SOUP2;

                        using soup := cast(*Polyline_Soup2_Entity)it;
                        ImGui.Text(to_c_string(tprint("PolylineSoup2 #points, #polylines = %, %", point_count(shape), shape.polylines.count)));

                    case .POLYLINE_SOUP3;

                        using soup := cast(*Polyline_Soup3_Entity)it;
                        ImGui.Text(to_c_string(tprint("PolyineSoup3 #points, #polylines = %, %", point_count(shape), shape.polylines.count)));

                    case .POLYGON_SOUP;

                        using soup := cast(*Polygon_Soup_Entity)it;
                        ImGui.Text(to_c_string(tprint("PolygonSoup #points, #polygons = %, %", point_count(shape), shape.polygons.count)));

                    case .UNKNOWN; #through;
                    case .MESH;

                        mesh := cast(*Mesh_Entity)it;
                        if #complete mesh.mesh.geometry_format == {
                            case .UNKNOWN; #through;
                            case .POINTS;
                                ImGui.Text(to_c_string(tprint("Mesh #points = %", mesh.mesh.positions.count)));
                            case .LINES;
                                ImGui.Text(to_c_string(tprint("Mesh #points, #lines = %, %", mesh.mesh.positions.count, mesh.mesh.indices.count / 2)));
                            case .TRIANGLES;
                                ImGui.Text(to_c_string(tprint("Mesh #points, #triangles = %, %", mesh.mesh.positions.count, mesh.mesh.indices.count / 3)));
                        }
                }
                maybe_update_render_info(*it.render_info, *it.mesh);
                aabb := it.render_info.bounding_aabb;
                ImGui.Text(to_c_string(tprint("Model space AABB = [%, %, %]x[%, %, %]",
                                              aabb.min_point.x, aabb.min_point.y, aabb.min_point.z,
                                              aabb.max_point.x, aabb.max_point.y, aabb.max_point.z)));


            } else {
                for app.entities if it.is_selected {
                    if it.fully_pathed_filename.count {
                        if ImGui.Button(imgui_label("Reload", it)) {
                            app.entities[it_index] = reload_entity(it);
                        }
                        ImGui.SameLine();
                        text := entity_filename(<<it, with_generation_index=true, with_short_filename=false, with_loaded_time=true);
                        ImGui.TextUnformatted(text);
                    }
                }

                if ImGui.Button("Reload Selection") {
                    for app.entities if it.is_selected {
                        app.entities[it_index] = reload_entity(it);
                    }
                    // ImGui.CloseCurrentPopup();
                }

                ImGui.SameLine();
                if ImGui.Button("Clear Selection") {
                    for app.entities if it.is_selected {
                        it.is_selected = false;
                    }
                    ImGui.CloseCurrentPopup();
                }

                ImGui.Separator();

                selection_aabb : AxisBox3;
                for app.entities if it.is_selected {
                    maybe_update_render_info(*it.render_info, *it.mesh);
                    // @Volatile @Cleanup only works for a shift
                    aabb := it.render_info.bounding_aabb;
                    aabb.min_point = (it.mesh.world_from_model * make_vector4(aabb.min_point, 1)).xyz;
                    aabb.max_point = (it.mesh.world_from_model * make_vector4(aabb.max_point, 1)).xyz;
                    expand(*selection_aabb, aabb);
                }

                set := display_info_ui(*app.selection_display_info, selection_aabb);

                for app.entities if it.is_selected {
                    other := *app.selection_display_info;
                    using it.display_info;

                    if set.vertex_label_style_update.show_position vertex_label_style.show_position = other.vertex_label_style.show_position;
                    if set.vertex_label_style_update.show_index    vertex_label_style.show_index    = other.vertex_label_style.show_index;
                    if set.vertex_label_style_update.format_float  vertex_label_style.format_float  = other.vertex_label_style.format_float;
                    if set.vertex_label_style_update.label_scale   vertex_label_style.label_scale   = other.vertex_label_style.label_scale;
                    if set.vertex_label_style_update.label_color   vertex_label_style.label_color   = other.vertex_label_style.label_color;

                    if set.wireframe_visible    wireframe_visible    = other.wireframe_visible;
                    if set.wireframe_width      wireframe_width      = other.wireframe_width;
                    if set.surface_visible      surface_visible      = other.surface_visible;
                    if set.display_mode         display_mode         = other.display_mode;
                    if set.screentone_backfaces screentone_backfaces = other.screentone_backfaces;
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
                }
            }
        }
    }

    {
        ImGui.Separator();

        it := *app.user_selection;

        // Remove button
        if ImGui.Button(imgui_label("Clear ", it)) {
            deinit(it);
        }

        // Toggle visibility checkbox
        ImGui.SameLine();
        visibility_changed := ImGui.Checkbox(imgui_label("##Visible", it), *it.is_visible);
        Show_Tooltip("Enable Selection Mode");
        any_visibility_changed = any_visibility_changed || visibility_changed;
        ImGui.SameLine();
        ImGui.ColorEdit4(imgui_label("##color", it), *it.display_info.points_color.component, ImGui.ColorEditFlags.NoInputs);

        ImGui.SameLine();
        ImGui.Text("Selection");
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

        if ImGui.BeginPopupContextItem(imgui_label("##context_menu", it)) {
            defer ImGui.EndPopup();

            ImGui.Text(to_c_string(tprint("#points = %", it.mesh.positions.count)));

            maybe_update_render_info(*it.render_info, *it.mesh);
            aabb := it.render_info.bounding_aabb;
            ImGui.Text(to_c_string(tprint("AABB [%, %, %], [%, %, %]",
                                          aabb.min_point.x, aabb.min_point.y, aabb.min_point.z,
                                          aabb.max_point.x, aabb.max_point.y, aabb.max_point.z)));

            ImGui.Separator();

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
            Show_Tooltip("Format is '#E,I {X,Y,Z}'\n X,Y,Z are the coordinates of the closest vertex\n E is entity index to which it belongs\n I is the vertex index within the entity");
            ImGui.DragFloat("Cursor text scale", *app.user_selection_cursor_text_scale, .005, .2, 1., format="%.3f");
            ImGui.InputInt("Max #points for selectable entities", xx *app.user_selection_max_point_count_for_selectable_entity);
        }
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

show_camera_controls :: () {
    window_pos := ImGui.make_ImVec2(ImGui.GetIO().DisplaySize.x - WINDOW_BORDER_UI_OFFSET.x, WINDOW_BORDER_UI_OFFSET.y);
    window_pivot := ImGui.make_ImVec2(1, 0);

    using ImGui.WindowFlags;

    ImGui.SetNextWindowPos(window_pos, .Always, window_pivot);
    // SetNextWindowSize(ImVec2(400,400), ImGuiCond_FirstUseEver);
    // ImGui.SetNextWindowSize(*ImVec2.{150., 0.});
    ImGui.SetNextWindowContentSize(ImGui.ImVec2.{110., 0.});
    // ImGui.SetNextWindowBgAlpha(.3);
    ImGui.Begin("Camera shortcuts", flags = NoTitleBar | AlwaysAutoResize | NoMove /*| NoNav*/);
    defer ImGui.End();

    X_AXIS :: Vector3.{1, 0, 0};
    Y_AXIS :: Vector3.{0, 1, 0};
    Z_AXIS :: Vector3.{0, 0, 1};

    keep_up := app.settings.camera_controls_keep_up_when_setting_look_along;

    // @Incomplete Interpolate the motion

    ImGui.Columns(3, border=false);
    if ImGui.Button("+X ") {
        set_look_direction(direction=X_AXIS, up=ifx keep_up then app.camera.up_direction else Z_AXIS);
    }
    ImGui.NextColumn();
    if ImGui.Button("+Y ") {
        set_look_direction(direction=Y_AXIS, up=ifx keep_up then app.camera.up_direction else Z_AXIS);
    }
    ImGui.NextColumn();
    if ImGui.Button("+Z ") {
        set_look_direction(direction=Z_AXIS, up=ifx keep_up then app.camera.up_direction else Y_AXIS);
    }
    ImGui.NextColumn();

    if ImGui.Button("-X ") {
        set_look_direction(direction=-X_AXIS, up=ifx keep_up then app.camera.up_direction else Z_AXIS);
    }
    ImGui.NextColumn();
    if ImGui.Button("-Y ") {
        set_look_direction(direction=-Y_AXIS, up=ifx keep_up then app.camera.up_direction else Z_AXIS);
    }
    ImGui.NextColumn();
    if ImGui.Button("-Z ") {
        set_look_direction(direction=-Z_AXIS, up=ifx keep_up then app.camera.up_direction else Y_AXIS);
    }
    ImGui.NextColumn();

    // @Volatile button text in camera control pane should be kept in sync with keymap!
    right_label, left_label, amount := "<< ", " >>", 5.;
    if io().KeyShift {
        right_label, left_label, amount = "<<<", ">>>", 15.;
    } else if io().KeyAlt {
        right_label, left_label, amount = " < ", " > ", 1.;
    }

    if ImGui.Button(to_c_string(right_label)) {
        axis := camera_rotation_axis();
        rotate_look_direction(axis, amount);
    }
    ImGui.NextColumn();
    if ImGui.Button("XYZ") {
        up := normalize(cross(.{-1, 1, 0}, .{-1, -1, -1}));
        set_look_direction(direction=.{-1, -1, -1}, up=up);
    }
    ImGui.NextColumn();
    if ImGui.Button(to_c_string(left_label)) {
        axis := camera_rotation_axis();
        rotate_look_direction(axis, -amount);
    }
    ImGui.NextColumn();

    ImGui.Columns(1, border=false);

    ImGui.PushItemWidth(100);
    combo_box("", *app.camera.rotation_axis, type_info(type_of(app.camera.rotation_axis)));
    Show_Tooltip("Camera Rotation Axis");

    if app.camera.look_position != Vector3.{0, 0, 0} {
        if ImGui.Button(" Reset Orbit ") {
            look_direction := current_look_direction();
            app.camera.look_position = .{0, 0, 0};
            app.camera.eye_position = app.camera.look_position - look_direction;
        }
    }

    // @Incomplete add perspective/orthographic toggle
    // @Incomplete add button to reset look position
}

show_help_ui :: () {
    if !app.show_help_ui return;

    window_pos := ImGui.make_ImVec2(ImGui.GetIO().DisplaySize.x - WINDOW_BORDER_UI_OFFSET.x, WINDOW_BORDER_UI_OFFSET.y);
    window_pivot := ImGui.make_ImVec2(1, 0);

    ImGui.SetNextWindowPos(pos=window_pos, pivot=window_pivot);
    ImGui.Begin("##show_help_ui", flags = ImGui.WindowFlags.NoTitleBar | .AlwaysAutoResize | .NoMove /*| .NoNav*/);
    defer ImGui.End();

    ImGui.Text("In the Viewport");
    ImGui.Separator();
    ImGui.Columns(2);
    ImGui.SetColumnWidth(-1, 80);
    ImGui.NextColumn();
    ImGui.NextColumn();
    ImGui.Text("MMB"); ImGui.NextColumn();
    ImGui.Text("Pan the camera"); ImGui.NextColumn();
    ImGui.Text("Scroll"); ImGui.NextColumn();
    ImGui.Text("Zoom the camera into the position under the cursor"); ImGui.NextColumn();
    ImGui.Text("C-Scroll"); ImGui.NextColumn();
    ImGui.Text("Zoom the camera into the camera look position"); ImGui.NextColumn();
    ImGui.Text("RMB"); ImGui.NextColumn();
    ImGui.Text("Rotate the camera"); ImGui.NextColumn();
    ImGui.Text("S-RMB"); ImGui.NextColumn();
    ImGui.Text("Rotate about selected axis in the camera control pane");
    ImGui.Columns(1);
    ImGui.NewLine();

    ImGui.Text("In the Item List");
    Show_Tooltip("The Item List is visible in the top right\nwhen at least one item has been loaded");
    ImGui.Separator();
    ImGui.Columns(2);
    ImGui.SetColumnWidth(-1, 80);
    ImGui.NextColumn();
    ImGui.NextColumn();
    ImGui.Text("LMB"); ImGui.NextColumn();
    ImGui.Text("(on a filename) Focus an item");  ImGui.NextColumn();
    ImGui.Text("C-LMB"); ImGui.NextColumn();
    ImGui.Text("(on a filename) Select an item"); ImGui.NextColumn();
    ImGui.Text("RMB"); ImGui.NextColumn();
    ImGui.Text("(on a filename) Access item/selection context menu"); ImGui.NextColumn();
    ImGui.Text("RMB"); ImGui.NextColumn();
    ImGui.Text("(on a color) Cycle shading styles"); ImGui.NextColumn();
    ImGui.Text("MMB"); ImGui.NextColumn();
    ImGui.Text("(on a color) Reset color from the filename"); ImGui.NextColumn();
    ImGui.Text("LMB"); ImGui.NextColumn();
    ImGui.Text("(sweep over visibility checkbox) Update item visibility"); ImGui.NextColumn();
    ImGui.Text("C-LMB"); ImGui.NextColumn();
    ImGui.Text("(sweep over visibility checkbox) Focus hovered item"); ImGui.NextColumn();
    ImGui.Text("S-LMB"); ImGui.NextColumn();
    ImGui.Text("(sweep over visibility checkbox) Focus hovered item and update camera"); ImGui.NextColumn();
    ImGui.Columns(1);
    ImGui.NewLine();

    ImGui.Text("In Selection Mode");
    Show_Tooltip("Enable selection mode by toggling visibility\non the 'Selection' item");
    ImGui.Separator();
    ImGui.Columns(2);
    ImGui.SetColumnWidth(-1, 80);
    ImGui.NextColumn();
    ImGui.NextColumn();
    ImGui.Text("C-LMB"); ImGui.NextColumn();
    ImGui.Text("Add vertex nearest the cursor to 'Selection' item");  ImGui.NextColumn();
    ImGui.Text("C-RMB"); ImGui.NextColumn();
    ImGui.Text("Place camera orbit on vertex nearest the cursor");  ImGui.NextColumn();
    ImGui.Columns(1);
    ImGui.NewLine();

    ImGui.Text("Key bindings");
    ImGui.Separator();
    ImGui.Columns(2);
    ImGui.SetColumnWidth(-1, 80);
    ImGui.NextColumn();
    ImGui.NextColumn();
    for app.keymap_keydown.mappings {
        Push_Temporary();
        ImGui.Text(to_c_string(tprint("%", to_string(it))));
        ImGui.NextColumn();
        ImGui.Text(to_c_string(tprint("%", app.keymap_keydown.procs[it.proc_info_index].name)));
        ImGui.NextColumn();
    }
    for app.keymap.mappings {
        Push_Temporary();
        ImGui.Text(to_c_string(tprint("%", to_string(it))));
        ImGui.NextColumn();
        ImGui.Text(to_c_string(tprint("%", app.keymap.procs[it.proc_info_index].name)));
        ImGui.NextColumn();
    }
    ImGui.Columns(1);

    // ImGui.NewLine();
    ImGui.Text("                                                                                ");
    ImGui.Text("Note: S=Shift, C=Ctrl, A=Alt, SPC=Space bar");

    // @Incomplete add a message about where the keymap is for editing
}

#scope_file

Vertex_Label_Style_Update :: struct {
    show_position : bool;
    show_index : bool;
    format_float : bool;
    label_scale : bool;
    label_color : bool;
}

Display_Info_Update :: struct {
    points_visible : bool;
    points_color : [4]bool;
    points_size : bool;
    vertex_label_style_update : Vertex_Label_Style_Update;

    normals_visible : bool;
    normals_color : [4]bool;
    normals_length : bool;

    wireframe_visible : bool;
    wireframe_color : [4]bool;
    wireframe_width : bool;

    surface_visible : bool;
    surface_color : [4]bool;

    color_reset : bool;
    display_mode : bool;
    screentone_backfaces : bool;
    flat_shading : bool;

    clip_ranges : [3]bool;
}

#run {
    info :   Display_Info;
    update : Display_Info_Update;
    if info.clip_ranges.count != update.clip_ranges.count {
        compiler_report(#file, #line, 0, "Expected clip_ranges arrays to have matching sizes");
    }
}

display_info_ui :: (display_info : *Display_Info, aabb : AxisBox3, normals_ui : bool = true, lines_ui : bool = true, faces_ui : bool = true) -> Display_Info_Update {

    set : Display_Info_Update;

    // FIXME FIXME: opacity should control wireframe??
    ImGui.PushItemWidth(120);
    set.display_mode = combo_box("", *display_info.display_mode, type_info(type_of(display_info.display_mode)));
    ImGui.PopItemWidth();

    {
        ImGui.Text("Points    ");
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
        ImGui.Text("Normals   ");
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
        ImGui.Text("Lines     ");
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
        ImGui.Text("Triangles ");
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
        set.screentone_backfaces = ImGui.Checkbox(imgui_label("##screentone_backfaces", display_info), *display_info.screentone_backfaces);
        Show_Tooltip("Backface dots");
        ImGui.SameLine();
        set.flat_shading = ImGui.Checkbox(imgui_label("##flat_shading", display_info), *display_info.flat_shading);
        Show_Tooltip("Flat shading");
    }

    set.color_reset = ImGui.Button(imgui_label("Reset Colors##color_reset", display_info));
    Show_Tooltip("Deduce item primary colors from the file path");

    if ImGui.TreeNode("%", "Clipping") {
        defer ImGui.TreePop();
        using display_info;
        display_info.aabb_visible = true;

        ImGui.Text("Clip using distance from planes though the origin");

        set.clip_ranges[0] = clipping_ui(*clip_ranges[0], aabb);
        set.clip_ranges[1] = clipping_ui(*clip_ranges[1], aabb);
        set.clip_ranges[2] = clipping_ui(*clip_ranges[2], aabb);

        if almost_equal(length(clip_ranges[0].normal), 0.) clip_ranges[0].normal = .{1, 0, 0};
        if almost_equal(length(clip_ranges[1].normal), 0.) clip_ranges[1].normal = .{0, 1, 0};
        if almost_equal(length(clip_ranges[2].normal), 0.) clip_ranges[2].normal = .{0, 0, 1};

        if ImGui.Button(imgui_label("Normalize", display_info)) {
            for *clip_ranges {
                normal_length := length(it.normal);
                if normal_length != 0 {
                    it.min /= normal_length;
                    it.max /= normal_length;
                    it.normal /= normal_length;
                }
            }
        }
        Show_Tooltip("Make the normals unit and update the min/max for all ranges");
    }

    if ImGui.TreeNode("%", "Label Settings") {
        defer ImGui.TreePop();
        using display_info;

        // ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing());
        // defer ImGui.Indent(ImGui.GetTreeNodeToLabelSpacing());

        set.vertex_label_style_update.show_index = ImGui.Checkbox("Index labels", *vertex_label_style.show_index);
        ImGui.SameLine();
        set.vertex_label_style_update.show_position = ImGui.Checkbox("Position labels", *vertex_label_style.show_position);

        trailing_width : s32 = xx vertex_label_style.format_float.trailing_width;
        set.vertex_label_style_update.format_float |= ImGui.InputInt("Float decimals", *trailing_width);
        vertex_label_style.format_float.trailing_width = clamp(trailing_width, 0, 12);
        Show_Tooltip("Number of digits following the decimal point");

        set.vertex_label_style_update.format_float = combo_box("Float format", *vertex_label_style.format_float.mode, type_info(FormatFloat.Mode));
        set.vertex_label_style_update.label_scale  = ImGui.DragFloat("Label scale", *vertex_label_style.label_scale, .005, .2, 1., format="%.3f");
        set.vertex_label_style_update.label_color  = ImGui.ColorEdit4("Label color", *vertex_label_style.label_color.component, ImGui.ColorEditFlags.NoInputs);
    }

    return set;
}

clipping_ui :: (p : *Clip_Range, aabb : AxisBox3) -> (changed : bool) {
    changed := false;
    W :: 60;
    MIN_RANGE :: .1;

    ImGui.Checkbox(imgui_label("##clip_plane", p), *p.is_active);
    Show_Tooltip("Enable this clipping range");
    ImGui.SameLine();

    ImGui.PushItemWidth(W);
    if ImGui.DragFloat(imgui_label("##range_min", p), *p.min, .1, 0., 0., format="%.3f") {
        p.min = min(p.min, p.max - MIN_RANGE);
        changed = true;
    }
    ImGui.PopItemWidth();
    ImGui.SameLine();
    ImGui.Text("<");
    ImGui.SameLine();
    ImGui.PushItemWidth(W);
    changed |= ImGui.DragFloat(imgui_label("##normal.x", p), *p.normal.x, .01, 0., 0., format="%.3f");
    ImGui.PopItemWidth();
    ImGui.SameLine();
    ImGui.Text("x +");
    ImGui.SameLine();
    ImGui.PushItemWidth(W);
    changed |= ImGui.DragFloat(imgui_label("##normal.y", p), *p.normal.y, .01, 0., 0., format="%.3f");
    ImGui.PopItemWidth();
    ImGui.SameLine();
    ImGui.Text("y +"); ImGui.SameLine();
    ImGui.PushItemWidth(W);
    changed |= ImGui.DragFloat(imgui_label("##normal.z", p), *p.normal.z, .01, 0., 0., format="%.3f");
    ImGui.PopItemWidth();
    ImGui.SameLine();
    ImGui.Text("z");
    ImGui.SameLine();
    ImGui.Text("<");
    ImGui.SameLine();
    ImGui.PushItemWidth(W);
    if ImGui.DragFloat(imgui_label("##range_max", p), *p.max, .1, 0., 0., format="%.3f") {
        p.max = max(p.min + MIN_RANGE, p.max);
        changed = true;
    }
    ImGui.PopItemWidth();

    NEGATIVE_INF :: 0hFF800000;
    POSITIVE_INF :: 0h7F800000;

    ImGui.SameLine();
    uninitialized := (p.min == NEGATIVE_INF) || (p.max == POSITIVE_INF);
    if ImGui.Button(imgui_label("Reset", p)) || uninitialized {
        p.min = POSITIVE_INF;
        p.max = NEGATIVE_INF;
        for :corners_iterator aabb {
            plane := make_hyperplane3(p.normal, Vector3.{0, 0, 0});
            dist := signed_distance_point3_plane3(it, plane);
            p.min = min(p.min, dist);
            p.max = max(p.max, dist);
        }
        p.min -= .0001;
        p.max += .0001;
    }
    Show_Tooltip("Reset the range min/max to keep the entire aabb");

    return changed;
}

imgui_label :: (label : string, ptr : *void) -> *u8 {
    Push_Temporary();
    return to_c_string(join(label, tprint("##%", ptr)));
}

// Combo box to select display mode enum value
combo_box :: (label : string, data: *void, info_enum: *Type_Info_Enum) -> bool {
    changed := false;
    value := get_enum_value(data, info_enum);
    value_name := "";
    for info_enum.names {
        if value == info_enum.values[it_index]  value_name = it;
    }
    if ImGui.BeginCombo(to_c_string(label), temp_c_string(value_name)) {
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


// Toggle visibility if the checkbox was pressed or if we swept over it with the LMB down
checkbox_press_or_sweep_to_toggle :: (state : *bool, hovered : *bool, label : *u8) -> bool {

    old_state := <<state;
    if ImGui.Checkbox(label, *old_state) { // @Hack Why do we need to pass old_state? To mimic a PressedOnClick checkbox? Explain this better/reimplement it
        // Get here when the LMB is released after going down while hovering the checkbox
        return true;
    }

    // ImGui Rects position min in upper left and max in lower right
    checkbox_upper_left := make_Vector2(ImGui.GetItemRectMin());
    checkbox_lower_right := make_Vector2(ImGui.GetItemRectMax());

    previous_frame_hovered := <<hovered;
    <<hovered = ImGui.IsItemHovered(.RectOnly);
    current_frame_hovered := <<hovered;

    // Enter checkbox sweep mode on lmb down
    if ImGui.IsItemClicked(.Left) {
        app.checkbox_sweep_mode = true;
        app.checkbox_sweep_mode_state_to_set = <<state;
        app.checkbox_sweep_mode_mouse_min_x = xx checkbox_upper_left.x;
        app.checkbox_sweep_mode_mouse_max_x = xx checkbox_lower_right.x;
    }

    // Exit checkbox sweep mode on lmb release
    if ImGui.IsMouseReleased(.Left) {
        app.checkbox_sweep_mode = false;
    }

    if app.checkbox_sweep_mode {
        // When in checkbox sweep mode, provide a nice UX

        assert(ImGui.IsMouseDown(.Left), "Expected checkbox sweep mode only when lmb is down");

        // Issue an SDL event to warps the mouse cursor position to keep it from drifting outside the checkbox column
        // We snap to the middle half of the checkbox since using the whole checkbox means you can sometimes skip around the checkbox boundary
        margin : s32 = (app.checkbox_sweep_mode_mouse_max_x - app.checkbox_sweep_mode_mouse_min_x) / 4;
        if io().MousePos.x < xx (app.checkbox_sweep_mode_mouse_min_x + margin) {
            SDL_WarpMouseInWindow(app.window, app.checkbox_sweep_mode_mouse_min_x + margin, xx io().MousePos.y);
        }
        if io().MousePos.x > xx (app.checkbox_sweep_mode_mouse_max_x - margin) {
            SDL_WarpMouseInWindow(app.window, app.checkbox_sweep_mode_mouse_max_x - margin, xx io().MousePos.y);
        }

        if io().KeyCtrl || io().KeyShift {
            // When control/shift are pressed make the focus the hovered item, hiding others that are swept through
            if !previous_frame_hovered && current_frame_hovered {
                <<state = true;
            } else if previous_frame_hovered && !current_frame_hovered {
                <<state = false;
            }
            if io().KeyShift {
                fit_scene_on_screen(); // Also update the camera when shift is pressed
            }
        } else {
            // Update any checkbox intersecting the mouse sweep so none are missed if the mouse is moved a lot in a single frame
            frame_sweep_start, frame_sweep_end := make_Vector2(io().MousePos) - make_Vector2(io().MouseDelta), io().MousePos;
            swept_up   := frame_sweep_start.y < checkbox_lower_right.y && frame_sweep_end.y > checkbox_upper_left.y;
            swept_down := frame_sweep_start.y > checkbox_upper_left.y  && frame_sweep_end.y < checkbox_lower_right.y;
            if swept_up || swept_down {
                <<state = !app.checkbox_sweep_mode_state_to_set;
            }
        }
    }

    return old_state != <<state;
}


// @Incomplete add a delay before popup
Show_Tooltip :: (description : string) #expand {
    if (ImGui.IsItemHovered()) {
        ImGui.BeginTooltip();
        // ImGui.PushTextWrapPos(450);
        ImGui.TextUnformatted(description);
        // ImGui.PopTextWrapPos();
        ImGui.EndTooltip();
    }
}
