#run build();

build :: () {

    set_working_directory(#filepath);

    w := compiler_create_workspace("Target Program");
    if !w {
        print("Workspace creation failed.\n");
        return;
    }

    target_options := get_build_options(w);
    target_options.output_executable_name = "target";
    set_build_options(target_options, w);

    compiler_begin_intercept(w);
    add_build_file("target.jai", w);
    message_loop();
    compiler_end_intercept(w);

    set_build_options_dc(.{do_output=false});
}

message_loop :: () {
    while true {
        print("Call compiler_wait_for_message()...\n");
        message : *Message = compiler_wait_for_message();
        print("Done, got message.kind = %\n", message.kind);
        if message.kind == .COMPLETE break;
    }
}

#import "Basic";
#import "Compiler";
