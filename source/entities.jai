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
    mesh : Mesh;
    spatial : *AABB_Tree(Mesh);

    // @Incomplete Perhaps there should be a pool for the annotation strings?
    command_annotations :  [..]Annotation; // Comments in the file but not attached to any particular geometry, the first block of comments will be shown in the item tooltip
    block_annotations :  [..]Annotation; // Comments in the file but not attached to any particular geometry, the first block of comments will be shown in the item tooltip
    vertex_annotations : [..]Annotation; // Comments attached to vertices e.g., v directives in .obj files, @Think maybe also include comments on p directives
    face_annotations :   [..]Annotation; // Comments attached to triangles e.g., f directives in .obj files
    line_annotations :   [..]Annotation; // Comments attached to line segments e.g., l directives in .obj files
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
PRESET_SHAPE_FOLDER :: "Preset Shapes";
COMMAND_OUTPUT_FOLDER :: "Command Outputs";

/*

// Annotate these with the entity and source index
// When we have arrays in annotations, also add the original annotation
point_selection : Mesh_Entity;
segment_selection : Mesh_Entity;
triangle_selection : Mesh_Entity;

How do I add annotations to the points/segments/triangles
Selection_Entity :: struct {
    points : Mesh;
    segments : Mesh;
    triangles : Mesh;
}
*/

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

clear :: (using entity : *Entity) {
    clear(*mesh);

    // Remove data from gpu memory as well
    if render_info.vbo glDeleteBuffers(1, *render_info.vbo);
    if render_info.ibo glDeleteBuffers(1, *render_info.ibo);
    render_info = .{};
}


remove_entity_by_index :: (entity_to_remove_index : int) {
    if entity_to_remove_index >= 0 && entity_to_remove_index < app.entities.count {
        entity_to_remove : *Entity = app.entities[entity_to_remove_index];
        remove_directory(get_directory(get_entity_source(entity_to_remove).path));
        deinit(entity_to_remove);
        free(entity_to_remove);
        array_ordered_remove_by_index(*app.entities, entity_to_remove_index);
    }
}

remove_entities_if_selected :: () {
    for app.entities if it.is_selected {
        remove_directory(get_directory(get_entity_source(it).path));
        deinit(it);
        free(it);
        remove it; // @FIXME this screws up the order of items in the list, this function should do an ordered remove
    }
}

deinit :: (using entity : *Entity) {
    if !entity return;

    deinit(*mesh);
    deinit(spatial);
    
    for :AnnotationIterator entity deinit(it);
    // nocommit We should have AnnotationListIterator, so we don't need to change so many places
    array_reset(*command_annotations);
    array_reset(*block_annotations);
    array_reset(*vertex_annotations);
    array_reset(*face_annotations);
    array_reset(*line_annotations);


    free(get_entity_source(entity).path);
    if #complete source.kind == {
        case .Entity_Source_File;      #through;
        case .Entity_Source_Preset;    #through;
        case .Entity_Source_Selection;
            // Do nothing
        case .Entity_Source_Command;
            source := isa(entity.source, Entity_Source_Command);
            free(source.console_command);
    }

    // Remove data from gpu memory as well
    if render_info.vbo glDeleteBuffers(1, *render_info.vbo);
    if render_info.ibo glDeleteBuffers(1, *render_info.ibo);
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

                entity_source := isa(entity.source, Entity_Source_File);
                found_source :=  isa(found.source,  Entity_Source_File);
                if entity_source && found_source {
                    entity_source.auto_reload = found_source.auto_reload;
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

is_empty :: (entity : Entity) -> bool {
    count : int = inline point_count(entity.mesh);
    return count == 0;
    // return inline point_count(entity.mesh) == 0; // @CompilerBug? Error: Attempted use of keyword 'inline' on a non-procedure-call.
}

is_changed_on_disk :: (entity : Entity) -> bool {
    changed := false;
    if entity.source.kind == .Entity_Source_File {
        source := isa(entity.source, Entity_Source_File);
        assert(source != null);
        modtime, size, ok := file_modtime_and_size(source.path);
        if modtime > source.creation_time || size != source.creation_size {
            changed = true;
        }
    }
    return changed;
}


entity_primary_color :: (using entity : *Entity) -> *Vector4, *bool {
    if #complete mesh.geometry_format == {
        case .UNKNOWN;   #through;
        case .POINTS;    return *display_info.points_color,    *display_info.points_visible;
        case .LINES;     return *display_info.wireframe_color, *display_info.wireframe_visible;
        case .TRIANGLES; return *display_info.surface_color,   *display_info.surface_visible;
    }
    return null, null;
}

