// @Cleanup Use a pool per entity? Store display info separate to entities so we don't trash cache when we check visibility
// @Refactor Make AABB_Tree pointers, and default to brute force search if the pointer is null
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
    spatial : *AABB_Tree;

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
    {
        using entity.mesh.world_from_model;
        _14, _24, _34 += shift.x, shift.y, shift.z;
    }

    // Don't update entity.render_info because that uses entity.mesh.world_from_model
    // in the same way as the mesh data i.e., those shapes are defined in model space

    // entity.render_info.bounding_sphere.center  += shift;
    // entity.render_info.bounding_aabb.min_point += shift;
    // entity.render_info.bounding_aabb.max_point += shift;

    update_clip_domains :: true; // @Think maybe expose this?
    if update_clip_domains {
        using entity.display_info;
        clip_sphere.center += shift;
        clip_sphere_prev.center += shift;
        for * clip_ranges {
            delta := dot_product(it.normal, shift);
            it.min += delta;
            it.max += delta;
        }
    }
}

// Intentionally not implemented: Keep it simple and just remove the entity using remove_entity_by_index
// clear :: (using entity : *Entity) {}


remove_entity_by_index :: (entity_to_remove_index : int) {
    if entity_to_remove_index >= 0 && entity_to_remove_index < app.entities.count {
        entity_to_remove : *Entity = app.entities[entity_to_remove_index];
        remove_directory_if_unwatched(get_directory(get_entity_source(entity_to_remove).path));
        deinit(entity_to_remove);
        free(entity_to_remove);
        array_ordered_remove_by_index(*app.entities, entity_to_remove_index);
    }
}

remove_entities_if_selected :: () {
    maybe_remove_folders : [..]string = temp_array(string);
    selected_entities : [..]*Entity = temp_selected_entities();

    for selected_entities {
        entity_path := get_entity_source(it).path;
        log("Removed item with path '%'", entity_path);

        array_add(*maybe_remove_folders, get_directory(entity_path));
        deinit(it);
        free(it);

        removed := array_ordered_remove_by_value(*app.entities, it);
        assert(removed);
    }

    for maybe_remove_folders {
        remove_directory_if_unwatched(it);
    }
}

deinit :: (using entity : *Entity) {
    if !entity return;

    deinit(*mesh);
    deinit(spatial);
    
    for :AnnotationIterator entity {
        deinit(it);
    }

    // @Cleanup We should have AnnotationListIterator, so we don't need to change so many places
    array_reset(*command_annotations);
    array_reset(*block_annotations);
    array_reset(*vertex_annotations);
    array_reset(*point_annotations);
    array_reset(*face_annotations);
    array_reset(*line_annotations);

    free(get_entity_source(entity).path);
    if #complete source.kind == {
        case ._Entity_Source_File;      #through;
        case ._Entity_Source_Preset;    #through;
        case ._Entity_Source_Selection;
            // Do nothing
        case ._Entity_Source_Command;
            source := isa(entity.source, Entity_Source_Command);
            free(source.console_command);
    }

    if render_info.positions_vbo         glDeleteBuffers(1, *render_info.positions_vbo);
    if render_info.positions_vao         glDeleteVertexArrays(1, *render_info.positions_vao);

    if render_info.points_vbo            glDeleteBuffers(1, *render_info.points_vbo);
    if render_info.points_vao            glDeleteVertexArrays(1, *render_info.points_vao);

    if render_info.segments_vbo          glDeleteBuffers(1, *render_info.segments_vbo);
    if render_info.segments_vao          glDeleteVertexArrays(1, *render_info.segments_vao);
    if render_info.segments_normals_vao  glDeleteVertexArrays(1, *render_info.segments_normals_vao);

    if render_info.triangles_vbo         glDeleteBuffers(1, *render_info.triangles_vbo);
    if render_info.triangles_vao         glDeleteVertexArrays(1, *render_info.triangles_vao);
    if render_info.triangles_edges_vao   glDeleteVertexArrays(1, *render_info.triangles_edges_vao);
    if render_info.triangles_normals_vao glDeleteVertexArrays(1, *render_info.triangles_normals_vao);

    render_info = .{};
}

