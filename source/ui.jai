// Copyright Epic Games, Inc. All Rights Reserved.

WINDOW_BORDER_UI_OFFSET :: ImGui.ImVec2.{10, 10};

// @Refactor This function is too long (especially the top level for loop). Break it up.
show_item_list_ui :: () {
    using app;

    if !entities.count return;

    ImGui.SetNextWindowPos(WINDOW_BORDER_UI_OFFSET);
    ImGui.Begin("Main Panel", flags = ImGui.WindowFlags.AlwaysAutoResize | ImGui.WindowFlags.NoTitleBar);
    defer ImGui.End();

    any_visibility_changed := false;

    {
        show_entity_index := app.show_console_ui || app.user_selection.is_visible;

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
                visibility_changed := checkbox_press_or_sweep_to_toggle(*it.is_visible, *it.is_visible_sweep_hovered, imgui_label("##Visible", it));
                any_visibility_changed = any_visibility_changed || visibility_changed;
                Show_Tooltip("Visible");

                if !was_visible && it.is_visible {
                    // Make sure we see something when turning on visibility
                    if !it.display_info.surface_visible && !it.display_info.wireframe_visible {
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
                text := entity_filename(<<it, with_short_filename=true, with_generation_index=true, with_loaded_time=false);

                delta_time := get_current_file_time() - it.loaded_filetime;
                FADE_TIME_SECS := 1;
                base_color := ifx is_empty(<<it) then Vector4.{.5, .5, .5, 1} else Vector4.{1, 1, 1, 1};
                color := make_ImVec4(base_color.x, base_color.x, base_color.z, base_color.w);
                if delta_time < xx (FADE_TIME_SECS * 10_000_000.) {
                    alpha := clamp(delta_time / (FADE_TIME_SECS * 10_000_000.), 0., 1.);
                    color4 := lerp(Vector4.{0, 1, 0, 1}, base_color, xx alpha);
                    color = make_ImVec4(color4.x, color4.y, color4.z, color4.w);
                }

                ImGui.PushStyleColor(xx ImGui.Col.Text, color);
                {
                    push_allocator(temp); // to free the join'd string
                    if ImGui.Selectable(to_c_string(join(text, tprint("##%", it))), *it.is_selected) {
                        if !io().KeyCtrl it.is_selected = !it.is_selected;
                    }
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

            SELECTION_MODE_TOOLTIP :: #string DONE
C-LMB Add nearest unclipped vertex to Selection item
S-LMB Click-drag to set clipping sphere on selected items
C-RMB Place camera orbit
DONE // @Volatile Keep synced with keymap
            Show_Tooltip(ifx it.is_visible then SELECTION_MODE_TOOLTIP else "Show Selection\nEnable Selection and Clipping Modes");
        }

        ImGui.TableNextColumn();
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

            ImGui.Separator();

            ImGui.Text("#points = %", it.mesh.positions.count);

            maybe_update_render_info(*it.render_info, *it.mesh);
            aabb := it.render_info.bounding_aabb;
            ImGui.Text("AABB [%, %, %], [%, %, %]", aabb.min_point.x, aabb.min_point.y, aabb.min_point.z, aabb.max_point.x, aabb.max_point.y, aabb.max_point.z);
        }
    }
}

show_item_context_menu :: (entity : *Entity, entity_index : s64) {
    current_pos := ImGui.GetWindowPos();
    current_size := ImGui.GetWindowSize();
    window_pos := make_ImVec2(current_pos.x + current_size.x + WINDOW_BORDER_UI_OFFSET.x, ImGui.GetCursorPos().y);
    ImGui.SetNextWindowPos(pos=window_pos, cond=.ImGuiCond_Appearing);

    if ImGui.BeginPopupContextItem(imgui_label("##context_menu", xx entity_index)) {
        defer ImGui.EndPopup();

        if !entity.is_selected {
            if entity.fully_pathed_filename.count {
                if ImGui.Button(imgui_label("Reload", entity)) {
                    app.entities[entity_index] = reload_entity(entity);
                }
                ImGui.SameLine();
                text := entity_filename(<<entity, with_generation_index=true, with_short_filename=false, with_loaded_time=true);
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

            ImGui.Separator();

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
            ImGui.Text("Model space AABB = [%, %, %]x[%, %, %]", aabb.min_point.x, aabb.min_point.y, aabb.min_point.z, aabb.max_point.x, aabb.max_point.y, aabb.max_point.z);

            shift := make_vector3(entity.mesh.world_from_model._14, entity.mesh.world_from_model._24, entity.mesh.world_from_model._34);
            ImGui.DragFloat3(imgui_label("Offset", entity), *shift.component, .05);
            entity.mesh.world_from_model._14, entity.mesh.world_from_model._24, entity.mesh.world_from_model._34 = shift.x, shift.y, shift.z;

        } else {
            if ImGui.TreeNodeEx(to_c_string(tprint("Selection (% item%)", num_selected_entities(), ifx num_selected_entities() == 1 then "" else "s"))) {
                defer ImGui.TreePop();
                for :selected app.entities {
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
                    for :selected app.entities {
                        app.entities[it_index] = reload_entity(it);
                    }
                    // ImGui.CloseCurrentPopup();
                }

                ImGui.SameLine();
                if ImGui.Button("Clear Selection") {
                    for :selected app.entities {
                        it.is_selected = false;
                    }
                    ImGui.CloseCurrentPopup();
                }
            }

            selection_aabb : AxisBox3;
            for :selected app.entities {
                maybe_update_render_info(*it.render_info, *it.mesh);
                // @Volatile @Cleanup only works for a shift
                aabb := it.render_info.bounding_aabb;
                aabb.min_point = (it.mesh.world_from_model * make_vector4(aabb.min_point, 1)).xyz;
                aabb.max_point = (it.mesh.world_from_model * make_vector4(aabb.max_point, 1)).xyz;
                expand(*selection_aabb, aabb);
            }

            set := display_info_ui(*app.selection_display_info, selection_aabb);

            for :selected app.entities {
                other := *app.selection_display_info;
                using it.display_info;

                if set.vertex_label_style_update.show_position vertex_label_style.show_position = other.vertex_label_style.show_position;
                if set.vertex_label_style_update.show_index    vertex_label_style.show_index    = other.vertex_label_style.show_index;
                if set.vertex_label_style_update.format_float  vertex_label_style.format_float  = other.vertex_label_style.format_float;
                if set.vertex_label_style_update.label_scale   vertex_label_style.label_scale   = other.vertex_label_style.label_scale;
                if set.vertex_label_style_update.label_color   vertex_label_style.label_color   = other.vertex_label_style.label_color;

                if set.element_label_theme_update.show_position element_label_theme.show_position = other.element_label_theme.show_position;
                if set.element_label_theme_update.show_index    element_label_theme.show_index    = other.element_label_theme.show_index;
                if set.element_label_theme_update.format_float  element_label_theme.format_float  = other.element_label_theme.format_float;
                if set.element_label_theme_update.label_scale   element_label_theme.label_scale   = other.element_label_theme.label_scale;
                if set.element_label_theme_update.label_color   element_label_theme.label_color   = other.element_label_theme.label_color;

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
                if set.clip_sphere clip_sphere = other.clip_sphere;
            }
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
    }

    ImGui.SetNextItemWidth(-FLOAT32_MIN);
    combo_box("", *app.camera.rotation_axis, type_info(type_of(app.camera.rotation_axis)));
    Show_Tooltip("C-RMB Camera Rotation Axis");

    if app.camera.look_position != Vector3.{0, 0, 0} {
        size_of_last_item := ImGui.GetItemRectSize();
        if ImGui.Button("Reset Orbit", size=size_of_last_item) {
            look_direction := current_look_direction();
            app.camera.look_position = .{0, 0, 0};
            app.camera.eye_position = app.camera.look_position - look_direction;
        }
    }

    // @Incomplete add perspective/orthographic toggle
    // @Incomplete add button to reset look position
}

show_help_ui :: (world_axes : *Axes_Triad) {
    if !app.show_help_ui return;

    ImGui.SetNextWindowPos(make_ImVec2(app.current_window_width / 2., app.current_window_height / 2.), pivot=.{.5, .5},
    cond=.ImGuiCond_Appearing);
    ImGui.SetNextWindowSizeConstraints(make_ImVec2(app.current_window_width * .6, app.current_window_height * .75),
                                       make_ImVec2(app.current_window_width * .6, app.current_window_height * .75));
    flags := ImGui.WindowFlags.NoTitleBar | .AlwaysHorizontalScrollbar | .NoCollapse;

    ImGui.Begin("##show_help_ui", flags = ImGui.WindowFlags.NoTitleBar | .AlwaysAutoResize | .NoMove /*| .NoNav*/);
    defer ImGui.End();

    COLUMN_WIDTH :: 100;

    Show_Binding :: (binding : string, description : string) #expand {
        ImGui.TextColored(NICE_YELLOW, binding);
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
        Show_Binding("Ctrl-Scroll", "Zoom the camera into the camera look position");
        Show_Binding("RMB", "Rotate the camera");
        Show_Binding("Alt-RMB", "Rotate about selected axis in the camera control pane");
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
        Show_Binding("Ctrl-LMB", "(on a filename) Select an item");
        Show_Binding("RMB", "(on a filename) Access item/selection context menu");
        Show_Binding("RMB", "(on a color) Cycle shading styles");
        Show_Binding("MMB", "(on a color) Reset color from the filename");
        Show_Binding("LMB", "(sweep over visibility checkbox) Update item visibility");
        Show_Binding("Ctrl-LMB", "(sweep over visibility checkbox) Focus hovered item");
        Show_Binding("Shift-LMB", "(sweep over visibility checkbox) Focus hovered item and update camera");
    }

    if Tree_Node_With_Tooltip("Key bindings for Selection Mode",
                              "Enable selection mode by toggling visibility\non the 'Selection' item") {
        defer ImGui.TreePop();
        ImGui.Columns(2);
        defer ImGui.Columns(1);
        ImGui.SetColumnWidth(-1, COLUMN_WIDTH);
        ImGui.NextColumn(); ImGui.NextColumn();
        Show_Binding("Ctrl-LMB", "Add nearest unclipped vertex to 'Selection' item");
        Show_Binding("Shift-LMB", "Click-drag to set clipping sphere");
        Show_Binding("Ctrl-RMB", "Place camera orbit");
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
            Show_Binding(to_string(it), app.keymap_keydown.procs[it.proc_info_index].name);
        }
        for app.keymap.mappings {
            push_allocator(temp);
            Show_Binding(to_string(it), app.keymap.procs[it.proc_info_index].name);
        }
    }

    if ImGui.TreeNode("%", "General Settings") {
        defer ImGui.TreePop();
        combo_box("Background", *app.background_style, type_info(app.Background_Style));
        if app.background_style == .SOLID_COLOR {
            ImGui.ColorEdit4("Background Color", *app.background_solid_color.component, ImGui.ColorEditFlags.NoInputs);
        }
        ImGui.Checkbox("World Axes", *world_axes.visible);

        ImGui.InputInt("Label limit", *app.label_limit);
        if app.label_limit > 2000 {
            color := ImGui.ImVec4.{1., .4, .4, 1.};
            ImGui.TextColored(color, "%", "Warning: label limit > 2000 may be slow");
        }

        if app.current_window_width != app.INITIAL_WINDOW_WIDTH || app.current_window_height != app.INITIAL_WINDOW_HEIGHT {
            if ImGui.Button("Reset Window") {
                SDL_SetWindowSize(app.window, app.INITIAL_WINDOW_WIDTH, app.INITIAL_WINDOW_HEIGHT);
            }
        }
    }

    // :UserConfig add a button to overwrite the user settings file with new defaults here?
    inspect("User Settings", *app.settings);
    clamp_user_settings();

    if ImGui.TreeNodeEx("CHANGELOG") {
        defer ImGui.TreePop();

        COMPILER_VERSION_INFO :: #run tprint("Compiled with Jai version %", compiler_get_version_info(null));
        ImGui.Text(COMPILER_VERSION_INFO);

        latest := app.changelog[0];
        if ImGui.TreeNodeEx(temp_c_string(tprint("Version % (latest)", latest.name)), .DefaultOpen) {
            defer ImGui.TreePop();

            ImGui.PushStyleColor(xx ImGui.Col.Text, NICE_YELLOW);
            ImGui.TextWrapped(latest.changes);
            ImGui.PopStyleColor();
        }

        for 1..app.changelog.count-1 {
            version := app.changelog[it];
            if ImGui.TreeNodeEx(temp_c_string(tprint("Version %", version.name))) {
                defer ImGui.TreePop();

                ImGui.PushStyleColor(xx ImGui.Col.Text, NICE_YELLOW);
                ImGui.TextWrapped(version.changes);
                ImGui.PopStyleColor();
            }
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
    screentone_backfaces : bool;
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

display_info_ui :: (display_info : *Display_Info, aabb : AxisBox3, normals_ui : bool = true, lines_ui : bool = true, faces_ui : bool = true) -> Display_Info_Update {

    set : Display_Info_Update;

    if ImGui.TreeNodeEx("Rendering", .DefaultOpen) {
        defer ImGui.TreePop();

        // FIXME FIXME: opacity should control wireframe??
        ImGui.PushItemWidth(120);
        set.display_mode = combo_box("##display_mode", *display_info.display_mode, type_info(type_of(display_info.display_mode)));
        ImGui.PopItemWidth();

        ImGui.SameLine();
        set.color_reset = ImGui.Button(imgui_label("Reset Colors##color_reset", display_info));
        Show_Tooltip("Deduce item primary colors from the file path");

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
    }

    show_clipping_ui(*set, display_info, aabb);

    show_label_theme_ui :: (update : *Label_Theme_Update, theme : *Label_Theme) {
        // @Cleanup consider the checkbox next to a color idiom here, with separate colors for index and position labels
        update.show_index    = ImGui.Checkbox("Index labels", *theme.show_index);
        update.show_position = ImGui.Checkbox("Position labels", *theme.show_position);
        update.label_color   = ImGui.ColorEdit4("Label color", *theme.label_color.component, ImGui.ColorEditFlags.NoInputs);

        trailing_width : s32 = xx theme.format_float.trailing_width;
        update.format_float |= ImGui.InputInt("Float decimals", *trailing_width);
        theme.format_float.trailing_width = clamp(trailing_width, 0, 12);
        Show_Tooltip("Number of digits following the decimal point");

        update.format_float |= combo_box("Float format", *theme.format_float.mode, type_info(FormatFloat.Mode));
        update.label_scale  = ImGui.DragFloat("Label scale", *theme.label_scale, .005, .2, 1., format="%.3f");
    }

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
                        for :corners_iterator aabb {
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


imgui_label :: (label : string, ptr : *void) -> *u8 {
    push_allocator(temp);
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


// Toggle visibility if the checkbox was pressed or if we swept over it with the LMB down
checkbox_press_or_sweep_to_toggle :: (state : *bool, hovered : *bool, label : *u8) -> bool {

    old_state := <<state;
    if ImGui.Checkbox(label, *old_state) { // @Hack Why do we need to pass old_state? To mimic a PressedOnClick checkbox? Explain this better/reimplement it
        // Get here when the LMB is released after going down while hovering the checkbox
        app.checkbox_sweep_mode = false; // So we don't get stuck in a state where this mode is on we don't reach the toggle off in IsMouseReleased branch. @Cleanup
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

#scope_file

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

NICE_YELLOW :: ImGui.ImVec4.{1, .8, 0, 1};

// @Cleanup I think to_c_string leaks memory, perhaps we can fix by pushing the temporary allocator before calling it
