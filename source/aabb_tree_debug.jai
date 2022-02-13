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
            entity_at_depth := cast(*Table(int, *Entity))user_data;

            if node.child_lhs == -1 {
                assert(node.child_rhs == -1); // @Refactor Implement an ensure-like macro which just logs a warning

                // Leaf
                // @Incomplete

            } else {
                // Internal

                found := table_find_pointer(<<entity_at_depth, depth);

                if found == null {
                    entity := New(Polyline_Soup3_Entity);
                    assert(entity != null);

                    entity.shape = to_polyline_soup(node.aabb);
                    entity.mesh = to_Mesh(entity.shape);
                    init_entity_base_parameters(entity, tprint("%_debug_spatial_%", entity.fully_pathed_filename, depth), entity.mesh); // @Incomplete pad depth integer?

                    table_add(entity_at_depth, depth, entity);
                } else {
                    entity_base := <<found;
                    assert(entity_base.type == .POLYLINE_SOUP3);

                    entity := cast(*Polyline_Soup3_Entity)entity_base;

                    // Update shape and overwrite mesh
                    shape := to_polyline_soup(node.aabb);
                    for polyline : shape.polylines {
                        shape_polyline := array_add(*entity.shape.polylines);
                        <<shape_polyline = polyline;
                    }
                    deinit(*entity.mesh); // @Speed maybe we just keep the memory
                    entity.mesh = to_Mesh(entity.shape);
                    entity.render_info.is_dirty = true; // Redundant
                }
            }

            return true; // Continue visitation
        }

        visitor : spatial.Node_Visitor;
        visitor.proc = append_to_entity_at_depth;
        visitor.data = *entity_at_depth;
        depth_first_visit(<<spatial, visitor);

        Entity_At_Depth :: struct {
            depth : int;
            entity : *Entity;
        }

        sorted_by_depth : [..]Entity_At_Depth;
        defer array_free(sorted_by_depth);

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