// If matching_name_behaviour == .OVERWRITE you need to also set entity.generation_index to the value you wanted
add_entity :: (entity : *Entity, matching_name_behaviour : Duplicate_File_Behaviour) {
    if entity == null {
        return;
    }

    found : *Entity;
    found_index : int = -1;
    if matching_name_behaviour == .APPEND {
        // Finds the entity with maximum generation index
        found, found_index = find_entity(get_entity_source(entity).path, -1);
    } else {
        // Finds the entity with matching generation index
        found, found_index = find_entity(get_entity_source(entity).path, entity.generation_index);
    }

    if found {

        if #complete matching_name_behaviour == {

            case .IGNORE;

                // Do nothing

            case .OVERWRITE;

                entity.mesh.world_from_model = found.mesh.world_from_model;
                // entity.generation_index =   found.generation_index; // Already matches
                entity.display_info =          found.display_info;
                entity.is_selected =           found.is_selected;

                entity_file_source := isa(entity.source, Entity_Source_File);
                found_file_source :=  isa(found.source,  Entity_Source_File);
                if entity_file_source && found_file_source {
                    entity_file_source.auto_reload = found_file_source.auto_reload;
                }

                deinit(found);

                // @Cleanup Replace with code to set the dirty flag
                maybe_update_render_info(*entity.render_info, *entity.mesh);

                app.entities[found_index] = entity;

            case .APPEND;

                entity.generation_index = found.generation_index + 1;
                array_add(*app.entities, entity);
        }
    } else {
        array_add(*app.entities, entity);
    }
}

is_changed_on_disk :: (entity : Entity) -> bool {
    changed := false;
    if entity.source.kind == ._Entity_Source_File {
        source := isa(entity.source, Entity_Source_File);
        assert(source != null);
        modtime, size, ok := file_modtime_and_size(source.path);
        if modtime > source.creation_time || size != source.creation_size {
            changed = true;
        }
    }
    return changed;
}

temp_visible_entities :: () -> [..]*Entity {
    visible : [..]*Entity = temp_array(*Entity);
    for :Visible app.entities array_add(*visible, it);
    return visible;
}

temp_selected_entities :: () -> [..]*Entity {
    selected : [..]*Entity = temp_array(*Entity);
    for :Selected app.entities array_add(*selected, it);
    return selected;
}

count_selected_entities :: () -> s64 {
    return temp_selected_entities().count;
}

compute_entity_primary_color :: (using entity : Entity) -> Vector4 {
    return color_from_path(get_entity_source(entity).path);
}

get_entity_primary_color :: (using entity : *Entity) -> *Vector4, *bool {
    assert(entity != null);

    if mesh.triangles.count {
        return *display_info.triangle_style.color, *display_info.triangle_style.visible;
    }

    if mesh.segments.count {
        return *display_info.segment_style.color, *display_info.segment_style.visible;
    }

    if mesh.points.count {
        return *display_info.point_style.color, *display_info.point_style.visible;
    }

    return *display_info.vertex_style.color, *display_info.vertex_style.visible;
}

set_entity_primary_color :: (using entity : *Entity) {
    assert(entity != null);

    // @CompilerBug? Error: We parsed a declaration, so we expected a semicolon after it, but saw this instead
    // primary_color, is_visible : *Vector4, *bool;

    primary_color : *Vector4 = get_entity_primary_color(entity);
    if primary_color {
        primary_color.* = compute_entity_primary_color(entity);
    }
}

// Assumes that fully_pathed_name is canonically formatted (see canonically_formatted_path_string)
// Returns a string in temporary storage
entity_name :: (fully_pathed_name : string) -> string {
    name := fully_pathed_name;

    path := parse_path(name,, temp);
    if path.words.count {
        name = path.words[path.words.count - 1];
    }

    return name;
}

// Returns a string in temporary storage, or a constant string literal "---"
entity_name :: (entity : Entity) -> string {
    name := entity_name(get_entity_source(entity).path);
    if name.count return name;
    return "---";
}

entity_description :: (using entity : Entity, with_creation_time : bool) -> string {

    generation_index_text := "";
    if generation_index != 0 {
        generation_index_text = tprint(" <%>", generation_index);
    }

    time_text := "";
    time_separator := "";
    if with_creation_time {
        time_text = filetime_to_readable_date(get_entity_source(entity).creation_time);
        time_separator = " @ ";
    }

    return tprint("%1%2%3%4", entity_name(entity), generation_index_text, time_separator, time_text);
}

// @Incomplete @Think Maybe we should handle visiblity on a more granular level e.g., on the element type level? We would need separate bounding geometry on the level of visibility control, which actually kindof makes sense.

