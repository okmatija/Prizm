// dear imgui: Platform Backend for SDL2
// This needs to be used along with a Renderer (e.g. DirectX11, OpenGL3, Vulkan..)
// (Info: SDL2 is a cross-platform general purpose library for handling windows, inputs, graphics context creation, etc.)
// (Prefer SDL 2.0.5+ for full feature support.)

// Implemented features:
//  [X] Platform: Mouse cursor shape and visibility. Disable with 'io.ConfigFlags |= ImGuiConfigFlags_NoMouseCursorChange'.
//  [X] Platform: Clipboard support.
//  [X] Platform: Keyboard arrays indexed using SDL_SCANCODE_* codes, e.g. ImGui::IsKeyPressed(SDL_SCANCODE_SPACE).
//  [X] Platform: Gamepad support. Enabled with 'io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad'.
// Missing features:
//  [ ] Platform: SDL2 handling of IME under Windows appears to be broken and it explicitly disable the regular Windows IME. You can restore Windows IME by compiling SDL with SDL_DISABLE_WINDOWS_IME.

// You can use unmodified imgui_impl_* files in your project. See examples/ folder for examples of using this.
// Prefer including the entire imgui/ repository into your project (either as a copy or as a submodule), and only build the backends you need.
// If you are new to Dear ImGui, read documentation from the docs/ folder + read the top of imgui.cpp.
// Read online: https://github.com/ocornut/imgui/tree/master/docs

// CHANGELOG
// (minor and older changes stripped away, please see git history for details)
//  2021-08-17: Calling io.AddFocusEvent() on SDL_WINDOWEVENT_FOCUS_GAINED/SDL_WINDOWEVENT_FOCUS_LOST.
//  2021-07-29: Inputs: MousePos is correctly reported when the host platform window is hovered but not focused (using SDL_GetMouseFocus() + SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH, requires SDL 2.0.5+)
//  2021-06-29: *BREAKING CHANGE* Removed 'SDL_Window* window' parameter to ImGui_ImplSDL2_NewFrame() which was unnecessary.
//  2021-06-29: Reorganized backend to pull data from a single structure to facilitate usage with multiple-contexts (all g_XXXX access changed to bd->XXXX).
//  2021-03-22: Rework global mouse pos availability check listing supported platforms explicitly, effectively fixing mouse access on Raspberry Pi. (#2837, #3950)
//  2020-05-25: Misc: Report a zero display-size when window is minimized, to be consistent with other backends.
//  2020-02-20: Inputs: Fixed mapping for ImGuiKey_KeyPadEnter (using SDL_SCANCODE_KP_ENTER instead of SDL_SCANCODE_RETURN2).
//  2019-12-17: Inputs: On Wayland, use SDL_GetMouseState (because there is no global mouse state).
//  2019-12-05: Inputs: Added support for ImGuiMouseCursor_NotAllowed mouse cursor.
//  2019-07-21: Inputs: Added mapping for ImGuiKey_KeyPadEnter.
//  2019-04-23: Inputs: Added support for SDL_GameController (if ImGuiConfigFlags_NavEnableGamepad is set by user application).
//  2019-03-12: Misc: Preserve DisplayFramebufferScale when main window is minimized.
//  2018-12-21: Inputs: Workaround for Android/iOS which don't seem to handle focus related calls.
//  2018-11-30: Misc: Setting up io.BackendPlatformName so it can be displayed in the About Window.
//  2018-11-14: Changed the signature of ImGui_ImplSDL2_ProcessEvent() to take a 'const SDL_Event*'.
//  2018-08-01: Inputs: Workaround for Emscripten which doesn't seem to handle focus related calls.
//  2018-06-29: Inputs: Added support for the ImGuiMouseCursor_Hand cursor.
//  2018-06-08: Misc: Extracted imgui_impl_sdl.cpp/.h away from the old combined SDL2+OpenGL/Vulkan examples.
//  2018-06-08: Misc: ImGui_ImplSDL2_InitForOpenGL() now takes a SDL_GLContext parameter.
//  2018-05-09: Misc: Fixed clipboard paste memory leak (we didn't call SDL_FreeMemory on the data returned by SDL_GetClipboardText).
//  2018-03-20: Misc: Setup io.BackendFlags ImGuiBackendFlags_HasMouseCursors flag + honor ImGuiConfigFlags_NoMouseCursorChange flag.
//  2018-02-16: Inputs: Added support for mouse cursors, honoring ImGui::GetMouseCursor() value.
//  2018-02-06: Misc: Removed call to ImGui::Shutdown() which is not available from 1.60 WIP, user needs to call CreateContext/DestroyContext themselves.
//  2018-02-06: Inputs: Added mapping for ImGuiKey_Space.
//  2018-02-05: Misc: Using SDL_GetPerformanceCounter() instead of SDL_GetTicks() to be able to handle very high framerate (1000+ FPS).
//  2018-02-05: Inputs: Keyboard mapping is using scancodes everywhere instead of a confusing mixture of keycodes and scancodes.
//  2018-01-20: Inputs: Added Horizontal Mouse Wheel support.
//  2018-01-19: Inputs: When available (SDL 2.0.4+) using SDL_CaptureMouse() to retrieve coordinates outside of client area when dragging. Otherwise (SDL 2.0.3 and before) testing for SDL_WINDOW_INPUT_FOCUS instead of SDL_WINDOW_MOUSE_FOCUS.
//  2018-01-18: Inputs: Added mapping for ImGuiKey_Insert.
//  2017-08-25: Inputs: MousePos set to -FLT_MAX,-FLT_MAX when mouse is unavailable/missing (instead of -1,-1).
//  2016-10-15: Misc: Added a void* user_data parameter to Clipboard function handlers.

