app : App;

// Shared global state is stored here
// @Cleanup Remove the thing not associated with the application logic directly, make these file scoped globals?
App :: struct {
    window : *SDL_Window = null;
    simp_font: *Simp.Dynamic_Font;

    INITIAL_WINDOW_WIDTH  : s32 : 1440;
    INITIAL_WINDOW_HEIGHT : s32 : 900;

    current_window_width := INITIAL_WINDOW_WIDTH;
    current_window_height := INITIAL_WINDOW_HEIGHT;
    fullscreen := false;

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
    background_solid_color := Vector4.{230./255, 230./255, 230./256, 1.};
    background_program : GLuint;
    background_vao : GLuint;

    show_ui := true;
    show_help_ui := false;
    show_fps := false;

    triad : Axes_Triad;
    // triad.origin.display_info.backface_mode = .FIXED;
    // triad.x_axis.display_info.backface_mode = .FIXED;
    // triad.y_axis.display_info.backface_mode = .FIXED;
    // triad.z_axis.display_info.backface_mode = .FIXED;

    // Item Context menu UI, Action button UI and Action keybindings edit this value and apply it to all target entities (see Target_Items enum)
    // We want to update this value in all these contexts so that things are consistent when e.g., we have the item context menu up and can see
    // element label themes, but rather than pressing the checkboxes, we change the theme with the hotkey
    // @FIXME This name is confusing, its not related to the user_selection object, its just a display info that
    //  is used for group edits, not even just selected target items now either..! Maybe action_ is a better prefix?
    selection_display_info : Display_Info;
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
    user_selection.display_info.is_visible = true;
    user_selection.display_info.points_visible = true;
    user_selection.display_info.points_size = 6;
    user_selection.display_info.points_color = .{1, 0, .8, 1}; // @Volatile Used for the dynamic label text too
    user_selection.display_info.vertex_label_style.show_position = true;
    user_selection.display_info.vertex_label_style.label_color = .{0, 0, 0, 1};

    clipping_sphere_mode_entity_index : int = -1; // The entity which set the clipping sphere center

    // Checkbox sweep mode is enabled while LMB is held down if it was clicked on a sweepable checkbox, the mouse will be constrained to move only up and down and the inverse of the state of the checkbox just before the click will be set on all the checkboxes that get swept
    sweep_state : Checkbox_Sweep_Mode_State;

    camera : Camera;
    console : Console;
    entities : [..]*Entity;

    vertex_label_style : Label_Theme;
    element_label_style : Label_Theme;

    keymap : Keymap;
    keymap_actions : Keymap;
    keymap_keydown : Keymap;
    settings : User_Settings;

    closing_application := false; // Set this to true to quit the application on the next frame
    show_imgui_demo_window := false;

    file_watcher : File_Watcher;

    // Vertices with inf/nan components are replaced with the corresponding coordinate of invalid_point
    // Indices that reference missing vertices will reference a new point positioned at invalid_point
    // The user can change this coordinate if the default zero value is inconvenient, reloading the file will show the new result
    invalid_point : Vector3 = .{0, 0, 0};

    Version :: struct {
        name : string;
        date : string;
        description : string;
    }
    changelog : [..]Version;

    Known_Issue :: struct {
        name :        string;
        description : string;
    }
    known_issues : [..]Known_Issue;

    debug_frame := false;
    debug_color := CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR;
}

// @Incomplete Deduplicate file watcher directories on linux

add_file_watcher_directory :: (fully_pathed_filename : string) {
    directory : string = get_directory(fully_pathed_filename);

    #if OS == .WINDOWS {
    found := false;
    for app.file_watcher.directories {
        if it.name == directory {
            found = true;
            break;
        }
    }
    if !found {
        add_directories(*app.file_watcher, directory);
    }
    } else {
        // @Incomplete
    }
}

remove_file_watcher_directory :: (fully_pathed_filename : string, entity_to_ignore : *Entity) {
    if entity_to_ignore.source != .FILE_ON_DISK {
        return;
    }

    directory : string = get_directory(fully_pathed_filename);

    // Check if no other entities will need to watch this directory
    remove_directory := true;
    for app.entities {
        if it != entity_to_ignore && it.source == .FILE_ON_DISK && get_directory(it.fully_pathed_filename) == directory {
            remove_directory = false;
        }
    }

    if remove_directory {
        #if OS == .WINDOWS {
        for app.file_watcher.directories {
            if it.name == directory {
                remove it;
                break;
            }
        }
        } else {
            // @Incomplete
        }
    }
}

// Specfied since we use the values as an index into an array
Target_Items :: enum int #specified {
    // @Volatile Don't change ordering, it will desync the descriptions etc in the keymap
    ALL_ITEMS :: 0;
    VISIBLE ::   1;
    SELECTED ::  2;
}
TARGET_ITEMS_COUNT :: #run get_enum_count(Target_Items);


current_window_aspect_ratio_width_over_height :: () -> float {
    return cast(float) app.current_window_width / cast(float) app.current_window_height;
}

Entities_Iterator :: (entities : *[..]*Entity, body : Code, flags : For_Flags, should_visit : (*Entity)->bool) #expand {
    #assert(flags == 0); // No options are supported

    for entity, entity_index : <<entities {
        if !should_visit(entity) continue;

        `it_index := entity_index;
        `it := entity;
        #insert (remove=#assert(false), break=break entity) body;
    }
}

Visible ::  #bake_arguments Entities_Iterator(should_visit = (e)=>(e.display_info.is_visible));
Selected :: #bake_arguments Entities_Iterator(should_visit = (e)=>(e.is_selected));

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
    camera_zoom_max_limited_by_scene_bounding_sphere := false;

    duplicate_file_behaviour := Duplicate_File_Behaviour.APPEND;
    color_from_path_behaviour := Color_From_Path_Behaviour.FILENAME_ONLY;

    show_header_annotation_tooltips := true;
    disable_reload_if_file_unchanged := true; // This can be annoying but otoh saves pointlessly loading unchanged files
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

#import "Basic";
// #import "Basic"()(MEMORY_DEBUGGER=true);
#import "File";
#import "File_Watcher";
#import "File_Utilities";
#import "String";
#import "Sort";
#import "Random";
#import "Reflection";
#import "Math";
#import "SDL";
Simp :: #import "Simp_beta_0_1_016";
#import "Window_Type";
#import "GL";
#import "Deep_Copy";
#import "Debug";
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
#load "point_cloud.jai";
#load "edge.jai";
#load "mesh.jai";
#load "aabb_tree.jai";
#load "aabb_tree_impl.jai";
#load "aabb_tree_debug.jai";
#load "grid.jai";
#load "axes.jai";
#load "selection_mode.jai";
#load "numeric.jai";
#load "intervals.jai";
#load "io_obj.jai";
#load "io_wkt.jai";
#load "rendering.jai";
#load "rendering_utils.jai";
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
#load "changelog.jai";
#load "colors.jai";

#load "kernel/distance.jai";
#load "kernel/intersect.jai";
#load "kernel/closest.jai";
#load "kernel/utility.jai";
#load "kernel/types.jai";
#load "kernel/test.jai";

#import "Compiler";
#run compiler_set_type_info_flags(GL_Procedures, .NO_SIZE_COMPLAINT);
#run compiler_set_type_info_flags(ImGui, .NO_SIZE_COMPLAINT);
