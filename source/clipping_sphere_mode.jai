do_clipping_sphere_mode :: () {
    if mouse_init_clip_center() { // Set the clipping sphere center
        closest : Closest_Point_Ray_Entity = find_closest_element(visit_visible);

        if closest.entity_index != -1 {
            array_reset(*app.clipping_sphere_mode_last_entity_index_set);

            // When we first enter clip radius mode (when the mouse is first clicked) we:
            // 1. Store the previous sphere
            // 2. Store the center of the new sphere

            app.clipping_sphere_mode_entity_index = closest.entity_index;
            array_add(*app.clipping_sphere_mode_last_entity_index_set, closest.entity_index);

            entity := app.entities[app.clipping_sphere_mode_entity_index];

            new_sphere : Clip_Sphere;
            new_sphere.is_active = true;
            new_sphere.center = get_closest_point_on_element(closest);
            new_sphere.radius = 0.;

            // @Cleanup Make this into two calls to an update sphere function!
            entity.display_info.clip_sphere_prev = entity.display_info.clip_sphere;
            entity.display_info.clip_sphere = new_sphere;
            if entity.is_selected for :Selected app.entities {
                if it == entity continue; // Must skip entity since we set it above
                it.display_info.clip_sphere_prev = it.display_info.clip_sphere;
                it.display_info.clip_sphere = new_sphere;
                array_add(*app.clipping_sphere_mode_last_entity_index_set, it_index);
            }
        }
    } else if mouse_set_clip_radius() && app.clipping_sphere_mode_entity_index != -1 { // Set the clipping sphere radius
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
    } else {
        // Reset clipping sphere mode global data
        app.clipping_sphere_mode_entity_index = -1;
    }
}
