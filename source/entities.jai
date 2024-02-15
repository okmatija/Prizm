// @Cleanup Use a pool per entity? Store display info separate to entities so we don't trash cache when we check visibility
// @Refactor Maybe Entity should contain the mesh and the item variables, but data specific to rendering meshes should be in the mesh?

// :EntityInitializers I tried twice to make init functions for these structs but it seems like a waste of time! These structs collections of things, some don't need initting, and others do but in orders that change depending on the context e.g., set the mesh then convert to the shape, or set the shape and convert ot a mesh. It's fine just to set the fields when their needed, you could make local init functions specific to the local context if it saves typing out the initting code.

Entity :: struct {
    // Note @ctp has a custom version of Tagged_Union posted on the secret beta discord, which works around some problems in this one (not exactly sure what the problems are though)
    // Note: To debug in RemedyBG use this in the watch window, note that bytes will be a static c-array of bytes, so it doesn't have a data member:
    //       (Entity_Source_File*)(&app->entities.data[0]->_source.bytes)
    source : Tagged_Union(
        // Order is important here because reload_items uses it for sorting
        // @Think If the order is changed but the values stay constant what happens?
        Entity_Source_File,
        Entity_Source_Preset,
        Entity_Source_Command,
        Entity_Source_Selection,
    );

    is_selected := false;
    is_hovered := false;

    render_info : Render_Info;
    display_info : Display_Info;

    // Note the transform stored in this mesh also applies to:
    // - Shape geometry in the specialized types
    // - Bounding shapes in render_info
    mesh : Simple_Mesh;

    // @Incomplete Perhaps there should be a pool for the annotation strings?
    command_annotations : [..]Annotation;
    block_annotations :   [..]Annotation; // Comments in the file but not attached to any particular geometry, the first block of comments will be shown in the item tooltip
    vertex_annotations :  [..]Annotation; // Comments attached to vertices e.g., v directives in .obj files
    point_annotations :   [..]Annotation; // Comments attached to vertices e.g., p directives in .obj files
    line_annotations :    [..]Annotation; // Comments attached to line segments e.g., l directives in .obj files
    face_annotations :    [..]Annotation; // Comments attached to triangles e.g., f directives in .obj files
    annotation_info : Annotation_Info;

    Annotation_Info :: struct {
        show_kind := Annotation.Kind.TRIANGLE; // Only ONE
    }

    // @Incomplete
    // user_data : *void; // Registered commands may want to attach data here

    // Move this to entity source base?
    // This gets set when we add the entity to app.entities, and makes sense only in that context (I think)
    generation_index : int; // @Cleanup delete this incorrect comment: entities with the same 'fully_pathed_name' will increment this
}

SELECTION_FOLDER :: "Selections";
PRESET_SHAPE_FOLDER :: "Examples";
COMMAND_OUTPUT_FOLDER :: "Command Outputs";

update_entity_transform :: (entity : *Entity, shift : Vector3) {
}

// Intentionally not implemented: Keep it simple and just remove the entity using remove_entity_by_index
// clear :: (using entity : *Entity) {}


remove_entity_by_index :: (entity_to_remove_index : int) {
}

remove_entities_if_selected :: () {
}

deinit :: (using entity : *Entity) {
}

// If matching_name_behaviour == .OVERWRITE you need to also set entity.generation_index to the value you wanted
add_entity :: (entity : *Entity, matching_name_behaviour : Duplicate_File_Behaviour) {
}

is_changed_on_disk :: (entity : Entity) -> bool {
    return true;
}

temp_visible_entities :: () -> [..]*Entity {
    visible : [..]*Entity = temp_array(*Entity);
    return visible;
}

temp_selected_entities :: () -> [..]*Entity {
    selected : [..]*Entity = temp_array(*Entity);
    return selected;
}

count_selected_entities :: () -> s64 {
    return 0;
}

compute_entity_primary_color :: (using entity : Entity) -> Vector4 {
    return .{};
}

get_entity_primary_color :: (using entity : *Entity) -> *Vector4, *bool {
    return null, null;
}

set_entity_primary_color :: (using entity : *Entity) {
}

// Assumes that fully_pathed_name is canonically formatted (see canonically_formatted_path_string)
// Returns a string pointing into the argument
entity_name :: (fully_pathed_name : string) -> string {
    return "";
}

// Returns a string pointing into entity.fully_pathed_name
entity_name :: (entity : Entity) -> string {
    return "---";
}

entity_description :: (using entity : Entity, with_creation_time : bool) -> string {
    return "";
}

