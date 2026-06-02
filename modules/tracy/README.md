# jai-tracy

Jai bindings for [Tracy 0.12.2](https://github.com/wolfpld/tracy) from [roeyb1/jai-tracy](https://github.com/roeyb1/jai-tracy).

Built with `-DTRACY_ON_DEMAND`: zero overhead when no Tracy GUI is connected, so the profiling build can be your normal development binary.

---

## Metaprogram setup

Tracy has two parts: a **plugin** (injected into the compiler, instruments the target program) and a **runtime** (linked into the target program).

### 1. Copy the runtime library next to your executable

Add this to `build()` in your metaprogram, after `set_working_directory`, before compilation:

```jai
// Always copy (no file_exists guard) so a rebuilt library is picked up immediately.
#if OS == .LINUX {
    if tracy_enabled {
        copy_file("modules/tracy/linux/libtracy.so", "libtracy.so");
    }
} else #if OS == .WINDOWS {
    if tracy_enabled {
        copy_file("modules/tracy/windows/libtracy.dll", "libtracy.dll");
    }
}
```

The Jai linker sets `-rpath='$ORIGIN'` on Linux, so a `.so` placed next to the executable is found at runtime without a system install.

Add `/libtracy.dll` and `/libtracy.so` to your `.gitignore`.

### 2. Load and register the plugin

```jai
#import "Metaprogram_Plugins";

plugins: [..] *Metaprogram_Plugin;

// In build(), before compiler_begin_intercept:
if tracy_enabled {
    // IMPORT_MODE=METAPROGRAM (default) loads the instrumentation plugin.
    // -min_size 100 skips tiny procedures (< 100 sub-expressions) to reduce overhead.
    plugin := get_plugin(.(name = "tracy", args = .["-min_size", "100"]));
    array_add(*plugins, plugin);
}
init_plugins(plugins, w);

// Pass messages to plugins in the intercept loop:
for plugins  if it.message  it.message(it, message);

// After the intercept loop:
for plugins  if it.finish    it.finish(it);
for plugins  if it.shutdown  it.shutdown(it);
```

### 3. Tell the target program Tracy is enabled

```jai
add_build_string("USE_TRACY :: true;", w);  // or false for non-profiling builds
```

---

## Using Tracy in your program

Import Tracy in the target program (not the metaprogram):

```jai
#if USE_TRACY {
    using,except(ZoneScoped) context._Tracy;  // brings FrameMark, FrameMarkStart/End etc. into scope
}
```

**The plugin auto-instruments every procedure** with `ZoneScoped()` — you get full call-tree coverage without any manual annotation. Add manual zones only where you want explicit names or colours:

```jai
some_proc :: () {
    #if USE_TRACY  context._Tracy.ZoneScoped("my_zone", color = 0xFF4020);
    // ...
}
```

Tag a procedure with `@NoProfile` to exclude it from auto-instrumentation.

**Frame boundaries** — call once per frame so Tracy separates per-frame data:

```jai
#if USE_TRACY  context._Tracy.FrameMark();
```

**Named spans** for async or multi-frame work:

```jai
#if USE_TRACY  context._Tracy.FrameMarkStart("asset_load");
// ... async work ...
#if USE_TRACY  context._Tracy.FrameMarkEnd("asset_load");
```

---

## Running a profiling session

1. Build your program with Tracy enabled.
2. Download the Tracy 0.12.x GUI from the [releases page](https://github.com/wolfpld/tracy/releases) — the GUI version **must match** the library version (0.12.x).
3. Start the Tracy GUI, then start your program.
4. Click **Connect** — Tracy auto-detects the process on `localhost:8086`.

Because the library uses `ON_DEMAND`, the program runs at full speed until the GUI connects.

---

## Plugin options

| Option | Effect |
|---|---|
| `-min_size N` | Skip auto-instrumentation for procedures with fewer than N sub-expressions. Default: 100. |
| `-modules` | Also instrument imported modules (not just the main program). |

---

## Platform notes

### Linux

Pre-built `linux/libtracy.so` — compiled from source on Ubuntu 22.04 (glibc 2.35) with:
```
-DTRACY_ON_DEMAND -DTRACY_NO_SYSPROFILE -DTRACY_EXPORTS -std=c++20 -fPIC -shared
```

`-DTRACY_NO_SYSPROFILE` disables OS-level call-stack sampling (SysTrace). On WSL, SysTrace floods the thread timeline with `[unknown]` frames because Jai's debug symbols aren't in a format Tracy's symbol resolver handles.

**To rebuild** (Ubuntu/Debian, g++ required):
```bash
cd modules/tracy
g++ -std=c++20 -DTRACY_ENABLE -DTRACY_EXPORTS -DTRACY_ON_DEMAND -DTRACY_NO_SYSPROFILE \
    -Wno-deprecated-declarations -fPIC -shared \
    -o linux/libtracy.so tracy/public/TracyClient.cpp \
    -lpthread -ldl
```

### Windows

Pre-built `windows/libtracy.dll` + `windows/libtracy.lib` (import library). Built without `/GL /LTCG` — using LTCG embeds object code inside the import library, which causes `LNK2019: _Thrd_sleep_for` on MSVC 14.36+ where that symbol was inlined in STL headers and is no longer exported from `msvcp140.dll`.

**If the pre-built DLL fails to link** (MSVC version mismatch), rebuild from source. Open an **x64 Native Tools Command Prompt for VS 2022** and run:
```
cd modules\tracy
rebuild_windows.bat
```
This produces a fresh `windows/libtracy.dll` and `windows/libtracy.lib` compatible with your installed MSVC.

### macOS

Not yet tested. `bindings.jai` has the `#library "macos/libtracy"` clause; the binary is missing. Run `jai generate.jai` on a Mac to produce it (requires `Bindings_Generator` with libclang, and Xcode command-line tools).

---

## Regenerating bindings

Only needed if the Tracy C API changes (i.e. upgrading to a new Tracy version). Requires `Bindings_Generator` (needs libclang):

```
cd modules/tracy
jai generate.jai
```

This recompiles the library from source and regenerates `bindings.jai`. To skip recompilation and only regenerate the bindings:

```
jai generate.jai - -no_compile
```
