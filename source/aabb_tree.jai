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

    LEAF_MAX_PRIMITIVES_COUNT :: 32; // @Incomplete make this configurable e.g., see Hash_Table.jai implementation

    // Types that depend on the Shape (Index is included since its interpretation depends on the Shape)
    // @CompilerBug Unable to use #run syntactic abbreviation here
    Primitive, Vector, AABB :: #run () -> (Type, Type, Type) {
        if Shape == {
            case; compiler_report(tprint("AABB_Tree unsupported for shape with type '%'.", Shape));
            #through; // So all control paths return a value

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
        Proc :: #type (ray : Ray3, primitive_id : int, primitive : Primitive, user_data : *void) -> bool;
        proc :  Proc = null;
        data : *void = null;
    }

    Intersection_Filter :: struct {
        // Returns true if the intersection point should be skipped
        Proc :: #type (point : Vector, user_data : *void) -> bool;
        proc :  Proc = null;
        data : *void = null;
    }

    Node_Visitor :: struct {
        // Returns true if the visitation should proceed
        Proc :: #type (node : Node, depth : int, user_data : *void) -> bool;
        proc :  Proc = null;
        data : *void = null;
    }

    Intersection_Ray3_Primitive :: struct {
        t : float = FLOAT32_INFINITY;
        point : Vector;
        primitive_id : Primitive_Id = -1;
    }

    // nocommit @Cleanup Rename to Primitive_Info_Iterator
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
        count : int; // @Cleanup Make type just large enough to address at most LEAF_MAX_PRIMITIVES_COUNT primitives
    }

    // @Speed Could reduce the size of this struct e.g., by storing indices into `nodes`, rather than 64 bit pointers
    Node :: struct {
        range : Primitive_Range;
        aabb : AABB;

        // These are indices, not pointers, because pointers are invalidated when the nodes array resizes
        child_lhs : int = -1;
        child_rhs : int = -1;
    }

    Primitive_Info :: struct {
        primitive_id : Primitive_Id;

        // @Cleanup No need to store these
        aabb : AABB;
        center : Vector;
    }

    nodes : [..]Node;
    primitive_info : [..]Primitive_Info;
    shape : *Shape; // Not an owning pointer
}

init :: (tree : *$T/AABB_Tree, target : *T.Shape) {
    if T.Shape != Mesh return; // nocommit @Incomplete implement other primitive types

    tree.shape = target;

    // @Cleanup Implement this via an iterator over `target` rather than allocating primitive_ids array?
    primitive_ids := get_primitive_index_array(target);
    defer array_free(primitive_ids);

    for primitive_ids {
        primitive := get_primitive(tree, it);

        info := array_add(*tree.primitive_info);
        info.aabb = get_primitive_aabb(primitive);
        info.center = get_primitive_center(primitive);
        info.primitive_id = it; // tree.primitive_info will get jumbled
    }

    iterator :: tree.primitive_info_iterator; // @Cleanup @CompilerBug Should be unecessary

    root := array_add(*tree.nodes);
    root.range.first = 0;
    root.range.count = tree.primitive_info.count;
    for :iterator root.range expand(*root.aabb, it.aabb);
    build(tree, 0, 0);
}

deinit :: (tree : *$T/AABB_Tree) {
    if !tree return;
    array_reset(*tree.primitive_info);
    array_reset(*tree.nodes);
    free(tree);
}

