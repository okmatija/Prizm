// dear imgui: Platform Backend for SDL3
// Ported to Jai from imgui_impl_sdl3.cpp (imgui 1.92.7)
// This needs to be used along with a Renderer (e.g. OpenGL3, Vulkan..)

// Implemented features:
//  [X] Platform: Clipboard support.
//  [X] Platform: Mouse cursor shape and visibility.
//  [X] Platform: Keyboard support via io.AddKeyEvent().
//  [X] Platform: Gamepad support (stubbed out).

// SDL Data
ImGui_ImplSDL2_Data :: struct
{
    Window              : *SDL_Window;
    Time                : u64;
    MouseButtonsDown    : u32;
    MouseCursors        : [ImGui.MouseCursor.COUNT]*SDL_Cursor;
    ClipboardTextData   : *u8;
    MouseCanUseGlobalState : bool;
};

#scope_file

ImGui_ImplSDL2_GetBackendData :: () -> *ImGui_ImplSDL2_Data
{
    return ifx ImGui.GetCurrentContext() then cast(*ImGui_ImplSDL2_Data)ImGui.GetIO().BackendPlatformUserData else null;
}

ImGui_ImplSDL2_GetClipboardText :: (ctx : *ImGui.ImGuiContext) -> *u8 #c_call
{
    push_context {
        return SDL_GetClipboardText();
    }
}

ImGui_ImplSDL2_SetClipboardText :: (ctx : *ImGui.ImGuiContext, text : *u8) #c_call
{
    push_context {
        SDL_SetClipboardText(text);
    }
}

