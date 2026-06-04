// This generator is based on the ImGui module shipped with the
// jai compiler beta 0.2.012, built 11 May 2025.

// We don’t ship the Dear ImGui source with the compiler. Download a Dear ImGui release and update this path if you want to re-generate the bindings.
IMGUI_PATH :: "src/imgui"; // v1.92.7-docking
SDL3_INCLUDE_PATH :: "src/include"; // Used for SDL v3.2.14
FREETYPE_INCLUDE_PATH :: "src/include/freetype-2.12.1";

DECLARATIONS_TO_OMIT :: string.[
    // We have custom declarations for these in module.jai:
    "ImVec2",
    "ImVec4",
    "ImColor",
    "ImVector",
    "ImDrawCallback",

    // Jai has its own, better "String_Builder"
    "ImGuiTextBuffer",

    "ImDrawCallback_ResetRenderState", // casting an integer to a function pointer is not supported in Jai.
];

macos_x64_version_arg   := "-mmacos-version-min=10.13"; // Our current x64 min version
macos_arm64_version_arg := "-mmacos-version-min=11.0";  // Earliest version that supports arm64

#run,stallable {

    set_build_options_dc(.{do_output=false});

    root_options := get_build_options();
    args := root_options.compile_time_command_line;


    if !generate_imgui_bindings(args) {
        compiler_set_workspace_status(.FAILED);
    }
}

