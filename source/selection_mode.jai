Geometry_Select_Tool :: struct {
    entity : Entity; // @Refactor Make this a pointer to entity 0?

    entity.display_info.is_visible = false;

    entity.display_info.vertex_label_theme.show_position = true;
    entity.display_info.vertex_label_theme.label_color = .{0, 0, 0, 1};

    entity.display_info.vertex_style.visible = true;
    entity.display_info.vertex_style.size = 6;
    entity.display_info.vertex_style.color = SELECT_VERTEX;
    entity.display_info.vertex_style.color_mode = .PICKED;

    entity.display_info.point_style.visible = true;
    entity.display_info.point_style.size = 6;
    entity.display_info.point_style.color = SELECT_POINT;
    entity.display_info.point_style.color_mode = .PICKED;

    entity.display_info.segment_style.visible = true;
    entity.display_info.segment_style.width = 2;
    entity.display_info.segment_style.color = SELECT_SEGMENT;
    entity.display_info.segment_style.color_mode = .PICKED;

    entity.display_info.triangle_style.visible = true;
    entity.display_info.triangle_style.color = SELECT_TRIANGLE;
    entity.display_info.triangle_style.color_mode = .PICKED;
    entity.display_info.triangle_style.edge_style.visible = true;
    entity.display_info.triangle_style.edge_style.color = BLACK;
    entity.display_info.triangle_style.edge_style.width = 2.;

    // Maybe we should default to vertex because all meshes have those...
    target_element : Simple_Mesh_Element = .TRIANGLE;
}

