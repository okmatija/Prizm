// Copyright Epic Games, Inc. All Rights Reserved.

#load "app.jai";

main :: () {

    SDL_Init(SDL_INIT_VIDEO);

    app.window = SDL_CreateWindow(tprint("Prism v%", VERSION_STRING).data,
                                  SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                  app.INITIAL_WINDOW_WIDTH, app.INITIAL_WINDOW_HEIGHT,
                                  SDL_WINDOW_OPENGL|SDL_WINDOW_RESIZABLE);

    // Check that the window was successfully created
    if app.window == null {
        // In the case that the window could not be made...
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return;
    }

    // Decide GL+GLSL versions
    // GL 3.0 + GLSL 130
    glsl_version :: "#version 130";

    // @FIXME If I don't explicitly set attributes here gl_get_version() returns a different result
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 6);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);

    gl_context := SDL_GL_CreateContext(app.window);
    if !gl_context {
        print( "Could not create OpenGL context: %\n", to_string(SDL_GetError()));
        return;
    }

    gl_load(*gl, SDL_GL_GetProcAddress);

    gl_version_major, gl_version_minor = gl_get_version();
    print ("OpenGL %.%\n", gl_version_major, gl_version_minor);

    // Setup Dear ImGui context
    // IMGUI_CHECKVERSION();
    ImGui_Impl_CreateContext();
    assert(ctx != null, "must call create context");
    ImGui.SetCurrentContext(ctx);

    // Setup Platform/Renderer backends
    ImGui_ImplSDL2_InitForOpenGL(app.window, gl_context);
    ImGui_ImplOpenGL3_Init(glsl_version);

    ImGui.StyleColorsDark();

    // Main loop
    while !app.closing_application {
        handle_events();

        ImGui.GetStyle().WindowRounding = 0;

        // Start the Dear ImGui frame
        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplSDL2_NewFrame(app.window);
        ImGui.NewFrame();

        io :: () -> *ImGui.IO {return ImGui.GetIO(); }

        glViewport(0, 0, xx io().DisplaySize.x, xx io().DisplaySize.y); // @TODO Is DisplaySize updated with window resizing? Use current_window_height/width here?
        glEnable(GL_DEPTH_TEST);
        glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);

        ImGui.ShowDemoWindow(*app.show_imgui_demo_window);

        // Rendering
        ImGui.Render();
        ImGui_ImplOpenGL3_RenderDrawData(ImGui.GetDrawData());

        // Update and Render additional Platform Windows
        // (Platform functions may change the current OpenGL context, so we save/restore it to make it easier to paste this code elsewhere.
        //  For this specific demo app we could also call SDL_GL_MakeCurrent(window, gl_context) directly)
        if io().ConfigFlags_ & .ViewportsEnable {
            backup_current_window := SDL_GL_GetCurrentWindow();
            backup_current_context := SDL_GL_GetCurrentContext();
            ImGui.UpdatePlatformWindows();
            ImGui.RenderPlatformWindowsDefault();
            SDL_GL_MakeCurrent(backup_current_window, backup_current_context);
        }

        SDL_GL_SwapWindow(app.window);

        reset_temporary_storage();
    }

    // Cleanup
    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplSDL2_Shutdown();
    ImGui.DestroyContext();

    SDL_GL_DeleteContext(gl_context);
    SDL_DestroyWindow(app.window);
    SDL_Quit();
}

handle_events :: () {
    event: SDL_Event;
    while SDL_PollEvent(*event) {
        ImGui_ImplSDL2_ProcessEvent(*event);

        if event.type == {
            case SDL_QUIT; {
                app.closing_application = true;
            }
            case SDL_WINDOWEVENT;
            case SDL_KEYDOWN; 
            case SDL_KEYUP; 
            case SDL_DROPFILE; 
        }
    }
}

#scope_file


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
    io.ConfigFlags_ |= .DockingEnable;
    // io.ConfigFlags_ |= .NavEnableKeyboard; // This interacts in an annoying way with keyboard shortcuts, fix that before enabling
}
