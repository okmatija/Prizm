//
// This file was auto-generated using the following command:
//
// jai generate.jai - -backend_sdl3_gpu3
//



// Follow "Getting Started" link and check examples/ folder to learn about using backends!
ImplSDL3_InitForOpenGL :: (window: *SDL_Window, sdl_gl_context: *void) -> bool #foreign imgui_sdl3_gpu3 "_Z28ImGui_ImplSDL3_InitForOpenGLP10SDL_WindowPv";
ImplSDL3_InitForVulkan :: (window: *SDL_Window) -> bool #foreign imgui_sdl3_gpu3 "_Z28ImGui_ImplSDL3_InitForVulkanP10SDL_Window";
ImplSDL3_InitForD3D :: (window: *SDL_Window) -> bool #foreign imgui_sdl3_gpu3 "_Z25ImGui_ImplSDL3_InitForD3DP10SDL_Window";
ImplSDL3_InitForMetal :: (window: *SDL_Window) -> bool #foreign imgui_sdl3_gpu3 "_Z27ImGui_ImplSDL3_InitForMetalP10SDL_Window";
ImplSDL3_InitForSDLRenderer :: (window: *SDL_Window, renderer: *SDL_Renderer) -> bool #foreign imgui_sdl3_gpu3 "_Z33ImGui_ImplSDL3_InitForSDLRendererP10SDL_WindowP12SDL_Renderer";
ImplSDL3_InitForSDLGPU :: (window: *SDL_Window) -> bool #foreign imgui_sdl3_gpu3 "_Z28ImGui_ImplSDL3_InitForSDLGPUP10SDL_Window";
ImplSDL3_InitForOther :: (window: *SDL_Window) -> bool #foreign imgui_sdl3_gpu3 "_Z27ImGui_ImplSDL3_InitForOtherP10SDL_Window";
ImplSDL3_Shutdown :: () -> void #foreign imgui_sdl3_gpu3 "_Z23ImGui_ImplSDL3_Shutdownv";
ImplSDL3_NewFrame :: () -> void #foreign imgui_sdl3_gpu3 "_Z23ImGui_ImplSDL3_NewFramev";
ImplSDL3_ProcessEvent :: (event: *SDL_Event) -> bool #foreign imgui_sdl3_gpu3 "_Z27ImGui_ImplSDL3_ProcessEventPK9SDL_Event";

// Gamepad selection automatically starts in AutoFirst mode, picking first available SDL_Gamepad. You may override this.
// When using manual mode, caller is responsible for opening/closing gamepad.
ImplSDL3_GamepadMode :: enum u32 {
    AutoFirst :: 0;
    AutoAll   :: 1;
    Manual    :: 2;
    ImGui_ImplSDL3_GamepadMode_AutoFirst :: AutoFirst;
    ImGui_ImplSDL3_GamepadMode_AutoAll   :: AutoAll;
    ImGui_ImplSDL3_GamepadMode_Manual    :: Manual;
}
ImplSDL3_SetGamepadMode :: (mode: ImplSDL3_GamepadMode, manual_gamepads_array: **SDL_Gamepad = null, manual_gamepads_count: s32 = -1) -> void #foreign imgui_sdl3_gpu3 "_Z29ImGui_ImplSDL3_SetGamepadMode26ImGui_ImplSDL3_GamepadModePP11SDL_Gamepadi";

// (Advanced, for X11 users) Override Mouse Capture mode. Mouse capture allows receiving updated mouse position after clicking inside our window and dragging outside it.
// Having this 'Enabled' is in theory always better. But, on X11 if you crash/break to debugger while capture is active you may temporarily lose access to your mouse.
// The best solution is to setup your debugger to automatically release capture, e.g. 'setxkbmap -option grab:break_actions && xdotool key XF86Ungrab' or via a GDB script. See #3650.
// But you may independently decide on X11, when a debugger is attached, to set this value to ImGui_ImplSDL3_MouseCaptureMode_Disabled.
ImplSDL3_MouseCaptureMode :: enum u32 {
    Enabled          :: 0;
    EnabledAfterDrag :: 1;
    Disabled         :: 2;
    ImGui_ImplSDL3_MouseCaptureMode_Enabled          :: Enabled;
    ImGui_ImplSDL3_MouseCaptureMode_EnabledAfterDrag :: EnabledAfterDrag;
    ImGui_ImplSDL3_MouseCaptureMode_Disabled         :: Disabled;
}
ImplSDL3_SetMouseCaptureMode :: (mode: ImplSDL3_MouseCaptureMode) -> void #foreign imgui_sdl3_gpu3 "_Z34ImGui_ImplSDL3_SetMouseCaptureMode31ImGui_ImplSDL3_MouseCaptureMode";

