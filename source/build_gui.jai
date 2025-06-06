build_gui :: (
    preset_build_options : Table(string, Build_Options), // @Unused?
    chosen_build_options : *Build_Options = null,
    chosen_console_commands : *[..]*Code_Procedure_Header = null)
{
    if (chosen_build_options == null && chosen_console_commands == null) ||
       (chosen_build_options != null && chosen_console_commands != null) {
        compiler_report("build_gui expected to set exactly one of build options or console commands");
    }

    SDL_Init(SDL_INIT_VIDEO);

    task : string;
    if chosen_build_options {
        task = "Configure Build Options";
    } else if chosen_console_commands {
        task = "Configure Console Commands";
    }
    window := SDL_CreateWindow(temp_c_string(tprint("Prizm Builder: %", task)), SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 1280, 720, SDL_WINDOW_OPENGL|SDL_WINDOW_RESIZABLE);
    if window == null {
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return;
    }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);

    gl_context := SDL_GL_CreateContext(window);
    if !gl_context {
        print( "Could not create OpenGL context: %\n", to_string(SDL_GetError()));
        return;
    }

    gl_load(*gl, SDL_GL_GetProcAddress);
    //using gl;

    // Setup Dear ImGui context
    // IMGUI_CHECKVERSION();
    ImGui_Impl_CreateContext();
    assert(imgui_context != null, "must call create context");
    ImGui.SetCurrentContext(imgui_context);

    // Setup Platform/Renderer backends
    ImGui_ImplSDL2_InitForOpenGL(window, gl_context);
    ImGui_ImplOpenGL3_Init("#version 130");

    // Setup style
    ImGui.StyleColorsDark();
    ImGui.GetStyle().WindowRounding = 0;

    io := ImGui.GetIO();

    clear_color := rgba(0.45, 0.55, 0.60, 1.00);


    enable_console_command : [..]bool;
    defer array_reset(*enable_console_command);
    if chosen_console_commands {
        quick_sort(chosen_console_commands.*, (a, b) => compare_strings(a.name, b.name));
        for chosen_console_commands.* {
            array_add(*enable_console_command, true);
        }
    }

    done := false;
    while !done {
        event: SDL_Event;
        while SDL_PollEvent(*event) {
            ImGui_ImplSDL2_ProcessEvent(*event);

            if event.type == SDL_QUIT {
                compiler_report("Compilation manually aborted.");
            }
            if event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_CLOSE && event.window.windowID == SDL_GetWindowID(window) {
                done = true;
            }
        }

        // Start the Dear ImGui frame
        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplSDL2_NewFrame();
        ImGui.NewFrame();

        {
            ImGui.SetNextWindowPos(.{0, 0});
            ImGui.SetNextWindowSize(ImGui.GetIO().DisplaySize);
            ImGui.Begin("UI", null, flags = ImGui.WindowFlags.NoResize | .NoTitleBar);
            defer ImGui.End();

            if chosen_console_commands {
                for command, command_index : chosen_console_commands.* {
                    ImGui.Checkbox(imgui_label(command.name, *command), *enable_console_command[command_index]);
                }
            }

            if chosen_build_options {
                using chosen_build_options;

                // @Refactor This can lookup a string in the Build_Options struct using reflection, so usage can be Check_Box("optimization_level"), and we insert the string as code, too
                // Note: Use of get_ident_name is only possible at compile-time, so this code
                // cannot be used at runtime which precludes debugging except via the bytecode
                // debugger

                Combo_Box :: (code : Code) -> bool #expand {
                    return combo_box(get_ident_name(code), *#insert,scope() code, type_info(type_of(#insert,scope() code)));
                }

                Check_Box :: (code : Code) -> bool #expand {
                    return ImGui.Checkbox(temp_c_string(get_ident_name(code)), *#insert,scope() code);
                }

                Input_Int :: (code : Code) -> bool #expand {
                    return ImGui.InputInt(temp_c_string(get_ident_name(code)), *#insert,scope() code);
                }

                //output_type : enum;
                // Combo_Box(optimization_level); // Commented out when upgrading to jai version 0.1.064

                Check_Box(write_added_strings);
                Check_Box(runtime_storageless_type_info);
                Check_Box(shorten_filenames_in_error_messages);
                Check_Box(use_visual_studio_message_format);
                //use_custom_link_command : bool
                Check_Box(lazy_foreign_function_lookups);
                Check_Box(enable_bytecode_inliner);
                Check_Box(stack_trace);

                Combo_Box(array_bounds_check);
                Combo_Box(cast_bounds_check);
                Combo_Box(arithmetic_overflow_check);
                Combo_Box(null_pointer_check);
                Combo_Box(dead_code_elimination);

                // // @CompilerBug Using any InputText widgets causes compilation to crash in realloc, but the same code works at runtime
                // InputText("output_executable_name", *output_executable_name, .EnterReturnsTrue); show_tooltip("Unpathed, does not include extension such as \".exe\"");
                // InputText("output_path", *output_path, .EnterReturnsTrue);
                // InputText("intermediate_path", *intermediate_path, .EnterReturnsTrue); show_tooltip("The place for temporary files, such as .added_strings_*, intermediate object files, etc.");
                // InputText("entry_point_name", *entry_point_name, .EnterReturnsTrue);

                Input_Int(temporary_storage_size);
                //info_flags : enum_flags;
                //text_output_flags : enum_flags;
                //os_target := OS;
                Combo_Box(#code backend);
                //machine_type: enum;
                //machine_options: Machine_Options;
                Combo_Box(#code emit_debug_info);
                //maximum_polymorph_depth := 100;
                //maximum_array_count_before_compile_time_returns_are_not_reflected_in_ast := 5000;
                //import_path: [] string;
                //additional_linker_arguments: [] string;
                //user_data_u64:          u64;
                //user_data_string:       string;
                //user_data_pointer:      *void;
                //user_data_pointer_size: s32;
                //x64_options:  X64_Options;
                //llvm_options: Llvm_Options;

                inspect("Chosen Build Options (Auto Generated UI)", chosen_build_options);
            }

            if ImGui.Button("Submit") {
                done = true;
                if chosen_console_commands {
                    assert(chosen_console_commands.count == enable_console_command.count);
                    for command, command_index : chosen_console_commands.* {
                        if enable_console_command[command_index] == false {
                            enable_console_command[command_index], enable_console_command[chosen_console_commands.count-1]
                            = enable_console_command[chosen_console_commands.count-1], enable_console_command[command_index];
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
        ImGui_ImplOpenGL3_RenderDrawData(ImGui.GetDrawData());

        glViewport(0, 0, xx io.DisplaySize.x, xx io.DisplaySize.y);
        glClearColor(clear_color.x, clear_color.y, clear_color.z, clear_color.w);
        glClear(GL_COLOR_BUFFER_BIT);

        SDL_GL_SwapWindow(window);

        reset_temporary_storage();
    }

    // Cleanup
    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplSDL2_Shutdown();
    ImGui.DestroyContext();

    SDL_GL_DeleteContext(gl_context);
    SDL_DestroyWindow(window);
    SDL_Quit();
}

imgui_context : *ImGui.ImGuiContext;

_imgui_alloc_context: #Context;

c_alloc :: (sz: u64, userdata: *void) -> *void #c_call {
    push_context (cast(*#Context)userdata).* {
        return alloc(cast(s64)sz);
    }
}

c_free :: (ptr: *void, userdata: *void) -> void #c_call {
    push_context (cast(*#Context)userdata).* {
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


// @Volatile! Do not share code with runtime Prizm app, since that code often uses the App global which does not exist in this build gui
#load "imgui_impl_sdl.jai"; // SDL platform backend
#load "imgui_impl_opengl3.jai"; // OpenGL renderer backend
#load "inspector.jai";

ImGui :: #import "ImGui";
#import "SDL";
#import "Math";


fit_scene_on_screen :: () {} // @Hack needed for checkbox sweeping... sigh

imgui_label :: (label : string, ptr : *void = null) -> *u8 {
    return temp_c_string(tprint("%##%", label, ptr));
}

// Combo box to select display mode enum value
// @Cleanup Deduce the info_enum from the data
combo_box :: (label : string, data: *void, info_enum: *Type_Info_Enum, flags : ImGui.ComboFlags = .None) -> bool {
    changed := false;
    value := get_enum_value(data, info_enum);
    value_name := "";
    for info_enum.names {
        if value == info_enum.values[it_index]  value_name = it;
    }
    if ImGui.BeginCombo(imgui_label(label, data), temp_c_string(value_name), flags) {
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