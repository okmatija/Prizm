// Phase 0 spike: prove that the ImGui sdl3_gpu3 backend (built vs SDL 3.2.14) works
// correctly against Prizm's SDL 3.4.4 bindings.  No freetype, no viewports — minimal loop.
//
// Build:  /mnt/c/Dev/jai/bin/jai-linux build.jai
// Run:    ./spike

#import "SDL3"(USE_SYSTEM_LIBRARY=false);
#import "Basic";
#import "ImGui";
#load "../modules/ImGui/backends/sdl3_gpu3.jai";

main :: () {
    ok := SDL_Init(SDL_INIT_VIDEO);
    assert(ok, "SDL_Init: %", to_string(SDL_GetError()));

    window := SDL_CreateWindow("Prizm SDL_GPU spike", 1280, 720, SDL_WINDOW_RESIZABLE);
    assert(window != null, "SDL_CreateWindow: %", to_string(SDL_GetError()));

    gpu := SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_SPIRV | SDL_GPU_SHADERFORMAT_DXIL | SDL_GPU_SHADERFORMAT_METALLIB, true, null);
    assert(gpu != null, "SDL_CreateGPUDevice: %", to_string(SDL_GetError()));

    ok = SDL_ClaimWindowForGPUDevice(gpu, window);
    assert(ok, "SDL_ClaimWindowForGPUDevice: %", to_string(SDL_GetError()));

    ok = SDL_SetGPUSwapchainParameters(gpu, window, .SDR, .VSYNC);
    assert(ok, "SDL_SetGPUSwapchainParameters: %", to_string(SDL_GetError()));

    ctx := CreateContext();
    io  := GetIO();
    io.ConfigFlags_ |= .NavEnableKeyboard;
    StyleColorsDark();

    ok = ImplSDL3_InitForSDLGPU(window);
    assert(ok, "ImplSDL3_InitForSDLGPU: %", to_string(SDL_GetError()));

    init_info := ImplSDLGPU3_InitInfo.{
        Device            = gpu,
        ColorTargetFormat = SDL_GetGPUSwapchainTextureFormat(gpu, window),
        MSAASamples       = .SDL_GPU_SAMPLECOUNT_1,
    };
    ok = ImplSDLGPU3_Init(*init_info);
    assert(ok, "ImplSDLGPU3_Init: %", to_string(SDL_GetError()));

    is_running  := true;
    clear_color := SDL_FColor.{r=0.1, g=0.1, b=0.15, a=1};

    while is_running {
        ev: SDL_Event;
        while SDL_PollEvent(*ev) {
            ImplSDL3_ProcessEvent(*ev);
            if ev.type.(SDL_EventType) == {
            case .QUIT;
                is_running = false;
            case .KEY_DOWN;
                if ev.key.key == SDLK_ESCAPE  is_running = false;
            case .WINDOW_CLOSE_REQUESTED;
                if ev.window.windowID == SDL_GetWindowID(window)  is_running = false;
            }
        }

        if SDL_GetWindowFlags(window) & SDL_WINDOW_MINIMIZED {
            sleep_milliseconds(16);
            continue;
        }

        ImplSDLGPU3_NewFrame();
        ImplSDL3_NewFrame();
        NewFrame();
        ShowDemoWindow();
        Render();

        draw_data  := GetDrawData();
        is_min     := draw_data.DisplaySize.x <= 0 || draw_data.DisplaySize.y <= 0;
        cmd        := SDL_AcquireGPUCommandBuffer(gpu);

        swapchain_tex: *SDL_GPUTexture;
        SDL_AcquireGPUSwapchainTexture(cmd, window, *swapchain_tex, null, null);

        if swapchain_tex && !is_min {
            ImplSDLGPU3_PrepareDrawData(draw_data, cmd);

            target := SDL_GPUColorTargetInfo.{
                texture     = swapchain_tex,
                clear_color = clear_color,
                load_op     = .CLEAR,
                store_op    = .STORE,
            };
            pass := SDL_BeginGPURenderPass(cmd, *target, 1, null);
            ImplSDLGPU3_RenderDrawData(draw_data, cmd, pass);
            SDL_EndGPURenderPass(pass);
        }

        SDL_SubmitGPUCommandBuffer(cmd);
    }

    SDL_WaitForGPUIdle(gpu);
    ImplSDL3_Shutdown();
    ImplSDLGPU3_Shutdown();
    DestroyContext(ctx);
    SDL_ReleaseWindowFromGPUDevice(gpu, window);
    SDL_DestroyGPUDevice(gpu);
    SDL_DestroyWindow(window);
    SDL_Quit();
}
