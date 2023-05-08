// Procedures tagged with @RegisterCommand will have their documentation appear
// in the console when the user calls `help <command-name>`. Every line starting
// with // above the procedure will be included in the documentation
//
// It's clearer for users if explicit types are put in function argument lists
//
// Note the advice from how_to/500_use_of_compile_time_execution.jai:
//
//    If you generate code once and then
//    it will be fixed for the rest of the project, we encourage you to copy that
//    code out of the .added_strings file into an input source file, and to comment out
//    the execution.
//
// Maybe we should do that for commands which have proven to be useful for a long time, for example

// @Think Check if @RegisterCommand procedures are using this function, and not valid_geometry_index
check_geometry_index :: (index : int) -> bool #must {
    if index < 0 || index >= app.entities.count {
        log_error("Invalid/Out-of-range geometry index, expected integer in range [0, %]", app.entities.count - 1);
        return false;
    }
    return true;
}

check_color :: (r : int, g : int, b : int, a : int) -> bool #must {
    if r < 0 || r > 255 {
        log_error("# Expected r to be in the range [0, 255], got %", r);
        return false;
    }

    if g < 0 || g > 255 {
        log_error("# Expected g to be in the range [0, 255], got %", g);
        return false;
    }

    if b < 0 || b > 255 {
        log_error("# Expected b to be in the range [0, 255], got %", b);
        return false;
    }

    if a < 0 || a > 255 {
        log_error("# Expected a to be in the range [0, 255], got %", a);
        return false;
    }

    return true;
}

// Like check_geometry_index but with no logging
valid_geometry_index :: (index : int) -> bool #must {
    if index < 0 || index >= app.entities.count {
        return false;
    }
    return true;
}

// Close the application
quit :: () {
    app.closing_application = true;
} @RegisterCommand

// Load files found in the given path as if it was provided to the Prism executable on the command line.
// The path may contain * wildcards for matching filenames but not directories (this will be implemented in future)
load :: (path : string) {
    count := app.entities.count;
    handle_load_string(path); 
    loaded_count := app.entities.count - count;
    log("Loaded % item%", loaded_count, plural_suffix(loaded_count != 1));
} @RegisterCommand

// Print the path containing the running Prism executable
// Handy to know this if you want to pass a relative path to the `load` function
pwd :: () {
    log(path_strip_filename(get_path_of_running_executable()));
} @RegisterCommand

debug_toggle_fps :: () {
    app.show_fps = !app.show_fps;
} @RegisterCommand

// Clear annotations and then fake ones to the item with the given id
debug_fake_annotations :: (id : int) {
    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(id) {
        return;
    }

    item := app.entities[id];
    array_reset_keeping_memory(*item.vertex_annotations);
    array_reset_keeping_memory(*item.line_annotations);
    array_reset_keeping_memory(*item.face_annotations);

    if item.mesh.positions.count > 0 {
        for item.mesh.positions {
            annotation : Annotation;
            annotation.kind = .VERTEX;
            set(*annotation.value, sprint("vertex %", it_index));
            annotation.id = it_index;
            array_add(*item.vertex_annotations, annotation);
        }

        log("# Cleared vertex annotations and added fake ones");
    }

    if item.mesh.segments.count > 0 {
        for :SegmentTupleIterator item.mesh {
            annotation : Annotation;
            annotation.kind = .LINE;
            set(*annotation.value, random_get_zero_to_one());
            annotation.id = it_index;
            array_add(*item.line_annotations, annotation);
        }

        log("# Cleared segments annotations and added fake ones");
    }

    if item.mesh.triangles.count > 0 {
        for :TriangleTupleIterator item.mesh {
            annotation : Annotation;
            annotation.kind = .TRIANGLE;
            set(*annotation.value, random_get_zero_to_one());
            annotation.id = it_index;
            array_add(*item.face_annotations, annotation);
        }

        log("# Cleared triangle annotations and added fake ones");
    }

} @RegisterCommand

// Show the history of console commands
console_history :: () {
    console_log_clear();
    for app.console.history log("# % %", it_index, it);
} @RegisterCommand

// Lists all available commands and displays a help message
help :: () {
    log("# % available commands:", app.console.commands.count);
    for app.console.commands {
        log("#  %", it.usage);
    }
} @RegisterCommand

select_if :: (should_select : (Entity)->bool, invert : int) {
    count := 0;
    for :All app.entities {
        if should_select(it) == (invert == 0) {
            it.is_selected = true;
            count += 1;
        }
    }
    if count == 1 log("# selected 1 entity");
    else          log("# selected % entities", count);
}

