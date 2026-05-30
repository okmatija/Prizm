#if OS == .WINDOWS {
    #load "windows/windows.jai";
} else #if OS == .LINUX {
    #load "linux/linux.jai";
} else #if OS == .MACOS {
    #load "macos/macos.jai";
}
