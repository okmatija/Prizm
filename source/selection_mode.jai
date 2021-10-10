// Copyright Epic Games, Inc. All Rights Reserved.

do_selection_mode :: () {
    {
        if app.user_selection.is_hovered {
            glClear(GL_DEPTH_BUFFER_BIT);
        }

        entity := *app.user_selection;
        mesh := *app.user_selection.mesh;

        render_mesh_points(mesh, *entity.render_info, entity.display_info);
        render_mesh_lines(mesh, *entity.render_info, entity.display_info);
        render_mesh_triangles(mesh, *entity.render_info, entity.display_info);
        render_normals(mesh, *entity.render_info, entity.display_info);
        render_vertex_labels(mesh.positions, mesh.world_from_model, entity.display_info.vertex_label_style);
    }

    if io().WantCaptureMouse || !ImGui.IsMousePosValid(*io().MousePos) {
        return;
    }

    // @TODO Add an enum representing the type of cursor text being displayed: INTERSECT_PLANE, CLOSEST_POINT, CLOSEST_VERTEX
    // @TODO Hide the cursor and display a line from the cursor to the point

    use_result_for_adding_to_selection := ImGui.IsMouseClicked(.Left) && io().KeyCtrl;
    use_result_for_repositioning_camera := ImGui.IsMouseClicked(.Right) && io().KeyCtrl;
    use_result_for_rendering_cursor_text := app.user_selection_cursor_text_shown;

    if use_result_for_adding_to_selection || use_result_for_repositioning_camera || use_result_for_rendering_cursor_text {

        closest := find_closest_vertex_on_visible_entities();
        if closest.entity_index != -1 {

            if use_result_for_repositioning_camera {
                view_from_world := make_look_at_matrix(app.camera);
                closest_view := view_from_world * make_vector4(closest.vertex_position, 1.);

                world_from_view := inverse(view_from_world);
                eye_displacement := (world_from_view * make_vector4(closest_view.x, closest_view.y, 0., 0.)).xyz;

                app.camera.look_position = closest.vertex_position;
                app.camera.eye_position  += eye_displacement;

                sphere : Sphere;
                sphere.center = app.camera.look_position;
                sphere.radius = 0;

                // Compute the bounding sphere the points in the scene
                for :visible entity : app.entities {
                    for * entity.mesh.positions {
                        p := (entity.mesh.world_from_model * make_vector4(<<it, 1.)).xyz;
                        sphere.radius = max(sphere.radius, length_squared(app.camera.look_position - p));
                    }
                }
                if app.user_selection.is_visible {
                    mesh := *app.user_selection.mesh;
                    for * mesh.positions {
                        p := (mesh.world_from_model * make_vector4(<<it, 1.)).xyz;
                        sphere.radius = max(sphere.radius, length_squared(app.camera.look_position - p));
                    }
                }

                sphere.radius = sqrt(sphere.radius);
                app.camera.far = sphere.radius * 2;
                app.camera.near = -app.camera.far;
            }

            if use_result_for_adding_to_selection {

                removed := false;
                for app.user_selection.mesh.positions {
                    if closest.vertex_position == it {
                        remove it;
                        removed = true;
                        break;
                    }
                }
                if !removed {
                    array_add(*app.user_selection.mesh.positions, closest.vertex_position);
                }

                app.user_selection.render_info.is_dirty = true;
            }

            // if use_result_for_rendering_cursor_text {
            //     text := tprint("#%,%: %", closest.entity_index, closest.vertex_index, closest.vertex_position);
            //     debug_text_at_cursor(text, app.user_selection_cursor_text_scale, app.user_selection.display_info.points_color);
            // }
        }
    }
}