// Add items with/without position data to the selection, if `invert` is true/false
select_if_empty :: (invert : int = 0) {
    select_if((e)=>(is_empty(e.mesh)), invert);
} @RegisterCommand

// @CompilerBug By passing *void data to the should_select procedure we could use the generic version above

// Add items with names that match/dont match (`invert` is true/false) the given `pattern` to the selection 
// The following wildcards/regex patterns are supported: * ? [] [-]
select_if_match :: (pattern : string, invert : int = 0) {
    count := 0;
    for :All app.entities {
        // Note: We use entity_name here, we could have used the fully pathed filename but then you need to prefix with a * always
        text : string = entity_name(it);
        if wildcard_match(text, pattern) == (invert == 0) {
            it.is_selected = true;
            count += 1;
        }
    }
    if count == 1 log("# selected 1 entity");
    else          log("# selected % entities", count);
} @RegisterCommand

// Sorts items in alphabetical order
sort_by_name :: (reversed : int = 0) {
    compare_alphabetical :: (a : *Entity, b : *Entity) -> s64 {
        return compare_nocase(entity_name(a), entity_name(b));
    }

    compare_reverse_alphabetical :: (a : *Entity, b : *Entity) -> s64 {
        return compare_nocase(entity_name(b), entity_name(a));
    }

    if   reversed quick_sort(app.entities, compare_reverse_alphabetical);
    else          quick_sort(app.entities, compare_alphabetical);
} @RegisterCommand

// Sorts items using the load timestamp
sort_by_time :: (ascending : int = 1) {
    compare_ascending :: (a : *Entity, b : *Entity) -> s64 {
        // @Cleanup This is a pretty weird way to do this...
        at := filetime_to_readable_date(get_entity_source(a).creation_time);
        bt := filetime_to_readable_date(get_entity_source(b).creation_time);
        if at == bt return compare_nocase(entity_name(b), entity_name(a));
        return compare_nocase(bt, at);
    }

    compare_descending :: (a : *Entity, b : *Entity) -> s64 {
        // @Cleanup This is a pretty weird way to do this...
        at := filetime_to_readable_date(get_entity_source(a).creation_time);
        bt := filetime_to_readable_date(get_entity_source(b).creation_time);
        if at == bt return compare_nocase(entity_name(a), entity_name(b));
        return compare_nocase(at, bt);
    }

    if   ascending quick_sort(app.entities, compare_ascending);
    else           quick_sort(app.entities, compare_descending);
} @RegisterCommand

// Sorts items using the number of points in the mesh, falling back to sorting by filename
sort_by_size :: (ascending : int = 1) {
    compare_ascending :: (a : *Entity, b : *Entity) -> s64 {
        if a.mesh.positions.count == b.mesh.positions.count {
            return compare_nocase(entity_name(a), entity_name(b));
        }
        return compare_floats(xx a.mesh.positions.count, xx b.mesh.positions.count);
    }

    compare_descending :: (a : *Entity, b : *Entity) -> s64 {
        if a.mesh.positions.count == b.mesh.positions.count {
            return compare_nocase(entity_name(b), entity_name(a));
        }
        return compare_floats(xx b.mesh.positions.count, xx a.mesh.positions.count);
    }

    if   ascending quick_sort(app.entities, compare_ascending);
    else           quick_sort(app.entities, compare_descending);
} @RegisterCommand

// Clears the item with the given `id` (resets geometry data containers)
item_clear :: (id : int) {
    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(id) {
        return;
    }

    item := app.entities[id];
    point_count := item.mesh.positions.count;
    clear(item);

    log("# Cleared item #% which had % points", id, point_count);
} @RegisterCommand

// Clears the point element container (e.g., p-directive in .obj files), for then item with the given `id`
item_clear_points :: (id : int) {
    if !check_geometry_index(id) {
        return;
    }

    item := app.entities[id];
    count := item.mesh.points.count;
    array_reset(*item.mesh.points);

    log("# Cleared item #% which had % points", id, count);
} @RegisterCommand

// Clears the segments (e.g., l-directive in .obj files) from the item with the given `id`
item_clear_segments :: (id : int) {
    if !check_geometry_index(id) {
        return;
    }

    item := app.entities[id];
    count := item.mesh.segments.count;
    array_reset(*item.mesh.segments);

    log("# Cleared item #% which had % segments", id, count);
} @RegisterCommand

// Clears the triangles (e.g., l-directive in .obj files) from the item with the given `id`
item_clear_triangles :: (id : int) {
    if !check_geometry_index(id) {
        return;
    }

    item := app.entities[id];
    count := item.mesh.triangles.count;
    array_reset(*item.mesh.triangles);

    log("# Cleared item #% which had % triangles", id, count);
} @RegisterCommand

