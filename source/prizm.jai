#load "app.jai";

main :: () {

    // Direct all logging into the console
    // Note: For debugging you may want to comment these lines and use the default logger, you'll also need to comment the disable_runtime_console() line in first.jai so that the Windows program console is shown
    context.logger = console_logger;
    context.logger_data = *app.console.log;

    // Gets the version info, used by print_usage_and_maybe_exit
    init_changelog();

    sdl_window_flags : SDL_WindowFlags = SDL_WINDOW_OPENGL|SDL_WINDOW_RESIZABLE|SDL_WINDOW_BORDERLESS;

    // Must come before SDL_CreateWindow since it changes sdl_window_flags
    {
        args := get_command_line_arguments();
        defer array_free(args);
        for 1..args.count-1 {
            arg : string = to_lower_copy_new(args[it]);

            if arg.count >= 2 && arg[0] == #char "-" && arg[1] == #char "-" {
                // @Volatile Sync with :PRIZM_ICON_COLORS
                if arg == "--help" {
                    print_usage_and_maybe_exit();
                } else if arg == "--alwaysontop" {
                    sdl_window_flags |= SDL_WINDOW_ALWAYS_ON_TOP;
                } else if arg == "--blue" {
                    prizm_icon_color_index = 0;
                } else if arg == "--green" {
                    prizm_icon_color_index = 1;
                } else if arg == "--red" {
                    prizm_icon_color_index = 2;
                } else if arg == "--black" {
                    prizm_icon_color_index = 3;
                } else {
                    error := tprint("Unrecognized program argument '%' at position %\n", args[it], it);
                    print_usage_and_maybe_exit(error);
                }
            }
        }
    }

    SDL_Init(SDL_INIT_VIDEO);

    app.window = SDL_CreateWindow(OUTPUT_EXE_NAME.data,
                                  SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                  app.INITIAL_WINDOW_WIDTH, app.INITIAL_WINDOW_HEIGHT,
                                  sdl_window_flags);

    // Check that the window was successfully created
    if app.window == null {
        // In the case that the window could not be made...
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return;
    }


    // Load console history from file
    console_load_history();

    // @FIXME If I don't explicitly set attributes here gl_get_version() returns a different result
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);

    // gl_version_major, gl_version_minor = gl_get_version();
    // print("Using OpenGL %.%", gl_version_major, gl_version_minor);

    gl_context := SDL_GL_CreateContext(app.window); // alias for *void
    if !gl_context {
        print("Could not create OpenGL context: %\n", to_string(SDL_GetError()));
        return;
    }

    gl_load(*gl, SDL_GL_GetProcAddress);

    gl_enable_debug_output(true);
    // glEnable(GL_DEBUG_OUTPUT); // @FIXME above enables GL_DEBUG_OUTPUT_SYNCHRONOUS, but without this line debug output doesn't work

    TRIAD_AXIS_LENGTH :: 1;
    app.triad = make_axes_triad(TRIAD_AXIS_LENGTH);

    init_shaders();
    init_camera();
    init_commands();
    init_keymap();
    init_known_issues();
    init_icons();

    // Setup file watcher
    file_events_to_watch : File_Change_Event;
    file_events_to_watch |= .ADDED;
    file_events_to_watch |= .MODIFIED;
    if !init(*app.file_watcher, file_change_callback, null, file_events_to_watch, merge_window_seconds = .1, watch_recursively = false, verbose = false) {
        log_error("Could not init file watcher"); // @Cleanup Should just disable this feature in this case..
        exit(1);
    }
    defer deinit(app.file_watcher);

    // Init these after the file watcher
    array_add(*app.directories, .{path=SELECTION_FOLDER});
    array_add(*app.directories, .{path=PRESET_SHAPE_FOLDER});
    array_add(*app.directories, .{path=COMMAND_OUTPUT_FOLDER});

    // Setup Dear ImGui context
    // IMGUI_CHECKVERSION();
    ImGui_Impl_CreateContext();
    assert(imgui_context != null, "must call create context");
    ImGui.SetCurrentContext(imgui_context);

    // Setup Platform/Renderer backends
    ImGui_ImplSDL2_InitForOpenGL(app.window, gl_context);
    ImGui_ImplOpenGL3_Init("#version 130");

    // Disable writing the .ini and .log files
    io().IniFilename = null;
    io().LogFilename = null;

    SDL_SetWindowHitTest(app.window, window_hit_test, null);

    // // Using those as a base value to create width/height that are factor of the size of our font
    // const float TEXT_BASE_WIDTH = ImGui::CalcTextSize("A").x;
    // const float TEXT_BASE_HEIGHT = ImGui::GetTextLineHeightWithSpacing();

    imgui_init_fonts();

    set_prizm_theme(.LIGHT); // @Refactor this so that we just need to change the theme enum to change the theme

    load_from_command_line();

    // Main loop
    while !app.closing_application {
        // Cache the state we need this frame and reset it for the next frame
        g_this_frame_state = g_next_frame_state; // This should be read-only for this frame
        g_next_frame_state = ImGui_Frame_State.{};

        changed, needs_wait, wait_seconds := process_changes(*app.file_watcher);

        handle_events();

        update_camera();

        // Start the Dear ImGui frame
        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplSDL2_NewFrame();
        ImGui.NewFrame();
        ImGui.PushFont(app.font_set.normal);

        // The selection should only be visible if the Select tool is visible in the UI.  We do this so that the keybinds that add stuff to the geometry selection can be used to add items to the item selection when not in selection mode
        app.select_tool.entity.display_info.is_visible = false;

        glViewport(0, 0, xx io().DisplaySize.x, xx io().DisplaySize.y);
        glEnable(GL_DEPTH_TEST);
        glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);

        // @FIXME: move to after glClear etc so that we can do immediate mode viz in these functions?
        show_menu_bar_ui();
        if app.show_ui {
            show_left_window();
            show_right_window();
            show_imgui_demo_window();
            show_ribbon_buttons_ui();
            console_draw();
            show_pending_directories_ui();

            // inspect("Debug", app.entities[0], true);
            // inspect("Debug", *app.camera, true);
            // inspect("Debug", *app.triad, true);
        }

        // These functions all do a ray cast on all visible entities, but usually its only one function per frame, we could make this clear by having them return booleans saying if they executed and putting them in an if-else-if chain
        // Also, these functions determine what is rendered so its important they are called before the rendering functions
        do_clipping_sphere_mode();
        do_geometry_selection_mode();
        do_item_selection_mode();

        // @Think Maybe we can have the metaprogram check that the app global variable is not modified in these functions
        // FIXME: When rendering entities we clear the depth buffer which means the order of these functions is quite @Volatile!
        render_background();
        render_selections();
        render_entities();
        render_text();
        render_axes_triad();
        render_demo_mode();

        ImGui.PopFont();
        ImGui.Render();
        ImGui_ImplOpenGL3_RenderDrawData(ImGui.GetDrawData());

        SDL_GL_SwapWindow(app.window);

        reset_temporary_storage();
        app.debug_frame = false;
        // sleep_milliseconds(200);
    }

    // Cleanup
    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplSDL2_Shutdown();
    ImGui.DestroyContext();

    SDL_GL_DeleteContext(gl_context);
    SDL_DestroyWindow(app.window);
    SDL_Quit();
}

