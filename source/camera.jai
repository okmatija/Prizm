// Copyright Epic Games, Inc. All Rights Reserved.

Camera :: struct {
    // Data to transfrom from world to view coordinates
    eye_position :  Vector3; // world
    look_position : Vector3;
    up_direction :  Vector3;

    rotation_axis := Camera_Rotation_Axis.ROLL; // :UserConfig use configurable default
    scene_bounding_sphere : Sphere;

    // Data for orthographic projection
    left:   float;
    right:  float;
    bottom: float;
    top:    float;

    near : float;
    far :  float;

    // @Incomplete
    // near_grid : Grid;
    // far_grid : Grid;
}

Camera_Rotation_Axis :: enum {
    ROLL :: 0;
    PITCH;
    YAW;
    WORLD_X;
    WORLD_Y;
    WORLD_Z;
}

camera_rotation_axis :: () -> Vector3
{
    axis : Vector3 = ---;
    if #complete app.camera.rotation_axis == {
        case .ROLL;    axis = current_look_direction();
        case .PITCH;   axis = cross(current_look_direction(), app.camera.up_direction);
        case .YAW;     axis = app.camera.up_direction;
        case .WORLD_X; axis = .{1, 0, 0};
        case .WORLD_Y; axis = .{0, 1, 0};
        case .WORLD_Z; axis = .{0, 0, 1};
    }
    return axis;
}

set_look_direction :: (direction : Vector3, up : Vector3)
{
    // @Incomplete Interpolate the motion
    using *app.camera;
    d := distance(look_position, eye_position) / length(direction);
    eye_position = look_position - d * direction;
    up_direction = up;
}

// Return the vector from the current eye position to the look position
current_look_direction :: () -> Vector3
{
    return app.camera.look_position - app.camera.eye_position;
}

rotate_look_direction :: (axis : Vector3, degrees : float)
{
    using *app.camera;

    rotation : Quaternion = ---;
    set_from_axis_and_angle(*rotation, axis, to_radians(degrees));

    look_direction := rotate(current_look_direction(), rotation);
    eye_position = look_position - look_direction;
    up_direction = rotate(up_direction, rotation);
}

// Return the orthographic view volume in view space coordinates
current_orthographic_view_volume :: () -> AxisBox3
{
    min_point_vs := make_vector3(app.camera.left,  app.camera.bottom, app.camera.near);
    max_point_vs := make_vector3(app.camera.right, app.camera.top,    app.camera.far);
    volume_vs := make_axis_box3(min_point_vs, max_point_vs);
    return volume_vs;
}

init_camera :: () {
    camera := *app.camera;

    // These define the camera coordinate system
    camera.eye_position = .{0, 0, 200};
    camera.look_position = .{0, 0, 0}; // arcball pivot
    camera.up_direction = .{0, 1, 0};

    camera.top = 70;
    camera.bottom = -camera.top;
    camera.right = camera.top * current_window_aspect_ratio_width_over_height();
    camera.left = -camera.right;

    camera.near = -100;
    camera.far = 400;
}

