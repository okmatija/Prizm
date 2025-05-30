Camera :: struct {
    // Data to transfrom from world to view coordinates
    eye_position :  Vector3; // world
    look_position : Vector3;
    up_direction :  Vector3;

    rotation_axis := Camera_Rotation_Axis.ROLL; // :UserConfig use configurable default

    // @Cleanup Is this even used?? Remove it, we can compute from the entities or the look/eye_positions
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

    show_ui := true;
}

almost_equal :: (a : Camera, b : Camera) -> bool {
    return
        almost_equal(a.eye_position, b.eye_position) &&
        almost_equal(a.look_position, b.look_position) &&
        almost_equal(a.up_direction, b.up_direction) &&
        almost_equal(a.left, b.left) &&
        almost_equal(a.right, b.right) &&
        almost_equal(a.bottom, b.bottom) &&
        almost_equal(a.top, b.top) &&
        almost_equal(a.near, b.near) &&
        almost_equal(a.far, b.far);
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
    min_point_vs := Vector3.{app.camera.left,  app.camera.bottom, app.camera.near};
    max_point_vs := Vector3.{app.camera.right, app.camera.top,    app.camera.far};
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

    up := normalize(cross(.{-1, 1, 0}, .{-1, -1, -1}));
    set_look_direction(direction=.{-1, -1, -1}, up=up);
}

update_camera :: () {
    camera := *app.camera;

    if io().WantCaptureMouse return;

    if ImGui.IsMouseClicked(.Right) {
        rmb_down_pos = make_Vector2(io().MousePos);
        camera_at_mouse_down = app.camera;
    }

    valid, world_from_projection := inverse(make_projection_from_world(camera));
    if !valid vlog_warning("Could not invert projection_from_world matrix created from camera '%'", camera);

    if mouse_reposition_camera() {

        closest_world : Closest_Point_Ray_Entity = find_closest_element();
        if closest_world.entity_index != -1 {

            // We want to shift the camera over to look at the new point but preserve the top/bottom/left/right planes

            position_world : Vector3 = get_closest_point_on_element(closest_world);
            sphere : Sphere = entities_world_bounding_radius(visit_visible, position_world);
            assert(is_empty(sphere) == false); // if got closest.entity_index != -1 we should have a sphere

            view_from_world := make_look_at_matrix(app.camera);
            valid, world_from_view := inverse(view_from_world);
            if !valid vlog_warning("Could not inverset view from world matrix '%'", view_from_world);
        
            position_view := transform_point(view_from_world, position_world);
            eye_displacement := transform_vector(world_from_view, Vector3.{position_view.x, position_view.y, 0.});
        
            app.camera.look_position = position_world;
            app.camera.eye_position  += eye_displacement;
        
            look_length := distance(app.camera.look_position, app.camera.eye_position);
            app.camera.far  = look_length + sphere.radius * 2;
            app.camera.near = look_length - sphere.radius * 2;
        }

    } else if mouse_pan_camera() { // Pan with middle down.

        get_pan_position :: (mouse_position_px : Vector2, world_from_projection : Matrix4, camera : Camera) -> Vector3, bool {
            plane := make_hyperplane3(unit_vector(camera.eye_position - camera.look_position), camera.look_position);
            line : Line3 = ---;
            line.origin = (world_from_projection * Vector4.{xy=to_ndc(mouse_position_px), z=-1., w=1.}).xyz;
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

            // TODOOO We also need to adjust the near and far planes here! Currently when we pan and rotate things start getting clipped
        }

    } else if mouse_orbit_camera() { // Orbit about the look position using right button. Make sure Ctrl is not down since Ctrl RMB sets the camera orbit and its annoying to have the camera start rotating after you do that..!

        world_from_projection_at_mouse_down := inverse(make_projection_from_world(camera_at_mouse_down));

        prev_arcball_vector := arcball_vector(rmb_down_pos);
        curr_arcball_vector := arcball_vector(make_Vector2(io().MousePos));
        arcball_axis_ndc := cross_product(curr_arcball_vector, prev_arcball_vector);

        view_from_world := make_look_at_matrix(camera_at_mouse_down);
        valid, world_from_view := inverse(view_from_world);
        if !valid vlog_warning("Could not invert view_from_world matrix '%'", view_from_world);
        arcball_axis_world := (world_from_view * Vector4.{xyz=arcball_axis_ndc}).xyz;

        arcball_angle := angle(curr_arcball_vector, prev_arcball_vector);

        if io().KeyShift { // :CameraAlternativeRotationAxis
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
            debug_vector(l, (world_from_projection * Vector4.{xyz=prev_arcball_vector}).xyz, .{1., .5, .5, 1.});
            debug_vector(l, (world_from_projection * Vector4.{xyz=curr_arcball_vector}).xyz, .{.5, 1., .5, 1.});
            debug_vector(l, look_to_eye, .{1., 1., 1., 1.});
            debug_vector(l, rotate(camera_at_mouse_down.up_direction, q), .{1., 1., 1., 1.});
            debug_vector(l, camera_at_mouse_down.eye_position - camera_at_mouse_down.look_position, .{1., 1., 0., 1.});
            debug_vector(l, camera_at_mouse_down.up_direction, .{1., 1., 0., 1.});
        }

        camera.eye_position = camera_at_mouse_down.look_position + look_to_eye;
        camera.up_direction = rotate(camera_at_mouse_down.up_direction, q);

    } else if mouse_zoom_camera() { // Zoom with scroll wheel

        ratio := app.settings.camera_zoom_scrolling_ratio;
        if      io().KeyAlt   ratio = .97;
        // else if io().KeyShift ratio = .5;

        zoom_factor := 1.;
        if      (io().MouseWheel > 0) zoom_factor *= ratio;
        else if (io().MouseWheel < 0) zoom_factor /= ratio;
        handle_zoom(zoom_factor, make_Vector2(io().MousePos), !io().KeyShift);
    }
}

