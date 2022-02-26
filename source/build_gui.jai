build_gui :: (
    preset_build_modes : Table(string, Build_Mode),
    chosen_build_mode : *Build_Mode = null,
    chosen_console_commands : *[..]*Code_Procedure_Header = null)
{
    if (chosen_build_mode == null && chosen_console_commands == null) ||
       (chosen_build_mode != null && chosen_console_commands != null) {
        compiler_report("build_gui expected to set exactly one of build options or console commands");
    }

    SDL_Init(SDL_INIT_VIDEO);

    task : string;
    if chosen_build_mode {
        task = "Choose Build Configuration";
    } else if chosen_console_commands {
        task = "Choose Console Commands";
    }
    window := SDL_CreateWindow(temp_c_string(tprint("Prism Builder: %", task)), SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 1280, 720, SDL_WINDOW_OPENGL|SDL_WINDOW_RESIZABLE);
    if window == null {
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return;
    }

    //SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    //SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);

    gl_context := SDL_GL_CreateContext(window);
    if !gl_context {
        print( "Could not create OpenGL context: %\n", to_string(SDL_GetError()));
        return;
    }

    gl_load(*gl, SDL_GL_GetProcAddress);
    //using gl;

    imgui_context := ImGui.CreateContext();

    // Setup ImGui binding
    ImGui_ImplSdl_Init(window);

    // Setup style
    ImGui.StyleColorsDark();
    ImGui.GetStyle().WindowRounding = 0;

    io := ImGui.GetIO();

    clear_color := rgba(0.45, 0.55, 0.60, 1.00);


    enable_console_command : [..]bool;
    sweep_hover_console_command : [..]bool;
    sweep_state : Checkbox_Sweep_Mode_State;
    defer array_reset(*enable_console_command);
    defer array_reset(*sweep_hover_console_command);
    if chosen_console_commands {
        quick_sort(<<chosen_console_commands, (a, b) => compare_strings(a.name, b.name));
        for <<chosen_console_commands {
            array_add(*enable_console_command, true);
            array_add(*sweep_hover_console_command, false);
        }
    }

    done := false;
    while !done {
        event: SDL_Event;
        while SDL_PollEvent(*event) {
            ImGui_ImplSdl_ProcessEvent(*event);
            if event.type == SDL_QUIT done = true;
            if event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_CLOSE && event.window.windowID == SDL_GetWindowID(window) {
                done = true;
            }
        }
        ImGui_ImplSdl_NewFrame(window);
        ImGui.NewFrame();

        {
            ImGui.SetNextWindowPos(.{0, 0});
            ImGui.SetNextWindowSize(ImGui.GetIO().DisplaySize);
            ImGui.Begin("UI", null, flags = ImGui.WindowFlags.NoResize | .NoTitleBar);
            defer ImGui.End();

            if chosen_console_commands {
                for command, command_index : <<chosen_console_commands {
                    // ImGui.Checkbox(imgui_label(command.name, *command), *enable_console_command[command_index]);
                    checkbox_press_or_sweep_to_toggle(*enable_console_command[command_index], *sweep_hover_console_command[command_index], imgui_label(command.name, *command), *sweep_state, window);
                }
            }

            if chosen_build_mode {
                inspect("Chosen Build Mode (Auto Generated UI)", chosen_build_mode);
            }

            if ImGui.Button("Submit") {
                done = true;
                if chosen_console_commands {
                    assert(chosen_console_commands.count == enable_console_command.count);
                    for command, command_index : <<chosen_console_commands {
                        if enable_console_command[command_index] == false {
                            enable_console_command[command_index], enable_console_command[chosen_console_commands.count-1]
                            = swap(enable_console_command[command_index], enable_console_command[chosen_console_commands.count-1]);
                            remove command;
                        }
                    }
                }
            }
            ImGui.SameLine();
            if ImGui.Button("Abort") {
                compiler_report("Compilation manually aborted.");
            }

            ImGui.Text("% ms/frame (% FPS)", formatFloat(1000.0 / io.Framerate, trailing_width=3), formatFloat(io.Framerate, trailing_width=1, zero_removal=.NO));
        }

        // Rendering
        ImGui.Render();
        glViewport(0, 0, xx io.DisplaySize.x, xx io.DisplaySize.y);
        glClearColor(clear_color.x, clear_color.y, clear_color.z, clear_color.w);
        glClear(GL_COLOR_BUFFER_BIT);
        ImGui_ImplSdl_RenderDrawLists(ImGui.GetDrawData());
        SDL_GL_SwapWindow(window);

        reset_temporary_storage();
    }

    // Cleanup
    ImGui_ImplSdl_Shutdown();
    ImGui.DestroyContext(imgui_context);
    SDL_GL_DeleteContext(gl_context);
    SDL_DestroyWindow(window);
    SDL_Quit();
}


#load "imgui_sdl_gl.jai";
#load "inspector.jai";

fit_scene_on_screen :: () {} // @Hack needed for checkbox sweeping... sigh
#load "carpet.jai";