update_camera :: (delta_time : float) {
    camera := *app.camera;

    if io().WantCaptureMouse return;

    if ImGui.IsMouseClicked(.Right) {
        rmb_down_pos = make_Vector2(io().MousePos);
        camera_at_mouse_down = app.camera;
    }

    // Mouse delta is zero when current or previous mouse positions were invalid
    mouse_move_valid := !(io().MouseDelta.x == 0 && io().MouseDelta.y == 0);

    world_from_projection := inverse(make_projection_from_world(camera));

    // Pan with middle down.
    if io_mouse_middle_down() && mouse_move_valid {

        get_pan_position :: (mouse_position_px : Vector2, world_from_projection : Matrix4, camera : Camera) -> Vector3, bool {
            plane := make_hyperplane3(unit_vector(camera.eye_position - camera.look_position), camera.look_position);
            line : Line3 = ---;
            line.origin = (world_from_projection * make_vector4(to_ndc(mouse_position_px), -1, 1)).xyz;
            line.direction = -plane.normal;

            intersect_count, intersect_t := find_intersect_line3_plane3(line, plane);
            if intersect_count != 1 || intersect_t < 0 {
                return .{}, false;
            }

            assert(intersect_count == 1, "Expected 1 intersection, got %", intersect_count);
            assert(intersect_t >= 0, "Expected intersection in front of near plane with t >= 0, got t = %", intersect_t);
            return to_point(line, intersect_t), true;
        }

        // Shoot ray through pixel along the look vector to hit a plane through the look position with the same normal
        curr_pan_point, curr_ok := get_pan_position(make_Vector2(io().MousePos), world_from_projection, camera);
        prev_pan_point, prev_ok := get_pan_position(make_Vector2(io().MousePos) - make_Vector2(io().MouseDelta), world_from_projection, camera);
        if curr_ok && prev_ok {
            increment := -(curr_pan_point - prev_pan_point) / 2; // @Cleanup WHY this divide by 2, there is probably a bug elsewhere... ?

            camera.eye_position += increment;
            camera.look_position += increment;
        }

    } else if ImGui.IsMouseDragging(.Right, 0.) && mouse_move_valid && !do_clip_radius_mode() { // Orbit about the look position using right button

        world_from_projection_at_mouse_down := inverse(make_projection_from_world(camera_at_mouse_down));

        prev_arcball_vector := arcball_vector(rmb_down_pos);
        curr_arcball_vector := arcball_vector(make_Vector2(io().MousePos));
        arcball_axis_ndc := cross_product(curr_arcball_vector, prev_arcball_vector);

        view_from_world := make_look_at_matrix(camera_at_mouse_down);
        world_from_view := inverse(view_from_world);
        arcball_axis_world := (world_from_view * make_vector4(arcball_axis_ndc, 0)).xyz;

        arcball_angle := angle(curr_arcball_vector, prev_arcball_vector);

        if io().KeyAlt {
            // Rotate around the currently chosen camera rotation axis
            arcball_axis_world = camera_rotation_axis();
            arcball_angle = (io().MousePos.y - rmb_down_pos.y) * .02;
        } else {
            arcball_angle *= 30.;
        }

        // @Cleanup fishy negative sign and rotation speed multiplier should be chosen so screen top/bottom or left/right rotates the scene by tau or tau/2 respectively.
        q : Quaternion = ---;
        set_from_axis_and_angle(*q, arcball_axis_world, -arcball_angle);

        look_to_eye := rotate(camera_at_mouse_down.eye_position - camera_at_mouse_down.look_position, q);

        #if false {
            l := (camera.top - camera.bottom) * .15;
            debug_vector(l, (world_from_projection * make_vector4(prev_arcball_vector, 0)).xyz, .{1., .5, .5, 1.});
            debug_vector(l, (world_from_projection * make_vector4(curr_arcball_vector, 0)).xyz, .{.5, 1., .5, 1.});
            debug_vector(l, look_to_eye, .{1., 1., 1., 1.});
            debug_vector(l, rotate(camera_at_mouse_down.up_direction, q), .{1., 1., 1., 1.});
            debug_vector(l, camera_at_mouse_down.eye_position - camera_at_mouse_down.look_position, .{1., 1., 0., 1.});
            debug_vector(l, camera_at_mouse_down.up_direction, .{1., 1., 0., 1.});
        }

        camera.eye_position = camera_at_mouse_down.look_position + look_to_eye;
        camera.up_direction = rotate(camera_at_mouse_down.up_direction, q);

    } else if io().MouseWheel { // Zoom with scroll wheel

        ratio := app.settings.camera_zoom_scrolling_ratio;
        if      io().KeyAlt   ratio = .97;
        else if io().KeyShift ratio = .5;

        zoom_factor := 1.;
        if      (io().MouseWheel > 0) zoom_factor *= ratio;
        else if (io().MouseWheel < 0) zoom_factor /= ratio;
        handle_zoom(zoom_factor, make_Vector2(io().MousePos), !io().KeyCtrl);
    }
}

handle_zoom :: (zoom_factor : float, previous_pos : Vector2, follow_cursor : bool) {

    camera := *app.camera;

    view_from_clip := inverse(make_orthographic_projection_matrix(camera));

    previous_clip := to_ndc(previous_pos);
    zoomed_clip := previous_clip / zoom_factor;

    previous_view := view_from_clip * make_vector4(previous_clip, 0., 1.);
    zoomed_view := view_from_clip * make_vector4(zoomed_clip, 0., 1.);

    camera.top   *= zoom_factor;
    camera.right *= zoom_factor;
    camera.bottom = -camera.top;
    camera.left   = -camera.right;

    if follow_cursor && camera.top < camera_top_max() {
        world_from_view := inverse(make_look_at_matrix(camera));
        delta_world := zoom_factor *(world_from_view * (zoomed_view - previous_view)).xyz;
        camera.eye_position += delta_world;
        camera.look_position += delta_world;
    }

    camera_clamp_orthographic_view_planes();
}

// Adjust the camera position and viewing volume to fit the visible geometry while preserving the camera look direction
fit_scene_on_screen :: (accurate : bool = false) {
    sphere := visible_entities_bounding_sphere(accurate);
    fit_sphere_on_screen(sphere, sphere.radius);
}

