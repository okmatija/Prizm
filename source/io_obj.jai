// http://paulbourke.net/dataformats/obj/

/* @Incomplete

Tests covering:
- Floats should parse properly
- Files with junk on the end of a vertex/face definition should load and ignore relevant elements (the corrupted vertex/attached faces)
- ...
Don't remove leading spaces from BLOCK type annotations, so that formatting is better perserved in those comments

*/

// @Cleanup Read shape from an obj and then turn that into a mesh?!
// @Incomplete Parameter to enable objs with segments to not get converted to polylines?

// The returned array is in temporary storage, the array elements are allocated with context.allocator
load_obj :: (filename : string, data : string, name : string) -> []*Entity {
    results : [..]*Entity;
    results.allocator = temp;
    if !data {
        log(" File was empty");
        return results;
    }

    parser : Parser; // TODO Give the filename here too, so it can be used to report errors
    defer deinit(*parser);

    parser.data = data;
    parser.tokens = get_tokens(filename, parser.data, obj_style_comments=true);
    parser.current_token = 0;

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

    result := New(Entity);
    array_add(*results, result);

    set_entity_source_from_file(result, filename); // Do this here so the new entity has a filename, which is commonly needed in console commands

    using,only(mesh,
        command_annotations,
        block_annotations,
        vertex_annotations,
        point_annotations,
        face_annotations,
        line_annotations) result;

    // Temporary storage for normals and texture coordinates read from vn and vt directives
    scratch_vn : [..]Vector3;
    // scratch_vt : [..]Vector3;
    defer {
        array_free(scratch_vn);
        // array_free(scratch_vt);
    }

    missing : bool;
    found_inf_or_nan : bool;
    missing_normals_count : int;
    missing_vertices_count : int;
    MISSING_NORMAL_FALLBACK :: Vector3.{0,0,0};
    MISSING_VERTEX_INDEX :: U32_MAX;

    // Always add normals attributes, we'll remove the empty ones later
    triangle_normals : *Simple_Mesh_Triangle_Normals = find_or_add_triangle_normals_attribute(*mesh);
    segment_normals : *Simple_Mesh_Segment_Normals = find_or_add_segment_normals_attribute(*mesh);
    point_normals : *Simple_Mesh_Point_Normals = find_or_add_point_normals_attribute(*mesh);

    warning_ignored_texture_reference_p : int;
    warning_ignored_texture_reference_l : int;
    warning_ignored_texture_reference_f : int;
    warning_ignored_invalid_directive_p : int;
    warning_ignored_invalid_directive_l : int;
    warning_ignored_invalid_directive_f : int;
    defer {
        if warning_ignored_texture_reference_p > 1 {
            log_warning("'%' warning occurred % times", "Ignoring texture reference in p-directive", warning_ignored_texture_reference_p);
        }
        if warning_ignored_texture_reference_l > 1 {
            log_warning("'%' warning occurred % times", "Ignoring texture reference in l-directive", warning_ignored_texture_reference_l);
        }
        if warning_ignored_texture_reference_f > 1 {
            log_warning("'%' warning occurred % times", "Ignoring texture reference in f-directive", warning_ignored_texture_reference_f);
        }
        if warning_ignored_invalid_directive_p > 1 {
            log_warning("'%' warning occured % times", "Ignoring invalid p-directive", warning_ignored_invalid_directive_p);
        }
        if warning_ignored_invalid_directive_l > 1 {
            log_warning("'%' warning occured % times", "Ignoring invalid l-directive", warning_ignored_invalid_directive_l);
        }
        if warning_ignored_invalid_directive_f > 1 {
            log_warning("'%' warning occured % times", "Ignoring invalid f-directive", warning_ignored_invalid_directive_f);
        }
    }

    while peek_token(*parser).type != .EOF && !parser.failed {

        current_line : s64 = peek_token(*parser).line_number;

        if eat_possible_identifier(*parser, "v") {

            position2 : Vector2 = ---;
            position3 : Vector3 = ---;
            dim, finite := obj_parse_position(*parser, *position2, *position3);
            if !finite {
                found_inf_or_nan = true;
            }

            if dim == 2 {
                // @Think Maybe use app.invalid_point.z here
                array_add(*mesh.positions, Vector3.{xy=position2});
            } else if dim == 3 {
                array_add(*mesh.positions, position3);
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

            tok := peek_token(*parser);
            if tok.type == .COMMENT && tok.line_number == current_line {
                // @Cleanup This warning text is not very useful and possibly incorrect
                log_warning("%:%: Skipping comment annotation. Comments on 'vn' directives are @Incomplete", filename, current_line);
                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "vt") {

            uv, finite := ensure_finite(parse_vector2(*parser));
            if !finite {
                // @Incomplete
                // found_inf_or_nan = true;
            }

            // array_add(*scratch_vt, Vector3.{xy=uv});

            tok := peek_token(*parser);
            if tok.type == .COMMENT && tok.line_number == current_line {
                log_warning("Skipping comment annotation at %:%. Comments on 'vt' directives are @Incomplete", filename, current_line);
                eat_token(*parser);
            }

        } else if eat_possible_identifier(*parser, "p") {

            refs : Obj_Vertex_References = parse_vertex_references(*parser);

            refs_valid, nv, nn, nt := true, refs.indices.count, refs.normal.count, refs.texture.count;

            if nt {
                if warning_ignored_texture_reference_p == 0 {
                    log_warning("%:%: Ignoring texture reference in p-directive", filename, current_line);
                    log("Note: Obj v-/vn-/vt-directive reference format variants are v, v/vt, v//vn or v/vt/vn, maybe you wanted v//vn rather than v/vt");
                }
                warning_ignored_texture_reference_p += 1;
            }

            if nv < 1 {
                if warning_ignored_invalid_directive_p == 0 {
                    log_warning("%:%: Ignoring invalid p-directive. Expected at least 1 vertex reference, got %\n", filename, current_line, nv);
                }
                warning_ignored_invalid_directive_p += 1;
                // Do not error here! 
                refs_valid = false;
            }

            if nn > 0 && nn != nv {
                log_warning("%:%: Ignoring invalid p-directive. Expected vertex/normal reference count to be identical, got %/%\n", filename, current_line, nv, nn);
                // Do not error here! 
                refs_valid = false;
            }

            if refs_valid {

                tok := peek_token(*parser);
                has_annotation := tok.type == .COMMENT && tok.line_number == current_line;

                // Parse annotation before adding faces so we add the annotation to each face
                annotation_string : string;
                if has_annotation {
                    annotation_string = string_between_hashes(tok.string_value);
                    if annotation_string.count == 0 {
                        has_annotation = false;
                    }
                    eat_token(*parser);
                }

                // Loop over the points in the point cloud described by the current p-directive
                for i : 0..refs.indices.count-1 {

                    if refs.normal.count {
                        // If we previously encountered l-directives without normal references so fill these with zero normals
                        if point_normals.values.count != mesh.points.count {
                            assert(point_normals.values.count < mesh.points.count);
                            array_resize(*point_normals.values, mesh.points.count, initialize=true);
                        }

                        // Add the normals for this point
                        normal : *Vector3 = array_add(*point_normals.values);
                        missing, normal.* = obj_value(scratch_vn, refs.normal[i], MISSING_NORMAL_FALLBACK);
                        if missing {
                            missing_normals_count += 1;
                        }
                    }
                    
                    // Add the point before the annotation
                    {
                        point : *u32 = array_add(*mesh.points);
                        missing, point.* = obj_index(mesh.positions.count, refs.indices[i], MISSING_VERTEX_INDEX);
                        if missing {
                            missing_vertices_count += 1;
                        }
                    }

                    // After adding the point we can add the annotation
                    if has_annotation {
                        annotation : Annotation;
                        annotation.kind = .POINT;
                        annotation.id = mesh.points.count - 1;
                        // Important that each annotation allocates its own string value, not doing this caused a crash
                        assert(set_annotation_value(*annotation, annotation_string));
                        array_add(*point_annotations, annotation);
                    }
                }
            }

        } else if eat_possible_identifier(*parser, "l") {

            // @Incomplete Support texture vertices here? or log warning and ignore?

            refs : Obj_Vertex_References = parse_vertex_references(*parser);

            refs_valid, nv, nn, nt := true, refs.indices.count, refs.normal.count, refs.texture.count;

            if nt {
                if warning_ignored_texture_reference_l == 0 {
                    log_warning("%:%: Ignoring texture reference in l-directive", filename, current_line);
                    log("Note: Obj v-/vn-/vt-directive reference format variants are v, v/vt, v//vn or v/vt/vn, maybe you wanted v//vn rather than v/vt");
                }
                warning_ignored_texture_reference_l += 1;
            }

            if nv < 2 {
                if warning_ignored_invalid_directive_l == 0 {
                    log_warning("%:%: Ignoring invalid l-directive. Expected at least 2 vertex references, got %\n", filename, current_line, nv);
                }
                warning_ignored_invalid_directive_l += 1;
                // Do not error here! 
                refs_valid = false;
            }

            if nn > 0 && nn != nv {
                log_warning("%:%: Ignoring invalid l-directive. Expected vertex/normal reference count to be identical, got %/%\n", filename, current_line, nv, nn);
                // Do not error here! 
                refs_valid = false;
            }

            if refs_valid {

                tok := peek_token(*parser);
                has_annotation := tok.type == .COMMENT && tok.line_number == current_line;

                // Parse annotation before adding faces so we add the annotation to each face
                annotation_string : string;
                if has_annotation {
                    annotation_string = string_between_hashes(tok.string_value);
                    if annotation_string.count == 0 {
                        has_annotation = false;
                    }
                    eat_token(*parser);
                }

                // Loop over the segments in the polyline described by the current l-directive
                for i : 0..refs.indices.count-1-1 {
                    vids : [2]int;
                    vids[0] = i;
                    vids[1] = i + 1;

                    if refs.normal.count {
                        // If we previously encountered l-directives without normal references so fill these with zero normals
                        if segment_normals.values.count != mesh.segments.count {
                            assert(segment_normals.values.count < mesh.segments.count);
                            array_resize(*segment_normals.values, mesh.segments.count, initialize=true);
                        }

                        // Add the normals for this segment
                        normals : *Matrix3x2 = array_add(*segment_normals.values);
                        for i : 0..1 {
                            missing, normals.v[i] = obj_value(scratch_vn, refs.normal[vids[i]], MISSING_NORMAL_FALLBACK);
                            if missing {
                                missing_normals_count += 1;
                            }
                        }
                    }
                    
                    // Add the segment before the annotation
                    {
                        segment : *Tuple2(u32) = array_add(*mesh.segments);
                        for i : 0..1 {
                            missing, segment.component[i] = obj_index(mesh.positions.count, refs.indices[vids[i]], MISSING_VERTEX_INDEX);
                            if missing {
                                missing_vertices_count += 1;
                            }
                        }
                    }

                    // After adding the segment we can add the annotation
                    if has_annotation {
                        annotation : Annotation;
                        annotation.kind = .LINE;
                        annotation.id = mesh.segments.count - 1;
                        // Important that each annotation allocates its own string value, not doing this caused a crash
                        assert(set_annotation_value(*annotation, annotation_string));
                        array_add(*line_annotations, annotation);
                    }
                }
            }

        } else if eat_possible_identifier(*parser, "f") {

            refs : Obj_Vertex_References = parse_vertex_references(*parser);

            refs_valid, nv, nn, nt := true, refs.indices.count, refs.normal.count, refs.texture.count;

            if nt {
                if warning_ignored_texture_reference_f == 0 {
                    log_warning("%:%: Ignoring texture reference in f-directive", filename, current_line);
                    log("Note: Obj v-/vn-/vt-directive reference format variants are v, v/vt, v//vn or v/vt/vn, maybe you wanted v//vn rather than v/vt");
                }
                warning_ignored_texture_reference_f += 1;
            }

            if nv < 3 {
                if warning_ignored_invalid_directive_f == 0 {
                    log_warning("%:%: Ignoring invalid f-directive. Expected at least 3 vertex references, got %\n", filename, current_line, nv);
                }
                warning_ignored_invalid_directive_f += 1;
                // Do not error here! 
                refs_valid = false;
            }

            if nn > 0 && nn != nv {
                log_warning("%:%: Ignoring invalid f-directive. Expected vertex/normal reference count to be identical, got %/%\n", filename, current_line, nv, nn);
                // Do not error here! 
                refs_valid = false;
            }

            if refs_valid {

                tok := peek_token(*parser);
                has_annotation := tok.type == .COMMENT && tok.line_number == current_line;

                // Parse annotation before adding faces so we add the annotation to each face
                annotation_string : string;
                if has_annotation {
                    annotation_string = string_between_hashes(tok.string_value);
                    if annotation_string.count == 0 {
                        has_annotation = false;
                    }
                    eat_token(*parser);
                }

                // Loop over the triangles in the triangle fan described by the current f-directive
                for f : 0..refs.indices.count-2-1 {
                    vids : [3]int;
                    vids[0] = 0;
                    vids[1] = f + 1;
                    vids[2] = f + 2;

                    if refs.normal.count {
                        // If we previously encountered f-directives without normal references so fill these with zero normals
                        if triangle_normals.values.count != mesh.triangles.count {
                            assert(triangle_normals.values.count < mesh.triangles.count);
                            array_resize(*triangle_normals.values, mesh.triangles.count, initialize=true);
                        }

                        // Add the normals for the current triangle
                        normals : *Matrix3 = array_add(*triangle_normals.values);
                        for i : 0..2 {
                            missing, normals.v[i] = obj_value(scratch_vn, refs.normal[vids[i]], MISSING_NORMAL_FALLBACK);
                            if missing {
                                missing_normals_count += 1;
                            }
                        }
                    }

                    // Add the triangle before the annotation
                    {
                        triangle : *Tuple3(u32) = array_add(*mesh.triangles);
                        for i : 0..2 {
                            missing, triangle.component[i] = obj_index(mesh.positions.count, refs.indices[vids[i]], MISSING_VERTEX_INDEX);
                            if missing {
                                missing_vertices_count += 1;
                            }
                        }
                    }

                    // After adding the triangle we can add the annotation
                    if has_annotation {
                        annotation : Annotation;
                        annotation.kind = .TRIANGLE;
                        annotation.id = mesh.triangles.count - 1;
                        // Important that each annotation allocates its own string value, not doing this caused a crash
                        assert(set_annotation_value(*annotation, annotation_string));
                        array_add(*face_annotations, annotation);
                    }
                }
            }

        } else if eat_possible_identifier(*parser, "g") ||
                  eat_possible_identifier(*parser, "mtllib") ||
                  eat_possible_identifier(*parser, "usemtl") {

            warning(*parser, peek_token(*parser), "%: Unsupported '%' token, support is @Incomplete. Attempting to continue...\n", filename, to_string(peek_token(*parser)));

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
                if remainder && remainder[0] == #char "!" {
                    // Remove the ! and any space after it
                    remainder = advance(remainder, 1);
                    array_add(*commands, trim_left(remainder));
                } else {
                    // Block annotations can be empty, which is handy to preserve formatting
                    array_add(*block, remainder);
                }

                eat_token(*parser);
                tok = peek_token(*parser);
            }

            if block.count {
                annotation : Annotation;
                annotation.kind = .BLOCK;
                annotation.id = current_line;
                value : string = join(..block, "\n",, temp);
                if set_annotation_value(*annotation, value) {
                    array_add(*block_annotations, annotation);
                }
            }

            for command : commands {
                annotation : Annotation;
                annotation.kind = .COMMAND;
                annotation.id = current_line;
                if set_annotation_value(*annotation, command) {
                    array_add(*command_annotations, annotation);
                }
            }
        } else {

            warning(*parser, peek_token(*parser), "%: Unexpected '%' token will be ignored. Attempting to continue...\n", filename, to_string(peek_token(*parser)));

            tok := peek_token(*parser);
            while tok.type != Token.Type.EOF && tok.line_number == current_line {
                eat_token(*parser);
                tok = peek_token(*parser);
            }

        }
    } // end parsing

    if found_inf_or_nan {
        log_warning("%: Detected inf/nan floats in file. In 'v' directives these are set using components of \"Invalid Point\", elsewhere these are set to zero", filename);
    }

    // Check obj indices
    if missing_vertices_count {
        log_warning("%: Detected % missing points. These will be positioned at %", filename, missing_vertices_count, app.invalid_point);

        // Direct any elements with missing vertex indices to the missing/invalid position
        for *point : mesh.points {
            if point.* == MISSING_VERTEX_INDEX {
                point.* = xx mesh.positions.count;
            }
        }
        for *segment : mesh.segments {
            for 0..1 if segment.component[it] == MISSING_VERTEX_INDEX {
                segment.component[it] = xx mesh.positions.count;
            }
        }
        for *triangle : mesh.triangles {
            for 0..2 if triangle.component[it] == MISSING_VERTEX_INDEX {
                triangle.component[it] = xx mesh.positions.count;
            }
        }

        // Append the missing/invalid position
        array_add(*mesh.positions, app.invalid_point);
        // parser.failed = true; // Do not fail here! better to show a weird looking file!
    } else if missing_normals_count {
        log_warning("%: Detected % missing normals. These will be set to %.", filename, missing_normals_count, MISSING_NORMAL_FALLBACK);
        // parser.failed = true; // Do not fail here! better to show a weird looking file!
    }

    if parser.failed {
        for results {
            deinit(it);
        }
        array_reset(*results);
        return results;
    }

    // Sort annotations by kind then by id
    entity_sort_annotations(result, (a,b)=>(compare_annotation_ids(a, b)));

    // Initialize points array in the simple case where there are no elements so all positions are unreferenced
    // In more general cases users can call the item_find_unreferenced_positions command, from the console or as a command annotation in the file
    if no_elements(mesh) {
        array_resize(*mesh.points, mesh.positions.count);
        for * mesh.points { 
            it.* = xx it_index;
        }
        log_warning("%: File contains % position% but has no element directives (p-, l- or f-directives) so we auto-assigned p-directives", filename, mesh.positions.count, plural_suffix(mesh.positions.count > 1));
        log("If you intended to represent a point cloud its recommended that you explicitly add p-directives for each vertex (v-directive)");
    }

    // Remove attributes which correspond to empty containers
    if mesh.triangles.count == 0 remove_mesh_attribute(*mesh, TRIANGLE_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Triangle_Normals);
    if mesh.segments.count == 0 remove_mesh_attribute(*mesh, SEGMENT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Segment_Normals);
    if mesh.points.count == 0 remove_mesh_attribute(*mesh, POINT_NORMALS_ATTRIBUTE_NAME, Simple_Mesh_Point_Normals);

    // @Cleanup remove this? and replace with something to deduce annotation_info?
    set_entity_annotations(result, 
        command_annotations=result.command_annotations,
        block_annotations=result.block_annotations,
        vertex_annotations=result.vertex_annotations,
        point_annotations=result.point_annotations,
        face_annotations=result.face_annotations,
        line_annotations=result.line_annotations);
    set_entity_display_info(result);

    // Use the local entities array as the one that is referenced by console commands and the restore the old one after that
    old_entities := app.entities;
    app.entities = results;
    for command : result.command_annotations {
        console_execute_command(to_string(command));
    }
    results = app.entities;
    app.entities = old_entities;

    init_entity_spatial_index(result);

    //print("result = %\n", formatStruct(result.*, use_newlines_if_long_form=true, use_long_form_if_more_than_this_many_members=0));
    //for result.mesh_attributes {
    //    if it.type == {
    //        case Simple_Mesh_Attribute(Matrix3, .TRIANGLE);
    //            attr := (cast(*Simple_Mesh_Attribute(Matrix3, .TRIANGLE))it).*;
    //            print_vars(attr);
    //    }
    //}

    return results;
}

save_obj :: (filename : string, mesh : Simple_Mesh) -> bool
{
    objfile, success :=  file_open(filename, for_writing=true, keep_existing_content=false);
    if !success {
        return false;
    }

    log_error("@Incomplete save_obj is not implemented");

    file_close(*objfile);
    return false;
}