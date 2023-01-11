#load "app.jai";

main :: () {

    SDL_Init(SDL_INIT_VIDEO);

    init_changelog();
    app.window = SDL_CreateWindow(tprint("% %", OUTPUT_EXE_NAME, app.changelog[0].name).data,
                                  SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                  app.INITIAL_WINDOW_WIDTH, app.INITIAL_WINDOW_HEIGHT,
                                  SDL_WINDOW_OPENGL|SDL_WINDOW_RESIZABLE);

    // Check that the window was successfully created
    if app.window == null {
        // In the case that the window could not be made...
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return;
    }

    // Direct all logging into the console
    // Note: For debugging you may want to comment these lines and use the default logger, you'll also need to comment the disable_runtime_console() line in build.jai so that the Windows program console is shown
    context.logger = console_logger;
    context.logger_data = *app.console.log;

    // Load console history from file
    console_load_history();

    // @FIXME If I don't explicitly set attributes here gl_get_version() returns a different result
    // Set 3,3 to match Simp MINIMUM_GL_MINOR_VERSION, MINIMUM_GL_MAJOR_VERSION??
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);

    gl_context := SDL_GL_CreateContext(app.window); // alias for *void
    if !gl_context {
        print( "Could not create OpenGL context: %\n", to_string(SDL_GetError()));
        return;
    }

    gl_load(*gl, SDL_GL_GetProcAddress);

    // gl_enable_debug_output(true);
    // glEnable(GL_DEBUG_OUTPUT); // @FIXME above enables GL_DEBUG_OUTPUT_SYNCHRONOUS, but without this line debug output doesn't work

    gl_version_major, gl_version_minor = gl_get_version();
    print ("OpenGL %.%\n", gl_version_major, gl_version_minor);

    // Prepare VAO for text quads.
    {
        glGenVertexArrays(1, *app.text_vao);
        glGenBuffers(1, *app.text_vbo);
        glBindVertexArray(app.text_vao);
        glBindBuffer(GL_ARRAY_BUFFER, app.text_vbo);
        glBufferData(GL_ARRAY_BUFFER, size_of(GLfloat) * 6 * 4, null, GL_DYNAMIC_DRAW);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 4 * size_of(GLfloat), xx 0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);
    }

    {
        VERT, VERT_OK :: #run read_entire_file("source/shaders/simple_mesh.vert"); #assert(VERT_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/shaders/simple_mesh.frag"); #assert(FRAG_OK);
        app.simple_mesh_program = get_shader_program(VERT, FRAG);
        glGenVertexArrays(1, *app.simple_mesh_vao);
    }

    {
        VERT, VERT_OK :: #run read_entire_file("source/shaders/mesh.vert"); #assert(VERT_OK);
        GEOM, GEOM_OK :: #run read_entire_file("source/shaders/mesh.geom"); #assert(GEOM_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/shaders/mesh.frag"); #assert(FRAG_OK);
        app.mesh_program = get_shader_program(VERT, FRAG, GEOM);
        glGenVertexArrays(1, *app.mesh_vao);
    }

    {
        VERT, VERT_OK :: #run read_entire_file("source/shaders/normals.vert"); #assert(VERT_OK);
        GEOM, GEOM_OK :: #run read_entire_file("source/shaders/normals.geom"); #assert(GEOM_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/shaders/normals.frag"); #assert(FRAG_OK);
        app.normals_program = get_shader_program(VERT, FRAG, GEOM);
        glGenVertexArrays(1, *app.normals_vao);
    }

    {
        VERT, VERT_OK :: #run read_entire_file("source/shaders/aabb.vert"); #assert(VERT_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/shaders/aabb.frag"); #assert(FRAG_OK);
        app.aabb_program = get_shader_program(VERT, FRAG);
        glGenVertexArrays(1, *app.aabb_vao);
    }

    {
        // We may want to hot-load this file in future to allow the user to customize the background
        VERT, VERT_OK :: #run read_entire_file("source/shaders/background.vert"); #assert(VERT_OK);
        FRAG, FRAG_OK :: #run read_entire_file("source/shaders/background.frag"); #assert(FRAG_OK);
        app.background_program = get_shader_program(VERT, FRAG);
        glGenVertexArrays(1, *app.background_vao);
    }

    TRIAD_AXIS_LENGTH :: 1;
    app.triad = make_axes_triad(TRIAD_AXIS_LENGTH);

    init_camera();
    init_commands();
    init_keymap();
    init_known_issues();

    file_change_callback :: (watcher: *File_Watcher(), change: *File_Change, user_data : *void) {
        // print("Change for path %: %", change.full_path, change.events);

        found_entity : *Entity;
        for entity : app.entities {
            if entity.source.kind == .Entity_Source_File && get_entity_source(entity).path == change.full_path {
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
                entity := load_one_file(change.full_path, .IGNORE);
                add_entity(entity, .IGNORE);

                if app.settings.fit_to_screen_on_file_watcher_event {
                    fit_scene_on_screen();
                }
            }
        }
    }

    // Setup file watcher
    file_events_to_watch : File_Change_Event;
    file_events_to_watch |= File_Change_Event.ADDED | .MODIFIED;
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
    assert(ctx != null, "must call create context");
    ImGui.SetCurrentContext(ctx);

    // Setup Platform/Renderer backends
    ImGui_ImplSDL2_InitForOpenGL(app.window, gl_context);
    ImGui_ImplOpenGL3_Init("#version 130");

    // // Using those as a base value to create width/height that are factor of the size of our font
    // const float TEXT_BASE_WIDTH = ImGui::CalcTextSize("A").x;
    // const float TEXT_BASE_HEIGHT = ImGui::GetTextLineHeightWithSpacing();

    // Set up Simp
    {
        window_type := get_window_type(app.window);
        Simp.ScopeContext();
        Simp.set_render_target(window_type);

        FONT, FONT_OK :: #run read_entire_file("data/Inconsolata.otf"); #assert(FONT_OK);
        font_data : []u8;
        font_data.data = FONT.data;
        font_data.count = FONT.count;
        app.simp_font = Simp.get_font_at_size(font_data, FONT_SIZE);
        assert(app.simp_font != null);
    }

    set_prism_theme(.LIGHT); // @Refactor this so that we just need to change the theme enum to change the theme

    load_from_command_line();

    // Main loop
    while !app.closing_application {
        // Cache the state we need this frame and reset it for the next frame
        g_this_frame_state = g_next_frame_state; // This should be read-only for this frame
        g_next_frame_state = ImGui_Frame_State.{};

        handle_events();

        changed, needs_wait, wait_seconds := process_changes(*app.file_watcher);

        // Start the Dear ImGui frame
        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplSDL2_NewFrame();
        ImGui.NewFrame();

        // @FIXME: move to after glClear etc so that we can do immediate mode viz in these functions?
        if app.show_ui {
            show_left_window();
            show_right_window();
            show_imgui_demo_window();
            show_item_list_actions_ui();
            console_draw();
            show_pending_directories_ui();

            // inspect("Debug", *app.camera, true);
        }

        glViewport(0, 0, xx io().DisplaySize.x, xx io().DisplaySize.y); // @TODO Is DisplaySize updated with window resizing? Use current_window_height/width here?
        {
            // @Cleanup Window resizing works even without this, why?
            Simp.ScopeContext();
            Simp.update_window(get_window_type(app.window));
        }
        glEnable(GL_DEPTH_TEST);
        glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);

        update_camera(1);

        // These functions all do a ray cast on all visible entities, but usually its only one function per frame, we could make this clear by having them return booleans saying if they executed and putting them in an if-else-if chain
        // Also, these functions determine what is rendered so its important they are called before the rendering functions
        do_clipping_sphere_mode();
        do_geometry_selection_mode();
        do_item_selection_mode();


        // @Think Maybe we can have the metaprogram check that the app global variable is not modified in these functions
        render_background();
        render_entities();
        render_selections();
        render_axes_triad();

        do_demo_mode(); // @Cleanup Why do we need this here---some opengl weirdness is going on!

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