// Map SDL3 keycodes/scancodes to ImGuiKey values.
// Priority 1: scancode-based (for keypad and OEM keys that have no unique keycode in SDL3).
// Priority 2: keycode-based.
sdl_key_event_to_imgui_key :: (keycode : SDL_Keycode, scancode : SDL_Scancode) -> ImGui.Key
{
    // Keypad: use scancodes (SDL3 keypad keys share SDLK_ values with numerals)
    if scancode == {
    case SDL_Scancode.KP_0;        return .Keypad0;
    case SDL_Scancode.KP_1;        return .Keypad1;
    case SDL_Scancode.KP_2;        return .Keypad2;
    case SDL_Scancode.KP_3;        return .Keypad3;
    case SDL_Scancode.KP_4;        return .Keypad4;
    case SDL_Scancode.KP_5;        return .Keypad5;
    case SDL_Scancode.KP_6;        return .Keypad6;
    case SDL_Scancode.KP_7;        return .Keypad7;
    case SDL_Scancode.KP_8;        return .Keypad8;
    case SDL_Scancode.KP_9;        return .Keypad9;
    case SDL_Scancode.KP_PERIOD;   return .KeypadDecimal;
    case SDL_Scancode.KP_DIVIDE;   return .KeypadDivide;
    case SDL_Scancode.KP_MULTIPLY; return .KeypadMultiply;
    case SDL_Scancode.KP_MINUS;    return .KeypadSubtract;
    case SDL_Scancode.KP_PLUS;     return .KeypadAdd;
    case SDL_Scancode.KP_ENTER;    return .KeypadEnter;
    case SDL_Scancode.KP_EQUALS;   return .KeypadEqual;
    }

    // Named keys: use keycodes
    if keycode == {
    case SDLK_TAB;         return .Tab;
    case SDLK_LEFT;        return .LeftArrow;
    case SDLK_RIGHT;       return .RightArrow;
    case SDLK_UP;          return .UpArrow;
    case SDLK_DOWN;        return .DownArrow;
    case SDLK_PAGEUP;      return .PageUp;
    case SDLK_PAGEDOWN;    return .PageDown;
    case SDLK_HOME;        return .Home;
    case SDLK_END;         return .End;
    case SDLK_INSERT;      return .Insert;
    case SDLK_DELETE;      return .Delete;
    case SDLK_BACKSPACE;   return .Backspace;
    case SDLK_SPACE;       return .Space;
    case SDLK_RETURN;      return .Enter;
    case SDLK_ESCAPE;      return .Escape;
    case SDLK_COMMA;       return .Comma;
    case SDLK_PERIOD;      return .Period;
    case SDLK_SEMICOLON;   return .Semicolon;
    case SDLK_CAPSLOCK;    return .CapsLock;
    case SDLK_SCROLLLOCK;  return .ScrollLock;
    case SDLK_NUMLOCKCLEAR; return .NumLock;
    case SDLK_PRINTSCREEN; return .PrintScreen;
    case SDLK_PAUSE;       return .Pause;
    case SDLK_LCTRL;       return .LeftCtrl;
    case SDLK_LSHIFT;      return .LeftShift;
    case SDLK_LALT;        return .LeftAlt;
    case SDLK_LGUI;        return .LeftSuper;
    case SDLK_RCTRL;       return .RightCtrl;
    case SDLK_RSHIFT;      return .RightShift;
    case SDLK_RALT;        return .RightAlt;
    case SDLK_RGUI;        return .RightSuper;
    case SDLK_APPLICATION; return .Menu;
    case SDLK_0;           return ._0;
    case SDLK_1;           return ._1;
    case SDLK_2;           return ._2;
    case SDLK_3;           return ._3;
    case SDLK_4;           return ._4;
    case SDLK_5;           return ._5;
    case SDLK_6;           return ._6;
    case SDLK_7;           return ._7;
    case SDLK_8;           return ._8;
    case SDLK_9;           return ._9;
    case SDLK_A;           return .A;
    case SDLK_B;           return .B;
    case SDLK_C;           return .C;
    case SDLK_D;           return .D;
    case SDLK_E;           return .E;
    case SDLK_F;           return .F;
    case SDLK_G;           return .G;
    case SDLK_H;           return .H;
    case SDLK_I;           return .I;
    case SDLK_J;           return .J;
    case SDLK_K;           return .K;
    case SDLK_L;           return .L;
    case SDLK_M;           return .M;
    case SDLK_N;           return .N;
    case SDLK_O;           return .O;
    case SDLK_P;           return .P;
    case SDLK_Q;           return .Q;
    case SDLK_R;           return .R;
    case SDLK_S;           return .S;
    case SDLK_T;           return .T;
    case SDLK_U;           return .U;
    case SDLK_V;           return .V;
    case SDLK_W;           return .W;
    case SDLK_X;           return .X;
    case SDLK_Y;           return .Y;
    case SDLK_Z;           return .Z;
    case SDLK_F1;          return .F1;
    case SDLK_F2;          return .F2;
    case SDLK_F3;          return .F3;
    case SDLK_F4;          return .F4;
    case SDLK_F5;          return .F5;
    case SDLK_F6;          return .F6;
    case SDLK_F7;          return .F7;
    case SDLK_F8;          return .F8;
    case SDLK_F9;          return .F9;
    case SDLK_F10;         return .F10;
    case SDLK_F11;         return .F11;
    case SDLK_F12;         return .F12;
    case SDLK_F13;         return .F13;
    case SDLK_F14;         return .F14;
    case SDLK_F15;         return .F15;
    case SDLK_F16;         return .F16;
    case SDLK_F17;         return .F17;
    case SDLK_F18;         return .F18;
    case SDLK_F19;         return .F19;
    case SDLK_F20;         return .F20;
    case SDLK_F21;         return .F21;
    case SDLK_F22;         return .F22;
    case SDLK_F23;         return .F23;
    case SDLK_F24;         return .F24;
    case SDLK_AC_BACK;     return .AppBack;
    case SDLK_AC_FORWARD;  return .AppForward;
    }

    // Fallback to scancodes for OEM keys
    if scancode == {
    case SDL_Scancode.GRAVE;           return .GraveAccent;
    case SDL_Scancode.MINUS;           return .Minus;
    case SDL_Scancode.EQUALS;          return .Equal;
    case SDL_Scancode.LEFTBRACKET;     return .LeftBracket;
    case SDL_Scancode.RIGHTBRACKET;    return .RightBracket;
    case SDL_Scancode.NONUSBACKSLASH;  return .Oem102;
    case SDL_Scancode.BACKSLASH;       return .Backslash;
    case SDL_Scancode.SEMICOLON;       return .Semicolon;
    case SDL_Scancode.APOSTROPHE;      return .Apostrophe;
    case SDL_Scancode.COMMA;           return .Comma;
    case SDL_Scancode.PERIOD;          return .Period;
    case SDL_Scancode.SLASH;           return .Slash;
    }

    return .None;
}

