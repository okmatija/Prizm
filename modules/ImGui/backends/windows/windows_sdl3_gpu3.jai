//
// This file was auto-generated using the following command:
//
// jai generate.jai - -backend_sdl3_gpu3
//



// Follow "Getting Started" link and check examples/ folder to learn about using backends!
ImplSDL3_InitForOpenGL :: (window: *SDL_Window, sdl_gl_context: *void) -> bool #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDL3_InitForOpenGL@@YA_NPEAUSDL_Window@@PEAX@Z";
ImplSDL3_InitForVulkan :: (window: *SDL_Window) -> bool #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDL3_InitForVulkan@@YA_NPEAUSDL_Window@@@Z";
ImplSDL3_InitForD3D :: (window: *SDL_Window) -> bool #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDL3_InitForD3D@@YA_NPEAUSDL_Window@@@Z";
ImplSDL3_InitForMetal :: (window: *SDL_Window) -> bool #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDL3_InitForMetal@@YA_NPEAUSDL_Window@@@Z";
ImplSDL3_InitForSDLRenderer :: (window: *SDL_Window, renderer: *SDL_Renderer) -> bool #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDL3_InitForSDLRenderer@@YA_NPEAUSDL_Window@@PEAUSDL_Renderer@@@Z";
ImplSDL3_InitForSDLGPU :: (window: *SDL_Window) -> bool #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDL3_InitForSDLGPU@@YA_NPEAUSDL_Window@@@Z";
ImplSDL3_InitForOther :: (window: *SDL_Window) -> bool #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDL3_InitForOther@@YA_NPEAUSDL_Window@@@Z";
ImplSDL3_Shutdown :: () -> void #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDL3_Shutdown@@YAXXZ";
ImplSDL3_NewFrame :: () -> void #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDL3_NewFrame@@YAXXZ";
ImplSDL3_ProcessEvent :: (event: *SDL_Event) -> bool #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDL3_ProcessEvent@@YA_NPEBTSDL_Event@@@Z";

// Gamepad selection automatically starts in AutoFirst mode, picking first available SDL_Gamepad. You may override this.
// When using manual mode, caller is responsible for opening/closing gamepad.
ImplSDL3_GamepadMode :: enum s32 {
    AutoFirst :: 0;
    AutoAll   :: 1;
    Manual    :: 2;
    ImGui_ImplSDL3_GamepadMode_AutoFirst :: AutoFirst;
    ImGui_ImplSDL3_GamepadMode_AutoAll   :: AutoAll;
    ImGui_ImplSDL3_GamepadMode_Manual    :: Manual;
}
ImplSDL3_SetGamepadMode :: (mode: ImplSDL3_GamepadMode, manual_gamepads_array: **SDL_Gamepad = null, manual_gamepads_count: s32 = -1) -> void #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDL3_SetGamepadMode@@YAXW4ImGui_ImplSDL3_GamepadMode@@PEAPEAUSDL_Gamepad@@H@Z";

// (Advanced, for X11 users) Override Mouse Capture mode. Mouse capture allows receiving updated mouse position after clicking inside our window and dragging outside it.
// Having this 'Enabled' is in theory always better. But, on X11 if you crash/break to debugger while capture is active you may temporarily lose access to your mouse.
// The best solution is to setup your debugger to automatically release capture, e.g. 'setxkbmap -option grab:break_actions && xdotool key XF86Ungrab' or via a GDB script. See #3650.
// But you may independently decide on X11, when a debugger is attached, to set this value to ImGui_ImplSDL3_MouseCaptureMode_Disabled.
ImplSDL3_MouseCaptureMode :: enum s32 {
    Enabled          :: 0;
    EnabledAfterDrag :: 1;
    Disabled         :: 2;
    ImGui_ImplSDL3_MouseCaptureMode_Enabled          :: Enabled;
    ImGui_ImplSDL3_MouseCaptureMode_EnabledAfterDrag :: EnabledAfterDrag;
    ImGui_ImplSDL3_MouseCaptureMode_Disabled         :: Disabled;
}
ImplSDL3_SetMouseCaptureMode :: (mode: ImplSDL3_MouseCaptureMode) -> void #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDL3_SetMouseCaptureMode@@YAXW4ImGui_ImplSDL3_MouseCaptureMode@@@Z";

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
ImplSDLGPU3_Init :: (info: *ImplSDLGPU3_InitInfo) -> bool #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDLGPU3_Init@@YA_NPEAUImGui_ImplSDLGPU3_InitInfo@@@Z";
ImplSDLGPU3_Shutdown :: () -> void #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDLGPU3_Shutdown@@YAXXZ";
ImplSDLGPU3_NewFrame :: () -> void #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDLGPU3_NewFrame@@YAXXZ";
ImplSDLGPU3_PrepareDrawData :: (draw_data: *ImDrawData, command_buffer: *SDL_GPUCommandBuffer) -> void #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDLGPU3_PrepareDrawData@@YAXPEAUImDrawData@@PEAUSDL_GPUCommandBuffer@@@Z";
ImplSDLGPU3_RenderDrawData :: (draw_data: *ImDrawData, command_buffer: *SDL_GPUCommandBuffer, render_pass: *SDL_GPURenderPass, pipeline: *SDL_GPUGraphicsPipeline = null) -> void #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDLGPU3_RenderDrawData@@YAXPEAUImDrawData@@PEAUSDL_GPUCommandBuffer@@PEAUSDL_GPURenderPass@@PEAUSDL_GPUGraphicsPipeline@@@Z";

// Use if you want to reset your rendering device without losing Dear ImGui state.
ImplSDLGPU3_CreateDeviceObjects :: () -> void #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDLGPU3_CreateDeviceObjects@@YAXXZ";
ImplSDLGPU3_DestroyDeviceObjects :: () -> void #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDLGPU3_DestroyDeviceObjects@@YAXXZ";

// (Advanced) Use e.g. if you need to precisely control the timing of texture updates (e.g. for staged rendering), by setting ImDrawData::Textures = nullptr to handle this manually.
ImplSDLGPU3_UpdateTexture :: (tex: *ImTextureData) -> void #foreign imgui_sdl3_gpu3 "?ImGui_ImplSDLGPU3_UpdateTexture@@YAXPEAUImTextureData@@@Z";

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

imgui_sdl3_gpu3 :: #library,no_dll "ImGui_sdl3_gpu3.static";