generate_imgui_bindings :: (args: [] string) -> bool {

    no_demo := array_find(args, "-no_demo");
    compile := array_find(args, "-compile");
    compile_debug := array_find(args, "-debug");
    compile_and_gen_backend_sdl3_gpu3 := array_find(args, "-backend_sdl3_gpu3");
    compile_and_gen_freetype := array_find(args, "-freetype");

    if compile {

        imgui_src_files: [..] string;

        array_add(*imgui_src_files, tprint("%/imgui.cpp", IMGUI_PATH));
        array_add(*imgui_src_files, tprint("%/imgui_widgets.cpp", IMGUI_PATH));
        array_add(*imgui_src_files, tprint("%/imgui_draw.cpp", IMGUI_PATH));
        array_add(*imgui_src_files, tprint("%/imgui_tables.cpp", IMGUI_PATH));

        if !no_demo
            array_add(*imgui_src_files, tprint("%/imgui_demo.cpp", IMGUI_PATH));

        success := true;
        #if OS == .WINDOWS {

            make_directory_if_it_does_not_exist("windows");

            success &&= build_cpp_dynamic_lib(
                "windows/ImGui",
                ..imgui_src_files,
                extra=.[
                    "/DIMGUI_API=__declspec(dllexport)",
                    "/DIMGUI_USE_WCHAR32",
                ],
                debug=compile_debug,
            );

            // We set IMGUI_DISABLE_WIN32_DEFAULT_IME_FUNCTIONS. Otherwise all users of the ImGui module have to link against "imm32".
            success &&= build_cpp_static_lib(
                "windows/ImGui.static",
                ..imgui_src_files,
                extra=.[
                    "/DIMGUI_API=__declspec(dllexport)",
                    "/DIMGUI_DISABLE_WIN32_DEFAULT_IME_FUNCTIONS",
                    "/DIMGUI_USE_WCHAR32",
                ],
                debug=compile_debug,
            );

        } else #if OS == .LINUX {
            make_directory_if_it_does_not_exist("linux");
            success &&= build_cpp_dynamic_lib("linux/ImGui", ..imgui_src_files, debug=compile_debug, extra=.["-DIMGUI_USE_WCHAR32"]);
            // @Hack: Is -fno-threadsafe-statics really the way to go? Without it, we get linker errors when using the static library
            // due to "__cxa_guard_acquire" et al not being defined. The library users probably need to link agains libc++ or something. But do we really want to enforce that?
            success &&= build_cpp_static_lib("linux/ImGui", ..imgui_src_files, extra = .["-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics", "-fPIC", "-DIMGUI_USE_WCHAR32"], debug=compile_debug);
        } else #if OS == .MACOS {

            #import "Process";

            make_directory_if_it_does_not_exist("macos");

            // x64 variant
            success &&= build_cpp_dynamic_lib("macos/ImGui_x64", ..imgui_src_files, extra = .["-arch", "x86_64", "-std=c++20", macos_x64_version_arg, "-DIMGUI_USE_WCHAR32"], debug=compile_debug);

            // @Hack: Is -fno-threadsafe-statics really the way to go? Without it, we get linker errors when using the static library
            // due to "__cxa_guard_acquire" et al not being defined. The library users probably need to link agains libc++ or something. But do we really want to enforce that?
            success &&= build_cpp_static_lib( "macos/ImGui_x64", ..imgui_src_files, extra = .["-arch", "x86_64", "-std=c++20", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics", macos_x64_version_arg, "-DIMGUI_USE_WCHAR32"], debug=compile_debug);

            // arm64 variant
            success &&= build_cpp_dynamic_lib("macos/ImGui_arm64", ..imgui_src_files, extra = .["-arch", "arm64",  "-std=c++20", macos_arm64_version_arg, "-DIMGUI_USE_WCHAR32"], debug=compile_debug);

            success &&= build_cpp_static_lib( "macos/ImGui_arm64", ..imgui_src_files, extra = .["-arch", "arm64",  "-std=c++20", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics", macos_arm64_version_arg, "-DIMGUI_USE_WCHAR32"], debug=compile_debug);

            // create universal binaries
            run_result := run_command("lipo", "-create", "macos/ImGui_x64.dylib", "macos/ImGui_arm64.dylib", "-output", "macos/ImGui.dylib");
            success &&= (run_result.exit_code == 0);

            run_result =  run_command("lipo", "-create", "macos/ImGui_x64.a", "macos/ImGui_arm64.a", "-output", "macos/ImGui.a");
            success &&= (run_result.exit_code == 0);

        } else {
            assert(false, "this OS is not supported, check the procedure % for details\n", #procedure_name());
        }

        if !success return false;
    }

    // We return if we generate a backend because bindings generator crashes if we do more than one generation per run
    if compile_and_gen_backend_sdl3_gpu3 {
        success := compile_and_generate_bindings_backend_sdl3_gpu3(compile_debug);
        return success;
    }

    if compile_and_gen_freetype {
        success := compile_and_generate_bindings_freetype(compile_debug);
        return success;
    }

    defer {
        deinit(*enums_for_typedefs);
        array_reset(*begin_end_string_args);
    }

    output_filename: string;
    opts: Generate_Bindings_Options;
    {
        using opts;

        #if OS == .WINDOWS {

            array_add(*libraries, .{filename="ImGui.static"});
            array_add(*library_search_paths, "windows");
            output_filename = "windows/windows.jai";
            generate_library_declarations = false;

            footer = #string EOF
imgui :: #library,no_dll "ImGui.static";
EOF

        } else {

            #if OS == .LINUX {
                array_add(*library_search_paths, "linux");
            } else #if OS == .MACOS {
                array_add(*library_search_paths, "macos");
            } else {
                assert(false);
            }

            footer = FOOTER_UNIX;
            output_filename = "unix.jai";
            array_add(*libraries, .{filename="ImGui"});
            generate_library_declarations = false;
        }

        array_add(*include_paths, IMGUI_PATH);
        array_add(*source_files,  tprint("%/imgui.h", IMGUI_PATH));
        array_add(*extra_clang_arguments, "-x", "c++", "-DWIN32_LEAN_AND_MEAN", "-DIMGUI_USE_WCHAR32");
        array_add(*flatten_namespaces, "ImGui");
        array_add(*strip_prefixes, "ImGui");
        auto_detect_enum_prefixes = false;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;
        strip_flags |= .INLINED_FUNCTIONS; // "inline" functions are not present in the static library.

        visitor = imgui_visitor;
        get_func_args_for_printing = imgui_get_function_arg_for_printing;
    }

    success := generate_bindings(opts, output_filename);
    return success;
}