print_usage_and_maybe_exit :: (error := "") {
if OS == .WINDOWS { // See :DisableRuntimeConsoleCleanup
    app.console.show_ui = true;
    if error log_error("%", error);
    else     log("\n"); // Needed to fix a weird alignment issue in the terminal..??
    log("Prizm % allows the following (case insensitive) program options:\n\n", changelog[0].name);
    log("--Help           Print this message and exit.\n");
    log("--AlwaysOnTop    Keeps the Prizm window on top.\n");
    log("--Red            Use the red   icon in the title bar.\n");
    log("--Green          Use the green icon in the title bar.\n");
    log("--Blue           Use the blue  icon in the title bar (This is the default).\n");
    log("--Black          Use the black icon in the title bar.\n");
    // exit(0); // Don't exit, the user can only read the logs in the program
} else {
    print("\n"); // Don't bother printing the error here
    print("Prizm % allows the following (case insensitive) program options:\n\n", changelog[0].name);
    print("--Help           Print this message and exit.\n");
    print("--AlwaysOnTop    Keeps the Prizm window on top.\n");
    print("--Red            Use the red   icon in the title bar.\n");
    print("--Green          Use the green icon in the title bar.\n");
    print("--Blue           Use the blue  icon in the title bar (This is the default).\n");
    print("--Black          Use the black icon in the title bar.\n");
    exit(0);
}
}

