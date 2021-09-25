// Copyright Epic Games, Inc. All Rights Reserved.

// Shared global state is stored here
App :: struct {
    window : *SDL_Window = null;

    INITIAL_WINDOW_WIDTH  : s32 : 1440;
    INITIAL_WINDOW_HEIGHT : s32 : 900;

    current_window_width := INITIAL_WINDOW_WIDTH;
    current_window_height := INITIAL_WINDOW_HEIGHT;
    fullscreen := false;

    closing_application := false; // Set this to true to quit the application on the next frame
    show_imgui_demo_window := true;
}

app : App;

current_window_aspect_ratio_width_over_height :: () -> float {
    return cast(float) app.current_window_width / cast(float) app.current_window_height;
}

#import "Compiler";
#import "Basic";
#import "SDL";
#import "GL";
#run compiler_set_type_info_flags(GL_Procedures, .NO_SIZE_COMPLAINT);
ImGui :: #import "jai-imgui"(LINK_STATIC=true);
#run compiler_set_type_info_flags(ImGui, .NO_SIZE_COMPLAINT);

#load "modules/jai-imgui/backends/imgui_impl_sdl.jai"; // SDL platform backend
#load "modules/jai-imgui/backends/imgui_impl_opengl3.jai"; // OpenGL renderer backend

#load "rendering_utils.jai";