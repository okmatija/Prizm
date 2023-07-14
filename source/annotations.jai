Annotation :: struct {
    // @Cleanup Remove kind because we sort this out by storing annotations in separate containers
    Kind :: enum_flags {
        VERTEX;   // v-directive
        POINT;    // p-directive
        LINE;     // l-directive
        TRIANGLE; // f-directive
        BLOCK;    // e.g., a header at the top of an .obj file
        COMMAND;
    }
    kind : Kind; // Should only have ONE flag set

    // if kind == .BLOCK or .COMMAND then 1-based line number starting block comment
    // if kind != .BLOCK or .COMMAND then 0-based index for vertex/line/triangle
    id : int;

    // strings are owned @Cleanup This sucks, we should use a pool for the annotations
    value : Tagged_Union(string, float); // FIXME This should just be string type, typed data should be an attribute
}

deinit :: (annotation : Annotation) {
    if #complete annotation.value.kind == {
        case .string;
            pointer := cast(*string) annotation.value.bytes.data;
            free(pointer.*);
        case .float32;
            // do nothing
    }
}

// In temporary storage... @Cleanup, this should use the contextual allocator
to_string :: (annotation : Annotation) -> string {
    // @Think maybe prefix with directive that was annotated??
    if #complete annotation.value.kind == {
        case .string;
            pointer := cast(*string) annotation.value.bytes.data;
            return tprint("%", pointer.*); // necessary??
        case .float32;
            pointer := cast(*float) annotation.value.bytes.data;
            return tprint("%", pointer.*);
    }
    vt := annotation.value.value_types;
    assert(false); // unreachable
    return "";
}

compare_annotation_ids :: (a : Annotation , b : Annotation) -> int {
    if a.kind < b.kind return -1;
    if a.kind > b.kind return  1;
    return compare_floats(xx a.id, xx b.id);
}

compare_annotation_values :: (a : Annotation , b : Annotation) -> int {
    afound, aindex := array_find(a.value.value_types, get_type(a.value));
    bfound, bindex := array_find(b.value.value_types, get_type(b.value));
    if aindex < bindex return -1;
    if aindex > bindex return  1;

    afloat, bfloat := isa(a.value, float), isa(b.value, float);
    if afloat && bfloat {
        return compare_floats(afloat.*, bfloat.*);
    }
    
    astring, bstring := isa(a.value, string), isa(b.value, string);
    if astring && bstring {
        return compare_strings(astring.*, bstring.*);
    }

    assert(false); // unreachable
    return 0;
}