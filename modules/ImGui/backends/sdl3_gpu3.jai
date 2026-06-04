#if OS == .WINDOWS {
    #load "windows/windows_sdl3_gpu3.jai";
} else #if OS == .MACOS || OS == .LINUX {
    #load "./unix_sdl3_gpu3.jai";
} else {
    #assert false "sdl3_gpu3 currently only supports Windows, MacOS, and Linux. Check generate.jai to see how these platforms are implemented so that you can add support for your OS!";
}