// @Incomplete @Think Maybe we should handle visiblity on a more granular level e.g., on the element type level? We would need separate bounding geometry on the level of visibility control, which actually kindof makes sense.

// Result could be an empty sphere. Does not check visiblity
entity_raw_world_bounding_sphere :: (using entity : *Entity) -> Sphere {   
    return .{};
}

// Result could be an empty sphere. Does not check visibility
entity_raw_world_clipping_sphere :: (using entity : Entity) -> Sphere {
    if display_info.clip_sphere.is_active {
        return display_info.clip_sphere.sphere; // Already in world space. Should not be empty (radius may be infinite though)
    }
    return .{}; // Empty sphere
}

// Result could be an empty_sphere.
// Checks visibility, entity-level state checking like this is probably not a perf problem and makes the API more convenient. Also, it wouldn't really make sense to account for clipping, which affects visibility, but not account for overall visibility
// Accounts for clipping sphere and @Incomplete clipping ranges
entity_world_bounding_sphere :: (using entity : *Entity, $radius_of_point : float = 0) -> Sphere {
    return .{};
}

visit_visible :: #code !is_visible(it);
visit_visible_selected :: #code !(is_visible(it) && it.is_selected);

// Result could be an empty_sphere.
// Accounts for clipping sphere @Incomplete FIXME clipping ranges
// Note: hidden entities are skipped regardless of entity_filter, because entity_world_bounding_sphere returns an empty sphere in that case
entities_world_bounding_sphere :: ($entity_filter : Code = visit_visible) -> Sphere {
    return .{};
}

entities_world_bounding_radius :: ($entity_filter : Code = visit_visible, center : Vector3) -> Sphere {
    return .{};
}


entity_annotation_count :: (using entity : Entity, only_geometry_annotations := false) -> int {
    return 0;
}

entity_sort_annotations :: (using entity : Entity, compare : (Annotation, Annotation) -> s64) {
}

// The header annotation is the first block annotation
entity_header_annotation :: (entity : *Entity) -> *Annotation {
    return null;
}

// FIXME This is fragile when you add a new annotation array
set_entity_annotations :: (entity : *Entity,
    command_annotations : [..]Annotation,
    block_annotations :  [..]Annotation,
    vertex_annotations : [..]Annotation,
    point_annotations : [..]Annotation,
    face_annotations :   [..]Annotation,
    line_annotations :   [..]Annotation) {
}

// @Think Do we need this is we have a default value for kinds?
AnnotationIterator :: #bake_arguments AnnotationIteratorBase(
    // @Volatile
    kinds=Annotation.Kind.COMMAND|.BLOCK|.POINT|.VERTEX|.LINE|.TRIANGLE
    );

AnnotationIteratorBase :: (using entity : *Entity, body : Code, flags : For_Flags, kinds : Annotation.Kind) #expand {
    #assert(flags == 0); // No options are supported

    `it : Annotation;
    `it_index : int;

    if kinds & .COMMAND {
        for annotation, annotation_index : command_annotations {
            it, it_index = annotation, annotation_index;
            #insert body;
        }
    }

    if kinds & .BLOCK {
        for annotation, annotation_index : block_annotations {
            it, it_index = annotation, annotation_index;
            #insert body;
        }
    }

    if kinds & .VERTEX {
        for annotation, annotation_index : vertex_annotations {
            it, it_index = annotation, annotation_index;
            #insert body;
        }
    }

    if kinds & .POINT {
        for annotation, annotation_index : point_annotations {
            it, it_index = annotation, annotation_index;
            #insert body;
        }
    }

    if kinds & .LINE {
        for annotation, annotation_index : line_annotations {
            it, it_index = annotation, annotation_index;
            #insert body;
        }
    }

    if kinds & .TRIANGLE {
        for annotation, annotation_index : face_annotations {
            it, it_index = annotation, annotation_index;
            #insert body;
        }
    }
}

color_from_path :: (path : string) -> Vector4 {
    if path.count == 0 {
        return .{1., 1., 1., 1.};
    }

    to_hash : string;
    if app.settings.color_from_path_behaviour == {
        case .FILENAME_ONLY;
            parsed := parse_path(path);
            to_hash = parsed.words[parsed.words.count - 1];
        case .FULLY_PATHED_FILENAME;
            to_hash = path;
    }

    return color_from_string(to_hash);
}

color_from_string :: (str : string) -> Vector4 {
    return .{};
}

// @FIXME Revisit this find_entity function now that we've added a bunch of fields to the Entity type

