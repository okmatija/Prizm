// @Cleanup Maybe this should be a debug command only

// Adds items to visualize the spatial index of the given item
// `jumbo_item`    if true only one item is added is the distance between adjacent grid points in each world axes direction
debug_spatial_index :: (index : int, jumbo_item : int = 1) {
    if !check_geometry_index(index) {
        return;
    }

    if app.entities[index].type != .MESH {
        log_error("@Incomplete Currently only % type is supported, got %.", Entity_Type.MESH, app.entities[index].type);
        return;
    }

    mesh_entity := cast(*Mesh_Entity)app.entities[index];
    spatial := *mesh_entity.spatial;

    if spatial.nodes.count == 0 {
        return;
    }

    Iterator :: spatial.primitive_info_iterator; // nocommit @Cleanup

    if jumbo_item {
        // Put all AABBs into a single polyline soup
        shape : Polyline_Soup3;
        for spatial.nodes {
            polyline_aabb := to_polyline_soup(it.aabb);
            for polyline : polyline_aabb.polylines {
                shape_polyline := array_add(*shape.polylines);
                <<shape_polyline = polyline;
            }
        }

        entity := New(Polyline_Soup3_Entity);
        assert(entity != null);

        entity.shape = shape;
        entity.mesh = to_Mesh(entity.shape);
        init_entity_base_parameters(entity, tprint("%_debug_spatial", mesh_entity.fully_pathed_filename), entity.mesh);
        array_add(*app.entities, entity);
    } else {
        // Internal nodes will be polyline soup entities showing AABBs
        // Leaf nodes will be mesh entitites so that the AABB and primitive data can be shown
        entity_at_depth : Table(int, *Entity);

        append_to_entity_at_depth :: (node : spatial.Node, depth : int, user_data : *void) -> bool {
            using data := cast(*Visitor_Data)user_data;

            if node.child_lhs == -1 {
                assert(node.child_rhs == -1); // @Refactor Implement an ensure-like macro which just logs a warning

                // Leaf

                found := table_find_pointer(entity_at_depth, depth);

                if found == null {
                    entity := New(Mesh_Entity);
                    assert(entity != null);

                    entity.mesh = to_edge_Mesh(node.aabb);
                    init_entity_base_parameters(entity, tprint("%_debug_spatial_%", fully_pathed_filename, depth), entity.mesh); // @Incomplete pad depth integer?

                    {
                        using primitives : Mesh;
                        defer deinit(*primitives);
                        for :Iterator info : node.range {
                            tri := get_primitive(tree, info.primitive_id);
                            array_add(*indices, xx indices.count); array_add(*positions, tri.a);
                            array_add(*indices, xx indices.count); array_add(*positions, tri.b);
                            array_add(*indices, xx indices.count); array_add(*positions, tri.c);
                        }
                        merge(entity.mesh, primitives);
                    }

                    table_add(entity_at_depth, depth, entity);
                } else {
                    entity_base := <<found;
                    assert(entity_base.type == .MESH);
                    entity := cast(*Mesh_Entity)entity_base;
                    entity.render_info.is_dirty = true; // Redundant

                    {
                        using primitives : Mesh;
                        defer deinit(*primitives);
                        for :Iterator info : node.range {
                            tri := get_primitive(tree, info.primitive_id);
                            array_add(*indices, xx indices.count); array_add(*positions, tri.a);
                            array_add(*indices, xx indices.count); array_add(*positions, tri.b);
                            array_add(*indices, xx indices.count); array_add(*positions, tri.c);
                        }
                        merge(entity.mesh, primitives);
                    }

                    {
                        using edges : Mesh = to_edge_Mesh(node.aabb);
                        defer deinit(*edges);
                        merge(entity.mesh, edges);
                    }

                }


            } else {
                // Internal

                found := table_find_pointer(entity_at_depth, depth);

                if found == null {
                    entity := New(Mesh_Entity);
                    assert(entity != null);

                    entity.mesh = to_edge_Mesh(node.aabb);
                    init_entity_base_parameters(entity, tprint("%_debug_spatial_%", fully_pathed_filename, depth), entity.mesh); // @Incomplete pad depth integer?

                    table_add(entity_at_depth, depth, entity);
                } else {
                    entity_base := <<found;
                    assert(entity_base.type == .MESH);

                    other := to_edge_Mesh(node.aabb);
                    defer deinit(*other);

                    entity := cast(*Mesh_Entity)entity_base;
                    merge(entity.mesh, other);
                    entity.render_info.is_dirty = true; // Redundant
                }
            }

            return true; // Continue visitation
        }

        Visitor_Data :: struct {
            entity_at_depth : *Table(int, *Entity);
            fully_pathed_filename : string;
            tree : *AABB_Tree(Mesh); // Needed so iterator can work
        }
        visitor_data : Visitor_Data;
        visitor_data.entity_at_depth = *entity_at_depth;
        visitor_data.fully_pathed_filename = mesh_entity.fully_pathed_filename;
        visitor_data.tree = spatial;

        visitor : spatial.Node_Visitor;
        visitor.proc = append_to_entity_at_depth;
        visitor.data = *visitor_data;
        depth_first_visit(<<spatial, visitor); // @CompilerBug why can't I implicit pointer dereference here?

        Entity_At_Depth :: struct {
            depth : int;
            entity : *Entity;
        }

        sorted_by_depth : [..]Entity_At_Depth;
        defer array_free(sorted_by_depth);

        // nocommit what the heck is going on, is depth the index??
        for entity, depth : entity_at_depth {
            entry := array_add(*sorted_by_depth);
            entry.depth = depth;
            entry.entity = entity;
        }

        quick_sort(sorted_by_depth, x=>x.depth);

        for sorted_by_depth {
            array_add(*app.entities, it.entity);
        }
    }
} @RegisterCommand