// SDL Data
ImGui_ImplSDL2_Data :: struct
{
    Window : *SDL_Window;
    Time : u64;
    MousePressed : [3]bool;
    MouseCursors : [ImGui.MouseCursor.COUNT]*SDL_Cursor;
    ClipboardTextData : *u8;
    MouseCanUseGlobalState : bool;
};

#scope_file

// Backend data stored in io.BackendPlatformUserData to allow support for multiple Dear ImGui contexts
// It is STRONGLY preferred that you use docking branch with multi-viewports (== single Dear ImGui context + multiple windows) instead of multiple Dear ImGui contexts.
// FIXME: multi-context support is not well tested and probably dysfunctional in this backend.
// FIXME: some shared resources (mouse cursor shape, gamepad) are mishandled when using multi-context.
ImGui_ImplSDL2_GetBackendData :: () -> *ImGui_ImplSDL2_Data 
{
    return ifx ImGui.GetCurrentContext() then cast(*ImGui_ImplSDL2_Data)ImGui.GetIO().BackendPlatformUserData else null;
}

// Functions
ImGui_ImplSDL2_GetClipboardText :: (data : *void) -> *u8 #c_call
{
    // bd := ImGui_ImplSDL2_GetBackendData();
    // if (bd.ClipboardTextData)
    //     SDL_free(bd.ClipboardTextData);
    // bd.ClipboardTextData = SDL_GetClipboardText();
    // return bd.ClipboardTextData;
    // TODO: hide the context in the userdata pointer passed to us
    push_context {
        return SDL_GetClipboardText();
    }
}

ImGui_ImplSDL2_SetClipboardText :: (data : *void, text : *u8) #c_call
{
    // TODO: hide the context in the userdata pointer passed to us
    push_context {
        SDL_SetClipboardText(text);
    }
}

#scope_export

