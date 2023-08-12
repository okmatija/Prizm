// nocommittttt Remove the opacity < X% means you can't click the item feature, it sucks in the common case where you have one item and you made it transparent
// nocommittttt Unstash the most recent changes
// nocommit Improve the rendering of the changelog, maybe just with different colors and text wrapping which starts at the indent, then post he pic with the changelog
// nocommit Fix the size of the menu bar buttons for the window
// nocommit Don't hardcode widget size, it needs to depend on the font size
// nocommit Remove the rouding on the window buttons
// nocommit Use drag floats for vertex/line sizes, and switch to rendering with quads

WINDOW_BORDER_UI_OFFSET :: ImGui.ImVec2.{10, 10};
EASY_RESIZE_FRACTION :: .25;
WINDOW_RESIZE_MARGIN_PX :: 3;

// @Cleanup Remove usages of helper functions BeginPopupContextItem when there is a function boundary between the imgui widget which is rmb clicked and the function rendering the UI

init_icons :: () {
    PRISM_ICON_DATA0,     OK0 :: #run read_entire_file("data/icon_blue.png",  zero_terminated=true);  #assert(OK0);
    PRISM_ICON_DATA1,     OK1 :: #run read_entire_file("data/icon_green.png", zero_terminated=true);  #assert(OK1);
    PRISM_ICON_DATA2,     OK2 :: #run read_entire_file("data/icon_red.png",   zero_terminated=true);  #assert(OK2);
    PRISM_ICON_DATA3,     OK3 :: #run read_entire_file("data/icon_black.png", zero_terminated=true);  #assert(OK3);
    PRISM_LOGO_DATA,      OK4 :: #run read_entire_file("data/logo.png",       zero_terminated=true);  #assert(OK4);

    WINDOW_CLOSE_DATA,    OK5 :: #run read_entire_file("data/close.png",      zero_terminated=true);  #assert(OK5);
    WINDOW_MAXIMIZE_DATA, OK6 :: #run read_entire_file("data/maximize.png",   zero_terminated=true);  #assert(OK6);
    WINDOW_MINIMIZE_DATA, OK7 :: #run read_entire_file("data/minimize.png",   zero_terminated=true);  #assert(OK7);
    WINDOW_RESTORE_DATA,  OK8 :: #run read_entire_file("data/restore.png",    zero_terminated=true);  #assert(OK8);

    BACKFACE_DATA,        OK9 :: #run read_entire_file("data/backface.png",    zero_terminated=true); #assert(OK9);
    OPACITY_DATA,         OKa :: #run read_entire_file("data/opacity.png",     zero_terminated=true); #assert(OKa);
    CLIPPING_DATA,        OKb :: #run read_entire_file("data/clipping.png",    zero_terminated=true); #assert(OKb);
    NORMALS_DATA,         OKc :: #run read_entire_file("data/normals.png",     zero_terminated=true); #assert(OKc);
    THICKNESS_DATA,       OKd :: #run read_entire_file("data/thickness.png",   zero_terminated=true); #assert(OKd);
    RADIUS_DATA,          OKe :: #run read_entire_file("data/radius.png",      zero_terminated=true); #assert(OKe);
    INDICES_DATA,         OKf :: #run read_entire_file("data/indices.png",     zero_terminated=true); #assert(OKf);
    COORDINATES_DATA,     OKg :: #run read_entire_file("data/coordinates.png", zero_terminated=true); #assert(OKg);
    ANNOTATIONS_DATA,     OKh :: #run read_entire_file("data/annotations.png", zero_terminated=true); #assert(OKh);

    ok : bool;
    icon_prism_icon_texture[0],   ok = load_texture_from_memory(cast([]u8)PRISM_ICON_DATA0);     assert(ok);
    icon_prism_icon_texture[1],   ok = load_texture_from_memory(cast([]u8)PRISM_ICON_DATA1);     assert(ok);
    icon_prism_icon_texture[2],   ok = load_texture_from_memory(cast([]u8)PRISM_ICON_DATA2);     assert(ok);
    icon_prism_icon_texture[3],   ok = load_texture_from_memory(cast([]u8)PRISM_ICON_DATA3);     assert(ok);
    icon_prism_logo_texture,      ok = load_texture_from_memory(cast([]u8)PRISM_LOGO_DATA);      assert(ok);

    icon_window_close_texture,    ok = load_texture_from_memory(cast([]u8)WINDOW_CLOSE_DATA);    assert(ok);
    icon_window_maximize_texture, ok = load_texture_from_memory(cast([]u8)WINDOW_MAXIMIZE_DATA); assert(ok);
    icon_window_minimize_texture, ok = load_texture_from_memory(cast([]u8)WINDOW_MINIMIZE_DATA); assert(ok);
    icon_window_restore_texture,  ok = load_texture_from_memory(cast([]u8)WINDOW_RESTORE_DATA);  assert(ok);

    icon_backface_texture,    ok = load_texture_from_memory(cast([]u8)BACKFACE_DATA);    assert(ok);
    icon_opacity_texture,     ok = load_texture_from_memory(cast([]u8)OPACITY_DATA);     assert(ok);
    icon_clipping_texture,    ok = load_texture_from_memory(cast([]u8)CLIPPING_DATA);    assert(ok);
    icon_normals_texture,     ok = load_texture_from_memory(cast([]u8)NORMALS_DATA);     assert(ok);
    icon_thickness_texture,   ok = load_texture_from_memory(cast([]u8)THICKNESS_DATA);   assert(ok);
    icon_radius_texture,      ok = load_texture_from_memory(cast([]u8)RADIUS_DATA);      assert(ok);
    icon_indices_texture,     ok = load_texture_from_memory(cast([]u8)INDICES_DATA);     assert(ok);
    icon_coordinates_texture, ok = load_texture_from_memory(cast([]u8)COORDINATES_DATA); assert(ok);
    icon_annotations_texture, ok = load_texture_from_memory(cast([]u8)ANNOTATIONS_DATA); assert(ok);
}

show_menu_bar_ui :: () {
    // Draw a grey border around the entire screen, if we don't do this its hard to see where the application ends
    fg_draw_list : *ImGui.ImDrawList = ImGui.GetForegroundDrawList();
    ImGui.ImDrawList.AddRect(fg_draw_list, ImGui.ImVec2.{}, ImGui.GetMainViewport().Size, ImGui.GetColorU32(ImGui.GetStyle().Colors[ImGui.Col.Border]));

    ImGui.BeginMainMenuBar();
    defer ImGui.EndMainMenuBar();

    // Put a single pixel border around the entire window to frame the application
    ScopedChildBorderTheme(ImGui.GetStyle().Colors[ImGui.Col.Border], 1.);

    {
        icon_size := ImGui.ImVec2.{xx ImGui.GetWindowSize().y, xx ImGui.GetWindowSize().y};
        ImGui.Image(cast(ImGui.ImTextureID)icon_prism_icon_texture[prism_icon_color_index].gl_handle, icon_size);
        click_cycle_prism_color_index();
        if ImGui.IsItemHovered(.DelayNormal) {
            show_tooltip(tprint("Prism %", app.changelog[0].name));
        }
    }

    // sz : float = ImGui.GetTextLineHeight();
    // p : ImGui.ImVec2 = ImGui.GetCursorScreenPos();
    // ImGui.ImDrawList.AddRectFilled(ImGui.GetWindowDrawList(), p, ImGui.ImVec2.{p.x + xx sz, p.y + xx sz}, ImGui.GetColorU32(RED));
    // ImGui.Dummy(ImGui.ImVec2.{xx sz, xx sz});

    if (ImGui.BeginMenu("File")) {
        defer ImGui.EndMenu();

        if ImGui.BeginMenu("Preferences") {
            defer ImGui.EndMenu();
            show_preferences();
        }

        ImGui.Separator();

        if ImGui.MenuItem("Quit", "Alt F4") {
            app.closing_application = true;
        }
    }

    if ImGui.BeginMenu("Edit") {
        defer ImGui.EndMenu();

        if ImGui.MenuItem("Toggle Current Item Selection", "Alt   A") {
            toggle_current_selection();
        }

        if ImGui.MenuItem("Select/Deselect All Items", "Ctrl  A") {
            select_or_deselect_all();
        }

        if ImGui.MenuItem("Select/Deselect Visible Items", "Shift A") {
            select_or_deselect_visible();
        }
        show_tooltip("Also deselects items which are not visible");

        if ImGui.MenuItem("Delete Selected Items", "      Del") {
            remove_entities_if_selected();
        }
    }

    if ImGui.BeginMenu("View") {
        defer ImGui.EndMenu();

        // TODO Have more granular show ui checkboxes
        if ImGui.MenuItem("Show All UI", "Ctrl `", app.show_ui) {
            app.show_ui = !app.show_ui;
        }

        if ImGui.MenuItem("Show Console UI", "     `", app.console.show_ui) {
            app.console.show_ui = !app.console.show_ui;
            if app.console.show_ui {
                app.show_ui = true;
            }
        }

        if ImGui.MenuItem("Show Camera UI", null, app.camera.show_ui) {
            app.camera.show_ui = !app.camera.show_ui;
            if app.camera.show_ui {
                app.show_ui = true;
            }
        }

        if ImGui.MenuItem("Show World Axes", null, app.triad.visible) {
            app.triad.visible = !app.triad.visible;
        }

        if ImGui.MenuItem("Enable Demo Mode", null, app.demo_mode) {
            app.demo_mode = !app.demo_mode;
        }
        show_tooltip("Show Keyboard/Mouse presses in the viewport\nIntended to be useful for screen share/demos\nEarly WIP feature, only mouse supported");

        ImGui.Separator();

        if ImGui.BeginMenu("Window Settings") {
            defer ImGui.EndMenu();

            // Window Size
            {
                // @Volatile :EasyResizeModeKeybind
                tooltip :: () { show_tooltip_binding("(near window border) Resize the window", "Alt LMB", flags=.None); }

                ImGui.Text("Window Size    ");
                tooltip();

                ImGui.SameLine();
                size : [2]s32 = .[app.current_window_width, app.current_window_height];
                ImGui.PushItemWidth(70);
                if ImGui.DragInt2("##WindowSize", *size) {
                    SDL_SetWindowSize(app.window, size[0], size[1]);
                }
                tooltip();
                ImGui.PopItemWidth();

                ImGui.SameLine();
                disable_window_resize_reset := (app.current_window_width == app.INITIAL_WINDOW_WIDTH && app.current_window_height == app.INITIAL_WINDOW_HEIGHT);
                if disable_window_resize_reset ImGui.BeginDisabled();
                if ImGui.Button("Reset##WindowSize") {
                    SDL_SetWindowSize(app.window, app.INITIAL_WINDOW_WIDTH, app.INITIAL_WINDOW_HEIGHT);
                }
                tooltip();
                if disable_window_resize_reset ImGui.EndDisabled();
            }

            // Window Position
            {
                // @Volatile :EasyResizeModeKeybind
                tooltip :: () { show_tooltip_binding("(near window center) Move the window", "Alt LMB", flags=.None); }

                ImGui.Text("Window Position");
                tooltip();

                ImGui.SameLine();
                position : [2]s32;
                SDL_GetWindowPosition(app.window, *position[0], *position[1]);
                ImGui.PushItemWidth(70);
                if ImGui.DragInt2("##WindowPosition", *position) {
                    SDL_SetWindowPosition(app.window, position[0], position[1]);
                }
                tooltip();
                ImGui.PopItemWidth();

                // ImGui.SameLine();
                // if ImGui.Button("Reset##WindowPosition") {
                //     SDL_SetWindowSize(app.window, app.INITIAL_WINDOW_WIDTH, app.INITIAL_WINDOW_HEIGHT);
                // }
                // tooltip();
            }

            // Window Opacity
            {
                // @Volatile :WindowOpacityControl
                tooltip :: () { show_tooltip_binding("Reset window opacity to 1.", "Esc", flags=.None); }

                ImGui.Text("Window Opacity ");
                tooltip(); 
                ImGui.SameLine();

                window_opacity : float;
                SDL_GetWindowOpacity(app.window, *window_opacity);
                ImGui.PushItemWidth(70);
                if ImGui.DragFloat("##WindowOpacity", *window_opacity, .01, 0.2, 1., format="%.2f") {
                    window_opacity = clamp(window_opacity, .2, 1.);
                    SDL_SetWindowOpacity(app.window, window_opacity);
                }
                ImGui.PopItemWidth();
                tooltip(); 
                ImGui.SameLine();

                disable_window_opacity_reset := (window_opacity == 1.);
                if disable_window_opacity_reset ImGui.BeginDisabled();
                if ImGui.Button("Reset##WindowOpacity") {
                    SDL_SetWindowOpacity(app.window, 1);
                }
                if disable_window_opacity_reset ImGui.EndDisabled();
                tooltip(); 
            }

            // TODOO Always on top window
        }
    }

    if ImGui.BeginMenu("Help") {
        defer ImGui.EndMenu();

        if ImGui.BeginMenu("Window Shortcuts") {
            defer ImGui.EndMenu();
            show_window_key_bindings();
        }

        if ImGui.BeginMenu("Camera Shortcuts") {
            defer ImGui.EndMenu();
            show_camera_key_bindings();
        }

        if ImGui.BeginMenu("Items List Shortcuts") {
            defer ImGui.EndMenu();
            show_items_list_key_bindings();
        }

        if ImGui.BeginMenu("Viewport Shortcuts") {
            defer ImGui.EndMenu();
            show_viewport_key_bindings();
        }

        if ImGui.BeginMenu("Miscellaneous Shortcuts") {
            defer ImGui.EndMenu();
            show_miscellaneous_key_bindings();
        }

        ImGui.Separator();

        if ImGui.BeginMenu("Release Notes") {
            defer ImGui.EndMenu();
            show_changelog();
        }

        ImGui.PushStyleColor(xx ImGui.Col.PopupBg, ImGui.GetStyle().Colors[ImGui.Col.MenuBarBg]);
        logo_width := icon_prism_logo_texture.width;
        text_width := ImGui.CalcTextSize("                                                                   ").x;
        window_width := max(1.2 * logo_width, text_width); // nocommit at some padding to the text_width
        ImGui.SetNextWindowContentSize(ImGui.ImVec2.{window_width, 0});
        if ImGui.BeginMenu("About") {
            defer ImGui.EndMenu();

            show_help_about_content();
        }
        ImGui.PopStyleColor();
    }

    {
        icon_size := ImGui.ImVec2.{xx ImGui.GetWindowSize().y * .7, xx ImGui.GetWindowSize().y * .7};

        ImGui.PushStyleColor(xx ImGui.Col.Button, ImGui.ImColor.{0, 0, 0, 0});
        defer ImGui.PopStyleColor();
        ImGui.PushStyleVar(xx ImGui.StyleVar.FrameBorderSize, 0);
        defer ImGui.PopStyleVar();

        {
            ImGui.PushStyleColor(xx ImGui.Col.Button, TRANSPARENT);
            ImGui.PushStyleColor(xx ImGui.Col.ButtonHovered, TRANSPARENT);
            ImGui.PushStyleColor(xx ImGui.Col.ButtonActive, TRANSPARENT);
            defer ImGui.PopStyleColor(3);

            app.window_draggable_rect_min = ImGui.GetCursorScreenPos() + ImGui.ImVec2.{0, WINDOW_RESIZE_MARGIN_PX};

            // Invisible dummy button to figure out where to start putting the minimize, maximize/restore, quit buttons
            button_width := -ImGui.GetCursorScreenPos().x;
            ImGui.ImageButton(cast(ImGui.ImTextureID)icon_window_maximize_texture.gl_handle, icon_size, tint_col=TRANSPARENT);
            button_width +=  ImGui.GetCursorScreenPos().x;
            start_x := ImGui.GetWindowSize().x - 3. * button_width + ImGui.GetStyle().ItemSpacing.x;
            ImGui.SetCursorScreenPos(.{start_x, ImGui.GetCursorScreenPos().y});

            app.window_draggable_rect_max = .{start_x, ImGui.GetWindowSize().y};
            // ImGui.ImDrawList.AddRect(fg_draw_list, app.window_draggable_rect_min, app.window_draggable_rect_max, ImGui.GetColorU32(RED)); // Debug
        }

        {
            ImGui.PushStyleColor(xx ImGui.Col.ButtonHovered, ImGui.GetStyle().Colors[ImGui.Col.HeaderHovered]);
            ImGui.PushStyleColor(xx ImGui.Col.ButtonActive, ImGui.GetStyle().Colors[ImGui.Col.HeaderActive]);
            defer ImGui.PopStyleColor(2);

            if ImGui.ImageButton("##MinimizeButton", cast(ImGui.ImTextureID)icon_window_minimize_texture.gl_handle, icon_size, tint_col=BLACK) {
                SDL_MinimizeWindow(app.window);
            }

            if app.window_maximized {
                if ImGui.ImageButton("##RestoreButton", cast(ImGui.ImTextureID)icon_window_restore_texture.gl_handle, icon_size, tint_col=BLACK) {
                    SDL_RestoreWindow(app.window);
                }
            } else {
                if ImGui.ImageButton("##MaximizeButton", cast(ImGui.ImTextureID)icon_window_maximize_texture.gl_handle, icon_size, tint_col=BLACK) {
                    SDL_MaximizeWindow(app.window);
                }
            }
        }

        {
            ImGui.PushStyleColor(xx ImGui.Col.ButtonHovered, ImGui.ImColor.{250./255, 66./255, 66./255, 1});
            ImGui.PushStyleColor(xx ImGui.Col.ButtonActive, RED);
            defer ImGui.PopStyleColor(2);

            if ImGui.ImageButton("##QuitButton", cast(ImGui.ImTextureID)icon_window_close_texture.gl_handle, icon_size, tint_col=BLACK) {
                quit_application();
            }
        }
    }
}

