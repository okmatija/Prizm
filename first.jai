#run,stallable build(); // If plugins have assertions, they may stall.

EXPECTED_COMPILER_VERSION_INFO :: "beta 0.2.010, built on 4 March 2025";

HELP_STRING :: #string DONE

Build Options:
  help       print this help message
  debug_gl   build with opengl in debug mode, and use GL 4.3 so RenderDoc annotations work
  Choose one of:
    verydebug  build debug mode with the memory debugger enabled
    debug      build debug mode (default)
    release    build release mode
    shipping   build release mode, set application icon and bundle zip file
    custom     build with custom build options set in a gui
DONE

Build_Kind :: enum {
    VERY_DEBUG;
    DEBUG;
    RELEASE;
    SHIPPING;
    CUSTOM;
}

OUTPUT_EXE_NAME :: "Prizm";

// @TODOOO Put console generating code into a plugin and revert to the Default_Metaprogram

// This is used to implement the shipping build option (it creates the .zip for distribution)
#if OS == .WINDOWS {
PATH_TO_7z :: "c:\\Program Files\\NVIDIA Corporation\\NVIDIA GeForce Experience\\7z.exe";
}

//#assert(false && "Work on performance with deferred renderer using `jai first - tracy`");

build :: () {

    // Check compiler version
    {
        version_info := compiler_get_version_info(null);
        if (version_info != EXPECTED_COMPILER_VERSION_INFO) {
            message := tprint("Using compiler version '%' but expected version '%'. The program may not compile, or some things may be broken.", version_info, EXPECTED_COMPILER_VERSION_INFO);
            compiler_report(message, mode = Report.ERROR_CONTINUABLE);
        }
    }

    // This is a build file that doesn't generate an executable
    set_build_options_dc(.{do_output=false});

    set_working_directory(#filepath);

    HasArgument :: (arg : string) -> bool #expand {
        return array_find(command_line_arguments, arg);
    }

    // Create a workspace where we will compile our actual program
    w := compiler_create_workspace(OUTPUT_EXE_NAME);
    if !w exit(1);

    init_preset_build_options(w);


    build_kind := Build_Kind.DEBUG;
    build_options : Build_Options;
    build_options_found : bool;
    debug_gl : bool;
    tracy_profiling : bool;

    command_line_arguments := get_build_options(w).compile_time_command_line;
    index := 0;
    while index < command_line_arguments.count {
        // Plugins may alter this index
        defer index += 1;
        it := command_line_arguments[index];

        if it == {

        case "help";

            print(HELP_STRING);
            exit(0);

        case "debug_gl";

            debug_gl = true;

        case "verydebug";

            build_kind = .VERY_DEBUG;

        case "debug";

            build_kind = .DEBUG;

        case "release";

            build_kind = .RELEASE;

        case "shipping";

            build_kind = .SHIPPING;

        case "custom";

            build_kind = .CUSTOM;

        case "tracy";

            tracy_profiling = true; // NOTE: We don't use the tracy handle_one_option function

        }
    }

    print("[%] Compiling with % build options.\n", OUTPUT_EXE_NAME, build_kind);
    if #complete build_kind == {
    case .CUSTOM;
        compiler_report("This feature is currently broken, gl_load does not work at compile-time?");
        build_options, build_options_found = table_find(*preset_build_options, "debug"); // Start from debug options
        build_gui(preset_build_options, chosen_build_options=*build_options);
    case .RELEASE; #through;
    case .SHIPPING;
        build_options, build_options_found = table_find(*preset_build_options, "release");
    case .DEBUG; #through;
    case .VERY_DEBUG;
        build_options, build_options_found = table_find(*preset_build_options, "debug");
    }
    assert(build_options_found);

    // new_path: [..] string;
    // array_add(*new_path, ..build_options.import_path);
    // array_add(*new_path, "source/modules");
    // array_add(*new_path, "../jai-tracy/tracy");
    // build_options.import_path = new_path;

    plugins_to_create: [..] Plugin_To_Create;
    array_add(*plugins_to_create, .{name="Check"}); // .{name="Check(CHECK_BINDINGS=false)"}
    if tracy_profiling {
        array_add(*plugins_to_create, .{name="tracy"});
    }
    init_plugins(plugins_to_create, *plugins, w);

    set_build_options(build_options, w);

    {
        intercept_flags : Intercept_Flags;
        for plugins if it.before_intercept it.before_intercept(it, *intercept_flags);

        compiler_begin_intercept(w);

        for plugins if it.add_source it.add_source(it);

        add_build_file("source/prizm.jai", w);

        build_constants := tprint(#string DONE
OUTPUT_EXE_NAME :: "%";
USE_MEMORY_DEBUGGER :: %;
DEBUG_OPENGL :: %;
USE_TRACY :: %;
DONE,
                build_options.output_executable_name,
                ifx HasArgument("verydebug") then "true" else "false",
                ifx HasArgument("debug_gl")  then "true" else "false",
                ifx HasArgument("tracy")  then "true" else "false",
        );
        add_build_string(build_constants, w);

        while true {
            message : *Message = compiler_wait_for_message();

            if !message {
                continue;
            }

            // Pass the message to all plugins.
            for plugins if it.message it.message(it, message);

            if message.kind == .COMPLETE {
                // @Cleanup If this fails (why does it fail?) we need to sit through the entire compilation again, can it be made to fail sooner?
                if HasArgument("shipping") {
                    {
                        print("[%] Setting application icon\n", OUTPUT_EXE_NAME);

                        // @FIXME Replace this with the icon plugin
                        // @CompilerBug I had a problem where I hit the "Failure to set the icon." compilation error here because I had an empty icon.ico file. ie it was read correctly but had zero bytes. To fix the problem I deleted icon.ico, the icon module could do a better job of error messages in this case
                        set_icon_and_manifest(build_options);
                    }

                    {
                        print("[%] Setting application icon\n", OUTPUT_EXE_NAME);

                        init_changelog();

                        #if OS == {
                        case .WINDOWS;

                            zip_name := tprint("%-%-Windows-x86_64.zip", OUTPUT_EXE_NAME, changelog[0].name);

                            // @Incomplete We should check that this worked
                            run_command(PATH_TO_7z, "a", zip_name, tprint("%.exe", OUTPUT_EXE_NAME), "SDL2.dll", "shapes", "api");

                            print("[%] Wrote '%' (hopefully!)\n", OUTPUT_EXE_NAME, zip_name);
                            print("[%] To cleanup you can run 'del %'\n", OUTPUT_EXE_NAME, zip_name);

                        case .LINUX;

                            // @TODO Can we just cross compile?
                            zip_basename := tprint("%-%-Linux-x86_64", OUTPUT_EXE_NAME, changelog[0].name);
                            zip_name := tprint("%.zip", zip_basename);

                            // @Incomplete We should check that this worked
                            run_command("mkdir", zip_basename); // Do this so that the user always unzips to a folder with the Prizm version
                            run_command("cp", "-r", OUTPUT_EXE_NAME, "shapes", "api", zip_basename); // Note: SDL is statically linked on linux
                            run_command("zip", "-r", zip_name, zip_basename);

                            print("[%] Wrote '%' (hopefully!)\n", OUTPUT_EXE_NAME, zip_name);
                            print("[%] To cleanup you can run 'rm -rf % %'\n", OUTPUT_EXE_NAME, zip_basename, zip_name);

                        }
                    }
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

                    case .PHASE;
                        phase := cast(*Message_Phase) message;
                        if phase.phase == .TYPECHECKED_ALL_WE_CAN {
                            if !generated_code {
                                if HasArgument("custom") {
                                    build_gui(preset_build_options, chosen_console_commands=*registered_console_commands);
                                }
                                generate_code_to_register_console_commands(message.workspace);
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

preset_build_options : Table(string, Build_Options);

init_preset_build_options :: (w : Workspace) {
    {
        build_options := get_build_options(w);
        set_optimization(*build_options, .DEBUG, preserve_debug_info=true);
        build_options.lazy_foreign_function_lookups = true; // Why do we set this?
        build_options.stack_trace = true; // So that we can use the NoteEntryExit helper in carpet.jai
        build_options.output_executable_name = OUTPUT_EXE_NAME;
        table_add(*preset_build_options, "debug", build_options);
    }

    {
        build_options := get_build_options(w);
        set_optimization(*build_options, .OPTIMIZED);
        build_options.lazy_foreign_function_lookups = true; // Why do we set this?
#if OS == .WINDOWS {
        // @FIXME This disables the runtime console but also hides printing to the 
        // console, so we can't show usage message if the user --help argument!
        // As a workaround we just show this message in the console but really we
        // should fix this, the :DisableRuntimeConsoleCleanup used to work but its
        // currently broken :(
        build_options.additional_linker_arguments=.["/SUBSYSTEM:windows", "/ENTRY:mainCRTStartup"];
}
        build_options.output_executable_name = OUTPUT_EXE_NAME;
        table_add(*preset_build_options, "release", build_options);
    }
}

// @Refactor
// - Make use of an indent local variable, which is incremented/decremented when we print lines starting a new block (containing an opening brace)
// - Rename to AddLine and make it automatically add a newline
Print :: (format_string : string, args : ..Any) #expand {
    print_to_builder(*`builder, format_string, ..args);
} @PrintLike

generated_code := false;
registered_console_commands : [..]*Code_Procedure_Header;

generate_code_to_register_console_commands :: (w : Workspace) {

    // Prior to beta 0.1.049 (and I think before beta 0.1.047?) this was \r\n.
    // If this separator is wrong then the split call below breaks too
    SEPARATOR :: "\n";

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

            usage = escape(usage); // @Leak
            documentation = escape(documentation); // @Leak
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
        plural := plural_suffix(command.arguments.count != 1);

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
            Print("        log_error(\"Expected exactly % argument%, got \%.\", args.count);\n", command.arguments.count, plural);
        } else {
            Print("        log_error(\"Expected between % and % arguments, got \%.\", args.count);\n", min_arg_count, max_arg_count);
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
                    Print("%    a%2 = xx (cast(*s64)(args[%2].value_pointer)).*;\n", indent, arg_index);
                    integer_arg := cast(*Type_Info_Integer)arg.type;
                    if integer_arg.signed == false {
                        Print("%    if a%2 < 0 {\n", indent, arg_index);
                        Print("%        log_error(\"Argument %2 is unsigned but passed value was \%\", a%2);\n", indent, arg_index);
                        Print("%        return;\n", indent);
                        Print("%    }\n", indent);
                    }
                    Print("%} else {\n", indent);
                    Print("%    log_error(\"Argument %2 is not an int, its a \%\", args[%2].type.type);\n", indent, arg_index);
                    Print("%    return;\n", indent);
                    Print("%}\n", indent);
                case .FLOAT;
                    Print("%if args[%].type.type == .FLOAT {\n", indent, arg_index);
                    Print("%    a%2 = xx (cast(*float64)(args[%2].value_pointer)).*;\n", indent, arg_index);
                    Print("%} else if args[%].type.type == .INTEGER {\n", indent, arg_index);
                    Print("%    a%2 = xx (cast(*s64)(args[%2].value_pointer)).*;\n", indent, arg_index);
                    Print("%} else {\n", indent);
                    Print("%    log_error(\"Argument %2 is not a number, its a \%\", args[%2].type.type);\n", indent, arg_index);
                    Print("%    return;\n", indent);
                    Print("%}\n", indent);
                case .STRING;
                    Print("%if args[%].type.type == .STRING {\n", indent, arg_index);
                    Print("%    a%2 = xx (cast(*string)(args[%2].value_pointer)).*;\n", indent, arg_index);
                    Print("%} else {\n", indent);
                    Print("%    log_error(\"Argument %2 is not an string, its a \%\", args[%2].type.type);\n", indent, arg_index);
                    Print("%    return;\n", indent);
                    Print("%}\n", indent);
                case .TYPE;
                    Print("%if args[%].type.type == .TYPE {\n", indent, arg_index);
                    Print("%    a%2 = xx (cast(*Type)(args[%2].value_pointer)).*;\n", indent, arg_index);
                    Print("%} else {\n", indent);
                    Print("%    log_error(\"Argument %2 is not an Type, its a \%\", args[%2].type.type);\n", indent, arg_index);
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

escape :: (s: string) -> string {
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


set_icon_and_manifest :: (options: Build_Options) #compile_time {
    if options.output_type != .EXECUTABLE  return;

    // Set the icon on the executable.
    #if OS == .WINDOWS {
        icon_name := "icon";
        exe_path  := tprint("%.exe", options.output_executable_name);
        icon_path := tprint("%.ico", icon_name);

        if !file_exists(icon_path) {
            bitmap_filename := tprint("data/%.png", icon_name);
            print("Create ico file from '%'\n", bitmap_filename);
            ico_file := create_ico_file_from_bitmap_filename(bitmap_filename);
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
#import "Process";

#if OS == .WINDOWS {
#import "Windows_Resources";
#import "Ico_File";
}

#load "source/changelog.jai"; // to get the latest version name when making a zip
#load "source/carpet.jai"; // for plural_suffix
#load "source/build_gui.jai";