// You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
// - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
// - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
// Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
// If you have multiple SDL events and some of them are not meant to be used by dear imgui, you may need to filter events based on their windowID field.
ImGui_ImplSDL2_ProcessEvent :: (event : *SDL_Event) -> bool
{
    io := ImGui.GetIO();
    bd := ImGui_ImplSDL2_GetBackendData();

    if event.type == {
    case .SDL_MOUSEWHEEL;
            if (event.wheel.x > 0) io.MouseWheelH += 1;
            if (event.wheel.x < 0) io.MouseWheelH -= 1;
            if (event.wheel.y > 0) io.MouseWheel += 1;
            if (event.wheel.y < 0) io.MouseWheel -= 1;
            return true;
    case .SDL_MOUSEBUTTONDOWN;
            if (event.button.button == SDL_BUTTON_LEFT) { bd.MousePressed[0] = true; }
            if (event.button.button == SDL_BUTTON_RIGHT) { bd.MousePressed[1] = true; }
            if (event.button.button == SDL_BUTTON_MIDDLE) { bd.MousePressed[2] = true; }
            return true;
    case .SDL_TEXTINPUT;
            io.AddInputCharactersUTF8(io, xx event.text.text.data);
            return true;
    case .SDL_KEYDOWN; #through;
    case .SDL_KEYUP;
        {
            //@@key := event.key.keysym.sym & ~SDLK_SCANCODE_MASK;
            key := event.key.keysym.sym & (xx ~(1<<30));
            io.KeysDown[key] = (event.type == SDL_KEYDOWN);
            io.KeyShift = ((SDL_GetModState() & KMOD_SHIFT) != 0);
            io.KeyCtrl = ((SDL_GetModState() & KMOD_CTRL) != 0);
            io.KeyAlt = ((SDL_GetModState() & KMOD_ALT) != 0);
#if OS == .WINDOWS {
            io.KeySuper = false;
} else {
            io.KeySuper = ((SDL_GetModState() & KMOD_GUI) != 0);
}
            return true;
        }
    case .SDL_WINDOWEVENT;
            if (event.window.event == .SDL_WINDOWEVENT_FOCUS_GAINED)
                io.AddFocusEvent(io, true);
            else if (event.window.event == .SDL_WINDOWEVENT_FOCUS_LOST)
                io.AddFocusEvent(io, false);
            return true;
    }
    return false;
}

#scope_file

ImGui_ImplSDL2_Init :: (window : *SDL_Window) -> bool
{
    io := ImGui.GetIO();
    assert(io.BackendPlatformUserData == null); // Already initialized a platform backend!

    // Check and store if we are on a SDL backend that supports global mouse position
    // ("wayland" and "rpi" don't support it, but we chose to use a white-list instead of a black-list)
    mouse_can_use_global_state := false;

    // Setup backend capabilities flags
    bd := New(ImGui_ImplSDL2_Data);
    io.BackendPlatformUserData = cast(*void)bd;
    io.BackendPlatformName = "imgui_impl_sdl";
    io.BackendFlags_ |= .HasMouseCursors;       // We can honor GetMouseCursor() values (optional)
    io.BackendFlags_ |= .HasSetMousePos;        // We can honor io.WantSetMousePos requests (optional, rarely used)

    bd.Window = window;
    bd.MouseCanUseGlobalState = mouse_can_use_global_state;

    // Keyboard mapping. Dear ImGui will use those indices to peek into the io.KeysDown[] array.
    io.KeyMap[ImGui.Key.Tab] = xx SDLK_TAB; // SDL_SCANCODE_TAB;
    io.KeyMap[ImGui.Key.LeftArrow] = xx SDL_SCANCODE_LEFT;
    io.KeyMap[ImGui.Key.RightArrow] = xx SDL_SCANCODE_RIGHT;
    io.KeyMap[ImGui.Key.UpArrow] = xx SDL_SCANCODE_UP;
    io.KeyMap[ImGui.Key.DownArrow] = xx SDL_SCANCODE_DOWN;
    io.KeyMap[ImGui.Key.PageUp] = xx SDL_SCANCODE_PAGEUP;
    io.KeyMap[ImGui.Key.PageDown] = xx SDL_SCANCODE_PAGEDOWN;
    io.KeyMap[ImGui.Key.Home] = xx SDL_SCANCODE_HOME;
    io.KeyMap[ImGui.Key.End] = xx SDL_SCANCODE_END;
    io.KeyMap[ImGui.Key.Insert] = xx SDL_SCANCODE_INSERT;
    io.KeyMap[ImGui.Key.Delete] = xx SDLK_DELETE; // SDL_SCANCODE_DELETE;
    io.KeyMap[ImGui.Key.Backspace] = xx SDLK_BACKSPACE; // SDL_SCANCODE_BACKSPACE;
    io.KeyMap[ImGui.Key.Space] = xx SDL_SCANCODE_SPACE;
    io.KeyMap[ImGui.Key.Enter] = xx SDLK_RETURN; // SDL_SCANCODE_RETURN;
    io.KeyMap[ImGui.Key.Escape] = xx SDLK_ESCAPE; // SDL_SCANCODE_ESCAPE;
    io.KeyMap[ImGui.Key.KeyPadEnter] = xx SDL_SCANCODE_KP_ENTER;
    io.KeyMap[ImGui.Key.A] = xx SDLK_a; // SDL_SCANCODE_A;
    io.KeyMap[ImGui.Key.C] = xx SDLK_c; // SDL_SCANCODE_C;
    io.KeyMap[ImGui.Key.V] = xx SDLK_v; // SDL_SCANCODE_V;
    io.KeyMap[ImGui.Key.X] = xx SDLK_x; // SDL_SCANCODE_X;
    io.KeyMap[ImGui.Key.Y] = xx SDLK_y; // SDL_SCANCODE_Y;
    io.KeyMap[ImGui.Key.Z] = xx SDLK_z; // SDL_SCANCODE_Z;

    io.SetClipboardTextFn = ImGui_ImplSDL2_SetClipboardText;
    io.GetClipboardTextFn = ImGui_ImplSDL2_GetClipboardText;
    io.ClipboardUserData = null;

    // Load mouse cursors
    bd.MouseCursors[ImGui.MouseCursor.Arrow] = SDL_CreateSystemCursor(.ARROW);
    bd.MouseCursors[ImGui.MouseCursor.TextInput] = SDL_CreateSystemCursor(.IBEAM);
    // bd.MouseCursors[ImGui.MouseCursor.ResizeAll] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_SIZEALL);
    bd.MouseCursors[ImGui.MouseCursor.ResizeNS] = SDL_CreateSystemCursor(.SIZENS);
    bd.MouseCursors[ImGui.MouseCursor.ResizeEW] = SDL_CreateSystemCursor(.SIZEWE);
    bd.MouseCursors[ImGui.MouseCursor.ResizeNESW] = SDL_CreateSystemCursor(.SIZENESW);
    bd.MouseCursors[ImGui.MouseCursor.ResizeNWSE] = SDL_CreateSystemCursor(.SIZENWSE);
    bd.MouseCursors[ImGui.MouseCursor.Hand] = SDL_CreateSystemCursor(.HAND);
    // bd.MouseCursors[ImGui.MouseCursor.NotAllowed] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_NO);

    info : SDL_SysWMinfo;
    SDL_VERSION(*info.version);
    if (SDL_GetWindowWMInfo(window, *info)) {
        #if OS == .WINDOWS {
            io.ImeWindowHandle = info.info.win.window;
        } else #if OS == .LINUX {
            io.ImeWindowHandle = xx info.info.x11.window;
        }
    }

    return true;
}

