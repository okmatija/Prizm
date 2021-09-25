// Copyright Epic Games, Inc. All Rights Reserved.

#run build();

HELP_STRING :: #string DONE

Build Options:
  debug      build debug mode (default)
  release    build release mode
  checks     enable array bounds checks and fatal cast and math bounds checks
DONE

VERSION_STRING :: #string DONE
VERSION_STRING :: "0.1.0";
DONE

build :: () {

    // This is a build file that doesn't generate an executable
    set_build_options_dc(.{do_output=false});

    set_working_directory(#filepath);

    // Create a workspace where we will compile our actual program
    w := compiler_create_workspace();
    if !w exit(1);

    command_line_arguments := compiler_get_command_line_arguments();

    Has_Argument :: (arg : string) -> bool #expand {
        return array_find(command_line_arguments, arg);
    }

    if Has_Argument("help") {
        print(HELP_STRING);
        exit(0);
    }

    {
        using build_options := get_build_options(w);
        defer set_build_options(build_options, w);

        output_type = .EXECUTABLE;
        lazy_foreign_function_lookups = true;

        output_executable_name = "Prism";

        if Has_Argument("checks") {
            array_bounds_check = .ON;
            cast_bounds_check  = .FATAL;
            math_bounds_check  = .FATAL;
        }

        if Has_Argument("release") {
            set_optimization_level(*build_options, 3, 3);
        } else {
            // memory_debugger = true;
            // llvm_options.debug_options = .["-g"];
        }

        CWD :: #run get_working_directory();

        _import_path : [..]string;
        for import_path array_add(*_import_path, it);
        array_add(*_import_path, join(CWD, "source/modules", separator="/"));
        import_path = _import_path;
    }

    {
        compiler_begin_intercept(w);
        defer compiler_end_intercept(w);

        add_build_string(VERSION_STRING, w);
        add_build_file("source/prism.jai", w);

        while true {
            message := compiler_wait_for_message();
            if message.kind == .COMPLETE break;
            if !message                  continue;
            if message.workspace != w    continue;

            do_error_checking(message);
        }
    }
}

#import "Basic";
#import "Check";
#import "Compiler";
#import "String";
