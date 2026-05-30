#run build();

vulkan_support := false;

build :: () {

    set_build_options_dc(.{do_output=false});

    options := get_build_options();
    args := options.compile_time_command_line;
    vulkan_support = array_find(args, "-vulkan");

    if !generate_bindings() {
        compiler_set_workspace_status(.FAILED);
        return;
    }
}

generate_bindings :: () -> bool {

    output_filename: string;
    opts: Generate_Bindings_Options;

    {
        #if OS == .WINDOWS {

            output_filename = "windows/windows.jai";
            opts.strip_flags = .FUNCTIONS_WITH_VALIST;

            FOOTER :: #string EOF
#if CPU == .X64 {
    sdl3 :: #library,no_dll "bin/x64/SDL3";
} else #if CPU == .ARM64 {
    sdl3 :: #library,no_dll "bin/arm64/SDL3";
}
// MSG and HINSTANCE conflict with Jai's Windows module so are omitted from generated
// output. SDL_WindowsMessageHook is redefined here using *void for the msg parameter
// (same ABI; cast to *MSG from Jai's Windows module if field access is needed).
SDL_WindowsMessageHook :: #type (userdata: *void, msg: *void) -> bool #c_call;
EOF
            // DLL provided by user not in bin, so use our own footer not generated library declaration
            opts.footer = FOOTER;
            opts.generate_library_declarations = false;

            #if CPU == .X64 {
                array_add(*opts.library_search_paths, "windows/bin/x64");
            } else #if CPU == .ARM64 {
                array_add(*opts.library_search_paths, "windows/bin/arm64");
            } else {
                assert(false, "the CPU % is currently unsupported. You might be able to add support for it though!", CPU);
            }

            array_add(*opts.libraries, .{filename="SDL3"});

        } else #if OS == .LINUX {
            opts.strip_flags = .FUNCTIONS_WITH_VALIST;

            output_filename = "linux/linux.jai";

            FOOTER :: #string EOF
// libsdl3 is declared in module.jai (conditionally on USE_SYSTEM_LIBRARY module parameter).
EOF;
            opts.footer = FOOTER;
            opts.generate_library_declarations = false;

            array_add(*opts.libraries, .{filename="libSDL3.so.0"});

        } else #if OS == .MACOS {

            output_filename = "macos/macos.jai";
            opts.strip_flags = .FUNCTIONS_WITH_VALIST;

            FOOTER :: #string EOF
    libsdl3 :: #library "bin/arm64/libSDL3.0_dynamic"; // Universal binary
EOF;
            // We have a universal binary
            #if CPU == .ARM64 || CPU == .X64 {
                array_add(*opts.library_search_paths, "macos/bin/arm64");
            } else {
                assert(false, "the CPU % is currently unsupported. You might be able to add support for it though!", CPU);
            }

            opts.footer = FOOTER;
            opts.generate_library_declarations = false;

            // We need the .a to bind but .dylib is used in runtime.
            array_add(*opts.libraries, .{filename="libSDL3.0"});
        } else {
            assert(false, "the OS % is currently unsupported. You might be able to add support for it though!", OS);
        }

        array_add(*opts.include_paths, "include");
        array_add(*opts.source_files, "include/SDL3/SDL.h");
        array_add(*opts.source_files, "include/SDL3/SDL_main.h");
        if vulkan_support {
            array_add(*opts.source_files, "include/SDL3/SDL_vulkan.h");
            opts.footer = sprint("#import \"Vulkan\";\n%", opts.footer);
        }

        opts.visitor = sdl3_visitor;
        opts.generate_compile_time_struct_checks = false;
    }

    return generate_bindings(opts, output_filename);
}

event_type_decl: *Enum;

sdl3_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {

    if vulkan_support {
        if begins_with(decl.name, "Vk") {
            decl.decl_flags |= .OMIT_FROM_OUTPUT;
            return .STOP;
        }
    }

    if array_find(DECLARATIONS_TO_OMIT, decl.name) {
        decl.decl_flags |= .OMIT_FROM_OUTPUT;
        return .STOP;
    }

    if decl.kind == .ENUM {
        en := cast(*Enum)decl;
        if en.name == "SDL_EventType" {
            event_type_decl = en; // Save for later
        }
    }

    // Here we replace the Uint8 type to SDL_EventType enum
    if parent_decl && parent_decl.kind == .STRUCT && ends_with(parent_decl.name, "Event") && decl.kind == .DECLARATION && decl.name == "type" {
        type := New(CType);
        type.type_of_enum = event_type_decl;
        type.size = event_type_decl.type.size;
        decl.type = type;
    }

    if parent_decl == null && decl.kind == .TYPEDEF {
        // We handcraft our window flag.
        if decl.name == "SDL_WindowFlags" {
            decl.decl_flags |= .OMIT_FROM_OUTPUT;
            return .STOP;
        }

        // Also handcraft init flag.
        if decl.name == "SDL_InitFlags" {
            decl.decl_flags |= .OMIT_FROM_OUTPUT;
            return .STOP;
        }
    }

    // Remove the init flag define.
    if parent_decl == null && begins_with(decl.name, "SDL_INIT_") {
        decl.decl_flags |= .OMIT_FROM_OUTPUT;
        return .STOP;
    }

    return .RECURSE;
}

#scope_file

#import "Basic";
#import "Compiler";
#import "BuildCpp";
#import "Check";
#import "Bindings_Generator";
#import "File";
#import "String";

DECLARATIONS_TO_OMIT :: string.[
    "_m_prefetch",
    "__debugbreak",

    // SDL_WINDOWPOS_* are #define macros converted to inline functions by the generator,
    // but they are handcrafted as cross-platform inline procs in module.jai to avoid
    // the platform files generating conflicting duplicates.
    "SDL_WINDOWPOS_UNDEFINED_DISPLAY",
    "SDL_WINDOWPOS_UNDEFINED",
    "SDL_WINDOWPOS_ISUNDEFINED",
    "SDL_WINDOWPOS_CENTERED_DISPLAY",
    "SDL_WINDOWPOS_CENTERED",
    "SDL_WINDOWPOS_ISCENTERED",

    // Windows types that conflict with Jai's built-in Windows module.
    // SDL_WindowsMessageHook is redefined in the Windows footer using *void for the
    // msg parameter to avoid taking a dependency on Jai's Windows module.
    "HINSTANCE__",
    "HINSTANCE",
    "tagMSG",
    "MSG",
    "SDL_WindowsMessageHook",

    /*
    Those are force inlined functions defined in the headers, so they don't appear in the library and so bindings generator complains.

    One way is to automatically remove inline, compile them into a DLL, and turn them into #c_call jai procs. However, this loses inline.

    The performant way is to rewrite them in pure jai code, however that introduces overhead of ensuring they are updated.
    */
    "SDL_size_mul_check_overflow",
    "SDL_size_mul_check_overflow_builtin",
    "SDL_size_add_check_overflow",
    "SDL_size_add_check_overflow_builtin",
    "SDL_SwapFloat",
    "SDL_MostSignificantBitIndex32",
    "SDL_HasExactlyOneBitSet32",
    "SDL_RectToFRect",
    "SDL_PointInRect",
    "SDL_RectEmpty",
    "SDL_RectsEqual",
    "SDL_PointInRectFloat",
    "SDL_RectEmptyFloat",
    "SDL_RectsEqualEpsilon",
    "SDL_RectsEqualFloat",
    "SDL_main",
    "main",
    "wmain",
    "main1",
    "WinMain",
    "wWinMain",
];