handle_zoom :: (zoom_factor : float, previous_pos : Vector2, follow_cursor : bool) {

    camera := *app.camera;

    valid, view_from_clip := inverse(make_orthographic_projection_matrix(camera));
    if !valid vlog_warning("Could not invert orthographic projection matrix created from cameara '%'", camera);

    previous_clip := to_ndc(previous_pos);
    zoomed_clip := previous_clip / zoom_factor;

    previous_view := view_from_clip * Vector4.{xy=previous_clip, w=1.};
    zoomed_view := view_from_clip * Vector4.{xy=zoomed_clip, w=1.};

    camera.top   *= zoom_factor;
    camera.right *= zoom_factor;
    camera.bottom = -camera.top;
    camera.left   = -camera.right;

    if follow_cursor {
        valid=, world_from_view := inverse(make_look_at_matrix(camera));
        if !valid vlog_warning("Could not invert orthographic projection matrix created from cameara '%'", camera);
        delta_world := zoom_factor *(world_from_view * (zoomed_view - previous_view)).xyz;
        camera.eye_position += delta_world;
        camera.look_position += delta_world;
    }

    camera_clamp_orthographic_view_planes();
}

// @Cleanup There are some weird issues still happenening here e.g., load blend*obj, select all and then press f on repeat, the camera should not be changing but it does

// Adjust the camera position and viewing volume to fit the visible geometry while preserving the camera look direction
// The camera orbit will be centered on the centroid of all visible entities
fit_scene_on_screen :: () {
    fit_on_screen_multiple(visit_visible);
}

// While preserving the camera look direction:
// 1. Set the camera look position to the center of `entity_world_bounding_sphere`
// 2. Set the camera near/far/top/bottom/left/right planes to fit all visible items on the screen
fit_on_screen :: (entity : *Entity) {
    // Compute camera look position as the center of the bounding sphere of the visible entity geometry
    look_sphere := entity_world_bounding_sphere(entity);

    if is_empty(look_sphere) {
        return; // Do nothing, we don't know where to look
    }

    // Compute the sphere, centered on `look_position`, to place the camera planes
    camera_sphere := entities_world_bounding_radius(visit_visible, look_sphere.center);
    assert(!is_empty(camera_sphere)); // If look_sphere was not empty this shouldn't be!

    // Update the camera to fit the camera sphere
    fit_sphere_on_screen(camera_sphere);
}

// As `fit_on_screen` but for multiple entities
fit_on_screen_multiple :: ($entity_filter : Code = visit_visible) {
    // Compute a sphere whose center will be the look position
    look_sphere := entities_world_bounding_sphere(entity_filter);

    if is_empty(look_sphere) {
        return; // Do nothing, we don't know where to look
    }

    // Compute a sphere centered on `look_position`, to place the camera planes
    camera_sphere := entities_world_bounding_radius(visit_visible, look_sphere.center);
    assert(!is_empty(camera_sphere)); // If look_sphere was not empty this shouldn't be!

    // Update the camera to fit the camera sphere
    fit_sphere_on_screen(camera_sphere);
}

// While preserving the camera look direction:
// 1. Set the camera look position to the center of `entity_world_bounding_sphere`
// 2. Set the camera top/bottom/left/right planes to fit the `entity_world_bounding_sphere` sphere
// 3. Set the camera near/far planes to fit all visible items on the screen
fit_on_screen_filled :: (entity : *Entity) {

    // Compute a tight sphere the bounding sphere of the visible entity geometry
    look_sphere := entity_world_bounding_sphere(entity);

    if is_empty(look_sphere) {
        return; // Do nothing, we don't know where to look
    }

    // Update the camera as described in `fit_on_screen` and cache it
    fit_on_screen(entity);
    near_far_camera := app.camera;
    assert(look_sphere.center == near_far_camera.look_position);

    // Update the camera to fit the tight sphere
    fit_sphere_on_screen(look_sphere);

    // Update the near/far planes so they fit all visible geometry 
    app.camera.near = near_far_camera.near;
    app.camera.far = near_far_camera.far;
}