compile_and_generate_bindings_backend_sdl3_gpu3 :: (compile_debug: bool) -> bool {

    success := false;
    array_add(*prefixes_to_keep, "ImGui_ImplSDL3_", "ImGui_ImplSDLGPU3_");

    src_files := string.[
        tprint("%/backends/imgui_impl_sdl3.cpp", IMGUI_PATH),
        tprint("%/backends/imgui_impl_sdlgpu3.cpp", IMGUI_PATH),
    ];

    // Generate binaries
    #if OS == .WINDOWS {

        make_directory_if_it_does_not_exist("backends/windows", recursive=true);

        // We set IMGUI_DISABLE_WIN32_DEFAULT_IME_FUNCTIONS. Otherwise all users of the ImGui module have to link against "imm32".
        success = build_cpp_static_lib("backends/windows/ImGui_sdl3_gpu3.static", ..src_files, extra = .["/DIMGUI_DISABLE_WIN32_DEFAULT_IME_FUNCTIONS", "/DIMGUI_USE_WCHAR32", tprint("/I%", IMGUI_PATH), tprint("/I%", SDL3_INCLUDE_PATH)], debug=compile_debug);

        if !success return false;

    } else #if OS == .MACOS {

        #import "Process";

        make_directory_if_it_does_not_exist("backends/macos", recursive=true);

        // x64 variant
        // @Hack: Is -fno-threadsafe-statics really the way to go? Without it, we get linker errors when using the static library
        // due to "__cxa_guard_acquire" et al not being defined. The library users probably need to link agains libc++ or something. But do we really want to enforce that?
        success = build_cpp_static_lib("backends/macos/ImGui_x64_sdl3_gpu3", ..src_files, extra = .["-arch", "x86_64", "-std=c++20", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics", "-DIMGUI_USE_WCHAR32", macos_x64_version_arg, tprint("-I%", IMGUI_PATH), tprint("-I%", SDL3_INCLUDE_PATH)], debug=compile_debug);
        assert(success, "build_cpp_static_lib('backends/macos/ImGui_x64_sdl3_gpu3'");

        // arm64 variant
        success = build_cpp_static_lib("backends/macos/ImGui_arm64_sdl3_gpu3", ..src_files, extra = .["-arch", "arm64",  "-std=c++20", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics", "-DIMGUI_USE_WCHAR32", macos_arm64_version_arg, tprint("-I%", IMGUI_PATH), tprint("-I%", SDL3_INCLUDE_PATH)], debug=compile_debug);
        assert(success, "build_cpp_static_lib('backends/macos/ImGui_arm64_sdl3_gpu3'");

        // create universal binaries
        run_result :=  run_command("lipo", "-create", "backends/macos/ImGui_x64_sdl3_gpu3.a", "backends/macos/ImGui_arm64_sdl3_gpu3.a", "-output", "backends/macos/ImGui_sdl3_gpu3.a");
        success = (run_result.exit_code == 0);

    } else #if OS == .LINUX {

        #import "Process";

        make_directory_if_it_does_not_exist("backends/linux", recursive=true);

        // @Hack: Is -fno-threadsafe-statics really the way to go? Without it, we get linker errors when using the static library
        // due to "__cxa_guard_acquire" et al not being defined. The library users probably need to link agains libc++ or something. But do we really want to enforce that?
        success = build_cpp_static_lib("backends/linux/ImGui_sdl3_gpu3", ..src_files, extra = .["-std=c++20", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics", "-DIMGUI_USE_WCHAR32", tprint("-I%", IMGUI_PATH), tprint("-I%", SDL3_INCLUDE_PATH)], debug=compile_debug);
        assert(success, "build_cpp_static_lib('backends/linux/ImGui_sdl3_gpu3'");
    }

    // Generate bindings
    output_filename: string;
    opts: Generate_Bindings_Options;
    {
        using opts;

        #if OS == .WINDOWS {

            array_add(*library_search_paths, "backends/windows");
            array_add(*libraries, .{filename="ImGui_sdl3_gpu3.static"});
            output_filename = "backends/windows/windows_sdl3_gpu3.jai";
            generate_library_declarations = false;

            footer = #string EOF
imgui_sdl3_gpu3 :: #library,no_dll "ImGui_sdl3_gpu3.static";
EOF

        } else {

            // "inline" functions are not present in the static library.
            strip_flags |= .INLINED_FUNCTIONS;

            #if OS == .LINUX {
                array_add(*library_search_paths, "backends/linux");
            } else #if OS == .MACOS {

                array_add(*library_search_paths, "backends/macos");

                // For some reason generation on macos doesn't find
                // the library and so strips the functions we want.
                //
                // So for now we avoid stripping them and then do the horrible hack
                // below to replace '#foreign __UnknownLib' and '#elsewhere __UnknownLib'
                // with '#foreign imgui_sdl3_gpu3'
                strip_flags &= ~.SYMBOLS_WITH_UNKNOWN_FOREIGN_LIBS;

            } else {
                assert(false);
            }

            array_add(*libraries, .{filename="ImGui_sdl3_gpu3"});
            output_filename = "backends/unix_sdl3_gpu3.jai";
            generate_library_declarations = false;
            footer = #string END
#if OS == .MACOS imgui_sdl3_gpu3 :: #library,no_dll "macos/ImGui_sdl3_gpu3";
#if OS == .LINUX imgui_sdl3_gpu3 :: #library,no_dll "linux/ImGui_sdl3_gpu3";
END
        }

        array_add(*include_paths, IMGUI_PATH, SDL3_INCLUDE_PATH);
        array_add(*source_files, tprint("%/backends/imgui_impl_sdl3.h", IMGUI_PATH), tprint("%/backends/imgui_impl_sdlgpu3.h", IMGUI_PATH));
        array_add(*extra_clang_arguments, "-x", "c++", "-DWIN32_LEAN_AND_MEAN", "-DIMGUI_USE_WCHAR32");
        array_add(*flatten_namespaces, "ImGui");
        array_add(*strip_prefixes, "ImGui", "Imgui");

        auto_detect_enum_prefixes = false;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;

        visitor = imgui_visitor;
        get_func_args_for_printing = imgui_get_function_arg_for_printing;
    }

    success = generate_bindings(opts, output_filename);

    // Horrible hack but...
    #if OS == .MACOS {

        file_path := "backends/unix_sdl3_gpu3.jai";
        defer {
            if !success {
                log("failed to replace invalid library name from generated MacOS bindings at '%'. You will have to manually replace '#foreign __UnknownLib' and '#elsewhere __UnknownLib' with '#foreign imgui_sdl3_gpu3' and '#elsewhere imgui_sdl3_gpu3'", file_path, flags=.ERROR);
            }
        }

        contents, success= := read_entire_file(file_path);
        if success {
            defer free(contents);

            replace1 := replace(contents, "#foreign __UnknownLib", "#foreign imgui_sdl3_gpu3");
            defer free(replace1);

            replace2 := replace(replace1, "#elsewhere __UnknownLib", "#elsewhere imgui_sdl3_gpu3");
            defer free(replace2);

            success = write_entire_file(file_path, replace2);
        }
    }

    return success;
}

