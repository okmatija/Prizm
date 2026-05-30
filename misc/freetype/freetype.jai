#if OS == .WINDOWS {
    #load "windows/windows_freetype.jai";
} else #if OS == .MACOS || OS == .LINUX {
    #load "./unix_freetype.jai";
} else {
    #assert false "Dear ImGui Freetype currently only supports Windows, MacOS, and Linux. Check generate.jai to see how these platforms are implemented so that you can add support for your OS!";
}