// Result could be an empty sphere. Does not check visiblity
entity_raw_world_bounding_sphere :: (using entity : *Entity) -> Sphere {
    maybe_update_render_info(*entity.render_info, *entity.mesh);
    result : Sphere = render_info.bounding_sphere;
    transform(*result, mesh.world_from_model);
    return result;
}

// Result could be an empty sphere. Does not check visibility
entity_raw_world_clipping_sphere :: (using entity : Entity) -> Sphere {
    if display_info.clip_sphere.is_active {
        using display_info.clip_sphere;
        return .{center, radius}; // Already in world space. Should not be empty (radius may be infinite though)
    }
    return .{}; // Empty sphere
}

// Result could be an empty_sphere.
// Checks visibility, entity-level state checking like this is probably not a perf problem and makes the API more convenient. Also, it wouldn't really make sense to account for clipping, which affects visibility, but not account for overall visibility
// Accounts for clipping sphere and @Incomplete clipping ranges
entity_world_bounding_sphere :: (using entity : *Entity, $radius_of_point : float = 0) -> Sphere {
    if !entity.display_info.is_visible {
        return .{}; // Empty sphere
    }

    bound : Sphere = inline entity_raw_world_bounding_sphere(entity);

    if is_empty(bound) {
        return .{}; // Empty sphere
    }

    if entity.display_info.clip_sphere.is_active {

        clip : Sphere = inline entity_raw_world_clipping_sphere(entity);
        intersection := find_intersection_sphere3_sphere3(bound, clip);

        if #complete intersection.kind == {
        case .SPHERES_SEPARATED_AND_DISJOINT;

            return .{}; // Empty sphere

        case .SPHERES_SEPARATED_WITH_COMMON_POINT;

            return .{intersection.point, radius_of_point};

        case .SPHERES_INTERSECT_IN_A_CIRCLE;

            if bound.radius > clip.radius {
                if distance_squared(intersection.circle.center, bound.center) < distance_squared(clip.center, bound.center) {
                    return .{intersection.circle.center, intersection.circle.radius};
                } else {
                    return clip;
                }
            } else {
                if distance_squared(intersection.circle.center, clip.center) < distance_squared(bound.center, clip.center) {
                    return .{intersection.circle.center, intersection.circle.radius};
                } else {
                    return bound;
                }
            }

        case .SPHERE0_STRICTLY_INSIDE_SPHERE1; #through;
        case .SPHERE0_INSIDE_SPHERE1_WITH_COMMON_POINT;

            return bound;

        case .SPHERE1_STRICTLY_INSIDE_SPHERE0; #through;
        case .SPHERE1_INSIDE_SPHERE0_WITH_COMMON_POINT;

            return clip;
        }
    }

    // @Incomplete Clip the against the clipping planes as well

    return bound;
}

visit_visible :: #code !is_visible(it);
visit_visible_selected :: #code !(is_visible(it) && it.is_selected);

// Result could be an empty_sphere.
// Accounts for clipping sphere @Incomplete FIXME clipping ranges
// Note: hidden entities are skipped regardless of entity_filter, because entity_world_bounding_sphere returns an empty sphere in that case
entities_world_bounding_sphere :: ($entity_filter : Code = visit_visible) -> Sphere {

    expand_sphere :: (result : *Sphere, entity : *Entity) {
        sphere : Sphere = entity_world_bounding_sphere(entity);
        if !is_empty(sphere) {
            if is_empty(result) {
                result.* = sphere;
            } else {
                expand(result, sphere);
            }
        }
    }

    result : Sphere;

    Iterator :: #bake_arguments EntitiesIterator(entity_filter=entity_filter);
    for :Iterator app.entities {
        expand_sphere(*result, it);
    }

    // @Cleanup use entity_filter here? Or remove it altogether
    it : *Entity = *app.select_tool.entity;
    if it.display_info.is_visible {
        expand_sphere(*result, it);
    }

    return result;
}

entities_world_bounding_radius :: ($entity_filter : Code = visit_visible, center : Vector3) -> Sphere {

    expand_radius :: (result : *Sphere, entity : *Entity) {
        sphere : Sphere = entity_world_bounding_sphere(entity);
        if !is_empty(sphere) {
            if is_empty(result) {
                result.radius = distance(result.center, sphere.center) + sphere.radius;
            } else {
                expand_radius(result, sphere);
            }
        }
    }

    result : Sphere;
    result.center = center;

    Iterator :: #bake_arguments EntitiesIterator(entity_filter=entity_filter);
    for :Iterator app.entities {
        expand_radius(*result, it);
    }

    // @Cleanup use entity_filter here? Or remove it altogether
    it : *Entity = *app.select_tool.entity;
    if it.display_info.is_visible {
        expand_radius(*result, it);
    }

    return result;
}