do_geometry_selection_mode :: () {
    if !viewport_capture_mouse() || (!mouse_toggle_in_geometry_selection() && !mouse_set_geometry_selection()) {
        return;
    }

    using app.select_tool.entity;

    if app.select_tool.target_element == {
    case .VERTEX;

        closest : Closest_Point_Ray_Entity = find_closest_vertex();
        if closest.element_index == -1 || !valid_geometry_index(closest.entity_index) {
            if mouse_set_geometry_selection() {
                deinit(*app.select_tool.entity);
            }
            return;
        }

        position := get_closest_point_on_element(closest); // world space

        // Find position indices with this coordinate value
        position_indices := temp_array(u32);
        for p, position_index : mesh.positions {
            if position == p {
                array_add(*position_indices, cast(u32)position_index);
            }
        }

        if mouse_toggle_in_geometry_selection() {
            if position_indices.count {

                // Collect elements connected to any of the position indices being removed
                to_remove_tids := temp_array(int);
                to_remove_sids := temp_array(int);
                to_remove_pids := temp_array(int);

                for remove_index : position_indices {
                    for :TriangleTupleIterator triangle_tuple, triangle_index : mesh {
                        if triangle_tuple.x == remove_index || triangle_tuple.y == remove_index || triangle_tuple.z == remove_index {
                            array_add(*to_remove_tids, triangle_index);
                        }
                    }

                    for :SegmentTupleIterator segment_tuple, segment_index : mesh {
                        if segment_tuple.x == remove_index || segment_tuple.y == remove_index {
                            array_add(*to_remove_sids, segment_index);
                        }
                    }

                    for :PointIndexIterator position_index, point_index : mesh {
                        if position_index == remove_index {
                            array_add(*to_remove_pids, point_index);
                        }
                    }
                }

                // Remove elements connected any of the position indices
                remove_elements_by_index(*mesh.triangles, ..to_remove_tids);
                remove_elements_by_index(*mesh.segments, ..to_remove_sids);
                remove_elements_by_index(*mesh.points, ..to_remove_pids);

                compact_mesh(*mesh);
            } else {
                // Adding the position as a point
                add_point(*mesh, position);
            }
        }

        if mouse_set_geometry_selection() {
            deinit(*app.select_tool.entity);
            add_point(*mesh, position);
        }

    case .POINT;

        closest : Closest_Point_Ray_Entity = find_closest_element(target_segments=elements_not_targetted, target_triangles=elements_not_targetted);
        if closest.element_index == -1 || !valid_geometry_index(closest.entity_index) {
            if mouse_set_geometry_selection() {
                deinit(*app.select_tool.entity);
            }
            return;
        }

        if closest.closest_point_element != .POINT {
            log_error("Expected a point: casting a ray in point selection mode");
            return;
        }

        // :NormalsInGeometrySelectionMode Get normals here
        hit_entity : *Entity = app.entities[closest.entity_index];
        hit_point : Vector3 = mesh_point_world(hit_entity.mesh, closest.element_index);

        if mouse_toggle_in_geometry_selection() {
            // Search for the segment in the current selection mesh
            found_index := -1;
            for :WorldPointIterator position, point_index : mesh {
                if position == hit_point {
                    found_index = point_index;
                    break;
                }
            }

            if found_index < 0 {
                add_point(*mesh, hit_point);
            } else {
                remove_point_by_index(*mesh, found_index);
            }
        }

        if mouse_set_geometry_selection() {
            deinit(*app.select_tool.entity);
            add_point(*mesh, hit_point);
        }

    case .SEGMENT;

        closest : Closest_Point_Ray_Entity = find_closest_element(target_points=elements_not_targetted, target_triangles=elements_not_targetted);
        if closest.element_index == -1 || !valid_geometry_index(closest.entity_index) {
            if mouse_set_geometry_selection() {
                deinit(*app.select_tool.entity);
            }
            return;
        }

        if closest.closest_point_element != .SEGMENT {
            log_error("Expected a segment: casting a ray in segment selection mode");
            return;
        }

        // :NormalsInGeometrySelectionMode Get normals here
        hit_entity : *Entity = app.entities[closest.entity_index];
        hit_segment : Segment3 = mesh_segment_world(hit_entity.mesh, closest.element_index);

        if mouse_toggle_in_geometry_selection() {
            // Search for the segment in the current selection mesh
            found_index := -1;
            for :WorldSegmentIterator segment, segment_index : mesh {
                if segment.start == hit_segment.start && segment.end == hit_segment.end {
                    found_index = segment_index;
                    break;
                }
            }

            if found_index < 0 {
                add_segment(*mesh, hit_segment);
            } else {
                remove_segment_by_index(*mesh, found_index);
            }
        }

        if mouse_set_geometry_selection() {
            deinit(*app.select_tool.entity);
            add_segment(*mesh, hit_segment);
        }

    case .TRIANGLE;

        closest : Closest_Point_Ray_Entity = find_closest_element(target_points=elements_not_targetted, target_segments=elements_not_targetted);
        if closest.element_index == -1 || !valid_geometry_index(closest.entity_index) {
            if mouse_set_geometry_selection() {
                deinit(*app.select_tool.entity);
            }
            return;
        }

        if closest.closest_point_element != .TRIANGLE {
            log_error("Triangle selection mode expected %, got %", Simple_Mesh_Element.TRIANGLE, closest.closest_point_element);
            return;
        }

        // :NormalsInGeometrySelectionMode Get normals here
        hit_entity : *Entity = app.entities[closest.entity_index];
        hit_triangle : Triangle3 = mesh_triangle_world(hit_entity.mesh, closest.element_index);

        if mouse_toggle_in_geometry_selection() {
            // Search for the triangle in the current selection mesh @Speed use a set or some datastructure where we can insert/delete quick
            found_index := -1;
            for :WorldTriangleIterator triangle, triangle_index : mesh {
                if hit_triangle.a == triangle.a && hit_triangle.b == triangle.b && hit_triangle.c == triangle.c {
                    found_index = triangle_index;
                    break;
                }
            }

            if found_index < 0 {
                add_triangle(*mesh, hit_triangle);
            } else {
                remove_triangle_by_index(*mesh, found_index);
            }
        }

        if mouse_set_geometry_selection() {
            deinit(*app.select_tool.entity);
            add_triangle(*mesh, hit_triangle);
        }

    } // if app.select_tool.target_element ==

    render_info.is_dirty = true;
}

do_item_selection_mode :: () {
    if !viewport_capture_mouse() || (!mouse_toggle_in_item_selection() && !mouse_set_item_selection()) {
        return;
    }

    closest : Closest_Point_Ray_Entity = find_closest_element();

    if valid_geometry_index(closest.entity_index) {
        if mouse_set_item_selection() {
            for :Selected app.entities {
                it.is_selected = false;
            }
            app.entities[closest.entity_index].is_selected = true;
        }

        if mouse_toggle_in_item_selection() {
            app.entities[closest.entity_index].is_selected = !app.entities[closest.entity_index].is_selected;
        }
    } else {
        if mouse_set_item_selection() {
            for :Selected app.entities {
                it.is_selected = false;
            }
        }
    }
}