#scope_export

ImGui_ImplSDL2_InitForOpenGL :: (window : *SDL_Window, sdl_gl_context : *void) -> bool
{
    // IM_UNUSED(sdl_gl_context); // Viewport branch will need this.
    return ImGui_ImplSDL2_Init(window);
}

ImGui_ImplSDL2_Shutdown :: ()
{
    bd := ImGui_ImplSDL2_GetBackendData();
    assert(bd != null); // No platform backend to shutdown, or already shutdown?
    io := ImGui.GetIO();

    // @Incomplete @Leak Jai port omits this code (as of Jai beta 0.0.098 the SDL module does not provide the SDL_free binding)
    // if (bd.ClipboardTextData)
    //     SDL_free(bd.ClipboardTextData);
    // for cursor_n : 0..(xx ImGui.MouseCursor.Count - 1)
    //     SDL_FreeCursor(bd.MouseCursors[cursor_n]);

    io.BackendPlatformName = null;
    io.BackendPlatformUserData = null;
    free(bd);
}

#scope_file

ImGui_ImplSDL2_UpdateMousePosAndButtons :: ()
{
    bd := ImGui_ImplSDL2_GetBackendData();
    io := ImGui.GetIO();

    mouse_pos_prev := io.MousePos;
    io.MousePos = ImGui.ImVec2.{-FLOAT32_MAX, -FLOAT32_MAX};

    // Update mouse buttons
    mouse_x_local, mouse_y_local : s32;
    mouse_buttons := SDL_GetMouseState(*mouse_x_local, *mouse_y_local);
    io.MouseDown[0] = bd.MousePressed[0] || (mouse_buttons & SDL_BUTTON(SDL_BUTTON_LEFT)) != 0;  // If a mouse press event came, always pass it as "mouse held this frame", so we don't miss click-release events that are shorter than 1 frame.
    io.MouseDown[1] = bd.MousePressed[1] || (mouse_buttons & SDL_BUTTON(SDL_BUTTON_RIGHT)) != 0;
    io.MouseDown[2] = bd.MousePressed[2] || (mouse_buttons & SDL_BUTTON(SDL_BUTTON_MIDDLE)) != 0;
    bd.MousePressed[0], bd.MousePressed[1], bd.MousePressed[2] = false, false, false;

    // Obtain focused and hovered window. We forward mouse input when focused or when hovered (and no other window is capturing)
    // SDL 2.0.3 and non-windowed systems: single-viewport only
    mouse_window := ifx (SDL_GetWindowFlags(bd.Window) & SDL_WINDOW_INPUT_FOCUS) then bd.Window else null;

    if mouse_window == null
       return;

    // Set OS mouse position from Dear ImGui if requested (rarely used, only when ImGuiConfigFlags_NavEnableSetMousePos is enabled by user)
    if io.WantSetMousePos
        SDL_WarpMouseInWindow(bd.Window, cast(s32)mouse_pos_prev.x, cast(s32)mouse_pos_prev.y);

    // Set Dear ImGui mouse position from OS position + get buttons. (this is the common behavior)
    if bd.MouseCanUseGlobalState
    {
        // Single-viewport mode: mouse position in client window coordinates (io.MousePos is (0,0) when the mouse is on the upper-left corner of the app window)
        // Unlike local position obtained earlier this will be valid when straying out of bounds.
        mouse_x_global, mouse_y_global : s32;
        SDL_GetGlobalMouseState(*mouse_x_global, *mouse_y_global);
        window_x, window_y : s32;
        SDL_GetWindowPosition(mouse_window, *window_x, *window_y);
        io.MousePos = ImGui.ImVec2.{xx (mouse_x_global - window_x), xx (mouse_y_global - window_y)};
    }
    else
    {
        io.MousePos = ImGui.ImVec2.{xx mouse_x_local, xx mouse_y_local};
    }
}