// @Incomplete @FIXME Load files first so that if a directory and a file in that directory are both passed, the directory will correctly mention the file is loaded
load_from_command_line :: () {

    // @CompilerBug for .\Prizm.exe 'C:\Users\MatijaKecman\Desktop\TestShapes - Copy\' we get a result with a trailing ", maybe its the shell, maybe its this function..??
    args := get_command_line_arguments();
    defer array_reset(*args); // get_command_line_arguments() creates a new array so we release it here. The strings themselves are not copies, however!
    for 1..args.count-1 {
        if starts_with(args[it], "--") {
            continue; // Skip program argument
        }
        handle_load_string(args[it]);
    }
    fit_scene_on_screen();
}

handle_events :: () {

    // @Cleanup The parameters here are a bit weird, I think the loops that call this function should not be over the mappings, but the keymaps 
    maybe_run_binding :: (sdl_keycode : SDL_Keycode, mapping : Single_Key_Mapping, keymap : Keymap) {
        if to_sdl_keycode(mapping.key_code) == sdl_keycode {
            if io().KeyShift == mapping.modifier_flags.shift_pressed   &&
               io().KeyCtrl  == mapping.modifier_flags.control_pressed &&
               io().KeyAlt   == mapping.modifier_flags.alt_pressed {
                if io().WantCaptureKeyboard && !mapping.override_WantCaptureKeyboard {
                    return;
                }
                info := *keymap.procs[mapping.proc_info_index];
                info.proc();
                return;
            }
        }
    }

    event: SDL_Event;
    while SDL_PollEvent(*event) {
        ImGui_ImplSDL2_ProcessEvent(*event);

        if event.type == {
            case SDL_QUIT;

                app.closing_application = true;

            case SDL_WINDOWEVENT;

                //print("window event: %\n", event.window.event);

                if event.window.event == SDL_WINDOWEVENT_SIZE_CHANGED {

                    width_scale  := cast(float) event.window.data1 / app.current_window_width;
                    height_scale := cast(float) event.window.data2 / app.current_window_height;

                    camera_delta_rl   := (1. -  width_scale) * (app.camera.right - app.camera.left) / 2;
                    camera_delta_tb   := (1. - height_scale) * (app.camera.top   - app.camera.bottom) / 2;
                    app.camera.right  -= camera_delta_rl;
                    app.camera.left   += camera_delta_rl;
                    app.camera.top    -= camera_delta_tb;
                    app.camera.bottom += camera_delta_tb;

                    app.current_window_width  = event.window.data1;
                    app.current_window_height = event.window.data2;
                }

                if event.window.event == SDL_WINDOWEVENT_MAXIMIZED {
                    app.window_maximized = true;
                }

                if event.window.event == SDL_WINDOWEVENT_SIZE_CHANGED {
                    app.window_maximized = false;
                }

                if event.window.event == SDL_WINDOWEVENT_FOCUS_GAINED {
                    SDL_SetWindowOpacity(app.window, app.window_focussed_opacity);
                }

                if event.window.event == SDL_WINDOWEVENT_FOCUS_LOST {
                    SDL_SetWindowOpacity(app.window, app.window_unfocussed_opacity);
                }

            case SDL_MOUSEWHEEL;

                using app.demo_mode;
                if enabled {
                    scrolling_up = false;
                    scrolling_down = false;
                    if (event.wheel.y > 0) { // Scrolled up
                        scrolling_up = true;
                    } else if (event.wheel.y < 0) { // Scrolled down
                        scrolling_down = true;
                    }
                }

            case SDL_KEYDOWN;

                if app.demo_mode.enabled {
                    array_add_if_unique(*app.demo_mode.keys_down, event.key.keysym.sym);
                }

                for app.keymap_keydown.mappings {
                    maybe_run_binding(event.key.keysym.sym, it, app.keymap_keydown);
                }

                // @Cleanup Make this a proper function!
                if event.key.keysym.sym == .SDLK_ESCAPE {
                    app.console.show_ui = false;

                    // :WindowOpacityControl
                    app.window_focussed_opacity = 1.;
                    app.window_unfocussed_opacity = 1.;
                    SDL_SetWindowOpacity(app.window, app.window_focussed_opacity);
                }

            case SDL_KEYUP;

                if app.demo_mode.enabled {
                    array_ordered_remove_by_value(*app.demo_mode.keys_down, event.key.keysym.sym);
                }

                for app.keymap.mappings {
                    maybe_run_binding(event.key.keysym.sym, it, app.keymap);
                }

                for app.keymap_actions.mappings {
                    maybe_run_binding(event.key.keysym.sym, it, app.keymap_actions);
                }

            case SDL_DROPFILE;

                // @Leak event.drop.file should be free'd using SDL_free
                drop_file : string = to_string(event.drop.file);
                dropped, success := canonically_formatted_path_string(drop_file);
                if !success {
                    log_warning("Failed to read file path '%', maybe it doesn't exist?", drop_file);
                    continue;
                }

                got_directory, got_directory_valid := is_directory(dropped);
                if !got_directory_valid {
                    log_warning("Expected a filename or directory, got '%'", dropped);
                } else if got_directory {
                    handle_directory(dropped);
                    // fit_scene_on_screen() is called when the pending directories are actually handled
                } else {
                    handle_filename(dropped, app.settings.duplicate_file_behaviour);
                    if app.settings.fit_to_screen_on_file_drop_event {
                        fit_scene_on_screen();
                    }
                }
        }
    }
}