// Initialization data, for ImGui_ImplSDLGPU_Init()
// - Remember to set ColorTargetFormat to the correct format. If you're rendering to the swapchain, call SDL_GetGPUSwapchainTextureFormat() to query the right value
ImplSDLGPU3_InitInfo :: struct {
    Device:               *SDL_GPUDevice = null;
    ColorTargetFormat:    SDL_GPUTextureFormat = .SDL_GPU_TEXTUREFORMAT_INVALID;
    MSAASamples:          SDL_GPUSampleCount = .SDL_GPU_SAMPLECOUNT_1;
    SwapchainComposition: SDL_GPUSwapchainComposition = .SDL_GPU_SWAPCHAINCOMPOSITION_SDR; // Only used in multi-viewports mode.
    PresentMode:          SDL_GPUPresentMode = .SDL_GPU_PRESENTMODE_VSYNC; // Only used in multi-viewports mode.
}

// Follow "Getting Started" link and check examples/ folder to learn about using backends!
ImplSDLGPU3_Init :: (info: *ImplSDLGPU3_InitInfo) -> bool #foreign imgui_sdl3_gpu3 "_Z22ImGui_ImplSDLGPU3_InitP26ImGui_ImplSDLGPU3_InitInfo";
ImplSDLGPU3_Shutdown :: () -> void #foreign imgui_sdl3_gpu3 "_Z26ImGui_ImplSDLGPU3_Shutdownv";
ImplSDLGPU3_NewFrame :: () -> void #foreign imgui_sdl3_gpu3 "_Z26ImGui_ImplSDLGPU3_NewFramev";
ImplSDLGPU3_PrepareDrawData :: (draw_data: *ImDrawData, command_buffer: *SDL_GPUCommandBuffer) -> void #foreign imgui_sdl3_gpu3 "_Z33ImGui_ImplSDLGPU3_PrepareDrawDataP10ImDrawDataP20SDL_GPUCommandBuffer";
ImplSDLGPU3_RenderDrawData :: (draw_data: *ImDrawData, command_buffer: *SDL_GPUCommandBuffer, render_pass: *SDL_GPURenderPass, pipeline: *SDL_GPUGraphicsPipeline = null) -> void #foreign imgui_sdl3_gpu3 "_Z32ImGui_ImplSDLGPU3_RenderDrawDataP10ImDrawDataP20SDL_GPUCommandBufferP17SDL_GPURenderPassP23SDL_GPUGraphicsPipeline";

// Use if you want to reset your rendering device without losing Dear ImGui state.
ImplSDLGPU3_CreateDeviceObjects :: () -> void #foreign imgui_sdl3_gpu3 "_Z37ImGui_ImplSDLGPU3_CreateDeviceObjectsv";
ImplSDLGPU3_DestroyDeviceObjects :: () -> void #foreign imgui_sdl3_gpu3 "_Z38ImGui_ImplSDLGPU3_DestroyDeviceObjectsv";

// (Advanced) Use e.g. if you need to precisely control the timing of texture updates (e.g. for staged rendering), by setting ImDrawData::Textures = nullptr to handle this manually.
ImplSDLGPU3_UpdateTexture :: (tex: *ImTextureData) -> void #foreign imgui_sdl3_gpu3 "_Z31ImGui_ImplSDLGPU3_UpdateTextureP13ImTextureData";

// [BETA] Selected render state data shared with callbacks.
// This is temporarily stored in GetPlatformIO().Renderer_RenderState during the ImGui_ImplSDLGPU3_RenderDrawData() call.
// (Please open an issue if you feel you need access to more data)
ImplSDLGPU3_RenderState :: struct {
    Device:         *SDL_GPUDevice;
    SamplerLinear:  *SDL_GPUSampler; // Bilinear filtering sampler
    SamplerNearest: *SDL_GPUSampler; // Nearest/point filtering sampler
    SamplerCurrent: *SDL_GPUSampler; // Current sampler (may be changed by callback)
}

#scope_file

#if OS == .MACOS imgui_sdl3_gpu3 :: #library,no_dll "macos/ImGui_sdl3_gpu3";
#if OS == .LINUX imgui_sdl3_gpu3 :: #library,no_dll "linux/ImGui_sdl3_gpu3";