compile_and_generate_bindings_freetype :: (compile_debug: bool) -> bool {

    success := false;
    array_add(*prefixes_to_keep, "ImGuiFreeType", "ImGui_ImplFreeType");

    src_files := string.[
        tprint("%/misc/freetype/imgui_freetype.cpp", IMGUI_PATH),
    ];

    // Generate binaries
    #if OS == .WINDOWS {

        make_directory_if_it_does_not_exist("misc/freetype/windows", recursive=true);

        success = build_cpp_static_lib("misc/freetype/windows/ImGui_freetype.static", ..src_files,
            extra = .[
                tprint("/I%", IMGUI_PATH),
                tprint("/I%", FREETYPE_INCLUDE_PATH),
                tprint("/I%", join(IMGUI_PATH, "/misc/freetype",, temp)),
                "/DIMGUI_USE_WCHAR32",
            ],
            debug=compile_debug);

        if !success return false;

    } else #if OS == .LINUX {

        #import "Process";

        make_directory_if_it_does_not_exist("misc/freetype/linux");

        success = build_cpp_static_lib("misc/freetype/linux/ImGui_freetype", ..src_files,
            extra = .[
                tprint("-I%", IMGUI_PATH),
                tprint("-I%", FREETYPE_INCLUDE_PATH),
                tprint("-I%", join(IMGUI_PATH, "/misc/freetype",, temp)),
                "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics", "-fPIC",
                "-DIMGUI_USE_WCHAR32",
            ],
            debug=compile_debug);

        assert(success, "build_cpp_static_lib('misc/freetype/linux/ImGui_freetype'");

    } else #if OS == .MACOS {

        #import "Process";

        make_directory_if_it_does_not_exist("misc/freetype/macos", recursive=true);

        // x64 variant
        success = build_cpp_static_lib("misc/freetype/macos/ImGui_freetype_x64", ..src_files,
            extra = .[
                "-arch", "x86_64", "-std=c++20", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics",
                macos_x64_version_arg,
                tprint("-I%", IMGUI_PATH),
                tprint("-I%", FREETYPE_INCLUDE_PATH),
                join("-I", IMGUI_PATH, "/misc/freetype",, temp),
                "-DIMGUI_USE_WCHAR32",
            ],
            debug=compile_debug);
        assert(success, "build_cpp_static_lib('misc/freetype/macos/ImGui_freetype_x64'");

        // arm64 variant
        success = build_cpp_static_lib("misc/freetype/macos/ImGui_freetype_arm64", ..src_files,
            extra = .[
                "-arch", "arm64", "-std=c++20", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics",
                macos_arm64_version_arg,
                tprint("-I%", IMGUI_PATH),
                tprint("-I%", FREETYPE_INCLUDE_PATH),
                join("-I", IMGUI_PATH, "/misc/freetype",, temp),
                "-DIMGUI_USE_WCHAR32",
            ],
            debug=compile_debug);
        assert(success, "build_cpp_static_lib('misc/freetype/macos/ImGui_freetype_arm64'");

        // create universal binary
        run_result := run_command("lipo", "-create", "misc/freetype/macos/ImGui_freetype_x64.a", "misc/freetype/macos/ImGui_freetype_arm64.a", "-output", "misc/freetype/macos/ImGui_freetype.a");
        success = (run_result.exit_code == 0);

    } else {
        assert(false, "this OS is not supported");
    }

    if !success return false;

    // Generate bindings
    output_filename: string;
    opts: Generate_Bindings_Options;
    {
        using opts;

        #if OS == .WINDOWS {

            array_add(*library_search_paths, "misc/freetype/windows");
            array_add(*libraries, .{filename="ImGui_freetype.static"});
            output_filename = "misc/freetype/windows/windows_freetype.jai";
            generate_library_declarations = false;

            footer = #string EOF
imgui_freetype :: #library,no_dll "ImGui_freetype.static";
EOF

        } else {

            // "inline" functions are not present in the static library.
            strip_flags |= .INLINED_FUNCTIONS;

            #if OS == .LINUX {
                array_add(*library_search_paths, "misc/freetype/linux");
            } else #if OS == .MACOS {

                array_add(*library_search_paths, "misc/freetype/macos");

                // Same reason as SDL backend — macOS generator sometimes fails to find the lib
                strip_flags &= ~.SYMBOLS_WITH_UNKNOWN_FOREIGN_LIBS;

            } else {
                assert(false);
            }

            array_add(*libraries, .{filename="ImGui_freetype"});
            output_filename = "misc/freetype/unix_freetype.jai";
            generate_library_declarations = false;

            footer = #string END
