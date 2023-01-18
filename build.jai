#run {
	cpp_defines := string.["/DTRACY_ENABLE", "/DTRACY_EXPORTS"];
	cpp_main_path := join(#filepath, "/tracy/public/TracyClient.cpp");
	
	build_cpp_static_lib("TracyClient", cpp_main_path, extra = cpp_defines);
	build_cpp_dynamic_lib("TracyClient", cpp_main_path, extra = cpp_defines);
	
	set_build_options_dc(.{do_output = false});
}

#import "Basic";
#import "String";[
#import "BuildCpp";
#import "Compiler";