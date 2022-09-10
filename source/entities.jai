Entity_Type :: enum {
    // GENERAL_OBJ; // See what the snake example does
    MESH; // nocommit rename this to TRIANGLE_MESH, and the corresponding Mesh_Entity to Triangle_Mesh_Entity
    POLYLINE_SOUP2;
    POLYLINE_SOUP3;
    POLYGON_SOUP;
    POINT_CLOUD;   // isa Mesh
    SEGMENT_SOUP3; // isa Mesh
    UNKNOWN;
}

// Used for entity reloading, order is important here becaues reload_items uses it for sorting
Entity_Source :: enum {
    FILE_ON_DISK;
    PRESET_SHAPE;
    COMMAND_OUTPUT;
    UNKNOWN; // Use this if you don't want anything to happen when an entity is reloaded
}

Annotation :: struct {
    Kind :: enum {
        VERTEX;
        LINE;
        TRIANGLE;
        BLOCK; // e.g., a header at the top of an .obj file
    }

    kind : Kind;
    text : string; // owned
 
    // if kind == .BLOCK then 1-based line number starting block comment
    // if kind != .BLOCK then 0-based index for vertex/line/triangle
    id : int;
}

find_header_annotation :: (entity : *Entity) -> *Annotation {
    for *annotation : entity.annotations {
        if annotation.kind == .BLOCK && annotation.id == 1 {
            return annotation;
        }
    }
    return null;
}

// @Refactor Make AABB_Tree pointers, and default to brute force search if the pointer is null

Entity :: struct {
    type : Entity_Type = .UNKNOWN;
    source : Entity_Source = .UNKNOWN;

    is_selected := false;
    is_hovered := false;

    render_info : Render_Info;
    display_info : Display_Info;

    // Note the transform stored in this mesh also applies to:
    // - Shape geometry in the specialized types
    // - Bounding shapes in render_info
    mesh : Mesh;

    // @Incomplete Perhaps there should be a pool for the annotation strings?
    // Interpretation depends on Entity_Type (I think)
    annotations : [..]Annotation;

    // @Incomplete
    // user_data : *void; // Registered commands may want to attach data here

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

    // This should be used to find entities
    // If source == .FILE_ON_DISK   this is fully_pathed_filename
    // If source == .PRESET_SHAPE   this is PRESET_SHAPE_FOLDER
    // If source == .COMMAND_OUTPUT this is COMMAND_OUTPUT_FOLDER
    fully_pathed_name : string;

    // if source == .FILE_ON_DISK these are filled using file_modtime_and_size
    // otherwise these are the current_time_consensus and the mesh vertex count
    creation_time : Apollo_Time;
    creation_size : s64;

    generation_index : int; // entities with the same 'fully_pathed_name' will increment this
}

PRESET_SHAPE_FOLDER :: "Preset shapes";
COMMAND_OUTPUT_FOLDER :: "Command outputs";

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
    // nocommit @Cleanup Pull out all the clear mesh calls
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
        directory_to_remove := "";
        if entity_to_remove.source == .FILE_ON_DISK {
            directory_to_remove = get_directory(entity_to_remove.fully_pathed_filename);
        }
        deinit(entity_to_remove);
        free(entity_to_remove);
        array_ordered_remove_by_index(*app.entities, entity_to_remove_index);
        remove_directory(directory_to_remove);
    }
}

// @FIXME This should be an ordered remove!
remove_entities_if_selected :: () {
    for app.entities if it.is_selected {
        directory_to_remove := "";
        if it.source == .FILE_ON_DISK {
            directory_to_remove = get_directory(it.fully_pathed_filename);
        }
        deinit(it);
        free(it);
        remove it; // @FIXME this screws up the order of items in the list
        remove_directory(directory_to_remove);
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
            for entity.annotations free(it.text);
            array_reset(*entity.annotations);

        case .POLYLINE_SOUP3;

            entity := cast(*Polyline_Soup3_Entity)base;
            deinit(*entity.mesh);
            deinit(*entity.shape);
            deinit(entity.spatial);
            for entity.annotations free(it.text);
            array_reset(*entity.annotations);

        case .POLYGON_SOUP;

            entity := cast(*Polygon_Soup_Entity)base;
            deinit(*entity.mesh);
            deinit(*entity.shape);
            deinit(entity.spatial);
            for entity.annotations free(it.text);
            array_reset(*entity.annotations);

        case .POINT_CLOUD;

            entity := cast(*Point_Cloud_Entity)base;
            deinit(*entity.mesh);
            deinit(entity.spatial);
            for entity.annotations free(it.text);
            array_reset(*entity.annotations);

        case .SEGMENT_SOUP3;

            entity := cast(*Segment_Soup3_Entity)base;
            deinit(*entity.mesh);
            deinit(entity.spatial);
            for entity.annotations free(it.text);
            array_reset(*entity.annotations);

        case .MESH;

            entity := cast(*Mesh_Entity)base;
            deinit(*entity.mesh);
            deinit(entity.spatial);
            for entity.annotations free(it.text);
            array_reset(*entity.annotations);
    }

    if #complete base.source == {
        case .FILE_ON_DISK;   free(base.fully_pathed_filename);
        case .COMMAND_OUTPUT; free(base.console_command);
        case .PRESET_SHAPE;   // Do nothing
        case .UNKNOWN;        // Do nothing
    }

    free(base.name);

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

                // nocommit replace with code to set the dirty flag
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
    return entity.mesh.positions.count == 0;
}

