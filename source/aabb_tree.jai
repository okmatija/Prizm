// FIXME make it only work with elements and add points to unreferenced vertex elements. Maybe also put the vertex theme into the element themes so that everything can work on element granularity

// Axis-Aligned Bounding Box tree to accelerate spatial queries.
//
// To add support for a new `Shape` you need to implement the following functions:
//
// get_element
// get_element_center
// get_element_aabb
// get_element_index_array
// find_intersect_element_ray3
// find_intersect_aabb_ray3
//
// Supported queries:
//
// first_element_intersection
// all_element_intersections
// any_element_intersection
// test_element_intersection
// find_closest_element
//
// @Incomplete maybe we should have function pointers stored in a struct for the above, could test if some operations are supported by checking if the pointer is null
AABB_Tree :: struct {

    // Implement round-robin object median split?

    LEAF_MAX_PRIMITIVES_COUNT :: 32; // @Incomplete make this configurable e.g., see Hash_Table.jai implementation

    // Types that depend on the Shape (Index is included since its interpretation depends on the Shape)
    // @CompilerBug Unable to use #run syntactic abbreviation here
    Element, Vector, AABB :: Triangle3, Vector3, AxisBox3; // @Cleanup

    // This is an index into `shape`, it is defined implicitly by the `get_element` function overload
    Element_Id :: int; // @Cleanup remove this typedef...

    Node_Visitor :: struct {
        // Returns true if the visitation should proceed
        Proc :: #type (node : Node, depth : int, user_data : *void) -> bool;

        proc :  Proc = null;
        data : *void = null;
    }

    // @Think could have t and point in a base struct which is then #as using'd in this one 
    Intersection_Ray3_Element :: struct {
        t : float = FLOAT32_INFINITY;
        point : Vector;
        element_id : int = -1;
    }

    Element_Info_Iterator :: (range : *Element_Range, body : Code, flags : For_Flags) #expand {
        #assert(flags == 0);
        for i : 0..range.count-1 {
            `it_index := range.first + i;
            `it := `tree.element_info[it_index];
            #insert (remove=#assert(false), break=break i) body;
        }
    }

    Element_Range :: struct {
        first : int;
        count : int; // @Cleanup Make type just large enough to address at most LEAF_MAX_PRIMITIVES_COUNT elements
    }

    // @Speed Could reduce the size of this struct e.g., by storing indices into `nodes`, rather than 64 bit pointers
    Node :: struct {
        range : Element_Range;
        aabb : AABB;

        // These are indices, not pointers, because pointers are invalidated when the nodes array resizes
        child_lhs : int = -1;
        child_rhs : int = -1;
    }

    Element_Info :: struct {
        element_id : Element_Id;
        aabb : AABB;
        center : Vector;
    }

    nodes : [..]Node;
    element_info : [..]Element_Info;
    shape : *Simple_Mesh; // Borrowed
}

init :: (tree : *AABB_Tree, target : *Simple_Mesh) {
    tree.shape = target;

    // @Cleanup Implement this via an iterator over `target` rather than allocating element_ids array?
    element_ids : [..]int = get_element_index_array(target);
    defer array_free(element_ids);

    for element_ids {
        element := get_element(tree, it);

        info := array_add(*tree.element_info);
        info.aabb = get_element_aabb(element);
        info.center = get_element_center(element);
        info.element_id = it; // tree.element_info will get jumbled
    }

    root := array_add(*tree.nodes);
    root.range.first = 0;
    root.range.count = tree.element_info.count;
    for :tree.Element_Info_Iterator root.range {
        expand(*root.aabb, it.aabb);
    }
    build(tree, 0, 0);
}

deinit :: (tree : *AABB_Tree) {
    if !tree return;
    array_reset(*tree.element_info);
    array_reset(*tree.nodes);
    free(tree);
}

// @CompilerBug We need to pass a pointer to the tree here due to a bug??
visit_elements_triangles_ray :: (
    using tree : *AABB_Tree,
    ray : Ray3,
    visit_triangle : (Triangle3, int, *void)->(),
    visit_triangle_data : *void) {

    if tree.nodes.count == 0 {
        return;
    }

    // Only nodes whose AABBs are intersected by the ray will be pushed onto the stack
    stack : [..]int;
    defer array_reset(*stack);

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

            // Visit elements in leaf node
            // Note: We don't use tree.Element_Info_Iterator so that the inserted code can use backtick to refer to the callers' scope
            for 0..node.range.count-1 {

                triangle_index : int = tree.element_info[node.range.first + it].element_id;
                triangle : Triangle3 = get_element(tree, triangle_index);
                visit_triangle(triangle, triangle_index, visit_triangle_data);

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
}

// Note: the ray is expected to be in the model space of the mesh, since the tree is constructed from the model space mesh
// @Cleanup Look into refactoring this macro so it works like an iterator i.e., we'd like to write something like this instead:
//
// for :visit_elements_near_ray tree {
//     VISIT_PRIMITIVE(it, it_index);
// }
// 
visit_elements_near_ray :: (
    using tree : *AABB_Tree,
    ray : Ray3,
    distance : float,
    visit_triangle : (Triangle3, int, *void)->(),
    visit_triangle_data : *void) {

    if tree.nodes.count == 0 || !is_finite(distance) {
        return;
    }

    if app.debug_frame {
        log_error("Debugging visit_elements_near_ray");
    }

    // Only nodes whose AABBs are intersected by the ray will be pushed onto the stack
    stack : [..]int;
    defer array_reset(*stack);

    root := *tree.nodes[0];

    // Determine if the elements in this box are near the ray by offsetting the box by the query distance, we'll end up visiting some boxes that we neednt
    // @Speed Maybe distance ray-box will be more efficient?
    offset_aabb := root.aabb;
    offset(*offset_aabb, distance);
    root_hit_aabb, root_t_aabb, root_point_aabb := find_intersect_aabb_ray3(offset_aabb, ray);
    if root_hit_aabb {
        array_add(*stack, 0);
    }

    while stack.count {
        node_index : int = pop(*stack);
        node : Node = nodes[node_index];
        if node.child_lhs == -1 {
            assert(node.child_rhs == -1); // @Refactor Implement an ensure-like macro which just logs a warning

            // Visit elements in leaf node

            // Note: We don't use tree.Element_Info_Iterator so that the inserted code can use backtick to refer to the callers' scope
            for 0..node.range.count-1 {

                triangle_index : int = tree.element_info[node.range.first + it].element_id;
                triangle : Triangle3 = get_element(tree, triangle_index); // Model space
                visit_triangle(triangle, triangle_index, visit_triangle_data);

            }
        } else {
            // Traverse internal node

            lhs_offset_aabb := nodes[node.child_lhs].aabb;
            offset(*lhs_offset_aabb, distance);
            lhs_hit_aabb, lhs_t_aabb, lhs_point_aabb := find_intersect_aabb_ray3(lhs_offset_aabb, ray);

            rhs_offset_aabb := nodes[node.child_rhs].aabb;
            offset(*rhs_offset_aabb, distance);
            rhs_hit_aabb, rhs_t_aabb, rhs_point_aabb := find_intersect_aabb_ray3(rhs_offset_aabb, ray);

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
}

// Simple tree traversal, if you want more precise control e.g., over which child is visited first (see first_element_intersection)
// you may want to write a sepecialized function
// @Cleanup Use a macro rather than hacking a closure
depth_first_visit :: (using tree : AABB_Tree, visitor : tree.Node_Visitor) {
    if tree.nodes.count == 0 {
        return;
    }

    assert(visitor.proc != null);

    Entry :: struct {
        node_index : int;
        depth : int;
    }

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




get_element :: (tree : AABB_Tree, triangle_index : int) -> Triangle3 {
    return inline mesh_triangle_model(tree.shape, triangle_index);
}

get_element_center :: (triangle : Triangle3) -> Vector3 {
    return compute_centroid(triangle);
}

get_element_aabb :: (triangle : Triangle3) -> AxisBox3 {
    result : AxisBox3;
    expand(*result, triangle);
    return result;
}

get_element_index_array :: (mesh : Simple_Mesh) -> [..]int {
    result : [..]int;

    triangle_count := mesh.triangles.count;
    array_reserve(*result, triangle_count);
    for 0..triangle_count-1 {
        array_add(*result, it);
    }

    return result;
}

find_intersect_element_ray3 :: (triangle : Triangle3, ray : Ray3) ->  is_hit : bool, t : float, point : Vector3 {
    intersect, t, bary, point := find_intersect_ray3_triangle3(ray, triangle);
    return intersect, t, point;
}

find_intersect_aabb_ray3 :: (aabb : AxisBox3, ray : Ray3) -> is_hit : bool, t : float, point : Vector3 {
    result := find_intersect_ray3_axis_box3(ray, aabb);
    i := ifx result.parameter[0] < result.parameter[1] then 0 else 1;
    return result.intersect, result.parameter[i], result.point[i];
}




#scope_file // AABB_Tree implementation details

build :: (using tree : *AABB_Tree, depth : int, parent : int) {

    if nodes[parent].range.count <= LEAF_MAX_PRIMITIVES_COUNT {
        return; // parent is a leaf node
    }

    // @Bug FIXME Changing this to modulo 2 triggers an assert for the flat shield mesh
    axis := depth % 3;

    element_info_range := array_view(tree.element_info, nodes[parent].range.first, nodes[parent].range.count);

    interval : [2]float = .[FLOAT32_MAX, -FLOAT32_MAX];
    for *info : element_info_range {
        interval[0] = min(interval[0], info.center.component[axis]);
        interval[1] = max(interval[1], info.center.component[axis]);
    }

    midindex := element_info_range.count  / 2; // Default to object median split

    if interval[1] > interval[0] && !almost_equal(interval[0], interval[1]) {
        // Partition at midpoint by walking inwards from each side swapping if element center < midpoint
        midpoint := (interval[1] + interval[0]) / 2;
        lower, upper := 0, element_info_range.count-1;
        while lower < upper {
            while element_info_range[lower].center.component[axis] <= midpoint {
                lower += 1;
            }
            while element_info_range[upper].center.component[axis] >  midpoint {
                upper -= 1;
            }
            if lower >= upper {
                break;
            } else {
                element_info_range[lower], element_info_range[upper] =  element_info_range[upper], element_info_range[lower];
            }
        }

        midindex = lower;
    }

    child_lhs_index : int = -1;
    {
        child_lhs_index = tree.nodes.count;
        child_lhs := array_add(*tree.nodes);

        child_lhs.range.first = nodes[parent].range.first;
        child_lhs.range.count = midindex;
        for :tree.Element_Info_Iterator child_lhs.range {
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
        for :tree.Element_Info_Iterator child_rhs.range {
            expand(*child_rhs.aabb, it.aabb);
        }

    }
    nodes[parent].child_rhs = child_rhs_index;

    build(tree, depth + 1, child_lhs_index);
    build(tree, depth + 1, child_rhs_index);
}