// @Cleanup Maybe this should be a debug command only

// Adds items to visualize the spatial index of the given item
// `jumbo_item`    if true all AABBs are visualized as a single polyline soup
debug_spatial_index :: (id : int, jumbo_item : int = 0) {
    if !check_geometry_index(id) {
        return;
    }

    // @FIXME This does not apply the mesh transform properly

    mesh_entity := app.entities[id];
    spatial := mesh_entity.spatial;

    if spatial == null || spatial.nodes.count == 0 {
        log_warning("Item % has a null or empty spatial index.", id);
        return;
    }

    if jumbo_item {
        // Put all AABBs into a single polyline soup
        shape : Polyline_Soup3;
        for spatial.nodes {
            polyline_aabb := to_polyline_soup(it.aabb);
            for polyline : polyline_aabb.polylines {
                shape_polyline := array_add(*shape.polylines);
                shape_polyline.* = polyline; // @FIXME null check
            }
        }

        mesh := to_Mesh(shape);

        assert(app.console.history.count > 0);

        entity := New(Entity);
        entity.mesh = mesh;
        set_entity_source_from_command(entity, tprint("%_debug_spatial_aabbs", entity_name(mesh_entity)), app.console.history[app.console.history.count - 1], mesh.positions.count);
        set_entity_display_info(entity);

        add_entity(entity, .OVERWRITE);

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

                    assert(app.console.history.count > 0);

                    entity := New(Entity);
                    entity.mesh = to_edge_Mesh(node.aabb, tree.shape.world_from_model);
                    set_entity_source_from_command(entity,  tprint("%_debug_spatial_%", data.name, depth), app.console.history[app.console.history.count - 1], entity.mesh.positions.count);  // @Incomplete pad depth integer?
                    set_entity_display_info(entity);

                    {
                        using primitives : Simple_Mesh;
                        defer deinit(*primitives);
                        for :spatial.Element_Info_Iterator info : node.range {
                            tri := get_element(tree, info.element_id);
                            add_triangle(*primitives, tri);
                        }
                        primitives.world_from_model = tree.shape.world_from_model;
                        merge(*entity.mesh, primitives);
                    }

                    table_add(entity_at_depth, depth, entity);
                } else {
                    entity_base := found.*;
                    entity := entity_base;
                    entity.render_info.is_dirty = true; // Redundant
                    entity.display_info.segment_style.visible = true;
                    entity.display_info.segment_style.width = 2;

                    {
                        using primitives : Simple_Mesh;
                        defer deinit(*primitives);
                        for :spatial.Element_Info_Iterator info : node.range {
                            tri := get_element(tree, info.element_id);
                            add_triangle(*primitives, tri);
                        }
                        primitives.world_from_model = tree.shape.world_from_model;
                        merge(*entity.mesh, primitives);
                    }

                    {
                        using edges : Simple_Mesh = to_edge_Mesh(node.aabb, tree.shape.world_from_model);
                        defer deinit(*edges);
                        merge(*entity.mesh, edges);
                    }

                }


            } else {
                // Internal

                found := table_find_pointer(entity_at_depth, depth);

                if found == null {
                    assert(app.console.history.count > 0);

                    entity := New(Entity);
                    entity.mesh = to_edge_Mesh(node.aabb, tree.shape.world_from_model);
                    set_entity_source_from_command(entity, tprint("%_debug_spatial_%", data.name, depth), app.console.history[app.console.history.count - 1], entity.mesh.positions.count); // @Incomplete pad depth integer?
                    set_entity_display_info(entity);

                    table_add(entity_at_depth, depth, entity);
                } else {
                    entity := found.*;

                    other := to_edge_Mesh(node.aabb, tree.shape.world_from_model);
                    defer deinit(*other);

                    merge(*entity.mesh, other);
                    entity.render_info.is_dirty = true; // Redundant
                }
            }

            return true; // Continue visitation
        }

        Visitor_Data :: struct {
            entity_at_depth : *Table(int, *Entity);
            name : string;
            tree : *AABB_Tree; // Needed so iterator can work
        }
        visitor_data : Visitor_Data;
        visitor_data.entity_at_depth = *entity_at_depth;
        visitor_data.name = entity_name(mesh_entity);
        visitor_data.tree = spatial;

        visitor : spatial.Node_Visitor;
        visitor.proc = append_to_entity_at_depth;
        visitor.data = *visitor_data;
        depth_first_visit(spatial.*, visitor); // @CompilerBug why can't I implicit pointer dereference here?

        Entity_At_Depth :: struct {
            depth : int;
            entity : *Entity;
        }

        sorted_by_depth : [..]Entity_At_Depth;
        defer array_free(sorted_by_depth);

        // @Cleanup what the heck is going on, is depth the index??
        for entity, depth : entity_at_depth {
            entry := array_add(*sorted_by_depth);
            entry.depth = depth;
            entry.entity = entity;
        }

        quick_sort(sorted_by_depth, x=>x.depth);

        for sorted_by_depth {
            add_entity(it.entity, .OVERWRITE);
        }
    } // end else of if jumbo_item
} @RegisterCommand


debug_delete_spatial_index :: (id : int) {
    if !check_geometry_index(id) {
        return;
    }

    mesh_entity := app.entities[id];
    deinit(mesh_entity.spatial);
    mesh_entity.spatial = null;

} @RegisterCommand

#scope_file

to_edge_Mesh :: (using box : AxisBox3, world_from_model : Matrix4) -> Simple_Mesh {
    mesh : Simple_Mesh;
    mesh.world_from_model = world_from_model;

    AddEdge :: (a : Corner3, b : Corner3) #expand {
        offset : u32 = xx mesh.positions.count;
        array_add(*mesh.positions, corner(box, a));
        array_add(*mesh.colors, DEFAULT_VERTEX_COLOR);
        array_add(*mesh.positions, corner(box, b));
        array_add(*mesh.colors, DEFAULT_VERTEX_COLOR);
        tuple : *Tuple2(u32) = array_add(*mesh.segments);
        tuple.x, tuple.y = offset, offset + 1;
    }

    // Edges starting in the XY plane extending from Z=0 to Z=1
    AddEdge(.XYZ_000, .XYZ_001);
    AddEdge(.XYZ_010, .XYZ_011);
    AddEdge(.XYZ_100, .XYZ_101);
    AddEdge(.XYZ_110, .XYZ_111);

    // Edges starting in the XZ plane extending from Y=0 to Y=1
    AddEdge(.XYZ_000, .XYZ_010);
    AddEdge(.XYZ_001, .XYZ_011);
    AddEdge(.XYZ_100, .XYZ_110);
    AddEdge(.XYZ_101, .XYZ_111);

    // Edges starting in the YZ plane extending from X=0 to X=1
    AddEdge(.XYZ_000, .XYZ_100);
    AddEdge(.XYZ_001, .XYZ_101);
    AddEdge(.XYZ_010, .XYZ_110);
    AddEdge(.XYZ_011, .XYZ_111);

    return mesh;
}
