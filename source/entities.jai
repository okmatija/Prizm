Entity_Type :: enum {
    // GENERAL_OBJ; // See what the snake example does
    MESH;
    POLYLINE_SOUP2;
    POLYLINE_SOUP3;
    POLYGON_SOUP;
    POINT_CLOUD;
    UNKNOWN;
}

// Used for entity reloading
Entity_Source :: enum {
    FILE_ON_DISK;
    PRESET_SHAPE;
    COMMAND_OUTPUT;
    UNKNOWN;
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

    // Interpretation depends on Entity_Type (I think)
    annotations : [..]Annotation;

    // @Incomplete
    // user_data : *void; // Registered commands may want to attach data here

    fully_pathed_filename : string;
    creation_time : u64;

    // @Refactor consider keeping the fully_pathed_filename and the generation index together in a struct
    generation_index : int; // entities with the same fully pathed_filename will increment this
}

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

        case .MESH;

            entity := cast(*Mesh_Entity)base;
            deinit(*entity.mesh);
            deinit(entity.spatial);
            for entity.annotations free(it.text);
            array_reset(*entity.annotations);
    }

    // Remove data from gpu memory as well
    if base.render_info.vbo glDeleteBuffers(1, *base.render_info.vbo);
    if base.render_info.ibo glDeleteBuffers(1, *base.render_info.ibo);
    base.render_info = .{};
    free(base.fully_pathed_filename);
    base = null;
}

is_empty :: (entity : Entity) -> bool {
    return entity.mesh.positions.count == 0;
}

entity_primary_color :: (using entity : *Entity) -> *Vector4 {
    if #complete type == {
        case .POLYLINE_SOUP2; return *display_info.wireframe_color;
        case .POLYLINE_SOUP3; return *display_info.wireframe_color;
        case .POLYGON_SOUP;   return *display_info.surface_color;
        case .POINT_CLOUD;    return *display_info.points_color;
        case .UNKNOWN;     #through;
        case .MESH;
            if #complete mesh.geometry_format == {
                case .POINTS;    return *display_info.points_color;
                case .LINES;     return *display_info.wireframe_color;
                case .UNKNOWN; #through;
                case .TRIANGLES; return *display_info.surface_color;
            }
    }
    return null;
}

entity_filename :: (using entity : Entity, with_generation_index : bool, with_short_filename : bool, with_loaded_time : bool) -> string {

    name_text := fully_pathed_filename;

#if OS == .WINDOWS {
    for 0..name_text.count-1 {
        if name_text[it] == #char "\\" name_text[it] = #char "/";
    }
}

    if with_short_filename {
        push_allocator(temp);
        path := parse_path(fully_pathed_filename);
        if path.words.count {
            name_text = path.words[path.words.count - 1];
        }
    }

    index_text := "";
    if generation_index != 0 && with_generation_index {
        index_text = tprint(" <%>", generation_index);
    }

    time_text := "";
    time_separator := "";
    if with_loaded_time {
        time_text = filetime_to_readable_date(creation_time);
        time_separator = " @ ";
    }

    return tprint("%1%2%3%4", name_text, index_text, time_separator, time_text);
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

init_entity_base_parameters :: (entity : *Entity, filename : string, mesh : Mesh, loc := #caller_location) {
    if !entity return;

    entity.fully_pathed_filename = copy_string(filename);
    entity.creation_time = get_current_file_time();

    if #complete mesh.geometry_format == {
        case .LINES;

            entity.mesh = mesh;
            entity.display_info.wireframe_visible = true;
            entity.display_info.wireframe_width = 1;
            entity.display_info.wireframe_color = color_from_path(filename);

        case .TRIANGLES;

            entity.mesh = mesh;
            entity.display_info.surface_visible = true;
            entity.display_info.surface_color = color_from_path(filename);

        case .POINTS;

            entity.mesh = mesh;
            entity.display_info.surface_visible = true;
            entity.display_info.points_visible = true;
            entity.display_info.points_size = 2;
            entity.display_info.points_color = color_from_path(filename);

        case .UNKNOWN;

            log_warning("Unexpected unknown geometry format in init_entity_base_parameters, called from %", loc);
    }
}



