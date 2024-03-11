to_Mesh :: (sphere : Sphere) -> Simple_Mesh {
    ps_mesh := par_shapes_create_parametric_sphere(100, 100);
    par_shapes_scale(ps_mesh, sphere.radius, sphere.radius, sphere.radius);
    par_shapes_translate(ps_mesh, sphere.center);
    return to_Mesh(ps_mesh);
}

to_Mesh :: (shape : $T/Polyline_Soup) -> Simple_Mesh {
    #assert(T == Polyline_Soup2 || T == Polyline_Soup3);

    mesh : Simple_Mesh;

    index_offset := 0;
    for polyline : shape.polylines {
        if is_empty(polyline) {
            continue;
        }

        point := polyline.points[0];
#if T == Polyline_Soup2 {
        array_add(*mesh.positions, Vector3.{point.x, point.y, 0});
} else {
        array_add(*mesh.positions, point);
}

        for edge_index : 0..polyline.points.count-2 {
            point = polyline.points[edge_index + 1];
#if T == Polyline_Soup2 {
            array_add(*mesh.positions, Vector3.{point.x, point.y, 0});
} else {
            array_add(*mesh.positions, point);
}
            array_add(*mesh.segments, make_Tuple2(cast(u32) (index_offset + edge_index), xx (index_offset + edge_index  + 1)));
        }

        index_offset += polyline.points.count;
    }

    return mesh;
}

to_Polyline_Soup2 :: #bake_arguments to_Polyline_Soup(Point = Vector2);
to_Polyline_Soup3 :: #bake_arguments to_Polyline_Soup(Point = Vector3);

// @Cleanup @Refactor This should assert some pre-conditions and then never fail, it should not be called (in the obj loading function if the preconditions aren't met)
to_Polyline_Soup :: (mesh : Simple_Mesh, Point : $Type) -> Polyline_Soup(Point), bool #must {
    result : Polyline_Soup(Point);
    ok : bool;

    if mesh.segments.count == 0 || mesh.positions.count == 0 {
        return result, true;
    }

    get_edge :: (mesh : Simple_Mesh, edge_index : int) -> Indexed_Edge3, bool #must {
        edge : Indexed_Edge3;

        if edge_index >= mesh.segments.count {
            return edge, false;
        }

        edge.from_index = mesh.segments[2 * edge_index].x;
        edge.to_index   = mesh.segments[2 * edge_index].y;

        NP := mesh.positions.count;
        if (edge.from_index >= NP) || (edge.to_index >= NP) {
            return edge, false;
        }

        edge.from_point = *mesh.positions[edge.from_index];
        edge.to_point   = *mesh.positions[edge.to_index];

        return edge, true;
    }

    get_point :: inline (point : Vector3) -> Point {
        #if Point == Vector2 {
            return point.xy;
        } else {
            return point;
        }
    }

    edge_count := mesh.segments.count;

    edge_index := 0;
    edge : Indexed_Edge3;
    edge, ok = get_edge(mesh, edge_index);
    if !ok return result, false;

    // Start a new polyline
    polyline := array_add(*result.polylines);
    array_add(*polyline.points, get_point(edge.from_point));

    while true {
        prev_edge := edge;

        // Get next edge
        edge_index += 1;
        if edge_index >= edge_count {
            break;
        }

        edge, ok = get_edge(mesh, edge_index);
        if !ok return result, false;

        if edge.from_index == prev_edge.to_index {
            // Add to current polyline
            array_add(*polyline.points, get_point(edge.from_point));
        } else if edge_index != edge_count {
            // End current polyline
            array_add(*polyline.points, get_point(prev_edge.to_point));

            // Start a new polyline
            polyline = array_add(*result.polylines);
            array_add(*polyline.points, get_point(edge.from_point));
        }
    }

    // Terminate current polyline
    array_add(*polyline.points, get_point(edge.to_point));

    return result, true;
}

to_Mesh :: (shape : Polygon_Soup) -> Simple_Mesh {
    // @Incomplete
    using result : Simple_Mesh;
    return result;
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

