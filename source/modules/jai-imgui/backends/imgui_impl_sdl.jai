// dear imgui: Platform Backend for SDL2
// This needs to be used along with a Renderer (e.g. DirectX11, OpenGL3, Vulkan..)
// (Info: SDL2 is a cross-platform general purpose library for handling windows, inputs, graphics context creation, etc.)
// (Requires: SDL 2.0. Prefer SDL 2.0.4+ for full feature support.)

// #define SDL_HAS_CAPTURE_AND_GLOBAL_MOUSE    SDL_VERSION_ATLEAST(2,0,4)
// #define SDL_HAS_VULKAN                      SDL_VERSION_ATLEAST(2,0,6)

// Data
g_Window : *SDL_Window = null;
g_Time : u64;
g_MousePressed : [3]bool = .[false, false, false];
g_MouseCursors : [ImGui.MouseCursor.COUNT]*SDL_Cursor;
g_ClipboardTextData : *u8 = null;
g_MouseCanUseGlobalState := false;

ImGui_ImplSDL2_GetClipboardText :: (data : *void) -> *u8 #c_call
{
    // if (g_ClipboardTextData)
    //     SDL_free(g_ClipboardTextData);
    // g_ClipboardTextData = SDL_GetClipboardText();
    // return g_ClipboardTextData;
    new_context: Context; // TODO: hide the context in the userdata pointer passed to us
    push_context new_context {
        return SDL_GetClipboardText();
    }
}

ImGui_ImplSDL2_SetClipboardText :: ( data : *void, text : *u8) #c_call {
    new_context: Context; // TODO: hide the context in the userdata pointer passed to us
    push_context new_context {
        SDL_SetClipboardText(text);
    }
}