// @Refactor make this a macro and implement the filters as Code
// @CompilerBug We need to pass a pointer to the tree here due to a bug??
first_primitive_intersection :: (using tree : *AABB_Tree(Mesh), ray : Ray3, primitive_filter : tree.Primitive_Filter = .{}, intersection_filter : tree.Intersection_Filter = .{}) -> is_hit : bool, tree.Intersection_Ray3_Primitive {
    result : Intersection_Ray3_Primitive;

    if tree.nodes.count == 0 {
        return false, .{};
    }

    // Only nodes whose AABBs are intersected by the ray will be pushed onto the stack
    stack : [..]int;
    defer array_reset(*stack);

    iterator :: tree.primitive_info_iterator; // @Cleanup @CompilerBug Should be unecessary

    root := *tree.nodes[0];
    root_hit_aabb, root_t_aabb, root_point_aabb := find_intersect_aabb_ray3(root.aabb, ray);
    if root_hit_aabb {
        array_add(*stack, 0);
    }

    while stack.count {
        node_index := pop(*stack);
        node := nodes[node_index];
        if node.child_lhs == -1 {
            assert(node.child_rhs == -1); // @Refactor Implement an ensure-like macro which just logs a warning

            // Visit primitives in leaf node

            for :iterator info : node.range {
                primitive := get_primitive(tree, info.primitive_id);

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
        } else {
            // Traverse internal node

            lhs_hit_aabb, lhs_t_aabb, lhs_point_aabb := find_intersect_aabb_ray3(nodes[node.child_lhs].aabb, ray);
            rhs_hit_aabb, rhs_t_aabb, rhs_point_aabb := find_intersect_aabb_ray3(nodes[node.child_rhs].aabb, ray);

            if lhs_hit_aabb && rhs_hit_aabb {
                // Recurse closer box first
                if lhs_t_aabb < rhs_t_aabb {
                    array_add(*stack, node.child_lhs);
                    array_add(*stack, node.child_rhs);
                } else {
                    array_add(*stack, node.child_rhs);
                    array_add(*stack, node.child_lhs);
                }
            } else if  lhs_hit_aabb && !rhs_hit_aabb {
                array_add(*stack, node.child_lhs);
            } else if !lhs_hit_aabb &&  rhs_hit_aabb {
                array_add(*stack, node.child_rhs);
            }
        }
    }

    is_hit := result.primitive_id >= 0;
    return is_hit, result;
}

// Simple tree traversal, if you want more precise control e.g., over which child is visited first (see first_primitive_intersection)
// you may want to write a sepecialized function
depth_first_visit :: (using tree : $T/AABB_Tree, visitor : T.Node_Visitor) {
    if tree.nodes.count == 0 {
        return;
    }

    assert(visitor.proc != null);

    Entry :: struct {
        node_index : int;
        depth : int;
    }

    iterator :: tree.primitive_info_iterator; // @Cleanup @CompilerBug Should be unecessary

    stack : [..]Entry;
    defer array_free(stack);
    array_add(*stack, .{0, 0});

    while stack.count {
        entry := pop(*stack);
        node := *nodes[entry.node_index];

        if visitor.proc(node, entry.depth, visitor.data) == false {
            break;
        }

        if node.child_lhs != -1 {
            assert(node.child_rhs != -1); // @Refactor Implement an ensure-like macro which just logs a warning

            child_lhs_entry := array_add(*stack);
            child_lhs_entry.node_index = node.child_lhs;
            child_lhs_entry.depth = entry.depth + 1;

            child_rhs_entry := array_add(*stack);
            child_rhs_entry.node_index = node.child_rhs;
            child_rhs_entry.depth = entry.depth + 1;
        }
    }
}

#scope_file // AABB_Tree implementation details

build :: (using tree : *$T/AABB_Tree, depth : int, parent : int) {

    if nodes[parent].range.count <= LEAF_MAX_PRIMITIVES_COUNT {
        return; // parent is a leaf node
    }

    axis := depth % 3;

    primitive_info_range := array_view(tree.primitive_info, nodes[parent].range.first, nodes[parent].range.count);

    interval : [2]float = .[FLOAT32_MAX, -FLOAT32_MAX];
    for *info : primitive_info_range {
        interval[0] = min(interval[0], info.center.component[axis]);
        interval[1] = max(interval[1], info.center.component[axis]);
    }

    midindex := primitive_info_range.count  / 2; // Default to object median split

    if abs(interval[1] - interval[0]) > 1.e-6 {
        // Partition at midpoint by walking inwards from each side swapping if primitive center < midpoint
        midpoint := (interval[1] + interval[0]) / 2;
        lower, upper := 0, primitive_info_range.count-1;
        while lower < upper {
            while primitive_info_range[lower].center.component[axis] <= midpoint {
                lower += 1;
            }
            while primitive_info_range[upper].center.component[axis] >  midpoint {
                upper -= 1;
            }
            if lower >= upper {
                break;
            } else {
                primitive_info_range[lower], primitive_info_range[upper] = swap(primitive_info_range[lower], primitive_info_range[upper]);
            }
        }

        midindex = lower;
    }

    iterator :: tree.primitive_info_iterator; // @Cleanup @CompilerBug Should be unecessary

    child_lhs_index : int = -1;
    {
        child_lhs_index = tree.nodes.count;
        child_lhs := array_add(*tree.nodes);

        child_lhs.range.first = nodes[parent].range.first;
        child_lhs.range.count = midindex;
        for :iterator child_lhs.range {
            expand(*child_lhs.aabb, it.aabb);
        }
    }
    nodes[parent].child_lhs = child_lhs_index;

    child_rhs_index : int = -1;
    {
        child_rhs_index = tree.nodes.count;
        child_rhs := array_add(*tree.nodes);

        // Scoping intentional here, previous child_lhs is invalid because tree.nodes may resize
        child_lhs := tree.nodes[child_lhs_index];

        child_rhs.range.first = child_lhs.range.first + child_lhs.range.count;
        child_rhs.range.count = nodes[parent].range.count - child_lhs.range.count;
        for :iterator child_rhs.range {
            expand(*child_rhs.aabb, it.aabb);
        }

    }
    nodes[parent].child_rhs = child_rhs_index;

    build(tree, depth + 1, child_lhs_index);
    build(tree, depth + 1, child_rhs_index);
}