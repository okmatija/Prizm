do_selection_mode :: () {
    if !mouse_add_to_selection() {
        return;
    }

    closest : Closest_Point_Ray_Entity = find_closest_vertex_on_visible_entities();
    if closest.element_index == -1 {
        return;
    }

    position := get_closest_point_on_element(closest);

    removed := false;
    for app.user_selection.mesh.positions {
        if position == it {
            remove it;
            removed = true;
            break;
        }
    }
    if !removed {
        array_add(*app.user_selection.mesh.positions, position);
    }

    app.user_selection.mesh.geometry_format = .POINTS; // We added a point, we'll probably want to remove this
    app.user_selection.render_info.is_dirty = true;
}

do_closest_point_mode :: () {
    if !app.user_selection_cursor_text_shown {
        return;
    }

    closest : Closest_Point_Ray_Entity = find_closest_vertex_on_visible_entities();
    if closest.element_index == -1 {
        return;
    }

    directive : string = "?";
    if #complete closest.closest_point_element == {
        case .POINT;      directive = "p";
        case .SEGMENT;    directive = "s"; // pseudo obj directive
        case .TRIANGLE;   directive = "f";
        // These should never happen
        case .VERTEX;     directive = "v";
        case .MESH;       directive = "?";
    }

    position := get_closest_point_on_element(closest);
    text := tprint("#%,%0%: %", closest.entity_index, directive, closest.element_index, position);
    debug_text_at_cursor(text, app.user_selection_cursor_text_scale, app.user_selection.display_info.points_color);
}