is_changed_on_disk :: (using entity : Entity) -> bool {
    changed := false;
    if source == .FILE_ON_DISK {
        modtime, size, ok := file_modtime_and_size(fully_pathed_filename);
        if modtime > creation_time || size != creation_size {
            changed = true;
        }
    }
    return changed;
}


entity_primary_color :: (using entity : *Entity) -> *Vector4 {
    if #complete type == {
        case .POLYLINE_SOUP2; return *display_info.wireframe_color;
        case .POLYLINE_SOUP3; return *display_info.wireframe_color;
        case .SEGMENT_SOUP3;  return *display_info.wireframe_color;
        case .POLYGON_SOUP;   return *display_info.surface_color;
        case .POINT_CLOUD;    return *display_info.points_color;
        case .UNKNOWN;        #through;
        case .MESH;
            if #complete mesh.geometry_format == {
                case .POINTS;    return *display_info.points_color;
                case .LINES;     return *display_info.wireframe_color;
                case .UNKNOWN;   #through;
                case .TRIANGLES; return *display_info.surface_color;
            }
    }
    return null;
}

reset_entity_primary_color :: (entity : *Entity) {
    color : *Vector4 = entity_primary_color(entity);
    if color {
        <<color = color_from_path(entity.fully_pathed_name);
    }
}