entity_annotation_count :: (using entity : Entity, only_geometry_annotations := false) -> int {
    result : int = 0; 
    if only_geometry_annotations == false {
        result += command_annotations.count;
        result += block_annotations.count;
    }
    result += vertex_annotations.count;
    result += point_annotations.count;
    result += face_annotations.count;
    result += line_annotations.count;
    return result;
}

entity_sort_annotations :: (using entity : Entity, compare : (Annotation, Annotation) -> s64) {
    // Do not sort command annotations, since they may depend on each other its important they are executed in the order provided
    // quick_sort(command_annotations,  compare);
    quick_sort(block_annotations,  compare);
    quick_sort(vertex_annotations, compare);
    quick_sort(point_annotations, compare);
    quick_sort(face_annotations,   compare);
    quick_sort(line_annotations,   compare);
}

// The header annotation is the first block annotation
entity_header_annotation :: (entity : *Entity) -> *Annotation {
    if entity.block_annotations.count > 0 {
        return *entity.block_annotations[0];
    }
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

    entity.command_annotations = command_annotations;
    entity.block_annotations =  block_annotations;
    entity.vertex_annotations = vertex_annotations;
    entity.point_annotations =  point_annotations;
    entity.face_annotations =   face_annotations;
    entity.line_annotations =   line_annotations;

    using entity.annotation_info;
    max : int;

    max, show_kind = block_annotations.count, Annotation.Kind.BLOCK;
    if max < vertex_annotations.count {
        max, show_kind = vertex_annotations.count, Annotation.Kind.VERTEX;
    }
    if max < point_annotations.count {
        max, show_kind = point_annotations.count, Annotation.Kind.POINT;
    }
    if max < line_annotations.count {
        max, show_kind = line_annotations.count, Annotation.Kind.LINE;
    }
    if max < face_annotations.count {
        max, show_kind = face_annotations.count, Annotation.Kind.TRIANGLE;
    }
    if max < command_annotations.count {
        max, show_kind = command_annotations.count, Annotation.Kind.COMMAND; // @CompilerBug Unary '.' identifier should work here!
    }
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

// Returns a result in world space
entity_selection_aabb :: () -> AxisBox3 {
    result : AxisBox3;
    for :Selected app.entities {
        maybe_update_render_info(*it.render_info, *it.mesh);
        // @Volatile @Cleanup only works for a shift
        aabb := it.render_info.bounding_aabb;
        aabb.min_point = (it.mesh.world_from_model * Vector4.{xyz=aabb.min_point, w=1.}).xyz;
        aabb.max_point = (it.mesh.world_from_model * Vector4.{xyz=aabb.max_point, w=1.}).xyz;
        expand(*result, aabb);
    }
    return result;
}


color_from_path :: (path : string) -> Vector4 {
    if path.count == 0 {
        return .{1., 1., 1., 1.};
    }

    to_hash : string;
    if app.settings.color_from_path_behaviour == {
        case .FILENAME_ONLY;
            parsed := parse_path(path,, temp);
            to_hash = parsed.words[parsed.words.count - 1];
        case .FULLY_PATHED_FILENAME;
            to_hash = path;
    }

    return color_from_string(to_hash);
}

color_from_string :: (str : string) -> Vector4 {

    n := get_hash(str);
    m := get_hash(n);

    h := (cast(float)(n % 257) / 256);
    s := 1.;
    v := (cast(float)(m % 257) / 256) * .3 + .7;

    r, g, b : float;
    ImGui.ColorConvertHSVtoRGB(h, s, v, *r, *g, *b);

    return Vector4.{r, g, b, 1.};
}

// @FIXME Revisit this find_entity function now that we've added a bunch of fields to the Entity type

// Find the entity with matching name
// If generation_index >= 0 then find the entity with the given generation_index, otherwise find the one with maximum generation_index
// Return null, -1 if no matching entity is found
find_entity :: (fully_pathed_name : string, generation_index : int) -> *Entity, int {

    found : *Entity;
    found_index : int = -1;

    if generation_index >= 0 {
        for :All app.entities {
            if it.generation_index == generation_index {
                if get_entity_source(it).path == fully_pathed_name {
                    found = it;
                    found_index = it_index;
                    break;
                }
            }
        }
    } else {
        max_generation_index : int = -1;
        for :All app.entities {
            if it.generation_index > max_generation_index {
                if get_entity_source(it).path == fully_pathed_name {
                    max_generation_index = it.generation_index;
                    found = it;
                    found_index = it_index;
                }
            }
        }
    }

    return found, found_index;
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
    if #complete closest_point_element == {
        case .VERTEX; #through;
        case .POINT;
            return point.rayParameter;
        case .SEGMENT;
            return segment.parameter[0];
        case .TRIANGLE;
            return triangle.rayParameter;
        case .MESH;
            log_error("Unexpected enum value in get_ray_parameter");
    }
    return FLOAT32_INFINITY;
}