// Find the entity with matching name
// If generation_index >= 0 then find the entity with the given generation_index, otherwise find the one with maximum generation_index
// Return null, -1 if no matching entity is found
find_entity :: (fully_pathed_name : string, generation_index : int) -> *Entity, int {
    return null, 0;
}

// @Think Add a function to change closest_point_element to .VERTEX if the barycentric/segment parameter is 0/1?
Closest_Point_Ray_Entity :: struct {
    // Valid values are POINT/SEGMENT/TRIANGLE.
    // When the closest point was computed on a triangle this will be .TRIANGLE and not .SEGMENT/.POINT, even if closest_point.triangle.distance > 0. This will be only be .SEGMENT/.POINT when the ray was tested against segments/points
    closest_point_element : Simple_Mesh_Element = .MESH;

    // If the distance member is zero the closest point is an intersection point
    using closest_point : union {
        point : Closest_Point_Ray_Point;
        segment : Closest_Point_Ray_Segment;
        triangle : Closest_Point_Ray_Triangle;
    }

    element_index : int = -1;
    entity_index : int = -1;
}

get_ray_parameter :: (using closest : Closest_Point_Ray_Entity) -> float {
    return 0.;
}

get_closest_point_on_ray :: (using closest : Closest_Point_Ray_Entity) -> Vector3 {
    return .{};
}

get_closest_point_on_element :: (using closest : Closest_Point_Ray_Entity) -> Vector3 {
    return .{};
}


is_visible :: (e : *Entity) -> bool {
    return e.display_info.is_visible;
}

// @Refactor Use spatial lookups on triangles/segments/points
// @Cleanup Remove this function, replace it with a version find_closest_element which has a new arguement which determines what elements are being searched ie to have this behaviour we would only look for vertices
find_closest_vertex :: ($entity_filter : Code = visit_visible) -> Closest_Point_Ray_Entity {
    return .{};
}

// Return true if the given point is further than max_distance_px from the mouse position and false otherwise
outside_screen_dist :: inline (point_world : Vector3, projection_from_world : Matrix4, max_distance_px : int) -> bool {
    return false;
}

// Return the model space query radius for a given bounding box and query radius in pixels
get_model_space_query_radius :: (bbox : AxisBox3, query_radius_px : int) -> float {
    // @Incomplete Support perspective projection
    distance_1 : float = ((app.camera.right - app.camera.left) / app.current_window_width) * query_radius_px;
    distance_2 : float = length(diagonal(bbox)) / 20.;
    return min(distance_1, distance_2);
}

elements_targetted :: (entity : Entity) -> bool {
    return entity.display_info.is_visible;
}

elements_not_targetted :: (entity : Entity) -> bool {
    return false;
}

is_occluder :: (entity : Entity) -> bool {
    return entity.display_info.is_visible &&
        entity.display_info.triangle_style.visible &&
        entity.mesh.positions.count &&
        entity.mesh.triangles.count;
        // Do NOT do the following, we did it for a bit but, its super annoying not to be able to select an item because you made transparent!
        //entity.display_info.triangle_style.color.w >= .5;
}

// Result positions are in world space
// Rename these to target_XXX? Since we want to visit triangles for occlusion purposes even if we are not searching for a closest point on triangles (aka targetting triangles)
find_closest_element :: (
    // TODOOO Shouldn't these be checking points/segments/triangles visibility as well as the overall entity visibility?
    target_points : (Entity)->bool = elements_targetted,
    target_segments : (Entity)->bool = elements_targetted,
    target_triangles : (Entity)->bool = elements_targetted
    ) -> Closest_Point_Ray_Entity {
    return .{};
}

num_selected_entities :: () -> int {
    count := 0;
    return count;
}

load_one_file :: (filename : string, matching_name_behaviour : Duplicate_File_Behaviour) -> [..]*Entity {
    results : [..]*Entity;
    return results;
}

// @Cleanup rename to load_from_memory, and rename the filename argument..? or add another name parameter (or just set that after HMMMM)
load_one_file_from_memory :: (filename : string, contents : string, name : string, matching_name_behaviour : Duplicate_File_Behaviour) -> [..]*Entity {
    results : [..]*Entity;
    return results;
}


// @Incomplete pass Duplicate_File_Behaviour 
// Reload the entity using it's fully_pathed_filename, if loading fails clear the entity
reload_entity :: (entity : *Entity, triggered_by_button := false) -> did_reload : bool {
    return false;
}

set_entity_source_from_file :: (entity : *Entity, fully_pathed_filename : string, loc := #caller_location) {
}

