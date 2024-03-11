// A uniform infinite grid data-structure.
// This data-structure is defined in reference to an infinite 'background' grid.
// The background grid has the same spacing as the desired grid but its [0,0,0]-th sample point is located at world space zero.
// The origin_offset member locates position of the Grid's [0,0,0]-th sample point as an offset in local coordinates from the background grid origin

// @Incomplete 2D grids are just 3D grids with one point in one dimension
// @Incomplete Make a GRID Entity_Type so that e.g., index labelling can work better
// @Incomplete make_alignable_Grid
// @Incomplete Have an api where you have cell indices in X, Y, Z (slabs) XY, XZ, YZ (columns) XYZ (cells)

// @Incomplete Polymorph the Grid using this type to enable optimizations, maybe we'll need some make_Frame overloads, too
Grid_Type :: enum {
    XYZ; // 3D grid oriented with world axes
    UVW; // 3D grid not oriented with world axes

    XY;  // 2D grid parallel to world XY plane
    YZ;  // 2D grid parallel to world YZ plane
    XZ;  // 2D grid parallel to world XZ plane
    UV;  // 2D grid not oriented with world axes

    X;   // 1D grid parallel to world X axis
    Y;   // 1D grid parallel to world Y axis
    Z;   // 1D grid parallel to world Z axis
    U;   // 1D grid not oriented with world axes
}

Frame :: struct {
    x_axis : Vector3 = .{1, 0, 0};
    y_axis : Vector3 = .{0, 1, 0};
    z_axis : Vector3 = .{0, 0, 1};

    #place x_axis; u_axis : Vector3 = ---;
    #place y_axis; v_axis : Vector3 = ---;
    #place z_axis; w_axis : Vector3 = ---;
}

WORLD_FRAME :: Frame.{};

make_Frame :: (x_axis : Vector3, y_axis : Vector3, $checked := false) -> Frame {
    z_axis := cross_product(x_axis,  y_axis);

#if checked {
    assert(almost_equal(length(x_axis), 1.));
    assert(almost_equal(length(y_axis), 1.));
    assert(almost_equal(length(z_axis), 1.));
}

    result : Frame = ---;
    result.x_axis = x_axis;
    result.y_axis = y_axis;
    result.z_axis = z_axis;
    return result;
}