// Flip normals in the mesh item with the given `id`
// Reverses the winding of triangles and multiplies vertex normals by -1
item_flip_normals :: (id : int) {
    if !check_geometry_index(id) {
        return;
    }

    entity := app.entities[id];

    // @Incomplete Transform attributes

    for * entity.mesh.normals {
        <<it *= -1;
    }

    for i : 0..entity.mesh.triangles.count-1 {
        using entity.mesh;
        tuple : *Tuple3(u32) = *triangles[i];
        tuple.y, tuple.z = swap(tuple.y, tuple.z);
    }

    entity.render_info.is_dirty = true;
} @RegisterCommand


// Set the color of the highest-dimensional element (triangle > segment > point) in the given item's mesh
set_primary_color :: (id : int, r : int, g : int, b : int, a : int = 255) {
    if !check_geometry_index(id) return;
    if !check_color(r, g, b, a)  return;
    entity := app.entities[id];
    color, visible := get_entity_primary_color(entity);
    <<color = Vector4.{r / 255., g / 255., b / 255., a / 255.};
} @RegisterCommand




// visible is a boolean
set_visible :: (id : int, visible : int) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.is_visible = xx visible;
} @RegisterCommand




// visible is a boolean
set_annotations_visible :: (id : int, visible : int) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.annotation_label_theme.visible = xx visible;
} @RegisterCommand

set_annotations_color :: (id : int, r : int, g : int, b : int, a : int = 255) {
    if !check_geometry_index(id) return;
    if !check_color(r, g, b, a)  return;
    entity := app.entities[id];
    entity.display_info.annotation_label_theme.label_color = Vector4.{r / 255., g / 255., b / 255., a / 255.};
} @RegisterCommand

// The scale parameter is in the range [0.2, 1.0], by default Prism uses 0.4 @Cleanup Switch to size in pixels
set_annotations_scale :: (id : int, scale : float) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.annotation_label_theme.label_scale = scale;
} @RegisterCommand




// visible is a boolean
set_vertex_index_labels_visible :: (id : int, visible : int) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.vertex_label_theme.show_index = xx visible;
} @RegisterCommand

// visible is a boolean
set_vertex_position_labels_visible :: (id : int, visible : int) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.vertex_label_theme.show_position = xx visible;
} @RegisterCommand

set_vertex_label_color :: (id : int, r : int, g : int, b : int, a : int = 255) {
    if !check_geometry_index(id) return;
    if !check_color(r, g, b, a)  return;
    entity := app.entities[id];
    entity.display_info.vertex_label_theme.label_color = Vector4.{r / 255., g / 255., b / 255., a / 255.};
} @RegisterCommand

// The scale parameter is in the range [0.2, 1.0], by default Prism uses 0.4 @Cleanup Switch to size in pixels
set_vertex_label_scale :: (id : int, scale : float) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.vertex_label_theme.label_scale = scale;
} @RegisterCommand




// visible is a boolean
set_point_index_labels_visible :: (id : int, visible : int) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.point_label_theme.show_index = xx visible;
} @RegisterCommand

set_point_label_color :: (id : int, r : int, g : int, b : int, a : int = 255) {
    if !check_geometry_index(id) return;
    if !check_color(r, g, b, a)  return;
    entity := app.entities[id];
    entity.display_info.point_label_theme.label_color = Vector4.{r / 255., g / 255., b / 255., a / 255.};
} @RegisterCommand

// The scale parameter is in the range [0.2, 1.0], by default Prism uses 0.4 @Cleanup Switch to size in pixels
set_point_label_scale :: (id : int, scale : float) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.point_label_theme.label_scale = scale;
} @RegisterCommand




// visible is a boolean
set_segment_index_labels_visible :: (id : int, visible : int) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.segment_label_theme.show_index = xx visible;
} @RegisterCommand

set_segment_label_color :: (id : int, r : int, g : int, b : int, a : int = 255) {
    if !check_geometry_index(id) return;
    if !check_color(r, g, b, a)  return;
    entity := app.entities[id];
    entity.display_info.segment_label_theme.label_color = Vector4.{r / 255., g / 255., b / 255., a / 255.};
} @RegisterCommand

// The scale parameter is in the range [0.2, 1.0], by default Prism uses 0.4 @Cleanup Switch to size in pixels
set_segment_label_scale :: (id : int, scale : float) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.segment_label_theme.label_scale = scale;
} @RegisterCommand




