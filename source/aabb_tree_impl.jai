// nocommit Move this into aabb_tree.jai

// AABB_Tree(Mesh) implementation

get_primitive :: (tree : AABB_Tree(Mesh), triangle_index : int) -> Triangle3 {
    return inline mesh_triangle_model(tree.shape, triangle_index);
}

get_primitive_center :: (triangle : Triangle3) -> Vector3 {
    return compute_centroid(triangle);
}

get_primitive_aabb :: (triangle : Triangle3) -> AxisBox3 {
    result : AxisBox3;
    expand(*result, triangle);
    return result;
}

get_primitive_index_array :: (mesh : Mesh) -> [..]int {
    assert(mesh.geometry_format == .TRIANGLES, "Wanted % geometry format, got %", Geometry_Format.TRIANGLES, mesh.geometry_format);
    assert(mesh.indices.count % 3 == 0);

    result : [..]int;

    triangle_count := element_count(mesh);
    array_reserve(*result, triangle_count);
    for 0..triangle_count-1 {
        array_add(*result, it);
    }

    return result;
}

find_intersect_primitive_ray3 :: (triangle : Triangle3, ray : Ray3) ->  is_hit : bool, t : float, point : Vector3 {
    intersect, t, bary, point := find_intersect_ray3_triangle3(ray, triangle);
    return intersect, t, point;
}

find_intersect_aabb_ray3 :: (aabb : AxisBox3, ray : Ray3) -> is_hit : bool, t : float, point : Vector3 {
    result := find_intersect_ray3_axis_box3(ray, aabb);
    i := ifx result.parameter[0] < result.parameter[1] then 0 else 1;
    return result.intersect, result.parameter[i], result.point[i];
}