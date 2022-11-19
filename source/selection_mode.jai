do_selection_mode :: () {
    if !mouse_add_to_selection() {
        return;
    }

    closest : Point_On_Entity = find_closest_vertex_on_visible_entities();
    if closest.element_index == -1 {
        return;
    }

    removed := false;
    for app.user_selection.mesh.positions {
        if closest.position == it {
            remove it;
            removed = true;
            break;
        }
    }
    if !removed {
        array_add(*app.user_selection.mesh.positions, closest.position);
    }

    app.user_selection.render_info.is_dirty = true;
}

do_closest_point_mode :: () {
    if !app.user_selection_cursor_text_shown {
        return;
    }

    closest : Point_On_Entity = find_closest_vertex_on_visible_entities();
    if closest.element_index == -1 {
        return;
    }

    directive : string = "?";
    if #complete closest.element_kind == {
        case .VERTEX;     directive = "v";
        case .POINT;      directive = "p";
        case .SEGMENT;    directive = "s"; // pseudo obj directive
        case .TRIANGLE;   directive = "f";
        case .MESH;       directive = "?";
    }

    text := tprint("#%,%0%: %", closest.entity_index, directive, closest.element_index, closest.position);
    debug_text_at_cursor(text, app.user_selection_cursor_text_scale, app.user_selection.display_info.points_color);
}