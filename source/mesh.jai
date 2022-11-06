Mesh :: struct {
    geometry_format := Geometry_Format.UNKNOWN;

    // @Cleanup explicitly store allocator/allocator_data and use array views? see Hash_Table.jai
    // This would enable loading a binary blob and pointing into that data
    positions : [..]Vector3;
    normals :  [..]Vector3;
    indices :  [..]u32;
    // texture_uvs : [..]Vector2; @Incomplete

    // nocommit Cleanup this comment
    // Mesh normals and tangents are stored as overlays attributes
    // Attributes are added via the item_add_attribute_XXX commands, which can/should be used in command obj comments
    // Then name is specified in a leading #! ? maybe also say if the annotations are sparse or dense to pick the datastructure
    // I need shaders for different types of data attached to vertices/segments/faces
    // List of data types I want to support
    // - scalars e.g., errors/costs
    // - vectors e.g., Vector2 for UVs, Vector3 for normals/tangents/displacements
    // - tensors e.g., Matrix4 for stresses
    // - string  e.g., debug comments
    attributes : [..]*Simple_Mesh_Attribute;

    world_from_model : Matrix4 = .{_11 = 1, _22 = 1, _33 = 1, _44 = 1};
}

// @Cleanup These functions should also consider the transform, or have _raw variants that don't
// @Cleanup Add a points iterator that considers transforms

TriangleTupleIterator :: (using mesh : *Mesh, body : Code, flags : For_Flags) #expand {
    #assert(flags == 0); // No options are supported
    assert(mesh.geometry_format == .TRIANGLES);
    assert(mesh.indices.count % 3 == 0);

    for i : 0..(mesh.indices.count/3)-1 {
        `it_index := i;
        `it := inline mesh_triangle_tuple(mesh, i);
        #insert (remove=#assert(false)) body;
    }
}

// Reserve the ambiguous name for this iterator which won't compile if used directly
TriangleIterator :: (using mesh : *Mesh, body : Code, flags : For_Flags, $world_space : bool) #expand {
    #assert(flags == 0); // No options are supported
    assert(mesh.geometry_format == .TRIANGLES);
    assert(mesh.indices.count % 3 == 0);

    for i : 0..(mesh.indices.count/3)-1 {
        `it_index := i;
        `it := inline mesh_triangle_hack(mesh, i, world_space);
        #insert (remove=#assert(false)) body;
    }
}

ModelTriangleIterator :: #bake_arguments TriangleIterator(world_space=false);
WorldTriangleIterator :: #bake_arguments TriangleIterator(world_space=true);

// Reserve the ambiguous name for this iterator which won't compile if used directly
SegmentIterator :: (using mesh : *Mesh, body : Code, flags : For_Flags, $world_space : bool) #expand {
    #assert(flags == 0); // No options are supported
    assert(mesh.geometry_format == .LINES);
    assert(mesh.indices.count % 2 == 0);

    for i : 0..(mesh.indices.count/2)-1 {
        `it_index := i;
        `it : Segment3 = inline mesh_segment3_hack(mesh, i, world_space);
        #insert (remove=#assert(false)) body;
    }
}

ModelSegmentIterator :: #bake_arguments SegmentIterator(world_space=false);
WorldSegmentIterator :: #bake_arguments SegmentIterator(world_space=true);

// Reserve the ambiguous name for this iterator which won't compile if used directly
PointIterator :: (using mesh : *Mesh, body : Code, flags : For_Flags, $world_space : bool) #expand {
    #assert(flags == 0); // No options are supported

    for point_model, point_index : mesh.positions {
        `it_index := point_index;
        `it : Vector3 = mesh_point_hack(mesh, point_index, world_space);
        #insert (remove=#assert(false)) body;
    }
}

ModelPointIterator :: #bake_arguments PointIterator(world_space=false);
WorldPointIterator :: #bake_arguments PointIterator(world_space=true);

// // @Incomplete see parshapes for a sample implementation
// weld :: (mesh : Mesh) -> Mesh { }
// unweld :: (mesh : Mesh) -> Mesh { }

Geometry_Format :: enum {
    UNKNOWN;
    POINTS;
    LINES;
    TRIANGLES;
    // TETRAHEDRA; // @Think
}

to_nice_string :: (format : Geometry_Format, plural := false) -> string {
    if #complete format == {
        case .UNKNOWN;   return "Unknown";
        case .POINTS;    return ifx plural then "Point"     else "Points";
        case .LINES;     return ifx plural then "Line"      else "Lines";
        case .TRIANGLES; return ifx plural then "Triangle"  else "Triangles";
    }
}

// @Cleanup remove the _hack postfix

/* @CompilerBug
    E:/Dropbox/Prism/source/mesh.jai:82,66: Error: Internal compiler error: In #bake, we should be guaranteed to find an entry by this name, but we didn't.
    
        get_point_bake_arguments_proc :: #procedure_of_call get_point(Mesh.{}, 0, false);
        get_point_model :: #bake_arguments get_point_bake_arguments_proc(world_space=false);
        get_point_world :: #bake_arguments get_point_bake_arguments_proc(world_space=true);

get_point :: (using mesh : Mesh, vid : int, $world_space : bool) -> Vector3 {
    #if world_space {
        return transform_point(world_from_model, positions[vid]);
    }
    return positions[vid];
}

get_point_bake_arguments_proc :: #procedure_of_call get_point(Mesh.{}, 0, false);
get_point_model :: #bake_arguments get_point_bake_arguments_proc(world_space=false);
get_point_world :: #bake_arguments get_point_bake_arguments_proc(world_space=true);
*/