#scope_file

ImGui_ImplSDL2_UpdateMouseCursor :: ()
{
    io := ImGui.GetIO();
    if (io.ConfigFlags_ & ImGui.ConfigFlags.NoMouseCursorChange)
        return;
    bd := ImGui_ImplSDL2_GetBackendData();

    imgui_cursor := ImGui.GetMouseCursor();
    if (io.MouseDrawCursor || imgui_cursor == ImGui.MouseCursor.None)
    {
        // Hide OS mouse cursor if imgui is drawing it or if it wants no cursor
        SDL_ShowCursor(xx SDL_FALSE);
    }
    else
    {
        // Show OS mouse cursor
        SDL_SetCursor(ifx bd.MouseCursors[imgui_cursor] then bd.MouseCursors[imgui_cursor] else bd.MouseCursors[ImGui.MouseCursor.Arrow]);
        SDL_ShowCursor(xx SDL_TRUE);
    }
}

ImGui_ImplSDL2_UpdateGamepads :: ()
{
    return; // @Incomplete Jai port omits this code
/*
    ImGuiIO& io = ImGui::GetIO();
    memset(io.NavInputs, 0, sizeof(io.NavInputs));
    if ((io.ConfigFlags & ImGuiConfigFlags_NavEnableGamepad) == 0)
        return;

    // Get gamepad
    SDL_GameController* game_controller = SDL_GameControllerOpen(0);
    if (!game_controller)
    {
        io.BackendFlags &= ~ImGuiBackendFlags_HasGamepad;
        return;
    }

    // Update gamepad inputs
    #define MAP_BUTTON(NAV_NO, BUTTON_NO)       { io.NavInputs[NAV_NO] = (SDL_GameControllerGetButton(game_controller, BUTTON_NO) != 0) ? 1.0f : 0.0f; }
    #define MAP_ANALOG(NAV_NO, AXIS_NO, V0, V1) { float vn = (float)(SDL_GameControllerGetAxis(game_controller, AXIS_NO) - V0) / (float)(V1 - V0); if (vn > 1.0f) vn = 1.0f; if (vn > 0.0f && io.NavInputs[NAV_NO] < vn) io.NavInputs[NAV_NO] = vn; }
    const int thumb_dead_zone = 8000;           // SDL_gamecontroller.h suggests using this value.
    MAP_BUTTON(ImGuiNavInput_Activate,      SDL_CONTROLLER_BUTTON_A);               // Cross / A
    MAP_BUTTON(ImGuiNavInput_Cancel,        SDL_CONTROLLER_BUTTON_B);               // Circle / B
    MAP_BUTTON(ImGuiNavInput_Menu,          SDL_CONTROLLER_BUTTON_X);               // Square / X
    MAP_BUTTON(ImGuiNavInput_Input,         SDL_CONTROLLER_BUTTON_Y);               // Triangle / Y
    MAP_BUTTON(ImGuiNavInput_DpadLeft,      SDL_CONTROLLER_BUTTON_DPAD_LEFT);       // D-Pad Left
    MAP_BUTTON(ImGuiNavInput_DpadRight,     SDL_CONTROLLER_BUTTON_DPAD_RIGHT);      // D-Pad Right
    MAP_BUTTON(ImGuiNavInput_DpadUp,        SDL_CONTROLLER_BUTTON_DPAD_UP);         // D-Pad Up
    MAP_BUTTON(ImGuiNavInput_DpadDown,      SDL_CONTROLLER_BUTTON_DPAD_DOWN);       // D-Pad Down
    MAP_BUTTON(ImGuiNavInput_FocusPrev,     SDL_CONTROLLER_BUTTON_LEFTSHOULDER);    // L1 / LB
    MAP_BUTTON(ImGuiNavInput_FocusNext,     SDL_CONTROLLER_BUTTON_RIGHTSHOULDER);   // R1 / RB
    MAP_BUTTON(ImGuiNavInput_TweakSlow,     SDL_CONTROLLER_BUTTON_LEFTSHOULDER);    // L1 / LB
    MAP_BUTTON(ImGuiNavInput_TweakFast,     SDL_CONTROLLER_BUTTON_RIGHTSHOULDER);   // R1 / RB
    MAP_ANALOG(ImGuiNavInput_LStickLeft,    SDL_CONTROLLER_AXIS_LEFTX, -thumb_dead_zone, -32768);
    MAP_ANALOG(ImGuiNavInput_LStickRight,   SDL_CONTROLLER_AXIS_LEFTX, +thumb_dead_zone, +32767);
    MAP_ANALOG(ImGuiNavInput_LStickUp,      SDL_CONTROLLER_AXIS_LEFTY, -thumb_dead_zone, -32767);
    MAP_ANALOG(ImGuiNavInput_LStickDown,    SDL_CONTROLLER_AXIS_LEFTY, +thumb_dead_zone, +32767);

    io.BackendFlags |= ImGuiBackendFlags_HasGamepad;
    #undef MAP_BUTTON
    #undef MAP_ANALOG
*/
}

