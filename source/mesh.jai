Mesh :: struct {
    geometry_format := Geometry_Format.UNKNOWN;

    // @Cleanup explicitly store allocator/allocator_data and use array views? see Hash_Table.jai
    positions : [..]Vector3;
    normals :  [..]Vector3;
    indices :  [..]u32;
    // texture_uvs : [..]Vector2; @Incomplete

    world_from_model : Matrix4 = .{_11 = 1, _22 = 1, _33 = 1, _44 = 1};
}

triangle_tuples_iterator :: (using mesh : *Mesh, body : Code, flags : For_Flags) #expand {
    #assert(flags == 0); // No options are supported

    for i : 0..(mesh.indices.count/3)-1 {
        `it_index := i;
        `it := inline get_triangle_vertex_tuple(mesh, i);
        #insert (remove=#assert(false)) body;
    }
}

triangles_iterator :: (using mesh : *Mesh, body : Code, flags : For_Flags) #expand {
    #assert(flags == 0); // No options are supported

    for i : 0..(mesh.indices.count/3)-1 {
        `it_index := i;
        `it := inline get_triangle(mesh, i);
        #insert (remove=#assert(false)) body;
    }
}

// // @Incomplete see parshapes for a sample implementation
// weld :: (mesh : Mesh) -> Mesh { }
// unweld :: (mesh : Mesh) -> Mesh { }

Geometry_Format :: enum {
    UNKNOWN;
    POINTS;
    LINES;
    TRIANGLES;
}

get_triangle_vertex_tuple :: (using mesh : Mesh, triangle_index : int, $checked := false) -> Tuple3(u32) {
    #if checked assert(mesh.geometry_format == .TRIANGLES);

    i0 := mesh.indices[3 * xx triangle_index + 0];
    i1 := mesh.indices[3 * xx triangle_index + 1];
    i2 := mesh.indices[3 * xx triangle_index + 2];
    return inline make_Tuple3(i0, i1, i2);
}

get_triangle :: (using mesh : Mesh, triangle_index : int, $checked := false) -> Triangle3 {
    tuple := inline get_triangle_vertex_tuple(mesh, triangle_index, checked);

    result : Triangle3 = ---;
    result.a = mesh.positions[tuple.component[0]];
    result.b = mesh.positions[tuple.component[1]];
    result.c = mesh.positions[tuple.component[2]];
    return result;
}

element_count :: (using mesh : Mesh) -> int {
    if #complete geometry_format == {
        case .UNKNOWN;
            return -1;
        case .POINTS;
            return mesh.positions.count;
        case .LINES;
            assert(mesh.indices.count % 2 == 0);
            return mesh.indices.count / 2;
        case .TRIANGLES;
            assert(mesh.indices.count % 3 == 0);
            return mesh.indices.count / 3;
    }
}

copy_mesh :: (using mesh : Mesh) -> *Mesh {
    result := Deep_Copy(*mesh);
    return result;
}

compute_vertex_normals_from_triangles :: (using mesh : *Mesh) -> bool, string {
    if !mesh return false, "Null mesh";

    if mesh.geometry_format != .TRIANGLES {
        return false, "Invalid geometry format";
    }

    if mesh.indices.count % 3 == 0 {
        // @FIXME This doesn't compute vertex normals properly
        array_resize(*mesh.normals, mesh.positions.count, initialize=false);
        for i : 0..mesh.indices.count/3-1 {

            i0 := mesh.indices[3 * i + 0];
            i1 := mesh.indices[3 * i + 1];
            i2 := mesh.indices[3 * i + 2];

            if i0 < mesh.positions.count && i0 < mesh.positions.count && i0 < mesh.positions.count {
                // @FIXME incorrect normal??, use compute_normal instead, or at least the order of points from there
                e01 := mesh.positions[i0] - mesh.positions[i1];
                e02 := mesh.positions[i0] - mesh.positions[i2];
                n   := normalize(cross(e01, e02));

                mesh.normals[i0] = n;
                mesh.normals[i1] = n;
                mesh.normals[i2] = n;
            } else {
                array_reset(*mesh.normals); // Clear and free memory
                return false, "Out-of-range indices in mesh connectivity array";
            }
        }
        assert(mesh.normals.count == mesh.positions.count);
    }

    return true, "";
}

// @Cleanup, Don't need to pass pointers here, and remove setting to null

clear :: (using mesh : *Mesh) {
    // Zeros all the counts, but keeps the memory
    array_reset_keeping_memory(*positions);
    array_reset_keeping_memory(*normals);
    array_reset_keeping_memory(*indices);

    geometry_format = .UNKNOWN;
}

deinit :: (using mesh : *Mesh) {
    if !mesh return;

    // Note: array_reset frees memory and zeros members
    array_reset(*positions);
    array_reset(*normals);
    array_reset(*indices);

    geometry_format = .UNKNOWN;
    mesh = null;
}

merge :: (dst : Mesh, src : Mesh) {
    poffset := dst.positions.count;
    toffset := dst.indices.count;

    npoints := dst.positions.count + src.positions.count;
    ntriangles := dst.indices.count + src.indices.count;

    array_resize(*dst.positions, npoints);
    for i : 0..src.positions.count-1 {
        dst.positions[poffset + i] = src.positions[i];
    }

    if src.normals.count || dst.normals.count {
        array_resize(*dst.normals, npoints);
        for i : 0..src.normals.count-1 {
            dst.normals[poffset + i] = src.normals[i];
        }
    }

    array_resize(*dst.indices, ntriangles);
    for i : 0..src.indices.count-1 {
        dst.indices[toffset + i] = xx poffset + src.indices[i];
    }
}

bounding_box :: (using mesh : Mesh) -> AxisBox3 #must {
    box : AxisBox3;
    for * mesh.positions {
        expand(*box, it);
    }
    return box;
}

bounding_box :: (using mesh : Mesh, transform : Matrix4) -> AxisBox3 #must {
    box : AxisBox3;
    for point_model : mesh.positions {
        point_transformed := (transform * make_vector4(point_model, 1)).xyz;
        expand(*box, point_transformed);
    }
    return box;
}

transform :: (using mesh : *Mesh, transform : Matrix4) {
    if !mesh return;

    for * mesh.positions {
        <<it = (transform * make_vector4(it, 1.)).xyz;
    }

    if mesh.normals.count {
        inverse_transpose := transpose(inverse(transform));
        for * mesh.normals {
            <<it = (inverse_transpose * make_vector4(it, 0.)).xyz;
        }
    }
}