// visible is a boolean
set_triangle_index_labels_visible :: (id : int, visible : int) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.triangle_label_theme.show_index = xx visible;
} @RegisterCommand

set_triangle_label_color :: (id : int, r : int, g : int, b : int, a : int = 255) {
    if !check_geometry_index(id) return;
    if !check_color(r, g, b, a)  return;
    entity := app.entities[id];
    entity.display_info.triangle_label_theme.label_color = Vector4.{r / 255., g / 255., b / 255., a / 255.};
} @RegisterCommand

// The scale parameter is in the range [0.2, 1.0], by default Prism uses 0.4 @Cleanup Switch to size in pixels
set_triangle_label_scale :: (id : int, scale : float) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.triangle_label_theme.label_scale = scale;
} @RegisterCommand



// visible is a boolean
set_vertices_visible :: (id : int, visible : int) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.positions_visible = xx visible;
} @RegisterCommand

set_vertices_color :: (id : int, r : int, g : int, b : int, a : int = 255) {
    if !check_geometry_index(id) return;
    if !check_color(r, g, b, a)  return;
    entity := app.entities[id];
    entity.display_info.positions_color = Vector4.{r / 255., g / 255., b / 255., a / 255.};
} @RegisterCommand

set_vertices_size :: (id : int, size : int = 4) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.positions_size = xx size;
} @RegisterCommand



// You probably want to use the set_vertices_visible function
// visible is a boolean
set_points_visible :: (id : int, visible : int) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.points_visible = xx visible;
} @RegisterCommand

// You probably want to use the set_vertices_color function
set_points_color :: (id : int, r : int, g : int, b : int, a : int = 255) {
    if !check_geometry_index(id) return;
    if !check_color(r, g, b, a)  return;
    entity := app.entities[id];
    entity.display_info.points_color = Vector4.{r / 255., g / 255., b / 255., a / 255.};
} @RegisterCommand

// You probably want to use the set_vertices_size function
set_points_size :: (id : int, size : int = 4) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.points_size = xx size;
} @RegisterCommand



// visible is a boolean
set_segments_visible :: (id : int, visible : int) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.segments_visible = xx visible;
} @RegisterCommand

set_segments_color :: (id : int, r : int, g : int, b : int, a : int = 255) {
    if !check_geometry_index(id) return;
    if !check_color(r, g, b, a)  return;
    entity := app.entities[id];
    entity.display_info.segments_color = Vector4.{r / 255., g / 255., b / 255., a / 255.};
} @RegisterCommand

set_segments_width :: (id : int, width : float = 1.) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.segments_width = width;
} @RegisterCommand



// visible is a boolean
set_triangles_visible :: (id : int, visible : int) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.triangles_visible = xx visible;
} @RegisterCommand

set_triangles_color :: (id : int, r : int, g : int, b : int, a : int = 255) {
    if !check_geometry_index(id) return;
    if !check_color(r, g, b, a)  return;
    entity := app.entities[id];
    entity.display_info.triangles_color = Vector4.{r / 255., g / 255., b / 255., a / 255.};
} @RegisterCommand



// visible is a boolean
set_edges_visible :: (id : int, visible : int) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.edges_visible = xx visible;
} @RegisterCommand

set_edges_color :: (id : int, r : int, g : int, b : int, a : int = 255) {
    if !check_geometry_index(id) return;
    if !check_color(r, g, b, a)  return;
    entity := app.entities[id];
    entity.display_info.edges_color = Vector4.{r / 255., g / 255., b / 255., a / 255.};
} @RegisterCommand

set_edges_width :: (id : int, width : float = 1.) {
    if !check_geometry_index(id) return;
    entity := app.entities[id];
    entity.display_info.edges_width = width;
} @RegisterCommand


// @TODO It would be handy to support varargs/arrays for the target_ids for the following functions

// Copy the clipping ranges of item `source_id` to item `target_id`
item_copy_clipping_ranges :: (source_id : int, target_id : int) {
    if !check_geometry_index(source_id) || !check_geometry_index(target_id) || source_id == target_id {
        return;
    }

    app.entities[target_id].display_info.clip_ranges = app.entities[source_id].display_info.clip_ranges;
} @RegisterCommand

// Copy the clipping sphere of item `source_id` to item `target_id`
item_copy_clipping_sphere :: (source_id : int, target_id : int) {
    if !check_geometry_index(source_id) || !check_geometry_index(target_id) || source_id == target_id {
        return;
    }

    app.entities[target_id].display_info.clip_sphere = app.entities[source_id].display_info.clip_sphere;
} @RegisterCommand

