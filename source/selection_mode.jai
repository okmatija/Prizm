Geometry_Select_Tool :: struct {
    entity : Entity; // @Refactor Make this a pointer to entity 0?

    entity.display_info.is_visible = false;

    entity.display_info.vertex_label_theme.show_position = true;
    entity.display_info.vertex_label_theme.label_color = .{0, 0, 0, 1};

    entity.display_info.positions_visible = true;
    entity.display_info.positions_size = 6;
    entity.display_info.positions_color = .{1, 0, 0, 1};

    entity.display_info.segments_visible = true;
    entity.display_info.segments_width = 2;
    entity.display_info.segments_color = .{0, 1, 0, 1};

    entity.display_info.triangles_visible = true;
    entity.display_info.triangles_color = .{0, 0, 1, 1};

    // Default to vertex because all meshes have those...
    target_element : Simple_Mesh_Element = .VERTEX;
}

do_geometry_selection_mode :: () {
    if !mouse_add_to_geometry_selection() {
        return;
    }

    using app.select_tool.entity;

    if app.select_tool.target_element == .VERTEX {
        closest : Closest_Point_Ray_Entity = find_closest_vertex();
        if closest.element_index == -1 {
            return;
        }

        position := get_closest_point_on_element(closest);

        removed := false;
        for mesh.positions {
            if position == it {
                remove it;
                removed = true;
                break;
            }
        }
        if !removed {
            array_add(*mesh.positions, position);
        }

        // Rebuild points array in all cases
        array_reset_keeping_memory(*mesh.points);
        for 0..mesh.positions.count-1 array_add(*mesh.points, xx it);

        render_info.is_dirty = true;
    }
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