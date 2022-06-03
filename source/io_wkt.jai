load_wkt :: (filename : string, data : string, name : string) -> *Entity {

    if !data {
        log("File was empty");
        return null;
    }

    entity : *Entity;

    parser : Parser;
    parser.data = data;
    parser.tokens = get_tokens(filename, parser.data);
    parser.current_token = 0;

    defer deinit(*parser);

    // Make sure we at least got the end-of-file token
    assert(parser.tokens.count > 0);
    assert(parser.tokens[parser.tokens.count - 1].type == .EOF);

    ok : bool = true;

    while peek_token(*parser).type != .EOF && !parser.failed {

        if eat_possible_identifier(*parser, "POINT") {

            entity = New(Point_Cloud_Entity);

            expect_and_eat(*parser, xx #char "(");
            point2 : Vector2 = ---;
            point3 : Vector3 = ---;
            dim := parse_point(*parser, *point2, *point3);
            expect_and_eat(*parser, xx #char ")");

            if parser.failed {
                break;
            } else if dim == 2 {
                array_add(*entity.mesh.positions, make_vector3(point2, 0));
            } else if dim == 3 {
                array_add(*entity.mesh.positions, point3);
            } else {
                assert(false, "Unreachable, we should have set parser failure in this case!");
            }

            e := cast(*Point_Cloud_Entity)entity;
            e.spatial = New(AABB_Tree(e.Shape));
            init(e.spatial, *e.shape);

        } else if eat_possible_identifier(*parser, "MULTIPOINT") {

            entity = New(Point_Cloud_Entity);

            points2 : [..]Vector2;
            points3 : [..]Vector3;
            dim := parse_points(*parser, *points2, *points3);

            if parser.failed {
                break;
            } else if dim == 0 {
                break; // empty point cloud
            } else if dim == 2 {
                for points2 array_add(*entity.mesh.positions, make_vector3(it, 0));
            } else if dim == 3 {
                entity.mesh.positions = points3;
            } else {
                assert(false, "Unreachable, we should have set parser failure in this case!");
            }

            e := cast(*Point_Cloud_Entity)entity;
            e.spatial = New(AABB_Tree(e.Shape));
            init(e.spatial, *e.shape);

        } else if eat_possible_identifier(*parser, "LINESTRING") {

            points2 : [..]Vector2;
            points3 : [..]Vector3;
            dim := parse_points(*parser, *points2, *points3);

            if parser.failed {
                break;
            } else if dim == 0 {

                // @Cleanup what the heck is this code, just fail??
                empty_shape : Polyline_Soup3;
                empty_mesh : Mesh;
                empty_mesh.geometry_format = .LINES;
                entity = New(Polyline_Soup3_Entity);
                e : *Polyline_Soup3_Entity = xx entity;
                e.shape = empty_shape;
                e.mesh = empty_mesh;
                e.spatial = New(AABB_Tree(e.Shape));
                init(e.spatial, *e.shape);

            } else if dim == 2 {

                entity = New(Polyline_Soup2_Entity);
                e : *Polyline_Soup2_Entity = xx entity;
                array_add(*e.shape.polylines).points = points2;
                e.mesh = to_Mesh(e.shape);
                e.spatial = New(AABB_Tree(e.Shape));
                init(e.spatial, *e.shape);

            } else if dim == 3 {

                entity = New(Polyline_Soup3_Entity);
                e : *Polyline_Soup3_Entity = xx entity;
                array_add(*e.shape.polylines).points = points3;
                e.mesh = to_Mesh(e.shape);
                e.spatial = New(AABB_Tree(e.Shape));
                init(e.spatial, *e.shape);

            } else {
                assert(false, "Unreachable, we should have set parser failure in this case!");
            }

        } else if eat_possible_identifier(*parser, "MULTILINESTRING") {

            polyline_soup2 : Polyline_Soup2;
            polyline_soup3 : Polyline_Soup3;

            dim := parse_polyline_soup(*parser, *polyline_soup2, *polyline_soup3);

            if parser.failed {
                break;
            } else if dim == 0 {
                break; // empty polyline soup
            } else if dim == 2 {

                entity = New(Polyline_Soup2_Entity);
                e : *Polyline_Soup2_Entity = xx entity;
                e.shape = polyline_soup2;
                e.mesh = to_Mesh(e.shape);
                e.spatial = New(AABB_Tree(e.Shape));
                init(e.spatial, *e.shape);

            } else if dim == 3 {

                entity = New(Polyline_Soup3_Entity);
                e : *Polyline_Soup3_Entity = xx entity;
                e.shape = polyline_soup3;
                e.mesh = to_Mesh(e.shape);
                e.spatial = New(AABB_Tree(e.Shape));
                init(e.spatial, *e.shape);

            } else {
                assert(false, "Unreachable, we should have set parser failure in this case!");
            }

        } else if eat_possible_identifier(*parser, "POLYGON") {

            polygon := parse_polygon(*parser);

            e := New(Polygon_Soup_Entity);
            array_add(*e.shape.polygons, polygon);
            e.mesh = to_Mesh(e.shape);
            e.spatial = New(AABB_Tree(e.Shape));
            init(e.spatial, *e.shape);

            if !is_empty(e.shape) && e.mesh.positions.count == 0 {
                log_error("Loading polygons is not supported because polygon triangulation is not yet implemented, sorry!\n");
                parser.failed = true;
            }

            entity = e;

        } else if eat_possible_identifier(*parser, "MULTIPOLYGON") {

            polygon_soup := parse_polygon_soup(*parser);

            e := New(Polygon_Soup_Entity);
            e.shape = polygon_soup;
            e.mesh = to_Mesh(e.shape);
            e.spatial = New(AABB_Tree(e.Shape));
            init(e.spatial, *e.shape);

            if !is_empty(e.shape) && e.mesh.positions.count == 0 {
                log_error("Loading polygons is not supported because polygon triangulation is not yet implemented, sorry!\n");
                parser.failed = true;
            }

            entity = e;

        } else {
            error(*parser, peek_token(*parser), "Unexpected token %.\n", to_string(peek_token(*parser)));
            break;
        }
    }

    entity.source = .FILE_ON_DISK;
    entity.fully_pathed_filename = copy_string(filename);
    color := color_from_path(filename);
    init_entity_base_parameters(entity, name, color, entity.mesh);

    if parser.failed || (entity && entity.type == .UNKNOWN) {
        deinit(entity);
        return null;
    }

    return entity;
}

#scope_file

is_number :: (t : Token) -> bool {
    return t.type == .INTEGER || t.type == .FLOAT;
}

// Parses and returns a 2D or 3D point, or sets p.failed to true
// @Cleanup: Why bother with loc here?
parse_point :: (p: *Parser, point2 : *Vector2, point3 : *Vector3, loc := #caller_location) -> dim : int {
    dim := 0;
    dim += xx is_number(peek_ahead(p, 0));
    dim += xx is_number(peek_ahead(p, 1));
    dim += xx is_number(peek_ahead(p, 2));

    if dim == 1 {
        error(p, peek_token(p), "Expected 2D or 3D point, but only got one component %.\n", to_string(peek_token(p)));
    } else if dim == 2 {
        <<point2 = parse_vector2(p);
    } else if dim == 3 {
        <<point3 = parse_vector3(p);
    }

    return dim;
}

// Parses and returns an array of 2D or 3D points, or sets p.failed to true
parse_points :: (p : *Parser, points2 : *[..]Vector2, points3 : *[..]Vector3, loc := #caller_location) -> dim : int {

    expect_and_eat(p, xx #char "(");

    while peek_token(p).type != .EOF && peek_token(p).type != xx #char ")" {
        point2 : Vector2 = ---;
        point3 : Vector3 = ---;
        dim := parse_point(p, *point2, *point3);

        if p.failed {
            break;
        } else if dim == 0 {
            continue;
        } else if dim == 2 {
            if points3.count {
                error(p, peek_token(p), "Expected 3D point but got a 2D point");
                break;
            }
            array_add(points2, point2);
        } else if dim == 3 {
            if points2.count {
                error(p, peek_token(p), "Expected 2D point but got a 3D point");
                break;
            }
            array_add(points3, point3);
        } else {
            assert(false, "Unreachable, we should have set parser failure in this case!");
        }

        eat_possible_token(p, xx #char ",");
    }

    expect_and_eat(p, xx #char ")");

    if points2.count return 2;
    if points3.count return 3;
    return 0;
}

// Fills in one of the passed polyline soups and returns a dimension to indicate which
parse_polyline_soup :: (p : *Parser, polyline_soup2 : *Polyline_Soup2, polyline_soup3 : *Polyline_Soup3, loc := #caller_location) -> dim : int {

    expect_and_eat(p, xx #char "(");

    while peek_token(p).type != .EOF && peek_token(p).type != xx #char ")" {

        polyline2 : Polyline2;
        polyline3 : Polyline3;
        dim := parse_points(p, *polyline2.points, *polyline3.points);

        if p.failed {
            break;
        } else if dim == 0 {
            continue;
        } else if dim == 2 {
            if polyline_soup3.polylines.count {
                error(p, peek_token(p), "Expected 3D polyline but got a 2D polyline");
                break;
            }
            array_add(*polyline_soup2.polylines, polyline2);
        } else if dim == 3 {
            if polyline_soup2.polylines.count {
                error(p, peek_token(p), "Expected 2D polyline but got a 3D polyline");
                break;
            }
            array_add(*polyline_soup3.polylines, polyline3);
        } else {
            assert(false, "Unreachable, we should have set parser failure in this case!");
        }

        eat_possible_token(p, xx #char ",");
    }

    expect_and_eat(p, xx #char ")");

    if polyline_soup2.polylines.count return 2;
    if polyline_soup3.polylines.count return 3;
    return 0;
}

parse_polygon :: (p : *Parser, loc := #caller_location) -> Polygon {

    polygon : Polygon;

    expect_and_eat(p, xx #char "(", loc);

    is_outer := true;

    while peek_token(p).type != .EOF && peek_token(p).type != xx #char ")" {

        points2 : [..]Vector2;
        points3 : [..]Vector3;
        dim := parse_points(p, *points2, *points3);

        if p.failed {
            break;
        } else if dim == 2 {
            if is_outer {
                ring : Ring;
                ring.points = points2;
                polygon.outer_ring = ring;
            } else {
                array_add(*polygon.inner_rings).points = points2;
            }
        } else {
            error(p, peek_token(p), "Expected 2D points but got 3D points");
        }

        eat_possible_token(p, xx #char ",");
        is_outer = false;
    }

    expect_and_eat(p, xx #char ")", loc);

    return polygon;
}

parse_polygon_soup :: (p : *Parser, loc := #caller_location) -> Polygon_Soup {

    polygon_soup : Polygon_Soup;

    expect_and_eat(p, xx #char "(", loc);
    while peek_token(p).type != .EOF && peek_token(p).type != xx #char ")" {
        array_add(*polygon_soup.polygons, parse_polygon(p));
        eat_possible_token(p, xx #char ",");
    }
    expect_and_eat(p, xx #char ")", loc);

    return polygon_soup;
}