reset_entity_primary_color :: (entity : *Entity) {
    color : *Vector4 = entity_primary_color(entity);
    if color {
        <<color = color_from_path(get_entity_source(entity).path);
    }
}

// Assumes that fully_pathed_name is canonically formatted (see canonically_formatted_path_string)
// Returns a string pointing into the argument
entity_name :: (fully_pathed_name : string) -> string {
    name := fully_pathed_name;

    path := parse_path(name);
    if path.words.count {
        name = path.words[path.words.count - 1];
    }

    return name;
}

// Returns a string pointing into entity.fully_pathed_name
entity_name :: (entity : Entity) -> string {
    return entity_name(get_entity_source(entity).path);
}

entity_description :: (using entity : Entity, with_creation_time : bool) -> string {

    index_text := "";
    if generation_index != 0 {
        index_text = tprint(" <%>", generation_index);
    }

    time_text := "";
    time_separator := "";
    if with_creation_time {
        time_text = filetime_to_readable_date(get_entity_source(entity).creation_time);
        time_separator = " @ ";
    }

    return tprint("%1%2%3%4", entity_name(entity), index_text, time_separator, time_text);
}

entity_annotation_count :: (using entity : Entity) -> int {
    result : int = 0; 
    result += command_annotations.count;
    result += block_annotations.count;
    result += vertex_annotations.count;
    result += face_annotations.count;
    result += line_annotations.count;
    return result;
}

entity_sort_annotations :: (using entity : Entity, compare : (Annotation, Annotation) -> s64) {
    quick_sort(command_annotations,  compare);
    quick_sort(block_annotations,  compare);
    quick_sort(vertex_annotations, compare);
    quick_sort(face_annotations,   compare);
    quick_sort(line_annotations,   compare);
}

// nocommit Rename to entity_header_annotation
find_header_annotation :: (entity : *Entity) -> *Annotation {
    for *annotation : entity.block_annotations {
        if annotation.kind == .BLOCK && annotation.id == 1 {
            return annotation;
        }
    }
    return null;
}

// nocommit Fragile when you add a new annotation array
set_entity_annotations :: (entity : *Entity,
    command_annotations : [..]Annotation,
    block_annotations :  [..]Annotation,
    vertex_annotations : [..]Annotation,
    face_annotations :   [..]Annotation,
    line_annotations :   [..]Annotation) {

    entity.command_annotations = command_annotations;
    entity.block_annotations =  block_annotations;
    entity.vertex_annotations = vertex_annotations;
    entity.face_annotations =   face_annotations;
    entity.line_annotations =   line_annotations;

    using entity.annotation_info;
    max : int;

    max, show_kind = block_annotations.count, .BLOCK;
    if max < vertex_annotations.count {
        max, show_kind = vertex_annotations.count, .VERTEX;
    }
    if max < line_annotations.count {
        max, show_kind = line_annotations.count, .LINE;
    }
    if max < face_annotations.count {
        max, show_kind = face_annotations.count, .TRIANGLE;
    }
    if max < command_annotations.count {
        max, show_kind = command_annotations.count, Annotation.Kind.COMMAND; // @CompilerBug Unary '.' identifier should work here!
    }
}