get_closest_point_on_ray :: (using closest : Closest_Point_Ray_Entity) -> Vector3 {
    if #complete closest_point_element == {
        case .VERTEX; #through;
        case .POINT;
            return point.rayClosest;
        case .SEGMENT;
            return segment.closest[0];
        case .TRIANGLE;
            return triangle.closestPoint[0];
        case .MESH;
            log_error("Unexpected enum value in get_closest_point_on_ray");
    }
    return .{};
}

get_closest_point_on_element :: (using closest : Closest_Point_Ray_Entity) -> Vector3 {
    if #complete closest_point_element == {
        case .VERTEX; #through;
        case .POINT;
            return point.point;
        case .SEGMENT;
            return segment.closest[1];
        case .TRIANGLE;
            return triangle.closestPoint[1];
        case .MESH;
            log_error("Unexpected enum value in get_closest_point_on_element");
    }
    return .{};
}


is_visible :: (e : *Entity) -> bool {
    return e.display_info.is_visible;
}

// @Refactor Use spatial lookups on triangles/segments/points
// @Cleanup Remove this function, replace it with a version find_closest_element which has a new arguement which determines what elements are being searched ie to have this behaviour we would only look for vertices
find_closest_vertex :: ($entity_filter : Code = visit_visible) -> Closest_Point_Ray_Entity {

    // @Refactor to pass in the ray?
    ray_world : Ray3 = make_camera_ray();

    // @Cleanup Consider clamping this based on a max model space distance, see get_model_space_query_radius
    max_dist_px : int = app.settings.closest_point_query_max_dist_px;

    projection_from_world : Matrix4 = make_projection_from_world(app.camera);

    result : Closest_Point_Ray_Entity;

    min_dist2 := FLOAT32_INFINITY;

    FilterIterator :: #bake_arguments EntitiesIterator(entity_filter=entity_filter);
    
    for :FilterIterator entity, entity_index : app.entities {
        inverse_transpose := transpose(inverse(entity.mesh.world_from_model));
        for :WorldVertexIterator vertex_world, vertex_index : entity.mesh {

            if is_clipped(entity.display_info, vertex_world) {
                continue;
            }

            if outside_screen_dist(vertex_world, projection_from_world, max_dist_px) {
                continue;
            }

            cp_world : Closest_Point_Ray_Point = closest_point_ray_point(ray_world, vertex_world);

            if cp_world.sqrDistance < min_dist2 {

                min_dist2 = cp_world.sqrDistance;
                result.closest_point_element = .VERTEX;
                result.closest_point.point = cp_world;
                result.element_index = vertex_index;
                result.entity_index = entity_index;
            }
        }
    }

    return result;
}

// Return true if the given point is further than max_distance_px from the mouse position and false otherwise
outside_screen_dist :: inline (point_world : Vector3, projection_from_world : Matrix4, max_distance_px : int) -> bool {
    mouse_px : Vector2 = ---;
    mouse_px.x = io().MousePos.x;
    mouse_px.y = io().MousePos.y;

    point_px : Vector2 = ---;
    point_px_i : Tuple2i = to_screen_position(point_world, projection_from_world);
    point_px.x = cast(float)point_px_i.x;
    point_px.y = cast(float)app.window_size.height - cast(float)point_px_i.y;

    return distance(mouse_px, point_px) > xx max_distance_px;
}

