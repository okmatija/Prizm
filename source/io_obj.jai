// http://paulbourke.net/dataformats/obj/

/* @Incomplete

Tests covering:
- Floats should parse properly
- Files with junk on the end of a vertex/face definition should load and ignore relevant elements (the corrupted vertex/attached faces)
- ...
Don't remove leading spaces from BLOCK type annotations, so that formatting is better perserved in those comments

*/

ISSUE_005 :: "The .obj loader interprets face directives 'i//j' and 'i/j/k' as 'i//i' and 'i/i/i' e.g., 'f 4//1 5//2 6//3' is loaded as if it were 'f 4//4 5//5 6//6'. Will fix soon."; @KnownIssue
ISSUE_006 :: "The .obj loader does not yet support negative indices. Will fix soon."; @KnownIssue
ISSUE_007 :: "The .obj loader currently ignores texture information. Will fix soon."; @KnownIssue

// @Cleanup Read shape from an obj and then turn that into a mesh?!
// @Incomplete Parameter to enable objs with segments to not get converted to polylines?

// @Incomplete use the temp allocator for all intermediate allocation? see the memory management how_to
load_obj :: (filename : string, data : string, name : string) -> *Entity {

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
    annotation_entity : Entity;

    // @Cleanup nocommit Use the new using,only feature here
    block_annotations := annotation_entity.block_annotations;
    vertex_annotations := annotation_entity.vertex_annotations;
    face_annotations := annotation_entity.face_annotations;
    line_annotations := annotation_entity.line_annotations;

    defer if parser.failed {
        deinit(*mesh);
        deinit(*annotation_entity);
    }

    found_inf_or_nan : bool;

    ok : bool = true;

    while peek_token(*parser).type != .EOF && !parser.failed {

        current_line : s64 = peek_token(*parser).line_number;

        if eat_possible_identifier(*parser, "v") {

            point2 : Vector2 = ---;
            point3 : Vector3 = ---;
            dim, finite := obj_parse_point(*parser, *point2, *point3);
            if !finite {
                found_inf_or_nan = true;
            }

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
                set_annotation_value(*annotation, tok.string_value);
                annotation.id = mesh.positions.count - 1;
                array_add(*vertex_annotations, annotation);

                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "vn") {

            normal, finite := ensure_finite(parse_vector3(*parser));
            if !finite {
                found_inf_or_nan = true;
            }

            array_add(*mesh.normals, normal);

            tok := peek_token(*parser);
            if tok.type == .COMMENT && tok.line_number == current_line {
                log_warning("Skipping comment annotation at %:%. Comments on 'vn' directives are @Incomplete", filename, current_line);
                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "vt") {

            uv, finite := ensure_finite(parse_vector2(*parser));
            if !finite {
                // @Incomplete
                //found_inf_or_nan = true;
            }
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
                set_annotation_value(*annotation, tok.string_value);
                annotation.id = mesh.indices.count / 2 - 1;
                array_add(*line_annotations, annotation);

                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "f") {

            face : Obj_Face = parse_face(*parser);
            if face.index_count == 3 || face.index_count == 4 {
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
                    set_annotation_value(*annotation, tok.string_value);
                    annotation.id = mesh.indices.count / 3 - 1;
                    array_add(*face_annotations, annotation);

                    eat_token(*parser);
                }
            } else {
                log_warning("Ignoring invalid face on line %\n", current_line);
                // Do not error here! 
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

            set_annotation_value(*annotation, join(..block, "\n"));
            array_add(*block_annotations, annotation);
        } else {

            warning(*parser, peek_token(*parser), "Unexpected '%' token will be ignored. Attempting to continue...\n", to_string(peek_token(*parser)));

            tok := peek_token(*parser);
            while tok.type != Token.Type.EOF && tok.line_number == current_line {
                eat_token(*parser);
                tok = peek_token(*parser);
            }

        }
    }

    if found_inf_or_nan {
        log_warning("Detected inf/nan floats in file. In positions these set to the corresponding component of the \"Invalid Point\", elsewhere these are set to zero");
    }

    // Check obj indices
    max_index : s64 = -1;
    out_of_range_count : u64 = 0;
    for mesh.indices {
        if it > max_index {
            max_index = it;
        }
        if it >= mesh.positions.count {
            out_of_range_count += 1;
        }
    }

    if max_index >= mesh.positions.count {
        log_warning("Detected % missing points in the mesh file '%'. These will be positioned at %", out_of_range_count, filename, app.invalid_point);
        for * mesh.indices if <<it >= mesh.positions.count {
            <<it = xx mesh.positions.count; // Point to the missing/invalid point location
        }
        array_add(*mesh.positions, app.invalid_point);
        // parser.failed = true; // Do not fail here! better to show a weird looking file!
    } else if mesh.normals.count != 0 && max_index >= mesh.normals.count {
        log_warning("Detected % missing normals in the mesh file '%'. These will be set to zero.", max_index + 1 - mesh.normals.count, filename);
        // parser.failed = true; // Do not fail here! better to show a weird looking file!
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

    // Sort annotations by kind then by id
    entity_sort_annotations(annotation_entity, (a,b)=>(compare_annotation_ids(a, b)));

    result : *Entity;
    if #complete mesh.geometry_format == {
        case .LINES;

            dim := 2;
            for mesh.positions if it.z != 0 dim = 3;

            if dim == 2 {

            #if false {

                // nocommit @Incomplete make Segment_Soup2

            } else { // nocommit Only call this if convert_to_polyline_soup function

                result = New(Polyline_Soup2_Entity);
                e := cast(*Polyline_Soup2_Entity)result;
                e.shape, ok = to_Polyline_Soup2(mesh); // nocommit This conversion should always succeed (have a separate convertible_to_Polyline_Soup2 function)
                if !ok {
                    deinit(*e.shape);
                    return null;
                }
                result.mesh = mesh;
                set_entity_source_from_file(result, filename);
                set_entity_display_info(result, mesh.geometry_format);
                init_entity_spatial_index(cast(*Polyline_Soup2_Entity)result);

                if entity_annotation_count(annotation_entity) {
                    // FIXME Fixup annotation id numbering to sync with polyline soup conversion
                    log_warning("Omitting annotations for % since support for closed loops in polyline soups is @Incomplete, sorry!", filename);
                    deinit(*annotation_entity);
                }
            }

            } else if dim == 3 {

            #if true {

                result = New(Segment_Soup3_Entity);
                result.mesh = mesh;
                set_entity_annotations(result, block_annotations, vertex_annotations, face_annotations, line_annotations);
                set_entity_source_from_file(result, filename);
                set_entity_display_info(result, mesh.geometry_format);
                // init_entity_spatial_index(cast(*Segment_Soup3_Entity)result); // @Incomplete

            } else { // nocommit Only call this if convert_to_polyline_soup function

                result = New(Polyline_Soup3_Entity);
                result.mesh = mesh;
                set_entity_source_from_file(result, filename);
                set_entity_display_info(result, mesh.geometry_format);

                e := cast(*Polyline_Soup3_Entity)result;
                e.shape, ok = to_Polyline_Soup3(mesh);
                if !ok {
                    deinit(*e.shape);
                    return null;
                }
                init_entity_spatial_index(cast(*Polyline_Soup3_Entity)result);

                // FIXME Fixup annotation id numbering to sync with polyline soup conversion
                if annotations.count {
                    log_warning("Omitting annotations for % since support for closed loops in polyline soups is @Incomplete, sorry!", filename);
                    deinit(*annotation_entity);
                }
            }

            }

        case .POINTS;

            result = New(Point_Cloud_Entity);
            result.mesh = mesh;
            set_entity_annotations(result, block_annotations, vertex_annotations, face_annotations, line_annotations);
            set_entity_source_from_file(result, filename);
            set_entity_display_info(result, mesh.geometry_format);
            init_entity_spatial_index(cast(*Point_Cloud_Entity)result);

        case .TRIANGLES;

            result = New(Mesh_Entity);
            result.mesh = mesh;
            set_entity_annotations(result, block_annotations, vertex_annotations, face_annotations, line_annotations);
            set_entity_source_from_file(result, filename);
            set_entity_display_info(result, mesh.geometry_format);
            init_entity_spatial_index(cast(*Mesh_Entity)result);

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
        log_warning("@Incomplete save_obj only supports TRIANGLE geometry format, got %\n", mesh.geometry_format);
        return false;
    }

    file_close(*objfile);
    return true;
}

