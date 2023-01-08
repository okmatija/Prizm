do_geometry_selection_mode :: () {
    if !mouse_add_to_geometry_selection() {
        return;
    }

    closest : Closest_Point_Ray_Entity = find_closest_vertex();
    if closest.element_index == -1 {
        return;
    }

    position := get_closest_point_on_element(closest);

    using app.select_tool.entity;

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