// Copyright Epic Games, Inc. All Rights Reserved.

Entity_Type :: enum {
    MESH;
    POLYLINE_SOUP2;
    POLYLINE_SOUP3;
    POLYGON_SOUP;
    UNKNOWN;
}

Entity :: struct {
    type : Entity_Type = .UNKNOWN;

    is_visible := true;
    is_visible_sweep_hovered := false;
    is_selected := false;
    is_hovered := false;

    render_info : Render_Info;
    display_info : Display_Info;
    mesh : Mesh;

    // @Incomplete
    // user_data : *void; // Registered commands may want to attach data here

    fully_pathed_filename : string;
    loaded_filetime : u64;

    // @Refactor consider keeping the fully_pathed_filename and the generation index together in a struct
    generation_index : int; // entities with the same fully pathed_filename will increment this
}

Polyline_Soup2_Entity :: struct {
    using base : Entity;
    type = .POLYLINE_SOUP2;
    display_info.element_label_theme.label_color = .{.6, .6, 0, 1}; // @Cleanup put colors in app.jai

    Shape :: Polyline_Soup2;
    shape : Shape;
}

Polyline_Soup3_Entity :: struct {
    using base : Entity;
    type = .POLYLINE_SOUP3;
    display_info.element_label_theme.label_color = .{.6, .6, 0, 1};

    Shape :: Polyline_Soup3;
    shape : Shape;
}

Polygon_Soup_Entity :: struct {
    using base : Entity;
    type = .POLYGON_SOUP;
    display_info.element_label_theme.label_color = .{1., 1., 0, 1}; // @Cleanup put colors in app.jai

    Shape :: Polygon_Soup;
    shape : Shape;
}

Mesh_Entity :: struct {
    using base : Entity;
    type = .MESH;
    display_info.element_label_theme.label_color = .{1., 1., 0, 1};

    Shape :: Mesh;
#place mesh;
    shape : Shape = ---; // Alias for consistency
}