#scope_file

BYTES_TO_TRIM :: "# \t\r\n";

obj_parse_point :: (p : *Parser, point2 : *Vector2, point3 : *Vector3) -> int, bool {
    is_number :: (t : Token) -> bool {
        // Identifier for nan and inf, parse_vectorN functions will error if the identifier is unrecognised
        return t.type == .INTEGER || t.type == .FLOAT || t.type == .IDENTIFIER;
    }

    // Look ahead to figure out if we have a 2D or 3D point
    dim := 0;
    dim += xx is_number(peek_ahead(p, 0));
    dim += xx is_number(peek_ahead(p, 1));
    dim += xx is_number(peek_ahead(p, 2));

    finite := true;

    if dim == 1 {
        error(p, peek_token(p), "Expected 2D or 3D point, but only got one component %.\n", to_string(peek_token(p)));
    } else if dim == 2 {
        fallback : Vector2 = make_vector2(app.invalid_point.x, app.invalid_point.y);
        <<point2, finite = ensure_finite(parse_vector2(p), fallback);
    } else if dim == 3 {
        fallback : Vector3 = app.invalid_point;
        <<point3, finite = ensure_finite(parse_vector3(p), fallback);
    }

    return dim, finite;
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


set_annotation_value :: (annotation : *Annotation, _string_value : string) {
    string_value := _string_value;
    if string_value.count == 0 return;

    i := 0;
    while string_value.data[i] == #char "#" {
        string_value.data += 1;
        string_value.count -= 1;
    }

    value, success, remainder := string_to_float64(string_value);
    if success && remainder.count == 0 {
        set(*annotation.value, cast(float)value);
    } else {
        set(*annotation.value, copy_string(trim(string_value, BYTES_TO_TRIM)));
    }
}