// You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
// - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
// - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
// Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
// If you have multiple SDL events and some of them are not meant to be used by dear imgui, you may need to filter events based on their windowID field.
ImGui_ImplSDL2_ProcessEvent :: (event : *SDL_Event) -> bool {
    io := ImGui.GetIO();
    if event.type == {
    case .SDL_MOUSEWHEEL;
            if (event.wheel.x > 0) io.MouseWheelH += 1;
            if (event.wheel.x < 0) io.MouseWheelH -= 1;
            if (event.wheel.y > 0) io.MouseWheel += 1;
            if (event.wheel.y < 0) io.MouseWheel -= 1;
            return true;
    case .SDL_MOUSEBUTTONDOWN;
            if (event.button.button == SDL_BUTTON_LEFT) g_MousePressed[0] = true;
            if (event.button.button == SDL_BUTTON_RIGHT) g_MousePressed[1] = true;
            if (event.button.button == SDL_BUTTON_MIDDLE) g_MousePressed[2] = true;
            return true;
    case .SDL_TEXTINPUT;
            io.AddInputCharactersUTF8(io, xx event.text.text.data); // @@
            return true;
    case SDL_KEYDOWN; #through;
    case SDL_KEYUP;
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
    return false;
}

ImGui_ImplSDL2_Init :: (window : *SDL_Window) -> bool {
    g_Window = window;

    // Setup backend capabilities flags
    io := ImGui.GetIO();
    io.BackendFlags_ |= .HasMouseCursors;       // We can honor GetMouseCursor() values (optional)
    io.BackendFlags_ |= .HasSetMousePos;        // We can honor io.WantSetMousePos requests (optional, rarely used)
    io.BackendPlatformName = "imgui_impl_sdl";

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
    io.KeyMap[ImGui.Key.Enter] = xx SDLK_RETURN; // SDL_SCANCODE_RETURN
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
    g_MouseCursors[ImGui.MouseCursor.Arrow] = SDL_CreateSystemCursor(.ARROW);
    g_MouseCursors[ImGui.MouseCursor.TextInput] = SDL_CreateSystemCursor(.IBEAM);
    // g_MouseCursors[ImGui.MouseCursor.ResizeAll] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_SIZEALL);
    g_MouseCursors[ImGui.MouseCursor.ResizeNS] = SDL_CreateSystemCursor(.SIZENS);
    g_MouseCursors[ImGui.MouseCursor.ResizeEW] = SDL_CreateSystemCursor(.SIZEWE);
    g_MouseCursors[ImGui.MouseCursor.ResizeNESW] = SDL_CreateSystemCursor(.SIZENESW);
    g_MouseCursors[ImGui.MouseCursor.ResizeNWSE] = SDL_CreateSystemCursor(.SIZENWSE);
    g_MouseCursors[ImGui.MouseCursor.Hand] = SDL_CreateSystemCursor(.HAND);
    // g_MouseCursors[ImGui.MouseCursor.NotAllowed] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_NO);

    // // Check and store if we are on a SDL backend that supports global mouse position
    // // ("wayland" and "rpi" don't support it, but we chose to use a white-list instead of a black-list)
    // const char* sdl_backend = SDL_GetCurrentVideoDriver();
    // const char* global_mouse_whitelist[] = { "windows", "cocoa", "x11", "DIVE", "VMAN" };
    // g_MouseCanUseGlobalState = false;
    // for (int n = 0; n < IM_ARRAYSIZE(global_mouse_whitelist); n++)
    //     if (strncmp(sdl_backend, global_mouse_whitelist[n], strlen(global_mouse_whitelist[n])) == 0)
    //         g_MouseCanUseGlobalState = true;

// #if OS == .WINDOWS {
//     wmInfo : SDL_SysWMinfo;
//     SDL_VERSION(*wmInfo.version);
//     SDL_GetWindowWMInfo(window, *wmInfo);
//     io.ImeWindowHandle = wmInfo.info.win.window;
// }

    return true;
}

ImGui_ImplSDL2_InitForOpenGL :: (window : *SDL_Window, sdl_gl_context : *void) -> bool {
    return ImGui_ImplSDL2_Init(window);
}

ImGui_ImplSDL2_Shutdown :: () {
    // g_Window = NULL;

    // // Destroy last known clipboard data
    // if (g_ClipboardTextData)
    //     SDL_free(g_ClipboardTextData);
    // g_ClipboardTextData = NULL;

    // // Destroy SDL mouse cursors
    // for (ImGuiMouseCursor cursor_n = 0; cursor_n < ImGuiMouseCursor_COUNT; cursor_n++)
    //     SDL_FreeCursor(g_MouseCursors[cursor_n]);
    // memset(g_MouseCursors, 0, sizeof(g_MouseCursors));
}

ImGui_ImplSDL2_UpdateMousePosAndButtons :: () {
    io := ImGui.GetIO();

    // Set OS mouse position if requested (rarely used, only when ImGuiConfigFlags_NavEnableSetMousePos is enabled by user)
    if (io.WantSetMousePos)
        SDL_WarpMouseInWindow(g_Window, xx io.MousePos.x, xx io.MousePos.y);
    else
        io.MousePos = ImGui.make_ImVec2(-FLOAT32_MAX, -FLOAT32_MAX);

    mx, my : s32;
    mouse_buttons := SDL_GetMouseState(*mx, *my);
    io.MouseDown[0] = g_MousePressed[0] || (mouse_buttons & SDL_BUTTON(SDL_BUTTON_LEFT)) != 0;  // If a mouse press event came, always pass it as "mouse held this frame", so we don't miss click-release events that are shorter than 1 frame.
    io.MouseDown[1] = g_MousePressed[1] || (mouse_buttons & SDL_BUTTON(SDL_BUTTON_RIGHT)) != 0;
    io.MouseDown[2] = g_MousePressed[2] || (mouse_buttons & SDL_BUTTON(SDL_BUTTON_MIDDLE)) != 0;
    g_MousePressed[0], g_MousePressed[1], g_MousePressed[2] = false, false, false;

    if (SDL_GetWindowFlags(g_Window) & .SDL_WINDOW_INPUT_FOCUS)
        io.MousePos = ImGui.make_ImVec2(xx mx, xx my);
}

ImGui_ImplSDL2_UpdateMouseCursor :: () {
    io := ImGui.GetIO();
    if (io.ConfigFlags_ & .NoMouseCursorChange)
        return;

    imgui_cursor := ImGui.GetMouseCursor();
    if (io.MouseDrawCursor || imgui_cursor == .None)
    {
        // Hide OS mouse cursor if imgui is drawing it or if it wants no cursor
        SDL_ShowCursor(xx SDL_FALSE);
    }
    else
    {
        // Show OS mouse cursor
        SDL_SetCursor(ifx g_MouseCursors[imgui_cursor] then g_MouseCursors[imgui_cursor] else g_MouseCursors[ImGui.MouseCursor.Arrow]);
        SDL_ShowCursor(xx SDL_TRUE);
    }
}

ImGui_ImplSDL2_UpdateGamepads :: () {
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

ImGui_ImplSDL2_NewFrame :: (window : *SDL_Window) {
    io := ImGui.GetIO();
    // assert(io.Fonts.IsBuilt(), "Font atlas not built! It is generally built by the renderer backend. Missing call to renderer _NewFrame() function? e.g. ImGui_ImplOpenGL3_NewFrame().");

    // Setup display size (every frame to accommodate for window resizing)
    w, h : s32;
    display_w, display_h : s32;
    SDL_GetWindowSize(window, *w, *h);
    if (SDL_GetWindowFlags(window) & .SDL_WINDOW_MINIMIZED)
        w, h = 0, 0;
    SDL_GL_GetDrawableSize(window, *display_w, *display_h);
    io.DisplaySize = ImGui.make_ImVec2(xx w, xx h);
    if (w > 0 && h > 0)
        io.DisplayFramebufferScale = ImGui.make_ImVec2(cast(float) display_w / w, cast(float)display_h / h);

    // Setup time step (we don't use SDL_GetTicks() because it is using millisecond resolution)
    frequency := SDL_GetPerformanceFrequency();
    current_time := SDL_GetPerformanceCounter();
    io.DeltaTime = ifx g_Time > 0 then cast(float)(cast(float64)(current_time - g_Time) / xx frequency) else 1.0 / 60.0;
    g_Time = current_time;

    ImGui_ImplSDL2_UpdateMousePosAndButtons();
    ImGui_ImplSDL2_UpdateMouseCursor();

    // Update game controllers (if enabled and available)
    ImGui_ImplSDL2_UpdateGamepads();
}

#scope_file
ImGui :: #import "jai-imgui"(LINK_STATIC=true);

#import "SDL";
#import "Math";