// Return the model space query radius for a given bounding box and query radius in pixels
get_model_space_query_radius :: (bbox : AxisBox3, query_radius_px : int) -> float {
    // @Incomplete Support perspective projection
    distance_1 : float = ((app.camera.right - app.camera.left) / app.window_size.width) * query_radius_px;
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

    ray_world : Ray3 = make_camera_ray(); // @Refactor to pass in the ray?
    max_dist_px : int = app.settings.closest_point_query_max_dist_px;
    projection_from_world : Matrix4 = make_projection_from_world(app.camera);

    result : Closest_Point_Ray_Entity;

    // Perpendicular distance from from ray to closest point on element
    d_min := FLOAT32_INFINITY;

    max_query_ray_parameter := FLOAT32_INFINITY;

    for entity, entity_index : app.entities {
        if !is_occluder(entity) {
            continue;
        }

        ray_model : Ray3 = transform_ray(inverse(entity.mesh.world_from_model), ray_world);

        // Keep track of the best candidates (closest to the camera/ray origin) for intersected/hit triangles and missed ones
        best_ray_triangle_hit, best_ray_triangle_miss : Closest_Point_Ray_Triangle;
        best_ray_triangle_hit_index, best_ray_triangle_miss_index : int = -1;

        // @Speed Early out using a ray-clipping sphere check, this should account for the pixel distance from the sphere silhouette
        // if is_clipped(`entity.display_info, isect_world, test_sphere=`sphere_clipped, test_ranges=`range_clipped) {
        //     continue;
        // }

        Process_Triangle_Data :: struct {
            entity : *Entity;
            ray_world : Ray3;
            projection_from_world : *Matrix4;
            max_dist_px : int;
            best_ray_triangle_hit : *Closest_Point_Ray_Triangle;
            best_ray_triangle_hit_index : *int;
            best_ray_triangle_miss : *Closest_Point_Ray_Triangle;
            best_ray_triangle_miss_index : *int;
        };

        process_triangle_data : Process_Triangle_Data = ---;
        process_triangle_data.entity                       = entity;
        process_triangle_data.ray_world                    = ray_world;
        process_triangle_data.projection_from_world        = *projection_from_world;
        process_triangle_data.max_dist_px                  =  max_dist_px;
        process_triangle_data.best_ray_triangle_hit        = *best_ray_triangle_hit;
        process_triangle_data.best_ray_triangle_hit_index  = *best_ray_triangle_hit_index;
        process_triangle_data.best_ray_triangle_miss       = *best_ray_triangle_miss;
        process_triangle_data.best_ray_triangle_miss_index = *best_ray_triangle_miss_index;

        process_triangle :: (triangle_model : Triangle3, triangle_index : int, data : *void) {

            using process_triangle_data := cast(*Process_Triangle_Data) data;

            triangle_world : Triangle3 = transform_triangle(entity.mesh.world_from_model, triangle_model);

            cp : Closest_Point_Ray_Triangle = closest_point_ray_triangle(ray_world, triangle_world);

            if is_clipped(entity.display_info, cp.closestPoint[1]) {
                return;
            }

            if outside_screen_dist(cp.closestPoint[1], projection_from_world, max_dist_px) {
                return;
            }

            if cp.distance == 0 {
                if cp.rayParameter < best_ray_triangle_hit.rayParameter {
                    best_ray_triangle_hit.* = cp;
                    best_ray_triangle_hit_index.* = triangle_index;
                }
            } else {
                if cp.rayParameter < best_ray_triangle_miss.rayParameter {
                    best_ray_triangle_miss.* = cp;
                    best_ray_triangle_miss_index.* = triangle_index;
                }
            }
        }

        if entity.spatial == null {

            // @Speed Early out using a ray-clipping sphere check, this should account for the pixel distance from the sphere silhouette
            for :ModelTriangleIterator triangle, triangle_index : entity.mesh {
                process_triangle(triangle, triangle_index, *process_triangle_data);
            }

        } else {

            max_dist : float = get_model_space_query_radius(entity.render_info.bounding_aabb, max_dist_px);
            visit_elements_near_ray(entity.spatial, ray_model, max_dist, process_triangle, *process_triangle_data);
        }

        if best_ray_triangle_hit_index >= 0 {

            // If we hit a triangle in this entity, always update the result if the hit is closer because we prefer hits to misses
            if best_ray_triangle_hit.rayParameter < max_query_ray_parameter {

                d_min = best_ray_triangle_hit.distance; // This should be zero
                max_query_ray_parameter = best_ray_triangle_hit.rayParameter;

                result.closest_point_element = .TRIANGLE;
                result.closest_point.triangle = best_ray_triangle_hit;
                result.element_index = best_ray_triangle_hit_index;
                result.entity_index = entity_index;
            }

        } else if best_ray_triangle_miss_index >= 0 {

            // If we missed triangles in this entity, only update the result if its not storing a hit because we always prefer hits to misses
            if (result.entity_index == -1 || (result.entity_index >= 0 && result.closest_point.triangle.distance > 0)) &&
               best_ray_triangle_miss.rayParameter < max_query_ray_parameter {

                d_min = best_ray_triangle_miss.distance;

                result.closest_point_element = .TRIANGLE;
                result.closest_point.triangle = best_ray_triangle_miss;
                result.element_index = best_ray_triangle_miss_index;
                result.entity_index = entity_index;
            }

        }
    }

    hit_triangle := result.closest_point.triangle.distance == 0;
    if hit_triangle {
        if target_triangles(app.entities[result.entity_index]) {
            // Since we can only miss segments/points, and we always prefer hits to misses, return here if we have hit a triangle
            return result;
        } else {
            // Reset the result and d_min but keep max_query_ray_parameter
            d_min = FLOAT32_INFINITY;
            result = Closest_Point_Ray_Entity.{};
        }
    }

    // @Speed Early out if the ray misses the entity AABB
    // @Incomplete When available, use the spatial index

    // Note: When we use Simple_Mesh we will make this iterator go over the point set with a p directive, not vertices set with a v directive
    for entity, entity_index : app.entities {
        
        if target_points(entity) for :WorldPointIterator point_world, point_index : entity.mesh {

            cp_world : Closest_Point_Ray_Point = closest_point_ray_point(ray_world, point_world);

            if cp_world.rayParameter < max_query_ray_parameter && cp_world.distance < d_min {

                if is_clipped(entity.display_info, point_world) {
                    continue;
                }

                if outside_screen_dist(point_world, projection_from_world, max_dist_px) {
                    continue;
                }

                d_min = cp_world.distance;
                result.closest_point_element = .POINT;
                result.closest_point.point = cp_world;
                result.element_index = point_index;
                result.entity_index = entity_index;
            }
        }

        if target_segments(entity) for :WorldSegmentIterator segment_world, segment_index : entity.mesh {
            cp_world : Closest_Point_Ray_Segment = closest_point_ray_segment(ray_world, segment_world);

            if cp_world.parameter[0] < max_query_ray_parameter && cp_world.distance < d_min { // @CompilerBug When the body of the second for-loop was a macro it compiled without a backtick on d_min, which caused a bug!!!!! d_min wasn't locally declared in the macro either..!

                if is_clipped(entity.display_info, cp_world.closest[1]) {
                    continue;
                }

                if outside_screen_dist(cp_world.closest[1], projection_from_world, max_dist_px) {
                    continue;
                }

                d_min = cp_world.distance;
                result.closest_point_element = .SEGMENT;
                result.closest_point.segment = cp_world;
                result.element_index = segment_index;
                result.entity_index = entity_index;
            }
        }
    }

    return result;
}

