// Things with no clear file to go in just get shoved under the carpet.jai

// Returns a string in temporary storage
filetime_to_readable_date :: (filetime : u64) -> string {
    year, month, day, hour, min, sec := filetime_to_localtime(filetime);
    // return tprint("%:%:% on %-%-%",
    //               formatInt(hour, minimum_digits=2), formatInt(min,   minimum_digits=2), formatInt(sec, minimum_digits=2),
    //               formatInt(year, minimum_digits=4), formatInt(month, minimum_digits=2), formatInt(day, minimum_digits=2));
    return tprint("%:%:%", formatInt(hour, minimum_digits=2), formatInt(min, minimum_digits=2), formatInt(sec, minimum_digits=2));
}

printv :: (a : Code, loc := #caller_location) #expand {
    get_ident_name :: (code : Code) -> string {
        root := compiler_get_nodes(code);
        assert(root.kind == .IDENT);
        ident := cast(*Code_Ident) root;
        return ident.name;
    }

#if false {
    print("%:% % = %\n", loc.fully_pathed_filename, loc.line_number, #run get_ident_name(a), #insert a);
} else {
    print("% = %\n", #run get_ident_name(a), #insert a);
}
}

printd :: (fmt : string, args : ..Any, loc := #caller_location) {
    print("%:% ", loc.fully_pathed_filename, loc.line_number);
    print(fmt, ..args);
} @PrintLike

die :: (loc := #caller_location) {
    print("exit(1) at %:%\n", loc.fully_pathed_filename, loc.line_number);
    exit(1);
}

make_Vector2 :: inline (v : ImGui.ImVec2) -> Vector2 {
    result : Vector2 = ---;
    result.x = v.x;
    result.y = v.y;
    return result;
}

hack_char_to_string :: (c : *u8) -> string {
    result : string;
    result.data = c;
    result.count = 1;
    return result;
}

to_radians :: (degrees : float) -> float {
    scale :: PI / 180;
    return degrees * scale;
}

to_degrees :: (radians : float) -> float {
    scale :: 180 / PI;
    return radians * scale;
}

ensure_2d_or_3d :: (T : Type, loc := #caller_location) {
    dim := dimension_of(T, loc);
    if dim == 2 || dim == 3 return;
    compiler_report(loc.fully_pathed_filename, loc.line_number, 0, tprint("Expected Vector2 or Vector3, got %", T));
}

// Returns a signed int so we can write dim-1 in loops and things just work
dimension_of :: (T : Type, loc := #caller_location) -> int {
    if T == Vector2 return 2;
    if T == Vector3 return 3;
    compiler_report(loc.fully_pathed_filename, loc.line_number, 0, tprint("Expected Vector2 or Vector3, got %", T));
    return -1;
}

log_warning :: (format_string: string, args: .. Any, loc := #caller_location, flags := Log_Flags.NONE, user_flags : u32 = 0) {
    // In case people prefer to say log_warning instead of putting a flags argument on the end,
    // we provide this for convenience. Not really sure if it's worth it, but here you go.
    new_flags := flags | .WARNING;
    log(format_string, ..args, loc, new_flags, user_flags);
} @PrintLike