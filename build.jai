// Copyright Epic Games, Inc. All Rights Reserved.

#run build();

HELP_STRING :: #string DONE

Build Options:
  debug      build debug mode (default)
  release    build release mode
  checks     enable array bounds checks and fatal cast and math bounds checks
DONE

VERSION_STRING :: #string DONE
VERSION_STRING :: "0.2.0rc";
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

    build_options := get_build_options(w);
    {
        using build_options;

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
    set_build_options(build_options, w);

    {
        compiler_begin_intercept(w);
        defer compiler_end_intercept(w);

        add_build_string(VERSION_STRING, w);
        add_build_file("source/prism.jai", w);

        while true {
            message := compiler_wait_for_message();

            if !message {
                continue;
            }

            if message.kind == .COMPLETE {
                set_icon_and_manifest(build_options);
                break;
            }

            if message.workspace == w {
                do_error_checking(message);

                has_note :: (header: *Code_Procedure_Header, note: string) -> bool {
                    for header.notes  if it.text == note  return true;
                    return false;
                }

                if message.kind == {
                    case .TYPECHECKED;
                      typechecked := cast(*Message_Typechecked) message;

                      for tc: typechecked.procedure_headers {
                          header := tc.expression;
                          if has_note(header, "RegisterCommand") {
                              array_add(*registered_console_commands, header);
                          }
                      }

                    case .PHASE;
                        phase := cast(*Message_Phase) message;
                        if phase.phase == .TYPECHECKED_ALL_WE_CAN {
                            if !generated_code {
                                generate_code_to_register_console_commands(message.workspace);
                                generated_code = true;
                            }
                        }

                    case .COMPLETE;
                        break;
                }
            }
        }
    }
}

generated_code := false;
registered_console_commands : [..]*Code_Procedure_Header;