// Adjust the camera position and viewing volume to fit the entity while preserving the camera look direction
fit_on_screen :: (entity : *Entity, accurate : bool = false)
{
    if !entity.is_visible {
        return;
    }

    sphere := entity.render_info.bounding_sphere;
    transform(*sphere, entity.mesh.world_from_model);
    if entity.display_info.clip_sphere.is_active {
        sphere = entity.display_info.clip_sphere;
    }

    scene_sphere := visible_entities_bounding_sphere(accurate);
    sphere.radius += distance(sphere.center, scene_sphere.center);

    look_length := dot_product(unit_vector(current_look_direction()), sphere.center - app.camera.eye_position);

    fit_sphere_on_screen(sphere, look_length);
}

// Adjust the camera position and viewing volume to fit the world space sphere while preserving the camera look direction
fit_sphere_on_screen :: (_sphere : Sphere, look_length : float) {
    sphere := _sphere;

    if sphere.radius <= 0. {
        sphere.radius = 1.;
    }

    if look_length == 0. {
        look_length = 1.;
    }

    app.camera.scene_bounding_sphere = sphere;

    look_direction := current_look_direction();
    app.camera.look_position = sphere.center;
    app.camera.eye_position = app.camera.look_position - normalize_or_z_axis(look_direction) * look_length;
    app.camera.far    = distance(app.camera.look_position, app.camera.eye_position) + sphere.radius * 2;
    app.camera.top    = sphere.radius;
    app.camera.right  = current_window_aspect_ratio_width_over_height() * sphere.radius;
    app.camera.near   = distance(app.camera.look_position, app.camera.eye_position) - sphere.radius * 2;
    app.camera.bottom = -app.camera.top;
    app.camera.left   = -app.camera.right;

    camera_clamp_orthographic_view_planes();
}

camera_top_max :: () -> float {
    return app.settings.camera_zoom_max_screen_filling_length_factor * app.camera.scene_bounding_sphere.radius;
}

camera_clamp_orthographic_view_planes :: ()
{
    camera := *app.camera;

    lo := app.settings.camera_zoom_min_screen_filling_length_mm;
    hi := camera_top_max();

    aspect := current_window_aspect_ratio_width_over_height();

    if app.settings.camera_zoom_max_limited_by_scene_bounding_sphere {
        camera.top    = clamp(camera.top,   lo,          hi);
        camera.right  = clamp(camera.right, lo * aspect, hi * aspect);
        camera.bottom = -camera.top;
        camera.left   = -camera.right;
    } else {
        camera.top    = max(camera.top,   lo);
        camera.right  = max(camera.right, lo * aspect);
        camera.bottom = -camera.top;
        camera.left   = -camera.right;
    }
}

// @Cleanup use Math.make_look_at_matrix here
make_look_at_matrix :: (using camera : Camera) -> Matrix4 #must {
    f := normalize_or_z_axis(look_position - eye_position);
    s := normalize_or_z_axis(cross(f, up_direction));
    u := cross(s, f);

    m := matrix4_identity();

    // See glm::lookAtRH, but using row-major
    m.coef[0][0] =  s.x;
    m.coef[0][1] =  s.y;
    m.coef[0][2] =  s.z;
    m.coef[1][0] =  u.x;
    m.coef[1][1] =  u.y;
    m.coef[1][2] =  u.z;
    m.coef[2][0] = -f.x;
    m.coef[2][1] = -f.y;
    m.coef[2][2] = -f.z;
    m.coef[0][3] = -dot(s, eye_position);
    m.coef[1][3] = -dot(u, eye_position);
    m.coef[2][3] =  dot(f, eye_position);

    return m;
}

make_orthographic_projection_matrix :: (using camera : Camera) -> Matrix4 #must {
    return orthographic_projection_matrix(left, right, bottom, top, near, far);
}

make_projection_from_world :: (using camera : Camera) -> Matrix4 #must {
    view_from_world := make_look_at_matrix(camera);
    projection_from_view := make_orthographic_projection_matrix(camera);
    return projection_from_view * view_from_world;
}

io_mouse_left_down :: () -> bool { return io().MouseDown[0]; }
io_mouse_right_down :: () -> bool { return io().MouseDown[1]; }
io_mouse_middle_down :: () -> bool { return io().MouseDown[2]; }


// Return normalised device coordinates corresponding to the pixel position.
to_ndc :: (position_px : Vector2) -> Vector2
{
    using position_ndc : Vector2 = ---;
    x = 2 * (clamp(position_px.x, 0., xx app.current_window_width) / xx app.current_window_width) - 1;
    y = 2 * (clamp(position_px.y, 0., xx app.current_window_height) / cast(float)app.current_window_height) - 1;
    y *= -1; // (-1,-1) => bottom-left of screen, (+1,+1) => top-right of screen

    assert(x >= -1 && x <= 1, "Expected NDC x coordinates to be in range [-1,+1], got %", x);
    assert(y >= -1 && y <= 1, "Expected NDC y coordinates to be in range [-1,+1], got %", y);

    return position_ndc;
}