#if OS == .MACOS imgui_freetype :: #library,no_dll "macos/ImGui_freetype";
#if OS == .LINUX imgui_freetype :: #library,no_dll "linux/ImGui_freetype";
END
        }

        array_add(*include_paths, IMGUI_PATH, join(IMGUI_PATH, "/misc/freetype"), FREETYPE_INCLUDE_PATH);
        array_add(*source_files,
            tprint("%/misc/freetype/imgui_freetype.h", IMGUI_PATH)
        );
        array_add(*extra_clang_arguments, "-x", "c++", "-DWIN32_LEAN_AND_MEAN", "-DIMGUI_USE_WCHAR32");
        array_add(*strip_prefixes, "ImGui", "Imgui");

        auto_detect_enum_prefixes = false;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;

        visitor = imgui_visitor;
        get_func_args_for_printing = imgui_get_function_arg_for_printing;
    }

    success = generate_bindings(opts, output_filename);

    // Horrible macOS hack
    #if OS == .MACOS {

        file_path := "misc/freetype/unix_freetype.jai";
        defer {
            if !success {
                log("failed to replace invalid library name from generated MacOS bindings at '%'. You will have to manually replace '#foreign __UnknownLib' and '#elsewhere __UnknownLib' with '#foreign imgui_freetype' and '#elsewhere imgui_freetype'", file_path, flags=.ERROR);
            }
        }

        contents, read_ok := read_entire_file(file_path);
        if read_ok {
            defer free(contents);

            replace1 := replace(contents, "#foreign __UnknownLib", "#foreign imgui_freetype");
            defer free(replace1);

            replace2 := replace(replace1, "#elsewhere __UnknownLib", "#elsewhere imgui_freetype");
            defer free(replace2);

            success = write_entire_file(file_path, replace2);
        }
    }

    return success;
}

