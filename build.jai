#run,stallable build(); // If plugins have assertions, they may stall.

HELP_STRING :: #string DONE

Build Options:
  help       print this help message
  debug      build debug mode (default)
  release    build release mode (optimized, checks disabled, application icon set)
  custom     build with custom build options set in a gui
DONE

OUTPUT_EXE_NAME :: "Prism";
EXPECTED_COMPILER_VERSION_INFO :: "beta 0.1.071, built on 10 July 2023";

build :: () {

    #run check_compiler_version();

    // This is a build file that doesn't generate an executable
    set_build_options_dc(.{do_output=false});

    set_working_directory(#filepath);

    HasArgument :: (arg : string) -> bool #expand {
        return array_find(command_line_arguments, arg);
    }

    // Create a workspace where we will compile our actual program
    w := compiler_create_workspace(OUTPUT_EXE_NAME);
    if !w exit(1);

    command_line_arguments := get_build_options(w).compile_time_command_line;

    if HasArgument("help") {
        print(HELP_STRING);
        exit(0);
    }

    {
        mode : Build_Mode;
        mode.set_icon = false; // @FIXME Replace this with the icon plugin
        mode.build_options = get_build_options(w);
        set_optimization(*mode.build_options, .DEBUG, preserve_debug_info=true);
        mode.build_options.lazy_foreign_function_lookups = true; // Why do we set this?
        mode.build_options.stack_trace = true; // So that we can use the NoteEntryExit helper in carpet.jai
        mode.build_options.output_executable_name = OUTPUT_EXE_NAME;
        table_add(*preset_build_modes, "debug", mode);
    }

    {
        mode : Build_Mode;
        mode.set_icon = true;
        mode.build_options = get_build_options(w);
        set_optimization(*mode.build_options, .OPTIMIZED);
        mode.build_options.lazy_foreign_function_lookups = true; // Why do we set this?
        // This disables the runtime console but also hides printing to the console!
        mode.build_options.additional_linker_arguments=.["/SUBSYSTEM:windows", "/ENTRY:mainCRTStartup"]; // See :DisableRuntimeConsoleCleanup, setting it this way seems better anyway
        mode.build_options.output_executable_name = OUTPUT_EXE_NAME;
        table_add(*preset_build_modes, "release", mode);
    }

    build_mode : Build_Mode;
    build_mode_found : bool;
    if HasArgument("custom") {
        print("[%] Compiling with custom build options.\n", OUTPUT_EXE_NAME);
        build_mode, build_mode_found = table_find(*preset_build_modes, "debug"); // Start from debug options
        build_gui(preset_build_modes, chosen_build_mode=*build_mode);
    } else if HasArgument("release") {
        print("[%] Compiling with release build options.\n", OUTPUT_EXE_NAME);
        build_mode, build_mode_found = table_find(*preset_build_modes, "release");
    } else {
        print("[%] Compiling with debug build options.\n", OUTPUT_EXE_NAME);
        build_mode, build_mode_found = table_find(*preset_build_modes, "debug");
    }
    assert(build_mode_found);

    new_path: [..] string;
    array_add(*new_path, ..build_mode.build_options.import_path);
    array_add(*new_path, "source/modules");
    build_mode.build_options.import_path = new_path;

    plugin_names : [..]string;
    array_add(*plugin_names, "Check");

    // Now that we know what the plugins are, init them.
    init_plugins(plugin_names, *plugins, w);

    set_build_options(build_mode.build_options, w);

    {
        intercept_flags : Intercept_Flags;
        for plugins if it.before_intercept it.before_intercept(it, *intercept_flags);

        compiler_begin_intercept(w);

        for plugins if it.add_source it.add_source(it);

        add_build_string(tprint("OUTPUT_EXE_NAME :: \"%\";", build_mode.build_options.output_executable_name), w);
        add_build_file("source/prism.jai", w);

        while true {
            message := compiler_wait_for_message();

            if !message {
                continue;
            }

            // Pass the message to all plugins.
            for plugins if it.message it.message(it, message);

            if message.kind == .COMPLETE {
                // @Cleanup If this fails (why does it fail?) we need to sit through the entire compilation again, can it be made to fail sooner?
                if build_mode.set_icon {
                    print("[%] Setting application icon\n", OUTPUT_EXE_NAME);

                    // @CompilerBug I had a problem where I hit the "Failure to set the icon." compilation error here because I had an empty icon.ico file. ie it was read correctly but had zero bytes. To fix the problem I deleted icon.ico, the icon module could do a better job of error messages in this case
                    set_icon_and_manifest(build_mode.build_options);
                }
                break;
            }

            if message.workspace == w {

                has_note :: (header: *Code_Procedure_Header, note: string) -> bool {
                    for header.notes  if it.text == note  return true;
                    return false;
                }

                // @Cleanup
                has_note :: (header: *Code_Declaration, note: string) -> bool {
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

                        // @KnownIssue note which can be attached to top-level constant string declarations which describe known issues in the code
                        for tc: typechecked.declarations {
                            decl := tc.expression;
                            if decl.expression && decl.expression.kind == .LITERAL && has_note(decl, "KnownIssue") {
                                literal := cast(*Code_Literal)decl.expression;
                                if (decl.flags & .IS_CONSTANT) && literal.value_type == .STRING {
                                    array_add(*registered_known_issues, decl);
                                    // print("%", message.fully_pathed_filename);
                                    // print("Found issue '%' (%)\n", literal._string, decl.name);
                                } else {
                                    filename : string = decl.location.enclosing_load.fully_pathed_filename;
                                    line_no : s64 = decl.location.l0;
                                    char_no : s64 = decl.location.c0; 
                                    compiler_report(filename, line_no, char_no, "@KnownIssue note only allowed on constant string declarations");
                                }
                            }
                        }

                    case .PHASE;
                        phase := cast(*Message_Phase) message;
                        if phase.phase == .TYPECHECKED_ALL_WE_CAN {
                            if !generated_code {
                                if HasArgument("custom") {
                                    build_gui(preset_build_modes, chosen_console_commands=*registered_console_commands);
                                }
                                generate_code_to_register_console_commands(message.workspace);
                                generate_code_to_register_known_issues(message.workspace);
                                generated_code = true;
                            }
                        }

                    case .COMPLETE;
                        break;
                }
            }
        }

        compiler_end_intercept(w);

        for plugins if it.finish   it.finish  (it);
        for plugins if it.shutdown it.shutdown(it);
    }
}