make_camera_ray :: () -> Ray3 {
    view_from_clip := inverse(make_orthographic_projection_matrix(app.camera));
    world_from_view := inverse(make_look_at_matrix(app.camera));
    transform := world_from_view * view_from_clip;
    inverse_transpose := transpose(inverse(transform));

    ray : Ray3 = ---;
    ray.origin = (transform * make_vector4(to_ndc(make_Vector2(io().MousePos)), -1., 1.)).xyz;
    ray.direction = (inverse_transpose * make_vector4(0., 0., 1., 0.)).xyz;
    check := normalize_or_zero(*ray.direction);
    assert(check != 0.); // @Robustness: handle this error

    return ray;
}

#scope_file

visible_entities_bounding_sphere :: (accurate : bool = false) -> Sphere
{
    if accurate {
        return visible_entities_bounding_sphere_accurate();
    }
    return visible_entities_bounding_sphere_fast();
}

// Returns a bounding sphere of the visible items in the scene in world space, considers clipping sphere/planes
visible_entities_bounding_sphere_fast :: () -> Sphere
{
    expand_sphere :: (result : *Sphere, mesh : *Mesh, info : *Render_Info, display_info : Display_Info, first : bool) {
        if mesh.positions.count == 0 return;

        maybe_update_render_info(info, mesh);

        clipped := false;
        if display_info.clip_sphere.is_active  {
            // This algorithm works well if the sphere center is known to be a vertex on the mesh,
            // which is probably is. In cases when its not this might not end up as a very good
            // bounding sphere of the visible geometry

            // @TODO in some cases we still may prefer the mesh bounding sphere...
            sphere := display_info.clip_sphere.sphere;

            if first {
                <<result = sphere;
            } else {
                expand(result, sphere);
            }
            clipped = true;
        }

        for display_info.clip_ranges if it.is_active log_warning("@Incomplete Updating the bounding sphere ignoring clipping planes");

        if !clipped {
            sphere := info.bounding_sphere;
            transform(*sphere, mesh.world_from_model);
            if first {
                <<result = sphere;
            } else {
                expand(result, sphere);
            }
        }
    }

    result : Sphere;

    first := true;
    for :visible app.entities {
        expand_sphere(*result, *it.mesh, *it.render_info, it.display_info, first);
        first = false;
    }

    if app.user_selection.is_visible {
        expand_sphere(*result, *app.user_selection.mesh, *app.user_selection.render_info, app.user_selection.display_info, first);
        first = false;
    }

    return result;
}

// Returns a bounding sphere of the visible items in the scene in world space
visible_entities_bounding_sphere_accurate :: () -> Sphere
{
    // Compute the bounding sphere the points in the scene
    points_vs : [..]Point3;
    for :visible entity : app.entities {

        warn := false;
        for entity.display_info.clip_ranges if it.is_active warn = true;
        if  entity.display_info.clip_sphere.is_active       warn = true;
        if warn log_warning("Updating the bounding sphere doesn't yet properly consider clipping planes @Incomplete");

        for * entity.mesh.positions {
            p := (entity.mesh.world_from_model * make_vector4(it, 1.)).xyz;
            array_add(*points_vs, p);
        }
    }

    if app.user_selection.is_visible {
        mesh := *app.user_selection.mesh;
        for * mesh.positions {
            p := (mesh.world_from_model * make_vector4(it, 1.)).xyz;
            array_add(*points_vs, p);
        }
    }

    result := bounding_sphere_ritter(points_vs);

    return result;
}

arcball_vector :: (mouse_position_px : Vector2) -> Vector3
{
    arcball_center_px := make_vector2(app.current_window_width / 2., app.current_window_height / 2.);
    // arcball_radius_px := min(app.current_window_height, app.current_window_width) / 2.; // allows room on left/right for rotation look direction
    arcball_radius_px := 5 * length(make_vector2(xx app.current_window_height, xx app.current_window_width) / 2); // only room to rotate on sphere

    using result := make_vector3((mouse_position_px - arcball_center_px) / arcball_radius_px, 0);

    x /= current_window_aspect_ratio_width_over_height();
    y *= -1; // Since y_px increases from the top of the screen to the bottom
    d2 := x*x + y*y;
    if d2 <= 1. {
        z = -sqrt(1. - d2); // In NDC units Z = -1 is closest to the camera
    } else {
        result = normalize(result);
    }
    return result;
}

camera_at_mouse_down : Camera;
rmb_down_pos : Vector2; // @Cleanup: replace this state with ImGui: use GetMouseDragDelta
