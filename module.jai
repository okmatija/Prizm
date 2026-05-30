#module_parameters ();

ImVec2      :: Vector2;
ImVec4      :: Vector4;
ImColor     :: Vector4;

ImVector :: struct (T: Type) {
    Size: s32;
    Capacity: s32;
    Data: *T;
}

ImDrawCallback :: #type (parent_list: *ImDrawList, cmd: *ImDrawCmd) #c_call;

#scope_module

#import "Basic";
#import "Math";

#if OS == .WINDOWS {
    #load "windows/windows.jai";

    // Note: Check imconfig.h for a full list of compilation flags and the resulting
    // changes in features and system libraries required

    // Needed by imgui unless ImGui is compiled with IMGUI_DISABLE_WIN32_DEFAULT_CLIPBOARD_FUNCS"
    #library,system,link_always "user32";

    // Needed by imgui unless ImGui is compiled with IMGUI_DISABLE_DEFAULT_SHELL_FUNCTIONS
    #library,system,link_always "shell32";
} else {
    #load "unix.jai";
    #if OS == .LINUX  #library,system,link_always "libm";
}
