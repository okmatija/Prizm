// Copyright Epic Games, Inc. All Rights Reserved.

// A uniform grid data-structure.
// This data-structure is defined in reference to an infinite 'background' grid.
// The background grid has the same spacing as the desired grid but its [0,0,0]-th sample point is located at world space zero.
// The origin_offset member locates position of the Grid's [0,0,0]-th sample point as an offset in local coordinates from the background grid origin

// @Incomplete make_alignable_Grid

// GridPlane;

Grid :: struct ($DIM: u8) {
    #assert(DIM == 2 || DIM == 3);

#if DIM == 2 {
    Position :: #type,isa Vector2;
    Cell_Index :: #type,isa Vector2i;
} else {
    Position :: #type,isa Vector3;
    Cell_Index :: #type,isa Vector3i;
}

    Local :: #type,isa Position;
    World :: #type,isa Position;
    Cell_Linear_Index :: #type,isa s64; // Linear index into the Grid, useful to index data stored at grid cells

    spacing : float;
    inverse_spacing : float;
    origin_offset : Local;
}

Grid2 :: Grid(2);
Grid3 :: Grid(3);

make_Grid :: (spacing : float, origin_offset : Grid(DIM).Local, $DIM : u8) -> Grid(DIM) {
    result : Grid(DIM) = ---;
    result.spacing = spacing;
    result.inverse_spacing = 1. / spacing;
    result.origin_offset = origin_offset;
    return result;
}

make_Grid2 :: #bake_arguments make_Grid(DIM = 2);
make_Grid3 :: #bake_arguments make_Grid(DIM = 3);

// Return the local position transformed to world coordinates
to_world :: inline (using grid : $T/Grid, local : T.Local) -> T.World {
    return xx ((local + origin_offset) * spacing);
}

// Return the sample point located the local coordinate integer junction points (aka minimum cell corner)
sample_point :: inline (using grid : $T/Grid, cell : T.Cell_Index) -> T.World {
    return to_world(grid, inline make_Grid_Local(cell));
}

// Return the world position transformed to local coordinates
to_local :: inline (using grid : $T/Grid, world : T.World) -> T.Local {
    return xx (world * inverse_spacing - origin_offset);
}

// Return the cell containing the given local position
cell_of :: inline (using grid : $T/Grid, local : T.Local) -> T.Cell_Index {
    return inline make_Cell_Index(xx inline floor(local));
}

// Return the cell containing the given world position
cell_of :: inline (using grid : $T/Grid, world : T.World) -> T.Cell_Index {
    return cell_of(grid, to_local(grid, world));
}

// Return bounds, in world coordinates, of the cell with the given index
cell_bounds :: inline (using grid : $T/Grid, index : T.Cell_Index) -> AxisBox(T.Position) {
    min_corner := sample_point(grid, index);
    max_corner := min_corner;
    for 0..T.DIM-1 max_corner[it_index] += spacing;
    return inline make_axis_box3(min_corner, max_corner);
}

world_origin :: inline (using grid : $T/Grid) -> T.World {
    #if T.DIM == 2 {
        return sample_point(grid, .{0, 0});
    } else {
        return sample_point(grid, .{0, 0, 0});
    }
}




floor :: (v : Vector2) -> Vector2 {
    result : Vector2 = ---;
    result.x = floor(v.x);
    result.y = floor(v.y);
    return result;
}

floor :: (v : Vector3) -> Vector3 {
    result : Vector3 = ---;
    result.x = floor(v.x);
    result.y = floor(v.y);
    result.z = floor(v.z);
    return result;
}

Vector2i :: struct {
    x, y : int;
#place x;
    component : [2] int = ---;
}

Vector3i :: struct {
    x, y, z : int;
#place x;
    component : [3] int = ---;
}

make_Grid_Local :: (cell : Grid2.Cell_Index) -> Grid2.Local {
    result : Grid2.Local = ---;
    result.x = xx cell.x;
    result.y = xx cell.y;
    return result;
}

make_Grid_Local :: (cell : Grid3.Cell_Index) -> Grid3.Local {
    result : Grid3.Local = ---;
    result.x = xx cell.x;
    result.y = xx cell.y;
    result.z = xx cell.z;
    return result;
}

make_Cell_Index :: (i : int, j : int) -> Grid2.Cell_Index {
    result : Grid2.Cell_Index = ---;
    result.x = i;
    result.y = j;
    return result;
}

make_Cell_Index :: (i : int, j : int, k : int) -> Grid3.Cell_Index {
    result : Grid3.Cell_Index = ---;
    result.x = i;
    result.y = j;
    result.z = k;
    return result;
}

make_Cell_Index :: (local : Grid2.Local, $checked := false) -> Grid2.Cell_Index {
    #if checked assert(floor(local) == local);

    result : Grid2.Cell_Index = ---;
    result.x = xx local.x;
    result.y = xx local.y;
    return result;
}

make_Cell_Index :: (local : Grid3.Local, $checked := false) -> Grid3.Cell_Index {
    #if checked assert(floor(local) == local);

    result : Grid3.Cell_Index = ---;
    result.x = xx local.x;
    result.y = xx local.y;
    result.z = xx local.z;
    return result;
}