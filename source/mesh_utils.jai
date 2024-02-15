to_Mesh :: (sphere : Sphere) -> Simple_Mesh {
    ps_mesh := par_shapes_create_parametric_sphere(100, 100);
    par_shapes_scale(ps_mesh, sphere.radius, sphere.radius, sphere.radius);
    par_shapes_translate(ps_mesh, sphere.center);
    return to_Mesh(ps_mesh);
}

