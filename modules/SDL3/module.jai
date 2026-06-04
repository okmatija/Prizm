// Set USE_SYSTEM_LIBRARY=true to link against the system libSDL3.so.0 instead of
// the prebuilt library bundled in linux/bin/x64/.
// Has no effect on Windows or macOS (those always use their bundled libraries).
#module_parameters (USE_SYSTEM_LIBRARY := false);

#if OS == .WINDOWS {
    #load "windows/windows.jai";
} else #if OS == .LINUX {
    // libsdl3 declared here (before #load) so linux.jai foreign declarations can see it,
    // and so the path resolves relative to module.jai rather than linux/linux.jai.
    #if USE_SYSTEM_LIBRARY {
        libsdl3 :: #library,system "libSDL3.so.0";
    } else {
        // "libSDL3" — Jai appends .so, giving libSDL3.so (the linker name).
        // The SONAME embedded in the file is libSDL3.so.0; first.jai copies it
        // next to the executable under that name so the dynamic linker finds it.
        libsdl3 :: #library "linux/bin/x64/libSDL3";
    }
    #load "linux/linux.jai";
} else #if OS == .MACOS {
    #load "macos/macos.jai";
}

#load "sdl_callbacks.jai";

// From SDL_video.h, I generate it from Grok
SDL_WindowFlags :: enum_flags u64 {
    FULLSCREEN           :: 0x0000000000000001;    /**< window is in fullscreen mode */
    OPENGL               :: 0x0000000000000002;    /**< window usable with OpenGL context */
    OCCLUDED             :: 0x0000000000000004;    /**< window is occluded */
    HIDDEN               :: 0x0000000000000008;    /**< window is neither mapped onto the desktop nor shown in the taskbar/dock/window list; SDL_ShowWindow() is required for it to become visible */
    BORDERLESS           :: 0x0000000000000010;    /**< no window decoration */
    RESIZABLE            :: 0x0000000000000020;    /**< window can be resized */
    MINIMIZED            :: 0x0000000000000040;    /**< window is minimized */
    MAXIMIZED            :: 0x0000000000000080;    /**< window is maximized */
    MOUSE_GRABBED        :: 0x0000000000000100;    /**< window has grabbed mouse input */
    INPUT_FOCUS          :: 0x0000000000000200;    /**< window has input focus */
    MOUSE_FOCUS          :: 0x0000000000000400;    /**< window has mouse focus */
    EXTERNAL             :: 0x0000000000000800;    /**< window not created by SDL */
    MODAL                :: 0x0000000000001000;    /**< window is modal */
    HIGH_PIXEL_DENSITY   :: 0x0000000000002000;    /**< window uses high pixel density back buffer if possible */
    MOUSE_CAPTURE        :: 0x0000000000004000;    /**< window has mouse captured (unrelated to MOUSE_GRABBED) */
    MOUSE_RELATIVE_MODE  :: 0x0000000000008000;    /**< window has relative mode enabled */
    ALWAYS_ON_TOP        :: 0x0000000000010000;    /**< window should always be above others */
    UTILITY              :: 0x0000000000020000;    /**< window should be treated as a utility window, not showing in the task bar and window list */
    TOOLTIP              :: 0x0000000000040000;    /**< window should be treated as a tooltip and does not get mouse or keyboard focus, requires a parent window */
    POPUP_MENU           :: 0x0000000000080000;    /**< window should be treated as a popup menu, requires a parent window */
    KEYBOARD_GRABBED     :: 0x0000000000100000;    /**< window has grabbed keyboard input */
    VULKAN               :: 0x0000000010000000;    /**< window usable for Vulkan surface */
    METAL                :: 0x0000000020000000;    /**< window usable for Metal view */
    TRANSPARENT          :: 0x0000000040000000;    /**< window with transparent buffer */
    NOT_FOCUSABLE        :: 0x0000000080000000;    /**< window should not be focusable */
}

/**
 * Used to indicate that you don't care what the window position is.
 *
 * If you _really_ don't care, SDL_WINDOWPOS_UNDEFINED is the same, but always
 * uses the primary display instead of specifying one.
 *
 * \param X the SDL_DisplayID of the display to use.
 *
 * \since This macro is available since SDL 3.2.0.
 */
// Original: #define SDL_WINDOWPOS_UNDEFINED_DISPLAY(X)  (SDL_WINDOWPOS_UNDEFINED_MASK|(X))
SDL_WINDOWPOS_UNDEFINED_DISPLAY :: inline (display_id: SDL_DisplayID) -> SDL_DisplayID {
    return SDL_WINDOWPOS_UNDEFINED_MASK | display_id;
}

/**
 * Used to indicate that you don't care what the window position/display is.
 *
 * This always uses the primary display.
 *
 * \since This macro is available since SDL 3.2.0.
 */
// #define SDL_WINDOWPOS_UNDEFINED         SDL_WINDOWPOS_UNDEFINED_DISPLAY(0)
SDL_WINDOWPOS_UNDEFINED :: #bake_arguments SDL_WINDOWPOS_UNDEFINED_DISPLAY(display_id = 0);

/**
 * A macro to test if the window position is marked as "undefined."
 *
 * \param X the window position value.
 *
 * \since This macro is available since SDL 3.2.0.
 */
// #define SDL_WINDOWPOS_ISUNDEFINED(X)    (((X)&0xFFFF0000) == SDL_WINDOWPOS_UNDEFINED_MASK)
SDL_WINDOWPOS_ISUNDEFINED :: inline (display_id: SDL_DisplayID) -> bool {
    return (display_id & 0xFFFF0000) == SDL_WINDOWPOS_UNDEFINED_MASK;
}