// Returns the entity having the given `fully_pathed_filename` with maximum generation index, or null if no such entity exists
find_entity_with_max_generation_index :: (fully_pathed_filename : string) -> *Entity, int
{
    entity_index := -1;
    max_generation_index := -1;
    max_generation_index_entity : *Entity;
    for app.entities {
        if it.fully_pathed_filename == fully_pathed_filename && it.generation_index > max_generation_index {
            max_generation_index = it.generation_index;
            max_generation_index_entity = it;
            entity_index = it_index;
        }
    }
    return max_generation_index_entity, entity_index;
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

load_one_file :: (filename : string, matching_name_behaviour : Duplicate_File_Behaviour = .APPEND) -> *Entity {
    contents := read_entire_file(filename);
    defer free(contents);

    return load_one_file_from_memory(filename, contents, matching_name_behaviour);
}

load_one_file_from_memory :: (filename : string, contents : string, matching_name_behaviour : Duplicate_File_Behaviour = .APPEND) -> *Entity {
    if !contents {
        log_warning("Skipped file: '%' (empty or missing)\n", filename);
        return null;
    }

    found, found_index := find_entity_with_max_generation_index(filename);
    if found {
        if #complete matching_name_behaviour == {
            case .IGNORE;

                log_warning("Skipped file: '%' (already loaded)\n", filename);

            case .OVERWRITE;

                // Only affects the entity with maximum generation index
                entity := load_entity_from_memory(filename, contents);
                if entity {
                    entity.generation_index = found.generation_index;
                    entity.display_info = found.display_info;
                    deinit(found);
                    app.entities[found_index] = entity;
                    return entity;
                }

            case .APPEND;

                entity := load_entity_from_memory(filename, contents);
                if entity {
                    entity.generation_index = found.generation_index + 1;
                    array_add(*app.entities, entity);
                    return entity;
                }
        }
    } else {
        entity := load_entity_from_memory(filename, contents);
        if entity {
            array_add(*app.entities, entity);
            return entity;
        }
    }

    return null;
}

// @Incomplete pass Duplicate_File_Behaviour 
// Reload the entity using it's fully_pathed_filename, if loading fails clear the entity
reload_entity :: (entity : *Entity) -> *Entity {

    if entity.source != .FILE_ON_DISK {
        log("Skipped reloading item '%' as it has source type %. Only items with source type % can be reloaded (for now.. @Incomplete)", entity.fully_pathed_filename, entity.source, Entity_Source.FILE_ON_DISK);
        return entity;
    }

    log("Reloading file '%'... ", entity.fully_pathed_filename);

    contents := read_entire_file(entity.fully_pathed_filename);
    defer free(contents);

    new_entity : *Entity = load_entity_from_memory(entity.fully_pathed_filename, contents);

    if new_entity {
        // Maintain the following information after the entity reload
        new_entity.is_selected =           entity.is_selected;
        new_entity.display_info =          entity.display_info;
        new_entity.generation_index =      entity.generation_index;
        new_entity.mesh.world_from_model = entity.mesh.world_from_model;

        deinit(entity);

        maybe_update_render_info(*new_entity.render_info, *new_entity.mesh);

        return new_entity;
    }

    clear(entity);

    return entity;
}

#scope_file

load_entity_from_memory :: (filename : string, contents : string) -> *Entity {
    result : *Entity;

    if ends_with_nocase(filename, "obj") {
        result = load_obj(filename, contents);
    } else if ends_with_nocase(filename, "wkt") {
        result = load_wkt(filename, contents);
    }

    if result {
        log("Loaded file '%', with type %", filename, result.type);
    } else {
        log_error("Could not load file '%'", filename);
    }

    return result;
}