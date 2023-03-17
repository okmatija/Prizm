//
// This file is for instrumenting code at compile-time via a metaprogram.
// This is one of the two modes of operation supported by this compiler.
// (The other mode involves manually typing in the profiling hooks.)
//


// get_plugin() tells the metaprogram what the various hooks are:
get_plugin :: () -> *Metaprogram_Plugin {
    p := New(My_Plugin);  // We are making this on the heap so you could have more than one instance of this plugin running.

    p.before_intercept = before_intercept;
    p.add_source       = add_source;
    p.message          = message;
    p.finish           = finish;
    p.shutdown         = shutdown;

    p.log_help         = log_help;

    p.handle_one_option = handle_one_option;

    BUFFER_SIZE :: 4096;
    buffer: [BUFFER_SIZE] u8;
    s := get_working_directory();  // @Cleanup: Just make this take a [] u8.
    // Convert backslashes to forward-slashes.
    for 0..s.count-1
        if s[it] == #char "\\" { s[it] = #char "/"; }

    p.prepend_main_nodes = compiler_get_nodes(prepend_main);
    p.prepend_zone_nodes = compiler_get_nodes(prepend_zone);
    return p;
}

//
// Here are the hooks that get called directly at compile-time:
//
before_intercept :: (p: *Metaprogram_Plugin, flags: *Intercept_Flags) {
    options := get_build_options(p.workspace);
    import_path: [..] string;
    array_add(*import_path, ..options.import_path);
    array_add(*import_path, tprint("%/..", path_strip_filename(#file)));
    options.import_path = import_path;
    set_build_options(options, p.workspace);
}

add_source :: (p: *Metaprogram_Plugin) {
    my := cast(*My_Plugin) p;
    w := p.workspace;
    assert(w >= 0);
    add_build_string(TO_INSERT, w);
}

message :: (p: *Metaprogram_Plugin, message: *Message) {
    if injected_final_profiling_code  return;

    my := cast(*My_Plugin) p;
    if !entry_point_name {
        build_options := get_build_options(message.workspace);
        entry_point_name = build_options.entry_point_name;
        if !entry_point_name then entry_point_name = "main";
    }

    if message.kind == .PHASE {
        phase_message := cast (*Message_Phase) message;
        phase := phase_message.phase;

        if phase == .TYPECHECKED_ALL_WE_CAN {
            if !injected_final_profiling_code && instrumented_entry_point {
                injected_final_profiling_code = true;

                // Do any final code insertions here, if we ever need them…
            }
        }

        return;
    }

    if message.kind != .TYPECHECKED         return;

    m := cast(*Message_Typechecked) message;

    assert(!injected_final_profiling_code);
    for * tc: m.procedure_bodies {
        body := tc.expression;

        if body.body_flags & .ALREADY_MODIFIED continue;

        h := body.header;
        assert(h != null);

        if h.procedure_flags & (h.procedure_flags.POLYMORPHIC | .COMPILER_GENERATED | .COMPILE_TIME | .QUICK | .TYPE_ONLY | .MACRO) continue;  // @Incomplete: Need maybe we want a user-generated compile_time flag; that would be different than this, which is to detect #compiler.

        is_entry_point := h.name == entry_point_name;

        file := body.enclosing_load;
        use_guarded_macro := false;

        type := cast(*Type_Info_Procedure) h.type;
        if type.procedure_flags & .HAS_NO_CONTEXT {
            // We could use the unguarded version of Automatic_Zone here.
            // But that is currently just an alias for Automatic_Zone_Guarded, which uses the context.
            // So we can’t profile #c_call or #no_context functions atm.
            // :AutomaticZoneAlwaysGuarded
            continue;
        }

        // Don't profile stuff that is in Iprof itself:
        // @Robustness: Hardcoded module name for now.
        if file && file.enclosing_import {
            import := file.enclosing_import;

            if import.module_name == "tracy"  continue;
            if import.module_type == .PRELOAD continue;
            if import.module_type == .RUNTIME_SUPPORT continue;

            if import.module_type != .MAIN_PROGRAM {
                if !my.instrument_modules continue;

                if import.module_name == "Pool" {
                    continue; // Do not instrument this stuff, as runtime.jai needs to call it before we are initialized. We have our own version instead.
                }

                if import.module_name == "Basic" {
                    if h.name == "temporary_allocator_proc" continue; // This causes a circular dependency if we instrument it, as we need this for our Pool stuff. Or not??
                    if h.name == "IsScalar" continue; // Also a circular dependency here. Not sure why.
                }
            }
        }

        if !is_entry_point {  // We always need to instrument the entry point, because that is where we put the startup and shutdown.
            if tc.subexpressions.count < my.min_size continue; // Too small!
            if my.should_instrument {  // If this procedure has been given to us by the user.
                if !my.should_instrument(body) continue;
            }

            for h.notes {
                if it.text == "NoProfile" {
                    log("[Tracy] Skipping \"%\" due to NoProfile note.\n", h.name);
                    continue;
                }
            }
        }

        w := message.workspace;

        new_statements : [..] *Code_Node;

        array_reserve(*new_statements, body.block.statements.count + 1);
        if is_entry_point {
            array_add(*new_statements, my.prepend_main_nodes);
            instrumented_entry_point = true;
        } else {
            array_add(*new_statements, my.prepend_zone_nodes);
        }

        array_add(*new_statements, ..body.block.statements);

        body.block.statements = new_statements;

        // Submit the modify.
        //    print("Modifying procedure '%', zone index %.\n", proc.name, zone_index);
        //    print("Zone Declaration: %\n", << zone_decl);
        //    print("Root Expression: %\n", << cast(*Code_Literal) zone_decl.root_expression);

        compiler_modify_procedure(w, body);
    }
}

finish :: (p: *Metaprogram_Plugin) {
    my := cast(*My_Plugin) p;
}

shutdown :: (p: *Metaprogram_Plugin) {
    free(p);
}

// With TO_INSERT, we declare a global symbol that imports Iprof and then
// do an #add_context that binds to that symbol. This seems redundant, but
// if we just say #add_context :: #import "tracy", the import won't happen
// until the context gets finalized, which then means that anything imported
// by Iprof would be unable to add any thing to the context.
//
// Why are we adding an entry to the context? It's so that submodules can see
// the import, so that the code we inject actually works.
TO_INSERT :: #string DONE
__Tracy :: #import "tracy"(IMPORT_MODE=.CLIENT);
#add_context _Tracy :: __Tracy;
DONE

prepend_main    :: #code context._Tracy.ZoneScoped(); // Nothing special for now
prepend_zone    :: #code context._Tracy.ZoneScoped();

injected_final_profiling_code := false;
entry_point_name: string;
instrumented_entry_point := false;

#scope_module
#import "Basic";
#import "Compiler";
#import "File";
#import "String";

MINIMUM_SIZE_DEFAULT :: 30;

My_Plugin :: struct {
    #as using base: Metaprogram_Plugin;

    // These can be filled out by the user after calling get_plugin():

    should_instrument: (body: *Code_Procedure_Body) -> bool;

    per_frame_hook_name: string;
    editor\  _hook_name: string;
    font_name:           string;


    //
    // These things are set by commandline options:
    //
    csv_output_filename: string;
    min_size := MINIMUM_SIZE_DEFAULT;
    instrument_modules := false;

    //
    // The user should not mess with these:
    //
    prepend_main_nodes:   *Code_Node;
    prepend_zone_nodes:   *Code_Node;
}
