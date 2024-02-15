to_Mesh :: (sphere : Sphere) -> Simple_Mesh {
    ps_mesh := par_shapes_create_parametric_sphere(100, 100);
    par_shapes_scale(ps_mesh, sphere.radius, sphere.radius, sphere.radius);
    par_shapes_translate(ps_mesh, sphere.center);
    return to_Mesh(ps_mesh);
}


to_Mesh :: (m : par_shapes_mesh) -> Simple_Mesh {
    using result : Simple_Mesh;

    // @Incomplete Copy normals to the triangle normals attribute
    array_copy(*positions, m.points);
    array_reserve(*triangles, m.triangles.count);
    memcpy(triangles.data, m.triangles.data, m.triangles.count * size_of(m.Triangle));
    triangles.count = m.triangles.count;

    // @Incomplete tcoords

    return result;
}

