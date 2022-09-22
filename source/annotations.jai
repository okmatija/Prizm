Annotation :: struct {
    Kind :: enum {
        VERTEX;
        LINE;
        TRIANGLE;
        BLOCK; // e.g., a header at the top of an .obj file
    }
    kind : Kind;

    // if kind == .BLOCK then 1-based line number starting block comment
    // if kind != .BLOCK then 0-based index for vertex/line/triangle
    id : int;

    // strings are owned
    value : Tagged_Union(string, float);
}

deinit :: (annotation : Annotation) {
    if annotation.value.tag == {
        case string;
            pointer := cast(*string) annotation.value.bytes.data;
            free(<<pointer);
        case float;
            // do nothing
        case;
            assert(false); // unreachable
    }
}

// In temporary storage... @Cleanup, this should use the contextual allocator
to_string :: (annotation : Annotation) -> string {
    if annotation.value.tag == {
        case string;
            pointer := cast(*string) annotation.value.bytes.data;
            return tprint("%", <<pointer); // necessary??
        case float;
            pointer := cast(*float) annotation.value.bytes.data;
            return tprint("%", <<pointer);
    }
    vt := annotation.value.value_types;
    printv(vt);
    printv(annotation);
    assert(false); // unreachable
    return "";
}

compare_annotation_ids :: (a : Annotation , b : Annotation) -> int {
    if a.kind < b.kind return -1;
    if a.kind > b.kind return  1;
    return compare_floats(xx a.id, xx b.id);
}

compare_annotation_values :: (a : Annotation , b : Annotation) -> int {
    afound, aindex := array_find(a.value.value_types, a.value.tag);
    bfound, bindex := array_find(b.value.value_types, b.value.tag);
    if aindex < bindex return -1;
    if aindex > bindex return  1;

    afloat, bfloat := isa(a.value, float), isa(b.value, float);
    if afloat && bfloat {
        return compare_floats(<<afloat, <<bfloat);
    }
    
    astring, bstring := isa(a.value, string), isa(b.value, string);
    if astring && bstring {
        return compare_strings(<<astring, <<bstring);
    }

    assert(false); // unreachable
    return 0;
}