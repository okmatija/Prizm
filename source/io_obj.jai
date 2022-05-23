// http://paulbourke.net/dataformats/obj/

// @Cleanup Read shape from an obj and then turn that into a mesh?!
// @Incomplete Tests

load_obj :: (filename : string) -> *Entity {
    log("Loading file '%'... ", filename);

    contents := read_entire_file(filename);
    defer free(contents);

    return load_obj(filename, contents);
}

// @Incomplete use the temp allocator for all intermediate allocation? see the memory management how_to
load_obj :: (filename : string, data : string) -> *Entity {

    if !data {
        log("File was empty");
        return null;
    }

    parser : Parser;
    parser.data = data;
    parser.tokens = get_tokens(filename, parser.data, obj_style_comments=true);
    parser.current_token = 0;

    defer deinit(*parser);

    // for parser.tokens log("token[%] = %\n", it_index, it);

    // Make sure we at least got the end-of-file token
    assert(parser.tokens.count > 0);
    assert(parser.tokens[parser.tokens.count - 1].type == .EOF);

    mesh : Mesh;
    annotations : [..]Annotation;
    defer {
        if parser.failed {
            deinit(*mesh);
            for annotations free(it.text);
            array_reset(*annotations);
        }
    }

    ok : bool = true;

    while peek_token(*parser).type != .EOF && !parser.failed {

        current_line : s64 = peek_token(*parser).line_number;

        if eat_possible_identifier(*parser, "v") {

            point2 : Vector2 = ---;
            point3 : Vector3 = ---;
            dim := obj_parse_point(*parser, *point2, *point3);

            if dim == 2 {
                array_add(*mesh.positions, make_vector3(point2, 0));
            } else if dim == 3 {
                array_add(*mesh.positions, point3);
            } else if parser.failed {
                break;
            } else {
                assert(false, "Unreachable, we should have set parser failure in this case!");
            }

            tok := peek_token(*parser);
            if tok.type == .COMMENT && tok.line_number == current_line {
                annotation : Annotation;

                annotation.kind = .VERTEX;
                annotation.text = copy_string(trim(tok.string_value, BYTES_TO_TRIM));
                annotation.id = mesh.positions.count - 1;
                array_add(*annotations, annotation);

                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "vn") {

            normal := parse_vector3(*parser);
            array_add(*mesh.normals, normal);

            tok := peek_token(*parser);
            if tok.type == .COMMENT && tok.line_number == current_line {
                log_warning("Skipping comment annotation at %:%. Comments on 'vn' directives are @Incomplete", filename, current_line);
                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "vt") {

            uv := parse_vector2(*parser);
            // @Incomplete
            // array_add(*mesh.uvs0, uv);

            tok := peek_token(*parser);
            if tok.type == .COMMENT && tok.line_number == current_line {
                log_warning("Skipping comment annotation at %:%. Comments on 'vt' directives are @Incomplete", filename, current_line);
                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "p") {

            index := obj_parse_index(*parser);
            array_add(*mesh.indices, index);

            if mesh.geometry_format == .UNKNOWN {
                mesh.geometry_format = .POINTS;
            } else if mesh.geometry_format != .POINTS {
                error(*parser, peek_token(*parser), "Expected consistent geometry format, got %, wanted %.\n", Geometry_Format.POINTS, mesh.geometry_format);
            }

            tok := peek_token(*parser);
            if tok.type == .COMMENT && tok.line_number == current_line {
                log_warning("Skipping comment annotation at %:%. Comments on 'p' directives should be moved to 'v' directives", filename, current_line);
                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "l") {

            start := obj_parse_index(*parser);
            end   := obj_parse_index(*parser);
            array_add(*mesh.indices, start);
            array_add(*mesh.indices, end);

            if mesh.geometry_format == .UNKNOWN {
                mesh.geometry_format = .LINES;
            } else if mesh.geometry_format != .LINES {
                error(*parser, peek_token(*parser), "Expected consistent geometry format, got %, wanted %.\n", Geometry_Format.LINES, mesh.geometry_format);
            }

            tok := peek_token(*parser);
            if tok.type == .COMMENT && tok.line_number == current_line {
                annotation : Annotation;

                annotation.kind = .LINE;
                annotation.text = copy_string(trim(tok.string_value, BYTES_TO_TRIM));
                annotation.id = mesh.indices.count / 2 - 1;
                array_add(*annotations, annotation);

                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "f") {

            face := parse_face(*parser);
            if face.index_count != 3 && face.index_count != 4 {
                error(*parser, peek_token(*parser), "Invalid number of vertex references for 'f' directive, got %, wanted 3 or 4.\n", face.index_count);
            }

            // @Incomplete Do something with the texture and normal indices
            array_add(*mesh.indices, face.indices[0]);
            array_add(*mesh.indices, face.indices[1]);
            array_add(*mesh.indices, face.indices[2]);
            if face.index_count == 4 {
                array_add(*mesh.indices, face.indices[0]);
                array_add(*mesh.indices, face.indices[2]);
                array_add(*mesh.indices, face.indices[3]);
            }

            if mesh.geometry_format == .UNKNOWN {
                mesh.geometry_format = .TRIANGLES;
            } else if mesh.geometry_format != .TRIANGLES {
                error(*parser, peek_token(*parser), "Expected consistent geometry format, got %, wanted %.\n", Geometry_Format.TRIANGLES, mesh.geometry_format);
            }

            tok := peek_token(*parser);
            if tok.type == .COMMENT && tok.line_number == current_line {
                annotation : Annotation;

                annotation.kind = .TRIANGLE;
                annotation.text = copy_string(trim(tok.string_value, BYTES_TO_TRIM));
                annotation.id = mesh.indices.count / 3 - 1;
                array_add(*annotations, annotation);

                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "g") ||
                  eat_possible_identifier(*parser, "mtllib") ||
                  eat_possible_identifier(*parser, "usemtl") {

            warning(*parser, peek_token(*parser), "Unsupported '%' token, support is @Incomplete. Attempting to continue...\n", to_string(peek_token(*parser)));

            tok := peek_token(*parser);
            while tok.type != Token.Type.EOF && tok.line_number == current_line {
                eat_token(*parser);
                tok = peek_token(*parser);
            }

        } else if peek_token(*parser).type == .COMMENT {
            annotation : Annotation;
            annotation.kind = .BLOCK;
            annotation.id = current_line;

            block : [..]string;
            block.allocator = temp;

            tok := peek_token(*parser);
            while tok.type == .COMMENT && (tok.line_number - current_line < 2) {
                current_line = tok.line_number;
                array_add(*block, trim(tok.string_value, BYTES_TO_TRIM));
                eat_token(*parser);
                tok = peek_token(*parser);
            }

            annotation.text = join(..block, "\n");
            array_add(*annotations, annotation);
        } else {

            warning(*parser, peek_token(*parser), "Unexpected '%' token will be ignored. Attempting to continue...\n", to_string(peek_token(*parser)));

            tok := peek_token(*parser);
            while tok.type != Token.Type.EOF && tok.line_number == current_line {
                eat_token(*parser);
                tok = peek_token(*parser);
            }

        }
    }

    // Check obj indices
    max_index : s64 = -1;
    for mesh.indices max_index = max(max_index, it);
    if max_index >= mesh.positions.count {
        log_error("Detected out-of-range .obj index, found 1-based index %, but loaded mesh has % points", max_index + 1, mesh.positions.count);
        parser.failed = true;
    } else if mesh.normals.count != 0 && max_index >= mesh.normals.count {
        log_error("Detected out-of-range .obj index, found 1-based index %, but loaded mesh has % normals", max_index + 1, mesh.normals.count);
        parser.failed = true;
    }

    // Check inferred geometry format
    if mesh.geometry_format == .UNKNOWN {
        // @Incomplete Improve this message to suggest user may have missed p commands for a point cloud if they had vertices in the mesh
        log_warning("Skipped (Could not detect mesh geometry format)\n");
        parser.failed = true;
    }

    if parser.failed {
        return null;
    }

    compare_annotations :: (a : Annotation, b : Annotation) -> s64 {
        if a.kind < b.kind return -1;
        if a.kind > b.kind return  1;
        if a.id < b.id return -1;
        if a.id > b.id return  1;
        return 0;
    }

    // Sort annotations by kind then by id
    quick_sort(annotations, (a,b)=>(compare_annotations(a, b)));

    // @Cleanup it's annoying that init_entity_base_parameters must happen after the new and before the init
    result : *Entity;
    if #complete mesh.geometry_format == {
        case .LINES;

            dim := 2;
            for mesh.positions if it.z != 0 dim = 3;

            if dim == 2 {
                result = New(Polyline_Soup2_Entity);
                e := cast(*Polyline_Soup2_Entity)result;
                e.shape, ok = to_Polyline_Soup2(mesh);
                if !ok {
                    deinit(result);
                }
                init_entity_base_parameters(result, filename, mesh);
                e.spatial = New(AABB_Tree(e.Shape));
                init(e.spatial, *e.shape);

                // FIXME Fixup annotation id numbering to sync with polyline soup conversion
                if annotations.count {
                    needs_fixup := false;
                    for polyline : e.shape.polylines {
                        if polyline.points.count && (polyline.points[0] == polyline.points[polyline.points.count - 1]) {
                            needs_fixup = true;
                            break;
                        }
                    }

                    if needs_fixup {
                        log_error("Omitting annotations for % since support for closed loops in polyline soups is @Incomplete, sorry!", filename);
                    } else {
                        result.annotations = annotations;
                    }
                }

            } else if dim == 3 {
                result = New(Polyline_Soup3_Entity);
                e := cast(*Polyline_Soup3_Entity)result;
                e.shape, ok = to_Polyline_Soup3(mesh);
                if !ok {
                    deinit(result);
                }
                init_entity_base_parameters(result, filename, mesh);
                e.spatial = New(AABB_Tree(e.Shape));
                init(e.spatial, *e.shape);

                // FIXME Fixup annotation id numbering to sync with polyline soup conversion
                if annotations.count {
                    needs_fixup := false;
                    for polyline : e.shape.polylines {
                        if polyline.points.count && (polyline.points[0] == polyline.points[polyline.points.count - 1]) {
                            needs_fixup = true;
                            break;
                        }
                    }

                    if needs_fixup {
                        log_error("Omitting annotations for % since support for closed loops in polyline soups is @Incomplete, sorry!", filename);
                    } else {
                        result.annotations = annotations;
                    }
                }

            }

        case .POINTS;

            result = New(Point_Cloud_Entity);
            e := cast(*Point_Cloud_Entity)result;
            init_entity_base_parameters(result, filename, mesh);
            e.spatial = New(AABB_Tree(e.Shape));
            init(e.spatial, *e.shape);
            result.annotations = annotations;

        case .TRIANGLES;

            result = New(Mesh_Entity);
            e := cast(*Mesh_Entity)result;
            init_entity_base_parameters(result, filename, mesh);
            e.spatial = New(AABB_Tree(e.Shape));
            init(e.spatial, *e.shape);
            result.annotations = annotations;

        case .UNKNOWN;

            assert(false, "Should have handled UNKNOWN geometry format by now\n");
    }

    return result;
}

save_obj :: (filename : string, mesh : Mesh) -> bool
{
    // @Cleanup Are we calling file_close in the right places?

    objfile, success :=  file_open(filename, for_writing=true, keep_existing_content=false);
    if !success {
        return false;
    }

    if mesh.geometry_format == .TRIANGLES {
        if mesh.normals.count {
            for i : 0..mesh.positions.count-1 {
                px, py, pz := mesh.positions[i].x, mesh.positions[i].y, mesh.positions[i].z;
                nx, ny, nz := mesh.normals[i].x, mesh.normals[i].y, mesh.normals[i].z;
                file_write(*objfile, tprint("v % % %\n", px, py, pz));
                file_write(*objfile, tprint("vn % % %\n", nx, ny, nz));
            }
            for i : 0..(mesh.indices.count/3)-1 {
                a := 1 + mesh.indices[3 * i + 0];
                b := 1 + mesh.indices[3 * i + 1];
                c := 1 + mesh.indices[3 * i + 2];
                file_write(*objfile, tprint("f %//% %//% %//%\n", a, a, b, b, c, c));
            }
        } else {
            for i : 0..mesh.positions.count-1 {
                file_write(*objfile, tprint("v % % %\n", mesh.positions[i].x, mesh.positions[i].y, mesh.positions[i].z));
            }
            for i : 0..(mesh.indices.count/3)-1 {
                a := 1 + mesh.indices[3 * i + 0];
                b := 1 + mesh.indices[3 * i + 1];
                c := 1 + mesh.indices[3 * i + 2];
                file_write(*objfile, tprint("f % % %\n", a, b, c));
            }
        }
    } else {
        print("@Incomplete save_obj only supports TRIANGLE geometry format, got %\n", mesh.geometry_format);
        return false;
    }

    file_close(*objfile);
    return true;
}

#scope_file

BYTES_TO_TRIM :: "# \t\r\n";

obj_parse_point :: (p : *Parser, point2 : *Vector2, point3 : *Vector3) -> int {
    is_number :: (t : Token) -> bool {
        return t.type == .INTEGER || t.type == .FLOAT;
    }

    // Look ahead to figure out if we have a 2D or 3D point
    dim := 0;
    cursor := 0;
    if peek_ahead(p, cursor).type == xx #char "-" { cursor += 1; }
    dim += xx is_number(peek_ahead(p, cursor));
    cursor += 1;
    if peek_ahead(p, cursor).type == xx #char "-" { cursor += 1; }
    dim += xx is_number(peek_ahead(p, cursor));
    cursor += 1;
    if peek_ahead(p, cursor).type == xx #char "-" { cursor += 1; }
    dim += xx is_number(peek_ahead(p, cursor));

    if dim == 1 {
        error(p, peek_token(p), "Expected 2D or 3D point, but only got one component %.\n", to_string(peek_token(p)));
    } else if dim == 2 {
        <<point2 = parse_vector2(p);
    } else if dim == 3 {
        <<point3 = parse_vector3(p);
    }

    return dim;
}

obj_parse_index :: (p : *Parser) -> u32 {
    index := parse_integer(p);
    if index == 0 {
        error(p, peek_token(p), "Unexpected 0 index, the OBJ file format uses 1-based indices\n");
    } else if index < 0 {
        error(p, peek_token(p), "Support for OBJ files with negative indices is @Incomplete\n");
    }
    return cast,no_check(u32)(index - 1);
}

Obj_Face :: struct {
    // 1-based indices
    indices : [4]u32 = .[U32_MAX, U32_MAX, U32_MAX, U32_MAX];
    texture : [4]u32 = .[U32_MAX, U32_MAX, U32_MAX, U32_MAX];
    normal  : [4]u32 = .[U32_MAX, U32_MAX, U32_MAX, U32_MAX];
    index_count : int; // How many indices followed the 'f'

    has_textures := false;
    has_normals := false;
}

parse_face :: (p : *Parser) -> Obj_Face {
    face : Obj_Face = ---;
    current_line := peek_token(p).line_number;
    for i : 0..3 {
        if peek_token(p).line_number == current_line && peek_token(p).type != .EOF && peek_token(p).type != .COMMENT {

            face.indices[i] = obj_parse_index(p);
            slash := eat_possible_token(p, #char "/");
            if slash {
                slash = eat_possible_token(p, #char "/");
                if slash {
                    // case v//vn
                    face.normal[i] = obj_parse_index(p);
                    face.has_normals = true;
                } else {
                    face.texture[i] = obj_parse_index(p);
                    slash = eat_possible_token(p, #char "/");
                    if slash {
                        // case v/vt/vn
                        face.normal[i] = obj_parse_index(p);
                        face.has_normals = true;
                        face.has_textures = true;
                    } else {
                        // case v/vt
                        face.has_textures = true;
                    }
                }
            } else {
                // case v
            }

            face.index_count = i + 1;
        }
    }
    return face;
}