generate_code_to_register_console_commands :: (w : Workspace) {

    // @Refactor make use of an indent local variable, which is incremented/decremented when we print lines starting a new block
    Print :: (format_string : string, args : ..Any) #expand {
        print_to_builder(*builder, format_string, ..args);
    }

    builder: String_Builder;
    defer free_buffers(*builder);

    // Sort commands by name so that help lists them in alphabetic order
    quick_sort(registered_console_commands, (a,b) => (compare_strings(a.name, b.name)));

    max_padding : string;
    {
        longest_command_name : int;
        for registered_console_commands {
            longest_command_name = max(longest_command_name, it.name.count);
        }
        while longest_command_name != 0 {
            max_padding = tprint("% ", max_padding);
            longest_command_name -= 1;
        }
    }

    // Generate init_commands function
    Print("init_commands :: () {\n");
    for command, command_index : registered_console_commands {
        path := command.enclosing_load.fully_pathed_filename;

        if command.returns.count != 0 {
            compiler_report(path, command.l0, command.c0, tprint("Console commands must have 0 return values, got %", command.returns.count));
        }

        usage : string;
        {
            usage_builder : String_Builder;
            print_to_builder(*usage_builder, "%  XXX_PADDING_XXX", command.name);
            defer free_buffers(*usage_builder);
            for arg, arg_index : command.arguments {
                decl := cast(*Code_Declaration) arg.expression;
                print_expression(*usage_builder, arg);
                print_to_builder(*usage_builder, "  ");
            }

            padding := max_padding;
            padding.count -= command.name.count;
            usage = builder_to_string(*usage_builder);
            usage = replace(usage, ": ", ":");
            usage = replace(usage, " = ", "=");
            usage = replace(usage, "XXX_PADDING_XXX", padding);
        }

        Print("    {\n");
        Print("        info : Command_Info;\n");
        Print("        info.name = \"%\";\n", command.name);
        Print("        info.usage = \"%\";\n", usage);
        Print("        info.procedure = %_boiler_plate;\n", command.name);
        Print("        array_add(*app.console.commands, info);\n");
        Print("    }\n");
    }
    Print("}\n\n");

    // Generate boiler plate for registered console commands
    for command, command_index : registered_console_commands {
        path   := command.enclosing_load.fully_pathed_filename;
        plural := ifx command.arguments.count == 1 then "" else "s";

        max_arg_count : int = command.arguments.count;
        min_arg_count : int = max_arg_count;
        for arg, arg_index : command.arguments {
            if arg.expression {
                min_arg_count -= 1;
            }
        }
        assert(max_arg_count >= min_arg_count);

        Print("%_boiler_plate :: (args : []Any) {\n", command.name);
        defer Print("}\n\n");

        Print("    // Check number of arguments\n");
        Print("    if args.count < % || args.count > % {\n", min_arg_count, max_arg_count);
        if min_arg_count == max_arg_count {
            Print("        log_error(\"Expected exactly % argument%, got %%.\", args.count);\n", command.arguments.count, plural);
        } else {
            Print("        log_error(\"Expected between % and % arguments, got %%.\", args.count);\n", min_arg_count, max_arg_count, command.arguments.count);
        }
        Print("        return;\n");
        Print("    }\n\n");

        if command.arguments.count {
            Print("    // Declare arguments\n");
            defer Print("\n");
            for arg, arg_index : command.arguments {
                if arg.type.type == {
                    case .INTEGER; Print("    a%1 : int = ---;\n", arg_index);
                    case .FLOAT;   Print("    a%1 : float = ---;\n", arg_index);
                    case .STRING;  Print("    a%1 : string = ---;\n", arg_index);
                    case; compiler_report(path, arg.l0, arg.c0, tprint("Unsupported console command argument type %, only int/float/string are supported.", arg.type.type));
                }
            }
        }

        assign_argument :: (arg : *Code_Declaration, arg_index : int) #expand {
            indent := "    ";
            if arg.expression {
                indent = "        ";
                Print("    if args.count > % {\n", arg_index);
            }

            if arg.type.type == {
                case .INTEGER;
                    // @Incomplete Check for overflow?
                    Print("%if args[%].type.type == .INTEGER {\n", indent, arg_index);
                    Print("%    a%2 = xx <<cast(*s64)(args[%2].value_pointer);\n", indent, arg_index);
                    Print("%} else {\n", indent);
                    Print("%    log_error(\"Argument %2 is not an int, its a %%\", args[%2].type.type);\n", indent, arg_index);
                    Print("%    return;\n", indent);
                    Print("%}\n", indent);
                case .FLOAT;
                    Print("%if args[%].type.type == .FLOAT {\n", indent, arg_index);
                    Print("%    a%2 = xx <<cast(*float64)(args[%2].value_pointer);\n", indent, arg_index);
                    Print("%} else if args[%].type.type == .INTEGER {\n", indent, arg_index);
                    Print("%    a%2 = xx <<cast(*s64)(args[%2].value_pointer);\n", indent, arg_index);
                    Print("%} else {\n", indent);
                    Print("%    log_error(\"Argument %2 is not a number, its a %%\", args[%2].type.type);\n", indent, arg_index);
                    Print("%    return;\n", indent);
                    Print("%}\n", indent);
                case .STRING;
                    Print("%if args[%].type.type == .STRING {\n", indent, arg_index);
                    Print("%    a%2 = xx <<cast(*string)(args[%2].value_pointer);\n", indent, arg_index);
                    Print("%} else {\n", indent);
                    Print("%    log_error(\"Argument %2 is not an string, its a %%\", args[%2].type.type);\n", indent, arg_index);
                    Print("%    return;\n", indent);
                    Print("%}\n", indent);
            }

            if arg.expression {
                Print("    }\n");
            }
        }

        if command.arguments.count {
            Print("    // Set arguments\n");
            for arg, arg_index : command.arguments {
                assign_argument(arg, arg_index);
            }
            Print("\n");
        }

        Print("    // Call the function\n");
        for arg_count : min_arg_count..max_arg_count {

            if min_arg_count != max_arg_count {
                Print("    if args.count == % ", arg_count);
            }

            Print("    %(", command.name);
            for arg_index : 0..arg_count-1 {
                comma := ifx arg_index != arg_count-1 then ", " else "";
                Print("a%1%", arg_index, comma);
            }
            Print(");\n");
        }
    }

    add_build_string(builder_to_string(*builder), w);
}

set_icon_and_manifest :: (options: Build_Options) {
    if options.output_type != .EXECUTABLE  return;

    // Set the icon on the executable.
    #if OS == .WINDOWS {
        icon_name := "icon";

        exe_path  := tprint("%1%2.exe", options.output_path, options.output_executable_name);
        icon_path := tprint("%1%2.ico", options.output_path, icon_name);

        if !file_exists(icon_path) {
            ico_file := create_ico_file_from_bitmap_filename(tprint("%1/data/%2.png", options.output_path, icon_name));
            print("ico_file.count is: %\n", ico_file.count);
            write_entire_file(icon_path, ico_file);
            free(ico_file);
        }

        success := set_icon_by_filename(exe_path, icon_path);
        if success {
            print("The icon of '%' has been set successfully to '%'.", exe_path, icon_path);
        } else {
            compiler_report("Failure to set the icon.");
        }

        /*manifest_options: Manifest_Options;
        success = add_manifest_to_executable(exe_path, manifest_options);
        if !success {
            compiler_error("add manifest failed.");
        }*/
    }
}

#run {
#if OS == .WINDOWS {
disable_runtime_console();
}
}

#import "Basic";
#import "Check";
#import "Compiler";
#import "Program_Print";
#import "Sort";
#import "String";

#if OS == .WINDOWS {
    #import "Windows_Resources";
    #import "Ico_File";
}
#import "File";
#import "File_Utilities";