// @Refactor This function is too long (especially the top level for loop). Break it up.
show_left_window :: () {

    // Set window border color to match the selection/RMB target item color
    // original_border_color, original_border_size := ScopedWindowBorderTheme(app.theme.item_list_border_color, app.theme.item_list_border_size);

    ImGui.PushStyleVar(xx ImGui.StyleVar.IndentSpacing, 8);
    defer ImGui.PopStyleVar();

    ImGui.SetNextWindowPos(ImGui.GetMainViewport().WorkPos + WINDOW_BORDER_UI_OFFSET);
    ImGui.Begin("Main Panel", flags = ImGui.WindowFlags.AlwaysAutoResize | .NoTitleBar);
    defer ImGui.End();

    // ScopedWindowBorderTheme(original_border_color, original_border_size);

    // ImGui.ColorEdit4("debug_color", *app.debug_color.component, ImGui.ColorEditFlags.NoInputs);
    show_tools_ui();
    show_items_ui();
    show_details_ui();
}

show_right_window :: () {
    if !app.camera.show_ui {
        return;
    }

    window_pos := ImGui.ImVec2.{
        ImGui.GetMainViewport().WorkSize.x - WINDOW_BORDER_UI_OFFSET.x,
        ImGui.GetMainViewport().WorkPos.y  + WINDOW_BORDER_UI_OFFSET.y};
    window_pivot := ImGui.ImVec2.{1, 0};

    using ImGui.WindowFlags;

    ImGui.PushStyleColor(xx ImGui.Col.Border, app.theme.camera_ui_button_border_color);
    defer ImGui.PopStyleColor();

    // Set window border color to match the selection/RMB target item color
    // original_border_color, original_border_size := ScopedWindowBorderTheme(app.theme.camera_ui_border_color, app.theme.camera_ui_border_size);

    ImGui.SetNextWindowPos(window_pos, .Always, window_pivot);
    ImGui.Begin("Camera shortcuts", flags = NoTitleBar | AlwaysAutoResize | NoMove /*| NoNav*/);
    defer ImGui.End();

    // ScopedWindowBorderTheme(original_border_color, original_border_size);

    show_camera_controls();
}

