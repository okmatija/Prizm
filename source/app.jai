app : App;

// Shared global state is stored here
// @Cleanup Remove the thing not associated with the application logic directly, make these file scoped globals?
App :: struct {
    window : *SDL_Window = null;
    simp_font: *Simp.Dynamic_Font;
    theme : Prism_Theme;

    Folder :: struct {
        path : string; // owned
        auto_load_new_files := false;
        set_auto_reload_on_newly_loaded_files := false;
        last_frame_item_list_height_px : float; // How high the scrolling region showing the items in this folder would need to be to show all items
    }

    // When we source and entity from a file we update the directories in these members
    directories : [..]Folder; // named folder not directory since we use it to group items not on disk too, and its a nicer word
    file_watcher : File_Watcher;

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

    // @Refactor Make this entity 0
    user_selection : Mesh_Entity;
    user_selection_cursor_text_shown := false; // @Refactor This isn't really related to selection anymore
    user_selection_cursor_text_scale := .4;
    user_selection_max_point_count_for_selectable_entity := 5_000_000; // @Cleanup remove this? and make it only apply to entities without a spatial index 

    // Set the defaults for the user selection display
    user_selection.display_info.is_visible = true;
    user_selection.display_info.points_visible = true;
    user_selection.display_info.points_size = 6;
    user_selection.display_info.points_color = .{1, 0, .8, 1}; // @Volatile Used for the dynamic label text too
    user_selection.display_info.vertex_label_style.show_position = true;
    user_selection.display_info.vertex_label_style.label_color = .{0, 0, 0, 1};

    // The entity which set the clipping sphere center
    clipping_sphere_mode_entity_index : int = -1;

    // This member is used to implement the handy feature in clipping sphere mode where the use can click far away from a clipped entity and, while the click is held, have the wireframe of the items previously clipped with a sphere to show their wireframes. While this is happening the position/size of the clipping spheres is not changed.
    clipping_sphere_mode_last_entity_index_set : [..]int;

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

    demo_mode := false; // See demo_mode.jai

    debug_frame := false; // True on the frame in which space was pressed (see my_debug_function)
    debug_mode :=  false; // Toggled by pressing space (see my_debug_function)
    debug_color := CONTEXT_MENU_POPUP_TARGET_BORDER_COLOR;
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

remove_directory :: (directory : string) {
    if !folder_exists_on_disk(directory) {
        return; // Do not allow these directories to be removed
    }

    // Check if no other entities will need to watch this directory
    remove_directory := true;
    for app.entities {
        if it.source == .FILE_ON_DISK && get_directory(it.fully_pathed_name) == directory {
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

// nocommit Also pass the index to the predicate!
// nocommit Rename this to something less generic and use this name for a basic iterator over entities
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

VisibleSelectable :: #bake_arguments Entities_Iterator(should_visit = (e) => (
        e.display_info.is_visible &&
        e.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity
    ));

VisibleSelectableMeshTriangles :: #bake_arguments Entities_Iterator(should_visit = (e) => (
        e.display_info.is_visible &&
        (e.type == .MESH && e.mesh.geometry_format == .TRIANGLES) &&
        e.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity
    ));

VisibleSelectableMeshSegments :: #bake_arguments Entities_Iterator(should_visit = (e) => (
        e.display_info.is_visible &&
        (e.type == .MESH && e.mesh.geometry_format == .LINES) &&
        e.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity
    ));

VisibleSelectableMeshVertices :: #bake_arguments Entities_Iterator(should_visit = (e) => (
        e.display_info.is_visible &&
        (e.type == .MESH && e.mesh.geometry_format == .POINTS) &&
        e.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity
    ));

Visible_Selectable_Polyline_Soup3 :: #bake_arguments Entities_Iterator(should_visit = (e) => (
        e.display_info.is_visible &&
        e.type == .POLYLINE_SOUP3 &&
        e.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity
    ));

Visible_Selectable_Polyline_Soup2 :: #bake_arguments Entities_Iterator(should_visit = (e) => (
        e.display_info.is_visible &&
        e.type == .POLYLINE_SOUP2 &&
        e.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity
    ));

