#run,stallable build(); // If plugins have assertions, they may stall.

build :: () {

    // This is a build file that doesn't generate an executable
    set_build_options_dc(.{do_output=false});

    set_working_directory(#filepath);

    HasArgument :: (arg : string) -> bool #expand {
        return array_find(command_line_arguments, arg);
    }

    // Create a workspace where we will compile our actual program
    w := compiler_create_workspace("Prizm");
    if !w exit(1);

    command_line_arguments := get_build_options(w).compile_time_command_line;

    build_options := get_build_options(w);
    set_optimization(*build_options, .DEBUG, preserve_debug_info=true);
    build_options.lazy_foreign_function_lookups = true; // Why do we set this?
    build_options.stack_trace = true; // So that we can use the NoteEntryExit helper in carpet.jai
    build_options.output_executable_name = "Prizm";

    new_path: [..] string;
    array_add(*new_path, ..build_options.import_path);
    array_add(*new_path, "source/modules");
    build_options.import_path = new_path;

    plugin_names : [..]string;
    array_add(*plugin_names, "Check");

    // Now that we know what the plugins are, init them.
    init_plugins(plugin_names, *plugins, w);

    set_build_options(build_options, w);

    {
        intercept_flags : Intercept_Flags;
        for plugins if it.before_intercept it.before_intercept(it, *intercept_flags);

        compiler_begin_intercept(w);

        for plugins if it.add_source it.add_source(it);

        add_build_file("source/prizm.jai", w);

        last_message_kind : type_of(Message.kind) = .UNINITIALIZED;
        last_message_count := 1;

        #import "Hash_Table";
        visited_files : Table(string, int);

        while loop:=true {

            message : *Message = compiler_wait_for_message();
            defer last_message_kind = message.kind;

            if message.kind != last_message_kind {
                print("message.kind %, repeated % times\n", last_message_kind, last_message_count);
                last_message_count = 1;

                phase := cast(*Message_Phase)message;
                print("current  message kind is %1%2\n",
                    message.kind,
                    ifx message.kind == .PHASE then tprint(":%", phase.phase) else "");
            } else {
                last_message_count += 1;
            }

            print(". %\n", message.kind);

            // if message.kind == .TYPECHECKED && last_message_kind != .TYPECHECKED {
            //     print("%\n", message.kind);
            // }
            // if message.kind == .PHASE {
            //     phase := cast(*Message_Phase) message;
            //     print("%:%\n", message.kind, phase.phase);
            // }

            if !message {
                continue;
            }

            // Pass the message to all plugins.
            for plugins if it.message it.message(it, message);

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
                    case .FILE;

                        message_file := cast(*Message_File)message;

                        entry, newly_added := find_or_add(*visited_files, message_file.fully_pathed_filename);

                        entry.* += 1;
                        postfix := "th";
                        if entry.* == 1 then postfix = "st";
                        if entry.* == 2 then postfix = "nd";

                        print("  file = %1 (%2%3 time)\n", message_file.fully_pathed_filename, entry.*, postfix);

                    case .IMPORT;

                        message_import := cast(*Message_Import)message;
                        print("  module_name = % %\n",
                            message_import.module_name,
                            message_import.fully_pathed_filename);


                    case .TYPECHECKED;

                        typechecked := cast(*Message_Typechecked) message;

                        for tc: typechecked.declarations {
                            decl := tc.expression;
                            if decl {
                                print("  declarations[%]='%'\n", it_index, print_declaration(decl));
                            }
                        }

                        for tc: typechecked.procedure_headers {
                            header := tc.expression;
                            // if header {
                            //     print("  procedure_headers[%]='%'\n", it_index, print_declaration(decl));
                            // }
                        }

                    case .PHASE;
                        phase := cast(*Message_Phase) message;
                        print("  %\n", phase.phase);

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