show_item_list_actions_ui :: () {
    if app.console.show_ui {
        return;
    }

    window_pivot := ImGui.ImVec2.{0, 1}; // SetNextWindowPos will refer to the bottom left corner of the window

    button_count := 9;
    button_width := ACTION_BUTTON_SIZE.x + 2 * ImGui.GetStyle().FramePadding.x;
    buttons_space := (button_count - 1) * ImGui.GetStyle().ItemSpacing.x;  
    buttons_width := button_count * button_width + buttons_space + 2 * ImGui.GetStyle().WindowPadding.x;

    ImGui.SetNextWindowPos(ImGui.ImVec2.{(app.current_window_width - buttons_width)/2, xx app.current_window_height}, pivot=window_pivot);
    // ImGui.SetNextWindowSize(ImGui.ImVec2.{xx app.current_window_width, -1}, .Always); // Full width of OS window, we DONT do this.
    ImGui.SetNextWindowSize(ImGui.ImVec2.{-1, -1}, .Always); // Just wide enough to fit all the buttons---better since mouse can interact with viewport where there are no buttons

    window_flags := ImGui.WindowFlags.NoTitleBar | .NoResize | .NoDecoration;
    window_flags |= .NoBringToFrontOnFocus; // Prioritize drawing item list if it covers the console
    window_flags |= .NoFocusOnAppearing;    // So we dont clobber the reclaim_focus stuff in the console input window
    window_flags |= .NoBackground;          // Makes the console log transparent

    ImGui.Begin("target_items_ribbon", flags=window_flags);
    defer ImGui.End();

    ActionButton(icon_backface_texture,    *CYCLE_BACKFACE_MODE_ACTION_SET); ImGui.SameLine();
    ActionButton(icon_opacity_texture,     *CYCLE_OPACITY_ACTION_SET);       ImGui.SameLine();
    ActionButton(icon_clipping_texture,    *TOGGLE_CLIPPING_ACTION_SET);     ImGui.SameLine();
    ActionButton(icon_normals_texture,     *TOGGLE_NORMALS_ACTION_SET);      ImGui.SameLine();
    ActionButton(icon_thickness_texture,   *CYCLE_LINE_WIDTH_ACTION_SET);    ImGui.SameLine();
    ActionButton(icon_radius_texture,      *CYCLE_VERTEX_SIZE_ACTION_SET);   ImGui.SameLine();
    ActionButton(icon_indices_texture,     *CYCLE_ELEMENT_LABEL_ACTION_SET); ImGui.SameLine();
    ActionButton(icon_coordinates_texture, *CYCLE_VERTEX_LABEL_ACTION_SET);  ImGui.SameLine();
    ActionButton(icon_annotations_texture, *CYCLE_ANNOTATION_ACTION_SET);
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

    ImGui.SetNextWindowPos(ImGui.ImVec2.{app.current_window_width / 2., app.current_window_height / 2.}, pivot=.{.5, .5}, cond=.ImGuiCond_Appearing);
    // ImGui.SetNextWindowSizeConstraints(ImGui.ImVec2.{app.current_window_width * .6, app.current_window_height * .75},
    //                                    ImGui.ImVec2.{app.current_window_width * .6, app.current_window_height * .75});
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

    // outer_size := ImGui.ImVec2.{0, min(cast(float)(FONT_SIZE * dir.loadable_files.count), 200});
    outer_size := ImGui.ImVec2.{0, 400};
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
            show_tooltip(message);
        }
    }

    if dir.unloadable_file_count {
        ImGui.Text(tprint("Found % files without loadable extension (obj)", dir.unloadable_file_count));
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
                entities := load_one_file(file.fully_pathed_filename, .IGNORE);
                for entity : entities {
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
    show_tooltip("Load all selected/checked files");

    ImGui.SameLine();

    if ImGui.Button(imgui_label("Ignore", xx *dir)) {
        deinit(dir);
        app.pending_directories.count -= 1; // We were handling the last directory, so can just decrement the array count
    }
    show_tooltip("Do not load any files");

    ImGui.SameLine();

    if app.pending_directories.count > 1 {
        if ImGui.Button(imgui_label("Ignore All", xx *dir)) {
            for *dir : app.pending_directories {
                deinit(dir);
            }
            array_reset(*app.pending_directories);
        }
        show_tooltip(tprint("Do not load any files from all % pending directories", app.pending_directories.count));
    }
}


show_imgui_demo_window :: () {
    if app.settings.show_imgui_demo_window {
        ImGui.ShowDemoWindow(*app.settings.show_imgui_demo_window);
    }
}

ISSUE_008 :: "Sphere clipping does not work if the Selection item is not visible"; @KnownIssue
ISSUE_009 :: "Sphere clipping does not work on Point Cloud items"; @KnownIssue



//
// ImGui data needed between frames. @Think There must be a better way to do this...
//

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




//
// Textures and icon stuff
//

prism_icon_color_index := 0;

// @Volatile Sync with :PRISM_ICON_COLORS
PRISM_ICON_COLORS :: Named_Color.[
    .{.{102./255, 153./255, 1, 1}, "blue"},
    .{.{102./255, 153./255, 0, 1}, "green"},
    .{.{204./255, 0, 0, 1}, "red"},
    .{BLACK, "black"},
];

// TODOO Set these at compile-time to make runtime startup as fast as possible, maybe set them at runtime in debug?
icon_prism_icon_texture : [PRISM_ICON_COLORS.count]Texture;
icon_prism_logo_texture : Texture;

icon_window_close_texture : Texture;
icon_window_minimize_texture : Texture;
icon_window_maximize_texture : Texture;
icon_window_restore_texture : Texture;

icon_backface_texture : Texture;
icon_opacity_texture : Texture;
icon_clipping_texture : Texture;
icon_normals_texture : Texture;
icon_thickness_texture : Texture;
icon_radius_texture : Texture;
icon_indices_texture : Texture;
icon_coordinates_texture : Texture;
icon_annotations_texture : Texture;

#scope_file

ACTION_BUTTON_SIZE :: ImGui.ImVec2.{30, 30};

show_tools_ui :: () {
    // Trailing space makes it look nicer
    do_tree := ImGui.TreeNodeEx("Tools ", .SpanAvailWidth | .Framed);
    if do_tree {
        defer ImGui.TreePop();
        show_api_ui();
        show_create_tool_ui();
        show_select_tool_ui();
    }
}

show_items_ui :: () {
    entity_to_remove := -1;
    any_visibility_changed : bool;

    // Trailing space makes it look nicer @Cleanup Make this plural properly
    if ImGui.TreeNodeEx("Items ", .SpanAvailWidth | .DefaultOpen | .Framed) {
        defer ImGui.TreePop();

        for *folder : app.directories {

            Local_Entity :: struct {
                entity : *Entity;
                global_index : int;
            }

            // The list clipper works on lots of evenly spaced items, which means we need to group entities by folder before we use it
            entities_in_folder : [..]Local_Entity;
            entities_in_folder.allocator = temp;
            for :All entity, entity_index : app.entities {
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
                    table_flags := ImGui.TableFlags
                        //.RowBg |
                        //.BordersOuter |
                        .PadOuterX |
                        .NoBordersInBody |
                        .ScrollY;
                    outer_size :=  ImGui.ImVec2.{0, app.settings.item_list_max_size_before_scroll_px};

                    show_scrollbar := folder.last_frame_item_list_height_px >= outer_size.y;
                    if !show_scrollbar {
                        table_flags &= ~.ScrollY;
                        outer_size.y = 0; // Not really necessary, since its ignored unless flags include ScrollY
                    }

                    // // IIRC this is to get the table to fill the whole UI pane, but its only really needed when we have RowBg on
                    //ImGui.PushItemWidth(ImGui.GetFontSize() * -12);
                    //defer ImGui.PopItemWidth();

                    ScopeZeroCellPaddingY();

                    // @Hack Include an extra empty padding column so the filename is not trucated when we use a scrolling region
                    if ImGui.BeginTable(imgui_label("Item List Table", xx folder), 5, flags=table_flags, outer_size=outer_size) {
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

        selected : [..]*Entity = temp_selected_entities();
        ImGui.Text("% item% (% selected)", app.entities.count, ifx app.entities.count > 1 then "s" else "", selected.count);
        bindings : [..]Binding_With_Description = temp_array(Binding_With_Description);
        // @Volatile Sync with :SelectionKeybindTooltip
        array_add(*bindings, make_Binding_With_Description(to_string(#char "a", .{control_pressed=true}), "Select/deselect all items"));
        array_add(*bindings, make_Binding_With_Description(to_string(#char "a", .{shift_pressed=true}), "Select/deselect visible items"));
        array_add(*bindings, make_Binding_With_Description(to_string(#char "a", .{alt_pressed=true}), "Toggle current item selection"));
        array_add(*bindings, make_Binding_With_Description(to_string(#char "`", .{}), "Use the 'select_...' console commands"));
        show_tooltip_binding(..bindings, "Summary of ways to select items:");

    } // end TreeNodeEx

    // This block implements the feature where if you toggle visibility, editing colors and cycling/resetting display modes on a selected item it changes it on all selected items
    // This is similar to how editing the context menu of an item selection changes the corresponding field in all selected items
    {
        if g_this_frame_state.index_of_selected_item_where_color_was_changed != -1 {
            source : *Entity = app.entities[g_this_frame_state.index_of_selected_item_where_color_was_changed];
            for :Selected app.entities {
                it_primary_color : *Vector4 = get_entity_primary_color(it);
                source_primary_color : *Vector4 = get_entity_primary_color(source);
                if it_primary_color && source_primary_color {
                    it_primary_color.* = source_primary_color.*;
                }
            }
        }
        if g_this_frame_state.index_of_selected_item_where_mode_was_cycled != -1 {
            source : *Entity = app.entities[g_this_frame_state.index_of_selected_item_where_mode_was_cycled];
            for :Selected app.entities {
                it.display_info.triangle_style.display_mode = source.display_info.triangle_style.display_mode;
            }
        }
        if g_this_frame_state.index_of_selected_item_where_color_was_reset != -1 {
            for :Selected app.entities {
                it.display_info.triangle_style.display_mode = Display_Info.{}.triangle_style.display_mode;
                set_entity_primary_color(it);
            }
        }
        if g_this_frame_state.index_of_selected_item_where_visibility_changed_by_click != -1 {
            source : *Entity =app.entities[g_this_frame_state.index_of_selected_item_where_visibility_changed_by_click];
            for :Selected app.entities {
                it.display_info.is_visible = source.display_info.is_visible;
            }
        }
    }

    remove_entity_by_index(entity_to_remove);

    if any_visibility_changed {
        // See :PreserveCameraPositionWithNoVisibleItems, we want to keep that behaviour here too
        if app.settings.fit_to_screen_on_visibility_change {
            fit_scene_on_screen();
        } else {
            look_sphere := entities_world_bounding_radius(visit_visible, app.camera.look_position);
            prev_camera := app.camera;
            fit_sphere_on_screen(look_sphere);
            new_near := app.camera.near;
            new_far  := app.camera.far;
            new_eye  := app.camera.eye_position;

            // Adjust to fit newly visible items
            app.camera = prev_camera;
            app.camera.near = new_near;
            app.camera.far  = new_far;
            app.camera.eye_position = new_eye;
        }
    }
}


Item_Entry_Update :: struct {
    visibility_changed := false;
    entity_to_remove := -1;
}

show_item_list_entry :: (entity : *Entity, entity_index : int, hack_pad_last_column_to_fix_truncation : bool) -> Item_Entry_Update {
    result : Item_Entry_Update;

    ////    const ImU32 col = GetColorU32((held && hovered) ? ImGuiCol_HeaderActive : hovered ? ImGuiCol_HeaderHovered : ImGuiCol_Header);
    //header_color := ImGui.GetStyle().Colors[ImGui.Col.Header];
    //header_active := ImGui.GetStyle().Colors[ImGui.Col.HeaderActive];
    // col := ImGui.GetColorU32(ImGui.GetStyle().Colors[ImGui.Col.Header]);

    // Toggle visibility checkbox
    ImGui.TableNextColumn();
    // if entity.is_selected ImGui.TableSetBgColor(.CellBg, col);
    {
        was_visible := entity.display_info.is_visible;
        visibility_changed, changed_by_click := checkbox_press_or_sweep_to_toggle(*entity.display_info.is_visible, imgui_label("##Visible", entity), *item_list_sweep_state, app.window);
        result.visibility_changed = visibility_changed;
        show_tooltip("Visible");

        if !was_visible && entity.display_info.is_visible {
            // @Think We should probably have some kind of function list/hook/delegate feature so we can add code to be executed when visibility changes etc
            // Make sure we see something when turning on visibility. We don't consider normals here since there might not be any, or they might have zero length
            color, element_visibility := get_entity_primary_color(entity);
            if element_visibility {
                element_visibility.* = true;
            }
        }

        if entity.is_selected {
            if changed_by_click {
                g_next_frame_state.index_of_selected_item_where_visibility_changed_by_click = entity_index;
            }
        }
    }

    // Color selection
    ImGui.TableNextColumn();
    {
        color_changed := false; // Edited by widget
        color_reset :=   false; // Reset with MMB
        mode_cycled :=   false; // Cycled with RMB

        if entity.display_info.triangle_style.display_mode == .NORMALS {
            ImGui.TextDisabled("NR."); // @Design Replace this with a image with a normal gradient
        } else {
            color : *Vector4 = get_entity_primary_color(entity);
            if color {
                // ImGui.PushStyleColor(ImGui.Col.FrameBg, ImGui.ImVec4.{1,1,1,0});
                ImGui.PushStyleVar(ImGui.StyleVar.FrameBorderSize, 0);
                color_changed = ImGui.ColorEdit4(imgui_label("##color", entity), *color.component, ImGui.ColorEditFlags.NoInputs);
                ImGui.PopStyleVar();
                // ImGui.PopStyleColor();
            }
        }
        if ImGui.IsItemClicked(.Middle) {
            entity.display_info.triangle_style.display_mode = Display_Info.{}.triangle_style.display_mode; // Reset to default
            set_entity_primary_color(entity);
            color_reset = true;
        }
        if ImGui.IsItemClicked(.Right) {
            cycle_display_mode(*entity.display_info.triangle_style.display_mode);
            mode_cycled = true;
        }

        if entity.is_selected {
            if color_changed g_next_frame_state.index_of_selected_item_where_color_was_changed = entity_index;
            if color_reset   g_next_frame_state.index_of_selected_item_where_color_was_reset =   entity_index;
            if mode_cycled   g_next_frame_state.index_of_selected_item_where_mode_was_cycled =    entity_index;
        }
    }

    // Entity index used to refer to geometry in console or annotate the text following ther cursor when adding to the user selection
    ImGui.TableNextColumn();
    {
        ImGui.Text("#%", entity_index);
        show_tooltip("Entity index for console commands");
    }

    // Entity name
    ImGui.TableNextColumn();
    {
        // ImGui.SetNextItemWidth(-FLOAT32_MIN);
        {
            text : string = tprint("%1%2", entity_description(entity, with_creation_time=false), ifx is_changed_on_disk(entity) then "*" else "");
            label : *u8 =   imgui_label(text, entity);

            // Note that the ImGui.Selectable widget has this line to set the colors:
            //    const ImU32 col = GetColorU32((held && hovered) ? ImGuiCol_HeaderActive : hovered ? ImGuiCol_HeaderHovered : ImGuiCol_Header);

            // Use the default Selectable widget
            if ImGui.Selectable(label, *entity.is_selected, flags=ImGui.SelectableFlags.SpanAllColumns | .AllowItemOverlap) {
                if io_mouse_right_down() {
                    entity.is_selected = !entity.is_selected; // @Hack to undo the selection change we get with RMB, but I'm not sure why this was even happening..!
                } else if !io().KeyCtrl {
                    for :Selected app.entities if it != entity {
                        it.is_selected = false;
                    }
                    entity.is_selected = true;
                }
            }
        }

        entity_tick_flash_hover(entity);

        header_annotation : *Annotation = entity_header_annotation(entity);
        if app.settings.show_header_annotation_tooltips && header_annotation {
            show_tooltip(to_string(header_annotation));
        }
    }

    // Must remove with delete
    //// Remove button
    //ImGui.TableNextColumn();
    //if ImGui.Button(imgui_label("Remove", entity)) {
    //    result.entity_to_remove = entity_index;
    //}

    // Turned on only while context menu > clipping is on. See :RenderingSelectionAABB
    entity.display_info.aabb_visible = false;
    app.template_display_info.aabb_visible = false;

    // @Hack Write empty padding column so filename is not truncated
    ImGui.TableNextColumn();
    if hack_pad_last_column_to_fix_truncation {
        ImGui.Text("  ");
    }

    return result;
} // end show_item_list_entry()



show_create_tool_ui :: () {

    do_tree := ImGui.TreeNodeEx("Create", ImGui.TreeNodeFlags.SpanAvailWidth);
    show_tooltip("Create preset shapes\nSome function as tutorials");
    if do_tree {
        defer ImGui.TreePop();

        BoxSection();

        ImGui.TableNextColumn();
        if ImGui.Button("Cube    ") { add_preset_cube(); }
        ImGui.SameLine();
        ImGui.Text("A basic cube. Hold Alt to fix position");

        ImGui.TableNextColumn();
        if ImGui.Button("Widget  ") { add_preset_widget(); }
        ImGui.SameLine();
        ImGui.Text("A mesh generated from a CAD file");

        ImGui.TableNextColumn();
        if ImGui.Button("BooleanA") { add_preset_boolean_a(); }
        ImGui.SameLine();
        ImGui.Text("A failed mesh boolean");

        ImGui.TableNextColumn();
        if ImGui.Button("BooleanB") { add_preset_boolean_b(); }
        ImGui.SameLine();
        ImGui.Text("A failed cylinder/cone mesh boolean");
    }
}

show_preferences :: () {
    item_width :: 100;

    if ImGui.BeginMenu("UI/UX##Preferences>UI") {
        defer ImGui.EndMenu();

        ImGui.PushItemWidth(item_width);
        defer ImGui.PopItemWidth();

        // nocommit Limit the width of widgets here

        if combo_box("Theme", *app.theme.theme, type_info(Prism_Color_Theme)) {
            set_prism_theme(app.theme.theme);
        }

        ImGui.DragFloat("UI Scale", *io().FontGlobalScale, .001, format="%.3f");

        {
            combo_box("Background", *app.background_style, type_info(app.Background_Style));
            if app.background_style == .SOLID_COLOR {
                ImGui.ColorEdit4("Background Color", *app.background_solid_color.component, ImGui.ColorEditFlags.NoInputs);
            }

            // nocommit Add a shader period thing
        }

        {
            // TODO This (maybe!) interacts in an annoying way with keyboard shortcuts, fix that before enabling by default
            use_keyboard : bool;
            if ImGui.GetIO().ConfigFlags_ & ImGui.ConfigFlags.NavEnableKeyboard {
                use_keyboard = true;
            } else {
                use_keyboard = false;
            }
            ImGui.Checkbox("Enable Keyboard Navigation", *use_keyboard);
            if use_keyboard {
                ImGui.GetIO().ConfigFlags_ |= .NavEnableKeyboard;
            } else {
                ImGui.GetIO().ConfigFlags_ &= ~.NavEnableKeyboard;
            }
        }

        {
            radius_max_px : float = max(cast(float)app.current_window_width, cast(float)app.current_window_height);
            radius_px := cast(float) app.settings.closest_point_query_max_dist_px;
            ImGui.DragFloat("CP Query Radius (px)", *radius_px, 1, 25, radius_max_px, format="%.0f");
            show_tooltip(tprint(#string DONE
CP Query Radius in pixels, this affects:
- Selection of items and elements
- Clipping sphere center seeding
- Label visibility in % labelling mode
DONE, Labelling_Mode.RAY_CAST));
            app.settings.closest_point_query_max_dist_px = cast(int) radius_px;
        }
    }

    // @Incompletee Add this
    //if ImGui.BeginMenu("Camera") {
    //    defer ImGui.EndMenu();
    //}

    if ImGui.BeginMenu("Labelling") {
        defer ImGui.EndMenu();

        ImGui.PushItemWidth(item_width);
        defer ImGui.PopItemWidth();

        combo_box("Labelling Mode", *app.settings.labelling_mode, type_info(Labelling_Mode));
        show_tooltip(tprint(#string DONE
%: Show labels at the intersection/closest point of a camera ray query
%: Show labels within some distance of the cursor location
DONE, Labelling_Mode.RAY_CAST, Labelling_Mode.SPOTLIGHT));

        combo_box("Ray Cast Label Location", *app.label_format.location, type_info(app.Label_Format.Location));

        {
            // @Cleanupp Replace with DragInt
            radius_max_px : float = max(cast(float)app.current_window_width, cast(float)app.current_window_height);
            radius_px := cast(float) app.settings.labelling_radius_px;
            ImGui.DragFloat("Spotlight Radius (px)", *radius_px, 1, 25, radius_max_px, format="%.0f");
            show_tooltip(tprint("Label visibility radius in pixels for % labelling mode", Labelling_Mode.SPOTLIGHT));
            app.settings.labelling_radius_px = cast(int) radius_px;
        }

        format_float_ui(*app.label_format.format_float);
        format_struct_ui(*app.label_format.format_struct);
    }

    // @Think Maybe we should get rid of the console options button?
    if ImGui.BeginMenu("Console") {
        defer ImGui.EndMenu();

        ImGui.PushItemWidth(item_width);
        defer ImGui.PopItemWidth();

        combo_box("Log Mode", *app.console.log_mode, type_info(type_of(app.console.log_mode)));
        show_tooltip(#string DONE
Transparent mode: log window ignores mouse input so you can interact with the scene while reading the log
Interactive mode: log window captures mouse input so you can scroll through log messages
DONE);
        ImGui.Checkbox("Scroll to bottom", *app.console.scroll_to_bottom);
    }

    if ImGui.BeginMenu("Item List") {
        defer ImGui.EndMenu();

        // Invalid point widget looks bad with this
        //ImGui.PushItemWidth(item_width);
        //defer ImGui.PopItemWidth();

        ImGui.DragFloat3(imgui_label("Invalid Point", *app.invalid_point), *app.invalid_point.component, .05, format="%.3f");
        show_tooltip("Used to handle invalid .obj files:\nInvalid `f` directive references (missing points) use this position\nInvalid point components (inf/nan) get the corresponding component value");
        ImGui.Checkbox(imgui_label(tprint("Disable reload via % when file unchanged", to_string(RELOAD_ITEMS_ACTION_SET.key, pad_unmodified=false))), *app.settings.disable_reload_key_if_file_unchanged);
        ImGui.Checkbox("Show Header Annotation Tooltips", *app.settings.show_header_annotation_tooltips);
        ImGui.Checkbox("Item Details Section Uses Menus", *app.settings.item_details_uses_menu);
    }

    if ImGui.BeginMenu("Advanced") {
        defer ImGui.EndMenu();

        ImGui.PushItemWidth(item_width);
        defer ImGui.PopItemWidth();

        // :UserConfig add a button to overwrite the user settings file with new defaults here?
        inspect("Advanced##Impl", *app.settings);
        clamp_user_settings();
    }
}

// If entity == null then show the details for the template
show_details_ui :: () {

    selected : [..]*Entity = temp_selected_entities();
    if selected.count == 0 {
        return;
    }
    
    selected_index : int = -1;
    tooltip : string;
    if selected.count == 1 {
        selected_index = get_entity_index(selected[0]);
        tooltip = tprint("Displaying state for item #%.", selected_index);
    } else {
        tooltip = tprint("Displaying a template state.\nAny edits will be applied to % selected item%.", selected.count, plural_suffix(selected.count > 1));
    }

    // Trailing space looks better when its shut
    do_tree := ImGui.TreeNodeEx("Details ", ImGui.TreeNodeFlags.SpanAvailWidth | .Framed);
    show_tooltip(tooltip);
    if do_tree {
        defer ImGui.TreePop();

        if selected.count == 1 {
            show_details_pane_ui_for_item(selected[0], selected_index);
        } else {
            show_details_pane_ui_for_item_selection();
        }
    }
}

begin_item_details_section :: (label : *u8) -> bool {
    if app.settings.item_details_uses_menu {
        return ImGui.BeginMenu(label);
    }
    return ImGui.TreeNodeEx(label, ImGui.TreeNodeFlags.SpanAvailWidth);
}

end_item_details_section :: () {
    if app.settings.item_details_uses_menu {
        ImGui.EndMenu();
    } else {
        ImGui.TreePop();
    }
}

show_details_pane_ui_for_item :: (using entity : *Entity, entity_index : int) {
    if ImGui.BeginTabBar("##DetailsTabBar", flags=ImGui.TabBarFlags.None) {
        defer ImGui.EndTabBar();

        if ImGui.BeginTabItem("Display") {
            defer ImGui.EndTabItem();

            // This will just show one item
            show_item_selection_ui();

            display_information(entity);
            display_transform(entity);

            maybe_update_render_info(*entity.render_info, *entity.mesh);

            aabb_world := transform_axis_box3(entity.mesh.world_from_model, entity.render_info.bounding_aabb);
            display_info_ui(*entity.display_info, aabb_world, entity_index);
        }

        if ImGui.BeginTabItem("Annotations") {
            defer ImGui.EndTabItem();

            display_annotations(entity, entity_index);
        }

        // FIXME Enable attributes when they are working properly
        #if false {
        for base_attribute : entity.mesh.attributes {
            if ImGui.BeginTabItem(imgui_label(base_attribute.name, base_attribute)) {
                defer ImGui.EndTabItem();

                display_attribute(entity, entity_index, base_attribute);
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

            show_item_selection_ui();

            // @Incomplete We should show the selection information here, helpful e.g., to select all items and know if there are any segment elements in the selection

            app.template_aabb_world = entity_selection_aabb();
            update := display_info_ui(*app.template_display_info, app.template_aabb_world);
            for :Selected app.entities {
               apply_update(update, app.template_display_info, *it.display_info);
            }
        }
    }
}

show_item_selection_ui :: () {

    if begin_item_details_section("Selection") {
        defer end_item_details_section();
        if !app.settings.item_details_uses_menu begin_box_section();
        defer if !app.settings.item_details_uses_menu end_box_section();

        for :Selected entity : app.entities {

            ImGui.TableNextColumn();
            if entity_name(entity).count {

                // @Volatile :FocusItemBehavior Sync with focus items shortcut
                if ImGui.Button(imgui_label("Focus ", entity)) {
                    almost_equal :: (a : Camera, b : Camera) -> bool {
                        return
                            almost_equal(a.eye_position, b.eye_position) &&
                            almost_equal(a.look_position, b.look_position) &&
                            almost_equal(a.up_direction, b.up_direction) &&
                            almost_equal(a.left, b.left) &&
                            almost_equal(a.right, b.right) &&
                            almost_equal(a.bottom, b.bottom) &&
                            almost_equal(a.top, b.top) &&
                            almost_equal(a.near, b.near) &&
                            almost_equal(a.far, b.far);
                    }

                    prev_camera := app.camera;

                    fit_on_screen(entity);

                    // Not a exactly equal check becuase I think there is a feedback mechanism when the camera is computed from the sphere where we essentially have an operation like `camera = f(sphere, camera)` which with the "same" inputs the camera would change a bit FIXME There is still some bug here: load a lot of items and select all of them, the fit_on_screen and fit_on_screen_filled should give the same results but they are slightly different
                    if almost_equal(app.camera, prev_camera) {
                        fit_on_screen_filled(entity);
                    }
                }
                // nocommit Fix the padding in the tooltip for the Focus button
                show_tooltip_binding(FOCUS_ITEMS_ACTION_SET.desc, to_string(FOCUS_ITEMS_ACTION_SET.key));

                ImGui.SameLine();
                source : *Entity_Source_File = isa(entity.source, Entity_Source_File);
                if source {
                    ImGui.Checkbox(imgui_label("", entity), *source.auto_reload);
                    show_tooltip("Auto-reload if file changes on disk");
                } else {
                    dummy := true;
                    ImGui.Checkbox(imgui_label("", entity), *dummy);
                    show_tooltip(tprint("Auto-reload only makes sense for files loaded from disk.\nThis entity was sourced from a %", get_entity_source_description(entity)));
                }

                ImGui.SameLine();
                ImGui.Text("#%", it_index);
                show_tooltip("Entity index for console commands");

                ImGui.SameLine();
                text := entity_description(entity, with_creation_time=true);
                ImGui.TextUnformatted(text);
                entity_source_tooltip(entity);
            }
        }

        // Show these buttons for a single item as well
        {
            if ImGui.Button("Reload") {
                for :Selected entity : app.entities {
                    reload_entity(entity, triggered_by_button=true);
                }
            }
            // nocommit Fix the padding in the tooltip for the Reload button
            show_tooltip_binding(RELOAD_ITEMS_ACTION_SET.desc, to_string(RELOAD_ITEMS_ACTION_SET.key));
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
            show_tooltip("Toggle auto-reload state on selected items");
        }
    }
}

show_api_ui :: () {
    do_tree := ImGui.TreeNodeEx("API", ImGui.TreeNodeFlags.SpanAvailWidth);
    show_tooltip("Tools to interface between Prism and your program");
    if do_tree {
        defer ImGui.TreePop();

        // BoxSection(); // @FIXME ImGui bug?

        show_cpp_api_ui();
        show_python_api_ui();
    }
}

show_cpp_api_ui :: () {
    do_tree := ImGui.TreeNodeEx("C++", ImGui.TreeNodeFlags.SpanAvailWidth | .DefaultOpen);
    show_tooltip("Tools to interface between Prism and your C++ program");
    if do_tree {
        defer ImGui.TreePop();

        ImGui.Checkbox("Using Unreal", *app.api.using_unreal);
        show_tooltip("You can turn this off if you're working in project\noutside Unreal. The only dependency will be C++ STL\nheaders, in future we will try to eliminate this");

        if !app.api.using_unreal ImGui.BeginDisabled();
        ImGui.Checkbox("Using Unreal GeometryCore", *app.api.using_unreal_geometrycore);
        show_tooltip("You can turn this off if you're working in a module\nwhich doesn't include the GeometryCore module");
        if !app.api.using_unreal ImGui.EndDisabled();

        exe_directory := get_directory(get_path_of_running_executable());

        // Warning! Do not change this code without THOROUGH testing! e.g., Prism_Unreal.h is mutually exclusive with Prism.h!
        include : string;
        if app.api.using_unreal && app.api.using_unreal_geometrycore {
            include = tprint("%\n%\n%",
                "// See Prism::documentation()",
                "// See Prism::DocumentationForUnreal()",
                tprint("#include \"%/api/cpp/Prism_Unreal.h\"", exe_directory));
        } else if app.api.using_unreal {
            include = tprint("%\n%\n%\n%",
                "// See Prism::documentation()",
                "// See Prism::DocumentationForUnreal()",
                "#define PRISM_UNREAL_API_EXCLUDE_GEOMETRYCORE",
                tprint("#include \"%/api/cpp/Prism_Unreal.h\"", exe_directory));
        } else {
            include = tprint("%\n%",
                "// See Prism::documentation()",
                tprint("#include \"%/api/cpp/Prism.h\"", exe_directory));
        }
        path_overwrite_separators(include, #char "/");

        if ImGui.Button("Copy #include API") {
            SDL_SetClipboardText(temp_c_string(include));
        }

        show_tooltip(tprint("%\n%", #string DONE
This button copies the Prism C++ API #include line(s) to your clipboard.
You can paste it into your program and use it to write .obj files.
Having a debug API separate from your project source like this should
mean your CI system will catch forgotten/leftover debug code.
The copied string will be:
DONE, include)); 
    }
}

show_python_api_ui :: () {
    do_tree := ImGui.TreeNodeEx("Python", ImGui.TreeNodeFlags.SpanAvailWidth);
    show_tooltip("Tools to interface between Prism and your python program");
    if do_tree {
        defer ImGui.TreePop();

        ImGui.Text("This is incomplete");
    }
}

show_select_tool_ui :: () {
    // TODO Could add options to the select tool
    // - Should we copy over annotations/attributes?
    // - Should we prefix annotations with the item index of the source?
    // Latter is a way of adding the source entity to the elements in the selection

    using app.select_tool;

    do_tree := ImGui.TreeNodeEx("Select", ImGui.TreeNodeFlags.SpanAvailWidth);
    show_tooltip("Create items from mesh geometry selections");
    if do_tree {
        defer ImGui.TreePop();

        entity.display_info.is_visible = true;

        select_element :: (
            element_name : string,
            element_kind : Simple_Mesh_Element,
            tooltip : string,
            element_color : *Vector4,
            label_color : *Vector4,
            elements_visible : *bool) {

            using app.select_tool;

            ImGui.TableNextRow();

            // Element kind radio button
            ImGui.TableNextColumn();
            ImGui.RadioButton(imgui_label(tprint("%##element_kind", element_name), element_color), xx *target_element, xx element_kind);
            show_tooltip(tooltip);
            show_tooltip_binding(tprint("Add % to selection", element_name), "Ctrl LMB");
            entity_tick_flash_hover(*entity);

            // Enable checkbox. @Think Consider making this a radio button, if we always have a selection option, but maybe we don't want that...
            ImGui.TableNextColumn();
            ImGui.Checkbox(imgui_label("##elements_visible", elements_visible), elements_visible);
            show_tooltip(tprint("% selection visibility", element_name));

            // Color selection
            ImGui.TableNextColumn();
            if ImGui.ColorEdit4(imgui_label("##element_color", element_color), *element_color.component, ImGui.ColorEditFlags.NoInputs) {
                // This checkbox also sets the font color, to address feedback from BK: Black text on black wireframe is hard to read
                label_color.* = darken(element_color, .8);
            }

            // // Element kind name
            // ImGui.TableNextColumn();
            // ImGui.Text(element_name);
        }

        // Selection Mode UI
        if ImGui.BeginTable("Mode Table", 4, flags=ImGui.TableFlags.BordersOuter) {
            defer ImGui.EndTable();

            select_element(
                "Triangles", .TRIANGLE, "When chosen select triangles (obj f-directives)",
                *entity.display_info.triangle_style.color,
                *entity.display_info.triangle_label_theme.label_color,
                *entity.display_info.triangle_style.visible);
            entity.display_info.triangle_style.edge_style.visible = entity.display_info.triangle_style.visible; // Turn off/on edges with triangles

            select_element(
                "Segments", .SEGMENT, "When chosen select segments (obj l-directives)",
                *entity.display_info.segment_style.color,
                *entity.display_info.segment_label_theme.label_color,
                *entity.display_info.segment_style.visible);
            select_element(
                "Points", .POINT, "When chosen select points (obj p-directives)",
                *entity.display_info.point_style.color,
                *entity.display_info.point_label_theme.label_color,
                *entity.display_info.point_style.visible);
            select_element(
                "Positions", .VERTEX, "When chosen select vertices (obj v-directives)",
                *entity.display_info.vertex_style.color,
                *entity.display_info.vertex_label_theme.label_color,
                *entity.display_info.vertex_style.visible);
        }

        {
            disable_cache_button := is_empty(entity.mesh);
            if disable_cache_button       ImGui.BeginDisabled();
            defer if disable_cache_button ImGui.EndDisabled();

            if ImGui.Button(imgui_label("Cache", *entity)) {
                if !is_empty(entity.mesh) {

                    new_entity : *Entity = New(Entity);
                    merge(*new_entity.mesh, entity.mesh);
                    counter : *Preset_Counter = find_or_add(*g_preset_name_to_counter, "Selection");
                    set_entity_source_from_selection(new_entity, tprint("Selection %", counter.count), new_entity.mesh.positions.count);
                    set_entity_display_info(new_entity);
                    counter.count += 1;

                    add_entity(new_entity, app.settings.duplicate_file_behaviour);

                    log("Selection cached: Created item #% %", app.entities.count-1, entity_name(new_entity));
                } else {
                    log("Selection caching omitted: Mesh was empty");
                }
            }
            show_tooltip("Adds a new item based on this selection");
        }

        ImGui.SameLine();
        if ImGui.Button(imgui_label("Clear", *entity)) {
            deinit(*entity);
        }
    }
}

// @Incomplete This should have an update struct so we can know what changed on a granular level, we want to apply updates on a granular level
format_float_ui :: (format : *FormatFloat) -> bool {
    changed := false;

    trailing_width : s32 = xx format.trailing_width;
    changed |= ImGui.InputInt("Float decimals", *trailing_width);
    format.trailing_width = clamp(trailing_width, 0, 12);
    show_tooltip("Number of digits following the decimal point");
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

    TOOLTIP :: #string DONE
"short form" means just draw values e.g., {1, 3, 5}
"long form"  means draw names then values e.g., {x = 1; y = 3; z = 5;}
DONE
    show_tooltip(TOOLTIP);
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

ScopedChildBorderTheme :: (color : ImGui.ImVec4, size : float) -> ImGui.ImVec4, float #expand {
    prev_color := ImGui.GetStyle().Colors[ImGui.Col.Border];
    prev_size :=  ImGui.GetStyle().ChildBorderSize;
    ImGui.PushStyleColor(xx ImGui.Col.Border, color);
    ImGui.PushStyleVar(xx ImGui.StyleVar.ChildBorderSize, size);
    `defer ImGui.PopStyleColor();
    `defer ImGui.PopStyleVar();
    return prev_color, prev_size;
}

ActionButton :: (texture : Texture, action_set : *Action_Set) #expand {

    // :DisableUpdateButtonsIfNoSelection Maybe its confusing to see buttons you can't click or see the tooltip of
    has_target := false;
    for :Selected app.entities {
       has_target = true;
       break;
    }

    base_tint := ImGui.GetStyle().Colors[ImGui.Col.ButtonHovered];

    ImGui.PushStyleColor(xx ImGui.Col.Border, TRANSPARENT);
    ImGui.PushStyleColor(xx ImGui.Col.Button, TRANSPARENT);
    ImGui.PushStyleColor(xx ImGui.Col.ButtonHovered, TRANSPARENT);
    ImGui.PushStyleColor(xx ImGui.Col.ButtonActive, TRANSPARENT);
    ImGui.PushStyleColor(xx ImGui.Col.Text, BLACK);
    defer ImGui.PopStyleColor(5);

    tint : Vector4;
    if has_target {
        // hue cycles with progress
        progress := action_set.progress_proc();
        hsva := color_convert_RGB_to_HSV(base_tint.x, base_tint.y, base_tint.z, base_tint.w);
        hue := (cast(u16)(hsva.x * 255) + cast(u16)(255 * progress.numer / (progress.denom + 1))) % 256;
        tint = color_convert_HSV_to_RGB(xx hue / 255., hsva.y, hsva.z, hsva.w);
    } else {
        // Reproduce visual effect of BeginDisabled/EndDisabled but dont actually call that since it also disables the tooltips...
        tint = ImGui.GetStyle().Colors[ImGui.Col.TextDisabled];
        tint.w = ImGui.GetStyle().DisabledAlpha;
    }

    assert(texture.gl_handle != 0);
    if ImGui.ImageButton(imgui_label("##ActionButton", *action_set), cast(ImGui.ImTextureID)texture.gl_handle, ACTION_BUTTON_SIZE, tint_col=tint) {
        if has_target {
            action_set.last_interaction_time = current_time_consensus();
            action_set.proc(xx *action_set.last_interaction_time);
        }
    }
    show_tooltip_binding(action_set.desc, to_string(action_set.key, Modifier_Flags.{}, pad_unmodified=false));
}

show_folder_context_menu :: (path : string, auto_load_new_files : *bool = null) {
    current_pos := ImGui.GetWindowPos();
    current_size := ImGui.GetWindowSize();
    window_pos := ImGui.ImVec2.{current_pos.x + current_size.x + WINDOW_BORDER_UI_OFFSET.x, ImGui.GetCursorScreenPos().y};
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
            for :All app.entities {
                if get_directory(get_entity_source(it).path) == path {
                    remove it;
                }
            }
            remove_directory_if_unwatched(path);
        }
    }
}

show_camera_controls :: () {

    old_padding := ImGui.GetStyle().CellPadding;
    ImGui.PushStyleVar(xx ImGui.StyleVar.CellPadding, .{0, 0});
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
        show_tooltip("Near plane offset");

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
        show_tooltip("Far plane offset");

        ImGui.TableNextRow();
        ImGui.TableNextColumn();

        // @Volatile Sync with :RotateLookDirectionUI
        right_label, left_label, amount := "<< ", ">> ", 5.;
        if io().KeyShift {
            right_label, left_label, amount = "<<<", ">>>", 15.;
        } else if io().KeyAlt {
            right_label, left_label, amount = " < ", " > ", 1.;
        }

        if ImGui.Button(right_label.data) {
            axis := camera_rotation_axis();
            rotate_look_direction(axis, amount);
        }
        {
            ImGui.PushStyleVar(xx ImGui.StyleVar.CellPadding, old_padding);
            defer ImGui.PopStyleVar();
            ccw_bindings := temp_array(Binding_With_Description);
            array_add(*ccw_bindings, make_Binding_With_Description(to_string(#char "[", .{alt_pressed=true}),   "Rotate  -1 deg about selected rotation axis"));
            array_add(*ccw_bindings, make_Binding_With_Description(to_string(#char "[", .{}),                   "Rotate  -5 deg about selected rotation axis"));
            array_add(*ccw_bindings, make_Binding_With_Description(to_string(#char "[", .{shift_pressed=true}), "Rotate -15 deg about selected rotation axis"));
            show_tooltip_binding(..ccw_bindings);
        }

        ImGui.TableNextColumn();
        if ImGui.Button("XYZ") {
            up := normalize(cross(.{-1, 1, 0}, .{-1, -1, -1}));
            set_look_direction(direction=.{-1, -1, -1}, up=up);
        }

        ImGui.TableNextColumn();
        if ImGui.Button(left_label.data) {
            axis := camera_rotation_axis();
            rotate_look_direction(axis, -amount);
        }
        {
            ImGui.PushStyleVar(xx ImGui.StyleVar.CellPadding, old_padding);
            defer ImGui.PopStyleVar();
            cw_bindings := temp_array(Binding_With_Description);
            array_add(*cw_bindings, make_Binding_With_Description(to_string(#char "]", .{alt_pressed=true}),   "Rotate  1 deg about selected rotation axis"));
            array_add(*cw_bindings, make_Binding_With_Description(to_string(#char "]", .{}),                   "Rotate  5 deg about selected rotation axis"));
            array_add(*cw_bindings, make_Binding_With_Description(to_string(#char "]", .{shift_pressed=true}), "Rotate 15 deg about selected rotation axis"));
            show_tooltip_binding(..cw_bindings);
        }

        // ImGui.TableNextColumn();
        ImGui.SameLine();
        combo_box("##Alt Axis", *app.camera.rotation_axis, type_info(type_of(app.camera.rotation_axis)));
        show_tooltip_binding("Camera Rotation Axis", "Alt RMB");
    }

    // @FIXME Having this combo box here screws up the UI when you close the Settings tree :(
    // ImGui.SetNextItemWidth(-FLOAT32_MIN);
    // combo_box("", *app.camera.rotation_axis, type_info(type_of(app.camera.rotation_axis)));
    // show_tooltip("Alt RMB Camera Rotation Axis");

    // compiler_report("Move this menu next to the other buttons and update the changelog")

    /*
    if ImGui.TreeNodeEx("Advanced") {
        defer ImGui.TreePop();

        ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing());
        defer ImGui.Indent(ImGui.GetTreeNodeToLabelSpacing());

        // @TODO Would be better to set the look direction vector I think
        ImGui.DragFloat( "##Near ", *app.camera.near, .05);
        show_tooltip("Near plane offset");
        ImGui.DragFloat( "##Far  ", *app.camera.far, .05);
        show_tooltip("Far plane offset");
        // ImGui.DragFloat3("Orbit", *app.camera.look_position.component);
        // ImGui.DragFloat3("Eye  ", *app.camera.eye_position.component);
        // ImGui.DragFloat3("Up   ", *app.camera.up_direction.component);

        combo_box("##Alt Axis", *app.camera.rotation_axis, type_info(type_of(app.camera.rotation_axis)));
        show_tooltip_binding("Camera Rotation Axis", "Alt RMB");

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

show_help_about_content :: () {

    {
        logo := icon_prism_logo_texture;
        ImGui.SameLine(ImGui.GetContentRegionAvail().x / 2 - logo.width / 2);
        ImGui.Image(cast(ImGui.ImTextureID)logo.gl_handle, ImGui.ImVec2.{xx logo.width, xx logo.height});
        ImGui.NewLine();
    }

    {
        ImGui.Text("Prism is a tool for debugging geometry algorithms with obj files");
        ImGui.Text("This is version %. Feedback/Bugs:", app.changelog[0].name);
        ImGui.SameLine();
        ImGui.PushStyleColor(xx ImGui.Col.Text, app.theme.generic_color);
        defer ImGui.PopStyleColor();
        ImGui.Text("matija.kecman@epicgames.com"); // TODO Click to copy to clipboard?
    }

    ImGui.PushStyleVar(xx ImGui.StyleVar.IndentSpacing, 8);
    defer ImGui.PopStyleVar();

    ImGui.NewLine();
    if ImGui.TreeNodeEx("Credits and Licenses", .SpanAvailWidth | .Framed) {
        defer ImGui.TreePop();

        sdl_version : SDL_version = sdl_get_version();

        // BoxSection();
        // ImGui.TableNextColumn();

        COMPILER_VERSION :: #run stop_at_any(compiler_get_version_info(null), ",");
        ImGui.Text("Jai % (twitter.com/Jonathan_Blow)", COMPILER_VERSION);
        ImGui.Text("SDL %.%.%, zlib (libsdl.org)", sdl_version.major, sdl_version.minor, sdl_version.patch);
        ImGui.Text("ImGui %, MIT (github.com/ocornut/imgui)", to_string(ImGui.GetVersion()));
        ImGui.Text("Geometric Tools, BSL 1.0 (github.com/davideberly/GeometricTools)");
        ImGui.Text("par_shapes.h, MIT (github.com/prideout/par)");
    }
}

show_changelog :: () {
    if ImGui.Button("Save to CHANGELOG.md") {
        contents : string;
        defer free(contents);
        time := filetime_to_readable_date(current_time_consensus(), true);
        contents = join(contents, tprint("This Changelog was saved at % via a button in the Prism application\nFor a nicer reading experience consider pasting this file into https://markdownlivepreview.com\n\n\n", time));
        for app.changelog {
            entry := tprint("# Version %, %\n%\n\n\n", it.name, it.date, it.description);
            contents = join(contents, entry);
        }
        write_entire_file_to_cwd("CHANGELOG.md", contents);
    }
    show_tooltip("Write the changelog to CHANGELOG.md\nHandy if you want to search the changelog");

    blank_space :: () {
        ImGui.Text("                                                                                                                       ");
    }

    latest := app.changelog[0];
    if ImGui.TreeNodeEx(temp_c_string(tprint("Version %, % (latest)", latest.name, latest.date))) {
        defer ImGui.TreePop();

        ImGui.PushStyleColor(xx ImGui.Col.Text, app.theme.changelog_color);
        ImGui.TextWrapped(latest.description);
        // ImGui.Text(latest.description); // @Bug This truncated the changelog for PRISM_VERSION_0_2_1
        ImGui.PopStyleColor();
        blank_space();
    }

    for 1..app.changelog.count-1 {
        version := app.changelog[it];
        if ImGui.TreeNodeEx(temp_c_string(tprint("Version %, %", version.name, version.date))) {
            defer ImGui.TreePop();

            ImGui.PushStyleColor(xx ImGui.Col.Text, app.theme.changelog_color);
            ImGui.TextWrapped(version.description);
            // ImGui.Text(version.description);
            ImGui.PopStyleColor();
            blank_space();
        }
    }

    // FIXME This is broken
    //if ImGui.TreeNodeEx("Known Issues", ImGui.TreeNodeFlags.SpanAvailWidth | .Framed) {
    //    defer ImGui.TreePop();
    //    if ImGui.BeginTable("", 2, flags=table_flags | .ScrollX) {
    //        defer ImGui.EndTable();
    //        for app.known_issues {
    //            ShowBinding(it.name, it.description);
    //        }
    //    }
    //}
}


show_vertex_label_theme_ui :: (name : string, tooltip : string, theme : *Vertex_Label_Theme) {
    ImGui.Text(name);

    ImGui.SameLine();
    ImGui.Checkbox(imgui_label("##index", theme), *theme.show_index);
    show_tooltip(tooltip);

    ImGui.SameLine();
    ImGui.ColorEdit4(imgui_label("##color", theme), *theme.label_color.component, ImGui.ColorEditFlags.NoInputs);
    show_tooltip("Text Color");

    ImGui.SameLine();
    ImGui.PushItemWidth(70);
    ImGui.DragFloat(imgui_label("##scale", theme), *theme.label_scale, .005, .2, 1., format="%.3f");
    show_tooltip("Text Scale");
    ImGui.PopItemWidth();

    ImGui.SameLine();
    ImGui.Checkbox(imgui_label("##coord_visible", theme), *theme.show_position);
    show_tooltip("Show value of .obj v-directives (model space positions)\nwhich are referenced by elements");
}

show_element_label_theme_ui :: (name : string, tooltip : string, theme : *Element_Label_Theme) {
    ImGui.Text(name);
    ImGui.SameLine();

    ImGui.Checkbox(imgui_label("##index", theme), *theme.show_index);
    show_tooltip(tooltip);
    ImGui.SameLine();

    ImGui.ColorEdit4(imgui_label("##color", theme), *theme.label_color.component, ImGui.ColorEditFlags.NoInputs);
    show_tooltip("Text Color");
    ImGui.SameLine();

    ImGui.PushItemWidth(70);
    ImGui.DragFloat(imgui_label("##scale", theme), *theme.label_scale, .005, .2, 1., format="%.3f");
    show_tooltip("Text Scale");
    ImGui.PopItemWidth();
}

show_annotation_theme_ui :: (name : string, tooltip : string, theme : *Annotation_Label_Theme) {
    ImGui.Text(name);
    ImGui.SameLine();

    ImGui.Checkbox(imgui_label("##visible", theme), *theme.visible);
    show_tooltip(tooltip);
    ImGui.SameLine();

    ImGui.ColorEdit4(imgui_label("##color", theme), *theme.label_color.component, ImGui.ColorEditFlags.NoInputs);
    show_tooltip("Text Color");
    ImGui.SameLine();

    ImGui.PushItemWidth(70);
    ImGui.DragFloat(imgui_label("##scale", theme), *theme.label_scale, .005, .2, 1., format="%.3f");
    show_tooltip("Text Scale");
    ImGui.PopItemWidth();
}

show_attribute_theme_ui :: (name : string, tooltip : string, theme : *Attribute_Theme) {
    ImGui.Text(name);
    ImGui.SameLine();

    ImGui.Checkbox(imgui_label("##visible", theme), *theme.visible);
    show_tooltip(tooltip);
    ImGui.SameLine();

    ImGui.ColorEdit4(imgui_label("##color", theme), *theme.label_color.component, ImGui.ColorEditFlags.NoInputs);
    show_tooltip("Text Color");
    ImGui.SameLine();

    ImGui.PushItemWidth(70);
    ImGui.DragFloat(imgui_label("##scale", theme), *theme.label_scale, .005, .2, 1., format="%.3f");
    show_tooltip("Text Scale");
    ImGui.PopItemWidth();
}


display_info_ui :: (display_info : *Display_Info, aabb : AxisBox3, entity_index : int = -1) -> Display_Info_Update {

   old_display_info := display_info.*;

   show_clipping_ui(display_info, aabb);
   show_rendering_and_labeling_ui(display_info, entity_index);

   return get_update(old_display_info, display_info);
}

display_information :: (entity : *Entity) {
    if  begin_item_details_section("Information") {
        defer end_item_details_section();
        table_flags : ImGui.TableFlags;
        if !app.settings.item_details_uses_menu table_flags |= .BordersOuter;

        ImGui.BeginTable("##InformationTable", 2, flags=table_flags);
        defer ImGui.EndTable();

        ImGui.TableSetupColumn("Property", ImGui.TableColumnFlags.WidthFixed);//, 0);
        ImGui.TableSetupColumn("Value", ImGui.TableColumnFlags.WidthFixed);//;, 60);
        ImGui.TableSetupScrollFreeze(0, 1); // Make header row always visible
        ImGui.TableHeadersRow();

        Row :: (entry : string, description : string, tooltip : string) #expand {
            ImGui.TableNextColumn();
            ImGui.TextColored(app.theme.keymap_color, entry);
            if tooltip show_tooltip(tooltip);

            ImGui.TableNextColumn();
            ImGui.Text(description);
            if tooltip show_tooltip(tooltip);
        }

        // @Incomplete Attributes/Annotations information?
        Row("Date created", filetime_to_readable_date(get_entity_source(entity).creation_time), "Date/time when item was (re)loaded");
        Row("Positions", tprint("%", entity.mesh.positions.count), "Number of vertex positions");
        Row("Points", tprint("%", entity.mesh.points.count), "Number of point elements");
        Row("Segments", tprint("%", entity.mesh.segments.count), "Number of line segment elements");
        Row("Triangles", tprint("%", entity.mesh.triangles.count), "Number of triangle elements");

        aabb := entity.render_info.bounding_aabb;
        Row("AABB Max Point", tprint("[%, %, %]", aabb.max_point.x, aabb.max_point.y, aabb.max_point.z), "Model space AABB");
        Row("AABB Min Point", tprint("[%, %, %]", aabb.min_point.x, aabb.min_point.y, aabb.min_point.z), "Model space AABB");

        sphere := entity.render_info.bounding_sphere;
        Row("Sphere center", tprint("[%, %, %]", sphere.center.x, sphere.center.y, sphere.center.z), "Model space bounding sphere");
        Row("Sphere radius", tprint("%", sphere.radius), "Model space bounding sphere");
    }
}

display_transform :: (entity : *Entity) {
    if  begin_item_details_section("Transform") {
        defer end_item_details_section();
        if !app.settings.item_details_uses_menu begin_box_section();
        defer if !app.settings.item_details_uses_menu end_box_section();

        ImGui.TableNextColumn();

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

    annotation_count := entity_annotation_count(entity);
    header := ifx annotation_count == 0 then "Annotation Table (none)" else "Annotation Table";
    if            annotation_count == 0 then ImGui.BeginDisabled();
    defer if      annotation_count == 0 then ImGui.EndDisabled();

    show_annotation_theme_ui("Vertex Annotations  ", "Show annotations", *entity.display_info.vertex_label_theme.annotation_label_theme);
    show_annotation_theme_ui("Point Annotations   ", "Show annotations", *entity.display_info.point_label_theme.annotation_label_theme);
    show_annotation_theme_ui("Segment Annotations ", "Show annotations", *entity.display_info.segment_label_theme.annotation_label_theme);
    show_annotation_theme_ui("Triangle Annotations", "Show annotations", *entity.display_info.triangle_label_theme.annotation_label_theme);

    if ImGui.TreeNodeEx(imgui_label(header), .SpanAvailWidth) {
        defer ImGui.TreePop();

        DoRadioButton :: (name : string, annotations_kind : Annotation.Kind, annotations : [..]Annotation) #expand {
            if !annotations.count ImGui.BeginDisabled();
            ImGui.RadioButton(name, xx *`entity.annotation_info.show_kind, xx annotations_kind);
            show_tooltip(tprint("% annotation%", annotations.count, plural_suffix(annotations.count > 1)));
            if !annotations.count ImGui.EndDisabled();
        }

        // @Cleanup Make this work with reflection!
        DoRadioButton("Vertex", .VERTEX, entity.vertex_annotations);
        ImGui.SameLine();
        DoRadioButton("Point", .POINT, entity.point_annotations);
        ImGui.SameLine();
        DoRadioButton("Segment", .LINE, entity.line_annotations);
        ImGui.SameLine();
        DoRadioButton("Triangle", .TRIANGLE, entity.face_annotations);
        ImGui.SameLine();
        DoRadioButton("Block", .BLOCK, entity.block_annotations); // @Think Maybe better name is FILE annotation
        ImGui.SameLine();
        DoRadioButton("Command", .COMMAND, entity.command_annotations);

        annotations : [..]Annotation;
        if #complete entity.annotation_info.show_kind == {
            case .VERTEX;   annotations = entity.vertex_annotations;
            case .POINT;    annotations = entity.point_annotations;
            case .LINE;     annotations = entity.line_annotations;
            case .TRIANGLE; annotations = entity.face_annotations;
            case .BLOCK;    annotations = entity.block_annotations;
            case .COMMAND;  annotations = entity.command_annotations;
        }

        // This should be a function per annotation kind, so it can have different columns/states

        if annotations.count {

            table_flags := attr_anno_table_flags;
            outer_size := ImGui.ImVec2.{0, app.settings.annotation_list_max_size_before_scroll_px};

            if last_frame_annotation_list_height_px < outer_size.y {
                table_flags &= ~.ScrollY;
                outer_size.y = 0; // Not really necessary, since its ignored unless flags include ScrollY
            }

            column_count : s32 = 4;
            ScopeZeroCellPaddingY();
            if ImGui.BeginTable("##Annotations_Table", column_count, flags=table_flags, outer_size=outer_size) {
                defer ImGui.EndTable();

                ImGui.TableSetupColumn("UI",         ImGui.TableColumnFlags.WidthFixed | .NoSort);
                ImGui.TableSetupColumn("Index",      ImGui.TableColumnFlags.WidthFixed | .DefaultSort);
                ImGui.TableSetupColumn("Type",       ImGui.TableColumnFlags.WidthFixed | .DefaultHide | .NoSort);
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
                    if annotation.kind == .BLOCK || annotation.kind == .COMMAND {
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
                        show_tooltip_binding(..bindings);
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

display_attribute :: (entity : *Entity, entity_index : int, base_attribute : *Simple_Mesh_Attribute_Base) {
    value_type : Type;
    element_kind : Simple_Mesh_Element;
    if base_attribute.type == {
        case Simple_Mesh_Attribute(Matrix3, .TRIANGLE);
            ImGui.Text("Attribute '%' assigns % values to triangles", base_attribute.name, Matrix3);
            TOOLTIP :: #string DONE
Matrix3 :: struct {
_11, _12, _13 : float;
_21, _22, _23 : float;
_31, _32, _33 : float;
#place _11; row: [3]Vector3 = ---;
}
DONE;
            show_tooltip(TOOLTIP);
    }

    if base_attribute.type == {
        case Simple_Mesh_Attribute(Matrix3, .TRIANGLE);

            show_attribute_theme_ui("Attribute", "Show attribute labels", *base_attribute.display_info.theme);

            attribute := cast(*Simple_Mesh_Attribute(Matrix3, .TRIANGLE))base_attribute;
            if ImGui.TreeNodeEx(imgui_label(tprint("Attributes Table (%)", attribute.values.count), base_attribute), .SpanAvailWidth) {
                defer ImGui.TreePop();

                if attribute.values.count {

                    table_flags := attr_anno_table_flags;
                    table_flags &= ~.Sortable;

                    outer_size := ImGui.ImVec2.{0, app.settings.annotation_list_max_size_before_scroll_px};

                    if last_frame_annotation_list_height_px < outer_size.y {
                        table_flags &= ~.ScrollY;
                        outer_size.y = 0; // Not really necessary, since its ignored unless flags include ScrollY
                    }

                    column_count : s32 = 3;
                    ScopeZeroCellPaddingY();
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
                            show_tooltip_binding(..bindings);

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

// This is also used for the attribute tables, so don't be confused by the name..!
last_frame_annotation_list_height_px : float;


show_rendering_and_labeling_ui :: (display_info : *Display_Info, entity_index : int) {
    //if ImGui.TreeNodeEx("Rendering and Labeling", .SpanAvailWidth) {
    //    defer ImGui.TreePop();
    show_rendering_positions_ui(display_info, entity_index);
    show_rendering_points_ui(display_info, entity_index);
    show_rendering_segments_ui(display_info, entity_index);
    show_rendering_triangles_ui(display_info, entity_index);
}

show_normal_style_ui :: (normal_style : *Normal_Style, padding : string = "") {
    ImGui.Text("Normals Style%", padding);
    ImGui.SameLine();
    ImGui.Checkbox(imgui_label("##normals_visible", normal_style), *normal_style.visible);
    show_tooltip("Normal Visibility");
    ImGui.SameLine();
    ImGui.ColorEdit4(imgui_label("##normals_color", normal_style), *normal_style.color.component, ImGui.ColorEditFlags.NoInputs);
    ImGui.SameLine();
    ImGui.PushItemWidth(70);
    ImGui.DragFloat(imgui_label("##normals_scale", normal_style), *normal_style.scale, .05);
    show_tooltip("Scale/length multiplier applied to the obj normals");
    ImGui.PopItemWidth();
    ImGui.SameLine();
    ImGui.Checkbox(imgui_label("##normals_normalized", normal_style), *normal_style.normalized);
    show_tooltip("Normalize the obj normals before scaling");
}

show_rendering_triangles_ui :: (display_info : *Display_Info, entity_index : int = -1) {

    if valid_geometry_index(entity_index) && app.entities[entity_index].mesh.triangles.count == 0 {
        ImGui.BeginDisabled();
        if  begin_item_details_section("Triangles (none)") {
            defer end_item_details_section();
        }
        ImGui.EndDisabled();
        return;
    }

    if  begin_item_details_section("Triangles") {
        defer end_item_details_section();
        if !app.settings.item_details_uses_menu begin_box_section();
        defer if !app.settings.item_details_uses_menu end_box_section();

        ImGui.TableNextColumn();
        ImGui.Text(
            "Face Style        ");
        ImGui.SameLine();
        ImGui.Checkbox(imgui_label("##triangle_style.visible", display_info), *display_info.triangle_style.visible);
        show_tooltip("Triangle Face Visibility");
        ImGui.SameLine();
        ImGui.ColorEdit4(imgui_label("##triangle_style.color", display_info), *display_info.triangle_style.color.component, ImGui.ColorEditFlags.NoInputs);
        show_tooltip("Triangle Frontface Color");
        ImGui.SameLine();
        ImGui.PushItemWidth(70);
        combo_box("##Backface Mode", *display_info.triangle_style.backface_mode, type_info(Backface_Mode));
        ImGui.PopItemWidth();
        show_tooltip("Triangle Backface Render Mode");

        ImGui.TableNextColumn();
        ImGui.Text(
            "Edge Style        ");
        ImGui.SameLine();
        ImGui.Checkbox(imgui_label("##triangle_style.edge_style.visible", display_info), *display_info.triangle_style.edge_style.visible);
        show_tooltip("Triangle Edges Visibility");
        ImGui.SameLine();
        ImGui.ColorEdit4(imgui_label("##triangle_style.edge_style.color", display_info), *display_info.triangle_style.edge_style.color.component, ImGui.ColorEditFlags.NoInputs);
        ImGui.SameLine();
        ImGui.PushItemWidth(70);
        ImGui.DragFloat(imgui_label("##triangle_style.edge_style.width", display_info), *display_info.triangle_style.edge_style.width, .05);
        show_tooltip("Triangle Edges Width");
        display_info.triangle_style.edge_style.width = clamp(display_info.triangle_style.edge_style.width, 1., 5);
        ImGui.PopItemWidth();

        ImGui.TableNextColumn();
        show_normal_style_ui(*display_info.triangle_style.normal_style, "     ");

        ImGui.TableNextColumn();
        show_element_label_theme_ui(
            "Index Labels      ", "Show index of .obj f-directives", *display_info.triangle_label_theme);

        ImGui.TableNextColumn();
        show_annotation_theme_ui(
            "Annotation Labels ", "Show annotations", *display_info.triangle_label_theme.annotation_label_theme);

        if ImGui.TreeNodeEx("Advanced##Rendering", .SpanAvailWidth) {
            defer ImGui.TreePop();

            ImGui.Text("Render Mode");
            ImGui.SameLine();
            ImGui.Checkbox(imgui_label("##Flat Shading", display_info), *display_info.triangle_style.flat_shading);
            show_tooltip("Flat Shading");
            ImGui.SameLine();
            ImGui.PushItemWidth(120);
            combo_box("##triangle_style.display_mode", *display_info.triangle_style.display_mode, type_info(type_of(display_info.triangle_style.display_mode)));
            ImGui.PopItemWidth();

            // This doesn't seem very useful so I removed it
            //ImGui.SameLine();
            //ImGui.Button(imgui_label("Reset Colors##color_reset", display_info));
            //show_tooltip("Deduce item primary colors from the file path");
        }
   }
}

show_rendering_segments_ui :: (display_info : *Display_Info, entity_index : int = -1) {
    if valid_geometry_index(entity_index) && app.entities[entity_index].mesh.segments.count == 0 {
        ImGui.BeginDisabled();
        if  begin_item_details_section("Segments (none)") {
            defer end_item_details_section();
        }
        ImGui.EndDisabled();
        return;
    }

    if  begin_item_details_section("Segments") {
        defer end_item_details_section();
        if !app.settings.item_details_uses_menu begin_box_section();
        defer if !app.settings.item_details_uses_menu end_box_section();

        ImGui.TableNextColumn();
        ImGui.Text(
            "Segment Style     ");
        ImGui.SameLine();
        ImGui.Checkbox(imgui_label("##segment_style.visible", display_info), *display_info.segment_style.visible);
        show_tooltip("Segment Visibility");
        ImGui.SameLine();
        ImGui.ColorEdit4(imgui_label("##segment_style.color", display_info), *display_info.segment_style.color.component, ImGui.ColorEditFlags.NoInputs);
        ImGui.SameLine();
        ImGui.PushItemWidth(70);
        ImGui.DragFloat(imgui_label("##segment_style.width", display_info), *display_info.segment_style.width, .05);
        show_tooltip("Width");
        display_info.segment_style.width = clamp(display_info.segment_style.width, 1, 5);
        ImGui.PopItemWidth();

        ImGui.TableNextColumn();
        show_normal_style_ui(*display_info.segment_style.normal_style, "     ");

        ImGui.TableNextColumn();
        show_element_label_theme_ui(
            "Index Labels      ", "Show index of .obj l-directives", *display_info.segment_label_theme);

        ImGui.TableNextColumn();
        show_annotation_theme_ui(
            "Annotation Labels ", "Show annotations", *display_info.segment_label_theme.annotation_label_theme);
    }
}

show_rendering_points_ui :: (display_info : *Display_Info, entity_index : int = -1) {
    if valid_geometry_index(entity_index) && app.entities[entity_index].mesh.points.count == 0 {
        ImGui.BeginDisabled();
        if  begin_item_details_section("Points (none)") {
            defer end_item_details_section();
        }
        ImGui.EndDisabled();
        return;
    }

    if  begin_item_details_section("Points") {
        defer end_item_details_section();
        if !app.settings.item_details_uses_menu begin_box_section();
        defer if !app.settings.item_details_uses_menu end_box_section();

        ImGui.TableNextColumn();
        ImGui.Text(
            "Point Style       ");
        ImGui.SameLine();
        ImGui.Checkbox(imgui_label("##point_style.visible", display_info), *display_info.point_style.visible);
        show_tooltip("Point Visibility");
        ImGui.SameLine();
        ImGui.ColorEdit4(imgui_label("##point_style.color", display_info), *display_info.point_style.color.component, ImGui.ColorEditFlags.NoInputs);
        ImGui.SameLine();
        ImGui.SameLine();
        ImGui.PushItemWidth(70);
        ImGui.InputInt("##point_style.size", *display_info.point_style.size);
        show_tooltip("Size");
        display_info.point_style.size = clamp(display_info.point_style.size, 1, 10);
        ImGui.PopItemWidth();

        ImGui.TableNextColumn();
        show_normal_style_ui(*display_info.point_style.normal_style, "     ");

        ImGui.TableNextColumn();
        show_element_label_theme_ui(
            "Index Labels      ", "Show index of .obj p-directives", *display_info.point_label_theme);

        ImGui.TableNextColumn();
        show_annotation_theme_ui(
            "Annotation Labels ", "Show annotations", *display_info.point_label_theme.annotation_label_theme);
    }
}

show_rendering_positions_ui :: (display_info : *Display_Info, entity_index : int = -1) {
    if valid_geometry_index(entity_index) && app.entities[entity_index].mesh.positions.count == 0 {
        ImGui.BeginDisabled();
        if begin_item_details_section("Vertices (none)") {
            defer end_item_details_section();
        }
        ImGui.EndDisabled();
        return;
    }

    if  begin_item_details_section("Vertices") {
        defer end_item_details_section();
        if !app.settings.item_details_uses_menu begin_box_section();
        defer if !app.settings.item_details_uses_menu end_box_section();

        ImGui.TableNextColumn();
        ImGui.Text(
            "Vertex Style      ");
        ImGui.SameLine();
        ImGui.Checkbox(imgui_label("##vertex_style.visible", display_info), *display_info.vertex_style.visible);
        show_tooltip("Positions visibility.\nRender vertex positions as points");
        ImGui.SameLine();
        ImGui.ColorEdit4(imgui_label("##vertex_style.color", display_info), *display_info.vertex_style.color.component, ImGui.ColorEditFlags.NoInputs);
        ImGui.SameLine();
        ImGui.SameLine();
        ImGui.PushItemWidth(70);
        ImGui.InputInt("##vertex_style.size", *display_info.vertex_style.size);
        show_tooltip("Size");
        display_info.vertex_style.size = clamp(display_info.vertex_style.size, 1, 10);
        ImGui.PopItemWidth();

        ImGui.TableNextColumn();
        show_vertex_label_theme_ui(
            "Index Labels      ", "Show index of .obj v-directives\nwhich are referenced by elements", *display_info.vertex_label_theme);

        ImGui.TableNextColumn();
        show_annotation_theme_ui(
            "Annotation Labels ", "Show annotations", *display_info.vertex_label_theme.annotation_label_theme);

        if valid_geometry_index(entity_index) {
            if ImGui.TreeNodeEx("Advanced##Labelling", .SpanAvailWidth) {
                defer ImGui.TreePop();

                if ImGui.Button("Find Unreferenced Positions") {
                    item_find_unreferenced_positions(entity_index, new_item=0);
                }
                show_tooltip("If labels look wrong this may help:\nCalls `item_find_unreferenced_points` command\nSee the command documentation for details");
            }
        }
    }
}


show_clipping_ui :: (using display_info : *Display_Info, aabb : AxisBox3) {

    if begin_item_details_section("Clipping") {
        defer end_item_details_section();
        table_flags : ImGui.TableFlags;
        if !app.settings.item_details_uses_menu {
            table_flags |= .BordersOuter; // | .RowBg; // .SizingFixedFit
        }

        if ImGui.BeginTable("##Clipping UI Table", 4, flags=table_flags) {
            defer ImGui.EndTable();

            ImGui.TableSetupColumn("checkbox", .WidthFixed, user_id=0);
            ImGui.TableSetupColumn("center/normal|radius/range", .WidthFixed, user_id=1);
            ImGui.TableSetupColumn("center/normal|radius/range value", .WidthFixed, init_width_or_weight=200, user_id=2);
            ImGui.TableSetupColumn("reset/normalize", .WidthFixed, user_id=3);

            {
                ImGui.TableNextRow();
                old_clip_sphere := clip_sphere;
                
                BINDING :: "Shift LMB";
                DESCRIBE :: "Click-drag to set clipping sphere on selected items";

                ImGui.TableSetColumnIndex(0);
                ImGui.Text("Sphere");
                show_tooltip_binding(DESCRIBE, BINDING);
                ImGui.SameLine();
                ImGui.Checkbox(imgui_label("##clip_sphere", *clip_sphere), *clip_sphere.is_active);
                show_tooltip("Enable clipping using distance from a point.\nKeep the region inside the sphere.");

                ImGui.TableSetColumnIndex(1);
                ImGui.Text("Center");
                ImGui.Text("Radius");

                ImGui.TableSetColumnIndex(2);
                ImGui.SetNextItemWidth(-FLOAT32_MIN);
                ImGui.DragFloat3(imgui_label("##clip_sphere.center", *clip_sphere), *clip_sphere.center.component, .05, format="%.3f");
                show_tooltip_binding(DESCRIBE, BINDING);

                ImGui.SetNextItemWidth(-FLOAT32_MIN);
                // @Cleanup check this can't go nan, do we need to do the same to the clipping ranges?
                ImGui.DragFloat(imgui_label("##clip_sphere.radius", *clip_sphere), *clip_sphere.radius, .01, 0., 0., format="%.3f");
                if isnan(clip_sphere.radius) clip_sphere.radius = POSITIVE_INF;
                clip_sphere.radius = clamp(clip_sphere.radius, 0., POSITIVE_INF);
                show_tooltip_binding(DESCRIBE, BINDING);

                ImGui.TableSetColumnIndex(3);
                uninitialized := (clip_sphere.radius == POSITIVE_INF);
                if ImGui.Button(imgui_label("Reset    ##sphere", *clip_sphere)) || uninitialized {
                    if !is_empty(aabb) {
                        clip_sphere.sphere = bounding_sphere(aabb);
                    } else {
                        clip_sphere.center = .{0, 0, 0};
                        clip_sphere.radius = POSITIVE_INF;
                    }
                }
                show_tooltip("Reset sphere to contain the universe");

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
                    show_tooltip("Enable clipping using a distance range from a plane passing through the origin.\nKeep the region bounded by the parallel planes positioned at the range min/max.");

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
                    show_tooltip("Reset the range min/max to keep the entire aabb");

                    if ImGui.Button(imgui_label("Normalize", p)) {
                        normal_length := length(p.normal);
                        if normal_length != 0 {
                            p.min /= normal_length;
                            p.max /= normal_length;
                            p.normal /= normal_length;
                        }
                    }
                    show_tooltip("Make the normal unit and update the range min/max");
                }

                // See :RenderingSelectionAABB
                display_info.aabb_visible = true;

                clip_range_ui(*clip_ranges[0], aabb, .{1, 0, 0});
                clip_range_ui(*clip_ranges[1], aabb, .{0, 1, 0});
                clip_range_ui(*clip_ranges[2], aabb, .{0, 0, 1});
            }
        }
    }
}

make_opengl_texture :: (texture_data : *u8, texture_width : s32, texture_height : s32) -> GLuint {
    gl_handle : GLuint;

    // Create an OpenGL texture identifier
    glGenTextures(1, *gl_handle);
    glBindTexture(GL_TEXTURE_2D, gl_handle);

    // Setup filtering parameters for display
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); // This is required on WebGL for non power-of-two textures
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); // Same

    // Upload pixels into texture
    //glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, cast(u32)texture_width, cast(u32)texture_height, 0, GL_RGBA, GL_UNSIGNED_BYTE, texture_data);

    return gl_handle;
}

load_texture_from_file :: (filename : string) -> Texture, bool {
    texture : Texture;

    // Load from file
    texture_data : *u8 = stbi_load(temp_c_string(filename), *texture.width, *texture.height, null, 4);
    defer stbi_image_free(texture_data);

    if texture_data == null {
        return texture, false;
    }

    texture.gl_handle = make_opengl_texture(texture_data, texture.width, texture.height);

    return texture, true;
}

load_texture_from_memory :: (buffer : []u8) -> Texture, bool {
    texture : Texture;

    channels : s32;
    texture_data : *u8 = stbi_load_from_memory(buffer.data, cast(s32)buffer.count, *texture.width, *texture.height, *channels, 4);

    texture.gl_handle = make_opengl_texture(texture_data, texture.width, texture.height);

    return texture, true;
}

// @Cleanup I think to_c_string leaks memory, perhaps we can fix by pushing the temporary allocator before calling it

display_action_buttons := true;

entity_source_tooltip :: (entity : Entity) {
    if #complete entity.source.kind == {
        case .Entity_Source_File;
            source := isa(entity.source, Entity_Source_File); assert(source != null); // @CompilerBug Why assert(source) does not work?
            show_tooltip(tprint("File:    %\nCreated: %", source.path, filetime_to_readable_date(source.creation_time)));
        case .Entity_Source_Command;
            source := isa(entity.source, Entity_Source_Command); assert(source != null);
            show_tooltip(tprint("Command: %\nCreated: %", source.console_command, filetime_to_readable_date(source.creation_time)));
        case .Entity_Source_Preset;
            source := isa(entity.source, Entity_Source_Preset); assert(source != null);
            show_tooltip(tprint("Example shape\nCreated: %", filetime_to_readable_date(source.creation_time)));
        case .Entity_Source_Selection;
            source := isa(entity.source, Entity_Source_Selection); assert(source != null);
            show_tooltip(tprint("Selection\nCreated: %", filetime_to_readable_date(source.creation_time)));
    }
}

entity_tick_flash_hover :: (entity : *Entity) #expand {
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

attr_anno_table_flags :: ImGui.TableFlags
    .BordersOuter |
    .Hideable |
    .RowBg |
    .Resizable |
    .Reorderable |
    .ScrollY |
    .Sortable |
    .PadOuterX;

POSITIVE_INF :: 0h7F800000;

sdl_get_version :: () -> SDL_version {
    wm_info: SDL_SysWMinfo;
    SDL_VERSION(*wm_info.version);
    SDL_GetWindowWMInfo(app.window, *wm_info);
    return wm_info.version;
}

click_cycle_prism_color_index :: () {
    if ImGui.IsItemClicked() {
        prism_icon_color_index += 1;
        if prism_icon_color_index >= PRISM_ICON_COLORS.count {
            prism_icon_color_index = 0;
        }
        color : Named_Color = PRISM_ICON_COLORS[prism_icon_color_index];
        log("Set prism color to %. This is only aesthetic, it could be useful if you are comparing data between instances of Prism.", color.name);

        // TODO Also set the icon on the desktop, can we the following work??
        //#if OS == .WINDOWS {
        //#import "Windows_Resources";
        //icon_data :: #run read_entire_file("icon.ico");
        //set_icon_by_data(get_path_of_running_executable(), icon_data);
        //}
    }
}