// @Think Do we need this is we have a default value for kinds?
AnnotationIterator :: #bake_arguments AnnotationIteratorBase(kinds=Annotation.Kind.COMMAND|.BLOCK|.VERTEX|.LINE|.TRIANGLE);

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

    n := get_hash(str);
    m := get_hash(n);

    h := (cast(float)(n % 257) / 256);
    s := 1.;
    v := (cast(float)(m % 257) / 256) * .3 + .7;

    r, g, b : float;
    ImGui.ColorConvertHSVtoRGB(h, s, v, *r, *g, *b);

    return make_vector4(r, g, b, 1.);
}

// @FIXME Revisit this find_entity function now that we've added a bunch of fields to the Entity type

// Find the entity with matching name
// If generation_index >= 0 then find the entity with the given generation_index, otherwise find the one with maximum generation_index
// Return null, -1 if no matching entity is found
find_entity :: (fully_pathed_name : string, generation_index : int) -> *Entity, int {

    found : *Entity;
    found_index : int = -1;

    if generation_index >= 0 {
        for app.entities {
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
        for app.entities {
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

get_closest_point_on_element :: (using closest : Closest_Point_Ray_Entity) -> Vector3 {
    if closest_point_element == {
        case .POINT;
            return point.point;
        case .SEGMENT;
            return segment.closest[1];
        case .TRIANGLE;
            return triangle.closestPoint[1];
    }
    return .{};
}


// @Refactor Use spatial lookups on triangles/segments/points
find_closest_vertex_on_visible_entities :: (_max_dist_px : int = -1) -> Closest_Point_Ray_Entity {

    // @Refactor to pass in the ray?
    ray_world : Ray3 = make_camera_ray();

    max_dist_px : int = ifx _max_dist_px < 0 then app.settings.closest_point_query_max_dist_px else _max_dist_px;

    projection_from_world : Matrix4 = make_projection_from_world(app.camera);

    result : Closest_Point_Ray_Entity;

    min_dist2 := FLOAT32_INFINITY;
    
    for :VisibleSelectable entity, entity_index : app.entities {
        inverse_transpose := transpose(inverse(entity.mesh.world_from_model));
        for :WorldVertexIterator vertex_world, vertex_index : entity.mesh {

            if is_clipped(entity.display_info, vertex_world) {
                continue;
            }

            if OutsideScreenDist(vertex_world) {
                continue;
            }

            // Note if the vertex normals are 0 the dot product will be 0 and will _not_ trigger the continue, we
            // want to be able to select vertices with 0 normals in all cases
            front_facing_only :: false;
            if front_facing_only && entity.mesh.normals.count {
                normal_world : Vector3 = transform_vector(inverse_transpose, entity.mesh.normals[vertex_index]);
                if dot(normal_world, current_look_direction()) > 0 {
                    continue;
                }
            }

            cp_world : Closest_Point_Ray_Point = closest_point_ray_point(ray_world, vertex_world);

            if cp_world.sqrDistance < min_dist2 {

                min_dist2 = cp_world.sqrDistance;
                result.closest_point_element = .POINT;                        
                result.closest_point.point = cp_world;
                result.element_index = vertex_index;
                result.entity_index = entity_index;
            }
        }
    }

    return result;
}

// Return true if the given point is further than max_dist_px from the mouse position and false otherwise
OutsideScreenDist :: (point_world : Vector3) -> bool #expand {
    mouse_px : Vector2 = ---;
    mouse_px.x = io().MousePos.x;
    mouse_px.y = io().MousePos.y;

    point_px : Vector2 = ---;
    point_px_i : Tuple2i = to_screen_position(point_world, `projection_from_world);
    point_px.x = xx point_px_i.x;
    point_px.y = cast(float) app.current_window_height - xx point_px_i.y;

    return distance(mouse_px, point_px) > xx `max_dist_px;
}

// Result positions are in world space
find_closest_point_on_visible_entities :: (_max_dist_px : int = -1, front_facing_only := false) -> Closest_Point_Ray_Entity {

    // @Refactor to pass in the ray?
    ray_world := make_camera_ray();

    max_dist_px : int = ifx _max_dist_px < 0 then app.settings.closest_point_query_max_dist_px else _max_dist_px;

    projection_from_world : Matrix4 = make_projection_from_world(app.camera);

    ProcessTriangle :: (triangle_model : Triangle3, triangle_id : int) #expand {

        if `front_facing_only {
            // Don't skip degenerate triangles, note we check closest point from ray to triangle
            normal_direction := compute_normal(triangle_model, normalize=false);
            if dot_product(normal_direction, `ray_model.direction) > 0 {
                continue;
            }
        }

        triangle_world : Triangle3 = transform_triangle(`entity.mesh.world_from_model, triangle_model);
    
        cp : Closest_Point_Ray_Triangle = closest_point_ray_triangle(`ray_world, triangle_world);

        if is_clipped(`entity.display_info, cp.closestPoint[1]) {
            continue;
        }

        if OutsideScreenDist(cp.closestPoint[1]) {
            continue;
        }

        if cp.distance == 0 {
            if cp.rayParameter < `best_ray_triangle_hit.rayParameter {
                `best_ray_triangle_hit = cp;
                `best_ray_triangle_hit_index = triangle_id;
            }
        } else {
            if cp.rayParameter < `best_ray_triangle_miss.rayParameter {
                `best_ray_triangle_miss = cp;
                `best_ray_triangle_miss_index = triangle_id;
            }
        }
    }

    result : Closest_Point_Ray_Entity;

    d_min := FLOAT32_INFINITY;

    for :VisibleSelectableMeshTriangles entity, entity_index : app.entities {
        ray_model : Ray3 = transform_ray(inverse(entity.mesh.world_from_model), ray_world);

        // Keep track of the best candidates (closest to the camera/ray origin) for intersected/hit triangles and missed ones
        best_ray_triangle_hit, best_ray_triangle_miss : Closest_Point_Ray_Triangle;
        best_ray_triangle_hit_index, best_ray_triangle_miss_index : int = -1;

        // nocommit Early out using a ray-clipping sphere check, this should account for the pixel distance from the sphere silhouette
        // if is_clipped(`entity.display_info, isect_world, test_sphere=`sphere_clipped, test_ranges=`range_clipped) {
        //     continue;
        // }

        if entity.spatial == null {

            // nocommit Early out using a ray-clipping sphere check, this should account for the pixel distance from the sphere silhouette
            for :ModelTriangleIterator triangle, triangle_index : entity.mesh {
                ProcessTriangle(triangle, triangle_index);
            }

        } else {

            // @Incomplete Support perspective projection
            max_dist : float = ((app.camera.right - app.camera.left) / app.current_window_width) * max_dist_px;

            VisitPrimitivesNearRay(entity.spatial, ray_model, max_dist,
                 #code ProcessTriangle(primitive, primitive_id)
            );

        }

        if best_ray_triangle_hit_index >= 0 {
            // If we hit a triangle in this entity, always update the result if the hit is closer because we prefer hits to misses
            if best_ray_triangle_hit.rayParameter < d_min {
                d_min = best_ray_triangle_hit.rayParameter;
                result.closest_point_element = .TRIANGLE;
                result.closest_point.triangle = best_ray_triangle_hit;
                result.element_index = best_ray_triangle_hit_index;
                result.entity_index = entity_index;
            }
        } else if best_ray_triangle_miss_index >= 0 {
            // If we missed triangles in this entity, only update the result if its not storing a hit because we always prefer hits to misses
            if (result.entity_index == -1 || (result.entity_index >= 0 && result.closest_point.triangle.distance > 0)) && best_ray_triangle_miss.rayParameter < d_min {
                d_min = best_ray_triangle_miss.rayParameter;
                result.closest_point_element = .TRIANGLE;
                result.closest_point.triangle = best_ray_triangle_miss;
                result.element_index = best_ray_triangle_miss_index;
                result.entity_index = entity_index;
            }
        }
    }

    // Since we can only miss segments/points, and we always prefer hits to misses, return here if we have hit a triangle
    if result.closest_point.triangle.distance == 0 {
        return result;
    }

    // @Incomplete When available, use the spatial index

    // Note: When we use Simple_Mesh we will make this iterator go over the point set with a p directive, not vertices set with a v directive
    for :VisibleSelectableMeshVertices entity, entity_index : app.entities {
        for :WorldVertexIterator vertex_world, vertex_index : entity.mesh {

            cp_world : Closest_Point_Ray_Point = closest_point_ray_point(ray_world, vertex_world);

            if cp_world.distance < d_min {

                if is_clipped(entity.display_info, vertex_world) {
                    continue;
                }

                if OutsideScreenDist(vertex_world) {
                    continue;
                }

                d_min = cp_world.distance;
                result.closest_point_element = .POINT;                        
                result.closest_point.point = cp_world;
                result.element_index = vertex_index;
                result.entity_index = entity_index;
            }
        }
    }

    for :VisibleSelectableMeshSegments entity, entity_index : app.entities {
        for :WorldSegmentIterator segment_world, segment_index : entity.mesh {
            cp_world : Closest_Point_Ray_Segment = closest_point_ray_segment(ray_world, segment_world);

            if cp_world.distance < d_min { // @CompilerBug When the body of the second for-loop was a macro it compiled without a backtick on d_min, which caused a bug!!!!! d_min wasn't locally declared in the macro either..!

                if is_clipped(entity.display_info, cp_world.closest[1]) {
                    continue;
                }

                if OutsideScreenDist(cp_world.closest[1]) {
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

load_one_file :: (filename : string, matching_name_behaviour : Duplicate_File_Behaviour) -> *Entity {
    check, check_ok := is_directory(filename);
    if check || !check_ok {
        log_warning("Expected a fully pathed filename, got '%'\n", filename);
        return null;
    }

    name := entity_name(filename);

    // Check if we can early exit and avoid reading the file from disk
    {
        found, found_index := find_entity(filename, -1);
        if found && matching_name_behaviour == .IGNORE {
            log_warning("Skipped file: '%' (already loaded)\n", name);
            return null;
        }
    }

    add_directory(get_directory(filename));

    // @Speed After reading the file from disk the application should immediately read other files from disk, and do the rest of the file loading in a different thread
    contents := read_entire_file(filename);
    defer free(contents);

    result : *Entity = load_one_file_from_memory(filename, contents, name, matching_name_behaviour);
    // @Incomplete check the directory has been set correctly here?

    return result;
}

// @Cleanup rename to load_from_memory, and rename the filename argument..? or add another name parameter (or just set that after HMMMM)
load_one_file_from_memory :: (filename : string, contents : string, name : string, matching_name_behaviour : Duplicate_File_Behaviour) -> *Entity {
    if !contents {
        log_warning("Skipped file: '%' (empty or missing)\n", filename);
        return null;
    }

    // Check if we can early exit and avoid parsing the contents
    {
        found, found_index := find_entity(filename, -1);
        if found && matching_name_behaviour == .IGNORE {
            log_warning("Skipped file: '%' (already loaded)\n", name);
            return null;
        }
    }

    return load_one_file_from_memory(filename, contents, name);
}


// @Incomplete pass Duplicate_File_Behaviour 
// Reload the entity using it's fully_pathed_filename, if loading fails clear the entity
reload_entity :: (entity : *Entity, triggered_by_button := false) -> did_reload : bool {
    if #complete entity.source.kind == {
        case .Entity_Source_Selection;

            return false;

        case .Entity_Source_File;

            // nocommit This code is in the wrong place
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

                // nocommit With command annotations this function could return a list of new entities, and each of these should be merged into the item list using duplicate_file_behaviour
                new_entity := load_one_file(get_entity_source(entity).path, duplicate_file_behaviour);
                if new_entity {
                    // Set generation_index before adding to overwrite the correct entity
                    new_entity.generation_index = entity.generation_index;
                    add_entity(new_entity, duplicate_file_behaviour);
                } else {
                    // If the entity didn't exist or couldn't be loaded clear the entity
                    clear(entity);
                }
                return true;
            }

        case .Entity_Source_Preset;

            #if false {
                if entity.preset_proc() {
                    log("Reloading preset shape '%'... ", entity_name(entity));
                    new_entity := entity.preset_proc();
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

        case .Entity_Source_Command;

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

set_entity_source_from_preset :: (entity : *Entity, name : string, preset_proc : #type ()->*Entity, point_count : s64) {
    assert(entity != null);

    source : Entity_Source_Preset;
    source.path = sprint("%/%", PRESET_SHAPE_FOLDER, name);
    source.creation_time = current_time_consensus();
    source.creation_size = point_count;
    source.preset_proc = preset_proc;

    set(*entity.source, source);
}

set_entity_source_from_selection :: (entity : *Entity, name : string, point_count : s64) {
    assert(entity != null);

    source : Entity_Source_Selection;
    source.path = sprint("%/%", SELECTION_FOLDER, name);
    source.creation_time = current_time_consensus();
    source.creation_size = point_count;

    set(*entity.source, source);
}

set_entity_source_from_command :: (entity : *Entity, name : string, console_command : string, point_count : s64) {
    assert(entity != null);

    source : Entity_Source_Command;
    source.path = sprint("%/%", COMMAND_OUTPUT_FOLDER, name);
    source.creation_time = current_time_consensus();
    source.creation_size = point_count;
    source.console_command = copy_string(console_command);

    set(*entity.source, source);
}

// set_entity_source_from_code :: (entity : *Entity, name : string, console_command : string, point_count : s64) {
//     assert(entity != null);
//     entity.fully_pathed_name = copy_string(tprint("%/%", SOURCE_CODE_FOLDER, name));
//
//     entity.source = .SOURCE_CODE;
//     entity.creation_time = current_time_consensus();
//     entity.creation_size = point_count;
// }

// Preconditions: entity.source->path has been set
set_entity_display_info :: (entity : *Entity, geometry_format : Geometry_Format) {
    assert(entity != null);

    primary_color := color_from_path(get_entity_source(entity).path);
    if #complete geometry_format == {
        case .UNKNOWN;

            log_error("Unexpected % geometry format", geometry_format);

        case .POINTS;

            entity.display_info.surface_visible = true; // @Cleanup What the heck??
            entity.display_info.points_visible = true;
            entity.display_info.points_size = 4;
            entity.display_info.points_color = primary_color;
            entity.display_info.element_label_theme.label_color = .{1., 1., 0, 1}; // @Cleanup put colors in app.jai

        case .LINES;

            entity.display_info.wireframe_visible = true;
            entity.display_info.wireframe_width = 1;
            entity.display_info.wireframe_color = primary_color;
            entity.display_info.element_label_theme.label_color = .{.6, .6, 0, 1};

        case .TRIANGLES;

            entity.display_info.surface_visible = true;
            entity.display_info.surface_color = primary_color;
    }
}

init_entity_spatial_index :: (using entity : *Entity) {
    assert(entity != null);
    if mesh.geometry_format == .TRIANGLES {
        spatial = New(AABB_Tree(Mesh));
        init(spatial, *mesh);
    } else {
        log_warning("@Incomplete Accelerated spatial queries only supported for triangle meshes, got %!\n", mesh.geometry_format);
    }
}


get_entity_source :: (entity : Entity) -> *Entity_Source {
    return cast(*Entity_Source)entity.source.bytes.data;
}

// nocommit fix the comments here
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

load_one_file_from_memory :: (filename : string, contents : string, name : string) -> *Entity {
    result : *Entity;

    // @Refactor Improve the log messaging during file loading e.g., with indents after this message
    log("Loading file '%'...", filename);

    if ends_with_nocase(filename, "obj") {
        result = load_obj(filename, contents, name);
    } else if ends_with_nocase(filename, "wkt") {
        result = load_wkt(filename, contents, name);
    }

    if result {
        log("Loaded file '%'", filename);
    } else {
        log_error("Could not load file '%'", filename);
    }

    return result;
}