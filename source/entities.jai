// Copyright Epic Games, Inc. All Rights Reserved.

Entity_Type :: enum {
    UNKNOWN;
    POLYLINE_SOUP2;
    POLYLINE_SOUP3;
    POLYGON_SOUP;
    MESH;
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

    using_default_vertex_label_style : bool = true;
    fully_pathed_filename : string;
    loaded_filetime : u64;
    generation_index : int; // entities with the same fully pathed_filename will increment this
}

Polyline_Soup2_Entity :: struct {
    using base : Entity;
    type = .POLYLINE_SOUP2;

    shape : Polyline_Soup2;
}

Polyline_Soup3_Entity :: struct {
    using base : Entity;
    type = .POLYLINE_SOUP3;

    shape : Polyline_Soup3;
}

Polygon_Soup_Entity :: struct {
    using base : Entity;
    type = .POLYGON_SOUP;

    shape : Polygon_Soup;
}

Mesh_Entity :: struct {
    using base : Entity;
    type = .MESH;
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
        Push_Temporary();
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

    n := get_hash(to_hash);
    m := get_hash(n);

    h := (cast(float)(n % 257) / 256);
    s := 1.;
    v := (cast(float)(m % 257) / 256) * .3 + .7;

    r, g, b : float;
    ImGui.ColorConvertHSVtoRGB(h, s, v, *r, *g, *b);

    return make_vector4(r, g, b, 1.);
}

init_entity_base_parameters :: (entity : *Entity, filename : string, mesh : Mesh) {
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

            log("Skipped (Could not detect mesh geometry format)\n");
            deinit(entity);
    }
}

load_entity_from_file :: (filename : string) -> *Entity {
    result : *Entity;

    // if ends_with(filename, "obj") {
    //     result = load_obj(filename);
    // }

    return result;
}

Closest_Vertex_On_Entity :: struct {
    vertex_position : Point3;
    vertex_index : int = -1;
    entity_index : int = -1;
}

find_closest_vertex_on_visible_entities :: () -> Closest_Vertex_On_Entity {

    view_from_clip := inverse(make_orthographic_projection_matrix(app.camera));
    world_from_view := inverse(make_look_at_matrix(app.camera));
    transform := world_from_view * view_from_clip;
    inverse_transpose := transpose(inverse(transform));

    ray : Ray3 = ---;
    ray.origin = (transform * make_vector4(to_ndc(make_Vector2(io().MousePos)), -1., 1.)).xyz;
    ray.direction = (inverse_transpose * make_vector4(0., 0., 1., 0.)).xyz;
    check := normalize_or_zero(*ray.direction);
    assert(check != 0.); // @Robustness: handle this error

    result : Closest_Vertex_On_Entity;

    dist2 := FLOAT32_INFINITY;
    for entity, entity_index : app.entities {
        if entity.is_visible {
            if entity.mesh.positions.count <= app.user_selection_max_point_count_for_selectable_entity {
                for vertex, vertex_index : entity.mesh.positions {
                    p := (entity.mesh.world_from_model * make_vector4(vertex, 1.)).xyz;
                    c, d2, t := distance_point3_ray3(p, ray);
                    if d2 < dist2 {
                        dist2 = d2;
                        result.vertex_position = p;
                        result.vertex_index = vertex_index;
                        result.entity_index = entity_index;
                    }
                }

                if result.vertex_index != -1 for clip : entity.display_info.clip_ranges if clip.is_active {
                    plane := make_hyperplane3(clip.normal, Vector3.{0, 0, 0});
                    dist := signed_distance_point3_plane3(result.vertex_position, plane);
                    if (dist <= clip.min || dist >= clip.max) {
                        ini :: initializer_of(type_of(result));
                        ini(*result);
                    }
                }
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