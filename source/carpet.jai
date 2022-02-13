// Things with no clear file to go in just get shoved under the carpet.jai

// Returns a string in temporary storage
filetime_to_readable_date :: (filetime : u64) -> string {
    lt := filetime_to_local_time(filetime);
    // return tprint("%:%:% on %-%-%",
    //               formatInt(lt.hour, minimum_digits=2), formatInt(lt.minute,   minimum_digits=2), formatInt(lt.second, minimum_digits=2),
    //               formatInt(lt.year, minimum_digits=4), formatInt(lt.month_starting_at_0, minimum_digits=2), formatInt(lt.day_starting_at_0, minimum_digits=2));
    return tprint("%:%:%", formatInt(lt.hour, minimum_digits=2), formatInt(lt.minute, minimum_digits=2), formatInt(lt.second, minimum_digits=2));
}

maybe_trim_leading_dot_forwardslash :: (_s : string) -> string {
    s := _s;
    #if OS == .WINDOWS {
        if s.count >= 2 && s.data[0] == #char "." && s.data[1] == #char "/" {
            s.data += 2;
            s.count -= 2;
        }
    }
    return s;
}

canonically_formatted_path_string :: (_path : string) -> string {
    path := _path;
    path_overwrite_separators(path, #char "/");
    path = maybe_trim_leading_dot_forwardslash(path);
    return path;
}

printv :: (a : Code, loc := #caller_location) #expand {
    get_ident_name :: (code : Code) -> string {
        root := compiler_get_nodes(code);
        assert(root.kind == .IDENT);
        ident := cast(*Code_Ident) root;
        return ident.name;
    }

#if true {
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

// Returns a sorted array given a function mapping array elements to scalar values
// @Duplication This is copied from the Sort.jai module and modified to pass some user data to the scalar mapping function
quick_sort_with_user_data :: (array: [] $T, f: (T, *void) -> $R, user_data : *void) -> [] T {
    quicksort_helper :: (a: *$T, n: s64, f: (T, *void) -> $R, user_data : *void) {
        if n < 2 return;

        p := a[n / 2];

        i := 0;
        j := n-1;

        while true {
            fp := f(p, user_data);
            while f(a[i], user_data) < fp  {i += 1;}
            while fp < f(a[j], user_data)  {j -= 1;}

            if i >= j break;

            t := a[i];
            a[i] = a[j];
            a[j] = t;

            i += 1;
            j -= 1;
        }

        quicksort_helper(a, i, f, user_data);
        quicksort_helper(a + i, n - i, f, user_data);
    }

    quicksort_helper(array.data, array.count, f, user_data);
    return array;
}
