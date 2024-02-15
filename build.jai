#run,stallable build();

build :: () {

    set_build_options_dc(.{do_output=false});

    set_working_directory(#filepath);

    w := compiler_create_workspace("Target Program");
    if !w exit(1);

    build_options := get_build_options(w);
    build_options.output_executable_name = "target";

    set_build_options(build_options, w);

    compiler_begin_intercept(w);

    add_build_file("source/prizm.jai", w);

    while true {
        message : *Message = compiler_wait_for_message();
        print("message.kind = %\n", message.kind);
    }

    compiler_end_intercept(w);
}

#import "Basic";
#import "Compiler";
