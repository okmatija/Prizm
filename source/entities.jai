Entity_Type :: enum {
    // GENERAL_OBJ; // See what the snake example does
    MESH; // @Cleanup rename this to TRIANGLE_MESH, and the corresponding Mesh_Entity to Triangle_Mesh_Entity
    POLYLINE_SOUP2;
    POLYLINE_SOUP3;
    POLYGON_SOUP;
    POINT_CLOUD;   // isa Mesh
    SEGMENT_SOUP3; // isa Mesh
    UNKNOWN;
}

// Used for entity reloading, order is important here becaues reload_items uses it for sorting @Think If the order is changed but the values stay constant what happens?
Entity_Source :: enum #specified {
    UNKNOWN :: 0;
    FILE_ON_DISK :: 1;
    SELECTION :: 2;
    COMMAND_OUTPUT :: 3;
    PRESET_SHAPE :: 4;
}

find_header_annotation :: (entity : *Entity) -> *Annotation {
    for *annotation : entity.block_annotations {
        if annotation.kind == .BLOCK && annotation.id == 1 {
            return annotation;
        }
    }
    return null;
}

// @Refactor Make AABB_Tree pointers, and default to brute force search if the pointer is null
// @Refactor Maybe Entity should contain the mesh and the item variables, but data specific to rendering meshes should be in the mesh?

Entity :: struct {
    type : Entity_Type = .UNKNOWN;
    source : Entity_Source = .UNKNOWN;

    // source : Tagged_Union();

    is_selected := false;
    is_hovered := false;

    render_info : Render_Info;
    display_info : Display_Info;

    // Note the transform stored in this mesh also applies to:
    // - Shape geometry in the specialized types
    // - Bounding shapes in render_info
    mesh : Mesh; // :EntityInitializers Note that sometimes its convenient to start with the mesh and compute the shape in the Entity sub-types, and other timee vice-verse!

    // @Incomplete Perhaps there should be a pool for the annotation strings?
    // Interpretation depends on Entity_Type (I think)
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

    using source_info : union {
        // The console command the user executed to generate the entity
        console_command : string;

        // The function that was called to generate the entity
        preset_proc : #type () -> *Entity;
    }

    auto_reload : bool; // Only really relevant if source == .FILE_ON_DISK

    // This should be used to find entities
    // If source == .SELECTION      this is SELECTION_FOLDER/name
    // If source == .FILE_ON_DISK   this is fully_pathed_filename
    // If source == .PRESET_SHAPE   this is PRESET_SHAPE_FOLDER/name
    // If source == .COMMAND_OUTPUT this is COMMAND_OUTPUT_FOLDER/name
    fully_pathed_name : string;

    // if source == .FILE_ON_DISK these are filled using file_modtime_and_size
    // otherwise these are the current_time_consensus and the mesh vertex count
    creation_time : Apollo_Time;
    creation_size : s64;

    // This gets set when we add the entity to app.entities, and makes sense only in that context (I think)
    generation_index : int; // @Cleanup delete this incorrect comment: entities with the same 'fully_pathed_name' will increment this
}

SELECTION_FOLDER :: "Selections";
PRESET_SHAPE_FOLDER :: "Preset Shapes";
COMMAND_OUTPUT_FOLDER :: "Command Outputs";

// :EntityInitializers I tried twice to make init functions for these structs but it seems like a waste of time! These structs collections of things, some don't need initting, and others do but in orders that change depending on the context e.g., set the mesh then convert to the shape, or set the shape and convert ot a mesh. It's fine just to set the fields when their needed, you could make local init functions specific to the local context if it saves typing out the initting code.

Polyline_Soup2_Entity :: struct {
    #as using base : Entity;
    type = .POLYLINE_SOUP2;
    display_info.element_label_theme.label_color = .{.6, .6, 0, 1}; // @Cleanup put colors in app.jai

    Shape :: Polyline_Soup2;
    shape : Shape;
    spatial : *AABB_Tree(Shape);
}