// :UserConfig hotload changes to this file
User_Settings :: struct {
    item_list_max_size_before_scroll_px := 300.;
    annotation_list_max_size_before_scroll_px := 400.;

    fit_to_screen_on_visibility_change :=  false;
    fit_to_screen_on_file_drop_event :=    true;
    fit_to_screen_on_file_watcher_event := true;

    camera_controls_keep_up_when_setting_look_along := false;

    camera_zoom_scrolling_ratio          := .8;
    // camera_zoom_dragging_follows_cursor  := false;
    // camera_zoom_dragging_ratio           := .8;
    camera_zoom_min_screen_filling_length_mm := 0.; // .0001; // .1um
    camera_zoom_max_screen_filling_length_factor := 4.; // multiplies a visible scene bounding sphere radius
    camera_zoom_max_limited_by_scene_bounding_sphere := false;

    closest_point_query_max_dist_px := 20;

    duplicate_file_behaviour := Duplicate_File_Behaviour.APPEND;
    color_from_path_behaviour := Color_From_Path_Behaviour.FILENAME_ONLY;

    show_header_annotation_tooltips := true;
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
        <<value = clamp(<<value, min, max);
    }

    using app.settings;
    // clamp(*camera_zoom_dragging_ratio, .3, .99);
    clamp(*camera_zoom_scrolling_ratio, .3, .99);
    clamp(*camera_zoom_min_screen_filling_length_mm, 0., app.camera.scene_bounding_sphere.radius / 2);
    clamp(*item_list_max_size_before_scroll_px, 100., .75 * app.current_window_height);
    clamp(*annotation_list_max_size_before_scroll_px, 100., .75 * app.current_window_height);
    clamp(*closest_point_query_max_dist_px, 0, 100);
}

set_prism_theme :: (theme : Prism_Color_Theme) {
    if #complete theme == {
        case .DARK;
            ImGui.StyleColorsDark();
            app.theme = Prism_Theme_Dark.{};
        case .LIGHT;
            ImGui.StyleColorsLight();
            app.theme = Prism_Theme_Light.{};
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
#import "SDL";
Simp :: #import "Simp_beta_0_1_016";
#import "Window_Type";
#import "GL";
#import "Deep_Copy";
Debug :: #import "Debug";
#import "Hash";
#import "Hash_Table";
#import "Tagged_Union"(DEBUG=true);
#import "freetype255";
#import "System";
ImGui :: #import "ImGui";
#load "imgui_impl_sdl.jai"; // SDL platform backend
#load "imgui_impl_opengl3.jai"; // OpenGL renderer backend

#if OS == .WINDOWS {
#import "Windows";
#import "Windows_Utf8";
}

#load "annotations.jai";
#load "axis_box.jai";
#load "polyline.jai";
#load "polygon.jai";
#load "edge.jai";
#load "mesh.jai";
#load "mesh_utils.jai";
#load "simple_mesh.jai";
#load "simple_mesh_io.jai";
#load "aabb_tree.jai";
#load "aabb_tree_impl.jai";
#load "aabb_tree_debug.jai";
#load "grid.jai";
#load "axes.jai";
#load "selection_mode.jai";
#load "clipping_sphere_mode.jai";
#load "numeric.jai";
#load "intervals.jai";
#load "io_obj.jai";
#load "io_wkt.jai";
#load "io_utils.jai";
#load "rendering.jai";
#load "rendering_utils.jai";
#load "carpet.jai";
#load "camera.jai";
#load "entities.jai";
#load "ui.jai";
#load "shapes.jai";
#load "keymap.jai";
#load "target_items.jai";
#load "inspector.jai";
#load "lexer.jai";
#load "parser.jai";
#load "changelog.jai";
#load "colors.jai";
#load "demo_mode.jai";

#load "console/console.jai";
#load "console/commands.jai";
#load "console/grid_commands.jai";

#load "kernel/distance.jai"; // @Cleanup
#load "kernel/intersect.jai"; // @Cleanup
#load "kernel/closest.jai"; // @Cleanup
#load "kernel/GTE_Mathematics_Vector.jai";
#load "kernel/GTE_Mathematics_Vector3.jai";
#load "kernel/GTE_Mathematics_Segment.jai";
#load "kernel/GTE_Mathematics_DistPointRay.jai";
#load "kernel/GTE_Mathematics_DistLineSegment.jai";
#load "kernel/GTE_Mathematics_DistLine3Triangle3.jai";
#load "kernel/GTE_Mathematics_DistRay3Triangle3.jai";
#load "kernel/GTE_Mathematics_DistPointTriangle.jai";
#load "kernel/utility.jai";
#load "kernel/types.jai";
#load "kernel/test.jai";

#import "Compiler";
#run compiler_set_type_info_flags(GL_Procedures, .NO_SIZE_COMPLAINT);
#run compiler_set_type_info_flags(ImGui, .NO_SIZE_COMPLAINT);
