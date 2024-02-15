
main :: () {

    window : *SDL_Window;

    Simp.update_window(get_window_type(window)); // Comment this line to allow compilation to complete!
}


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

#scope_export

ImGui_ImplSDL2_ProcessEvent :: (event : *SDL_Event) -> bool
{
    return true;
}

#scope_file

ImGui_ImplSDL2_Init :: (window : *SDL_Window) -> bool
{
    return true;
}

#scope_export

ImGui_ImplSDL2_InitForOpenGL :: (window : *SDL_Window, sdl_gl_context : *void) -> bool
{
    return false;
}

ImGui_ImplSDL2_Shutdown :: ()
{
}

#scope_file

ImGui_ImplSDL2_UpdateMousePosAndButtons :: ()
{
}

#scope_file

ImGui_ImplSDL2_UpdateMouseCursor :: ()
{
}

ImGui_ImplSDL2_UpdateGamepads :: ()
{
    return; // @Incomplete Jai port omits this code
}

#scope_export

ImGui_ImplSDL2_NewFrame :: ()
{
}

#scope_file
ImGui :: #import "ImGui";

#import "SDL";
#import "Math";
#import "Basic";


Simp :: #import "Simp";