#import "sdl3";
#import "Basic";
#import "freetype";

// Import the imgui module (usually just '#import "imgui')
#import,file "../module.jai";

// Load the backend(s) you want. This *must* be #load because they might rely on other libraries.
// In this case, sdl3_gpu3 relies on types from "sdl3", so by importing sdl3 and loading imgui, imgui
// gets access to the types it needs.
#load "../backends/sdl3_gpu3.jai";

#load "../misc/freetype/freetype.jai";

// Calls SDL_GetError then SDL_ClearError
//
// The returned string is owned by SDL and only valid
// until the next SDL call
consume_sdl_error :: () -> string {
    data := SDL_GetError();
    SDL_ClearError();
    return to_string(data);
}

ok_or_exit :: inline (success: bool, err_msg_format: string, args: ..Any, flags := Log_Flags.ERROR, exit_code : s32 = 1) {

    if success return;

    log(err_msg_format, ..args, flags=flags);
    exit(exit_code);
} @PrintLike

DEBUG :: true;

main :: () {

    // Keep freetype from being removed by the compiler
    FT_Error_String(0);

    // Setup window and gpu using the SDL3_GPU3 backend.
    // This is based on the 'example_sdl3_sdlgpu3' Dear ImGui example, which you can find on their repo.
    success := SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD | SDL_INIT_AUDIO);
    ok_or_exit(success, "failed to init sdl3 with error = %", consume_sdl_error());

    win_scale := SDL_GetDisplayContentScale(SDL_GetPrimaryDisplay());
    window := SDL_CreateWindow("Overlord Systems", (1920 * win_scale).(s32), (1080 * win_scale).(s32), SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIDDEN | SDL_WINDOW_HIGH_PIXEL_DENSITY);
    ok_or_exit(window != null, "failed to create window with error = %", consume_sdl_error());

    SDL_SetWindowPosition(window, xx SDL_WINDOWPOS_CENTERED(), xx SDL_WINDOWPOS_CENTERED());
    SDL_ShowWindow(window);

    gpu_device := SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_SPIRV | SDL_GPU_SHADERFORMAT_DXIL | SDL_GPU_SHADERFORMAT_METALLIB, DEBUG, null);
    ok_or_exit(gpu_device != null, "failed to create gpu device with error = %", consume_sdl_error());

    success = SDL_ClaimWindowForGPUDevice(gpu_device, window);
    ok_or_exit(success, "failed to claim window with title '%' for gpu device with error = %", to_string(SDL_GetWindowTitle(window)), consume_sdl_error());

    success = SDL_SetGPUSwapchainParameters(gpu_device, window, .SDR, .VSYNC);
    ok_or_exit(success, "failed to set swapchain parameters with error = %", consume_sdl_error());

    // Setup ImGui
    success = DebugCheckVersionAndDataLayout(IMGUI_VERSION, size_of(IO), size_of(Style), size_of(ImVec2), size_of(ImVec4), size_of(ImDrawVert), size_of(ImDrawIdx));
    ok_or_exit(success, "failed imgui DebugCheckVersionAndDataLayout");

    ctx := CreateContext();
    io := GetIO();

    // Enable freetype rendering
    io.Fonts.SetFontLoader(io.Fonts, FreeType.GetFontLoader());

    // Other IO setup
    io.ConfigFlags_ |= .DockingEnable | .ViewportsEnable | .DpiEnableScaleViewports | .DpiEnableScaleFonts | .NavEnableKeyboard | .NavEnableGamepad;

    StyleColorsDark();

    // When viewports are enabled we tweak WindowRounding/WindowBg so platform windows can look identical to regular ones.
    style := GetStyle();
    if io.ConfigFlags_ & .ViewportsEnable {
        style.WindowRounding = 0;
        style.Colors[Col.WindowBg].w = 1;
    }

    style.ScaleAllSizes(style, win_scale);   // Bake a fixed style scale. (until we have a solution for dynamic style scaling, changing this requires resetting Style + calling this again)
    style.FontScaleMain = win_scale;
    style.FontScaleDpi = win_scale;   // Set initial font scale. (in docking branch: using io.ConfigDpiScaleFonts=true automatically overrides this for every window depending on the current monitor)

    io.ConfigDpiScaleFonts = true;     // [Experimental] Automatically overwrite style.FontScaleDpi in Begin() when Monitor DPI changes. This will scale fonts but _NOT_ scale sizes/padding for now.
    io.ConfigDpiScaleViewports = true; // [Experimental] Scale Dear ImGui and Platform Windows when Monitor DPI changes.

    // Setup imgui sdl3_gpu3 backend
    success = ImplSDL3_InitForSDLGPU(window);
    ok_or_exit(success, "failed to InitForSDLGPU with error = %", consume_sdl_error());

    init_info := ImplSDLGPU3_InitInfo.{
        Device = gpu_device,
        ColorTargetFormat = SDL_GetGPUSwapchainTextureFormat(gpu_device, window),
        MSAASamples = .SDL_GPU_SAMPLECOUNT_1,
        SwapchainComposition = .SDL_GPU_SWAPCHAINCOMPOSITION_SDR,
        PresentMode = .SDL_GPU_PRESENTMODE_VSYNC,
    };

    success = ImplSDLGPU3_Init(*init_info);
    ok_or_exit(success, "failed to init SDLGPU3 with error = %", consume_sdl_error());

    // Program loop
    is_running := true;
    clear_color := SDL_FColor.{ a=1};

    while is_running {

        //
        // Frame start
        //
        ev: SDL_Event;
        while(SDL_PollEvent(*ev)) {

            // Send events to imgui through the backend, then do our processing
            event_consumed := ImplSDL3_ProcessEvent(*ev);

            if ev.type.(SDL_EventType) == {

                case SDL_EventType.QUIT;
                    is_running = false;

                case SDL_EventType.KEY_DOWN;
                    if ev.key.key == SDLK_ESCAPE
                        is_running = false;

                case SDL_EventType.WINDOW_CLOSE_REQUESTED;
                    if ev.window.windowID == SDL_GetWindowID(window)
                        is_running = false;
                case;
            }
        }

        //
        // Frame logic
        //

        // Slow down rendering when minimized to not waste power
        if SDL_GetWindowFlags(window) & SDL_WINDOW_MINIMIZED {
            sleep_milliseconds(16);
            continue;
        }

        // Start new imgui frame
        ImplSDLGPU3_NewFrame();
        ImplSDL3_NewFrame();
        NewFrame();

        // Draw whatever we want
        ShowDemoWindow();

        //
        // Rendering
        //

        // Render imgui
        Render();
        draw_data := GetDrawData();
        is_minimized := (draw_data.DisplaySize.x <= 0 || draw_data.DisplaySize.y <= 0);

        // Acquire a GPU command buffer and swapchain texture
        cmd_buffer := SDL_AcquireGPUCommandBuffer(gpu_device);

        swapchain_texture: *SDL_GPUTexture;
        success = SDL_AcquireGPUSwapchainTexture(cmd_buffer, window, *swapchain_texture, null, null);

        // If all good we will do a render pass that draws the UI
        if swapchain_texture && !is_minimized {

            // This must be done first when using this backend to upload imgui vertex data
            ImplSDLGPU3_PrepareDrawData(draw_data, cmd_buffer);

            // Setup render pass and start it
            target_info := SDL_GPUColorTargetInfo.{
                texture = swapchain_texture,
                clear_color = clear_color,
                load_op = .CLEAR,
                store_op = .STORE,
                mip_level = 0,
                layer_or_depth_plane = 0,
                cycle = false,
            };

            render_pass := SDL_BeginGPURenderPass(cmd_buffer, *target_info, 1, null);

            // Draw things. Here, we only have imgui
            ImplSDLGPU3_RenderDrawData(draw_data, cmd_buffer, render_pass);

            // End render pass
            SDL_EndGPURenderPass(render_pass);
        }

        // Update and Render additional Platform Windows
        if io.ConfigFlags_ & .ViewportsEnable {
            UpdatePlatformWindows();
            RenderPlatformWindowsDefault();
        }

        // Finally, we send to GPU to draw
        SDL_SubmitGPUCommandBuffer(cmd_buffer);
    }

    //
    // Cleanup and app shutdown
    //

    SDL_WaitForGPUIdle(gpu_device);

    // Cleanup imgui
    ImplSDL3_Shutdown();
    ImplSDLGPU3_Shutdown();
    DestroyContext(ctx);

    // Cleanup sdl
    SDL_ReleaseWindowFromGPUDevice(gpu_device, window);
    SDL_DestroyGPUDevice(gpu_device);
    SDL_DestroyWindow(window);
    SDL_Quit();
}