#scope_export

ImGui_ImplSDL2_NewFrame :: ()
{
    bd := ImGui_ImplSDL2_GetBackendData();
    assert(bd != null); // Did you call ImGui_ImplSDL2_Init()?
    io := ImGui.GetIO();

    // Setup display size (every frame to accommodate for window resizing)
    w, h : s32;
    display_w, display_h : s32;
    SDL_GetWindowSize(bd.Window, *w, *h);
    if (SDL_GetWindowFlags(bd.Window) & SDL_WINDOW_MINIMIZED)
        w, h = 0, 0;
    SDL_GL_GetDrawableSize(bd.Window, *display_w, *display_h);
    io.DisplaySize = ImGui.ImVec2.{xx w, xx h};
    if (w > 0 && h > 0)
        io.DisplayFramebufferScale = ImGui.ImVec2.{cast(float)display_w / w, cast(float)display_h / h};

    // Setup time step (we don't use SDL_GetTicks() because it is using millisecond resolution)
    frequency := SDL_GetPerformanceFrequency(); // @Cleanup in C this was static
    current_time := SDL_GetPerformanceCounter();
    io.DeltaTime = ifx bd.Time > 0 then cast(float)(cast(float64)(current_time - bd.Time) / frequency) else cast(float)(1.0 / 60.0);
    bd.Time = current_time;

    ImGui_ImplSDL2_UpdateMousePosAndButtons();
    ImGui_ImplSDL2_UpdateMouseCursor();

    // Update game controllers (if enabled and available)
    ImGui_ImplSDL2_UpdateGamepads();
}