Polyline_Soup3_Entity :: struct {
    #as using base : Entity;
    type = .POLYLINE_SOUP3;
    display_info.element_label_theme.label_color = .{.6, .6, 0, 1};

    Shape :: Polyline_Soup3;
    shape : Shape;
    spatial : *AABB_Tree(Shape);
}

Polygon_Soup_Entity :: struct {
    #as using base : Entity;
    type = .POLYGON_SOUP;
    display_info.element_label_theme.label_color = .{1., 1., 0, 1}; // @Cleanup put colors in app.jai

    Shape :: Polygon_Soup;
    shape : Shape;
    spatial : *AABB_Tree(Shape);
}

Segment_Soup3_Entity :: struct {
    #as using base : Entity;
    type = .SEGMENT_SOUP3;
    display_info.element_label_theme.label_color = .{.6, .6, 0, 1};

    Shape :: Segment_Soup3;
    spatial : *AABB_Tree(Shape);

#place mesh;
    shape : Shape = ---; // Alias for consistency
}

Point_Cloud_Entity :: struct {
    #as using base : Entity;
    type = .POINT_CLOUD;

    // @Cleanup Probably we want to remove these base initializers
    display_info.element_label_theme.label_color = .{1., 1., 0, 1}; // @Cleanup put colors in app.jai
    mesh.geometry_format = .POINTS;

    Shape :: Point_Cloud;
    spatial : *AABB_Tree(Shape);
#place mesh;
    shape : Shape = ---; // Alias for consistency
}

// mesh.geometry_format will be .TRIANGLES for a Mesh_Entity
Mesh_Entity :: struct {
    #as using base : Entity;
    type = .MESH;
    display_info.element_label_theme.label_color = .{1., 1., 0, 1};

    // display_info.wireframe_visible = true;
    // display_info.wireframe_width = 2;
    // display_info.element_label_theme.show_index = true;
    // display_info.vertex_label_style.show_position = true;

    Shape :: Mesh;
    spatial : *AABB_Tree(Shape);
#place mesh;
    shape : Shape = ---; // Alias for consistency
}

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

clear :: (base : *Entity) {
    // @Cleanup Pull out all the clear mesh calls
    if #complete base.type == {
        case .UNKNOWN;
            // do nothing

        case .POINT_CLOUD;

            entity := cast(*Point_Cloud_Entity)base;
            clear(*entity.mesh);

        case .POLYLINE_SOUP2;

            entity := cast(*Polyline_Soup2_Entity)base;
            clear(*entity.mesh);
            clear(*entity.shape);

        case .POLYLINE_SOUP3;

            entity := cast(*Polyline_Soup3_Entity)base;
            clear(*entity.mesh);
            clear(*entity.shape);

        case .SEGMENT_SOUP3;

            entity := cast(*Segment_Soup3_Entity)base;
            clear(*entity.mesh);

        case .POLYGON_SOUP;

            entity := cast(*Polygon_Soup_Entity)base;
            clear(*entity.mesh);
            clear(*entity.shape);

        case .MESH;

            entity := cast(*Mesh_Entity)base;
            clear(*entity.mesh);
    }

    // Remove data from gpu memory as well
    if base.render_info.vbo glDeleteBuffers(1, *base.render_info.vbo);
    if base.render_info.ibo glDeleteBuffers(1, *base.render_info.ibo);
    base.render_info = .{};
}


remove_entity_by_index :: (entity_to_remove_index : int) {
    if entity_to_remove_index >= 0 && entity_to_remove_index < app.entities.count {
        entity_to_remove : *Entity = app.entities[entity_to_remove_index];
        remove_directory(get_directory(entity_to_remove.fully_pathed_name));
        deinit(entity_to_remove);
        free(entity_to_remove);
        array_ordered_remove_by_index(*app.entities, entity_to_remove_index);
    }
}

// @FIXME This should be an ordered remove!
remove_entities_if_selected :: () {
    for app.entities if it.is_selected {
        remove_directory(get_directory(it.fully_pathed_name));
        deinit(it);
        free(it);
        remove it; // @FIXME this screws up the order of items in the list
    }
}