set_entity_source_from_preset :: (entity : *Entity, name : string, preset_proc : #type ()->*Entity, vertex_count : s64) {
    assert(entity != null);

    source : Entity_Source_Preset;
    source.path = sprint("%/%", PRESET_SHAPE_FOLDER, name);
    source.creation_time = current_time_consensus();
    source.creation_size = vertex_count;
    source.preset_proc = preset_proc;

    set(*entity.source, source);
}

set_entity_source_from_selection :: (entity : *Entity, name : string, vertex_count : s64) {
    assert(entity != null);

    source : Entity_Source_Selection;
    source.path = sprint("%/%", SELECTION_FOLDER, name);
    source.creation_time = current_time_consensus();
    source.creation_size = vertex_count;

    set(*entity.source, source);
}

set_entity_source_from_command :: (entity : *Entity, name : string, console_command : string, vertex_count : s64) {
    assert(entity != null);

    source : Entity_Source_Command;
    source.path = sprint("%/%", COMMAND_OUTPUT_FOLDER, name);
    source.creation_time = current_time_consensus();
    source.creation_size = vertex_count;
    source.console_command = copy_string(console_command);

    set(*entity.source, source);
}

// set_entity_source_from_code :: (entity : *Entity, name : string, console_command : string, vertex_count : s64) {
//     assert(entity != null);
//     entity.fully_pathed_name = copy_string(tprint("%/%", SOURCE_CODE_FOLDER, name));
//
//     entity.source = .SOURCE_CODE;
//     entity.creation_time = current_time_consensus();
//     entity.creation_size = vertex_count;
// }

// Preconditions: entity.source->path has been set
set_entity_display_info :: (using entity : *Entity) {
    assert(entity != null);

    primary_color : Vector4 = compute_entity_primary_color(entity); 

    // @Cleanup Why are checking counts here? We could just remove all those ifs

    if mesh.triangles.count {
        display_info.triangle_style.visible = true;
        display_info.triangle_style.color = primary_color;
    }

    if mesh.segments.count {
        display_info.segment_style.visible = true;
        display_info.segment_style.color = primary_color;
    }

    if mesh.points.count {
        display_info.point_style.visible = true;
        display_info.point_style.color = primary_color;
    }

    if mesh.positions.count {
        display_info.vertex_style.color = primary_color;
        //display_info.vertex_style.visible = true; // All meshes have positions, and we don't want to show them always
    }
}

init_entity_spatial_index :: (using entity : *Entity) {
}

get_entity_index :: (entity : *Entity) -> int {
    for :All app.entities {
        if it == entity {
            return it_index;
        }
    }
    return -1;
}

get_entity_source :: (entity : Entity) -> *Entity_Source {
    return cast(*Entity_Source)entity.source.bytes.data;
}

get_entity_source_description :: (entity : Entity) -> string {
    if #complete entity.source.kind == {
        case ._Entity_Source_File; return "file";
        case ._Entity_Source_Preset; return "preset/example shape";
        case ._Entity_Source_Command; return "console command";
        case ._Entity_Source_Selection; return "selection";
    }
    return "";
}

// @Cleanup Are the comments here out of date?
Entity_Source :: struct {
    // if kind == .FILE_ON_DISK these are filled using file_modtime_and_size
    // otherwise these are the current_time_consensus and the mesh vertex count
    creation_time : Apollo_Time;
    creation_size : s64; // Size of the entity, format depends on the subtype

    // This should be used to find entities
    // If kind == .FILE_ON_DISK   this is the fully pathed filename
    // If kind == .SELECTION      this is SELECTION_FOLDER/name
    // If kind == .COMMAND_OUTPUT this is COMMAND_OUTPUT_FOLDER/name
    // If kind == .PRESET_SHAPE   this is PRESET_SHAPE_FOLDER/name
    path : string; // Format depends on the subtype
}

Entity_Source_File :: struct {
    using #as base : Entity_Source;

    // @Refactor use Duplicate_File_Behaviour, default to IGNORE but user can choose OVERWRITE/APPEND reload behavior
    auto_reload : bool;
}

Entity_Source_Preset :: struct {
    using #as base : Entity_Source;

    // The function that was called to generate the entity, reloading runs this procedure
    preset_proc : #type ()->*Entity;
}

Entity_Source_Command :: struct {
    using #as base : Entity_Source;

    // The console command the user executed to generate the entity, reloading runs this command
    console_command : string;
}

Entity_Source_Selection :: struct {
    using #as base : Entity_Source;
}

#scope_file

load_one_file_from_memory :: (filename : string, contents : string, name : string) -> [..]*Entity {
    results : [..]*Entity;

    return results;
}