// As `fit_on_screen_filled` but for multiple entities
fit_on_screen_filled_multiple :: ($entity_filter : Code = visit_visible) {

    // Compute a tight sphere the bounding sphere of the filter-passing geometry
    look_sphere := entities_world_bounding_sphere(entity_filter);

    if is_empty(look_sphere) {
        return; // Do nothing, we don't know where to look
    }

    // Update the camera as described in `fit_on_screen` and cache it
    fit_on_screen_multiple(entity_filter);
    near_far_camera := app.camera;
    assert(look_sphere.center == near_far_camera.look_position);

    // Update the camera to fit the tight sphere
    fit_sphere_on_screen(look_sphere);

    // Update the near/far planes so they fit all visible geometry 
    app.camera.near = near_far_camera.near;
    app.camera.far = near_far_camera.far;
    app.camera.eye_position = near_far_camera.eye_position;
}

// Adjust the camera position and viewing volume to fit the world space sphere while preserving the camera look direction
//
// It's important to position the eye on the boundary of the sphere, so that we avoid a bug like this:
//
//    a   <-E
//
//          E->   b
//
// Here the eye, E, is positioned between objects a and b, so when you change the look position to be centered on one and the other and the camera gets shifted if starts looking in opposite directions
fit_sphere_on_screen :: (sphere_world : Sphere) {
    if is_empty(sphere_world) {
        // :PreserveCameraPositionWithNoVisibleItems
        // Do nothing. This is useful behaviour if, for example, the user hides all items, doesn't move the mouse but then presses 'f', in this case we don't want to change the camera so that if the user unhides all the items are in the same place as before
        return;
    }

    app.camera.scene_bounding_sphere = sphere_world;
    buffer_factor := 0.0; // Maybe this should be more than 0?

    look_direction := normalize(current_look_direction(), fallback=.{z=1});
    app.camera.look_position = sphere_world.center;
    app.camera.eye_position  = sphere_world.center - sphere_world.radius * look_direction;
    app.camera.far    = (2. + buffer_factor) * sphere_world.radius;
    app.camera.top    = sphere_world.radius;
    app.camera.right  = current_window_aspect_ratio_width_over_height() * sphere_world.radius;
    app.camera.near   = (0. - buffer_factor) * sphere_world.radius;
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

    aspect := current_window_aspect_ratio_width_over_height();

    if app.settings.camera_zoom_max_limited_by_scene_bounding_sphere {
        hi := camera_top_max();
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
make_look_at_matrix :: (using camera : Camera) -> Matrix4 {
    f := normalize(look_position - eye_position, fallback=.{z=1});
    s := normalize(cross(f, up_direction), fallback=.{z=1});
    u := cross(s, f);

    m := Matrix4_Identity;

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

make_orthographic_projection_matrix :: (using camera : Camera) -> Matrix4 {
    return orthographic_projection_matrix(left, right, bottom, top, near, far);
}

make_projection_from_world :: (using camera : Camera) -> Matrix4 {
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
    x = 2 * (clamp(position_px.x, 0., cast(float) app.window_size.width) /  cast(float)app.window_size.width) - 1;
    y = 2 * (clamp(position_px.y, 0., cast(float) app.window_size.height) / cast(float)app.window_size.height) - 1;
    y *= -1; // (-1,-1) => bottom-left of screen, (+1,+1) => top-right of screen

    assert(x >= -1 && x <= 1, "Expected NDC x coordinates to be in range [-1,+1], got %", x);
    assert(y >= -1 && y <= 1, "Expected NDC y coordinates to be in range [-1,+1], got %", y);

    return position_ndc;
}

// @Cleanup Rename to make it clear this is in world space
// @Robustness: handle the errors in this function
make_camera_ray :: () -> Ray3 {
    valid, view_from_clip := inverse(make_orthographic_projection_matrix(app.camera));
    if !valid vlog_warning("Could not invert orthographic projection matrix created from camera '%'", app.camera);

    valid=, world_from_view := inverse(make_look_at_matrix(app.camera));
    if !valid vlog_warning("Could not invert look at matrix created from camera '%'", app.camera);

    transform := world_from_view * view_from_clip;
    valid=, transform_inverse := inverse(transform);
    if !valid vlog_warning("Could not invert matrix '%'", transform);
    inverse_transpose := transpose(transform_inverse);

    ray : Ray3 = ---;
    ray.origin = (transform * Vector4.{xy=to_ndc(make_Vector2(io().MousePos)), z=-1., w=1.}).xyz;
    ray.direction = (inverse_transpose * Vector4.{z=1.}).xyz;
    normalize(*ray.direction, fallback=.{z=1.});

    return ray;
}

#scope_file

arcball_vector :: (mouse_position_px : Vector2) -> Vector3
{
    arcball_center_px := Vector2.{app.window_size.width / 2., app.window_size.height / 2.};
    // arcball_radius_px := min(app.window_size.height, app.window_size.width) / 2.; // allows room on left/right for rotation look direction
    arcball_radius_px := 5 * length(arcball_center_px); // only room to rotate on sphere

    using result := Vector3.{xy=(mouse_position_px - arcball_center_px) / arcball_radius_px};

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

#scope_export
camera_at_mouse_down : Camera;
rmb_down_pos : Vector2; // @Cleanup: replace this state with ImGui: use GetMouseDragDelta
