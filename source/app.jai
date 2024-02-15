app : App;

// Shared global state is stored here
// @Cleanup Remove the thing not associated with the application logic directly, make these file scoped globals?
App :: struct {
    window : *SDL_Window = null;
    window_maximized := false;
    window_draggable_rect_min : ImGui.ImVec2;
    window_draggable_rect_max : ImGui.ImVec2;
    window_focussed_opacity : float = 1.;
    window_unfocussed_opacity : float = 1.;

    simp_font: *Simp.Dynamic_Font;

    theme : Prizm_Theme;

    Folder :: struct {
        path : string; // owned
        auto_load_new_files := false;
        set_auto_reload_on_newly_loaded_files := false;
        last_frame_item_list_height_px : float; // How high the scrolling region showing the items in this folder would need to be to show all items
    }

    // When we source and entity from a file we update the directories in these members
    directories : [..]Folder; // named folder not directory since we use it to group items not on disk too, and its a nicer word
    file_watcher : File_Watcher();

    // When the user adds directories (via drag-drop or via the commandline on startup) show UI asking the user what should be done with the files in those directories
    pending_directories : [..]Pending_Directory;

    Pending_Directory :: struct {
        using directory : Folder;
        unloadable_file_count : int;

        Pending_File :: struct {
            fully_pathed_filename : string; // owned
            modtime : Apollo_Time;
            size_in_bytes : s64;
            is_selected := true;
            is_loaded := false;
        }
        
        // Loadable files present in the directory at the time the directory was queried
        loadable_files : [..]Pending_File;
    }


    INITIAL_WINDOW_WIDTH  : s32 : 1440;
    INITIAL_WINDOW_HEIGHT : s32 : 900;

    // @Cleanup Rename these to have _px suffix
    current_window_width := INITIAL_WINDOW_WIDTH;
    current_window_height := INITIAL_WINDOW_HEIGHT;
    fullscreen := false;

    text_vao : GLuint;
    text_vbo : GLuint;

    aabb_program : GLuint;
    triangles_program : GLuint; // For triangle and solid wireframe rendering (triangle edges rendered on triangle faces)
    points_lines_program : GLuint;
    triangles_normal_program : GLuint;
    segments_normal_program : GLuint;
    points_normal_program : GLuint;

    Background_Style :: enum #specified {
        SOLID_COLOR :: 0;
        CUSTOM_SHADER :: 1;
    };

    background_style := Background_Style.CUSTOM_SHADER;
    background_solid_color := Vector4.{230./255, 230./255, 230./256, 1.};
    background_program : GLuint;
    background_vao : GLuint;

    show_ui := true;
    show_fps := false;

    Ribbon_Button_Mode :: enum #specified {
        HIDE :: 0; // Hide the ribbon buttons
        SHOW :: 1; // Show the ribbon buttons (if ui is showing and console not showing)
        AUTO :: 2; // Hide/show the ribbon buttons if cursor is near/far
    }

    ribbon_button_mode := Ribbon_Button_Mode.SHOW;

    label_format : Label_Format;
    Label_Format :: struct {
        format_float : FormatFloat;  // We ignore the `value` field
        format_float.mode = .SHORTEST;
        format_float.trailing_width = 8;
        format_float.zero_removal = .NO;

        format_struct : FormatStruct; // We ignore the `value` field
        format_struct.use_long_form_if_more_than_this_many_members = 99999;

        location : Location = .CLOSEST_POINT;

        Location :: enum {
            CLOSEST_POINT;
            // @Incomplete Support visualizing labels in different positions
            // VIEWPORT;
            // CONSOLE;
            // CENTROID;
        }
    }

    // Used when more than one item is selected/edited via shortcuts
    // @FIXME @Cleanup Rework this template stuff. When we first start a selection that items state should become the template, and then we edit that, this is easy for users to understand and I think it would simplify the action buttons in target_items.jai
    template_display_info : Display_Info;
    template_aabb_world : AxisBox3;

    select_tool : Geometry_Select_Tool;

    // The entity which set the clipping sphere center
    clipping_sphere_mode_entity_index : int = -1;

    // This member is used to implement the handy feature in clipping sphere mode where the use can click far away from a clipped entity and, while the click is held, have the wireframe of the items previously clipped with a sphere to show their wireframes. While this is happening the position/size of the clipping spheres is not changed.
    clipping_sphere_mode_last_entity_index_set : [..]int;

    camera : Camera;
    console : Console;
    entities : [..]*Entity;

    keymap : Keymap;
    keymap_actions : Keymap;
    keymap_keydown : Keymap;
    settings : User_Settings;

    closing_application := false; // Set this to true to quit the application on the next frame

    // Vertices with inf/nan components are replaced with the corresponding coordinate of invalid_point
    // Indices that reference missing vertices will reference a new point positioned at invalid_point
    // The user can change this coordinate if the default zero value is inconvenient, reloading the file will show the new result
    invalid_point : Vector3 = .{0, 0, 0};

    API :: struct {
        using_unreal := true;
        using_unreal_engine := false;
        using_unreal_geometrycore := false;
    }
    api : API;

    Version :: struct {
        name : string;
        date : string;
        description : string;
    }

    Known_Issue :: struct {
        name :        string;
        description : string;
    }
    known_issues : [..]Known_Issue;

    debug_frame := false; // True on the frame in which space was pressed (see my_debug_function)
    debug_mode :=  false; // Toggled by pressing space (see my_debug_function)
    debug_color := CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR;
}

