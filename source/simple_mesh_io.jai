// FIXME Rename to load_obj when we switch from annotations to attributes
load_obj_with_attributes :: (filename : string, data : string, name : string) -> *Entity {

    result : *Entity;
    if !data {
        log(" File was empty");
        return result;
    }

    parser : Parser;
    parser.data = data;
    parser.tokens = get_tokens(filename, parser.data, obj_style_comments=true);
    parser.current_token = 0;

    defer deinit(*parser);

    //for tok : parser.tokens {
    //    if tok.type == {
    //        case .IDENTIFIER; #through;
    //        case .COMMENT; #through;
    //        case .SQSTRING; #through;
    //        case .DQSTRING;
    //            for c : 0..tok.string_value.count-1 {
    //                if tok.string_value.data[c] == #char "\r" {
    //                    tok.string_value.data[c] = #char " ";
    //                }
    //            }
    //    }
    //    print("token [%] = '%'\n", it_index, tok);
    //}

    // Make sure we at least got the end-of-file token
    assert(parser.tokens.count > 0);
    assert(parser.tokens[parser.tokens.count - 1].type == .EOF);

    result = New(Entity); // nocommit local_entities should be the result 
    using,only(mesh,
        command_annotations,
        block_annotations,
        vertex_annotations,
        face_annotations,
        line_annotations) result;

    // Temporary storage for normals and texture coordinates read from vn and vt directives
    scratch_vn : [..]Vector3;
    // scratch_vt : [..]Vector3;
    defer {
        array_free(scratch_vn);
        // array_free(scratch_vt);
    }

    // For the duration of this function make app.entities point to the local entities array so that:
    // 1. We can more conveniently index entities created by this function, without needing a larger refactor to implement negative entity indexing (which we should still do)
    // 3. We can later multithread file loading
    local_entities, old_entities : [..]*Entity;
    array_add(*local_entities, result);
    old_entities = app.entities;
    app.entities = local_entities;
    defer app.entities = old_entities;

    found_inf_or_nan : bool;
    missing_normals_count : int;
    missing_vertices_count : int;
    MISSING_NORMAL_FALLBACK :: Vector3.{0,0,0};
    MISSING_VERTEX_INDEX :: U32_MAX;

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
                if set_annotation_value(*annotation, string_between_hashes(tok.string_value)) {
                    array_add(*vertex_annotations, annotation);
                }

                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "vn") {

            normal, finite := ensure_finite(parse_vector3(*parser));
            if !finite {
                found_inf_or_nan = true;
            }

            array_add(*scratch_vn, normal);
            // nocommit remove this
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
                // found_inf_or_nan = true;
            }

            // array_add(*scratch_vt, make_Vector3(uv, 0));

            tok := peek_token(*parser);
            if tok.type == .COMMENT && tok.line_number == current_line {
                log_warning("Skipping comment annotation at %:%. Comments on 'vt' directives are @Incomplete", filename, current_line);
                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "p") {

            missing, index := obj_index(mesh.positions.count, obj_parse_index(*parser), MISSING_VERTEX_INDEX);
            array_add(*mesh.indices, index);
            if missing {
                missing_vertices_count += 1;
            }

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

            missing, index := obj_index(mesh.positions.count, obj_parse_index(*parser), MISSING_VERTEX_INDEX);
            if missing missing_vertices_count += 1;
            array_add(*mesh.indices, index);

            missing, index = obj_index(mesh.positions.count, obj_parse_index(*parser), MISSING_VERTEX_INDEX);
            if missing missing_vertices_count += 1;
            array_add(*mesh.indices, index);

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
                if set_annotation_value(*annotation, string_between_hashes(tok.string_value)) {
                    array_add(*line_annotations, annotation);
                }

                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "f") {

            face : Obj_Face = parse_face(*parser);
            if face.index_count < 3 {
                log_warning("Ignoring invalid face on line %\n", current_line);
                // Do not error here! 
            } else {

                AddFace :: (vids : [3]int, face : Obj_Face, mesh : *Mesh) #expand {
                    if face.has_normals {
                        // @Speed Just add the normal attribute always, or refactor so we don't find the attribute for each face. Also verify that the current implemenation is actually slow
                        vn : *Simple_Mesh_Normals = find_or_add_mesh_attribute(result, "vn", Simple_Mesh_Normals);
                        normals : *Matrix3 = array_add(*vn.values);
                        for i : 0..2 {
                            missing : bool;
                            missing, normals.v[i] = obj_value(scratch_vn, face.normal[vids[i]], MISSING_NORMAL_FALLBACK);
                            if missing {
                                `missing_normals_count += 1;
                            }
                        }
                    }

                    for i : 0..2 {
                        missing, index := obj_index(mesh.positions.count, face.indices[vids[i]], MISSING_VERTEX_INDEX);
                        array_add(*mesh.indices, index);
                        if missing {
                            `missing_vertices_count += 1;
                        }
                    }
                }

                AddFace(.[0, 1, 2], face, *mesh);
                if face.index_count == 4 {
                    AddFace(.[0, 2, 3], face, *mesh);
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

                    if set_annotation_value(*annotation, string_between_hashes(tok.string_value)) {
                        array_add(*face_annotations, annotation);
                    }

                    eat_token(*parser);
                }
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

                remainder : string = string_between_hashes(tok.string_value);
                if remainder {
                    if remainder[0] == #char "!" {
                        // Remove the ! and any space after it
                        remainder = advance(remainder, 1);
                        array_add(*commands, trim_left(remainder));
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
    } // end parsing

    if found_inf_or_nan {
        log_warning("Detected inf/nan floats in file. In 'v' directives these are set using components of \"Invalid Point\", elsewhere these are set to zero");
    }

    // Check obj indices
    if missing_vertices_count {
        log_warning("Detected % missing points in the mesh file '%'. These will be positioned at %", missing_vertices_count, filename, app.invalid_point);
        for * mesh.indices if <<it == MISSING_VERTEX_INDEX {
            <<it = xx mesh.positions.count; // Point to the missing/invalid point location
        }
        array_add(*mesh.positions, app.invalid_point);
        // parser.failed = true; // Do not fail here! better to show a weird looking file!
    } else if missing_normals_count {
        log_warning("Detected % missing normals in the mesh file '%'. These will be set to %.", missing_normals_count, filename, MISSING_NORMAL_FALLBACK);
        // parser.failed = true; // Do not fail here! better to show a weird looking file!
    }

    // Check inferred geometry format
    if mesh.geometry_format == .UNKNOWN {
        // @Incomplete Improve this message to suggest user may have missed p commands for a point cloud if they had vertices in the mesh
        log_warning("Skipped (Could not detect mesh geometry format)\n");
        parser.failed = true;
    }

    // nocommit why was this here???
    // if mesh.geometry_format != .TRIANGLES {
    //     // @Incomplete Improve this message to suggest user may have missed p commands for a point cloud if they had vertices in the mesh
    //     log_warning("@Incomplete Currently only triangle meshes are supported!\n");
    //     parser.failed = true;
    // }

    if parser.failed {
        deinit(result);
        return null;
    }

    // Sort annotations by kind then by id
    entity_sort_annotations(result, (a,b)=>(compare_annotation_ids(a, b)));

    // nocommit remove this, and replace with something to deduce annotation_info?
    set_entity_annotations(result, 
        result.command_annotations,
        result.block_annotations,
        result.vertex_annotations,
        result.face_annotations,
        result.line_annotations);
    set_entity_source_from_file(result, filename);
    set_entity_display_info(result, mesh.geometry_format);
    init_entity_spatial_index(result);

    // nocommit
    //print("result = %\n", formatStruct(<<result, use_newlines_if_long_form=true, use_long_form_if_more_than_this_many_members=0));
    //for result.mesh_attributes {
    //    if it.type == {
    //        case Simple_Mesh_Dense_Attribute(Matrix3, .TRIANGLE);
    //            attr := <<cast(*Simple_Mesh_Dense_Attribute(Matrix3, .TRIANGLE))it;
    //            printv(attr);
    //    }
    //}

    return result;
}