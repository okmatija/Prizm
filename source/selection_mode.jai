Geometry_Select_Tool :: struct {
    entity : Entity; // @Refactor Make this a pointer to entity 0?

    entity.display_info.is_visible = false;

    entity.display_info.vertex_label_theme.show_position = true;
    entity.display_info.vertex_label_theme.label_color = .{0, 0, 0, 1};

    entity.display_info.positions_visible = true;
    entity.display_info.positions_size = 6;
    entity.display_info.positions_color = SELECT_VERTEX;

    entity.display_info.points_visible = true;
    entity.display_info.points_size = 6;
    entity.display_info.points_color = SELECT_POINT;

    entity.display_info.segments_visible = true;
    entity.display_info.segments_width = 2;
    entity.display_info.segments_color = SELECT_SEGMENT;

    entity.display_info.triangles_visible = true;
    entity.display_info.triangles_color = SELECT_TRIANGLE;
    entity.display_info.edges_visible = true;
    entity.display_info.edges_color = BLACK;
    entity.display_info.edges_width = 2.;

    // Maybe we should default to vertex because all meshes have those...
    target_element : Simple_Mesh_Element = .TRIANGLE;
}

do_geometry_selection_mode :: () {
    if !mouse_add_to_geometry_selection() {
        return;
    }

    using app.select_tool.entity;

    if app.select_tool.target_element == {
    case .VERTEX;

        closest : Closest_Point_Ray_Entity = find_closest_vertex();
        if closest.element_index == -1 || !valid_geometry_index(closest.entity_index) {
            return;
        }

        position := get_closest_point_on_element(closest);

        // Find position indices with this coordinate value
        position_indices := temp_array(u32);
        for p, position_index : mesh.positions {
            if position == p {
                array_add(*position_indices, xx position_index);
            }
        }

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

    case .POINT;

        closest : Closest_Point_Ray_Entity = find_closest_element(visit_segments=false, visit_triangles=false);
        if closest.element_index == -1 || !valid_geometry_index(closest.entity_index) {
            return;
        }

        if closest.closest_point_element != .POINT {
            log_error("Expected a point closest point casting a colliding ray in point selection mode");
            return;
        }

        hit_entity : *Entity = app.entities[closest.entity_index];
        hit_point : Vector3 = mesh_point_world(hit_entity.mesh, closest.element_index);

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

    case .SEGMENT;

        closest : Closest_Point_Ray_Entity = find_closest_element(visit_points=false, visit_triangles=false);
        if closest.element_index == -1 || !valid_geometry_index(closest.entity_index) {
            return;
        }

        if closest.closest_point_element != .SEGMENT {
            log_error("Expected a segment closest point casting a colliding ray in segment selection mode");
            return;
        }

        hit_entity : *Entity = app.entities[closest.entity_index];
        hit_segment : Segment3 = mesh_segment3_world(hit_entity.mesh, closest.element_index);

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

    case .TRIANGLE;

        closest : Closest_Point_Ray_Entity = find_closest_element(visit_points=false, visit_segments=false);
        if closest.element_index == -1 || !valid_geometry_index(closest.entity_index) {
            return;
        }

        if closest.closest_point_element != .TRIANGLE {
            log_error("Expected a triangle closest point casting a colliding ray in triangle selection mode");
            return;
        }

        hit_entity : *Entity = app.entities[closest.entity_index];
        hit_triangle : Triangle3 = mesh_triangle_world(hit_entity.mesh, closest.element_index);

        // Search for the triangle in the current selection mesh
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

    } // if app.select_tool.target_element ==

    render_info.is_dirty = true;
}

do_item_selection_mode :: () {
    if !mouse_add_to_item_selection() {
        return;
    }

    closest : Closest_Point_Ray_Entity = find_closest_element();

    if valid_geometry_index(closest.entity_index) {
        app.entities[closest.entity_index].is_selected = !app.entities[closest.entity_index].is_selected;
    } else {
        for :Selected app.entities {
            it.is_selected = false;
        }
    }
}