// Assumes that fully_pathed_name is canonically formatted (see canonically_formatted_path_string)
// Returns a string pointing into the argument
get_entity_name_from_fully_pathed_name :: (fully_pathed_name : string) -> string {
    name := fully_pathed_name;

    path := parse_path(name);
    if path.words.count {
        name = path.words[path.words.count - 1];
    }

    return name;
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

    return tprint("%1%2%3%4", name, index_text, time_separator, time_text);
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

init_entity_base_parameters :: (entity : *Entity, name : string, primary_color : Vector4, mesh : Mesh, loc := #caller_location) {
    if !entity return;

    // Make sure we set the source type before calling this function
    if entity.source == .UNKNOWN return;

    entity.name = copy_string(name);
    if #complete entity.source == {
        case .COMMAND_OUTPUT;

            entity.fully_pathed_name = copy_string(tprint("%/%", COMMAND_OUTPUT_FOLDER, name));
        
        case .PRESET_SHAPE;

            entity.fully_pathed_name = copy_string(tprint("%/%", PRESET_SHAPE_FOLDER, name));
            entity.creation_time = current_time_consensus();
            entity.creation_size = mesh.positions.count;

        case .FILE_ON_DISK;

            entity.fully_pathed_name = copy_string(entity.fully_pathed_filename);
            modtime, size, ok := file_modtime_and_size(entity.fully_pathed_filename);
            if ok {
                entity.creation_time = modtime;
                entity.creation_size = size;
            } else {
                log_error("Function % failed for entity '%' when called in %. Called from %", #procedure_name(file_modtime_and_size), name, #procedure_name(), loc);
            }

        case .UNKNOWN;

            log_error("Unexpected % source type for entity '%' in %. Called from %", entity.source, name, #procedure_name(), loc);
    }

    if #complete mesh.geometry_format == {
        case .LINES;

            entity.mesh = mesh;
            entity.display_info.wireframe_visible = true;
            entity.display_info.wireframe_width = 1;
            entity.display_info.wireframe_color = primary_color;

        case .TRIANGLES;

            entity.mesh = mesh;
            entity.display_info.surface_visible = true;
            entity.display_info.surface_color = primary_color;

        case .POINTS;

            entity.mesh = mesh;
            entity.display_info.surface_visible = true;
            entity.display_info.points_visible = true;
            entity.display_info.points_size = 2;
            entity.display_info.points_color = primary_color;

        case .UNKNOWN;

            log_warning("Unexpected % geometry format for item '%' in %. Called from %", mesh.geometry_format, name, #procedure_name(), loc);
    }
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

Point_On_Entity :: struct {
    position : Point3; // World space
    element_index : int = -1; // Vertex or Triangle
    entity_index : int = -1;
}

// @Cleanup Add a threshold for how close you need to be to consider adding a vertex
find_closest_vertex_on_visible_entities :: () -> Point_On_Entity {

    ray_world : Ray3 = make_camera_ray();

    result : Point_On_Entity;

    // @Incomplete Add a screenspace distance filter

    dist2 := FLOAT32_INFINITY;
    for entity, entity_index : app.entities {
        if entity.display_info.is_visible {
            if entity.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity {
                for vertex, vertex_index : entity.mesh.positions {

                    front_facing_only :: false;

                    // Note if the vertex normals are 0 the dot product will be 0 and will _not_ trigger the continue, we
                    // want to be able to select vertices with 0 normals in all cases
                    if front_facing_only && (entity.mesh.normals.count != 0) && dot(current_look_direction(), entity.mesh.normals[vertex_index]) > 0 {
                        continue;
                    }

                    p : Vector3 = transform_point(entity.mesh.world_from_model, vertex);
                    c, d2, t := distance_point3_ray3(p, ray_world);

                    if d2 < dist2 {

                        if is_clipped(entity.display_info, p) {
                            continue;
                        }

                        dist2 = d2;
                        result.position = p;
                        result.element_index = vertex_index;
                        result.entity_index = entity_index;
                    }
                }
            }
        }
    }

    return result;
}

find_closest_point_on_visible_entities :: (front_facing_only := false) -> Point_On_Entity {

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
    has_degenerate_triangles := false;
    t_min := FLOAT32_INFINITY;

    ProcessTriangle :: (primitive : Triangle3, primitive_id : int) #expand {
        normal_direction := compute_normal(primitive, normalize=false);
    
        if normal_direction == Vector3.{0, 0, 0} {
            `has_degenerate_triangles = true;
            continue;
        }
    
        if `front_facing_only && dot_product(normal_direction, `ray.direction) > 0 {
            continue;
        }
    
        is_hit, t, point := find_intersect_primitive_ray3(primitive, `ray);
    
        if is_hit == false || t >= `t_min {
            continue;
        }
    
        point_world : Vector3 = transform_point(`entity.mesh.world_from_model, point);
        if is_clipped(`entity.display_info, point_world, test_sphere=`sphere_clipped, test_ranges=`range_clipped) {
            continue;
        }
    
        `t_min = t;
        `result.position = point_world;
        `result.element_index = primitive_id;
        `result.entity_index = `entity_index;
        `intersected_triangle = true;
    }

    for :Visible_Selectable_Mesh entity, entity_index : app.entities {
        mesh_entity := cast(*Mesh_Entity)entity;

        // ray in model space
        ray := transform_ray(inverse(entity.mesh.world_from_model), ray_world);

        if mesh_entity.spatial == null {

            for :TrianglesIterator triangle, triangle_index : entity.mesh {
                ProcessTriangle(triangle, triangle_index);
            }

        } else {

            Visit_Primitives_Intersecting_Ray(mesh_entity.spatial, ray,
                #code ProcessTriangle(primitive, primitive_id)
            );

        }
    }

    if intersected_triangle {
        return result;
    }

    d_min := FLOAT32_INFINITY;
    if (has_degenerate_triangles) {
        for :Visible_Selectable_Mesh entity, entity_index : app.entities {

            // ray in model space
            ray := transform_ray(inverse(entity.mesh.world_from_model), ray_world);

            for i : 0..(entity.mesh.indices.count/3)-1 {

                triangle : Triangle3;
                triangle.a = entity.mesh.positions[entity.mesh.indices[3 * i + 0]];
                triangle.b = entity.mesh.positions[entity.mesh.indices[3 * i + 1]];
                triangle.c = entity.mesh.positions[entity.mesh.indices[3 * i + 2]];

                segment3 : Segment3 = ---;
                if triangle.a == triangle.b {
                    segment3.start = triangle.a;
                    segment3.end = triangle.c;
                } else if triangle.a == triangle.c {
                    segment3.start = triangle.a;
                    segment3.end = triangle.b;
                } else if triangle.b == triangle.c {
                    segment3.start = triangle.a;
                    segment3.end = triangle.b;
                } else {
                    segment3.start = triangle.a;
                    segment3.end = triangle.a;
                }

                // These are in model space
                closest_point := closest_point_ray_segment(ray, segment3);
                ipoint := closest_point.closest[1];
                d := closest_point.distance;

                // @Incomplete continue if the distance is beyond a threshold?

                if d < d_min {

                    ipoint_world := transform_point(entity.mesh.world_from_model, ipoint);
                    if is_clipped(entity.display_info, ipoint_world, test_sphere=sphere_clipped, test_ranges=range_clipped) {
                        continue;
                    }

                    d_min = d;
                    result.position = ipoint_world;
                    result.element_index = 0; // @Incomplete Is this properly handled? Maybe it should be the vertex index if the segment parameter is 0 or 1
                    result.entity_index = entity_index;
                }
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

        // ray in model space
        ray := transform_ray(inverse(entity.mesh.world_from_model), ray_world);

        // @Incomplete If available, use the spatial index
        for :SegmentIterator segment, segment_index : soup.shape {
            segment3 : Segment3;
            segment3.start = <<segment.from_point;
            segment3.end = <<segment.to_point;

            closest_point := closest_point_ray_segment(ray, segment3);
            ipoint := closest_point.closest[1];
            d := closest_point.distance;

            // @Incomplete continue if the distance is beyond a threshold?

            if d < d_min {

                ipoint_world := transform_point(entity.mesh.world_from_model, ipoint);
                if is_clipped(entity.display_info, ipoint_world, test_sphere=sphere_clipped, test_ranges=range_clipped) {
                    continue;
                }

                d_min = d;
                result.position = ipoint_world;
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

        // ray in model space
        ray := transform_ray(inverse(entity.mesh.world_from_model), ray_world);

        // @Incomplete If available, use the spatial index
        for :SegmentIterator segment, segment_index : soup.shape {
            segment3 : Segment3;
            segment3.start = make_vector3(segment.from_point.x, segment.from_point.y, 0.);
            segment3.end   = make_vector3(segment.to_point.x, segment.to_point.y, 0.);

            closest_point := closest_point_ray_segment(ray, segment3);
            ipoint := closest_point.closest[1];
            d := closest_point.distance;

            // @Incomplete continue if the distance is beyond a threshold?

            if d < d_min {

                ipoint_world := transform_point(entity.mesh.world_from_model, ipoint);
                if is_clipped(entity.display_info, ipoint_world, test_sphere=sphere_clipped, test_ranges=range_clipped) {
                    continue;
                }

                d_min = d;
                result.position = ipoint_world;
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

    name := get_entity_name_from_fully_pathed_name(filename);

    // Check if we can early exit and avoid reading the file from disk
    {
        found, found_index := find_entity(filename, -1);
        if found && matching_name_behaviour == .IGNORE {
            log_warning("Skipped file: '%' (already loaded)\n", name);
            return null;
        }
    }

    add_directory(get_directory(filename));

    contents := read_entire_file(filename);
    defer free(contents);

    result : *Entity = load_one_file_from_memory(filename, contents, name, matching_name_behaviour);
    // nocommit check the directory has been set correctly here?

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

enable_reload_button :: (entity : Entity) -> bool {
    if app.settings.disable_reload_if_file_unchanged {
        return is_changed_on_disk(entity);
    }
    return true;
}


// @Incomplete pass Duplicate_File_Behaviour 
// Reload the entity using it's fully_pathed_filename, if loading fails clear the entity
reload_entity :: (entity : *Entity) -> did_reload : bool {
    if #complete entity.source == {
        case .FILE_ON_DISK;

            if enable_reload_button(entity) {
                log("Reloading file '%'... ", entity.fully_pathed_filename);
                new_entity := load_one_file(entity.fully_pathed_filename, .OVERWRITE);
                if new_entity {
                    // Set generation_index before adding to overwrite the correct entity
                    new_entity.generation_index = entity.generation_index;
                    add_entity(new_entity, .OVERWRITE);
                } else {
                    clear(entity);
                }
                return true;
            }

        case .PRESET_SHAPE;

            log("Reloading preset shape '%'... ", entity.name);
            new_entity := entity.preset_proc();
            assert(new_entity != null);

            // Set generation_index before adding to overwrite the correct entity
            new_entity.generation_index = entity.generation_index;
            add_entity(new_entity, .OVERWRITE);
            return true;

        case .COMMAND_OUTPUT;

            // Note: This is only intended to support simple use cases,
            // reloading command output can easily break if e.g., item indices change
            log("Re-executing console command '%'... ", entity.console_command);
            console_execute_command(entity.console_command);
            return true;

        case .UNKNOWN;

            log("Skipped reloading item '%' as it has source type %. Only items with source type % can be reloaded (for now.. @Incomplete)", entity.fully_pathed_filename, entity.source, Entity_Source.FILE_ON_DISK);
            return false;
    }

    return false;
}

#scope_file

load_one_file_from_memory :: (filename : string, contents : string, name : string) -> *Entity {
    result : *Entity;

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