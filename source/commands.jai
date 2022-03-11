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

// Show the history of console commands
console_show_history :: () {
    console_clear_log();
    for app.console.history log("# % %", it_index, it);
} @RegisterCommand

// Lists all available commands and displays a help message
help :: () {
    log("# % available commands:", app.console.commands.count);
    for app.console.commands {
        log("#  %", it.usage);
    }
} @RegisterCommand

select_if :: (should_select : (Entity)->bool) {
    count := 0;
    for app.entities {
        if should_select(it) {
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
        text := entity_filename(it, false, true, false);
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

// Clears the item with the given `index` (resets geometry data containers)
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

// Sets the edge/wireframe color to the face/surface color for all items
set_edge_color_to_face_color :: () {
    for app.entities {
        it.display_info.wireframe_color = it.display_info.surface_color;
    }
} @RegisterCommand

// Update the camera so that the triangle with the given `triangle_index`, belonging to the mesh
// with the given `item_index`, fills the screen. The current look direction is preserved and the
// orbit/focus of the camera is positioned on the triangle centroid.
//
// If `radius` is less than zero (the default) then 2x triangle bounding sphere radius is used to
// update the camera, otherwise the given value is used as the bounding sphere radius.
focus_on_triangle :: (item_index : int, triangle_index : int, radius := -1.) {

    if !check_geometry_index(item_index) {
        return;
    }

    entity := app.entities[item_index];

    if entity.type != .MESH {
        log_error("Expected MESH type item, got %.", entity.type);
        return;
    }

    if entity.mesh.geometry_format != .TRIANGLES {
        // @CompilerBug Using .TRIANGLES as the second argument crashed the compiler!
        log_error("Expected mesh with % geometry format, got %.", Geometry_Format.TRIANGLES, entity.mesh.geometry_format);
        return;
    }

    tid_max := element_count(entity.mesh) - 1;
    if triangle_index < 0 || triangle_index > tid_max {
        log_error("Expected a triangle index in the range [0, %], got %.", tid_max, triangle_index);
        return;
    }

    tri := get_triangle(entity.mesh, triangle_index, true);

    sphere : Sphere = ---;
    sphere.center = (tri.a + tri.b + tri.c) / 3;

    if radius >= 0 {
        sphere.radius = radius;
    } else {
        sphere.radius = distance(sphere.center, tri.a);
        sphere.radius = max(sphere.radius, distance(sphere.center, tri.b));
        sphere.radius = max(sphere.radius, distance(sphere.center, tri.c));
        sphere.radius *= 2;
    }

    look_length := dot_product(unit_vector(current_look_direction()), sphere.center - app.camera.eye_position); // @Cleanup
    fit_sphere_on_screen(sphere, look_length);

} @RegisterCommand

// Update the camera so that a sphere with the given `radius`, centered on the vertex with the given
// `vertex_index`, belonging to the mesh with the given `item_index`, fills the screen. The current
// look direction is preserved.
focus_on_vertex :: (item_index : int, vertex_index : int, radius := 1.) {

    if !check_geometry_index(item_index) {
        return;
    }

    entity := app.entities[item_index];

    if entity.type != .MESH {
        log_error("Expected MESH type item, got %. Support for other item types is @Incomplete", entity.type);
        return;
    }

    vid_max := entity.mesh.positions.count - 1;
    if vertex_index < 0 || vertex_index >= vid_max {
        log_error("Expected a vertex index in the range [0, %], got %.", vid_max, vertex_index);
        return;
    }

    if radius < 0 {
        log_error("Expected a positive non-zero bounding sphere radius, got %.", radius);
        return;
    }

    sphere : Sphere = ---;
    sphere.center = entity.mesh.positions[vertex_index];
    sphere.radius = radius;

    look_length := dot_product(unit_vector(current_look_direction()), sphere.center - app.camera.eye_position); // @Cleanup
    fit_sphere_on_screen(sphere, look_length);

} @RegisterCommand

// Adds an item containing a soup of edges belonging to only one triangle in the mesh item with the given `index`
find_open_edges :: (index : int) {
    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(index) {
        return;
    }

    if app.entities[index].type != .MESH {
        log_error("Expected MESH type item, got %.", app.entities[index].type);
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
    defer uninit(*edge_to_origin);

    mesh := app.entities[index].mesh;
    if mesh.geometry_format != .TRIANGLES {
        log("Expected a mesh with TRIANGLES geometry format, got %.", mesh.geometry_format);
        return;
    }

    for :Triangle_Tuples_Iterator mesh {
        Process_Edge :: (i : u32, j : u32) #expand {
            edge := make_Tuple2(i, j);
            value, found := table_find(edge_to_origin, edge);
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
        log("No boundary edges detected");
        return;
    }

    // Collect the segment soup @Incomplete weld/stitch polyline segments together
    segment_soup : Polyline_Soup3;
    for origin, edge : edge_to_origin {
        segment := array_add(*segment_soup.polylines);
        array_add(*segment.points, mesh.positions[edge.x]);
        array_add(*segment.points, mesh.positions[edge.y]);
    }

    // Add a new item
    new_entity := New(Polyline_Soup3_Entity);
    new_entity.shape = segment_soup;
    new_entity.mesh = to_Mesh(new_entity.shape);
    maybe_update_render_info(*new_entity.render_info, *new_entity.mesh);
    name := join(app.entities[index].fully_pathed_filename, "_open_edges"); // @Leak
    init_entity_base_parameters(new_entity, name, new_entity.mesh);
    new_entity.display_info.wireframe_width = 3;
    found_entity := find_entity_with_max_generation_index(new_entity.fully_pathed_filename);
    if found_entity {
        new_entity.generation_index = found_entity.generation_index + 1;
    }
    array_add(*app.entities, new_entity);

} @RegisterCommand

// Modify the position data of the item with the given `index` so new positions lie on spheres with
// the given `radius` centered on the original positions.  If the item is two dimensional then the
// new positions will lie on a circle in the embedding plane containing the geometry
//
// Note: Mesh vertex normals are _not_ updated, but with flat shading the faces will be colored in
// a way which is consistent with the perturbation
perturb_positions :: (index : int, radius : float = .001) {
    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(index) {
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

    base := app.entities[index];
    base.render_info.is_dirty = true;
    if #complete base.type == {
        case .POLYLINE_SOUP2;
            entity := cast(*Polyline_Soup2_Entity)base;
            for * :Point_Iterator point : entity.shape {
                Perturb2(point);
            }
            entity.mesh = to_Mesh(entity.shape);
        case .POLYGON_SOUP;
            entity := cast(*Polygon_Soup_Entity)base;
            for polygon : entity.shape.polygons {
                for * :Point_Iterator point : polygon {
                    Perturb2(point);
                }
            }
            entity.mesh = to_Mesh(entity.shape);
        case .POLYLINE_SOUP3;
            entity := cast(*Polyline_Soup3_Entity)base;
            for * :Point_Iterator point : entity.shape {
                Perturb3(point);
            }
            entity.mesh = to_Mesh(entity.shape);
        case .POINT_CLOUD;
            entity := cast(*Point_Cloud_Entity)base;
            for * point : entity.mesh.positions {
                Perturb3(point);
            }
        case .MESH;
            entity := cast(*Mesh_Entity)base;
            for * point : entity.mesh.positions {
                Perturb3(point);
            }
        case .UNKNOWN;
            log_error("Unknown item type.");
            return;
    }
} @RegisterCommand

// @Incomplete variants to create a grids covering the aabb of an entity/selection/scene
// @Incomplete disable reload selection on Grid items

// Adds a 2D grid item filling the the camera near plane.
// `spacing`    is the distance between adjacent grid points in each world axes direction
// `restricted` by default the grid size is restricted, passing 0 will remove all restrictions
make_Grid_on_near_plane :: (spacing : float, restricted : int=1) {
    frame : Frame = ---;
    {
        forward := normalize_or_z_axis(app.camera.look_position - app.camera.eye_position);
        right := normalize_or_z_axis(cross(forward, app.camera.up_direction));
        up := cross(right, forward);
        frame = make_Frame(right, up);
    }

    origin := app.camera.eye_position + normalize(current_look_direction()) * (app.camera.near + .001);
    name := tprint("Grid_Near_%", spacing);

    assert(app.camera.right > app.camera.left);
    assert(app.camera.top > app.camera.bottom);
    Nx := cast(u32)ceil((app.camera.right - app.camera.left) / spacing / 2) + 2;
    Ny := cast(u32)ceil((app.camera.top - app.camera.bottom) / spacing / 2) + 2;
    color := color_from_string(tprint("%", ImGui.GetFrameCount()));

    make_Grid_on_plane(spacing, Nx, Ny, frame, xx origin, name, color, restricted);
} @RegisterCommand

// Adds a 2D grid item filling the the camera far plane.
// `spacing`    is the distance between adjacent grid points in each world axes direction
// `restricted` by default the grid size is restricted, passing 0 will remove all restrictions
make_Grid_on_far_plane :: (spacing : float, restricted : int=1) {
    frame : Frame = ---;
    {
        forward := normalize_or_z_axis(app.camera.look_position - app.camera.eye_position);
        right := normalize_or_z_axis(cross(forward, app.camera.up_direction));
        up := cross(right, forward);
        frame = make_Frame(right, up);
    }

    origin := app.camera.eye_position + normalize(current_look_direction()) * (app.camera.far - .001);
    name := tprint("Grid_Far_%", spacing); // @Cleanup Pick a good formatting here probably scientific? (and in similar places in this file)

    assert(app.camera.right > app.camera.left);
    assert(app.camera.top > app.camera.bottom);
    Nx := cast(u32)ceil((app.camera.right - app.camera.left) / spacing / 2) + 2;
    Ny := cast(u32)ceil((app.camera.top - app.camera.bottom) / spacing / 2) + 2;
    color := color_from_string(tprint("%", ImGui.GetFrameCount()));

    make_Grid_on_plane(spacing, Nx, Ny, frame, xx origin, name, color, restricted);
} @RegisterCommand

// Adds a 2D grid item in the XY plane passing through the camera orbit point
// `spacing`    is the distance between adjacent grid points in each world axes direction
// `restricted` by default the grid size is restricted, passing 0 will remove all restrictions
// Note: The camera orbit may be positioned on a model using C-RMB in Selection Mode
make_Grid_on_xy_plane :: (spacing : float, N : u32, restricted : int=1) {
    frame := make_Frame(.{1, 0, 0}, .{0, 1, 0});
    origin := app.camera.look_position;
    name := tprint("Grid_XY_%", spacing);
    BLUE :: Vector4.{0,0,1,1};
    make_Grid_on_plane(spacing, N, N, frame, xx origin, name, BLUE, restricted);
} @RegisterCommand

// Adds a 2D grid item in the YZ plane passing through the camera orbit point
// `spacing`    is the distance between adjacent grid points in each world axes direction
// `restricted` by default the grid size is restricted, passing 0 will remove all restrictions
// Note: The camera orbit may be positioned on a model using C-RMB in Selection Mode
make_Grid_on_yz_plane :: (spacing : float, N : u32, restricted : int=1) {
    frame := make_Frame(.{0, 1, 0}, .{0, 0, 1});
    origin := app.camera.look_position;
    name := tprint("Grid_YZ_%", spacing);
    RED :: Vector4.{1,0,0,1};
    make_Grid_on_plane(spacing, N, N, frame, xx origin, name, RED, restricted);
} @RegisterCommand

// Adds a 2D grid item in the ZX plane passing through the camera orbit point
// `spacing`    is the distance between adjacent grid points in each world axes direction
// `restricted` by default the grid size is restricted, passing 0 will remove all restrictions
// Note: The camera orbit may be positioned on a model using C-RMB in Selection Mode
make_Grid_on_zx_plane :: (spacing : float, N : u32, restricted : int=1) {
    frame := make_Frame(.{0, 0, 1}, .{1, 0, 0});
    origin := app.camera.look_position;
    name := tprint("Grid_ZX_%", spacing);
    GREEN :: Vector4.{0,1,0,1};
    make_Grid_on_plane(spacing, N, N, frame, xx origin, name, GREEN, restricted);
} @RegisterCommand

// Equivalent to calling each of make_Grid_on_xy/yz/zx_plane
make_Grid_on_xyz_planes :: (spacing : float, N : u32, restricted : int=1) {
    make_Grid_on_xy_plane(spacing, N, restricted);
    make_Grid_on_yz_plane(spacing, N, restricted);
    make_Grid_on_zx_plane(spacing, N, restricted);
} @RegisterCommand

// Adds a 3D grid item.
// `spacing`        is the distance between adjacent grid points in each world axes direction
// `nx`, `ny`, `nz` is the number of grid points in each world axes direction
// `ox`, `oy`, `oz` is the world position of the grid point with local coordinate {0,0,0}
make_Grid :: (spacing : float, nx : u32, ny : u32, nz : u32, ox : float, oy : float, oz : float) {
    grid := make_Grid_from_World(spacing, xx make_vector3(ox, oy, oz));
    extents := make_Tuple3(nx, ny, nz);
    name := tprint("Grid_%", grid.spacing);
    make_Grid_Entity(grid, extents, name, color_from_string(tprint("%", ImGui.GetFrameCount())));
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

#scope_file

make_Grid_on_plane :: (_spacing : float, _Nx : u32, _Ny : u32, frame : Frame, origin : Grid.World, name : string, color : Vector4, restricted : int=1) {
    Nx, Ny, spacing := _Nx, _Ny, _spacing;

    if restricted && spacing < .0001 {
        log_warning("Spacing was clamped to .0001. Pass 0 for restricted argument to not do this.");
        spacing = 0.0001;
    }

    grid := make_Grid_from_World(spacing, origin, frame);

    MAX_N :: 500;

    if restricted && Nx > MAX_N {
        log_warning("Extents were clamped to %, from %. Pass 0 for restricted argument to not do this.", MAX_N, Nx);
        Nx = MAX_N;
    }

    if restricted && Ny > MAX_N {
        log_warning("Extents were clamped to %, from %. Pass 0 for restricted argument to not do this.", MAX_N, Ny);
        Ny = MAX_N;
    }

    extents := make_Tuple3(Nx, Ny, 1);

    make_Grid_Entity(grid, extents, name, color);
}

make_Grid_Entity :: (grid : Grid, extents : Tuple3(u32), name : string, color : Vector4) {

    new_entity := New(Polyline_Soup3_Entity);

    new_entity.shape = to_Polyline_Soup3(grid, extents);
    new_entity.mesh = to_Mesh(new_entity.shape);
    init_entity_base_parameters(new_entity, name, new_entity.mesh);
    maybe_update_render_info(*new_entity.render_info, *new_entity.mesh);
    primary_color := entity_primary_color(new_entity);
    if primary_color {
        <<primary_color = color;
    }
    found_entity := find_entity_with_max_generation_index(name);
    if found_entity {
        new_entity.generation_index = found_entity.generation_index + 1;
    }

    array_add(*app.entities, new_entity);
}