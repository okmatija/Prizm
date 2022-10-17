// FIXME Rename to load_obj when we switch from annotations to attributes
load_obj_with_attributes :: (filename : string, data : string, name : string) -> *Entity {

    if !data {
        log("File was empty");
        return null;
    }

    parser : Parser;
    parser.data = data;
    parser.tokens = get_tokens(filename, parser.data, obj_style_comments=true);
    parser.current_token = 0;

    defer deinit(*parser);

    // print("nocommit: WHAT THE HECK\n");
    //     for tok : parser.tokens {
    //         if tok.type == {
    //             case .IDENTIFIER; #through;
    //             case .COMMENT; #through;
    //             case .SQSTRING; #through;
    //             case .DQSTRING;
    //                 for c : 0..tok.string_value.count-1 {
    //                     if tok.string_value.data[c] == #char "\r" {
    //                         tok.string_value.data[c] = #char " ";
    //                     }
    //                 }
    //         }
    //         print("token [%] = '%'\n", it_index, tok);
    //     }


    // Make sure we at least got the end-of-file token
    assert(parser.tokens.count > 0);
    assert(parser.tokens[parser.tokens.count - 1].type == .EOF);

    mesh : Mesh;
    annotation_entity : Entity;
    using,only(command_annotations, block_annotations,vertex_annotations,face_annotations,line_annotations) annotation_entity;

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
                annotation.id = mesh.positions.count - 1;
                if set_annotation_value(*annotation, tok.string_value) {
                    array_add(*vertex_annotations, annotation);
                }

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
            array_add(*mesh.indices, ToInt(index));

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
            array_add(*mesh.indices, ToInt(start));
            array_add(*mesh.indices, ToInt(end));

            if mesh.geometry_format == .UNKNOWN {
                mesh.geometry_format = .LINES;
            } else if mesh.geometry_format != .LINES {
                error(*parser, peek_token(*parser), "Expected consistent geometry format, got %, wanted %.\n", Geometry_Format.LINES, mesh.geometry_format);
            }

            tok := peek_token(*parser);
            if tok.type == .COMMENT && tok.line_number == current_line {
                annotation : Annotation;

                annotation.kind = .LINE;
                annotation.id = mesh.indices.count / 2 - 1;
                if set_annotation_value(*annotation, tok.string_value) {
                    array_add(*line_annotations, annotation);
                }

                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "f") {

            face : Obj_Face = parse_face(*parser);
            if face.index_count == 3 || face.index_count == 4 {
                // @Incomplete Do something with the texture and normal indices

                array_add(*mesh.indices, ToInt(face.indices[0]));
                array_add(*mesh.indices, ToInt(face.indices[1]));
                array_add(*mesh.indices, ToInt(face.indices[2]));
                if face.index_count == 4 {
                    array_add(*mesh.indices, ToInt(face.indices[0]));
                    array_add(*mesh.indices, ToInt(face.indices[2]));
                    array_add(*mesh.indices, ToInt(face.indices[3]));
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
                    annotation.id = mesh.indices.count / 3 - 1;
                    if set_annotation_value(*annotation, tok.string_value) {
                        array_add(*face_annotations, annotation);
                    }

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

            block : [..]string;
            block.allocator = temp;

            commands : [..]string;
            commands.allocator = temp;

            tok := peek_token(*parser);
            while tok.type == .COMMENT && (tok.line_number - current_line < 2) {
                current_line = tok.line_number;

                // Extract the string between #'s
                remainder : string = advance(tok.string_value, 1);
                remainder = trim(stop_at_any(remainder, "#"), BYTES_TO_TRIM);
                if remainder {
                    if remainder[0] == #char "!" {
                        remainder = advance(remainder, 1);
                        array_add(*commands, remainder);
                    } else {
                        array_add(*block, remainder);
                    }
                }

                eat_token(*parser);
                tok = peek_token(*parser);
            }

            if block.count {
                annotation : Annotation;
                annotation.kind = .BLOCK;
                annotation.id = current_line;
                value : string = join(..block, "\n");
                defer free(value);
                if set_annotation_value(*annotation, value) {
                    array_add(*block_annotations, annotation);
                }
            }

            for command : commands {
                console_execute_command(command);

                annotation : Annotation;
                annotation.kind = .COMMAND;
                annotation.id = current_line;
                if set_annotation_value(*annotation, command) {
                    array_add(*command_annotations, annotation);
                }
            }
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
        log_warning("Detected inf/nan floats in file. In 'v' directives these are set using components of \"Invalid Point\", elsewhere these are set to zero");
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

                // @FIXME make Segment_Soup2

            } else { // @FIXME Only call this if convert_to_polyline_soup function

                result = New(Polyline_Soup2_Entity);
                e := cast(*Polyline_Soup2_Entity)result;
                e.shape, ok = to_Polyline_Soup2(mesh); // @Cleanup This conversion should always succeed (have a separate convertible_to_Polyline_Soup2 function)
                if !ok {
                    deinit(*e.shape);
                    return null;
                }
                result.mesh = mesh;
                set_entity_source_from_file(result, filename);
                set_entity_display_info(result, mesh.geometry_format);
                init_entity_spatial_index(cast(*Polyline_Soup2_Entity)result);

                if entity_annotation_count(annotation_entity) {
                    // @Incomplete Fixup annotation id numbering to sync with polyline soup conversion
                    log_warning("Omitting annotations for % since support for closed loops in polyline soups is @Incomplete, sorry!", filename);
                    deinit(*annotation_entity);
                }
            }

            } else if dim == 3 {

            #if true {

                result = New(Segment_Soup3_Entity);
                result.mesh = mesh;
                set_entity_annotations(result, command_annotations, block_annotations, vertex_annotations, face_annotations, line_annotations);
                set_entity_source_from_file(result, filename);
                set_entity_display_info(result, mesh.geometry_format);
                // init_entity_spatial_index(cast(*Segment_Soup3_Entity)result); // @Incomplete

            } else { // @FIXME Only call this if convert_to_polyline_soup function

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
            set_entity_annotations(result, command_annotations, block_annotations, vertex_annotations, face_annotations, line_annotations);
            set_entity_source_from_file(result, filename);
            set_entity_display_info(result, mesh.geometry_format);
            init_entity_spatial_index(cast(*Point_Cloud_Entity)result);

        case .TRIANGLES;

            result = New(Mesh_Entity);
            result.mesh = mesh;
            set_entity_annotations(result, command_annotations, block_annotations, vertex_annotations, face_annotations, line_annotations);
            set_entity_source_from_file(result, filename);
            set_entity_display_info(result, mesh.geometry_format);
            init_entity_spatial_index(cast(*Mesh_Entity)result);

        case .UNKNOWN;

            assert(false, "Should have handled UNKNOWN geometry format by now\n");
    }

    return result;
}