deinit :: (base : *Entity) {
    if !base return;

    if #complete base.type == {
        case .UNKNOWN;
            // do nothing

        case .POLYLINE_SOUP2;

            entity := cast(*Polyline_Soup2_Entity)base;
            deinit(*entity.mesh);
            deinit(*entity.shape);
            deinit(entity.spatial);

        case .POLYLINE_SOUP3;

            entity := cast(*Polyline_Soup3_Entity)base;
            deinit(*entity.mesh);
            deinit(*entity.shape);
            deinit(entity.spatial);

        case .POLYGON_SOUP;

            entity := cast(*Polygon_Soup_Entity)base;
            deinit(*entity.mesh);
            deinit(*entity.shape);
            deinit(entity.spatial);

        case .POINT_CLOUD;

            entity := cast(*Point_Cloud_Entity)base;
            deinit(*entity.mesh);
            deinit(entity.spatial);

        case .SEGMENT_SOUP3;

            entity := cast(*Segment_Soup3_Entity)base;
            deinit(*entity.mesh);
            deinit(entity.spatial);

        case .MESH;

            entity := cast(*Mesh_Entity)base;
            deinit(*entity.mesh);
            deinit(entity.spatial);
    }

    for :AnnotationIterator base deinit(it);
    // nocommit We should have AnnotationListIterator, so we don't need to change so many places
    array_reset(*base.command_annotations);
    array_reset(*base.block_annotations);
    array_reset(*base.vertex_annotations);
    array_reset(*base.face_annotations);
    array_reset(*base.line_annotations);

    if #complete base.source == {
        case .UNKNOWN;        // Do nothing
        case .FILE_ON_DISK;   // Do nothing
        case .COMMAND_OUTPUT; free(base.console_command);
        case .PRESET_SHAPE;   // Do nothing
        case .SELECTION;      // Do nothing
    }

    // Remove data from gpu memory as well
    if base.render_info.vbo glDeleteBuffers(1, *base.render_info.vbo);
    if base.render_info.ibo glDeleteBuffers(1, *base.render_info.ibo);
    base.render_info = .{};
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
        found, found_index = find_entity(entity.fully_pathed_name, -1);
    } else {
        // Finds the entity with matching generation index
        found, found_index = find_entity(entity.fully_pathed_name, entity.generation_index);
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
                entity.auto_reload =           found.auto_reload;

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

is_changed_on_disk :: (using entity : Entity) -> bool {
    changed := false;
    if source == .FILE_ON_DISK {
        modtime, size, ok := file_modtime_and_size(fully_pathed_name);
        if modtime > creation_time || size != creation_size {
            changed = true;
        }
    }
    return changed;
}


entity_primary_color :: (using entity : *Entity) -> *Vector4, *bool {
    if #complete type == {
        case .UNKNOWN; #through;
        case .MESH;
            if #complete mesh.geometry_format == {
                case .UNKNOWN;   #through;
                case .POINTS;    return *display_info.points_color,    *display_info.points_visible;
                case .LINES;     return *display_info.wireframe_color, *display_info.wireframe_visible;
                case .TRIANGLES; return *display_info.surface_color,   *display_info.surface_visible;
            }
        case .POLYLINE_SOUP2; return *display_info.wireframe_color, *display_info.wireframe_visible;
        case .POLYLINE_SOUP3; return *display_info.wireframe_color, *display_info.wireframe_visible;
        case .SEGMENT_SOUP3;  return *display_info.wireframe_color, *display_info.wireframe_visible;
        case .POLYGON_SOUP;   return *display_info.surface_color,   *display_info.surface_visible;
        case .POINT_CLOUD;    return *display_info.points_color,    *display_info.points_visible;
    }
    return null, null;
}