begin_end_string_args: [..]*Declaration;
enums_for_typedefs: Table(string, *Enum);
prefixes_to_keep: [..]string;

imgui_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {

    // The parent check is because if we have a struct to keep we want
    // everything inside it to stay even if the names aren't to keep, and
    // so we only apply this check on top-level declarations.
    if prefixes_to_keep.count && !parent_decl {

        found := false;

        for prefixes_to_keep {
            if begins_with(decl.name, it) {
                found = true;
                break;
            }
        }

        if !found {
            decl.decl_flags |= .OMIT_FROM_OUTPUT;
            return .STOP;
        }
    }

    // ImGui has "typedef ints" for each enum. but we want to just use the enums directly,
    // so we get nice type safety, and .unary dots, etc.
    //
    // Look for declarations inside functions (i.e., arguments) or structs (i.e., fields)
    get_associated_enum_name :: (name: string) -> string {
        if name.count > 1 && name[name.count - 1] != #char "_" {
            return tprint("%_", name);
        }
        return name;
    }

    if !parent_decl {
        if array_find(DECLARATIONS_TO_OMIT, decl.name) {
            decl.decl_flags |= .OMIT_FROM_OUTPUT;
            return .STOP;
        }
        if decl.name == "ImGuiContext" {
            decl.output_name = decl.name; // Don’t shorten ImGuiContext to Context as this would conflict
        }

        if decl.kind == .TYPEDEF {
            old_name := decl.name;
            if old_name {
                new_name := get_associated_enum_name(old_name);
                for context.generator.global_scope.members {
                    if it.kind != .ENUM  || it.name != new_name     continue;

                    en := cast(*Enum)it;

                    // Don't output the integer typedef
                    decl.decl_flags |= .OMIT_FROM_OUTPUT;

                    // Make sure the enums like "FocusFlags_" get outputted as "FocusFlags"
                    if en.output_name.count > 2 && en.output_name[en.output_name.count - 1] == #char "_" {
                        en.output_name.count -= 1;
                    }

                    // Keep the comment, if there is one:
                    if decl.comment.text && !en.comment.text {
                        en.comment = decl.comment;
                    }

                    table_add(*enums_for_typedefs, old_name, en);
                    break;
                }
            }
        }
    }

    // Look for function arguments with "typedef" types.
    if parent_decl &&
        (parent_decl.kind == .FUNCTION || parent_decl.kind == .STRUCT) &&
        decl.kind == .DECLARATION && decl.type.type_of_typedef != null
    {
        old_name := decl.type.type_of_typedef.name;
        if old_name {
            found, en := table_find(*enums_for_typedefs, old_name);
            if found {
                change_type_to_enum(decl, en);
            }
        }
    }

    if decl.kind == .ENUM {
        // ImGui has lots of enums that should be enum flags. Luckily, they all end in "…Flags_".
        if ends_with(decl.name, "Flags_") {
            en := cast(*Enum)decl;
            en.flags |= .IS_ENUM_FLAGS;
            en.flags |= .VALUES_IN_HEX;
        }
    }

    if decl.kind == .FUNCTION {
        func := cast(*Function)decl;
        type := func.type.type_of_function;
        // ImGui also has functions with pairs of arguments like "text_begin" and "text_end"
        // for the pointers to the beginning and end of a string. We'll generate wrappers for
        // those function which take a jai string.
        //
        // Here we collect pointers to "_begin" arguments, and use them in
        // get_func_args_for_printing below.
        for type.arguments {
            if it_index == 0 || !ends_with(it.name, "_end")     continue;
            arg_type := find_underlying_type(it.type);
            if !arg_type.pointer_to || !(arg_type.pointer_to.number_flags & ._8BIT) continue; // Only convert *u8 ranges to string

            name_part := slice(it.name, 0, it.name.count - "_end".count);
            if !name_part   continue;

            // the first arg may appear as "text_begin" or just "text"
            name_part_with_begin := tprint("%_begin", name_part);
            prev_arg := type.arguments[it_index - 1];
            if prev_arg.name == name_part || prev_arg.name == name_part_with_begin {
                array_add(*begin_end_string_args, prev_arg);
                func.decl_flags |= .NEEDS_ARGUMENT_WRAPPER;
            }
        }
    }

    return .RECURSE;
}