// Note: path can have * wildcards in the filename part only
//
// Examples:
//      "file"
//      "file*set"
//      "file*set**again"
//      "directory"
//      "nested/path/file"
//      "nested/path/file*set"
//      "nested/path/file*set*again"
//      "../../path/file"
//      "../../path/directory"
//
// @Volatile This function should be carefully tested on both linux and windows...!
handle_load_string :: (path : string, recursive := false) {

    // @Incomplete Remove this constraint, make it recursive if the * isn't in the filename
    path_wildcard_index : s64 = find_index_of_any_from_left(path, "*"); // From left since we want the first one
    if path_wildcard_index >= 0 {

        path_directory_index : s64 = find_index_from_right(path, "/"); // From right since we want the last one
        if path_wildcard_index < path_directory_index {
            log_error("Wildcard * can only occur in the filename but it preceeded a directory separator in path '%'", path);
            return; // Fail if the wildcard didn't occur in the filename
        }

        directory_path := ifx path_directory_index >= 0 then slice(path, 0, path_directory_index) else ".";

        abs_directory_path, abs_directory_path_valid := canonically_formatted_path_string(directory_path);
        if !abs_directory_path_valid {
            log_error("Could not compute absolute path for '%', maybe this path does not exist?", directory_path);
            return;
        }

        filename_path := slice(path, path_directory_index + 1, path.count); // Note: The 3rd argument gets clamped
        pattern := join(abs_directory_path, filename_path, separator="/",, temp);

        match_count := 0;

        files := file_list(abs_directory_path, recursive=recursive, follow_symlinks=false);
        defer array_free(files);
        for _file, file_index : files {
            file := _file;
            file = canonically_formatted_path_string(file);
            if wildcard_match(file, pattern) {
                handle_filename(file, .IGNORE); // @TODO Perhaps this should be app.settings.duplicate_file_behaviour?
                match_count += 1;
            }
        }

        log("Loaded % file% matching path pattern '%'", match_count, plural_suffix(match_count > 1), pattern);

    } else {

        abs_path, abs_path_valid := canonically_formatted_path_string(path);
        if !abs_path_valid {
            log_error("Could not compute absolute path for '%', maybe this path does not exist?", path);
            return;
        }

        got_directory, got_directory_valid := is_directory(abs_path);
        if !got_directory_valid {
            log_error("Expected a filename or directory for '%', maybe this path does not exist?", abs_path);
            return;
        } else if got_directory {
            handle_directory(abs_path);
            return;
        } else {
            handle_filename(abs_path, app.settings.duplicate_file_behaviour);
            return;
        }

    }
}