clear :: (base : *Entity) {
    if #complete base.type == {
        case .UNKNOWN;
            // do nothing

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

        case .POLYLINE_SOUP3;

            entity := cast(*Polyline_Soup3_Entity)base;
            deinit(*entity.mesh);
            deinit(*entity.shape);

        case .POLYGON_SOUP;

            entity := cast(*Polygon_Soup_Entity)base;
            deinit(*entity.mesh);
            deinit(*entity.shape);

        case .MESH;

            entity := cast(*Mesh_Entity)base;
            deinit(*entity.mesh);
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
        case .UNKNOWN; #through;
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
        time_text = filetime_to_readable_date(loaded_filetime);
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
    entity.loaded_filetime = get_current_file_time();

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

load_entity_from_file :: (filename : string) -> *Entity {
    result : *Entity;

    if ends_with_nocase(filename, "obj") {
        result = load_obj(filename);
    } else if ends_with_nocase(filename, "wkt") {
        result = load_wkt(filename);
    }

    if result {
        log("Loaded file '%', with type %", filename, result.type);
    } else {
        log_error("Could not load file '%'", filename);
    }

    return result;
}

Point_On_Entity :: struct {
    position : Point3;
    element_index : int = -1; // Vertex or Triangle
    entity_index : int = -1;
}

// @Cleanup Add a threshold for how close you need to be to consider adding a vertex
find_closest_vertex_on_visible_entities :: () -> Point_On_Entity {

    ray := make_camera_ray();

    result : Point_On_Entity;

    dist2 := FLOAT32_INFINITY;
    for entity, entity_index : app.entities {
        if entity.is_visible {
            if entity.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity {
                for vertex, vertex_index : entity.mesh.positions {

                    front_facing_only :: true;
                    if front_facing_only && (entity.mesh.normals.count != 0) && dot(current_look_direction(), entity.mesh.normals[vertex_index]) > 0 {
                        continue;
                    }

                    p := (entity.mesh.world_from_model * make_vector4(vertex, 1.)).xyz;
                    c, d2, t := distance_point3_ray3(p, ray);

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

    ray := make_camera_ray();

    result : Point_On_Entity;

    visible_selectable_triangulated :: #bake_arguments entities_iterator(should_visit = (e) => (
            e.is_visible &&
            (e.type == .MESH || e.type == .POLYGON_SOUP) &&
            e.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity
        ));

    intersected_triangle := false;
    has_degenerate_triangles := false;
    t_min := FLOAT32_INFINITY;

    // Warning: I hit a confusing bug using a naked continue in this function when it was defined in the body of
    // an entities iterator for loop, and before the a triangles iterator for loop, this made the continue refer
    // to the entities loop, and not the triangle loop. Should be explicit with macros!
    Process_Triangle :: () #expand {
        normal_direction := compute_normal(`triangle, normalize=false);
        if normal_direction == Vector3.{0, 0, 0} {
            `has_degenerate_triangles = true;
        } else {
            if `front_facing_only && dot(current_look_direction(), normal_direction) > 0 {
                continue `triangle;
            }

            isect, t, bary, ipoint := find_intersect_ray3_triangle3(`ray, `triangle);
            if isect && t < `t_min {

                // @CompilerBug wtf, putting backticks on test_sphere compiled?
                if is_clipped(`entity.display_info, ipoint, test_sphere=`sphere_clipped, test_ranges=`range_clipped) {
                    continue `triangle;
                }

                `t_min = t;
                `result.position = ipoint;
                `result.element_index = `triangle_index;
                `result.entity_index = `entity_index;
                `intersected_triangle = true;
            }
        }
    }

    for :visible_selectable_triangulated entity, entity_index : app.entities {
        for :triangles_iterator triangle, triangle_index : entity.mesh {
            Process_Triangle();
        }
    }

    if intersected_triangle {
        return result;
    }

    d_min := FLOAT32_INFINITY;
    if (has_degenerate_triangles) {
        for :visible_selectable_triangulated entity, entity_index : app.entities {
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

                closest_point := closest_point_ray_segment(ray, segment3);
                ipoint := closest_point.closest[1];
                d := closest_point.distance;

                // @Incomplete continue if the distance is beyond a threshold?

                if d < d_min {

                    if is_clipped(entity.display_info, ipoint, test_sphere=sphere_clipped, test_ranges=range_clipped) {
                        continue;
                    }

                    d_min = d;
                    result.position = ipoint;
                    result.element_index = 0; // @Incomplete Is this properly handled? Maybe it should be the vertex index if the segment parameter is 0 or 1
                    result.entity_index = entity_index;
                }
            }
        }
    }


    visible_selectable_polyline_soup3 :: #bake_arguments entities_iterator(should_visit = (e) => (
            e.is_visible &&
            e.type == .POLYLINE_SOUP3 &&
            e.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity
        ));

    for :visible_selectable_polyline_soup3 entity, entity_index : app.entities {
        soup := cast(*Polyline_Soup3_Entity)entity;
        for :segment_iterator segment, segment_index : soup.shape {
            segment3 : Segment3;
            segment3.start = <<segment.from_point;
            segment3.end = <<segment.to_point;

            closest_point := closest_point_ray_segment(ray, segment3);
            ipoint := closest_point.closest[1];
            d := closest_point.distance;

            // @Incomplete continue if the distance is beyond a threshold?

            if d < d_min {

                if is_clipped(entity.display_info, ipoint, test_sphere=sphere_clipped, test_ranges=range_clipped) {
                    continue;
                }

                d_min = d;
                result.position = ipoint;
                result.element_index = segment_index; // @Incomplete Is this properly handled? Maybe it should be the vertex index if the segment parameter is 0 or 1
                result.entity_index = entity_index;
            }
        }
    }



    visible_selectable_polyline_soup2 :: #bake_arguments entities_iterator(should_visit = (e) => (
            e.is_visible &&
            e.type == .POLYLINE_SOUP2 &&
            e.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity
        ));

    for :visible_selectable_polyline_soup2 entity, entity_index : app.entities {
        soup := cast(*Polyline_Soup2_Entity)entity;
        for :segment_iterator segment, segment_index : soup.shape {
            segment3 : Segment3;
            segment3.start = make_vector3(segment.from_point.x, segment.from_point.y, 0.);
            segment3.end   = make_vector3(segment.to_point.x, segment.to_point.y, 0.);

            closest_point := closest_point_ray_segment(ray, segment3);
            ipoint := closest_point.closest[1];
            d := closest_point.distance;

            // @Incomplete continue if the distance is beyond a threshold?

            if d < d_min {

                if is_clipped(entity.display_info, ipoint, test_sphere=sphere_clipped, test_ranges=range_clipped) {
                    continue;
                }

                d_min = d;
                result.position = ipoint;
                result.element_index = segment_index; // @Incomplete Is this properly handled? Maybe it should be the vertex index if the segment parameter is 0 or 1
                result.entity_index = entity_index;
            }
        }
    }

    return result;
}

// Reload the entity using it's fully_pathed_filename, if loading fails clear the entity
reload_entity :: (entity : *Entity) -> *Entity {

    new_entity : *Entity = load_entity_from_file(entity.fully_pathed_filename);

    if new_entity {
        // Maintain the following information after the entity reload
        new_entity.is_visible            = entity.is_visible;
        new_entity.is_selected           = entity.is_selected;
        new_entity.display_info          = entity.display_info;
        new_entity.generation_index      = entity.generation_index;
        new_entity.mesh.world_from_model = entity.mesh.world_from_model;

        deinit(entity);

        maybe_update_render_info(*new_entity.render_info, *new_entity.mesh);

        return new_entity;
    }

    clear(entity);

    return entity;
}

num_selected_entities :: () -> int {
    count := 0;
    for :selected app.entities {
        count += 1;
    }
    return count;
}