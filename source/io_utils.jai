BYTES_TO_TRIM :: "# \t\r\n";

obj_parse_position :: (p : *Parser, position2 : *Vector2, position3 : *Vector3) -> int, bool {
    is_number :: (t : Token) -> bool {
        // Identifier for nan and inf, parse_vectorN functions will error if the identifier is unrecognised
        if t.type == .INTEGER || t.type == .FLOAT {
            return true;
        }

        if t.type == .IDENTIFIER {
            return equal_nocase(t.string_value, "inf") || equal_nocase(t.string_value, "nan");
        }

        return false;
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
        position2.*, finite = ensure_finite(parse_vector2(p), fallback);
    } else if dim == 3 {
        fallback : Vector3 = app.invalid_point;
        position3.*, finite = ensure_finite(parse_vector3(p), fallback);
    }

    return dim, finite;
}

// 1-based indices
Obj_Index :: #type,distinct int;

parse_obj_index :: (p : *Parser) -> Obj_Index {
    index : Obj_Index = xx parse_integer(p);
    if index == 0 {
        error(p, peek_token(p), "Unexpected 0 index, the OBJ file format uses 1-based indices\n");
    }
    return index;
}

obj_index :: (array_count : s64, obj_index : Obj_Index, fallback : u32) -> is_fallback : bool, index : u32 {
    if obj_index > 0 {
        array_index : u32 = xx (obj_index - 1);
        if array_index < array_count {
            return false, array_index;
        }
    } else if obj_index < 0 {
        array_index : u32 = xx (array_count + xx obj_index);
        if array_index >= 0 {
            return false, array_index;
        }
    }
    return true, fallback;
}

obj_value :: (array : []$T, obj_index : Obj_Index, fallback : T) -> is_fallback : bool, value : T {
    if obj_index > 0 {
        array_index : u32 = xx (obj_index - 1);
        if array_index < array.count {
            return false, array[array_index];
        }
    } else if obj_index < 0 {
        array_index : u32 = xx (array.count + xx obj_index);
        if array_index >= 0 {
            return false, array[array_index];
        }
    }
    return true, fallback;
}

// @continue The following code should be reused/renamed so it applies to a list of points for point cloud/polyline/polygon

Obj_Vertex_References :: struct {
    indices : [..]Obj_Index;
    texture : [..]Obj_Index;
    normal  : [..]Obj_Index;
}

parse_vertex_references :: (p : *Parser) -> Obj_Vertex_References {
    refs : Obj_Vertex_References;

    current_line := peek_token(p).line_number;
    while peek_token(p).line_number == current_line && peek_token(p).type != .EOF && peek_token(p).type != .COMMENT {
        array_add(*refs.indices, parse_obj_index(p));
        slash : bool = eat_possible_token(p, #char "/");
        if slash {
            slash = eat_possible_token(p, #char "/");
            if slash {
                // case v//vn
                array_add(*refs.normal, parse_obj_index(p));
            } else {
                array_add(*refs.texture, parse_obj_index(p));
                slash = eat_possible_token(p, #char "/");
                if slash {
                    // case v/vt/vn
                    array_add(*refs.normal, parse_obj_index(p));
                } else {
                    // case v/vt
                    // do nothing, already parsed v and vt
                }
            }
        } else {
            // case v
            continue;
        }
    }
    return refs;
}

parse_polyline :: (p : *Parser) -> [..]Obj_Index {
    result : [..]Obj_Index;

    current_line := peek_token(p).line_number;
    while peek_token(p).line_number == current_line && peek_token(p).type != .EOF && peek_token(p).type != .COMMENT {
        array_add(*result, parse_obj_index(p));
    }

    return result;
}

// @Refactor remove this when we've switched to attributes
set_annotation_value :: (annotation : *Annotation, _string_value : string) -> bool {
    string_value := _string_value;
    if string_value.count == 0 {
        return false;
    }

    while string_value.data[0] == #char "#" {
        string_value.data += 1;
        string_value.count -= 1;
    }

    value, success, remainder := string_to_float64(string_value);
    if success && remainder.count == 0 {
        set(*annotation.value, cast(float)value);
    } else {
        set(*annotation.value, copy_string(trim(string_value, BYTES_TO_TRIM)));
    }

    return true;
}

// This returns is a string view into `input`
string_between_hashes :: (input : string) -> string {
    assert(input[0] == #char "#");
    result : string = advance(input, 1);
    result = trim(stop_at_any(result, "#"), BYTES_TO_TRIM);
    return result;
}
