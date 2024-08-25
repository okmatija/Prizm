Axes_Triad :: struct {
    x_axis : Entity;
    y_axis : Entity;
    z_axis : Entity;
    origin : Entity;

    visible := true;
}

make_axes_triad :: (axis_length : float) -> Axes_Triad
{
    par_shapes_triad := make_triad(axis_length);
    defer deinit(*par_shapes_triad);

    using result : Axes_Triad;

    x_axis.mesh = to_Mesh(par_shapes_triad.x_axis);
    y_axis.mesh = to_Mesh(par_shapes_triad.y_axis);
    z_axis.mesh = to_Mesh(par_shapes_triad.z_axis);
    origin.mesh = to_Mesh(par_shapes_triad.origin);

    x_axis.display_info = .{triangle_style.backface_style.color_mode=.COPIED, triangle_style.visible=true, triangle_style.color=.{1., 0., 0., 1.}};
    y_axis.display_info = .{triangle_style.backface_style.color_mode=.COPIED, triangle_style.visible=true, triangle_style.color=.{0., 1., 0., 1.}};
    z_axis.display_info = .{triangle_style.backface_style.color_mode=.COPIED, triangle_style.visible=true, triangle_style.color=.{0., 0., 1., 1.}};
    origin.display_info = .{triangle_style.backface_style.color_mode=.COPIED, triangle_style.visible=true, triangle_style.color=.{.3, .3, .3, 1.}};

    return result;
}

render_axes_triad :: () {
    if app.triad.visible == false {
        return;
    }

    // @Refactor This is a confusing function with bad variable names

    using *app.camera;
    old_camera := app.camera;
    defer app.camera = old_camera;

    w, h : float = cast(float)app.window_size.width, cast(float)app.window_size.height;
    s := 80.;
    a := current_window_aspect_ratio_width_over_height();

    near, far = -s, s;
    bottom, top = 0., h;
    left, right = 0., w;
    unit_look_direction := normalize(current_look_direction());
    look_position = Vector3.{};
    eye_position = look_position - unit_look_direction;

    offset_vs := Vector3.{s, s, 0.} + Vector3.{w - 2*s - WINDOW_BORDER_UI_OFFSET.x, WINDOW_BORDER_UI_OFFSET.y, 0};
    world_from_view := inverse(make_look_at_matrix(app.camera));
    offset_ws := (world_from_view * Vector4.{xyz=offset_vs}).xyz;

    scale := make_scale_matrix4(.8 * Vector3.{s, s, s});
    shift := make_translation_matrix4(offset_ws);
    xform := shift * scale;

    app.triad.origin.mesh.world_from_model = xform;
    app.triad.x_axis.mesh.world_from_model = xform;
    app.triad.y_axis.mesh.world_from_model = xform;
    app.triad.z_axis.mesh.world_from_model = xform;

    ScopeGlState();

    render_mesh_triangles(app.triad.origin);
    render_mesh_triangles(app.triad.x_axis);
    render_mesh_triangles(app.triad.y_axis);
    render_mesh_triangles(app.triad.z_axis);

    // Bug Screws up the background shader!!?
    // render_mesh_triangles_as_lines(*app.triad.origin.mesh, *app.triad.origin.render_info, app.triad.origin.display_info);
    // render_mesh_triangles_as_lines(*app.triad.x_axis.mesh, *app.triad.x_axis.render_info, app.triad.x_axis.display_info);
    // render_mesh_triangles_as_lines(*app.triad.y_axis.mesh, *app.triad.y_axis.render_info, app.triad.y_axis.display_info);
    // render_mesh_triangles_as_lines(*app.triad.z_axis.mesh, *app.triad.z_axis.render_info, app.triad.z_axis.display_info);
}

#if 0 #run {
    using triad := make_triad(1);

    par_shapes_export(x_axis, "debug_x_arrow.obj");
    par_shapes_export(y_axis, "debug_y_arrow.obj");
    par_shapes_export(z_axis, "debug_z_arrow.obj");
    par_shapes_export(origin, "debug_origin.obj");

    #if 0 {
        cylinder := par_shapes_create_cylinder(8, 5);
        par_shapes_export(cylinder, "debug_cylinder.obj");
        deinit(cylinder);

        cone := par_shapes_create_cone(8, 5);
        par_shapes_export(cone, "debug_cone.obj");
        deinit(cone);

        disk := par_shapes_create_disk(8, 5);
        par_shapes_export(disk, "debug_disk.obj");
        deinit(disk);

        plane := par_shapes_create_plane(8, 5);
        par_shapes_export(plane, "debug_plane.obj");
        deinit(plane);

        sphere := par_shapes_create_parametric_sphere(8, 5);
        par_shapes_export(sphere, "debug_sphere.obj");
        deinit(sphere);

        hemisphere := par_shapes_create_hemisphere(8, 5);
        par_shapes_export(hemisphere, "debug_hemisphere.obj");
        deinit(hemisphere);

        torus := par_shapes_create_torus(16, 16, .2);
        par_shapes_export(torus, "debug_torus.obj");
        deinit(torus);
    }

    print("Done writing debug_*.obj meshes\n");
}

make_axis_arrow :: (axis_length : float) -> par_shapes_mesh {
    using params := make_triad_parameters(axis_length);

    result := par_shapes_create_cylinder(32, 1);
    par_shapes_scale(result, axis_radius, axis_radius, axis_length);

    cone := par_shapes_create_cone(32, 1);
    defer deinit(cone);
    par_shapes_scale(cone, cone_radius, cone_radius, cone_length);
    par_shapes_translate(cone, Vector3.{z=axis_length});


    base := par_shapes_create_disk(32, 1);
    defer deinit(base);
    par_shapes_scale(base, cone_radius, cone_radius, cone_length);
    par_shapes_translate(base, Vector3.{z=axis_length});

    par_shapes_merge(result, cone);
    par_shapes_merge(result, base);

    return result;
}

#scope_file

Triad_Parameters :: struct {
    axis_radius : float;
    cone_length : float;
    cone_radius : float;
    origin_radius : float;
}

make_triad_parameters :: (axis_length : float) -> Triad_Parameters {
    using result : Triad_Parameters;

    axis_radius = axis_length / 40;
    cone_length = axis_radius * 10;
    cone_radius = axis_radius * 3;
    origin_radius = axis_radius * 2;

    return result;
}

Triad :: struct {
    x_axis : par_shapes_mesh;
    y_axis : par_shapes_mesh;
    z_axis : par_shapes_mesh;
    origin : par_shapes_mesh;
}

make_triad :: (axis_length : float) -> Triad {
    using params := make_triad_parameters(axis_length);

    using result : Triad;

    x_axis = make_axis_arrow(axis_length);
    par_shapes_rotate(x_axis, PI/2, Vector3.{0, 1, 0});

    y_axis = make_axis_arrow(axis_length);
    par_shapes_rotate(y_axis, -PI/2, Vector3.{1, 0, 0});

    z_axis = make_axis_arrow(axis_length);

    origin = par_shapes_create_parametric_sphere(32, 32);
    par_shapes_scale(origin, origin_radius, origin_radius, origin_radius);

    return result;
}

deinit :: (using triad : *Triad) {
    deinit(triad.x_axis);
    deinit(triad.y_axis);
    deinit(triad.z_axis);
    deinit(triad.origin);
}