// Sets the edge/wireframe color to the face/surface color for all items
set_edge_color_to_face_color :: () {
    for :All app.entities {
        it.display_info.segments_color = it.display_info.triangles_color;
    }
} @RegisterCommand


// Update the camera to focus on the given segment. The current look direction is preserved and the
// orbit/look position of the camera is positioned on the segment centroid.
//
// `id`             The index of the item containing the desired segment
// `segment_index`  The segment that should be focussed
// `clip_radius`    If  < 0 then the items clipping sphere is unchanged (default)
//                  If == 0 then the items clipping sphere is set with a radius equal to 2x the bounding radius of the segment
//                  If  > 0 then the items clipping sphere is set with a radius of the given value
//
// If a clipping sphere is set then segment index text is also enabled
item_focus_segment :: (id : int, segment_index : int, clip_radius : float = -1.) {

    if !check_geometry_index(id) {
        return;
    }

    entity := app.entities[id];

    sphere : Sphere;

    if entity.mesh.segments.count == 0 {
        log("# Mesh contains no segments.");
        return;
    }

    {
        sid_max := entity.mesh.segments.count - 1;
        if segment_index < 0 || segment_index > sid_max {
            log_error("Expected a segment index in the range [0, %], got %.", sid_max, segment_index);
            return;
        }

        segment := mesh_segment3_model(entity.mesh, segment_index);
        sphere.center = (segment.start + segment.end) / 2;
        sphere.radius = 2 * distance(segment.start, segment.end);
    }

    sphere.center = transform_point(entity.mesh.world_from_model, sphere.center);

    if clip_radius > 0 {
        sphere.radius = clip_radius;
    }

    if clip_radius >= 0 {
        entity.display_info.segment_label_theme.show_index = true;
    }

    apply_focus(clip_radius, sphere, entity);

} @RegisterCommand

// Update the camera to focus on the given triangle. The current look direction is preserved and the
// orbit/look position of the camera is positioned on the triangle centroid.
//
// `id`             The index of the item containing the desired triangle
// `triangle_index` The triangle that should be focussed
// `clip_radius`    If  < 0 then the items clipping sphere is unchanged (default)
//                  If == 0 then the items clipping sphere is set with a radius equal to 2x the bounding radius of the triangle
//                  If  > 0 then the items clipping sphere is set with a radius of the given value
//
// If a clipping sphere is set then triangle index text is also enabled
item_focus_triangle :: (id : int, triangle_index : int, clip_radius : float = -1.) {

    if !check_geometry_index(id) {
        return;
    }

    entity := app.entities[id];

    if entity.mesh.triangles.count == 0 {
        log("# Mesh contains no triangles.");
        return;
    }

    tid_max := entity.mesh.triangles.count - 1;
    if triangle_index < 0 || triangle_index > tid_max {
        log_error("Expected a triangle index in the range [0, %], got %.", tid_max, triangle_index);
        return;
    }

    tri_world : Triangle3 = mesh_triangle_world(entity.mesh, triangle_index);

    sphere : Sphere;
    sphere.center = compute_centroid(tri_world);

    if clip_radius <= 0 {
        sphere.radius = distance(sphere.center, tri_world.a);
        sphere.radius = max(sphere.radius, distance(sphere.center, tri_world.b));
        sphere.radius = max(sphere.radius, distance(sphere.center, tri_world.c));
        sphere.radius *= 2;
    } else {
        sphere.radius = clip_radius;
        entity.display_info.triangle_label_theme.show_index = true;
    }

    if clip_radius >= 0 {
        entity.display_info.triangle_label_theme.show_index = true;
    }

    apply_focus(clip_radius, sphere, entity);

} @RegisterCommand

// Update the camera to focus on the given vertex. The current look direction is preserved and the
// orbit/look position of the camera is positioned on the vertex.
//
// `id`           The index of the item containing the desired vertex
// `vertex_index` The vertex that should be focussed
// `clip_radius`  If  < 0 then the items clipping sphere is unchanged (default)
//                If == 0 then the items clipping sphere is set to 1
//                If  > 0 then the items clipping sphere is set with a radius of the given value
//
// If a clipping sphere is set then vertex index text is also enabled
item_focus_vertex :: (id : int, vertex_index : int, clip_radius : float = -1.) {

    if !check_geometry_index(id) {
        return;
    }

    entity := app.entities[id];

    sphere : Sphere;

    {
        vid_max := entity.mesh.positions.count - 1;
        if vertex_index < 0 || vertex_index > vid_max {
            log_error("Expected a vertex index in the range [0, %], got %.", vid_max, vertex_index);
            return;
        }
        sphere.center = entity.mesh.positions[vertex_index];
    }

    sphere.center = transform_point(entity.mesh.world_from_model, sphere.center);

    if clip_radius <= 0 {
        sphere.radius = 1;
    } else {
        sphere.radius = clip_radius;
    }

    if clip_radius >= 0 {
        entity.display_info.vertex_label_theme.show_index = true;
    }

    apply_focus(clip_radius, sphere, entity);

} @RegisterCommand