// @Cleanup Using a return struct containing these values would be simpler
Declare_Inner_Products :: (a : Frame, b : Frame) #expand {
    `U_X, `V_X, `W_X := dot(a.u_axis, b.x_axis), dot(a.v_axis, b.x_axis), dot(a.w_axis, b.x_axis);
    `U_Y, `V_Y, `W_Y := dot(a.u_axis, b.y_axis), dot(a.v_axis, b.y_axis), dot(a.w_axis, b.y_axis);
    `U_Z, `V_Z, `W_Z := dot(a.u_axis, b.z_axis), dot(a.v_axis, b.z_axis), dot(a.w_axis, b.z_axis);
}

Grid :: struct {
    // Index a single grid point, a line of grid points, or a plane of grid points
    Point_Index_1D :: #type,isa int;         // e.g., In a 3D grid, this indexes a set of points {(x, y, Z) where x, y vary and Z is constant}
    Point_Index_2D :: #type,isa Tuple2(int); // e.g., In a 3D grid, this indexes a set of points {(x, Y, Z) where x varies and Y, Z are constant}
    Point_Index_3D :: #type,isa Tuple3(int);
    Point_Index ::    #type,isa Point_Index_3D; // Common case type alias

    // Index a single grid cube, a column of grid cubes, or a slab of grid cubes
    Cell_Index_1D :: #type,isa int;         // e.g., In a 3D grid, this indexes a set of cubes {(x, y, Z) where x, y vary and Z is constant}
    Cell_Index_2D :: #type,isa Tuple2(int); // e.g., In a 3D grid, this indexes a set of cubes {(x, Y, Z) where x varies and Y, Z are constant}
    Cell_Index_3D :: #type,isa Tuple3(int);
    Cell_Index ::    #type,isa Cell_Index_3D; // Common case type alias

    // Local or World position type
    Position_1D :: #type,isa float;
    Position_2D :: #type,isa Vector2;
    Position_3D :: #type,isa Vector3;
    Position ::    #type,isa Position_3D; // Common case type alias

    // Integer values of the local coordinate align with grid points
    Local_1D :: #type,isa Position_1D;
    Local_2D :: #type,isa Position_2D;
    Local_3D :: #type,isa Position_3D;
    Local ::    #type,isa Position; // Common case type alias

    // World_1D :: #type,isa Position_1D; // Not useful
    // World_2D :: #type,isa Position_2D; // Not useful
    // World_3D :: #type,isa Position_3D; // Not useful
    World_UVW :: #type,isa Position; // World in the grid frame
    World_XYZ :: #type,isa Position; // World in the world frame
    World :: World_XYZ; // Note: no #type,isa (clarify why)

    spacing : float;
    inverse_spacing : float;
    origin_offset : Local;
    frame : Frame;
}

make_Grid_from_World :: (spacing : float, origin : Grid.World, frame : Frame = .{}) -> Grid {
    background_grid := make_Grid_from_Local(spacing, Grid.Local.{}, frame);

    result : Grid = ---;
    result.spacing = spacing;
    result.inverse_spacing = 1. / spacing;
    result.origin_offset = to_local(background_grid, origin);
    result.frame = frame;
    return result;
}

make_Grid_from_Local :: (spacing : float, origin : Grid.Local, frame : Frame = .{}) -> Grid {
    result : Grid = ---;
    result.spacing = spacing;
    result.inverse_spacing = 1. / spacing;
    result.origin_offset = origin;
    result.frame = frame;
    return result;
}

// Return the local position transformed to world coordinates
// @Incomplete just `return xx ((local + origin_offset) * spacing);` when Grid_Type == .XYZ
to_world :: inline (using grid : Grid, local : Grid.Local) -> Grid.World {

    Declare_Inner_Products(grid.frame, WORLD_FRAME);

    world_uvw : Grid.World_UVW = xx ((local + origin_offset) * spacing);
    u, v, w  := world_uvw.x, world_uvw.y, world_uvw.z;

    x := u * U_X + v * V_X + w * W_X;
    y := u * U_Y + v * V_Y + w * W_Y;
    z := u * U_Z + v * V_Z + w * W_Z;
    world_xyz : Grid.World_XYZ = xx Vector3.{x, y, z}; // @CompilerBug should auto-cast be needed here?

    return world_xyz;
}

// Return the sample point located the local coordinate integer junction points (aka minimum cell corner)
sample_point :: inline (using grid : Grid, cell : Grid.Cell_Index) -> Grid.World {
    local : Grid.Local = ---;
    local.x, local.y, local.z = xx cell.x, xx cell.y, xx cell.z;
    return to_world(grid, local);
}

// Return the world position transformed to local coordinates
// @Incomplete just `return xx (world * inverse_spacing - origin_offset);` when Grid_Type == .XYZ
to_local :: inline (using grid : Grid, world_xyz : Grid.World) -> Grid.Local {

    Declare_Inner_Products(grid.frame, WORLD_FRAME);

    x, y, z := world_xyz.x, world_xyz.y, world_xyz.z;

    u := x * U_X + y * U_Y + z * U_Z;
    v := x * V_X + y * V_Y + z * V_Z;
    w := x * W_X + y * W_Y + z * W_Z;
    world_uvw : Grid.World_UVW = xx Vector3.{u, v, w}; // @CompilerBug should auto-cast be needed here?

    local : Grid.Local = xx (world_uvw * inverse_spacing - origin_offset);

    return local;
}

// Return the cell containing the given local position
cell_of :: inline (using grid : Grid, local : Grid.Local) -> Grid.Cell_Index {
    index : Grid.Cell_Index = ---;
    index.x, index.y, index.z = xx floor(local.x), xx floor(local.y), xx floor(local.z);
    return index;
}

// Return the cell containing the given world position
cell_of :: inline (using grid : Grid, world : Grid.World) -> Grid.Cell_Index {
    assert(grid.frame.x_axis == .{1, 0, 0} && grid.frame.y_axis == .{0, 1, 0}); // @Incomplete Not yet implemented for non-world frame
    return cell_of(grid, to_local(grid, world));
}

// Return bounds, in world coordinates, of the cell with the given index
cell_bounds :: inline (using grid : Grid, index : Grid.Cell_Index) -> AxisBox(xx Grid.Position) {
    min_corner := sample_point(grid, index);
    max_corner := min_corner;
    for 0..T.DIM-1 max_corner[it_index] += spacing;
    return inline make_axis_box3(min_corner, max_corner);
}

world_origin :: inline (using grid : Grid) -> Grid.World {
    return sample_point(grid, .{0, 0, 0});
}

to_Polyline_Soup3 :: (grid : Grid, extents : Tuple3(u32), symmetric : bool = true) -> Polyline_Soup3 {

    // Point count in each direction
    maxx, maxy, maxz : s64 = xx extents.x, xx extents.y, xx extents.z;
    minx, miny, minz : s64 = 0, 0, 0;
    if symmetric {
        minx, miny, minz = -maxx, -maxy, -maxz;
    }

    result : Polyline_Soup3;
    array_reserve(*result.polylines, 2*extents.x + 2*extents.y + 2*extents.z);

    for k : minz+1..maxz-1 for j : miny+1..maxy-1 {
        polyline := array_add(*result.polylines);
        array_reserve(*polyline.points, 2*extents.x);
        for i : minx+1..maxx-1 {
            index : Grid.Cell_Index = ---;
            index.x, index.y, index.z = i, j, k;
            p := sample_point(grid, index);
            array_add(*polyline.points, p);
        }
    }

    for k : minz+1..maxz-1 for i : minx+1..maxx-1 {
        polyline := array_add(*result.polylines);
        array_reserve(*polyline.points, 2*extents.y);
        for j : miny+1..maxy-1 {
            index : Grid.Cell_Index = ---;
            index.x, index.y, index.z = i, j, k;
            p := sample_point(grid, index);
            array_add(*polyline.points, p);
        }
    }

    for j : miny+1..maxy-1 for i : minx+1..maxx-1 {
        polyline := array_add(*result.polylines);
        array_reserve(*polyline.points, 2*extents.z);
        for k : minz+1..maxz-1 {
            index : Grid.Cell_Index = ---;
            index.x, index.y, index.z = i, j, k;
            p := sample_point(grid, index);
            array_add(*polyline.points, p);
        }
    }

    return result;
}