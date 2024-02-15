// Things with no clear file to go in just get shoved under the carpet.jai

make_Vector2 :: inline (v : ImGui.ImVec2) -> Vector2 {
    result : Vector2 = ---;
    result.x = v.x;
    result.y = v.y;
    return result;
}

io :: () -> *ImGui.IO {return ImGui.GetIO(); }


type_to_string :: (type: Type) -> string {
    push_allocator(temp);

    // This cast to *Type_Info requires runtime_storageless_type_info to be disabled,
    // or for us to be running at compile-time. We know for sure in this case that we are
    // calling this routine at compile-time, but in runtime use, this kind of cast
    // presumes that Type_Info has been exported for all runtime types.
    builder: String_Builder;
    print_type_to_builder(*builder, cast(*Type_Info)(type));
    type_string := builder_to_string(*builder);

    return type_string;
}