// // Adds an item containing a soup of edges belonging to only one triangle in the mesh item with the given `id`
// item_make_centroid_point_cloud :: (id : int) {
//     // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
//     if !check_geometry_index(id) {
//         return;
//     }

//     if app.entities[id].type != .MESH {
//         log_error("Expected MESH type item, got %.", app.entities[id].type);
//         return;
//     }

// } @RegisterCommand

// Adds an item containing a soup of segments indicating the normals
item_make_normals_segment_soup :: (id : int) {
    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(id) {
        return;
    }

    entity : *Entity = app.entities[id];
    mesh : Simple_Mesh = entity.mesh;
    vn : *Simple_Mesh_Normals = find_mesh_attribute(entity, "vn", Simple_Mesh_Normals);
    if vn == null {
        log("# Mesh has no normals.");
        return;
    }

    new_mesh : Simple_Mesh;
    for vn.values { // it has type Matrix3, it_index is the triangle index
        triangle : Triangle3 = mesh_triangle_world(mesh, it_index);
        for i : 0..2 {
            segment := Segment3.{start=triangle.v[i], end=triangle.v[i] + it.v[i]};
            add_segment(*new_mesh, segment);
        }
    }

    // Add a new item
    new_entity := New(Entity);
    new_entity.mesh = new_mesh;
    set_entity_source_from_command(new_entity, tprint("%_normals", entity_name(entity)), app.console.history[app.console.history.count - 1], mesh.positions.count);
    set_entity_display_info(new_entity);

    maybe_update_render_info(*new_entity.render_info, *new_entity.mesh); // @Cleanup fishy, why do we do this
    new_entity.display_info.segments_width = 3;

    // Set generation_index before adding to overwrite the correct entity // @Cleanup fishy
    new_entity.generation_index = entity.generation_index;
    add_entity(new_entity, .OVERWRITE);

    // log("# Added % edge% to the new item '%'",
    //     new_mesh.segments.count,
    //     plural_suffix(new_mesh.segments.count > 1),
    //     entity_name(new_entity));
} @RegisterCommand


// Finds triangle edges which are not shared by two triangles in the item with the given `id`
// If `new_item` is 0 the edges are added to the target item segments container
// If `new_item` is 1 adds an item containing a segment soup with the given `id`
item_find_open_edges :: (id : int, new_item : int = 0) {
    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(id) {
        return;
    }

    edge_hash :: (e : Tuple2(u32)) -> u32 {
        if e.x < e.y {
            return get_hash(e.component);
        } else {
            return get_hash(make_Tuple2(e.y, e.x).component);
        }
    }

    edge_comp :: (a : Tuple2(u32), b : Tuple2(u32)) -> bool {
        if a == b return true;
        if a == make_Tuple2(b.y, b.x) return true;
        return false;
    }

    edge_to_origin : Table(Tuple2(u32), s64, edge_hash, edge_comp);
    defer deinit(*edge_to_origin);

    entity : *Entity = app.entities[id];
    mesh : *Simple_Mesh = *entity.mesh;
    if mesh.triangles.count == 0 {
        log("# Mesh contains no triangles.");
        return;
    }

    for :TriangleTupleIterator mesh {
        Process_Edge :: (i : u32, j : u32) #expand {
            edge := make_Tuple2(i, j);
            value, found := table_find(*edge_to_origin, edge);
            if found {
                table_remove(*edge_to_origin, edge);
            } else {
                origin := edge.x;
                table_add(*edge_to_origin, edge, origin);
            }
        }

        Process_Edge(it.component[0], it.component[1]);
        Process_Edge(it.component[1], it.component[2]);
        Process_Edge(it.component[2], it.component[0]);
    }

    if edge_to_origin.count == 0 {
        log("# No boundary edges detected");
        return;
    }

    // Collect the segment soup @Incomplete weld/stitch polyline segments together
    polyline_soup : Polyline_Soup3;
    for origin, edge : edge_to_origin {
        segment := array_add(*polyline_soup.polylines);
        // Copy model space coordinates because the transform is encoded separately
        array_add(*segment.points, mesh_position_model(mesh, edge.x));
        array_add(*segment.points, mesh_position_model(mesh, edge.y));
    }
    new_mesh : Simple_Mesh = to_Mesh(polyline_soup);
    new_mesh.world_from_model = mesh.world_from_model;

    if new_item {
        assert(app.console.history.count > 0);

        // Add a new item
        new_entity := New(Entity);
        new_entity.mesh = new_mesh;
        set_entity_source_from_command(new_entity, tprint("%_open_edges", entity_name(entity)), app.console.history[app.console.history.count - 1], mesh.positions.count);
        set_entity_display_info(new_entity);

        maybe_update_render_info(*new_entity.render_info, *new_entity.mesh); // @Cleanup fishy, why do we do this
        new_entity.display_info.segments_width = 3;

        // Set generation_index before adding to overwrite the correct entity // @Cleanup fishy
        new_entity.generation_index = entity.generation_index;
        add_entity(new_entity, .OVERWRITE);

        log("# Added % edge% to the new item '%'",
            new_mesh.segments.count,
            plural_suffix(new_mesh.segments.count > 1),
            entity_name(new_entity));
    } else {

        merge(mesh, new_mesh);

        entity.render_info.is_dirty = true;
        entity.display_info.segments_visible = true;

        log("# Added % edge% to the target item '%'",
            new_mesh.segments.count,
            plural_suffix(new_mesh.segments.count > 1),
            entity_name(entity));
    }

} @RegisterCommand