reset_entity_primary_color :: (entity : *Entity) {
    color : *Vector4 = entity_primary_color(entity);
    if color {
        <<color = color_from_path(entity.fully_pathed_name);
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
    return entity_name(entity.fully_pathed_name);
}

entity_description :: (using entity : Entity, with_creation_time : bool) -> string {

    index_text := "";
    if generation_index != 0 {
        index_text = tprint(" <%>", generation_index);
    }

    time_text := "";
    time_separator := "";
    if with_creation_time {
        time_text = filetime_to_readable_date(creation_time);
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
                if it.fully_pathed_name == fully_pathed_name {
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
                if it.fully_pathed_name == fully_pathed_name {
                    max_generation_index = it.generation_index;
                    found = it;
                    found_index = it_index;
                }
            }
        }
    }

    return found, found_index;
}

// @Think Add field to say if its intersection or nearest point etc?
Point_On_Entity :: struct {
    position : Point3; // World space
    element_kind : Simple_Mesh_Element = .MESH;
    element_index : int = -1;
    entity_index : int = -1;
}


    // nocommit @Incomplete Add a screenspace distance filter
// @Cleanup Add a threshold for how close you need to be to consider adding a vertex
find_closest_vertex_on_visible_entities :: () -> Point_On_Entity {

    ray_world : Ray3 = make_camera_ray();

    result : Point_On_Entity;

//nocommit Use the visible iterator here
    min_dist2 := FLOAT32_INFINITY;
    for entity, entity_index : app.entities {
        if entity.display_info.is_visible {
            if entity.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity {
                inverse_transpose := transpose(inverse(entity.mesh.world_from_model));
                for :WorldPointIterator point_world, point_index : entity.mesh {

                    front_facing_only :: false;

                    // Note if the vertex normals are 0 the dot product will be 0 and will _not_ trigger the continue, we
                    // want to be able to select vertices with 0 normals in all cases
                    if front_facing_only && entity.mesh.normals.count {
                        normal_world : Vector3 = transform_vector(inverse_transpose, entity.mesh.normals[point_index]);
                        if dot(normal_world, current_look_direction()) > 0 {
                            continue;
                        }
                    }

                    unused_closest_point, dist2, unused_t := distance_point3_ray3(point_world, ray_world);

                    if dist2 < min_dist2 {

                        if is_clipped(entity.display_info, point_world) {
                            continue;
                        }

                        min_dist2 = dist2;
                        result.position = point_world;
                        result.element_kind = .VERTEX;
                        result.element_index = point_index;
                        result.entity_index = entity_index;
                    }
                }
            }
        }
    }

    return result;
}

