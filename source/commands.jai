// Copyright Epic Games, Inc. All Rights Reserved.

// Procedures tagged with @RegisterCommand will have their documentation appear
// in the console when the user calls `help <command-name>`. Every line starting
// with // above the procedure will be included in the documentation

check_geometry_index :: (index : int) -> bool #must {
    if index < 0 || index >= app.entities.count {
        log_error("Invalid/Out-of-range geometry index");
        return false;
    }
    return true;
}

// Close the application
quit :: () {
    app.closing_application = true;
} @RegisterCommand

// Show the history of console commands from this session
history :: () {
    console_clear_log();
    for app.console.history log("# % %", it_index, it);
} @RegisterCommand

// Clear all the text shown in the console
clear :: () {
    console_clear_log();
} @RegisterCommand

// Show the documentation of the given `command`
// If no arguments are passed list all available commands
help :: (command : string = "") {
    if command == "" {
        log("# Available commands:");
        for app.console.commands {
            log("#  %", it.usage);
        }
    } else {
        for app.console.commands {
            if it.name == command {
                log("#  %", it.documentation);
                break;
            }
        }
    }
} @RegisterCommand

select_if :: (should_select : (Entity)->bool) {
    count := 0;
    for app.entities {
        if should_select(<<it) {
            it.is_selected = true;
            count += 1;
        } else {
            it.is_selected = false;
        }
    }
    if count == 1 log("# selected 1 entity");
    else          log("# selected % entities", count);
}

// @TODO Add an invert option to these?

// Add all items with POLYLINE_SOUP2 type to the selection
select_if_Polyline_Soup2 :: () {
    select_if((e) => (e.type == .POLYLINE_SOUP2));
} @RegisterCommand

// Add all items with POLYLINE_SOUP3 type to the selection
select_if_Polyline_Soup3 :: () {
    select_if((e) => (e.type == .POLYLINE_SOUP3));
} @RegisterCommand

// Add all items with POLYGON_SOUP type to the selection
select_if_Polygon_Soup :: () {
    select_if((e) => (e.type == .POLYGON_SOUP));
} @RegisterCommand

// Add all items with MESH type to the selection
select_if_Mesh :: () {
    select_if((e) => (e.type == .MESH));
} @RegisterCommand

// Add all items with no position data to the selection
select_if_empty :: () {
    // @CompilerBug the following quick lambda doesn't work, but should: select_if((e) => (is_empty(e)));
    select_empty_entity :: (e : Entity) -> bool {
        return is_empty(e);
    }
    select_if(select_empty_entity);
} @RegisterCommand

// @CompilerBug By passing *void data to the should_select procedure we could use the generic version above

// Add all items matching the given `pattern` to the selection.
// The following wildcards/regex patterns are supported: * ? [] [-]
select_if_match :: (pattern : string) {
    count := 0;
    for app.entities {
        text := entity_filename(<<it, false, true, false);
        if wildcard_match(text, pattern) {
            it.is_selected = true;
            count += 1;
        } else {
            it.is_selected = false;
        }
    }
    if count == 1 log("# selected 1 entity");
    else          log("# selected % entities", count);
} @RegisterCommand

// Sorts items in alphabetical order
sort_by_name :: (reversed : int = 0) {
    compare_alphabetical :: (a : *Entity, b : *Entity) -> s64 {
        return compare_strings(a.fully_pathed_filename, b.fully_pathed_filename);
    }

    compare_reverse_alphabetical :: (a : *Entity, b : *Entity) -> s64 {
        return compare_strings(b.fully_pathed_filename, a.fully_pathed_filename);
    }

    if   reversed quick_sort(app.entities, compare_reverse_alphabetical);
    else          quick_sort(app.entities, compare_alphabetical);
} @RegisterCommand

