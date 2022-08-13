to_Mesh :: (shape : $T/Polyline_Soup) -> Mesh {
    #assert(T == Polyline_Soup2 || T == Polyline_Soup3);

    mesh : Mesh;
    mesh.geometry_format = .LINES;

    index_offset := 0;
    for polyline : shape.polylines {
        if is_empty(polyline) {
            continue;
        }

        point := polyline.points[0];
#if T == Polyline_Soup2 {
        array_add(*mesh.positions, make_vector3(point.x, point.y, 0));
} else {
        array_add(*mesh.positions, point);
}

        for edge_index : 0..polyline.points.count-2 {
            point = polyline.points[edge_index + 1];
#if T == Polyline_Soup2 {
            array_add(*mesh.positions, make_vector3(point.x, point.y, 0));
} else {
            array_add(*mesh.positions, point);
}
            array_add(*mesh.indices, xx (index_offset + edge_index));
            array_add(*mesh.indices, xx (index_offset + edge_index  + 1));
        }

        index_offset += polyline.points.count;
    }

    return mesh;
}

to_Polyline_Soup2 :: #bake_arguments to_Polyline_Soup(Point = Vector2);
to_Polyline_Soup3 :: #bake_arguments to_Polyline_Soup(Point = Vector3);

to_Polyline_Soup :: (mesh : Mesh, Point : $Type) -> Polyline_Soup(Point), bool #must {
    result : Polyline_Soup(Point);
    ok : bool;

    if mesh.geometry_format != .LINES {
        return result, false;
    }

    if mesh.indices.count < 2 || mesh.positions.count == 0 {
        return result, true;
    }

    get_edge :: (mesh : Mesh, edge_index : int) -> Indexed_Edge3, bool #must {
        edge : Indexed_Edge3;

        NI := mesh.indices.count;
        if 2 * edge_index >= NI {
            return edge, false;
        }

        edge.from_index = mesh.indices[2 * edge_index];
        edge.to_index   = mesh.indices[2 * edge_index + 1];

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

    edge_count := mesh.indices.count / 2;

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

to_Mesh :: (shape : Polygon_Soup) -> Mesh {
    // @Incomplete
    using result : Mesh;
    geometry_format = .TRIANGLES;
    return result;
}


to_Mesh :: (m : par_shapes_mesh) -> Mesh {
    using result : Mesh;

    geometry_format = .TRIANGLES;
    array_copy(*positions, m.points);
    array_copy(*normals, m.normals);

    array_reserve(*indices, m.triangles.count * 3);
    memcpy(indices.data, m.triangles.data, m.triangles.count * size_of(m.Triangle));
    indices.count = m.triangles.count * 3;

    // @Incomplete tcoords

    return result;
}