mesh_point_hack :: inline (using mesh : Mesh, vid : int, $world_space : bool) -> Vector3 {
    #if world_space {
        return transform_point(world_from_model, positions[vid]);
    }
    return positions[vid];
}

mesh_point_model :: #bake_arguments mesh_point_hack(world_space=false);
mesh_point_world :: #bake_arguments mesh_point_hack(world_space=true);





mesh_segment3_tuple :: (mesh : Mesh, segment_index : int, $checked := false) -> Tuple2(u32) {
    #if checked assert(mesh.geometry_format == .LINES);

    i0 := mesh.indices[2 * xx segment_index + 0];
    i1 := mesh.indices[2 * xx segment_index + 1];
    return inline make_Tuple2(i0, i1);
}

mesh_segment3_hack :: (mesh : Mesh, segment_index : int, $world_space : bool, $checked := false) -> Segment3 {
    tuple := inline mesh_segment3_tuple(mesh, segment_index, checked);

    result : Segment3 = ---;
    result.start = mesh_point_hack(mesh, tuple.component[0], world_space); 
    result.end   = mesh_point_hack(mesh, tuple.component[1], world_space); 
    return result;
}

mesh_segment3_model :: #bake_arguments mesh_segment3_hack(world_space=false);
mesh_segment3_world :: #bake_arguments mesh_segment3_hack(world_space=true);




mesh_triangle_tuple :: (using mesh : Mesh, triangle_index : int, $checked := false) -> Tuple3(u32) {
    #if checked assert(mesh.geometry_format == .TRIANGLES);

    i0 := mesh.indices[3 * xx triangle_index + 0];
    i1 := mesh.indices[3 * xx triangle_index + 1];
    i2 := mesh.indices[3 * xx triangle_index + 2];
    return inline make_Tuple3(i0, i1, i2);
}

mesh_triangle_hack :: (mesh : Mesh, triangle_index : int, $world_space : bool, $checked := false) -> Triangle3 {
    tuple := inline mesh_triangle_tuple(mesh, triangle_index, checked);

    result : Triangle3 = ---;
    result.a = mesh_point_hack(mesh, tuple.component[0], world_space);
    result.b = mesh_point_hack(mesh, tuple.component[1], world_space);
    result.c = mesh_point_hack(mesh, tuple.component[2], world_space);
    return result;
}

mesh_triangle_model :: #bake_arguments mesh_triangle_hack(world_space=false);
mesh_triangle_world :: #bake_arguments mesh_triangle_hack(world_space=true);





point_count :: (using mesh : Mesh) -> int {
    return mesh.positions.count;
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

// copy_mesh :: (using mesh : Mesh) -> *Mesh {
//     result := Deep_Copy(*mesh, .{});
//     return result;
// }

// Iterates over all triangles, computes the triangle normal and assigns it to the vertices
// - The normals will be in model space
// - Vertices which are referenced by more than one triangle, will be given the normal of the triangle with the largest triangle index
// - Vertices which are not referenced by any triangles will be assigned [0,0,0] as the normal
compute_vertex_normals_from_triangles :: (mesh : *Mesh) -> bool, string {
    if !mesh return false, "Null mesh";

    if mesh.geometry_format != .TRIANGLES {
        return false, "Invalid geometry format";
    }

    if mesh.indices.count % 3 == 0 {
        // Points not referenced by any triangle are assigned zero normals
        array_resize(*mesh.normals, mesh.positions.count, initialize=true);

        for :TriangleTupleIterator tt : mesh {
            if tt.i < mesh.positions.count && tt.i < mesh.positions.count && tt.i < mesh.positions.count {
                tri : Triangle3 = ---;
                tri.a = mesh.positions[tt.i];
                tri.b = mesh.positions[tt.j];
                tri.c = mesh.positions[tt.k];
                n := compute_normal(tri, normalize=true);
                mesh.normals[tt.i] = n;
                mesh.normals[tt.j] = n;
                mesh.normals[tt.k] = n;
            } else {
                array_reset(*mesh.normals); // Clear and free memory
                return false, tprint("Out-of-range indices in mesh connectivity array, got %, %, %, but max index is %", tt.i, tt.j, tt.k, mesh.positions.count-1);
            }
        }
    } else {
        return false, "Invalid indices in mesh connectivity array";
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

add_triangle :: (using mesh : *Mesh, triangle : Triangle3) {
    array_add(*mesh.indices, xx mesh.indices.count);
    array_add(*mesh.indices, xx mesh.indices.count);
    array_add(*mesh.indices, xx mesh.indices.count);
    array_add(*mesh.positions, triangle.a);
    array_add(*mesh.positions, triangle.b);
    array_add(*mesh.positions, triangle.c);
}

// @FIXME Make sure to account for transforms!
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

// @FIXME Add a $world_space argument
bounding_box :: (using mesh : Mesh) -> AxisBox3 #must {
    box : AxisBox3;
    for * mesh.positions {
        expand(*box, it);
    }
    return box;
}

// @FIXME Add a $world_space argument. WTF is the transform argument??
bounding_box :: (using mesh : Mesh, transform : Matrix4) -> AxisBox3 #must {
    box : AxisBox3;
    for point_model : mesh.positions {
        point_transformed := (transform * make_vector4(point_model, 1)).xyz;
        expand(*box, point_transformed);
    }
    return box;
}

// @FIXME This transform should just update world_from_model???
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