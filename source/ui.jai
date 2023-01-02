WINDOW_BORDER_UI_OFFSET :: ImGui.ImVec2.{10, 10};

// @Cleanup Remove usages of helper functions BeginPopupContextItem when there is a function boundary between the imgui widget which is rmb clicked and the function rendering the UI

// @Refactor This function is too long (especially the top level for loop). Break it up.
show_left_window :: () {

    // Set window border color to match the selection/RMB target item color
    original_border_color, original_border_size := ScopedWindowBorderTheme(app.theme.item_list_border_color, app.theme.item_list_border_size);

    ImGui.PushStyleVar(xx ImGui.StyleVar.IndentSpacing, 8);
    defer ImGui.PopStyleVar();

    ImGui.SetNextWindowPos(WINDOW_BORDER_UI_OFFSET);
    ImGui.Begin("Main Panel", flags = ImGui.WindowFlags.AlwaysAutoResize | .NoTitleBar);
    defer ImGui.End();

    ScopedWindowBorderTheme(original_border_color, original_border_size);

    if ImGui.BeginTabBar("##ItemsTab", flags=ImGui.TabBarFlags.None) {
        defer ImGui.EndTabBar();

        if ImGui.BeginTabItem("Prism") {
            defer ImGui.EndTabItem();

            // ImGui.ColorEdit4("debug_color", *app.debug_color.component, ImGui.ColorEditFlags.NoInputs);
            show_item_list_ui();
        }

        if ImGui.BeginTabItem("Edit") {
            defer ImGui.EndTabItem();

            show_edit_ui();
        }

        if ImGui.BeginTabItem("View") {
            defer ImGui.EndTabItem();

            ImGui.Checkbox("Show Camera UI", *app.camera.show_ui);
            ImGui.Checkbox("Show Console UI", *app.console.show_ui);
        }

        if ImGui.BeginTabItem("Help") {
            defer ImGui.EndTabItem();

            show_help_ui();
        }
    }
}

show_right_window :: () {
    if !app.camera.show_ui {
        return;
    }

    window_pos := make_ImVec2(ImGui.GetIO().DisplaySize.x - WINDOW_BORDER_UI_OFFSET.x, WINDOW_BORDER_UI_OFFSET.y);
    window_pivot := make_ImVec2(1, 0);

    using ImGui.WindowFlags;

    ImGui.PushStyleColor(xx ImGui.Col.Border, app.theme.camera_ui_button_border_color);
    defer ImGui.PopStyleColor();

    // Set window border color to match the selection/RMB target item color
    original_border_color, original_border_size := ScopedWindowBorderTheme(app.theme.camera_ui_border_color, app.theme.camera_ui_border_size);

    ImGui.SetNextWindowPos(window_pos, .Always, window_pivot);
    ImGui.Begin("Camera shortcuts", flags = NoTitleBar | AlwaysAutoResize | NoMove /*| NoNav*/);
    defer ImGui.End();

    ScopedWindowBorderTheme(original_border_color, original_border_size);

    show_camera_controls();
}