#scope_file

to_edge_Mesh :: (using box : AxisBox3) -> Mesh #must {
    mesh : Mesh;
    mesh.geometry_format = .TRIANGLES;

    Add_Edge_As_Degenerate_Triangle :: (a : Corner3, b : Corner3) #expand {
        offset : u32 = xx mesh.positions.count;
        array_add(*mesh.positions, corner(box, a));
        array_add(*mesh.indices, offset);
        array_add(*mesh.positions, corner(box, b));
        array_add(*mesh.indices, offset + 1);
        array_add(*mesh.positions, corner(box, a));
        array_add(*mesh.indices, offset + 2);
    }

    // Edges starting in the XY plane extending from Z=0 to Z=1
    Add_Edge_As_Degenerate_Triangle(.XYZ_000, .XYZ_001);
    Add_Edge_As_Degenerate_Triangle(.XYZ_010, .XYZ_011);
    Add_Edge_As_Degenerate_Triangle(.XYZ_100, .XYZ_101);
    Add_Edge_As_Degenerate_Triangle(.XYZ_110, .XYZ_111);

    // Edges starting in the XZ plane extending from Y=0 to Y=1
    Add_Edge_As_Degenerate_Triangle(.XYZ_000, .XYZ_010);
    Add_Edge_As_Degenerate_Triangle(.XYZ_001, .XYZ_011);
    Add_Edge_As_Degenerate_Triangle(.XYZ_100, .XYZ_110);
    Add_Edge_As_Degenerate_Triangle(.XYZ_101, .XYZ_111);

    // Edges starting in the YZ plane extending from X=0 to X=1
    Add_Edge_As_Degenerate_Triangle(.XYZ_000, .XYZ_100);
    Add_Edge_As_Degenerate_Triangle(.XYZ_001, .XYZ_101);
    Add_Edge_As_Degenerate_Triangle(.XYZ_010, .XYZ_110);
    Add_Edge_As_Degenerate_Triangle(.XYZ_011, .XYZ_111);

    return mesh;
}
