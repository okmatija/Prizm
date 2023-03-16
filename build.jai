#run {
	set_build_options_dc(.{do_output = false});

    #if OS == .WINDOWS {
        extra_args := string.["/DTRACY_ENABLE", "/DTRACY_EXPORTS"];
    } else {
        extra_args := string.["-DTRACY_ENABLE", "-DTRACY_EXPORTS", "-std=c++11", "-Wno-deprecated-declarations"];
    }

	cpp_main_path := join(#filepath, "/tracy/public/TracyClient.cpp");

	build_cpp_dynamic_lib("TracyClient", cpp_main_path, extra = extra_args);
	build_cpp_static_lib("TracyClient", cpp_main_path, extra = extra_args);
}

#import "Basic";
#import "String";
#import "BuildCpp";
#import "Compiler";