show_item_list_ui :: () {

    // indent := ImGui.GetTreeNodeToLabelSpacing();

    show_tools_ui();

    entity_to_remove := -1;
    any_visibility_changed : bool;

    if ImGui.TreeNodeEx("Items", ImGui.TreeNodeFlags.SpanAvailWidth | .DefaultOpen | .Framed) {
        defer ImGui.TreePop();

        for *folder : app.directories {

            Local_Entity :: struct {
                entity : *Entity;
                global_index : int;
            }

            // The list clipper works on lots of evenly spaced items, which means we need to group entities by folder before we use it
            entities_in_folder : [..]Local_Entity;
            entities_in_folder.allocator = temp;
            for entity, entity_index : app.entities {
                if get_directory(get_entity_source(entity).path) == folder.path {
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

                // indent2 := ImGui.GetTreeNodeToLabelSpacing();
                // ImGui.Unindent(indent2 - indent);
                // defer ImGui.Indent(indent2 - indent);

                if entities_in_folder.count {
                    table_flags := ImGui.TableFlags.NoBordersInBody | .ScrollY;
                    outer_size :=  make_ImVec2(0, app.settings.item_list_max_size_before_scroll_px);

                    show_scrollbar := folder.last_frame_item_list_height_px >= outer_size.y;
                    if !show_scrollbar {
                        table_flags &= ~.ScrollY;
                        outer_size.y = 0; // Not really necessary, since its ignored unless flags include ScrollY
                    }

                    // @Hack Include an extra empty padding column so the filename is not trucated when we use a scrolling region
                    if ImGui.BeginTable(imgui_label("Item List Table", xx folder), 6, flags=table_flags, outer_size=outer_size) {
                        defer ImGui.EndTable();

                        // @Volatile Using ListClipperIterator here is important since we'll issue checkbox_press_or_sweep_to_toggle commands in this loop, see the comment for that function

                        folder.last_frame_item_list_height_px = 0.;
                        for :ListClipperIterator local_entity : entities_in_folder {
                            folder.last_frame_item_list_height_px = clipper.ItemsHeight;
                            update : Item_Entry_Update = show_item_list_entry(local_entity.entity, local_entity.global_index, show_scrollbar);
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

        selected_count := count_selected_entities();
        ImGui.Text("% item% (% selected)", app.entities.count, ifx app.entities.count > 1 then "s" else "", selected_count);

    } // end TreeNodeEx

    // This block implements the feature where if you toggle visibility, editing colors and cycling/resetting display modes on a selected item it changes it on all selected items
    // This is similar to how editing the context menu of an item selection changes the corresponding field in all selected items
    {
        if g_this_frame_state.index_of_selected_item_where_color_was_changed != -1 {
            source : *Entity = app.entities[g_this_frame_state.index_of_selected_item_where_color_was_changed];
            for app.entities if it.is_selected {
                it_primary_color : *Vector4 = get_entity_primary_color(it);
                source_primary_color : *Vector4 = get_entity_primary_color(source);
                if it_primary_color && source_primary_color {
                    <<it_primary_color = <<source_primary_color;
                }
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
                set_entity_primary_color(it);
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

    // nocommit The above should be in a show_items_ui function

    show_details_pane_ui();

    show_tools_ui :: () {
        do_tree := ImGui.TreeNodeEx("Tools", ImGui.TreeNodeFlags.SpanAvailWidth | .Framed);
        if do_tree {
            defer ImGui.TreePop();
            show_select_ui();
            show_preset_ui();
        }
    }

}

Item_Entry_Update :: struct {
    visibility_changed := false;
    entity_to_remove := -1;
}

show_item_list_entry :: (entity : *Entity, entity_index : int, hack_pad_last_column_to_fix_truncation : bool) -> Item_Entry_Update {
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
            color : *Vector4 = get_entity_primary_color(entity);
            if color {
                color_changed = ImGui.ColorEdit4(imgui_label("##color", entity), *color.component, ImGui.ColorEditFlags.NoInputs);
            }
        }
        if ImGui.IsItemClicked(.Middle) {
            entity.display_info.display_mode = Display_Info.{}.display_mode; // Reset to default
            set_entity_primary_color(entity);
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
            color, element_visibility := get_entity_primary_color(entity);
            if element_visibility {
                <<element_visibility = true;
            }
        }

        if entity.is_selected {
            if changed_by_click g_next_frame_state.index_of_selected_item_where_visibility_changed_by_click = entity_index;
        }
    }

    // Toggle clipping checkbox?

    // Entity index used to refer to geometry in console or annotate the text following ther cursor when adding to the user selection
    ImGui.TableNextColumn();
    ImGui.Text("#%", entity_index);
    Show_Tooltip("Entity index for console commands");

    // Write filename
    ImGui.TableNextColumn();
    // ImGui.SetNextItemWidth(-FLOAT32_MIN);
    if entity_name(entity).count {
        text : string = tprint("%1%2", entity_description(entity, with_creation_time=false), ifx is_changed_on_disk(entity) then "*" else "");
        label : *u8 =   imgui_label(text, entity);

        // Note that the ImGui.Selectable widget has this line to set the colors:
        //    const ImU32 col = GetColorU32((held && hovered) ? ImGuiCol_HeaderActive : hovered ? ImGuiCol_HeaderHovered : ImGuiCol_Header);

        // Use the default Selectable widget
        if ImGui.Selectable(label, *entity.is_selected) {
            if !io().KeyCtrl entity.is_selected = !entity.is_selected;
        }
    } else {
        ImGui.Selectable("---", *entity.is_selected); // This should never happen
    }

    // No tooltip for this behaviour since we reserve the tooltip for annotations
    if ImGui.IsItemClicked() {
        app.details_pane.entity_index = entity_index;
        if is_empty(entity.mesh) == false {
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

    entity_tick_flash_hover(entity);

    header_annotation : *Annotation = entity_header_annotation(entity);
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
            ImGui.TextColored(app.theme.keymap_color, "RMB");
            ImGui.TableNextColumn();
            ImGui.Text("Open context menu for the current %", ifx entity.is_selected then "item selection" else "item");
            ImGui.TableNextRow(); ImGui.TableNextColumn();
            ImGui.TextColored(app.theme.keymap_color, "Ctrl LMB");
            ImGui.TableNextColumn();
            ImGui.Text("Toggle selected state of the hovered item");
        }
        ImGui.EndTooltip();
    }
    */

    // @Cleanup This is a horrible way to do this...
    entity.display_info.aabb_visible = false; // Turned on only while context menu > clipping is on

    // @Hack Write empty padding column so filename is not truncated
    ImGui.TableNextColumn();
    if hack_pad_last_column_to_fix_truncation {
        ImGui.Text("  ");
    }

    return result;
} // end show_item_list_entry()



show_preset_ui :: () {

    // indent := ImGui.GetTreeNodeToLabelSpacing();

    do_tree := ImGui.TreeNodeEx("Examples", ImGui.TreeNodeFlags.SpanAvailWidth);
    Show_Tooltip("Create preset shapes\nSome function as tutorials");
    if do_tree {
        defer ImGui.TreePop();

        // indent2 := ImGui.GetTreeNodeToLabelSpacing();
        // ImGui.Unindent(indent2 - indent);
        // defer ImGui.Indent(indent2 - indent);

        if ImGui.Button("Cube    ") { add_preset_cube(); }
        ImGui.SameLine();
        ImGui.Text("A basic cube. Hold Alt to fix position");

        if ImGui.Button("Widget  ") { add_preset_widget(); }
        ImGui.SameLine();
        ImGui.Text("A mesh generated from a CAD file");

        if ImGui.Button("BooleanA") { add_preset_boolean_a(); }
        ImGui.SameLine();
        ImGui.Text("A failed mesh boolean");

        if ImGui.Button("BooleanB") { add_preset_boolean_b(); }
        ImGui.SameLine();
        ImGui.Text("A failed cylinder/cone mesh boolean");
    }
}


show_edit_ui :: () {

    if ImGui.TreeNodeEx("Preferences", ImGui.TreeNodeFlags.SpanAvailWidth | .Framed) {
        defer ImGui.TreePop();

        if ImGui.TreeNodeEx("Appearance", ImGui.TreeNodeFlags.SpanAvailWidth) {
            defer ImGui.TreePop();

            if combo_box("Theme", *app.theme.theme, type_info(Prism_Color_Theme)) {
                set_prism_theme(app.theme.theme);
            }

            combo_box("Background", *app.background_style, type_info(app.Background_Style));
            if app.background_style == .SOLID_COLOR {
                ImGui.ColorEdit4("Background Color", *app.background_solid_color.component, ImGui.ColorEditFlags.NoInputs);
            }
            ImGui.DragFloat("UI Font Scale", *io().FontGlobalScale, .001, format="%.3f");
        }

        if ImGui.TreeNodeEx("Viewport", ImGui.TreeNodeFlags.SpanAvailWidth) {
            defer ImGui.TreePop();

            {
                radius_max_px : float = max(cast(float)app.current_window_width, cast(float)app.current_window_height);
                radius_px := cast(float) app.settings.closest_point_query_max_dist_px;
                ImGui.DragFloat("Closest-Point Query Radius (px)", *radius_px, 1, 25, radius_max_px, format="%.0f");
                Show_Tooltip(tprint(#string DONE
Closest-point query radius in pixels affecting:
- Selection
- Clipping sphere center seeding
- Label visibility in % labelling mode
DONE, Labelling_Mode.RAY_CAST));
                app.settings.closest_point_query_max_dist_px = cast(int) radius_px;
            }

            ImGui.Checkbox("Show World Axes", *app.triad.visible);
        }

        if ImGui.TreeNodeEx("Labelling", ImGui.TreeNodeFlags.SpanAvailWidth) {
            defer ImGui.TreePop();

            combo_box("Labelling Mode", *app.settings.labelling_mode, type_info(Labelling_Mode));
            Show_Tooltip(tprint(#string DONE
%: Show labels at the intersection/closest point of a camera ray query
%: Show labels within some distance of the cursor location
DONE, Labelling_Mode.RAY_CAST, Labelling_Mode.SPOTLIGHT));

            combo_box("Ray Cast Label Location", *app.label_format.location, type_info(app.Label_Format.Location));

            {
                radius_max_px : float = max(cast(float)app.current_window_width, cast(float)app.current_window_height);
                radius_px := cast(float) app.settings.labelling_radius_px;
                ImGui.DragFloat("Spotlight Radius (px)", *radius_px, 1, 25, radius_max_px, format="%.0f");
                Show_Tooltip(tprint("Label visibility radius in pixels for % labelling mode", Labelling_Mode.SPOTLIGHT));
                app.settings.labelling_radius_px = cast(int) radius_px;
            }

            format_float_ui(*app.label_format.format_float);
            format_struct_ui(*app.label_format.format_struct);
        }

        if ImGui.TreeNodeEx("Console", ImGui.TreeNodeFlags.SpanAvailWidth) {
            defer ImGui.TreePop();

            combo_box("Log Mode", *app.console.log_mode, type_info(type_of(app.console.log_mode)));
            Show_Tooltip(#string DONE
Transparent mode: log window ignores mouse input so you can interact with the scene while reading the log
Interactive mode: log window captures mouse input so you can scroll through log messages
DONE);
            ImGui.Checkbox("Scroll to bottom", *app.console.scroll_to_bottom);
        }

        if ImGui.TreeNodeEx("Save & Load", ImGui.TreeNodeFlags.SpanAvailWidth) {
            defer ImGui.TreePop();

            ImGui.DragFloat3(imgui_label("Invalid Point", *app.invalid_point), *app.invalid_point.component, .05, format="%.3f");
            Show_Tooltip("Used to handle invalid .obj files:\nInvalid `f` directive references (missing points) use this position\nInvalid point components (inf/nan) get the corresponding component value");
            ImGui.Checkbox(imgui_label(tprint("Disable reload via % when file unchanged", to_string(RELOAD_ITEMS_ACTION_SET.key))), *app.settings.disable_reload_key_if_file_unchanged);
        }

        if ImGui.TreeNodeEx("Miscellaneous", ImGui.TreeNodeFlags.SpanAvailWidth) {
            defer ImGui.TreePop();

            ImGui.Checkbox("Show Header Annotation Tooltips", *app.settings.show_header_annotation_tooltips);
            ImGui.Checkbox("Demo Mode", *app.demo_mode);
            Show_Tooltip("Show Keyboard/Mouse presses in the viewport\nIntended to be useful for screen share/demos\nEarly WIP feature, only mouse supported");

            disable_window_resize_button := (app.current_window_width == app.INITIAL_WINDOW_WIDTH && app.current_window_height == app.INITIAL_WINDOW_HEIGHT);
            if disable_window_resize_button ImGui.BeginDisabled();
            if ImGui.Button("Reset OS Window Size") SDL_SetWindowSize(app.window, app.INITIAL_WINDOW_WIDTH, app.INITIAL_WINDOW_HEIGHT);
            if disable_window_resize_button ImGui.EndDisabled();
        }
    }


    // :UserConfig add a button to overwrite the user settings file with new defaults here?
    inspect("Advanced", *app.settings);
    clamp_user_settings();

}

// nocommit Fix the focus shortcut when there is an item with just one point

// If entity == null then show the details for the template
show_details_pane_ui :: () {

    selection_ui : bool;
    selection_count := count_selected_entities();
    if selection_count == 0 {
        selection_ui = false;
    } else if selection_count == 1 {
        selection_ui = false;
        for :Selected app.entities {
            app.details_pane.entity_index = it_index;
            break;
        }
    } else {
        selection_ui = true;
    }

    tooltip : string;
    if selection_ui {
        tooltip = tprint("Displaying a template state.\nAny edits will be applied to % selected item%.", selection_count, plural_suffix(selection_count > 1));
    } else if valid_geometry_index(app.details_pane.entity_index) {
        tooltip = tprint("Displaying state for item #%.", app.details_pane.entity_index);
    } else {
        return;
    }

    do_tree := ImGui.TreeNodeEx("Details", ImGui.TreeNodeFlags.SpanAvailWidth | .Framed);
    if tooltip Show_Tooltip(tooltip);
    if do_tree {
        defer ImGui.TreePop();

        if selection_ui {
            show_details_pane_ui_for_item_selection();
        } else {
            show_details_pane_ui_for_item();
        }
    }
}

show_details_pane_ui_for_item :: () {
    entity_index := app.details_pane.entity_index;
    using entity : *Entity = app.entities[entity_index];

    if ImGui.BeginTabBar("##DetailsTabBar", flags=ImGui.TabBarFlags.None) {
        defer ImGui.EndTabBar();

        if ImGui.BeginTabItem("Display") {
            defer ImGui.EndTabItem();

            if entity_name(entity).count {

                if ImGui.Button(imgui_label("Reload", entity)) reload_entity(entity, triggered_by_button=true);
                if is_changed_on_disk(entity) == false {
                    Show_Tooltip("This file has NOT changed on disk\nsince the last time it was loaded");
                }

                source : *Entity_Source_File = isa(entity.source, Entity_Source_File);
                if source {
                    ImGui.SameLine();
                    ImGui.Checkbox(imgui_label("", entity), *source.auto_reload);
                    Show_Tooltip("Auto-reload if file changes on disk");
                } else {
                    dummy := true;
                    ImGui.SameLine();
                    ImGui.Checkbox(imgui_label("", entity), *dummy);
                    Show_Tooltip(tprint("Auto-reload only makes sense for files loaded from disk.\nThis entity was sourced from a %", get_entity_source_description(entity)));
                }

                ImGui.SameLine();
                ImGui.Text("#%", entity_index);
                Show_Tooltip("Entity index for console commands");
                ImGui.SameLine();
                text := entity_description(entity, with_creation_time=true);
                ImGui.TextUnformatted(text);
                entity_source_tooltip(entity);
            }
            if ImGui.Button("Focus ") {
                // Fit all visible items on the screen
                fit_on_screen(entity);
            }

            display_information(entity);
            display_transform(entity);

            maybe_update_render_info(*entity.render_info, *entity.mesh);

            aabb_world := transform_axis_box3(entity.mesh.world_from_model, entity.render_info.bounding_aabb);
            set := display_info_ui(*entity.display_info, aabb_world);
        }

        if ImGui.BeginTabItem("Annotations") {
            defer ImGui.EndTabItem();

            display_annotations(entity, entity_index);
        }

        for base_attribute : entity.mesh.attributes {
            if ImGui.BeginTabItem(imgui_label(base_attribute.name, base_attribute)) {
                defer ImGui.EndTabItem();

                value_type : Type;
                element_kind : Simple_Mesh_Element;
                if base_attribute.type == {
                    case Simple_Mesh_Attribute(Matrix3, .TRIANGLE);
                        ImGui.Text("Attribute '%' assigns % values to triangles", base_attribute.name, Matrix3);
                        Show_Tooltip(TOOLTIP);
                        TOOLTIP :: #string DONE
Matrix3 :: struct {
    _11, _12, _13 : float;
    _21, _22, _23 : float;
    _31, _32, _33 : float;
    #place _11; row: [3]Vector3 = ---;
}
DONE;
                }

                if base_attribute.type == {
                    case Simple_Mesh_Attribute(Matrix3, .TRIANGLE);

                        show_attribute_theme_ui("Attribute", "Show attribute labels", *base_attribute.display_info.theme);

                        attribute := cast(*Simple_Mesh_Attribute(Matrix3, .TRIANGLE))base_attribute;
                        if ImGui.TreeNodeEx(imgui_label(tprint("Attributes Table (%)", attribute.values.count), base_attribute), .SpanAvailWidth) {
                            defer ImGui.TreePop();

                            if attribute.values.count {

                                table_flags := ImGui.TableFlags.RowBg | .ScrollY | .RowBg | .Resizable | .Reorderable | .Hideable; // | .Sortable;
                                outer_size := make_ImVec2(0, app.settings.annotation_list_max_size_before_scroll_px);

                                if last_frame_annotation_list_height_px < outer_size.y {
                                    table_flags &= ~.ScrollY;
                                    outer_size.y = 0; // Not really necessary, since its ignored unless flags include ScrollY
                                }

                                column_count : s32 = 3;
                                if ImGui.BeginTable(imgui_label("##Attribute_Table", attribute), column_count, flags=table_flags, outer_size=outer_size) {
                                    defer ImGui.EndTable();

                                    ImGui.TableSetupColumn("UI",    ImGui.TableColumnFlags.WidthFixed | .NoSort);
                                    ImGui.TableSetupColumn("Index", ImGui.TableColumnFlags.WidthFixed | .DefaultSort);
                                    ImGui.TableSetupColumn("Value", ImGui.TableColumnFlags.WidthStretch);
                                    ImGui.TableSetupScrollFreeze(0, 1); // Make header row always visible
                                    ImGui.TableHeadersRow();

                                    last_frame_annotation_list_height_px = 0.;
                                    for :ListClipperIterator value, index : attribute.values {
                                        last_frame_annotation_list_height_px = clipper.ItemsHeight;

                                        ImGui.TableNextRow();

                                        ImGui.TableNextColumn();
                                        if ImGui.Button(imgui_label("Focus", xx index)) {
                                            item_focus_triangle(entity_index, index, ifx io().KeyShift then 0. else -1.);
                                        }
                                        bindings : [..]Binding_With_Description;
                                        bindings.allocator = temp;
                                        array_add(*bindings, make_Binding_With_Description( "LMB",       "Update camera to focus subject"));
                                        array_add(*bindings, make_Binding_With_Description( "Shift LMB", "As above, with sphere clipping"));
                                        Show_Tooltip_Binding(..bindings);

                                        ImGui.TableNextColumn();
                                        ImGui.Text(tprint("%", index));

                                        ImGui.TableNextColumn();
                                        new_context : Context;
                                        new_context.print_style.default_format_float = app.label_format.format_float;
                                        new_context.print_style.default_format_struct = app.label_format.format_struct;
                                        push_context new_context {
                                            ImGui.Text(tprint("%", value));
                                        }
                                    }
                                    last_frame_annotation_list_height_px *= attribute.values.count; // FIXME This is wrong if string annotations have different numbers of lines
                                }
                            }
                        }
                    case;
                        log_warning("@Incomplete attribute table UI for attribute type '%'", base_attribute.type);
                }
            }
        }
    }
}

show_details_pane_ui_for_item_selection :: () {
    if ImGui.BeginTabBar("##DetailsTabBar", flags=ImGui.TabBarFlags.None) {
        defer ImGui.EndTabBar();

        if ImGui.BeginTabItem("Display") {
            defer ImGui.EndTabItem();

            if ImGui.TreeNodeEx("Selection", .SpanAvailWidth) {
                defer ImGui.TreePop();

                for :Selected entity : app.entities {
                    if entity_name(entity).count {

                        if ImGui.Button(imgui_label("Reload", entity)) reload_entity(entity, triggered_by_button=true);
                        if is_changed_on_disk(entity) == false {
                            Show_Tooltip("This file has NOT changed on disk\nsince the last time it was loaded");
                        }

                        // nocommit consolidate code with the single item case
                        entity_source_file := isa(entity.source, Entity_Source_File);
                        if entity_source_file {
                            ImGui.SameLine();
                            ImGui.Checkbox(imgui_label("", entity), *entity_source_file.auto_reload);
                            Show_Tooltip("Auto-reload if file changes on disk");
                        }

                        ImGui.SameLine();
                        ImGui.Text("#%", it_index);
                        Show_Tooltip("Entity index for console commands");
                        ImGui.SameLine();
                        text := entity_description(entity, with_creation_time=true);
                        ImGui.TextUnformatted(text);
                        entity_source_tooltip(entity);
                    }
                }

                if ImGui.Button("Reload Selection  ") {
                    for :Selected entity : app.entities {
                        reload_entity(entity, triggered_by_button=true);
                    }
                }
                ImGui.SameLine();
                if ImGui.Button(imgui_label("Toggle Auto-Reload", *app.entities)) {
                    // Find the state to toggle
                    state := false;
                    for :Selected app.entities {
                        source := isa(it.source, Entity_Source_File);
                        if source {
                            state = !source.auto_reload;
                            break;
                        }
                    }

                    for :Selected app.entities {
                        source := isa(it.source, Entity_Source_File);
                        if source {
                            source.auto_reload = state;
                        }
                    }
                }
                Show_Tooltip("Toggle auto-reload state on selected items");

                if ImGui.Button("Focus Selection   ") {
                    focus_items(null, .SELECTED);
                }

                // This isn't actually very useful, user should use the Ctrl-a binding instead
                //ImGui.SameLine();
                //if ImGui.Button("Deselect All") {
                //    for :Selected entity : app.entities {
                //        entity.is_selected = false;
                //    }
                //    ImGui.CloseCurrentPopup();
                //}
            }

            update := display_info_ui(*app.edit_tool.display_info, entity_selection_aabb());
            apply_display_info_update(update, .SELECTED);
        }
    }
}

show_select_ui :: () {
    // nocommit:
    // - Could add options to the select tool e.g., should we copy over annotations/attributes? should we prefix annotations with the item index of the source? (latter is a way of adding the source entity to the elements in the selection)

    // indent := ImGui.GetTreeNodeToLabelSpacing();

    do_tree := ImGui.TreeNodeEx("Select", ImGui.TreeNodeFlags.SpanAvailWidth);
    Show_Tooltip("Create items from mesh point/face selections");
    if do_tree {
        defer ImGui.TreePop();

        // indent2 := ImGui.GetTreeNodeToLabelSpacing();
        // ImGui.Unindent(indent2 - indent);
        // defer ImGui.Indent(indent2 - indent);

        // Selection Mode UI
        if ImGui.BeginTable("Mode Table", 5, flags=ImGui.TableFlags.NoBordersInBody) {
            defer ImGui.EndTable();

            it := *app.select_tool.entity; // @Cleanup remove this weird alias

            ImGui.TableNextRow();

            // Remove button
            ImGui.TableNextColumn();
            {
                disable_cache_button := is_empty(app.select_tool.entity.mesh);
                if disable_cache_button       ImGui.BeginDisabled();
                defer if disable_cache_button ImGui.EndDisabled();

                if ImGui.Button(imgui_label("Cache ", *app.select_tool.entity)) {
                    if !is_empty(app.select_tool.entity.mesh) {
                        new_entity : *Entity = New(Entity);

                        merge(*new_entity.mesh, app.select_tool.entity.mesh);
                        counter : *Preset_Counter = find_or_add(*g_preset_name_to_counter, "Selection");
                        set_entity_source_from_selection(new_entity, tprint("Selection %", counter.count), new_entity.mesh.positions.count);
                        set_entity_display_info(new_entity);
                        counter.count += 1;

                        add_entity(new_entity, app.settings.duplicate_file_behaviour);

                        deinit(*app.select_tool.entity);

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
                    it.display_info.vertex_label_theme.label_color = darken(it.display_info.points_color, .8);
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
                // nocommit Fix this tooltip
                array_add(*bindings, make_Binding_With_Description( "RMB",       "Open context menu for the current Selection"));
                array_add(*bindings, make_Binding_With_Description( "Ctrl RMB",  "Set camera orbit on nearest unclipped vertex"));
                array_add(*bindings, make_Binding_With_Description( "Ctrl LMB",  "Add nearest unclipped vertex to Selection item"));
                array_add(*bindings, make_Binding_With_Description( "Shift LMB", "Click-drag to set clipping sphere on selected items"));
                Show_Tooltip_Binding(..bindings);
            } else {
                Show_Tooltip("Show Selection\nEnable Selection and Clipping Modes");
            }
            if ImGui.IsItemClicked() && is_empty(it.mesh) == false {
                fit_on_screen(it);
            }
            entity_tick_flash_hover(it);
            
            // Note: The select_tool entity should not have a context menu, this is just a bit confusing and weird, its simpler if the user just caches the selection to make it a proper item and then access the menu
            //show_item_context_menu(*app.select_tool.entity, -1);

            ImGui.TableNextRow();
            ImGui.TableNextColumn();
        }
    }
}

// @Incomplete This should have an update struct so we can know what changed on a granular level, we want to apply updates on a granular level
format_float_ui :: (format : *FormatFloat) -> bool {
    changed := false;

    trailing_width : s32 = xx format.trailing_width;
    changed |= ImGui.InputInt("Float decimals", *trailing_width);
    format.trailing_width = clamp(trailing_width, 0, 12);
    Show_Tooltip("Number of digits following the decimal point");
    changed |= combo_box("Float format", *format.mode, type_info(FormatFloat.Mode));

    return changed;
}

// @Incomplete This should have an update struct so we can know what changed on a granular level, we want to apply updates on a granular level
format_struct_ui :: (format : *FormatStruct) -> bool {
    changed := false;

    use_long_form := format.use_long_form_if_more_than_this_many_members == -1;
    if ImGui.Checkbox("Long form", *use_long_form) {
        format.use_long_form_if_more_than_this_many_members = ifx use_long_form then -1 else 99999;
        changed = true;
    }
    Show_Tooltip(TOOLTIP);
TOOLTIP :: #string DONE
"short form" means just draw values e.g., {1, 3, 5}
"long form"  means draw names then values e.g., {x = 1; y = 3; z = 5;}
DONE
    ImGui.SameLine();
    changed |= ImGui.Checkbox("Long form newlines", *format.use_newlines_if_long_form);

    return changed;
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
    if app.console.show_ui {
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
        apply_update(set, app.edit_tool.display_info, *it.display_info);
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

        // We could have buttons to toggle selection/visibility by folder but we don't, the user can just Ctrl LMB on folder names to select all the items and then press delete to remove them, or click on visibility to toggle visibility. Maybe we should have the buttons for better discoverability, but I think more tooltips (when we move to an ImGui version where delays are properly supported) will be a better solution

        if ImGui.Button("Remove folder") {
            for app.entities if get_directory(get_entity_source(it).path) == path {
                remove it;
            }
            remove_directory(path);
        }
    }
}

show_camera_controls :: () {

    ImGui.PushStyleVar(xx ImGui.StyleVar.CellPadding, .{0, 0});
    ImGui.PushStyleVar(xx ImGui.StyleVar.CellPadding, .{0, 0});
    defer ImGui.PopStyleVar();
    defer ImGui.PopStyleVar();

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
    table_flags := ImGui.TableFlags.BordersInnerV | .RowBg;

    if ImGui.TreeNodeEx("About", ImGui.TreeNodeFlags.SpanAvailWidth | .Framed) {
        defer ImGui.TreePop();

        ImGui.PushStyleColor(xx ImGui.Col.Text, app.theme.generic_color);
        defer ImGui.PopStyleColor();
        ImGui.Text("Prism is a tool for debugging computational geometry algorithms.");
        ImGui.Text("Load files/folders with drag/drop or via command line arguments.");

        /*
        Goals
        - work with .obj file format
        - writing quads seems not that useful, so make `f a b c d` represent a tet rather than a quad
        ImGui.Text("Feedback/Bugs can be:");
        ImGui.Text("- sent to matija.kecman@epicgames.com, or");
        ImGui.Text("- posted on the slack channel #sig-prism-ext, or");
        ImGui.Text("- suggested on the User Guide document pinned on slack");
        */

        COMPILER_VERSION_INFO :: #run tprint("Compiled with Jai version %.", compiler_get_version_info(null));
        ImGui.Text(COMPILER_VERSION_INFO);
    }

    // @Cleaup name it like a macro
    ShowBinding :: (binding : string, description : string) #expand {
        ImGui.TableNextColumn();
        ImGui.TextColored(app.theme.keymap_color, binding);
        ImGui.TableNextColumn();
        ImGui.Text(description);
    }

    if ImGui.TreeNodeEx("Key Bindings", ImGui.TreeNodeFlags.SpanAvailWidth | .Framed) {
        defer ImGui.TreePop();

        if ImGui.TreeNodeEx("In the Viewport", .SpanAvailWidth) {
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

        if ImGui.TreeNodeEx("In the Items Tab", .SpanAvailWidth) {
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

        if ImGui.TreeNodeEx("For Point Selection", .SpanAvailWidth) {
            defer ImGui.TreePop();
            ImGui.BeginTable("", 2, flags=table_flags);
            defer ImGui.EndTable();

            ShowBinding("Ctrl LMB", "Add nearest unclipped vertex to 'Selection' item");
            ShowBinding("Shift LMB", "Click-drag to set clipping sphere");
            ShowBinding("Ctrl RMB", "Place camera orbit");
        }

        if ImGui.TreeNodeEx("For Item Set Updates", .SpanAvailWidth) {
            defer ImGui.TreePop();
            ImGui.BeginTable("", 2, flags=table_flags);
            defer ImGui.EndTable();

            for app.keymap_actions.mappings {
                push_allocator(temp);
                ShowBinding(to_string(it.key_code, it.modifier_flags), app.keymap_actions.procs[it.proc_info_index].name);
            }
        }

        if ImGui.TreeNodeEx("Miscellaneous", .SpanAvailWidth) {
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
    }

    outer_size : ImGui.ImVec2;
    outer_size.x = min(800., app.current_window_width * .75);
    outer_size.y = 0;

    if ImGui.TreeNodeEx("Changelog", ImGui.TreeNodeFlags.SpanAvailWidth | .Framed) {
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

            ImGui.PushStyleColor(xx ImGui.Col.Text, app.theme.changelog_color);
            ImGui.TextWrapped(latest.description);
            // ImGui.Text(latest.description); // @Bug This truncated the changelog for PRISM_VERSION_0_2_1
            ImGui.PopStyleColor();
        }

        for 1..app.changelog.count-1 {
            version := app.changelog[it];
            if ImGui.TreeNodeEx(temp_c_string(tprint("Version %, %", version.name, version.date))) {
                defer ImGui.TreePop();

                ImGui.PushStyleColor(xx ImGui.Col.Text, app.theme.changelog_color);
                ImGui.TextWrapped(version.description);
                // ImGui.Text(version.description);
                ImGui.PopStyleColor();
            }
        }
    }

    if ImGui.TreeNodeEx("Known Issues", ImGui.TreeNodeFlags.SpanAvailWidth | .Framed) {
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
        ImGui.TableSetupScrollFreeze(0, 1); // Make header row always visible
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
                ImGui.PushStyleColor(xx ImGui.Col.Text, app.theme.generic_color);
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
                    source := isa(entity.source, Entity_Source_File);
                    assert(source != null); // Expecte a file
                    source.auto_reload = dir.set_auto_reload_on_newly_loaded_files;
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


show_vertex_label_theme_ui :: (name : string, tooltip : string, theme : *Vertex_Label_Theme) {
    ImGui.Text(name);
    ImGui.SameLine();

    ImGui.Checkbox(imgui_label("##index", theme), *theme.show_index);
    Show_Tooltip(tooltip);
    ImGui.SameLine();

    ImGui.ColorEdit4(imgui_label("##color", theme), *theme.label_color.component, ImGui.ColorEditFlags.NoInputs);
    Show_Tooltip("Text Color");
    ImGui.SameLine();

    ImGui.PushItemWidth(70);
    ImGui.DragFloat(imgui_label("##scale", theme), *theme.label_scale, .005, .2, 1., format="%.3f");
    Show_Tooltip("Text Scale");
    ImGui.PopItemWidth();
    ImGui.SameLine();

    ImGui.Checkbox(imgui_label("##coord_visible", theme), *theme.show_position);
    Show_Tooltip("Show Position (Model Space)");
}

show_element_label_theme_ui :: (name : string, tooltip : string, theme : *Element_Label_Theme) {
    ImGui.Text(name);
    ImGui.SameLine();

    ImGui.Checkbox(imgui_label("##index", theme), *theme.show_index);
    Show_Tooltip(tooltip);
    ImGui.SameLine();

    ImGui.ColorEdit4(imgui_label("##color", theme), *theme.label_color.component, ImGui.ColorEditFlags.NoInputs);
    Show_Tooltip("Text Color");
    ImGui.SameLine();

    ImGui.PushItemWidth(70);
    ImGui.DragFloat(imgui_label("##scale", theme), *theme.label_scale, .005, .2, 1., format="%.3f");
    Show_Tooltip("Text Scale");
    ImGui.PopItemWidth();
}

show_annotation_theme_ui :: (name : string, tooltip : string, theme : *Annotation_Label_Theme) {
    ImGui.Text(name);
    ImGui.SameLine();

    ImGui.Checkbox(imgui_label("##visible", theme), *theme.visible);
    Show_Tooltip(tooltip);
    ImGui.SameLine();

    ImGui.ColorEdit4(imgui_label("##color", theme), *theme.label_color.component, ImGui.ColorEditFlags.NoInputs);
    Show_Tooltip("Text Color");
    ImGui.SameLine();

    ImGui.PushItemWidth(70);
    ImGui.DragFloat(imgui_label("##scale", theme), *theme.label_scale, .005, .2, 1., format="%.3f");
    Show_Tooltip("Text Scale");
    ImGui.PopItemWidth();
}

show_attribute_theme_ui :: (name : string, tooltip : string, theme : *Attribute_Theme) {
    ImGui.Text(name);
    ImGui.SameLine();

    ImGui.Checkbox(imgui_label("##visible", theme), *theme.visible);
    Show_Tooltip(tooltip);
    ImGui.SameLine();

    ImGui.ColorEdit4(imgui_label("##color", theme), *theme.label_color.component, ImGui.ColorEditFlags.NoInputs);
    Show_Tooltip("Text Color");
    ImGui.SameLine();

    ImGui.PushItemWidth(70);
    ImGui.DragFloat(imgui_label("##scale", theme), *theme.label_scale, .005, .2, 1., format="%.3f");
    Show_Tooltip("Text Scale");
    ImGui.PopItemWidth();
}


display_info_ui :: (display_info : *Display_Info, aabb : AxisBox3) -> Display_Info_Update {

    old_display_info := <<display_info;

    if ImGui.TreeNodeEx("Rendering", .SpanAvailWidth) {
        defer ImGui.TreePop();

        ImGui.Text("Visible    ");
        ImGui.SameLine();
        ImGui.Checkbox(imgui_label("##item_visible", display_info), *display_info.is_visible);
        Show_Tooltip("Overall item visibility");

        // FIXME FIXME: opacity should control wireframe??
        ImGui.Text("Render Mode");
        ImGui.SameLine();
        ImGui.PushItemWidth(120);
        combo_box("##display_mode", *display_info.display_mode, type_info(type_of(display_info.display_mode)));
        ImGui.PopItemWidth();

        // This doesn't seem very useful so I removed it
        //ImGui.SameLine();
        //ImGui.Button(imgui_label("Reset Colors##color_reset", display_info));
        //Show_Tooltip("Deduce item primary colors from the file path");

        {
            ImGui.Text("Points     ");
            ImGui.SameLine();
            ImGui.Checkbox(imgui_label("##points_visible", display_info), *display_info.points_visible);
            Show_Tooltip("Point visibility");
            ImGui.SameLine();
            ImGui.ColorEdit4(imgui_label("##points_color", display_info), *display_info.points_color.component, ImGui.ColorEditFlags.NoInputs);
            ImGui.SameLine();
            ImGui.SameLine();
            ImGui.PushItemWidth(70);
            ImGui.InputInt("##points_size", *display_info.points_size);
            Show_Tooltip("Size");
            display_info.points_size = clamp(display_info.points_size, 1, 10);
            ImGui.PopItemWidth();
        }

        {
            ImGui.Text("Normals    ");
            ImGui.SameLine();
            ImGui.Checkbox(imgui_label("##normals_visible", display_info), *display_info.normals_visible);
            Show_Tooltip("Normal visibility");
            ImGui.SameLine();
            ImGui.ColorEdit4(imgui_label("##normals_color", display_info), *display_info.normals_color.component, ImGui.ColorEditFlags.NoInputs);
            ImGui.SameLine();
            ImGui.PushItemWidth(70);
            ImGui.DragFloat(imgui_label("##normals_length", display_info), *display_info.normals_length, .05);
            Show_Tooltip("Length");
            ImGui.PopItemWidth();
        }

        {
            ImGui.Text("Segments   ");
            ImGui.SameLine();
            ImGui.Checkbox(imgui_label("##segments_visible", display_info), *display_info.segments_visible);
            Show_Tooltip("Segment visibility");
            ImGui.SameLine();
            ImGui.ColorEdit4(imgui_label("##segments_color", display_info), *display_info.segments_color.component, ImGui.ColorEditFlags.NoInputs);
            ImGui.SameLine();
            ImGui.PushItemWidth(70);
            ImGui.DragFloat(imgui_label("##segments_width", display_info), *display_info.segments_width, .05);
            Show_Tooltip("Width");
            display_info.segments_width = clamp(display_info.segments_width, 1, 5);
            ImGui.PopItemWidth();
        }

        {
            ImGui.Text("Triangles  ");
            ImGui.SameLine();
            ImGui.Checkbox(imgui_label("##triangles_visible", display_info), *display_info.triangles_visible);
            Show_Tooltip("Triangle visibility");
            {
                ImGui.SameLine();
                ImGui.ColorEdit4(imgui_label("##triangles_color", display_info), *display_info.triangles_color.component, ImGui.ColorEditFlags.NoInputs);
                Show_Tooltip("Frontface Color");
            }
            ImGui.SameLine();
            ImGui.PushItemWidth(70);
            combo_box("##Backface Mode", *display_info.backface_mode, type_info(Backface_Mode));
            Show_Tooltip("Backface Render Mode");
            ImGui.PopItemWidth();
            ImGui.SameLine();
            ImGui.Checkbox(imgui_label("##Flat Shading", display_info), *display_info.flat_shading);
            Show_Tooltip("Flat Shading");
        }

        {
            ImGui.Text("Edges      ");
            ImGui.SameLine();
            ImGui.Checkbox(imgui_label("##edges_visible", display_info), *display_info.edges_visible);
            Show_Tooltip("Triangle edges visibility");
            ImGui.SameLine();
            ImGui.ColorEdit4(imgui_label("##edges_color", display_info), *display_info.edges_color.component, ImGui.ColorEditFlags.NoInputs);
            ImGui.SameLine();
            ImGui.PushItemWidth(70);
            ImGui.DragFloat(imgui_label("##edges_width", display_info), *display_info.edges_width, .05);
            Show_Tooltip("Width");
            display_info.edges_width = clamp(display_info.edges_width, 1., 5);
            ImGui.PopItemWidth();
        }
    }

    show_clipping_ui(display_info, aabb);

    if ImGui.TreeNodeEx("Labelling", .SpanAvailWidth) {
        defer ImGui.TreePop();

        show_vertex_label_theme_ui( "Vertex    ", "Show index of .obj 'v' directives", *display_info.vertex_label_theme);
        show_element_label_theme_ui("Point     ", "Show index of .obj 'p' directives", *display_info.point_label_theme);
        show_element_label_theme_ui("Segment   ", "Show index of .obj 'l' directives", *display_info.segment_label_theme);
        show_element_label_theme_ui("Triangle  ", "Show index of .obj 'f' directives", *display_info.triangle_label_theme);
        show_annotation_theme_ui("Annotation", "Show annotations", *display_info.annotation_label_theme); // Its convenient to have all the labels in one place!
    }

    return get_update(old_display_info, display_info);
}

display_information :: (entity : *Entity) {
    if ImGui.TreeNodeEx("Information", .SpanAvailWidth) {
        defer ImGui.TreePop();
        ImGui.PushStyleColor(xx ImGui.Col.Text, app.theme.generic_color);
        defer ImGui.PopStyleColor();

        ImGui.Text("#positions = %", entity.mesh.positions.count);
        Show_Tooltip("Number of vertex positions");
        ImGui.Text("#points = %", entity.mesh.points.count);
        Show_Tooltip("Number of point elements");
        ImGui.Text("#segments = %", entity.mesh.segments.count);
        Show_Tooltip("Number of line segment elements");
        ImGui.Text("#triangles = %", entity.mesh.triangles.count);
        Show_Tooltip("Number of triangle elements");

        maybe_update_render_info(*entity.render_info, *entity.mesh);

        imgui_text_for_aabb(entity.render_info.bounding_aabb);
    }
}

display_transform :: (entity : *Entity) {
    if ImGui.TreeNodeEx("Transform", .SpanAvailWidth) {
        defer ImGui.TreePop();
        ImGui.PushStyleColor(xx ImGui.Col.Text, app.theme.generic_color);
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

    header := "Annotation Table (none)";
    annotation_count := entity_annotation_count(entity);
    if annotation_count {
        header = tprint("Annotation Table (%)", annotation_count);
    } else {
        ImGui.BeginDisabled();
    }
    defer if annotation_count == 0 then ImGui.EndDisabled();

    show_annotation_theme_ui("Annotation", "Show annotations", *entity.display_info.annotation_label_theme);

    if ImGui.TreeNodeEx(imgui_label(header, entity), .SpanAvailWidth) {
        defer ImGui.TreePop();

        DoRadioButton :: (name : string, annotations_kind : Annotation.Kind, annotations : [..]Annotation) #expand {
            if !annotations.count ImGui.BeginDisabled();
            ImGui.RadioButton(name, xx *`entity.annotation_info.show_kind, xx annotations_kind);
            if !annotations.count ImGui.EndDisabled();
        }

        // @Cleanup Make this work with reflection!
        DoRadioButton("Vertex", .VERTEX, entity.vertex_annotations);
        ImGui.SameLine();
        DoRadioButton("Edge", .LINE, entity.line_annotations);
        ImGui.SameLine();
        DoRadioButton("Face", .TRIANGLE, entity.face_annotations);
        ImGui.SameLine();
        DoRadioButton("Block", .BLOCK, entity.block_annotations); // @Think Maybe better name is FILE annotation
        ImGui.SameLine();
        DoRadioButton("Command", .COMMAND, entity.command_annotations);

        annotations : [..]Annotation;
        if #complete entity.annotation_info.show_kind == {
            case .VERTEX;   annotations = entity.vertex_annotations;
            case .LINE;     annotations = entity.line_annotations;
            case .TRIANGLE; annotations = entity.face_annotations;
            case .BLOCK;    annotations = entity.block_annotations;
            case .COMMAND;  annotations = entity.command_annotations;
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
                ImGui.TableSetupScrollFreeze(0, 1); // Make header row always visible
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
                for :ListClipperIterator annotation : annotations {
                    last_frame_annotation_list_height_px = clipper.ItemsHeight;

                    ImGui.TableNextRow();

                    ImGui.TableNextColumn();
                    if annotation.kind == .BLOCK {
                        // @Incomplete Add an show/hide button to fold multiline comments?
                    } else {
                        if ImGui.Button(imgui_label("Focus", xx annotation.id)) {
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
                    ImGui.Text(tprint("%", get_type(annotation.value)));

                    ImGui.TableNextColumn();
                    ImGui.Text(to_string(annotation));
                }
                last_frame_annotation_list_height_px *= annotations.count; // FIXME This is wrong if string annotations have different numbers of lines
            }

        }
    }
}

// This is also used for the attribute tables, so don't be confused by the name..!
last_frame_annotation_list_height_px : float;

show_clipping_ui :: (using display_info : *Display_Info, aabb : AxisBox3) {

    if ImGui.TreeNodeEx(imgui_label("Clipping", display_info), .SpanAvailWidth) {
        defer ImGui.TreePop();

        if ImGui.BeginTable("##Clipping UI Table", 4, flags=ImGui.TableFlags.RowBg) { // , flags=ImGui.TableFlags.SizingFixedFit) {
            defer ImGui.EndTable();

            ImGui.TableSetupColumn("checkbox", .WidthFixed, user_id=0);
            ImGui.TableSetupColumn("center/normal|radius/range", .WidthFixed, user_id=1);
            ImGui.TableSetupColumn("center/normal|radius/range value", .WidthFixed, init_width_or_weight=200, user_id=2);
            ImGui.TableSetupColumn("reset/normalize", .WidthFixed, user_id=3);

            {
                ImGui.TableNextRow();
                old_clip_sphere := clip_sphere;

                ImGui.TableSetColumnIndex(0);
                ImGui.Text("Sphere");
                ImGui.SameLine();
                ImGui.Checkbox(imgui_label("##clip_sphere", *clip_sphere), *clip_sphere.is_active);
                Show_Tooltip("Enable clipping using distance from a point.\nKeep the region inside the sphere.");
                ImGui.TableSetColumnIndex(1);
                ImGui.Text("Center");
                ImGui.Text("Radius");
                ImGui.TableSetColumnIndex(2);
                ImGui.SetNextItemWidth(-FLOAT32_MIN);
                ImGui.DragFloat3(imgui_label("##clip_sphere.center", *clip_sphere), *clip_sphere.center.component, .05, format="%.3f");
                ImGui.SetNextItemWidth(-FLOAT32_MIN);
                ImGui.DragFloat(imgui_label("##clip_sphere.radius", *clip_sphere), *clip_sphere.radius, .01, 0., 0., format="%.3f");
                ImGui.TableSetColumnIndex(3);
                POSITIVE_INF :: 0h7F800000;
                uninitialized := (clip_sphere.radius == POSITIVE_INF);
                if ImGui.Button(imgui_label("Reset    ##sphere", *clip_sphere)) || uninitialized {
                    clip_sphere.center = .{0, 0, 0};
                    clip_sphere.radius = POSITIVE_INF;
                }
                Show_Tooltip("Reset sphere to contain the universe");

                get_update(old_clip_sphere, clip_sphere);
            }

            {
                clip_range_ui :: (p : *Clip_Range, aabb : AxisBox3, fallback_normal : Vector3) {
                    ImGui.TableNextRow();

                    MIN_RANGE :: .1;

                    ImGui.TableSetColumnIndex(0);
                    ImGui.Text("Slab  ");
                    ImGui.SameLine();
                    ImGui.Checkbox(imgui_label("##clip_plane", p), *p.is_active);
                    Show_Tooltip("Enable clipping using a distance range from a plane passing through the origin.\nKeep the region bounded by the parallel planes positioned at the range min/max.");
                    ImGui.TableSetColumnIndex(1);
                    ImGui.Text("Normal");
                    ImGui.Text("Range");
                    ImGui.TableSetColumnIndex(2);
                    ImGui.SetNextItemWidth(-FLOAT32_MIN);
                    ImGui.DragFloat3(imgui_label("##normal", *p.normal.component), *p.normal.component, .05, format="%.3f");
                    if almost_equal(length(*p.normal), 0.) p.normal = fallback_normal;
                    range := make_vector2(p.min, p.max);
                    ImGui.SetNextItemWidth(-FLOAT32_MIN);
                    if ImGui.DragFloat2(imgui_label("##range", *p.min), *range.component, .05, format="%.3f") {
                        p.min, p.max = range.x, range.y;
                        p.min = min(p.min, p.max - MIN_RANGE);
                        p.max = max(p.min + MIN_RANGE, p.max);
                    }

                    ImGui.TableSetColumnIndex(3);
                    NEGATIVE_INF :: 0hFF800000;
                    POSITIVE_INF :: 0h7F800000;
                    uninitialized := (p.min == NEGATIVE_INF) || (p.max == POSITIVE_INF);
                    if ImGui.Button(imgui_label("Reset    ", p)) || uninitialized {
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
                    }
                    Show_Tooltip("Reset the range min/max to keep the entire aabb");

                    if ImGui.Button(imgui_label("Normalize", p)) {
                        normal_length := length(p.normal);
                        if normal_length != 0 {
                            p.min /= normal_length;
                            p.max /= normal_length;
                            p.normal /= normal_length;
                        }
                    }
                    Show_Tooltip("Make the normal unit and update the range min/max");
                }

                display_info.aabb_visible = true;

                clip_range_ui(*clip_ranges[0], aabb, .{1, 0, 0});
                clip_range_ui(*clip_ranges[1], aabb, .{0, 1, 0});
                clip_range_ui(*clip_ranges[2], aabb, .{0, 0, 1});
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
    if #complete entity.source.kind == {
        case .Entity_Source_File;
            source := isa(entity.source, Entity_Source_File); assert(source != null); // @CompilerBug Why assert(source) does not work?
            Show_Tooltip(tprint("File:    %\nCreated: %", source.path, filetime_to_readable_date(source.creation_time)));
        case .Entity_Source_Command;
            source := isa(entity.source, Entity_Source_Command); assert(source != null);
            Show_Tooltip(tprint("Command: %\nCreated: %", source.console_command, filetime_to_readable_date(source.creation_time)));
        case .Entity_Source_Preset;
            source := isa(entity.source, Entity_Source_Preset); assert(source != null);
            Show_Tooltip(tprint("Example shape\nCreated: %", filetime_to_readable_date(source.creation_time)));
        case .Entity_Source_Selection;
            source := isa(entity.source, Entity_Source_Selection); assert(source != null);
            Show_Tooltip(tprint("Selection\nCreated: %", filetime_to_readable_date(source.creation_time)));
    }
}

entity_tick_flash_hover :: (entity : *Entity) {
    was_hovered := entity.is_hovered;
    entity.is_hovered = ImGui.IsItemHovered();
    if ImGui.IsItemHovered() {
        entity.display_info.flash_wave_dt += io().DeltaTime;
    } else if was_hovered {
        entity.display_info.flash_wave_dt = 0;
    }
}


pending_directories_sweep_state : Checkbox_Sweep_Mode_State;

// Checkbox sweep mode is enabled while LMB is held down if it was clicked on a sweepable checkbox, the mouse will be constrained to move only up and down and the inverse of the state of the checkbox just before the click will be set on all the checkboxes that get swept
item_list_sweep_state : Checkbox_Sweep_Mode_State;

FADE_TIME_SECS :: 1.;


#scope_export // @CompilerBug without this scope_export the line below errors!
ISSUE_008 :: "Sphere clipping does not work if the Selection item is not visible"; @KnownIssue
ISSUE_009 :: "Sphere clipping does not work on Point Cloud items"; @KnownIssue

// ImGui is immediate mode so we may have already drawn items which we want to change due to a UI interaction we're just drawing now.
// This stuct stores stuff we need to remember to use in the next render frame
ImGui_Frame_State :: struct {
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
