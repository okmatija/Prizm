// Axis-Aligned Bounding Box tree to accelerate spatial queries.
// 
// To add support for a new `Shape` you need to implement the following functions:
//
// get_primitive
// get_primitive_center
// get_primitive_aabb
// get_primitive_index_array
// find_intersect_primitive_ray3
// find_intersect_aabb_ray3
//
// Supported queries:
//
// first_primitive_intersection
// all_primitive_intersections
// any_primitive_intersection
// test_primitive_intersection
// find_closest_point
//
// @Incomplete maybe we should have function pointers stored in a struct for the above, could test if some operations are supported by checking if the pointer is null
// nocommit @Incomplete Handle point clouds
AABB_Tree :: struct(Shape : Type) {

    // Implment object median split?

    LEAF_MAX_PRIMITIVES_COUNT :: 10_000_000; // nocommit @Incomplete make this configurable e.g., see Hash_Table.jai implementation

    // Types that depend on the Shape (Index is included since its interpretation depends on the Shape)
    // @CompilerBug Unable to use #run syntactic abbreviation here
    Primitive, Vector, AABB :: #run () -> (Type, Type, Type) {
        if Shape == {
            case; compiler_report(tprint("AABB_Tree unsupported for shape with type '%'.", Shape)); #through;

            case Polyline_Soup3; return Segment3,  Vector3, AxisBox3;
            case Polyline_Soup2; return Segment2,  Vector3, AxisBox3;
            case Polygon_Soup;   return Segment3,  Vector3, AxisBox3;
            case Mesh;           return Triangle3, Vector3, AxisBox3;
        }
    }();

    // This is an index into `shape`, it is defined implicitly by the `get_primitive` function overload
    Primitive_Id :: int;

    Primitive_Info :: struct {
        aabb : AABB;
        center : Vector;
        primitive_id : Primitive_Id;
    }

    Primitive_Filter :: struct {
        // Returns true if the primitive should be skipped
        Filter_Proc :: #type (ray : Ray3, primitive_id : int, primitive : Primitive, user_data : *void) -> bool;

        proc : Filter_Proc = null;
        data : *void = null;
    }

    Intersection_Ray3_Primitive :: struct {
        t : float = FLOAT32_INFINITY;
        point : Vector;
        primitive_id : Primitive_Id = -1;
    }

    // @Speed Could reduce the size of this struct e.g., by storing indices into `nodes`, rather than 64 bit pointers
    Node :: struct {
        primitives : [..]Primitive_Info;
        aabb : AABB; 

        // These point into the `nodes` array, they are not owning pointers
        left : *Node;
        right : *Node;
    }

    nodes : [..]Node;
    shape : *Shape;
}

init :: (using tree : *$T/AABB_Tree, target : *T.Shape) {
    primitive_ids := get_primitive_index_array(<< target);
    defer array_free(primitive_ids);

    // Sort by 

    tree.shape = target;

    build(tree, primitive_ids);
}

deinit :: (using tree : *$T/AABB_Tree) {
    for node : nodes {
        array_reset(*node.primitives);
    }
    array_reset(*nodes);
}

first_primitive_intersection :: (using tree : AABB_Tree(Mesh), ray : Ray3, filter : tree.Primitive_Filter = .{}) -> is_hit : bool, tree.Intersection_Ray3_Primitive {
    result : Intersection_Ray3_Primitive;

    if tree.nodes.count == 0 {
        return false, .{};
    }

    stack : [..]*AABB_Tree(Mesh).Node;

    // Push the root node onto the stack
    array_add(*stack, *tree.nodes[0]);

    while stack.count {
        node := pop(*stack);
        if is_leaf(<<node) {
            hit_aabb, t_aabb, point_aabb := find_intersect_aabb_ray3(node.aabb, ray);
            if hit_aabb {
                for * info : node.primitives {
                    primitive := get_primitive(tree, info.primitive_id);
                    if filter.proc && filter.proc(ray, info.primitive_id, primitive, filter.data) {
                        continue;
                    }
                    hit_primitive, t_primitive, point_primitive := find_intersect_primitive_ray3(primitive, ray);
                    if hit_primitive && t_primitive < result.t {
                        result.t = t_primitive;
                        result.point = point_primitive;
                        result.primitive_id = info.primitive_id;
                    }
                }
            }
        } else {
            assert(false); // @Incomplete

            // child0 := *tree.nodes[node.child[0]];
            // child1 := *tree.nodes[node.child[1]];
            // hit1 := intersect(ray, child1.bbox);
        }
    }
    
    is_hit := result.primitive_id >= 0;
    return is_hit, result;
}

#scope_file // AABB_Tree(Mesh) implementation

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

#scope_file // AABB_Tree(Polyline_Soup3) implementation

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

#scope_file // AABB_Tree(Polyline_Soup2) implementation

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

#scope_file // AABB_Tree(Polygon_Soup) implementation

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

#scope_file // AABB_Tree implementation details

build :: (using tree : *$T/AABB_Tree, primitive_ids : [..]int) {

    if primitive_ids.count <= LEAF_MAX_PRIMITIVES_COUNT {
        add_leaf_node(tree, primitive_ids);
        return;
    }

    assert(false); // @Incomplete, testing aabb intersection
    return;

    // make an array of indices identifying primitives in the shape
    // call build with this array:
    //   find aabb of all primitives
    //   if the number of primitives is less than LEAF_MAX_PRIMITIVES_COUNT
    //     make a leaf
    //   else 
    //     using a splitting rule e.g., primitive count along an axis sort the primitives into two batches
    //     recurse to build function
}

// is_leaf :: (node : AABB_Tree($T).Node) -> bool { // @CompilerBug
is_leaf :: (node : $T) -> bool {
    return node.left == null /* && node.right == null */;
}

add_leaf_node :: (using tree : *$T/AABB_Tree, primitive_ids : [..]int) {
    node := array_add(*tree.nodes);

    for primitive_ids {
        primitive := get_primitive(<<tree, it);

        info := array_add(*node.primitives);
        info.aabb = get_primitive_aabb(primitive);
        info.center = get_primitive_center(primitive);
        info.primitive_id = it;

        expand(*node.aabb, info.aabb);
    }
}