Texture :: struct {
    gl_handle : GLuint;
    width : s32;
    height : s32;
}

// @Incomplete Deduplicate file watcher directories on linux

deinit :: (directory : app.Folder) {
    free(directory.path);
}

deinit :: (pending : app.Pending_Directory) {
    deinit(pending.directory);
    for pending.loadable_files {
        free(it.fully_pathed_filename);
    }
    array_reset(*pending.loadable_files);
}

add_directory :: (directory_path : string) -> *app.Folder {
    // post-condition (+2 for Entity_Source.PRESET_SHAPE and .COMMAND_OUTPUT)
    // defer assert(app.directories.count == app.file_watcher.directories.count + 2);

    result : *app.Folder;

    got_directory, got_directory_valid := is_directory(directory_path);
    if !got_directory_valid || !got_directory {
        log_warning("Expected a directory, but got something else ('%')", directory_path);
        return result;
    }

    folder : app.Folder;
    folder.path = copy_string(directory_path);

#if OS == .WINDOWS {
    for * app.directories {
        if it.path == folder.path {
            result = it;
            break;
        }
    }
    if !result {
        array_add(*app.directories, folder);

        path := parse_path(directory_path);
        fully_exists, how_much_exists := how_much_of_path_exists_on_the_local_filesystem(path);
        if fully_exists {
            // Update the list of watched directories so that we can reload this entity
            add_directories(*app.file_watcher, folder.path);
        }

        result = *app.directories[app.directories.count - 1];
    }
} else {
    assert(false); // @Incomplete linux support
}
    return result;
}

folder_exists_on_disk :: (directory : string) -> bool {
    if directory == PRESET_SHAPE_FOLDER || directory == COMMAND_OUTPUT_FOLDER || directory == SELECTION_FOLDER {
        return false;
    }
    return true;
}

remove_directory_if_unwatched :: (directory : string) {
    if !folder_exists_on_disk(directory) {
        return; // Do not allow these item folders to be removed
    }

    // Check if no other entities will need to watch this directory
    remove_directory := true;
    for :All app.entities {
        if it.source.kind == ._Entity_Source_File && get_directory(get_entity_source(it).path) == directory {
            remove_directory = false;
            break;
        }
    }

    if remove_directory {
        for app.directories {
            if it.path == directory {
                deinit(it);
                remove it;
                break;
            }
        }

        #if OS == .WINDOWS {
        for app.file_watcher.directories {
            if it.name == directory {
                // @FIXME do we have a memory leak here??
                remove it;
                break;
            }
        }
        } else {
            assert(false); // @Incomplete linux support
        }
    }
}


current_window_aspect_ratio_width_over_height :: () -> float {
    return cast(float) app.current_window_width / cast(float) app.current_window_height;
}

EntitiesIterator :: (entities : *[..]*Entity, body : Code, flags : For_Flags, $entity_filter : Code) #expand {
    #assert(flags == 0); // No options are supported

    for entity, entity_index : entities.* {
        `it_index := entity_index;
        `it := entity;
        if #insert,scope() entity_filter {
            continue;
        }

        #insert (break=break entity) body;
    }
}

All ::      #bake_arguments EntitiesIterator(entity_filter=false);
Visible ::  #bake_arguments EntitiesIterator(entity_filter=#code !it.display_info.is_visible);
Selected :: #bake_arguments EntitiesIterator(entity_filter=#code !it.is_selected);