// Finds any positions (eg obj file v-directives) which are not referenced by any element (eg p-, l- or f-directives) and explicitly add them as point elements.
// This is useful when inspecting position/element labels because for efficiency the ray-cast queries involved only visit elements
item_find_unreferenced_positions :: (id : int, new_item : int = 0) {
    if !check_geometry_index(id) {
        return;
    }

    using entity : *Entity = app.entities[id];

    // Init with all possible position indices
    unreferenced_positions : [..]u32;
    defer array_free(unreferenced_positions);
    array_resize(*unreferenced_positions, mesh.positions.count);
    for * unreferenced_positions { <<it = xx it_index; }

    // Remove the indices which are reference by an element
    for position_index : unreferenced_positions {
        for index : mesh.points {
            if index == position_index {
                remove position_index;   // This position is not unreferenced
                continue position_index; // We don't need to keep checking this position_index
            }
        }

        for tuple : mesh.segments {
            for index : tuple.component if index == position_index {
                remove position_index;   // This position is not unreferenced
                continue position_index; // We don't need to keep checking this position_index
            }
        }

        for tuple : mesh.triangles {
            for index : tuple.component if index == position_index {
                remove position_index;   // This position is not unreferenced
                continue position_index; // We don't need to keep checking this position_index
            }
        }
    }

    for position_index : unreferenced_positions {
        point_index : *u32 = array_add(*entity.mesh.points);
        <<point_index = position_index;
    }

    if unreferenced_positions.count {
        log("# Found % unreferenced positions, which were added to the meshes point element array", unreferenced_positions.count);
        entity.render_info.is_dirty = true;
        entity.display_info.points_visible = true;
    } else {
        log("# No unreferenced positions found");
    }

} @RegisterCommand

item_find_zero_area_triangles :: (id : int) {
    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(id) {
        return;
    }

    target : *Entity = app.entities[id];

    if target.mesh.triangles.count == 0 {
        log("# Mesh contains no triangles.");
        return;
    }

    zero_area_triangles : [..]Triangle3;
    defer array_reset(*zero_area_triangles);
    for :ModelTriangleIterator target.mesh {
        if it.a == it.b || it.a == it.c || it.b == it.c {
            array_add(*zero_area_triangles, it);
        }
    }

    if zero_area_triangles.count == 0 {
        log("# Mesh contains % triangles, but none of them have zero area.", target.mesh.triangles.count);
        return;
    }

    log("# Mesh contains % triangles, found % zero area triangles", target.mesh.triangles.count, zero_area_triangles.count);

    assert(app.console.history.count > 0);

    result := New(Entity);
    result.mesh.world_from_model = target.mesh.world_from_model;
    for zero_area_triangles {
        add_triangle(*result.mesh, it);
    }
    set_entity_source_from_command(result, tprint("%_zero_area", entity_name(target)), app.console.history[app.console.history.count - 1], result.mesh.positions.count);
    set_entity_display_info(result);

    maybe_update_render_info(*result.render_info, *result.mesh); // @Cleanup fishy, why do we do this
    result.display_info.segments_width = 3;

    // Set generation_index before adding to overwrite the correct entity // @Cleanup fishy
    result.generation_index = target.generation_index;
    add_entity(result, .OVERWRITE);

    log("# Added item '%'", entity_name(result));

} @RegisterCommand