// @Incomplete Pass a parameter or have a method on Point_On_Entity, which changes the element_kind to .VERTEX if the barycentric/segment parameter is 0/1?
find_closest_point_on_visible_entities :: (_max_dist_px : int = -1, front_facing_only := false) -> Point_On_Entity {

    max_dist_px : int = ifx _max_dist_px < 0 then app.settings.closest_point_query_max_dist_px else _max_dist_px;
    projection_from_world : Matrix4 = make_projection_from_world(app.camera);

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

    sphere_clipped :: true;
    range_clipped :: true;

    ray_world := make_camera_ray();

    result : Point_On_Entity;

    Visible_Selectable_Mesh :: #bake_arguments Entities_Iterator(should_visit = (e) => (
            e.display_info.is_visible &&
            e.type == .MESH &&
            e.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity
        ));

    intersected_triangle := false;
    t_min := FLOAT32_INFINITY;

    ProcessTriangle :: (triangle_model : Triangle3, triangle_id : int) #expand {
        normal_direction := compute_normal(triangle_model, normalize=false);
    
        if normal_direction == Vector3.{0, 0, 0} {
            continue;
        }
    
        if `front_facing_only && dot_product(normal_direction, `ray_model.direction) > 0 {
            continue;
        }
    
        is_hit, t, isect_model := find_intersect_primitive_ray3(triangle_model, `ray_model);
    
        if is_hit == false || t >= `t_min {
            continue;
        }
    
        isect_world : Vector3 = transform_point(`entity.mesh.world_from_model, isect_model);
        if is_clipped(`entity.display_info, isect_world, test_sphere=`sphere_clipped, test_ranges=`range_clipped) {
            continue;
        }
    
        `t_min = t;
        `result.position = isect_world;
        `result.element_kind = .TRIANGLE;
        `result.element_index = triangle_id;
        `result.entity_index = `entity_index;
        `intersected_triangle = true;
    }

    for :Visible_Selectable_Mesh entity, entity_index : app.entities {
        mesh_entity := cast(*Mesh_Entity)entity;
        ray_model : Ray3 = transform_ray(inverse(mesh_entity.mesh.world_from_model), ray_world);

        // Early out using a ray-clipping sphere check 
        // if is_clipped(`entity.display_info, isect_world, test_sphere=`sphere_clipped, test_ranges=`range_clipped) {
        //     continue;
        // }

        if mesh_entity.spatial == null {

            for :ModelTriangleIterator triangle, triangle_index : entity.mesh {
                ProcessTriangle(triangle, triangle_index);
            }

        } else {

            VisitPrimitivesIntersectingRay(mesh_entity.spatial, ray_model,
                #code ProcessTriangle(primitive, primitive_id)
            );

        }
    }

    if intersected_triangle {
        return result;
    }

    d_min := FLOAT32_INFINITY;

    // @Cleanup This should be done when we loop over each triangle?
    for :Visible_Selectable_Mesh entity, entity_index : app.entities {

        for :WorldTriangleEdgeIterator segment, segment_index : entity.mesh { 
            // These are in world space
            closest_point := closest_point_ray_segment(ray_world, segment);
            point_world := closest_point.closest[1];
            d := closest_point.distance;

            // @Incomplete continue if the distance is beyond a threshold?

            if d < d_min {

                if is_clipped(entity.display_info, point_world, test_sphere=sphere_clipped, test_ranges=range_clipped) {
                    continue;
                }

                if OutsideScreenDist(point_world) {
                    continue;
                }

                d_min = d;
                result.position = point_world;
                result.element_kind = .SEGMENT;
                result.element_index = segment_index;
                result.entity_index = entity_index;
            }
        }
    }

    Visible_Selectable_Point_Cloud :: #bake_arguments Entities_Iterator(should_visit = (e) => (
            e.display_info.is_visible &&
            e.type == .POINT_CLOUD &&
            e.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity
        ));

    // Note: When we use Simple_Mesh we will make this iterator go over the point set with a p directive, not vertices set with a v directive
    for :Visible_Selectable_Point_Cloud entity, entity_index : app.entities {
        for :WorldPointIterator point_world, point_index : entity.mesh {

            unused_closest_point, dist2, unused_t := distance_point3_ray3(point_world, ray_world);

            if dist2 < d_min * d_min {

                if is_clipped(entity.display_info, point_world, test_sphere=sphere_clipped, test_ranges=range_clipped) {
                    continue;
                }

                if OutsideScreenDist(point_world) {
                    continue;
                }

                d_min = sqrt(dist2);
                result.position = point_world;
                result.element_kind = .POINT;
                result.element_index = point_index;
                result.entity_index = entity_index;
            }
        }
    }

    Visible_Selectable_Polyline_Soup3 :: #bake_arguments Entities_Iterator(should_visit = (e) => (
            e.display_info.is_visible &&
            e.type == .POLYLINE_SOUP3 &&
            e.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity
        ));

    for :Visible_Selectable_Polyline_Soup3 entity, entity_index : app.entities {
        soup := cast(*Polyline_Soup3_Entity)entity;

        ray_model := transform_ray(inverse(entity.mesh.world_from_model), ray_world);

        // @Incomplete If available, use the spatial index
        for :PolylineSegmentIterator segment, segment_index : soup.shape {
            segment3 : Segment3;
            segment3.start = <<segment.from_point;
            segment3.end = <<segment.to_point;

            closest_point := closest_point_ray_segment(ray_model, segment3);
            point_model := closest_point.closest[1];
            d := closest_point.distance;

            // @Incomplete continue if the distance is beyond a threshold?

            if d < d_min {

                point_world := transform_point(entity.mesh.world_from_model, point_model);
                if is_clipped(entity.display_info, point_world, test_sphere=sphere_clipped, test_ranges=range_clipped) {
                    continue;
                }

                if OutsideScreenDist(point_world) {
                    continue;
                }

                d_min = d;
                result.position = point_world;
                result.element_kind = .SEGMENT;
                result.element_index = segment_index; // @Incomplete Is this properly handled? Maybe it should be the vertex index if the segment parameter is 0 or 1
                result.entity_index = entity_index;
            }
        }
    }



    Visible_Selectable_Polyline_Soup2 :: #bake_arguments Entities_Iterator(should_visit = (e) => (
            e.display_info.is_visible &&
            e.type == .POLYLINE_SOUP2 &&
            e.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity
        ));

    for :Visible_Selectable_Polyline_Soup2 entity, entity_index : app.entities {
        soup := cast(*Polyline_Soup2_Entity)entity;

        ray_model := transform_ray(inverse(entity.mesh.world_from_model), ray_world);

        // @Incomplete If available, use the spatial index
        for :PolylineSegmentIterator segment, segment_index : soup.shape {
            segment3 : Segment3;
            segment3.start = make_vector3(segment.from_point.x, segment.from_point.y, 0.);
            segment3.end   = make_vector3(segment.to_point.x, segment.to_point.y, 0.);

            closest_point := closest_point_ray_segment(ray_model, segment3);
            point_model := closest_point.closest[1];
            d := closest_point.distance;

            // @Incomplete continue if the distance is beyond a threshold?

            if d < d_min {

                point_world := transform_point(entity.mesh.world_from_model, point_model);
                if is_clipped(entity.display_info, point_world, test_sphere=sphere_clipped, test_ranges=range_clipped) {
                    continue;
                }

                if OutsideScreenDist(point_world) {
                    continue;
                }

                d_min = d;
                result.position = point_world;
                result.element_kind = .SEGMENT;
                result.element_index = segment_index; // @Incomplete Is this properly handled? Maybe it should be the vertex index if the segment parameter is 0 or 1
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
    if #complete entity.source == {
        case .UNKNOWN; #through;
        case .SELECTION;

            return false;

        case .FILE_ON_DISK;

            // nocommit This code is in the wrong place
            enable_reload_shortcut :: (entity : Entity) -> bool {
                if app.settings.disable_reload_key_if_file_unchanged {
                    return is_changed_on_disk(entity);
                }
                return true;
            }

            // Feature documentation: We want to always allow the user to reload the file by explictly clicking the UI button, but by default a user setting is set such that using the keyboard shortcut to reload a file will only reload it if it has changed
            if triggered_by_button || enable_reload_shortcut(entity) {
                log("Reloading file '%'... ", entity.fully_pathed_name);
                duplicate_file_behaviour := Duplicate_File_Behaviour.APPEND;

                // nocommit With command annotations this function could return a list of new entities, and each of these should be merged into the item list using duplicate_file_behaviour
                new_entity := load_one_file(entity.fully_pathed_name, duplicate_file_behaviour);
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

        case .PRESET_SHAPE;

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

        case .COMMAND_OUTPUT;

            // Note: This is only intended to support simple use cases,
            // reloading command output can easily break if e.g., item indices change
            log("Re-executing console command '%'... ", entity.console_command);
            console_execute_command(entity.console_command);
            return true;
    }

    return false;
}

set_entity_source_from_file :: (entity : *Entity, fully_pathed_filename : string, loc := #caller_location) {
    assert(entity != null);
    entity.fully_pathed_name = copy_string(fully_pathed_filename);

    entity.source = .FILE_ON_DISK;
    modtime, size, ok := file_modtime_and_size(fully_pathed_filename);
    if ok {
        entity.creation_time = modtime;
        entity.creation_size = size;
    } else {
        name := entity_name(fully_pathed_filename);
        log_error("Function % failed for entity '%' when called in %. Called from %", #procedure_name(file_modtime_and_size), name, #procedure_name(), loc);
    }
}

set_entity_source_from_preset :: (entity : *Entity, name : string, preset_proc : #type ()->*Entity, point_count : s64) {
    assert(entity != null);
    entity.fully_pathed_name = copy_string(tprint("%/%", PRESET_SHAPE_FOLDER, name));

    entity.source = .PRESET_SHAPE;
    entity.creation_time = current_time_consensus();
    entity.creation_size = point_count;
    entity.preset_proc = preset_proc;
}

set_entity_source_from_selection :: (entity : *Entity, name : string, point_count : s64) {
    assert(entity != null);
    entity.fully_pathed_name = copy_string(tprint("%/%", SELECTION_FOLDER, name));

    entity.source = .SELECTION;
    entity.creation_time = current_time_consensus();
    entity.creation_size = point_count;
}

set_entity_source_from_command :: (entity : *Entity, name : string, console_command : string, point_count : s64) {
    assert(entity != null);
    entity.fully_pathed_name = copy_string(tprint("%/%", COMMAND_OUTPUT_FOLDER, name));

    entity.source = .COMMAND_OUTPUT;
    entity.creation_time = current_time_consensus();
    entity.creation_size = point_count;
    entity.console_command = copy_string(console_command);
}

// set_entity_source_from_code :: (entity : *Entity, name : string, console_command : string, point_count : s64) {
//     assert(entity != null);
//     entity.fully_pathed_name = copy_string(tprint("%/%", SOURCE_CODE_FOLDER, name));
//
//     entity.source = .SOURCE_CODE;
//     entity.creation_time = current_time_consensus();
//     entity.creation_size = point_count;
// }

// Preconditions: entity.fully_pathed_name has been set
set_entity_display_info :: (entity : *Entity, geometry_format : Geometry_Format) {
    assert(entity != null);

    primary_color := color_from_path(entity.fully_pathed_name);
    if #complete geometry_format == {
        case .UNKNOWN;

            log_error("Unexpected % geometry format", geometry_format);

        case .POINTS;

            entity.display_info.surface_visible = true; // @Cleanup What the heck??
            entity.display_info.points_visible = true;
            entity.display_info.points_size = 4;
            entity.display_info.points_color = primary_color;

        case .LINES;

            entity.display_info.wireframe_visible = true;
            entity.display_info.wireframe_width = 1;
            entity.display_info.wireframe_color = primary_color;

        case .TRIANGLES;

            entity.display_info.surface_visible = true;
            entity.display_info.surface_color = primary_color;
    }
}

// Maybe this should also take the shape and set that (will set the mesh twice if T == Mesh_Entity, but that's fine)
init_entity_spatial_index :: (entity : *$T/Entity) {
    assert(entity != null);
    entity.spatial = New(AABB_Tree(T.Shape));
    init(entity.spatial, *entity.shape);
}

// Plan:
// - Single pixel radius means just select the item under the cursor, unless we miss and then just use the closest thing
// - Init the base struct, move the source stuff into an Entity_Source type? and init that separately?


/*

Ex:

init :: (using base : *Entity, set_source : $T/Entity_Source, geometry_format : Geometry_Format) {
    assert(base != null); // Make sure New succeeded, or we're on the stack

    set(*source, set_source);

    base_source := cast(*Entity_Source)source.bytes.data;
    fully_pathed_filename := tprint("%/%", base_source.path, base.name);
    primary_color := color_from_path(fully_pathed_filename);

    //if #complete set_source.kind == {
    //    case .UNKNOWN;
    //        assert(false); // Should I crash or not?
    //    case .FILE_ON_DISK;
    //        fully_pathed_filename = tprint("%/%", set_source.path, base.name);
    //    case .PRESET_SHAPE;
    //        fully_pathed_filename = tprint("%/%", PRESET_SHAPE_FOLDER, base.name);
    //    case .COMMAND_OUTPUT;
    //        fully_pathed_filename = tprint("%/%", COMMAND_OUTPUT_FOLDER, base.name);
    //    case .SOURCE_CODE;
    //        fully_pathed_filename = tprint("%/%", SOURCE_CODE_FOLDER, base.name);
    //}

    if #complete geometry_format == {
        case .UNKNOWN;

            log_warning("Unexpected % geometry format for item '%' in %. Called from %", mesh.geometry_format, name, #procedure_name(), loc);

        case .POINTS;

            display_info.surface_visible = true; // @Cleanup Why is this here??
            display_info.points_visible = true;
            display_info.points_size = 2;
            display_info.points_color = primary_color;

        case .LINES;

            display_info.wireframe_visible = true;
            display_info.wireframe_width = 1;
            display_info.wireframe_color = primary_color;

        case .TRIANGLES;

            display_info.surface_visible = true;
            display_info.surface_color = primary_color;
    }
}

set_entity_source_from_preset :: (base : *Entity, name : string, preset_proc : #type ()->*Entity);
set_entity_source_from_command :: (base : *Entity, name : string, console_command : string);
//set_entity_source_from_code :: (base : *Entity, entity_name : string, ...);
set_entity_display_info(base : *Entity, geometry_format : Geometry_Format);
init_entity_spatial_index :: (entity : *Mesh_Entity);

init :: (using source : *Entity_Source_File, fully_pathed_filename : string, loc := #caller_location) {
    path = copy_string(get_directory(fully_pathed_filename));
    modtime, size, ok := file_modtime_and_size(fully_pathed_filename);
    if ok {
        creation_time = modtime;
        creation_size = size;
    } else {
        creation_time = current_time_consensus();
        creation_size = 0;
        log_error("Function % failed for entity '%' when called in %. Called from %", #procedure_name(file_modtime_and_size), name, #procedure_name(), loc);
    }
}

init :: (using source : *Entity_Source_Command, console_command : string) {
    path = copy_string(console_command);
}

Entity_Source :: struct {
    Source :: enum {...}
    kind : Source = .UNKNOWN; // TODO make this the first entry!
    creation_time : Apollo_Time;
    creation_size : s64; // Size of the entity, format depends on the subtype
    path : string; // Format depends on the subtype
}

Entity_Source_File :: struct {
    using #as base : Entity_Source;
    kind = .FILE_ON_DISK;

    // set path to directory on disk and creation time to mod time

    // Reloading reads this file
    auto_reload : bool;
}

Entity_Source_Preset :: struct {
    using #as base : Entity_Source;
    kind = .PRESET_SHAPE;

    // hardcode path and set creation time to current time

    // Reloading runs this procedure
    preset_proc : #type ()->*Entity;
}

Entity_Source_Command :: struct {
    using #as base : Entity_Source;
    kind = .CONSOLE_COMMAND;

    // hardcode path and set creation time to current time

    // Reloading runs this command
    console_command : string;
    // generation_index : int; // maybe
}

Entity_Source_Code :: struct {
    using #as base : Entity_Source;
    kind = .SOURCE_CODE;

    // source code location?

    // set path to source code + line number? set creation time to current time

    // Reloading could run this procedure with the given data (closure)
    proc : #type (data : *void)->*Entity;
    data : *void;
    // generation_index : int; // maybe
}

init :: (base : *Entity, mesh : Mesh, source : $T/Entity_Source) {
    // stuff in init_entity_base_parameters (which needs the mesh)
    // stuff to init the user selection display_info (which needs the source)
}

// @Cleanup Add a modify to check T
new_debug_mesh_entity :: (mesh : Mesh) {
    type : Entity_Type = .UNKNOWN;
    source : Entity_Source = .UNKNOWN;
    is_selected := false;
    is_hovered := false;
    render_info : Render_Info;
    display_info : Display_Info;
    mesh : Mesh;
    annotations : [..]Annotation;

    using source_info : union {
        // The fully pathed filename pointing to file on disk that created the entity
        fully_pathed_filename : string;

        // The console command the user executed to generate the entity
        console_command : string;

        // The function that was called to generate the entity
        preset_proc : #type () -> *Entity;
    }

    auto_reload : bool; // Only really relevant if source == .FILE_ON_DISK

    name : string;
    fully_pathed_name : string;
    creation_time : Apollo_Time;
    creation_size : s64;
    generation_index : int; // entities with the same 'fully_pathed_name' will increment this
}

*/

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
        log("Loaded file '%', with type %", filename, result.type);
    } else {
        log_error("Could not load file '%'", filename);
    }

    return result;
}