// Modify function with _begin and _end string arguments as they get printed.
// See the note above about "text_begin".
imgui_get_function_arg_for_printing :: (func: *Function, type: *Function_Type, mode: Arg_Print_Mode) -> []*Declaration {
    args: [..]*Declaration;
    for type.arguments {
        if array_find(begin_end_string_args, it) {
            if mode == {
                case .OUTER_WRAPPER;
                    // For the outer wrapper, remove any "_begin" part of the argument, and
                    // change its type to a jai string
                    arg_copy := New(Declaration);
                    arg_copy.* = it.*;
                    arg_copy.type = context.generator.type_def_jai_string;
                    if ends_with(it.name, "_begin") {
                        arg_copy.output_name = slice(it.name, 0, it.name.count - "_begin".count);
                    }
                    array_add(*args, arg_copy);

                    it_index += 1; // skip the next argument-we collpase the _begin and _end args into one string arg

                    continue;
                case .INNER_WRAPPER_CALL;
                    // For the inner wrapper function call, we pass the incoming arg
                    // as two arguments: "jai_string.data, jai_string.data + jai_string.count" -- corresponding
                    // to the _begin and _end parts.
                    base_arg_name := it.name;
                    if ends_with(it.name, "_begin") {
                        base_arg_name = slice(it.name, 0, it.name.count - "_begin".count);
                    }

                    arg_copy := New(Declaration);
                    arg_copy.* = it.*;
                    arg_copy.output_name = tprint("%.data", base_arg_name);
                    array_add(*args, arg_copy);

                    arg_copy_2 := New(Declaration);
                    arg_copy_2.* = it.*;
                    arg_copy_2.output_name = tprint("%.data + %.count", base_arg_name, base_arg_name);
                    array_add(*args, arg_copy_2);

                    it_index += 1; // skip the next arg, since we already added a second one above
                    continue;
            }
        }

        array_add(*args, it);
    }

    return args;
}

#import "Basic";
#import "Bindings_Generator";
#import "BuildCpp";
#import "Compiler";
#import "File";
#import "Hash_Table";
#import "String";

FOOTER_UNIX :: #string END

#if OS == .MACOS    imgui :: #library,no_dll "macos/ImGui";
#if OS == .LINUX    imgui :: #library,no_dll "linux/ImGui";

END