Build_Mode :: struct {
    build_options : Build_Options;
    set_icon : bool;
}

preset_build_modes : Table(string, Build_Mode);

// @Refactor
// - Make use of an indent local variable, which is incremented/decremented when we print lines starting a new block (containing an opening brace)
// - Rename to AddLine and make it automatically add a newline
Print :: (format_string : string, args : ..Any) #expand {
    print_to_builder(*`builder, format_string, ..args);
}

registered_known_issues : [..]*Code_Declaration;

generate_code_to_register_known_issues :: (w : Workspace) {
    builder: String_Builder;
    defer free_buffers(*builder);
    Print("init_known_issues :: () {\n");
    for decl : registered_known_issues {
        if decl.expression && decl.expression.kind == .LITERAL {
            literal := cast(*Code_Literal)decl.expression;
            if decl.flags == .IS_CONSTANT && literal.value_type == .STRING {
                Print("    array_add(*app.known_issues, .{\"%\", \"%\"});\n", decl.name, literal._string);
            }
        }
    }
    Print("    quick_sort(app.known_issues, (a,b)=>compare_strings(a.name, b.name));\n");
    Print("}\n");

    add_build_string(builder_to_string(*builder), w);
}

generated_code := false;
registered_console_commands : [..]*Code_Procedure_Header;

generate_code_to_register_console_commands :: (w : Workspace) {

    #if OS == .WINDOWS {
        SEPARATOR :: "\n"; // Prior to beta 0.1.049 (and I think before beta 0.1.047?) this was \r\n. If this separator is wrong then the split call below breaks too
    } else {
        SEPARATOR :: "\n";
    }

    builder: String_Builder;
    defer free_buffers(*builder);

    // Sort commands by name so that help lists them in alphabetic order
    quick_sort(registered_console_commands, (a,b) => (compare_strings(a.name, b.name)));

    // Generate init_commands function
    Print("init_commands :: () {\n");
    for command, command_index : registered_console_commands {
        path := command.enclosing_load.fully_pathed_filename;

        if command.returns.count != 0 {
            compiler_report(path, command.l0, command.c0, tprint("Console commands must have 0 return values, got %", command.returns.count));
        }

        usage, documentation : string;
        {
            path := command.enclosing_load.fully_pathed_filename;
            file_contents, ok := read_entire_file(path);
            file_lines := split(file_contents, SEPARATOR);
            cursor := command.l0 - 1;
            while cursor < command.l1 {
                if file_lines[cursor] != "" {
                    usage = join(usage, trim(file_lines[cursor], " {"), " ");
                }
                cursor += 1;
            }

            documentation_lines : [..]string;
            cursor = command.l0 - 2;
            while cursor >= 0 && begins_with(file_lines[cursor], "//") {
                array_add(*documentation_lines, replace(file_lines[cursor], "//", "|"));
                cursor -= 1;
            }

            documentation = usage;
            for < documentation_lines {
                documentation = join(documentation, it, separator="\n");
            }

            // @Leak
            usage = escape(usage);
            documentation = escape(documentation);
        }

        Print("    {\n");
        Print("        info : Command_Info;\n");
        Print("        info.name = \"%\";\n", command.name);
        Print("        info.usage = \"%\";\n", usage);
        Print("        info.documentation = \"%\";\n", documentation);
        Print("        info.procedure = %_boiler_plate;\n", command.name);
        Print("        array_add(*app.console.commands, info);\n");
        Print("    }\n");
    }
    Print("}\n\n");

    // Generate boiler plate for registered console commands so they are callable from console input strings
    for command, command_index : registered_console_commands {
        path   := command.enclosing_load.fully_pathed_filename;
        plural := plural_suffix(command.arguments.count == 1);

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

        // command has type Code_Procedure_Header
        // command.arguments has type []*Code_Declaration
        if command.arguments.count {
            Print("    // Declare arguments\n");
            defer Print("\n");
            // arg has type Code_Node
            for arg, arg_index : command.arguments {
                // arg.type has type *Type_Info
                if arg.type.type == {
                    case .INTEGER; Print("    a%1 : int = ---;\n", arg_index);
                    case .FLOAT;   Print("    a%1 : float = ---;\n", arg_index);
                    case .STRING;  Print("    a%1 : string = ---;\n", arg_index);
                    case .TYPE;    Print("    a%1 : Type = ---;\n", arg_index);
                    // @Incomplete support enum types, which can be specified with a prefix dot, as in jai
                    case; compiler_report(path, arg.l0, arg.c0, tprint("Unsupported console command argument type %, only int/float/string/Type are supported.", arg.type.type));
                }
            }
        }

        // @Refactor its confusing that we're Print
        AssignArgument :: (arg : *Code_Declaration, arg_index : int) #expand {
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
                    integer_arg := cast(*Type_Info_Integer)arg.type;
                    if integer_arg.signed == false {
                        Print("%    if a%2 < 0 {\n", indent, arg_index);
                        Print("%        log_error(\"Argument %2 is unsigned but passed value was %%\", a%2);\n", indent, arg_index);
                        Print("%        return;\n", indent);
                        Print("%    }\n", indent);
                    }
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
                case .TYPE;
                    Print("%if args[%].type.type == .TYPE {\n", indent, arg_index);
                    Print("%    a%2 = xx <<cast(*Type)(args[%2].value_pointer);\n", indent, arg_index);
                    Print("%} else {\n", indent);
                    Print("%    log_error(\"Argument %2 is not an Type, its a %%\", args[%2].type.type);\n", indent, arg_index);
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
                AssignArgument(arg, arg_index);
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
                arg := command.arguments[arg_index];
                auto_cast := ifx arg.type.type == .INTEGER then "xx " else ""; // Could use xx,nocheck here since we catch integer overflow..?
                Print("%3a%1%2", arg_index, comma, auto_cast);
            }
            Print(");\n");
        }
    }

    add_build_string(builder_to_string(*builder), w);
}

escape :: (s: string) -> string #must {
    if s == "" {
        return "";
    }

    result : String_Builder;

    for i : 0..s.count - 1 {
        if s[i] == {
            case #char "\\";
            append(*result, "\\\\");

            case #char "\e";
            append(*result, "\\e");

            case #char "\n";
            append(*result, "\\n");

            case #char "\r";
            append(*result, "\\r");

            case #char "\t";
            append(*result, "\\t");

            case #char "\"";
            append(*result, "\\\"");

            case #char "\0";
            append(*result, "\\0");

            case;
            if s[i] < 32
                print_to_builder(*result, "\\x%", formatInt(s[i], 16, 2));
            else
                append(*result, s[i]);
        }
    }

    output := builder_to_string(*result);

    return output;
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
            print("The icon of '%' has been set successfully to '%'.\n", exe_path, icon_path);
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

check_compiler_version :: () {
    COMPILER_VERSION_INFO :: #run compiler_get_version_info(null);
    if (COMPILER_VERSION_INFO != EXPECTED_COMPILER_VERSION_INFO) {
        message := tprint("Using compiler version '%' but expected version '%'. The program may not compile, or some things may be broken.", COMPILER_VERSION_INFO, EXPECTED_COMPILER_VERSION_INFO);
        compiler_report(message, mode = Report.ERROR_CONTINUABLE);
    }
}

// @Cleanup Make this run in release and OS console disabled. Warning: Enabling this hides prints to the console!
// #run { #if OS == .WINDOWS { disable_runtime_console(); } } // :DisableRuntimeConsoleCleanup This used to work via a #run but that broke at some point...? @CompilerBug?

plugins: [..] *Metaprogram_Plugin;

#import "Basic";
#import "Metaprogram_Plugins";
#import "Compiler";
#import "Program_Print";
#import "Sort";
#import "String";
#import "File";
#import "File_Utilities";
#import "Hash_Table";
#import "Reflection";

#if OS == .WINDOWS {
#import "Windows_Resources";
#import "Ico_File";
}

#load "source/build_gui.jai";
