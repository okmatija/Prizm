
// AABB_Tree(Mesh) implementation

get_primitive :: (tree : AABB_Tree(Mesh), triangle_index : int) -> Triangle3 {
    return inline get_triangle(<<tree.shape, triangle_index);
}

get_primitive_center :: (triangle : Triangle3) -> Vector3 {
    return (triangle.a + triangle.b + triangle.c) / 3.;
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

// AABB_Tree(Point_Cloud) implementation

get_primitive :: (tree : AABB_Tree(Point_Cloud), point_index : int) -> Vector3 {
    assert(false, "@Incomplete");
    return .{};
}

get_primitive_center :: (point : Vector3) -> Vector3 {
    return point;
}

get_primitive_aabb :: (point : Vector3) -> AxisBox3 {
    return make_axis_box3(point, point);
}

get_primitive_index_array :: (cloud : Point_Cloud) -> [..]int {
    result : [..]int;
    array_reserve(*result, cloud.positions.count);
    for 0..cloud.positions.count-1 {
        array_add(*result, it);
    }
    return result;
}

find_intersect_primitive_ray3 :: (point : Vector3, ray : Ray3) ->  is_hit : bool, t : float, point : Vector3 {
    assert(false, "@Incomplete");
    return false, 0, .{};
}

// find_intersect_aabb_ray3 :: (aabb : AxisBox3, ray : Ray3) -> is_hit : bool, t : float, point : Vector3

// AABB_Tree(Polyline_Soup3) implementation

get_primitive :: (tree : AABB_Tree(Polyline_Soup3), triangle_index : int) -> Segment3 {
    assert(false, "@Incomplete");
    return .{};
}

get_primitive_center :: (segment : Segment3) -> Vector3 {
    assert(false, "@Incomplete");
    return .{};
}

get_primitive_aabb :: (segment : Segment3) -> AxisBox3 {
    assert(false, "@Incomplete");
    return .{};
}

get_primitive_index_array :: (soup : Polyline_Soup3) -> [..]int {
    assert(false, "@Incomplete");
    dummy : [..]int;
    return dummy;
}

find_intersect_primitive_ray3 :: (segment : Segment3, ray : Ray3) ->  is_hit : bool, t : float, point : Vector3 {
    assert(false, "@Incomplete");
    return false, 0, .{};
}

// find_intersect_aabb_ray3 :: (aabb : AxisBox3, ray : Ray3) -> is_hit : bool, t : float, point : Vector3

// AABB_Tree(Polyline_Soup2) implementation

get_primitive :: (tree : AABB_Tree(Polyline_Soup2), triangle_index : int) -> Segment2 {
    assert(false, "@Incomplete");
    return .{};
}

get_primitive_center :: (segment : Segment2) -> Vector3 {
    assert(false, "@Incomplete");
    return .{};
}

get_primitive_aabb :: (segment : Segment2) -> AxisBox3 {
    assert(false, "@Incomplete");
    return .{};
}

get_primitive_index_array :: (soup : Polyline_Soup2) -> [..]int {
    assert(false, "@Incomplete");
    dummy : [..]int;
    return dummy;
}

find_intersect_primitive_ray3 :: (segment : Segment2, ray : Ray3) ->  is_hit : bool, t : float, point : Vector3 {
    assert(false, "@Incomplete");
    return false, 0, .{};
}

find_intersect_aabb_ray3 :: (aabb : AxisBox2, ray : Ray3) -> is_hit : bool, t : float, point : Vector3 {
    assert(false, "@Incomplete");
    return false, 0, .{};
}

// AABB_Tree(Polygon_Soup) implementation

get_primitive :: (tree : AABB_Tree(Polygon_Soup), triangle_index : int) -> Segment3 {
    assert(false, "@Incomplete");
    return .{};
}

// get_primitive_center :: (segment : Segment3) -> Vector3

// get_primitive_aabb :: (segment : Segment3) -> AxisBox3

get_primitive_index_array :: (soup : Polygon_Soup) -> [..]int {
    assert(false, "@Incomplete");
    dummy : [..]int;
    return dummy;
}

// find_intersect_primitive_ray3 :: (segment : Segment3, ray : Ray3) ->  is_hit : bool, t : float, point : Vector3

// find_intersect_aabb_ray3 :: (aabb : AxisBox3, ray : Ray3) -> is_hit : bool, t : float, point : Vector3