#scope_file

file_change_callback :: (watcher: *File_Watcher(), change: *File_Change, user_data : *void) {
    // print("Change for path %: %", change.full_path, change.events);

    found_entity : *Entity;
    for :All entity : app.entities {
        if entity.source.kind == ._Entity_Source_File && get_entity_source(entity).path == change.full_path {
            found_entity = entity;
            break entity; // There can only be one relevant entity for each file change
        }
    }

    if found_entity {
        source := isa(found_entity.source, Entity_Source_File);
        if source && source.auto_reload {
            reload_entity(found_entity);

            if app.settings.fit_to_screen_on_file_watcher_event {
                fit_scene_on_screen();
            }
        }
    } else {
        found_dir : *app.Folder;
        for *dir : app.directories {
            if dir.path == get_directory(change.full_path) {
                found_dir = dir;
                break;
            }
        }
        if (change.events & .ADDED) && found_dir && found_dir.auto_load_new_files {
            entities := load_one_file(change.full_path, .IGNORE);
            for entity : entities {
                add_entity(entity, .IGNORE);
            }

            if app.settings.fit_to_screen_on_file_watcher_event {
                fit_scene_on_screen();
            }
        }
    }
}

handle_filename :: (fully_pathed_filename : string, matching_name_behaviour : Duplicate_File_Behaviour) {
    entities := load_one_file(fully_pathed_filename, matching_name_behaviour);
    for entity : entities {
        add_entity(entity, matching_name_behaviour); 
    }
}

handle_directory :: (path : string) {
    for *dir : app.pending_directories if dir.path == path {
        return; // We're already handling this directory, we can reach this code path if the user drops the same directory twice before the first one is handled
    }

    found_dir : *app.Folder;
    for *dir : app.directories if dir.path == path {
        found_dir = dir;
        break;
    }

    pending : app.Pending_Directory;

    if found_dir { // Directory already exists
        pending.directory = found_dir.*; // Copy state from found_dir, we'll overwrite the path though
    } else { // New directory
        // When a folder is given it defaults to auto reloading
        pending.auto_load_new_files = true;
        pending.set_auto_reload_on_newly_loaded_files = true;
    }
    pending.path = copy_string(path);

    files := file_list(path, recursive=false, follow_symlinks=false);
    defer array_free(files);
    not_loadable_count := 0;
    for file : files {
        if supported_format(file) {
            using pending_file : app.Pending_Directory.Pending_File;
            fully_pathed_filename = copy_string(file);
            modtime, size_in_bytes = file_modtime_and_size(file);
            is_loaded = find_entity(file, -1) != null;
            is_selected = !is_loaded;
            array_add(*pending.loadable_files, pending_file);
        } else {
            not_loadable_count += 1;
        }
    }

    // We add the pending directory even if there are no loadable files currently in it because we want to support a use-case where the user makes prizm watch a directory and then starts loading files
    array_add(*app.pending_directories, pending);
}

// Get the platform specific window handle from SDL
get_window_type :: (window : *SDL_Window) -> Window_Type {
    assert(window != null);
    sdl_wm_info : SDL_SysWMinfo;
    SDL_VERSION(*sdl_wm_info.version);
    SDL_GetWindowWMInfo(app.window, *sdl_wm_info);
    // print_vars(sdl_wm_info);
    #if OS == .WINDOWS {
        #import "Windows";
        window_type := sdl_wm_info.info.win.window;
    } else #if OS == .LINUX {
        window_type := sdl_wm_info.info.x11.window;
    }
    return window_type;
}

