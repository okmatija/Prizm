// Copyright Epic Games, Inc. All Rights Reserved.

do_clip_radius_mode :: (clicked : bool = false) -> bool {
    if ImGui.IsMouseClicked(.Left) assert(ImGui.IsMouseDown(.Left));
    button_component := ifx clicked then ImGui.IsMouseClicked(.Left) else ImGui.IsMouseDown(.Left)
    return app.user_selection.is_visible && button_component && io().KeyShift;
}

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

    if !do_clip_radius_mode() app.clipping_sphere_mode_entity_index = -1;

    // This block computes the radius of the clipping sphere, then returns from the function
    if app.clipping_sphere_mode_entity_index != -1 {

        entity := app.entities[app.clipping_sphere_mode_entity_index];

        // Find plane though point we clicked normal to the camera and compute intersection of mouse ray with that plane to set the radius
        ray := make_camera_ray();
        line : Line3; // @Cleanup Make a ray/plane intersection function
        line.origin = ray.origin;
        line.direction = ray.direction;
        plane := make_hyperplane3(plane_normal=current_look_direction(), point_on_plane=entity.display_info.clip_sphere.center);
        intersect_count, intersect_t := find_intersect_line3_plane3(line, plane);
        if intersect_count != 1 {
            log_error("Expected an intersection");
            return;
        }
        current_point := to_point(line, intersect_t);

        speed :: 2;
        d := distance(entity.display_info.clip_sphere.center, current_point);
        entity.display_info.clip_sphere.radius = speed * d;
        for :selected app.entities {
            it.display_info.clip_sphere.radius = entity.display_info.clip_sphere.radius;
            app.selection_display_info.clip_sphere.radius = entity.display_info.clip_sphere.radius; // Set in each iteration but whatever
        }

        return;
    }

    if do_clip_radius_mode() || use_result_for_adding_to_selection  || use_result_for_repositioning_camera || use_result_for_rendering_cursor_text {

        closest : Point_On_Entity = ---;
        if do_clip_radius_mode() || use_result_for_repositioning_camera {
            closest = find_intersection_point_on_visible_entities(); // @Volatile element_index is a triangle index
        } else {
            closest = find_closest_vertex_on_visible_entities(); // @Volatile element_index is now a vertex index
        }

        if closest.entity_index != -1 {

            if do_clip_radius_mode(clicked=true) {
                app.clipping_sphere_mode_entity_index = closest.entity_index;
                entity := app.entities[app.clipping_sphere_mode_entity_index];
                entity.display_info.clip_sphere.is_active = true;
                entity.display_info.clip_sphere.sphere.center = closest.position;
                entity.display_info.clip_sphere.sphere.radius = 0.;
                for :selected app.entities {
                    it.display_info.clip_sphere = entity.display_info.clip_sphere;
                    app.selection_display_info.clip_sphere = entity.display_info.clip_sphere; // Set in each iteration but whatever
                }
            }

            if use_result_for_repositioning_camera {

                sphere : Sphere;
                sphere.center = closest.position;

                // Compute the bounding sphere of the points in the scene
                sphere.radius = 0;
                for :visible entity : app.entities {
                    for * entity.mesh.positions {
                        p := (entity.mesh.world_from_model * make_vector4(<<it, 1.)).xyz;
                        sphere.radius = max(sphere.radius, length_squared(closest.position - p));
                    }
                }
                if app.user_selection.is_visible {
                    mesh := *app.user_selection.mesh;
                    for * mesh.positions {
                        p := (mesh.world_from_model * make_vector4(<<it, 1.)).xyz;
                        sphere.radius = max(sphere.radius, length_squared(closest.position - p));
                    }
                }
                sphere.radius = sqrt(sphere.radius);

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