// Sorts items using the load timestamp
sort_by_time :: (ascending : int = 1) {
    compare_ascending :: (a : *Entity, b : *Entity) -> s64 {
        // @Cleanup This is a pretty weird way to do this...
        at := filetime_to_readable_date(a.loaded_filetime);
        bt := filetime_to_readable_date(b.loaded_filetime);
        if at == bt return compare_strings(b.fully_pathed_filename, a.fully_pathed_filename);
        return compare_strings(bt, at);
    }

    compare_descending :: (a : *Entity, b : *Entity) -> s64 {
        // @Cleanup This is a pretty weird way to do this...
        at := filetime_to_readable_date(a.loaded_filetime);
        bt := filetime_to_readable_date(b.loaded_filetime);
        if at == bt return compare_strings(a.fully_pathed_filename, b.fully_pathed_filename);
        return compare_strings(at, bt);
    }

    if   ascending quick_sort(app.entities, compare_ascending);
    else           quick_sort(app.entities, compare_descending);
} @RegisterCommand

// Sorts items using the number of points in the mesh, falling back to sorting by filename
sort_by_size :: (ascending : int = 1) {
    compare_ascending :: (a : *Entity, b : *Entity) -> s64 {
        if a.mesh.positions.count == b.mesh.positions.count {
            return compare_strings(a.fully_pathed_filename, b.fully_pathed_filename);
        }
        return compare_floats(xx a.mesh.positions.count, xx b.mesh.positions.count);
    }

    compare_descending :: (a : *Entity, b : *Entity) -> s64 {
        if a.mesh.positions.count == b.mesh.positions.count {
            return compare_strings(b.fully_pathed_filename, a.fully_pathed_filename);
        }
        return compare_floats(xx b.mesh.positions.count, xx a.mesh.positions.count);
    }

    if   ascending quick_sort(app.entities, compare_ascending);
    else           quick_sort(app.entities, compare_descending);
} @RegisterCommand

// Clears the item with the given `index`
clear_item :: (index : int) {
    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(index) {
        return;
    }

    item := app.entities[index];
    point_count := item.mesh.positions.count;
    clear(item);

    log("# Cleared item #% which had % points", index, point_count);
} @RegisterCommand

} @RegisterCommand

// Sets the edge/wireframe color to the face/surface color for all items
set_edge_color_to_face_color :: () {
    for app.entities {
        it.display_info.wireframe_color = it.display_info.surface_color;
    }
} @RegisterCommand

// @Incomplete add an origin argument
// @Incomplete variants to create a grids covering the aabb of an entity/selection/scene
// @Incomplete 2D version placing grid in front of camera

// Adds a grid item with the given `spacing` and extending for the given number
// of cells in the x, y and z world axes directions
make_grid :: (spacing : float, nx : int, ny : int, nz : int) {

    new_entity := New(Polyline_Soup3_Entity);

    grid := make_Grid3(spacing, .{0, 0, 0});

    for k : 0..nz for j : 0..ny {
        polyline := array_add(*new_entity.shape.polylines);
        for i : 0..nx {
            p := sample_point(grid, make_Cell_Index(i, j, k));
            array_add(*polyline.points, p);
        }
    }

    for k : 0..nz for i : 0..nx {
        polyline := array_add(*new_entity.shape.polylines);
        for j : 0..ny {
            p := sample_point(grid, make_Cell_Index(i, j, k));
            array_add(*polyline.points, p);
        }
    }

    for j : 0..ny for i : 0..nx {
        polyline := array_add(*new_entity.shape.polylines);
        for k : 0..nz {
            p := sample_point(grid, make_Cell_Index(i, j, k));
            array_add(*polyline.points, p);
        }
    }

    ok : bool;
    new_entity.mesh, ok = to_Mesh(new_entity.shape);
    assert(ok);

    name :: "grid";
    init_entity_base_parameters(new_entity, name, new_entity.mesh);
    maybe_update_render_info(*new_entity.render_info, *new_entity.mesh);

    found, _ := find_entity_with_max_generation_index(name);
    if found {
        new_entity.generation_index = found.generation_index + 1;
    }
    array_add(*app.entities, new_entity);

} @RegisterCommand

/*
clear_normals :: (item_index : int) {
    // @Incomplete if the normals are all constant it screws up the normal render, wipe them here
} @RegisterCommand

flip_normals :: (item_index : int) {
    // @Incomplete
} @RegisterCommand

reorient_triangles_012_to_021 :: (item_index : int) {
    // @Incomplete Some triangles have flipped face,
} @RegisterCommand
*/
