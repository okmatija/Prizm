// @TODO Separate clipping mode

do_clip_radius_mode :: (clicked : bool = false) -> bool {
    if ImGui.IsMouseClicked(.Left) assert(ImGui.IsMouseDown(.Left));

    button_component := ifx clicked then ImGui.IsMouseClicked(.Left) else ImGui.IsMouseDown(.Left)
    return button_component && io().KeyShift;
}

do_selection_mode :: () {
    if app.user_selection.display_info.is_visible == false {
        if do_clip_radius_mode(true) {
            log_error("Cannot do sphere clipping when \"Points\" selection is not visible. This is dumb, sorry, make it visible to use sphere clipping.");
        }
        return;
    }

    if io().WantCaptureMouse || !ImGui.IsMousePosValid(*io().MousePos) {
        return;
    }

    // @TODO Add an enum representing the type of cursor text being displayed: INTERSECT_PLANE, CLOSEST_POINT, CLOSEST_VERTEX
    // @TODO Hide the cursor and display a line from the cursor to the point

    if !do_clip_radius_mode() {
        app.clipping_sphere_mode_entity_index = -1;
    }

    // This block computes the radius of the clipping sphere, then returns from the function
    if app.clipping_sphere_mode_entity_index >= 0 {

        entity := app.entities[app.clipping_sphere_mode_entity_index];
        sphere := entity.display_info.clip_sphere;

        // Find plane though point we clicked normal to the camera and compute intersection of mouse ray with that plane to set the radius
        ray := make_camera_ray();
        plane := make_hyperplane3(plane_normal=current_look_direction(), point_on_plane=sphere.center);
        intersect_count, intersect_t := find_intersect_ray3_plane3(ray, plane);
        if intersect_count != 1 {
            log_error("Expected an intersection");
            return;
        }
        current_point := to_point(ray, intersect_t);
        SPEED :: 2;
        new_radius := SPEED * distance(sphere.center, current_point);

        // TODO Set a minimum radius size in pixels so if the user just clicks and releases the shape does not completely disappear

        // Update the the radius of the current sphere
        new_sphere : Clip_Sphere = sphere;
        new_sphere.radius = new_radius;

        // Set the updated sphere on the relevant entities
        entity.display_info.clip_sphere = new_sphere;
        if entity.is_selected for :Selected app.entities {
            it.display_info.clip_sphere = new_sphere;
        }

        return;
    }

    use_result_for_adding_to_selection := ImGui.IsMouseClicked(.Left) && io().KeyCtrl;
    use_result_for_repositioning_camera := ImGui.IsMouseClicked(.Right) && io().KeyCtrl;
    use_result_for_rendering_cursor_text := app.user_selection_cursor_text_shown;

    if do_clip_radius_mode() || use_result_for_adding_to_selection  || use_result_for_repositioning_camera || use_result_for_rendering_cursor_text {

        closest : Point_On_Entity = ---;
        if do_clip_radius_mode() {
            // We dont check against vertices here. This would be handy in some case (e.g., if we have a bunch of floating points not
            // referenced by a triangle and we want to center the clipping sphere on one of them) but it spoils a handy workflow in
            // more common cases where the user has an active clipping sphere and can hold shift and click off the visible surface to
            // temporarily popup the wireframe of the rest of the mode, but wont affect the position/size of the clipping sphere
            closest = find_closest_point_on_visible_entities(); // @Volatile closest.element_index is a triangle index
        } else if use_result_for_repositioning_camera {
            closest = find_closest_point_on_visible_entities();
            if closest.element_index == -1 {
                closest = find_closest_vertex_on_visible_entities();
            }
            // @Cleanup @Volatile closest.element_index can be a vertex or triangle index
        } else {
            assert(use_result_for_rendering_cursor_text || use_result_for_adding_to_selection);
            closest = find_closest_vertex_on_visible_entities(); // @Volatile closest.element_index is now a vertex index
        }

        if closest.entity_index != -1 {

            if do_clip_radius_mode(clicked=true) {
                // When we first enter clip radius mode (when the mouse is first clicked) we:
                // 1. Store the previous sphere
                // 2. Store the center of the new sphere

                app.clipping_sphere_mode_entity_index = closest.entity_index;
                entity := app.entities[app.clipping_sphere_mode_entity_index];

                new_sphere : Clip_Sphere;
                new_sphere.is_active = true;
                new_sphere.center = closest.position;
                new_sphere.radius = 0.;

                // @Cleanup Make this into two calls to an update sphere function!
                entity.display_info.clip_sphere_prev = entity.display_info.clip_sphere;
                entity.display_info.clip_sphere = new_sphere;
                if entity.is_selected for :Selected app.entities {
                    if it == entity continue; // Must skip entity since we set it above
                    it.display_info.clip_sphere_prev = it.display_info.clip_sphere;
                    it.display_info.clip_sphere = new_sphere;
                }
            }

            if use_result_for_repositioning_camera {

                sphere : Sphere = entities_bounding_sphere_fast((e)=>(e.display_info.is_visible), fixed_center=*closest.position);

                view_from_world := make_look_at_matrix(app.camera);
                closest_view := view_from_world * make_vector4(closest.position, 1.);
                world_from_view := inverse(view_from_world);
                eye_displacement := (world_from_view * make_vector4(closest_view.x, closest_view.y, 0., 0.)).xyz;

                app.camera.look_position = closest.position;
                app.camera.eye_position  += eye_displacement;
                app.camera.far = sphere.radius * 2;
                app.camera.near = -app.camera.far;
            }

            if use_result_for_adding_to_selection {

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

            if use_result_for_rendering_cursor_text {
                text := tprint("#%,%: %", closest.entity_index, closest.element_index, closest.position);
                debug_text_at_cursor(text, app.user_selection_cursor_text_scale, app.user_selection.display_info.points_color);
            }
        }
    }
}

render_selections :: () {
    Scope_GL_State();

    if app.user_selection.is_hovered {
        glClear(GL_DEPTH_BUFFER_BIT);
    }

    entity := *app.user_selection;
    mesh := *app.user_selection.mesh;

    render_mesh_points(mesh, *entity.render_info, entity.display_info);
    render_mesh_lines(mesh, *entity.render_info, entity.display_info);
    render_mesh_triangles(mesh, *entity.render_info, entity.display_info);
    render_normals(mesh, *entity.render_info, entity.display_info);

    projection_from_model := make_projection_from_world(app.camera) * mesh.world_from_model;

    // We intentionally always all the text for selections since there usually aren't lots
    // of overlapping ones and its annoying not to see everything. We also don't consider
    // the clipping sphere (there is no way to set it right now, anyway) since this is also
    // annoying in the case of selections

    Simp.ScopeContext();
    point_theme := entity.display_info.vertex_label_style;
    for mesh.positions {
        text := get_point_text(it, it_index, point_theme);
        text_position_px := get_text_screen_position(it, projection_from_model);
        Simp.draw_text(app.simp_font, xx text_position_px.x, xx text_position_px.y, text, point_theme.label_color, scale=point_theme.label_scale);
    }
}