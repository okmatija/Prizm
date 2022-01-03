// Copyright Epic Games, Inc. All Rights Reserved.

app : App;

// Shared global state is stored here
App :: struct {
    window : *SDL_Window = null;

    INITIAL_WINDOW_WIDTH  : s32 : 1440;
    INITIAL_WINDOW_HEIGHT : s32 : 900;

    current_window_width := INITIAL_WINDOW_WIDTH;
    current_window_height := INITIAL_WINDOW_HEIGHT;
    fullscreen := false;

    text_program : GLuint;
    text_vao : GLuint;
    text_vbo : GLuint;

    // For triangle and solid wireframe rendering
    mesh_program : GLuint;
    mesh_vao : GLuint;

    // For point and line rendering
    simple_mesh_program : GLuint;
    simple_mesh_vao : GLuint;

    normals_program : GLuint;
    normals_vao : GLuint;

    aabb_program : GLuint;
    aabb_vao : GLuint;

    Background_Style :: enum #specified {
        SOLID_COLOR :: 0;
        CUSTOM_SHADER :: 1;
    };

    background_style := Background_Style.CUSTOM_SHADER;
    background_solid_color := Vector4.{170./256, 170./256, 170./256, 1.00};
    background_program : GLuint;
    background_vao : GLuint;

    show_ui := true;
    show_help_ui := false;
    show_console_ui := false;
    show_changelog := false;

    selection_display_info : Display_Info; // UI will edit this value and apply it to all selected entities
    selection_display_info.points_visible = false;
    selection_display_info.normals_visible = false;
    selection_display_info.wireframe_visible = false;
    selection_display_info.surface_visible = false;
    selection_display_info.aabb_visible = false;

    user_selection : Mesh_Entity;
    user_selection_cursor_text_shown := false;
    user_selection_cursor_text_scale := .4;
    user_selection_max_point_count_for_selectable_entity := 5_000_000;

    // Set the defaults for the user selection display
    user_selection.is_visible = true;
    user_selection.display_info.points_visible = true;
    user_selection.display_info.points_size = 6;
    user_selection.display_info.points_color = .{1, 0, .8, 1}; // @Volatile Used for the dynamic label text too
    user_selection.display_info.vertex_label_style.show_position = true;
    user_selection.display_info.vertex_label_style.label_color = .{0, 0, 0, 1};

    clipping_sphere_mode_entity_index : int = -1; // The entity which set the clipping sphere center

    // Checkbox sweep mode is enabled while LMB is held down if it was clicked on a sweepable checkbox, the mouse will be constrained to move only up and down and the inverse of the state of the checkbox just before the click will be set on all the checkboxes that get swept
    checkbox_sweep_mode := false;
    checkbox_sweep_mode_mouse_min_x : s32;
    checkbox_sweep_mode_mouse_max_x : s32;
    checkbox_sweep_mode_state_to_set := false;

    camera : Camera;
    console : Console;
    entities : [..]*Entity;

    vertex_label_style : Vertex_Label_Style;
    label_limit : s32 = 2000;

    keymap : Keymap;
    keymap_keydown : Keymap;
    settings : User_Settings;

    closing_application := false; // Set this to true to quit the application on the next frame
    show_imgui_demo_window := true;
}

CHANGELOG :: #run read_entire_file("CHANGELOG.md");

current_window_aspect_ratio_width_over_height :: () -> float {
    return cast(float) app.current_window_width / cast(float) app.current_window_height;
}

entities_iterator :: (entities : *[..]*Entity, body : Code, flags : For_Flags, should_visit : (*Entity)->bool) #expand {
    #assert(flags == 0); // No options are supported

    for entity, entity_index : <<entities {
        if !should_visit(entity) continue;

        `it_index := entity_index;
        `it := entity;
        #insert (remove=#assert(false), break=break entity) body;
    }
}

visible :: #bake_arguments entities_iterator(should_visit = (e)=>(e.is_visible));
selected :: #bake_arguments entities_iterator(should_visit = (e)=>(e.is_selected));

// :UserConfig hotload changes to this file
User_Settings :: struct {
    fit_to_screen_on_visibility_change := false;
    fit_to_screen_on_file_drop_event   := true;

    camera_controls_keep_up_when_setting_look_along := false;

    camera_zoom_scrolling_ratio          := .8;
    // camera_zoom_dragging_follows_cursor  := false;
    // camera_zoom_dragging_ratio           := .8;
    camera_zoom_min_screen_filling_length_mm := .0001; // .1um
    camera_zoom_max_screen_filling_length_factor := 4.; // multiplies a visible scene bounding sphere radius
    camera_zoom_max_limited_by_scene_bounding_sphere := true;

    duplicate_file_behaviour := Duplicate_File_Behaviour.APPEND;
    color_from_path_behaviour := Color_From_Path_Behaviour.FILENAME_ONLY;
}

Color_From_Path_Behaviour :: enum u8 #specified {
    FILENAME_ONLY :: 0;
    FULLY_PATHED_FILENAME :: 1;
}

Duplicate_File_Behaviour :: enum u8 #specified {
    APPEND :: 0;
    IGNORE :: 1;
    OVERWRITE :: 2;
    // ASK :: 3;
}

clamp_user_settings :: ()
{
    // app.settings.camera_zoom_dragging_ratio               = clamp(app.settings.camera_zoom_dragging_ratio,
    //                                                               .3, .99);
    app.settings.camera_zoom_scrolling_ratio              = clamp(app.settings.camera_zoom_scrolling_ratio,
                                                                  .3, .99);
    app.settings.camera_zoom_min_screen_filling_length_mm = clamp(app.settings.camera_zoom_min_screen_filling_length_mm,
                                                                  .00001, app.camera.scene_bounding_sphere.radius / 2);
}

#import "Basic"; // #import "Basic"()(MEMORY_DEBUGGER=true);
#import "File";
#import "File_Utilities";
#import "String";
#import "Sort";
#import "Reflection";
#import "Math";
#import "SDL";
#import "GL";
#import "Deep_Copy";
#import "Debug";
#import "Time";
#import "Hash";
#import "Hash_Table";
#import "freetype255";
#import "System";
ImGui :: #import "ImGui";
#load "imgui_impl_sdl.jai"; // SDL platform backend
#load "imgui_impl_opengl3.jai"; // OpenGL renderer backend

#load "axis_box.jai";
#load "polyline.jai";
#load "polygon.jai";
#load "edge.jai";
#load "mesh.jai";
#load "grid.jai";
#load "axes.jai";
#load "selection_mode.jai";
#load "numeric.jai";
#load "geometric_operations.jai";
#load "io_obj.jai";
#load "io_wkt.jai";
#load "rendering.jai";
#load "rendering_utils.jai";
#load "font.jai";
#load "carpet.jai";
#load "camera.jai";
#load "entities.jai";
#load "mesh_utils.jai";
#load "ui.jai";
#load "shapes.jai";
#load "keymap.jai";
#load "inspector.jai";
#load "lexer.jai";
#load "parser.jai";
#load "console.jai";
#load "commands.jai";

#import "Compiler";
#run compiler_set_type_info_flags(GL_Procedures, .NO_SIZE_COMPLAINT);
#run compiler_set_type_info_flags(ImGui, .NO_SIZE_COMPLAINT);