// :UserConfig hotload changes to this file
User_Settings :: struct {
    item_details_uses_menu := true;

    item_list_max_size_before_scroll_px := 300.;
    annotation_list_max_size_before_scroll_px := 400.;

    fit_to_screen_on_visibility_change :=  false;
    fit_to_screen_on_file_drop_event :=    true;
    fit_to_screen_on_file_watcher_event := false; // Having this as true can be kinda annoying

    camera_controls_keep_up_when_setting_look_along := false;

    camera_zoom_scrolling_ratio          := .8;
    // camera_zoom_dragging_follows_cursor  := false;
    // camera_zoom_dragging_ratio           := .8;
    camera_zoom_min_screen_filling_length_mm := 0.; // .0001; // .1um
    camera_zoom_max_screen_filling_length_factor := 4.; // multiplies a visible scene bounding sphere radius
    camera_zoom_max_limited_by_scene_bounding_sphere := false;

    closest_point_query_max_dist_px := 20;
    labelling_mode : Labelling_Mode = .RAY_CAST;

    // if labelling_mode == .RAY_CAST  this is the distance in pixels used when the labels are shown on nearby elements
    // if labelling_mode == .SPOTLIGHT this is the radius in pixels around the cursor where labels are visible 
    labelling_radius_px := 50;

    duplicate_file_behaviour := Duplicate_File_Behaviour.APPEND;
    color_from_path_behaviour := Color_From_Path_Behaviour.FILENAME_ONLY;

    show_header_annotation_tooltips := false;
    disable_reload_key_if_file_unchanged := true;

    show_imgui_demo_window := false;
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
    clamp :: (value : *$T, min : T, max : T) {
        value.* = clamp(value.*, min, max);
    }

    using app.settings;
    // clamp(*camera_zoom_dragging_ratio, .3, .99);
    clamp(*camera_zoom_scrolling_ratio, .3, .99);
    clamp(*camera_zoom_min_screen_filling_length_mm, 0., app.camera.scene_bounding_sphere.radius / 2);
    clamp(*item_list_max_size_before_scroll_px, 100., .75 * app.current_window_height);
    clamp(*annotation_list_max_size_before_scroll_px, 100., .75 * app.current_window_height);
    clamp(*closest_point_query_max_dist_px, 0, 100);
}

set_prizm_theme :: (theme : Prizm_Color_Theme) {
    if #complete theme == {
        case .DARK;
            ImGui.StyleColorsDark();
            app.theme = Prizm_Theme_Dark.{};
        case .LIGHT;
            ImGui.StyleColorsLight();
            app.theme = Prizm_Theme_Light.{};
    }

    ImGui.GetStyle().WindowRounding = 4;
    ImGui.GetStyle().PopupRounding = 4;
    ImGui.GetStyle().FrameRounding = 2;
    ImGui.GetStyle().FrameBorderSize = 1;
    ImGui.GetStyle().ChildBorderSize = 5;
    ImGui.GetStyle().DisabledAlpha = .5;
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
#import "Window_Type";
#import "GL";
#import "Deep_Copy";
Debug :: #import "Debug";
#import "Hash";
#import "Hash_Table";
#import "freetype255";
#import "System";
#import "stb_image";
ImGui :: #import "ImGui";
#load "imgui_impl_sdl.jai"; // SDL platform backend
#load "imgui_impl_opengl3.jai"; // OpenGL renderer backend

#if OS == .WINDOWS {
#import "Windows";
#import "Windows_Utf8";
}

Simp :: #import "Simp";

// @Cleanup @CompilerBug This should be a module but it doesn't work when we use it as a module
//#import "Tagged_Union_Enum"(DEBUG=true);
#load "Tagged_Union_Enum.jai";
#load "annotations.jai";
#load "mesh_utils.jai";
#load "simple_mesh.jai";
#load "numeric.jai";
#load "intervals.jai";
#load "rendering.jai";
#load "rendering_utils.jai";
#load "carpet.jai";
#load "entities.jai";
#load "target_items.jai";
#load "inspector.jai";
#load "colors.jai";
#load "updates.jai";

#load "console/console.jai";

#import "Compiler";
#run compiler_set_type_info_flags(GL_Procedures, .NO_SIZE_COMPLAINT);
#run compiler_set_type_info_flags(ImGui, .NO_SIZE_COMPLAINT);
