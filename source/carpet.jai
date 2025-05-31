// Things with no clear file to go in just get shoved under the carpet.jai

// @Incomplete If the message is already present in the log don't add it again... in all cases?
do_nothing_logger :: (message: string, data: *void, info: Log_Info) {}

// WithDoNothingLogger :: (code : Code) #expand {
//     new_context := context;
//     new_context.logger = do_nothing_logger; 
//     push_context new_context {
//         // ???
//     }
// }

plural_suffix :: (is_plural : bool) -> string {
    if is_plural return "s";
    return "";
}

// Returns a string in temporary storage
filetime_to_readable_date :: (filetime : Apollo_Time, include_date := true) -> string {
    lt : Calendar_Time = to_calendar(filetime, time_zone=.LOCAL);
    if include_date {
        return tprint("%-%-% %:%:%",
                      formatInt(lt.year, minimum_digits=4), formatInt(lt.month_starting_at_0 + 1, minimum_digits=2), formatInt(lt.day_of_month_starting_at_0 + 1, minimum_digits=2),
                      formatInt(lt.hour, minimum_digits=2), formatInt(lt.minute, minimum_digits=2), formatInt(lt.second, minimum_digits=2));
    } else {
        return tprint("%:%:%",
                      formatInt(lt.hour, minimum_digits=2), formatInt(lt.minute, minimum_digits=2), formatInt(lt.second, minimum_digits=2));
    }
}

supported_format :: (filename_with_extension : string) -> bool {
    extension, found_extension := path_extension(filename_with_extension);
    if found_extension && ends_with_nocase(extension, "obj") {
        return true;
    }
    return false;
}

readable_memory_size_decimal :: (size_in_bytes : s64) -> (readable_size : s64, unit_string : string) {
    size := size_in_bytes; if size < 1000 return size, " B"; // Byte, the extra space is for alignment
    size /= 1000;          if size < 1000 return size, "kB";
    size /= 1000;          if size < 1000 return size, "MB";
    size /= 1000;          if size < 1000 return size, "GB";
    size /= 1000;          if size < 1000 return size, "TB";
    size /= 1000;          if size < 1000 return size, "PB"; // petabyte
    size /= 1000;          if size < 1000 return size, "EB"; // exabyte
    size /= 1000;          if size < 1000 return size, "ZB"; // zettabyte
    size /= 1000;          if size < 1000 return size, "YB"; // yottabyte
    assert(false);
    return 0, "Unknown";
}

write_entire_file_to_cwd :: (filename : string, contents : string) {
    #import "System"; // @CompilerBug Why is this needed??? We import System in app.jai
    success, exe_path, exe_name := split_from_right(get_path_of_running_executable(), #char "/");
    if success {
        success = write_entire_file(filename, contents);
        if success {
            log("Wrote '%/%'", exe_path, filename);
        }
    }
    if success == false {
        log_error("Failed to save '%'", filename);
    }
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

maybe_trim_trailing_forwardslash :: (_s : string) -> string {
    s := _s;
    if s.count > 1 && s.data[s.count-1] == #char "/" {
        s.count -= 1;
    }
    return s;
}

canonically_formatted_path_string :: (_path : string) -> string, success : bool {
    path, success := get_absolute_path(_path);
    if success {
        path_overwrite_separators(path, #char "/"); // @CompilerBug.{"0.1.052"} in the documentation, I think the docs use a path which isn't writable, also "have a sad time" would be better clarified
        path = maybe_trim_leading_dot_forwardslash(path);
        // path = maybe_trim_trailing_forwardslash(path); // Don't remove this, its useful to use the trailing / to distinguish a directory/filename
    }
    return path, success;
}

get_ident_name :: (code : Code) -> string {
    root := compiler_get_nodes(code);
    assert(root.kind == .IDENT);
    ident := cast(*Code_Ident) root;
    return ident.name;
}

die :: (loc := #caller_location) {
    print("exit(1) at %:%\n", loc.fully_pathed_filename, loc.line_number);
    exit(1);
}

// Returns the directory in temporary storage
get_directory :: (fully_pathed_filename : string) -> string {
    push_allocator(temp);  // This macro in Basic makes temporary_allocator active until the scope closes.

    path : Path;
    path = parse_path(fully_pathed_filename); 
    path.words.count -= 1;
    directory : string = path_to_string(reduce_path(path));
    return directory;
}

//// Example: thing := array_find(all_things, t => t.id, "foo"); // get the thing with an id of "foo"
//array_find :: (array: []$T, select: (t: T) -> $S, compare: S) -> T, int {
//    for array {
//        if select(it) == compare {
//            return it, it_index;
//        }
//    }
//    default: T;
//    return default, -1;
//}

hack_char_to_string :: (c : *u8) -> string {
    result : string;
    result.data = c;
    result.count = 1;
    return result;
}


log_warning :: (format_string: string, args: .. Any, loc := #caller_location, flags := Log_Flags.NONE, user_flags : u32 = 0) {
    // In case people prefer to say log_warning instead of putting a flags argument on the end,
    // we provide this for convenience. Not really sure if it's worth it, but here you go.
    new_flags := flags | .WARNING;
    log(format_string, ..args, loc, new_flags, user_flags);
} @PrintLike

vlog_warning :: (format_string: string, args: .. Any, loc := #caller_location, flags := Log_Flags.NONE, user_flags : u32 = 0) {
    // @TODO Make a way to enable verbose logging, currently hardcode it off
    if false {
        // In case people prefer to say log_warning instead of putting a flags argument on the end,
        // we provide this for convenience. Not really sure if it's worth it, but here you go.
        new_flags := flags | .WARNING;
        log(format_string, ..args, loc, new_flags, user_flags);
    }
} @PrintLike



get_enum_count :: ($enum_type : Type) -> s64 {
    info := type_info(enum_type);
    assert(info.type == Type_Info_Tag.ENUM);
    info_enum := cast(*Type_Info_Enum) info;
    return info_enum.values.count;
}

temp_array :: ($Element_Type : Type) -> [..]Element_Type {
    result : [..]Element_Type;
    result.allocator = temp;
    return result;
}

PushAllocator :: push_allocator; // An alias so we match our macro convention

#if 1 { // This just delimits a block of code related to noting entry/exit from function

NoteEntryExit :: () #expand {
    // #this is the pointer to the procedure calling this macro
    note_entry(#this, #location(#this));
    `defer note_exit(#this);
}

#add_context note_entry_exit_depth: s32;

note_entry :: (proc: $T, location: Source_Code_Location) {
    for 0..context.note_entry_exit_depth-1 print("  ");
    context.note_entry_exit_depth += 1;

    if context.stack_trace {
        proc_name := context.stack_trace.info.name;
        print("--> Entering '%' at %:%\n", proc_name, location.fully_pathed_filename, location.line_number);
    } else {
        print("--> Entering '%' at %:%\n", proc, location.fully_pathed_filename, location.line_number);
    }
}

note_exit :: (proc: $T) {
    context.note_entry_exit_depth -= 1;
    for 0..context.note_entry_exit_depth-1 print("  ");

    if context.stack_trace {
        proc_name := context.stack_trace.info.name;
        print("<-- Exiting %\n", proc_name);
    } else {
        print("<-- Exiting %\n", cast(*void) proc);  // Cast to *void to make the print shorter.
    }
}

}

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
