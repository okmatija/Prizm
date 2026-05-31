#import "Basic";
#import "Compiler";
#import "File_Utilities";

#run build();

build :: () {
    set_build_options_dc(.{do_output=false});
    set_working_directory(#filepath);

    // Copy SDL3 runtime next to the spike executable so the dynamic linker finds it.
    #if OS == .LINUX {
        if !file_exists("libSDL3.so.0")
            copy_file("../modules/SDL3/linux/bin/x64/libSDL3.so", "libSDL3.so.0");
    }

    w := compiler_create_workspace("spike");
    if !w exit(1);

    options := get_build_options(w);

    new_path: [..] string;
    array_add(*new_path, "../modules"); // pick up SDL3 3.4.4 and ImGui before stdlib
    array_add(*new_path, ..options.import_path);
    options.import_path = new_path;

    options.output_executable_name = "spike";
    options.output_path = "./";

    set_build_options(options, w);
    add_build_file("spike.jai", w);
}
