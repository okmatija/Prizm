// Copyright Epic Games, Inc. All Rights Reserved.

check_geometry_index :: (index : int) -> bool #must {
    if index < 0 || index >= app.entities.count {
        log_error("Invalid/Out-of-range geometry index");
        return false;
    }
    return true;
}

quit :: () {
    app.closing_application = true;
} @RegisterCommand

history :: () {
    console_clear_log();
    for app.console.history log("# % %", it_index, it);
} @RegisterCommand

clear :: () {
    console_clear_log();
} @RegisterCommand

help :: () {
    log("# Available commands:");
    for app.console.commands log("#  %", it.usage);
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
select_if_Polyline_Soup2 :: () { select_if((e) => (e.type == .POLYLINE_SOUP2)); } @RegisterCommand
select_if_Polyline_Soup3 :: () { select_if((e) => (e.type == .POLYLINE_SOUP3)); } @RegisterCommand
select_if_Polygon_Soup   :: () { select_if((e) => (e.type == .POLYGON_SOUP));   } @RegisterCommand
select_if_Mesh           :: () { select_if((e) => (e.type == .MESH));           } @RegisterCommand
select_if_empty          :: () {
    // @CompilerBug the following quick lambda doesn't work, but should: select_if((e) => (is_empty(e)));
    select_empty_entity :: (e : Entity) -> bool {
        return is_empty(e);
    }
    select_if(select_empty_entity);
} @RegisterCommand

// @CompilerBug By passing *void data to the should_select procedure we could use the generic version above
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

sort_by_name :: (alphabetical : int = 1) {
    compare_alphabetical :: (a : *Entity, b : *Entity) -> s64 {
        return compare_strings(a.fully_pathed_filename, b.fully_pathed_filename);
    }

    compare_reverse_alphabetical :: (a : *Entity, b : *Entity) -> s64 {
        return compare_strings(b.fully_pathed_filename, a.fully_pathed_filename);
    }

    if   alphabetical quick_sort(app.entities, compare_alphabetical);
    else              quick_sort(app.entities, compare_reverse_alphabetical);
} @RegisterCommand

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

clear_item :: (item_index : int) {
    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(item_index) {
        return;
    }

    item := app.entities[item_index];
    point_count := item.mesh.positions.count;
    clear(item);

    log("# Cleared item #% which had % points", item_index, point_count);
} @RegisterCommand

set_edge_color_to_face_color :: () {
    for app.entities {
        it.display_info.wireframe_color = it.display_info.surface_color;
    }
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