num_selected_entities :: () -> int {
    count := 0;
    for :Selected app.entities {
        count += 1;
    }
    return count;
}

load_one_file :: (filename : string, matching_name_behaviour : Duplicate_File_Behaviour) -> []*Entity {
    results : []*Entity;

    check, check_ok := is_directory(filename);
    if check || !check_ok {
        log_warning("Expected a fully pathed filename, got '%'\n", filename);
        return results;
    }

    name := entity_name(filename);

    // Check if we can early exit and avoid reading the file from disk
    {
        found, found_index := find_entity(filename, -1);
        if found && matching_name_behaviour == .IGNORE {
            log_warning("Skipped file: '%' (already loaded)\n", name);
            return results;
        }
    }

    add_directory(get_directory(filename));

    // @Speed After reading the file from disk the application should immediately read other files from disk, and do the rest of the file loading in a different thread
    contents := read_entire_file(filename);
    defer free(contents);

    results = load_one_file_from_memory(filename, contents, name, matching_name_behaviour);
    // @Incomplete check the directory has been set correctly here?

    return results;
}

// @Cleanup rename to load_from_memory, and rename the filename argument..? or add another name parameter (or just set that after HMMMM)
load_one_file_from_memory :: (filename : string, contents : string, name : string, matching_name_behaviour : Duplicate_File_Behaviour) -> []*Entity {
    results : []*Entity;

    if !contents {
        log_warning("Skipped file: '%' (empty or missing)\n", filename);
        return results;
    }

    // Check if we can early exit and avoid parsing the contents
    {
        found, found_index := find_entity(filename, -1);
        if found && matching_name_behaviour == .IGNORE {
            log_warning("Skipped file: '%' (already loaded)\n", name);
            return results;
        }
    }

    results = load_one_file_from_memory(filename, contents, name);

    return results;
}


