#load "app.jai";

Keymap :: struct {}
Single_Key_Mapping :: struct {}

main :: () {

    sdl_window_flags : SDL_WindowFlags = SDL_WINDOW_OPENGL|SDL_WINDOW_RESIZABLE|SDL_WINDOW_BORDERLESS;

    SDL_Init(SDL_INIT_VIDEO);

    app.window = SDL_CreateWindow("Prizm",
                                  SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                  app.INITIAL_WINDOW_WIDTH, app.INITIAL_WINDOW_HEIGHT,
                                  sdl_window_flags);

    // Check that the window was successfully created
    if app.window == null {
        // In the case that the window could not be made...
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return;
    }

    // @FIXME If I don't explicitly set attributes here gl_get_version() returns a different result
    // Set 3,3 to match Simp MINIMUM_GL_MINOR_VERSION, MINIMUM_GL_MAJOR_VERSION??
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

    SDL_SetWindowHitTest(app.window, window_hit_test, null);

    // // Using those as a base value to create width/height that are factor of the size of our font
    // const float TEXT_BASE_WIDTH = ImGui::CalcTextSize("A").x;
    // const float TEXT_BASE_HEIGHT = ImGui::GetTextLineHeightWithSpacing();

    /*
    // TODO Option to pass font and size on the command line?
    FONT, FONT_OK ::   #run read_entire_file("data/Inconsolata-SemiBold.ttf"); #assert(FONT_OK);
    FONT2, FONT2_OK :: #run read_entire_file("data/Inconsolata.otf");          #assert(FONT2_OK);

    font_config : ImGui.ImFontConfig;
    ImGui.ImFontConfig.Constructor(*font_config);
    font_config.FontDataOwnedByAtlas = false;
    font :  *ImGui.ImFont = ImGui.ImFontAtlas.AddFontFromMemoryTTF(ImGui.GetIO().Fonts, FONT.data, FONT.count, 18., *font_config);
    font2 : *ImGui.ImFont = ImGui.ImFontAtlas.AddFontFromMemoryTTF(ImGui.GetIO().Fonts, FONT2.data, FONT2.count, 18., *font_config);

    // Set up Simp
    {
        window_type := get_window_type(app.window);
        Simp.ScopeContext();
        Simp.set_render_target(window_type);

        font_data : []u8;
        font_data.data = FONT.data;
        font_data.count = FONT.count;
        app.simp_font = Simp.get_font_at_size(font_data, FONT_SIZE);
        assert(app.simp_font != null);
    }
    */

    set_prizm_theme(.LIGHT); // @Refactor this so that we just need to change the theme enum to change the theme

    load_from_command_line();

    // Main loop
    while !app.closing_application {
        handle_events();

        changed, needs_wait, wait_seconds := process_changes(*app.file_watcher);

        // Start the Dear ImGui frame
        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplSDL2_NewFrame();
        ImGui.NewFrame();


        glViewport(0, 0, xx io().DisplaySize.x, xx io().DisplaySize.y); // @TODO Is DisplaySize updated with window resizing? Use current_window_height/width here?
        {
            // @Cleanup Window resizing works even without this, why?
            Simp.ScopeContext();
            Simp.update_window(get_window_type(app.window));
        }
        glEnable(GL_DEPTH_TEST);
        glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);

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
}

handle_events :: () {

    // @Cleanup The parameters here are a bit weird, I think the loops that call this function should not be over the mappings, but the keymaps 
    maybe_run_binding :: (sdl_keycode : SDL_Keycode, mapping : Single_Key_Mapping, keymap : Keymap) {
    }

    event: SDL_Event;
    while SDL_PollEvent(*event) {
        ImGui_ImplSDL2_ProcessEvent(*event);

        if event.type == {
            case SDL_QUIT;

            case SDL_WINDOWEVENT;

            case SDL_KEYDOWN;

            case SDL_KEYUP;

            case SDL_DROPFILE;

        }
    }
}

to_sdl_keycode :: (key_code : u32) -> SDL_Keycode {
    return SDLK_UNKNOWN;
}

handle_load_string :: (path : string, recursive := false) -> bool {

    // file_list uses the / separator but on windows we may have passed an input using the \ separator, so we fix that here.
    // Note: On unix this function fails if the path does not exist, on Windows it does not fail
    pattern : string;

    // Note: Previously we also searched for #char "-" but this was confusing since some folder names use this as a separator, if we want to find that one make sure its also within square brackets
    wildcard_index : s64 = find_index_of_any_from_left(pattern, "*"); // From left since we want the first one

    if wildcard_index != -1 {

        // Fail if the wildcard didn't occur in the filename
        // @Incomplete Remove this constraint, make it recursive if the * isn't in the filename
        directory_index : s64 = find_index_from_right(pattern, "/"); // From right since we want the last one
        if directory_index != -1 {
            if wildcard_index < directory_index {
                log_error("Wildcard * can only occur in the filename but it preceeded a directory separator, got '%'", path);
                return false;
            }
        }

        directory : string = slice(pattern, 0, directory_index + 1);
        if directory == "" || !is_directory(directory){
            directory = ".";
        }

        files := file_list(directory, recursive=recursive, follow_symlinks=false);
        defer array_free(files);

        for _file, file_index : files {
            file := _file;
            if wildcard_match(file, pattern) {
                handle_filename(file, .IGNORE);
            }
        }

    } else {

        got_directory, got_directory_valid := is_directory(pattern);

        if !got_directory_valid {
        } else if got_directory {
            handle_directory(pattern);
        } else {
            handle_filename(pattern, app.settings.duplicate_file_behaviour);
        }

    }

    return true;
}

#scope_file

file_change_callback :: (watcher: *File_Watcher(), change: *File_Change, user_data : *void) {
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

window_hit_test :: (window : *SDL_Window, point : *SDL_Point, data : *void) -> SDL_HitTestResult #c_call {

    new_context : Context;
    push_context new_context {

        return .SDL_HITTEST_NORMAL;
    }
}

ctx: *ImGui.ImGuiContext;

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

    ctx = ImGui.CreateContext();
}
