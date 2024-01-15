// @Incomplete variants to create a grids covering the aabb of an entity/selection/scene
// @Incomplete disable reload selection on Grid items

// Adds a 2D grid item filling the the camera near plane.
// `spacing`    is the distance between adjacent grid points in each world axes direction
// `restricted` by default the grid size is restricted, passing 0 will remove all restrictions
make_Grid_on_near_plane :: (spacing : float, restricted : int=1) {
    frame : Frame = ---;
    {
        forward := normalize(app.camera.look_position - app.camera.eye_position, fallback=.{z=1});
        right := normalize(cross(forward, app.camera.up_direction), fallback=.{z=1});
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
        forward := normalize(app.camera.look_position - app.camera.eye_position, fallback=.{z=1});
        right := normalize(cross(forward, app.camera.up_direction), fallback=.{z=1});
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

    assert(app.console.history.count > 0);

    shape : Polyline_Soup3 = to_Polyline_Soup3(grid, extents); 
    mesh : Simple_Mesh = to_Mesh(shape);

    new_entity := New(Entity);
    new_entity.mesh = mesh;
    set_entity_source_from_command(new_entity, name, app.console.history[app.console.history.count - 1], new_entity.mesh.positions.count);
    set_entity_display_info(new_entity);

    maybe_update_render_info(*new_entity.render_info, *new_entity.mesh); // @Cleanup fishy, why?

    // Set generation_index before adding to overwrite the correct entity
    new_entity.generation_index = 0;
    add_entity(new_entity, .OVERWRITE);
}