// Copyright Epic Games, Inc. All Rights Reserved.

Mesh :: struct {
    geometry_format := Geometry_Format.UNKNOWN;

    // @Cleanup explicitly store allocator/allocator_data and use array views? see Hash_Table.jai
    positions : [..]Vector3;
    normals :  [..]Vector3;
    indices :  [..]u32;
    // texture_uvs : [..]Vector2; @Incomplete

    world_from_model : Matrix4 = .{_11 = 1, _22 = 1, _33 = 1, _44 = 1};
}

triangles_iterator :: (using mesh : *Mesh, body : Code, flags : For_Flags) #expand {
    #assert(flags == 0); // No options are supported

    `it_index := 0;
    for i : 0..mesh.indices.count/3-1 {
        i0 := mesh.indices[3 * i + 0];
        i1 := mesh.indices[3 * i + 1];
        i2 := mesh.indices[3 * i + 2];
        `it := make_Tuple3(i0, i1, i2);
        #insert (remove=#assert(false)) body;
        it_index += 1;
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
}

bounding_box :: (using mesh : Mesh) -> AxisBox3 #must {
    box : AxisBox3;
    for * mesh.positions {
        expand(*box, <<it);
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
        <<it = (transform * make_vector4(<<it, 1.)).xyz;
    }

    if mesh.normals.count {
        inverse_transpose := transpose(inverse(transform));
        for * mesh.normals {
            <<it = (inverse_transpose * make_vector4(<<it, 0.)).xyz;
        }
    }
}