window_hit_test :: (window : *SDL_Window, point : *SDL_Point, data : *void) -> SDL_HitTestResult #c_call {

    new_context : Context;
    push_context new_context {

        // @Volatile :EasyResizeModeKeybind
        easy_resize_mode := io().KeyAlt;

        w := cast(float)app.current_window_width;
        h := cast(float)app.current_window_height;
        x := cast(float)point.x;
        y := cast(float)point.y;

        left   :=  cast(float)WINDOW_RESIZE_MARGIN_PX;
        right  := -cast(float)WINDOW_RESIZE_MARGIN_PX + w;
        top    :=  cast(float)WINDOW_RESIZE_MARGIN_PX;
        bottom := -cast(float)WINDOW_RESIZE_MARGIN_PX + h;
        if easy_resize_mode {
            k := EASY_RESIZE_FRACTION;;
            left   = w * k;
            right  = w * (1.-k);
            top    = h * k;
            bottom = h * (1.-k);
        }

        if y <= top {
            if x <= left {
                return .SDL_HITTEST_RESIZE_TOPLEFT;
            } else if x >= right {
                return .SDL_HITTEST_RESIZE_TOPRIGHT;
            } else {
                return .SDL_HITTEST_RESIZE_TOP;
            }
        } else if y >= bottom {
            if x <= left {
                return .SDL_HITTEST_RESIZE_BOTTOMLEFT;
            } else if x >= right {
                return .SDL_HITTEST_RESIZE_BOTTOMRIGHT;
            } else {
                return .SDL_HITTEST_RESIZE_BOTTOM;
            }
        } else {
            if x <= left {
                return .SDL_HITTEST_RESIZE_LEFT;
            } else if x >= right {
                return .SDL_HITTEST_RESIZE_RIGHT;
            } else if easy_resize_mode {
                return .SDL_HITTEST_DRAGGABLE;
            }
        }

        if x >= app.window_draggable_rect_min.x &&
            x <= app.window_draggable_rect_max.x &&
            y >= app.window_draggable_rect_min.y &&
            y <= app.window_draggable_rect_max.y {
            return .SDL_HITTEST_DRAGGABLE;
        }

        return .SDL_HITTEST_NORMAL;
    }
}

imgui_init_fonts :: () {
    // TODO Option to pass font and size on the command line?
    FONT, FONT_OK ::   #run read_entire_file("data/Inconsolata-SemiBold.ttf"); #assert(FONT_OK);
    //FONT2, FONT2_OK :: #run read_entire_file("data/Inconsolata.otf"); #assert(FONT2_OK);

    font_config : ImGui.ImFontConfig;
    ImGui.ImFontConfig.Constructor(*font_config);
    font_config.FontDataOwnedByAtlas = false;
    for enum_values_as_s64(Font_Size) {
        app.font_set.fonts[it_index] = ImGui.ImFontAtlas.AddFontFromMemoryTTF(ImGui.GetIO().Fonts, FONT.data, FONT.count, cast(float)it, *font_config);
    }
}


imgui_context : *ImGui.ImGuiContext;

_imgui_alloc_context: Context;

c_alloc :: (sz: u64, userdata: *void) -> *void #c_call {
    push_context (cast(*Context)userdata).* {
        return alloc(cast(s64)sz);
    }
}

c_free :: (ptr: *void, userdata: *void) -> void #c_call {
    push_context (cast(*Context)userdata).* {
        free(ptr);
    }
}

ImGui_Impl_CreateContext :: ($set_default_allocators := true) {
    #if set_default_allocators {
        _imgui_alloc_context = context;
        ImGui.SetAllocatorFunctions(c_alloc, c_free, *_imgui_alloc_context);
    }

    imgui_context = ImGui.CreateContext();
}