/**
 * Used to indicate that the window position should be centered.
 *
 * SDL_WINDOWPOS_CENTERED is the same, but always uses the primary display
 * instead of specifying one.
 *
 * \param X the SDL_DisplayID of the display to use.
 *
 * \since This macro is available since SDL 3.2.0.
 */
// #define SDL_WINDOWPOS_CENTERED_DISPLAY(X)  (SDL_WINDOWPOS_CENTERED_MASK|(X))
SDL_WINDOWPOS_CENTERED_DISPLAY :: inline (display_id: SDL_DisplayID) -> SDL_DisplayID {
    return SDL_WINDOWPOS_CENTERED_MASK | display_id;
}

/**
 * Used to indicate that the window position should be centered.
 *
 * This always uses the primary display.
 *
 * \since This macro is available since SDL 3.2.0.
 */
// #define SDL_WINDOWPOS_CENTERED         SDL_WINDOWPOS_CENTERED_DISPLAY(0)
SDL_WINDOWPOS_CENTERED :: #bake_arguments SDL_WINDOWPOS_CENTERED_DISPLAY(display_id = 0);

/**
 * A macro to test if the window position is marked as "centered."
 *
 * \param X the window position value.
 *
 * \since This macro is available since SDL 3.2.0.
 */
// #define SDL_WINDOWPOS_ISCENTERED(X)    \
            // (((X)&0xFFFF0000) == SDL_WINDOWPOS_CENTERED_MASK)
SDL_WINDOWPOS_ISCENTERED :: inline (pos: u32) -> bool {
    return (pos & 0xFFFF0000) == SDL_WINDOWPOS_CENTERED_MASK;
}

// Handcraft init flags
SDL_InitFlags :: enum_flags u32 {
    AUDIO    :: 0x00000010;
    VIDEO    :: 0x00000020;
    JOYSTICK :: 0x00000200;
    HAPTIC   :: 0x00001000;
    GAMEPAD  :: 0x00002000;
    EVENTS   :: 0x00004000;
    SENSOR   :: 0x00008000;
    CAMERA   :: 0x00010000;
}

// SDL_WINDOW_* typed constants — same values as SDL_WindowFlags enum members,
// provided as standalone identifiers for cross-platform source compatibility.
SDL_WINDOW_FULLSCREEN          : SDL_WindowFlags : 0x0000000000000001;
SDL_WINDOW_OPENGL              : SDL_WindowFlags : 0x0000000000000002;
SDL_WINDOW_OCCLUDED            : SDL_WindowFlags : 0x0000000000000004;
SDL_WINDOW_HIDDEN              : SDL_WindowFlags : 0x0000000000000008;
SDL_WINDOW_BORDERLESS          : SDL_WindowFlags : 0x0000000000000010;
SDL_WINDOW_RESIZABLE           : SDL_WindowFlags : 0x0000000000000020;
SDL_WINDOW_MINIMIZED           : SDL_WindowFlags : 0x0000000000000040;
SDL_WINDOW_MAXIMIZED           : SDL_WindowFlags : 0x0000000000000080;
SDL_WINDOW_MOUSE_GRABBED       : SDL_WindowFlags : 0x0000000000000100;
SDL_WINDOW_INPUT_FOCUS         : SDL_WindowFlags : 0x0000000000000200;
SDL_WINDOW_MOUSE_FOCUS         : SDL_WindowFlags : 0x0000000000000400;
SDL_WINDOW_EXTERNAL            : SDL_WindowFlags : 0x0000000000000800;
SDL_WINDOW_MODAL               : SDL_WindowFlags : 0x0000000000001000;
SDL_WINDOW_HIGH_PIXEL_DENSITY  : SDL_WindowFlags : 0x0000000000002000;
SDL_WINDOW_MOUSE_CAPTURE       : SDL_WindowFlags : 0x0000000000004000;
SDL_WINDOW_MOUSE_RELATIVE_MODE : SDL_WindowFlags : 0x0000000000008000;
SDL_WINDOW_ALWAYS_ON_TOP       : SDL_WindowFlags : 0x0000000000010000;
SDL_WINDOW_UTILITY             : SDL_WindowFlags : 0x0000000000020000;
SDL_WINDOW_TOOLTIP             : SDL_WindowFlags : 0x0000000000040000;
SDL_WINDOW_POPUP_MENU          : SDL_WindowFlags : 0x0000000000080000;
SDL_WINDOW_KEYBOARD_GRABBED    : SDL_WindowFlags : 0x0000000000100000;
SDL_WINDOW_VULKAN              : SDL_WindowFlags : 0x0000000010000000;
SDL_WINDOW_METAL               : SDL_WindowFlags : 0x0000000020000000;
SDL_WINDOW_TRANSPARENT         : SDL_WindowFlags : 0x0000000040000000;
SDL_WINDOW_NOT_FOCUSABLE       : SDL_WindowFlags : 0x0000000080000000;

// SDL_INIT_* typed constants — same values as SDL_InitFlags enum members.
SDL_INIT_AUDIO    : SDL_InitFlags : 0x00000010;
SDL_INIT_VIDEO    : SDL_InitFlags : 0x00000020;
SDL_INIT_JOYSTICK : SDL_InitFlags : 0x00000200;
SDL_INIT_HAPTIC   : SDL_InitFlags : 0x00001000;
SDL_INIT_GAMEPAD  : SDL_InitFlags : 0x00002000;
SDL_INIT_EVENTS   : SDL_InitFlags : 0x00004000;
SDL_INIT_SENSOR   : SDL_InitFlags : 0x00008000;
SDL_INIT_CAMERA   : SDL_InitFlags : 0x00010000;