// @Incomplete @FIXME Load files first so that if a directory and a file in that directory are both passed, the directory will correctly mention the file is loaded
load_from_command_line :: () {

    // @CompilerBug for .\Prism.exe 'C:\Users\MatijaKecman\Desktop\TestShapes - Copy\' we get a result with a trailing ", maybe its the shell, maybe its this function..??
    args := get_command_line_arguments();
    defer array_reset(*args); // get_command_line_arguments() creates a new array so we release it here. The strings themselves are not copies, however!
    for 1..args.count-1 {

        // file_list uses the / separator but on windows we may have passed an input using the \ separator, so we fix that here.
        pattern := canonically_formatted_path_string(args[it]);

        // Note: Previously we also searched for #char "-" but this was confusing since some folder names use this as a separator, if we want to find that one make sure its also within square brackets
        if find_index_of_any_from_left(pattern, "*") != -1 {
            // @Cleanup This is really annoying. file_list gives different results on windows/linux
            files := file_list(".", recursive=true, follow_symlinks=false);
            defer array_free(files);
            for _file, file_index : files {
                file := _file;
                file = canonically_formatted_path_string(file);
                if wildcard_match(file, pattern) {
                    handle_filename(file, .IGNORE);
                }
            }
        } else {
            got_directory, got_directory_valid := is_directory(pattern);
            if !got_directory_valid {
                log_warning("Expected a filename or directory, got '%'", pattern);
            } else if got_directory {
                handle_directory(pattern);
            } else {
                handle_filename(pattern, app.settings.duplicate_file_behaviour);
            }
        }
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
                info.proc(info.data);
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

            case SDL_KEYDOWN;

                for app.keymap_keydown.mappings {
                    maybe_run_binding(event.key.keysym.sym, it, app.keymap_keydown);
                }

                // @Cleanup Make this a proper function!
                if event.key.keysym.sym == .SDLK_ESCAPE {
                    app.console.show_ui = false;
                }

            case SDL_KEYUP;

                for app.keymap.mappings {
                    maybe_run_binding(event.key.keysym.sym, it, app.keymap);
                }

                for app.keymap_actions.mappings {
                    maybe_run_binding(event.key.keysym.sym, it, app.keymap_actions);
                }

            case SDL_DROPFILE;

                // @Leak event.drop.file should be free'd using SDL_free
                dropped := canonically_formatted_path_string(to_string(event.drop.file));

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

#scope_file

handle_filename :: (fully_pathed_filename : string, matching_name_behaviour : Duplicate_File_Behaviour) {
    entity := load_one_file(fully_pathed_filename, matching_name_behaviour);
    add_entity(entity, matching_name_behaviour); 
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
        pending.directory = <<found_dir; // Copy state from found_dir, we'll overwrite the path though
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

    // We add the pending directory even if there are no loadable files currently in it because we want to support a use-case where the user makes prism watch a directory and then starts loading files
    array_add(*app.pending_directories, pending);
}

// Get the platform specific window handle from SDL
get_window_type :: (window : *SDL_Window) -> Window_Type {
    assert(window != null);
    sdl_wm_info : SDL_SysWMinfo;
    SDL_VERSION(*sdl_wm_info.version);
    SDL_GetWindowWMInfo(app.window, *sdl_wm_info);
    // printv(sdl_wm_info);
    #if OS == .WINDOWS {
        #import "Windows";
        window_type := sdl_wm_info.info.win.window;
    } else #if OS == .LINUX {
        window_type := sdl_wm_info.info.x11.window;
        #assert(false, "@Incomplete verify that Simp integration works on linux");
    }
    return window_type;
}

ctx: *ImGui.Context;
_imgui_alloc_context: Context;
c_alloc :: (sz: u64, userdata: *void) -> *void #c_call { push_context << cast(*Context)userdata { return alloc(cast(s64)sz); } }
c_free :: (ptr: *void, userdata: *void) -> void #c_call { push_context << cast(*Context)userdata { free(ptr); } }

ImGui_Impl_CreateContext :: ($set_default_allocators := true) {
    #if set_default_allocators {
        _imgui_alloc_context = context;
        ImGui.SetAllocatorFunctions(c_alloc, c_free, *_imgui_alloc_context);
    }

    ctx = ImGui.CreateContext();
    io := ImGui.GetIO();
    // io.ConfigFlags_ |= .NavEnableKeyboard; // This interacts in an annoying way with keyboard shortcuts, fix that before enabling
}