// Modify the position data of the item with the given `id` so new positions lie on spheres with
// the given `radius` centered on the original positions.  If the item is two dimensional then the
// new positions will lie on a circle in the embedding plane containing the geometry
//
// Note: Mesh vertex normals are _not_ updated, but with flat shading the faces will be colored in
// a way which is consistent with the perturbation
item_perturb_positions :: (id : int, radius : float = .001) {
    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(id) {
        return;
    }

    if radius <= 0 {
        log_error("Radius argument should be greater than 0, got %.", radius);
        return;
    }

    Rand :: () -> float #expand {
        return random_get_within_range(-1, 1);
    }

    Perturb2 :: (point : *Vector2) #expand {
        delta := make_vector2(Rand(), Rand());
        normalize_or_x_axis(*delta);
        <<point = <<point + delta * radius;
    }

    Perturb3 :: (point : *Vector3) #expand {
        delta := make_vector3(Rand(), Rand(), Rand());
        normalize_or_z_axis(*delta);
        <<point = <<point + delta * radius;
    }

    // @FIXME: This is broken becuase the mesh points are not synced with the polyline (and polygon?) points,
    // the implementation should perturb the mesh and then recompute the shapes.

    entity := app.entities[id];
    entity.render_info.is_dirty = true;
    for * point : entity.mesh.positions {
        Perturb3(point);
    }
} @RegisterCommand

prism_log :: (message : string) {
    log(message);
} @RegisterCommand

prism_log_warning :: (message : string) {
    log_warning(message);
} @RegisterCommand

prism_log_error :: (message : string) {
    log_error(message);
} @RegisterCommand

item_add_triangle_attribute :: (id : int, attribute_name : string, value_type : Type) {
    if !check_geometry_index(id) {
        return;
    }

    item : *Entity = app.entities[id];

    // @cleanup generate this code
    if value_type == {
        case string;
            add_mesh_attribute(item, attribute_name, Simple_Mesh_Attribute(string, .TRIANGLE));
        case Matrix3;
            add_mesh_attribute(item, attribute_name, Simple_Mesh_Attribute(Matrix3, .TRIANGLE));
        case;
            // TODO Add others from the attribute list and improve this error message
            log_error("unsupported attribute type '%'", value_type);
            return;
    }

} @RegisterCommand

item_add_vertex_attribute :: (id : int, attribute_name : string, value_type : Type) {
    if !check_geometry_index(id) {
        return;
    }

    item : *Entity = app.entities[id];

    // @cleanup generate this code
    if value_type == {
        case string;
            add_mesh_attribute(item, attribute_name, Simple_Mesh_Attribute(string, .VERTEX));
        case float;
            add_mesh_attribute(item, attribute_name, Simple_Mesh_Attribute(float, .VERTEX));
        case;
            // TODO Add others from the attribute list and improve this error message
            log_error("unsupported attribute type '%'", value_type);
            return;
    }
} @RegisterCommand

/*
clear_normals :: (id : int) {
    // @Incomplete if the normals are all constant it screws up the normal render, wipe them here
} @RegisterCommand

reorient_triangles_012_to_021 :: (id : int) {
    // @Incomplete Some triangles have flipped face,
} @RegisterCommand
*/


#scope_file

apply_focus :: (clip_radius : float, sphere : Sphere, entity : *Entity) {
    if clip_radius >= 0 {
        fit_sphere_on_screen(sphere);

        entity.display_info.clip_sphere.sphere = sphere;
        entity.display_info.clip_sphere.is_active = true;
    } else {
        target : Sphere = ---;
        target.center = sphere.center;

        // @Think Maybe this behaviour for expanding spheres should be an $ argument to expand?
        // expand(*target, entity.render_info.bounding_sphere);
        center_distance := distance(target.center, entity.render_info.bounding_sphere.center);
        target.radius = center_distance + entity.render_info.bounding_sphere.radius;

        fit_sphere_on_screen(target);
        near_far_camera := app.camera;

        // @Think Maybe put this into the fit_sphere_on_screen function?
        // At this point the camera is set so that the left/right/top/bottom/near/far planes bound `target`.
        // We would like to keep the near/far values but change left/right/top/bottom so that the point of
        // interest fills the screen
        fit_sphere_on_screen(sphere);
        app.camera.near = near_far_camera.near;
        app.camera.far = near_far_camera.far;

        // Turn it off even if it was on (the user can just toggle it on again)
        entity.display_info.clip_sphere.is_active = false;
    }
}