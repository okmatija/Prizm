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
AABB_Tree :: struct(Shape : Type) {

    // Implment round-robin object median split?

    LEAF_MAX_PRIMITIVES_COUNT :: 10_000_000; // nocommit @Incomplete make this configurable e.g., see Hash_Table.jai implementation

    // Types that depend on the Shape (Index is included since its interpretation depends on the Shape)
    // @CompilerBug Unable to use #run syntactic abbreviation here
    Primitive, Vector, AABB :: #run () -> (Type, Type, Type) {
        if Shape == {
            case; compiler_report(tprint("AABB_Tree unsupported for shape with type '%'.", Shape)); #through;

            case Polyline_Soup3; return Segment3,  Vector3, AxisBox3;
            case Polyline_Soup2; return Segment2,  Vector3, AxisBox3;
            case Polygon_Soup;   return Segment3,  Vector3, AxisBox3;
            case Point_Cloud;    return Vector3,   Vector3, AxisBox3;
            case Mesh;           return Triangle3, Vector3, AxisBox3;
        }
    }();

    // This is an index into `shape`, it is defined implicitly by the `get_primitive` function overload
    Primitive_Id :: int;

    Primitive_Filter :: struct {
        // Returns true if the primitive should be skipped
        Filter_Proc :: #type (ray : Ray3, primitive_id : int, primitive : Primitive, user_data : *void) -> bool;

        proc : Filter_Proc = null;
        data : *void = null;
    }

    Intersection_Filter :: struct {
        // Returns true if the intersection point should be skipped
        Filter_Proc :: #type (point : Vector, user_data : *void) -> bool;

        proc : Filter_Proc = null;
        data : *void = null;
    }

    Intersection_Ray3_Primitive :: struct {
        t : float = FLOAT32_INFINITY;
        point : Vector;
        primitive_id : Primitive_Id = -1;
    }

    primitive_info_iterator :: (range : *Primitive_Range, body : Code, flags : For_Flags) #expand {
        #assert(flags == 0);
        for i : 0..range.count-1 {
            `it_index := range.first + i;
            `it := `tree.primitive_info[it_index];
            #insert (remove=#assert(false), break=break i) body;
        }
    }

    Primitive_Range :: struct {
        first : int;
        count : int; // @Cleanup make type just large enough to address at most LEAF_MAX_PRIMITIVES_COUNT primitives
    }

    // @Speed Could reduce the size of this struct e.g., by storing indices into `nodes`, rather than 64 bit pointers
    Node :: struct {
        aabb : AABB; 
        range : Primitive_Range;

        // These point into the `nodes` array, not owning pointers
        left : *Node;
        right : *Node;
    }
    nodes : [..]Node;

    Primitive_Info :: struct {
        aabb : AABB;
        center : Vector;
        primitive_id : Primitive_Id;
    }
    primitive_info : [..]Primitive_Info;

    shape : *Shape; // not owning pointer
}

init :: (using tree : *$T/AABB_Tree, target : *T.Shape) {
    // nocommit
    if T.Shape != Mesh return;

    tree.shape = target;

    // @Cleanup Implement this via an iterator over `target` rather than allocating primitive_ids array?
    primitive_ids := get_primitive_index_array(<< target);
    defer array_free(primitive_ids);

    for primitive_ids {
        primitive := get_primitive(<<tree, it);

        info := array_add(*tree.primitive_info);
        info.aabb = get_primitive_aabb(primitive);
        info.center = get_primitive_center(primitive);
        info.primitive_id = it; // tree.primitive_info will get jumbled
    }

    range : T.Primitive_Range = ---;
    range.first = 0;
    range.count = tree.primitive_info.count;
    build(tree, range);
}

deinit :: (using tree : *$T/AABB_Tree) {
    array_reset(*primitive_info);
    array_reset(*nodes);
}

// @CompilerBug We need to pass a pointer to the tree here due to a bug??
first_primitive_intersection :: (using tree : *AABB_Tree(Mesh), ray : Ray3, primitive_filter : tree.Primitive_Filter = .{}, intersection_filter : tree.Intersection_Filter = .{}) -> is_hit : bool, tree.Intersection_Ray3_Primitive {
    result : Intersection_Ray3_Primitive;

    if tree.nodes.count == 0 {
        return false, .{};
    }

    stack : [..]*AABB_Tree(Mesh).Node;
    defer array_reset(*stack);

    // Push the root node onto the stack
    array_add(*stack, *tree.nodes[0]);

    while stack.count {
        node := pop(*stack);
        if is_leaf(<<node) {
            hit_aabb, t_aabb, point_aabb := find_intersect_aabb_ray3(node.aabb, ray);
            if hit_aabb {
                iterator :: tree.primitive_info_iterator; // @CompilerBug Why did this not work?
                for :iterator info : node.range {
                    primitive := get_primitive(<<tree, info.primitive_id);

                    if primitive_filter.proc && primitive_filter.proc(ray, info.primitive_id, primitive, primitive_filter.data) {
                        continue;
                    }

                    is_hit, t, point := find_intersect_primitive_ray3(primitive, ray);

                    if is_hit == false || t >= result.t {
                        continue;
                    }

                    if intersection_filter.proc && intersection_filter.proc(point, intersection_filter.data) {
                        continue;
                    }

                    result.t = t;
                    result.point = point;
                    result.primitive_id = info.primitive_id;
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

#scope_file // AABB_Tree implementation details

build :: (using tree : *$T/AABB_Tree, range : T.Primitive_Range) {

    if range.count <= LEAF_MAX_PRIMITIVES_COUNT {
        iterator :: tree.primitive_info_iterator;

        node := array_add(*tree.nodes);
        node.range = range;
        for :iterator info : range {
            expand(*node.aabb, info.aabb);
        }

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