sdl_update_key_modifiers :: (sdl_key_mods : SDL_Keymod)
{
    io := ImGui.GetIO();
    io.AddKeyEvent(io, xx ImGui.Key.Mod_Ctrl,  (sdl_key_mods & SDL_KMOD_CTRL)  != 0);
    io.AddKeyEvent(io, xx ImGui.Key.Mod_Shift, (sdl_key_mods & SDL_KMOD_SHIFT) != 0);
    io.AddKeyEvent(io, xx ImGui.Key.Mod_Alt,   (sdl_key_mods & SDL_KMOD_ALT)   != 0);
    io.AddKeyEvent(io, xx ImGui.Key.Mod_Super, (sdl_key_mods & SDL_KMOD_GUI)   != 0);
}

#scope_export

// You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
// - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
// - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
ImGui_ImplSDL2_ProcessEvent :: (event : *SDL_Event) -> bool
{
    io := ImGui.GetIO();
    bd := ImGui_ImplSDL2_GetBackendData();

    if cast(SDL_EventType) event.type == {
    case SDL_EventType.MOUSE_MOTION;
        io.AddMousePosEvent(io, event.motion.x, event.motion.y);
        return true;
    case SDL_EventType.MOUSE_WHEEL;
        wheel_x : float = -event.wheel.x;
        wheel_y : float =  event.wheel.y;
        io.AddMouseWheelEvent(io, wheel_x, wheel_y);
        return true;
    case SDL_EventType.MOUSE_BUTTON_DOWN; #through;
    case SDL_EventType.MOUSE_BUTTON_UP;
        mouse_button : s32 = -1;
        if event.button.button == SDL_BUTTON_LEFT   mouse_button = 0;
        if event.button.button == SDL_BUTTON_RIGHT  mouse_button = 1;
        if event.button.button == SDL_BUTTON_MIDDLE mouse_button = 2;
        if mouse_button == -1 return false;
        down := cast(SDL_EventType) event.type == SDL_EventType.MOUSE_BUTTON_DOWN;
        io.AddMouseButtonEvent(io, mouse_button, down);
        bd.MouseButtonsDown = ifx down then (bd.MouseButtonsDown | cast(u32)(1 << mouse_button))
                                       else (bd.MouseButtonsDown & ~cast(u32)(1 << mouse_button));
        return true;
    case SDL_EventType.TEXT_INPUT;
        io.AddInputCharactersUTF8(io, xx event.text.text);
        return true;
    case SDL_EventType.KEY_DOWN; #through;
    case SDL_EventType.KEY_UP;
        sdl_update_key_modifiers(cast(SDL_Keymod) event.key.mod);
        key := sdl_key_event_to_imgui_key(event.key.key, event.key.scancode);
        io.AddKeyEvent(io, key, cast(SDL_EventType) event.key.type == SDL_EventType.KEY_DOWN);
        return true;
    case SDL_EventType.WINDOW_FOCUS_GAINED;
        io.AddFocusEvent(io, true);
        return true;
    case SDL_EventType.WINDOW_FOCUS_LOST;
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

    bd := New(ImGui_ImplSDL2_Data);
    io.BackendPlatformUserData = cast(*void)bd;
    io.BackendPlatformName = "imgui_impl_sdl3";
    io.BackendFlags_ |= .HasMouseCursors;
    io.BackendFlags_ |= .HasSetMousePos;

    bd.Window = window;

    // Clipboard: use PlatformIO (imgui >= 1.91.1)
    platform_io := ImGui.GetPlatformIO();
    platform_io.Platform_GetClipboardTextFn = ImGui_ImplSDL2_GetClipboardText;
    platform_io.Platform_SetClipboardTextFn = ImGui_ImplSDL2_SetClipboardText;

    // Load mouse cursors
    bd.MouseCursors[ImGui.MouseCursor.Arrow]      = SDL_CreateSystemCursor(.DEFAULT);
    bd.MouseCursors[ImGui.MouseCursor.TextInput]  = SDL_CreateSystemCursor(.TEXT);
    bd.MouseCursors[ImGui.MouseCursor.ResizeAll]  = SDL_CreateSystemCursor(.MOVE);
    bd.MouseCursors[ImGui.MouseCursor.ResizeNS]   = SDL_CreateSystemCursor(.NS_RESIZE);
    bd.MouseCursors[ImGui.MouseCursor.ResizeEW]   = SDL_CreateSystemCursor(.EW_RESIZE);
    bd.MouseCursors[ImGui.MouseCursor.ResizeNESW] = SDL_CreateSystemCursor(.NESW_RESIZE);
    bd.MouseCursors[ImGui.MouseCursor.ResizeNWSE] = SDL_CreateSystemCursor(.NWSE_RESIZE);
    bd.MouseCursors[ImGui.MouseCursor.Hand]       = SDL_CreateSystemCursor(.POINTER);
    bd.MouseCursors[ImGui.MouseCursor.Wait]       = SDL_CreateSystemCursor(.WAIT);
    bd.MouseCursors[ImGui.MouseCursor.Progress]   = SDL_CreateSystemCursor(.PROGRESS);
    bd.MouseCursors[ImGui.MouseCursor.NotAllowed] = SDL_CreateSystemCursor(.NOT_ALLOWED);

    return true;
}

#scope_export

ImGui_ImplSDL2_InitForOpenGL :: (window : *SDL_Window, sdl_gl_context : *void) -> bool
{
    return ImGui_ImplSDL2_Init(window);
}

ImGui_ImplSDL2_Shutdown :: ()
{
    bd := ImGui_ImplSDL2_GetBackendData();
    assert(bd != null); // No platform backend to shutdown, or already shutdown?
    io := ImGui.GetIO();

    for cursor_n : 0..ImGui.MouseCursor.COUNT-1 {
        if bd.MouseCursors[cursor_n] SDL_DestroyCursor(bd.MouseCursors[cursor_n]);
    }

    io.BackendPlatformName = null;
    io.BackendPlatformUserData = null;
    free(bd);
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
        SDL_HideCursor();
    }
    else
    {
        cursor := bd.MouseCursors[imgui_cursor];
        if !cursor cursor = bd.MouseCursors[ImGui.MouseCursor.Arrow];
        SDL_SetCursor(cursor);
        SDL_ShowCursor();
    }
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
    SDL_GetWindowSizeInPixels(bd.Window, *display_w, *display_h);
    io.DisplaySize = ImGui.ImVec2.{xx w, xx h};
    if (w > 0 && h > 0)
        io.DisplayFramebufferScale = ImGui.ImVec2.{cast(float)display_w / w, cast(float)display_h / h};

    // Setup time step
    frequency := SDL_GetPerformanceFrequency();
    current_time := SDL_GetPerformanceCounter();
    if current_time <= bd.Time
        current_time = bd.Time + 1;
    io.DeltaTime = ifx bd.Time > 0 then cast(float)(cast(float64)(current_time - bd.Time) / frequency) else cast(float)(1.0 / 60.0);
    bd.Time = current_time;

    // Handle WantSetMousePos (optional, rarely used)
    if io.WantSetMousePos
        SDL_WarpMouseInWindow(bd.Window, io.MousePos.x, io.MousePos.y);

    ImGui_ImplSDL2_UpdateMouseCursor();
}