// @Incomplete pass Duplicate_File_Behaviour 
// Reload the entity using it's fully_pathed_filename, if loading fails clear the entity
reload_entity :: (entity : *Entity, triggered_by_button := false) -> did_reload : bool {

    // @Volatile Keep this in sync with the auto_reload checkboxes in the item Display tab
    if #complete entity.source.kind == {
        case ._Entity_Source_Selection;

            return false;

        case ._Entity_Source_File;

            // @Cleanup This code is in the wrong place?
            enable_reload_shortcut :: (entity : Entity) -> bool {
                if app.settings.disable_reload_key_if_file_unchanged {
                    return is_changed_on_disk(entity);
                }
                return true;
            }

            // Feature documentation: We want to always allow the user to reload the file by explictly clicking the UI button, but by default a user setting is set such that using the keyboard shortcut to reload a file will only reload it if it has changed
            if triggered_by_button || enable_reload_shortcut(entity) {
                log("Reloading file '%'... ", get_entity_source(entity).path);
                duplicate_file_behaviour := Duplicate_File_Behaviour.OVERWRITE; // @Incomplete this should be customizable

                new_entities := load_one_file(get_entity_source(entity).path, duplicate_file_behaviour);
                if new_entities.count {
                    for new_entity : new_entities {
                        if new_entity {
                            // Set generation_index before adding to overwrite the correct entity
                            new_entity.generation_index = entity.generation_index;
                            add_entity(new_entity, duplicate_file_behaviour);
                        }
                    }
                } else {
                    // If the entity didn't exist or couldn't be loaded clear the entity
                    entity_index : int = get_entity_index(entity);
                    log("Removed item #% (file '%') since it could not be reloaded (deleted or empty)", entity_index, get_entity_source(entity).path);
                    remove_entity_by_index(entity_index);
                }
                return true;
            }

        case ._Entity_Source_Preset;

            #if false {
                entity_source := isa(entity.source, Entity_Source_Preset);
                if entity_source {
                    log("Reloading preset shape '%'... ", entity_name(entity));
                    new_entity := entity_source.preset_proc();
                    assert(new_entity != null);

                    // Set generation_index before adding to overwrite the correct entity
                    new_entity.generation_index = entity.generation_index;
                    add_entity(new_entity, .OVERWRITE);
                    return true;
                } else {
                    log("Could not reload preset item '%'", entity_name(entity));
                }
            } else {
                log_warning("Could not reload '%'. Preset shape reloading is not currently supported, sorry!", entity_name(entity));
                return false;
            }

        case ._Entity_Source_Command;

            source := isa(entity.source, Entity_Source_Command);
            assert(source != null);

            // Note: This is only intended to support simple use cases,
            // reloading command output can easily break if e.g., item indices change
            log("Re-executing console command '%'... ", source.console_command);
            console_execute_command(source.console_command);
            return true;
    }

    return false;
}

set_entity_source_from_file :: (entity : *Entity, fully_pathed_filename : string, loc := #caller_location) {
    assert(entity != null);

    source : Entity_Source_File;
    source.path = copy_string(fully_pathed_filename);
    modtime, size, ok := file_modtime_and_size(fully_pathed_filename);
    if ok {
        source.creation_time = modtime;
        source.creation_size = size;
    } else {
        name := entity_name(fully_pathed_filename);
        log_error("Function % failed for entity '%' when called in %. Called from %", #procedure_name(file_modtime_and_size), name, #procedure_name(), loc);
    }

    set(*entity.source, source);
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

set_entity_source_from_command :: (entity : *Entity, name : string, console_command : string, vertex_count : s64 = 0) {
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
    assert(entity != null);
    if mesh.points.count == 0 && mesh.segments.count == 0 { // @Incomplete: Support points/segments in AABB tree
        spatial = New(AABB_Tree);
        init(spatial, *mesh);
    } else {
        // TODOO Address this, but don't write it, its not very useful log info
        //log_warning("@Incomplete Accelerated spatial queries only supported for triangle-only meshes");
    }
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

load_one_file_from_memory :: (filename : string, contents : string, name : string) -> []*Entity {
    results : []*Entity;

    // @Refactor Improve the log messaging during file loading e.g., with indents after this message
    log("Loading file '%'...", filename);

    if ends_with_nocase(filename, "obj") {
        results = load_obj(filename, contents, name);
    }

    if results.count {
        log("Loaded  file '%'", filename); // Use double space to line up with "Loading file" text
    } else {
        log_error("Could not load file '%'", filename);
    }

    return results;
}