# jai-sdl3

Jai bindings for [SDL3 v3.4.4](https://github.com/libsdl-org/SDL/releases/tag/release-3.4.4) using the Bindings Generator.

These bindings are 'pure', we don't add or change the interface to SDL3.

## Installation

Copy this into your modules folder, then:

- **Windows**: Put the proper (x64/arm64) DLL next to your executable and make sure it's called `SDL3.dll`. Prebuilt DLLs [here](https://github.com/overlord-systems/jai-sdl3/releases/tag/v1.5_3.4.4).
- **Linux**: By default links against the system `libSDL3.so.0`. Pass `USE_SYSTEM_LIBRARY=false` to use the prebuilt x64 binary bundled in `linux/bin/x64/` instead. See the [Linux note](#linux-note) below for details on both options.
- **MacOS**: Place the `x86/arm64` universal dynamic library (download from [here](https://github.com/overlord-systems/jai-sdl3/releases/tag/v1.5_3.4.4)) next to your executable and make sure its called `libSDL3.0.dylib` (thanks to @4iwen).

SDL supports a ton of platforms, so adding support for things like Android/iOS/etc should be possible.

### Copying the library in your build script

Rather than requiring users to install SDL3 separately, your `first.jai` (or equivalent build metaprogram) can copy the bundled library next to your executable automatically. The Jai linker sets `-rpath='$ORIGIN'` on Linux, so a library placed next to the executable is found at runtime without a system install.

```jai
// Add near the top of build(), after set_working_directory(), before compilation.
// Copies the SDL3 runtime library from the module into the project root if not present.
{
    #if OS == .WINDOWS {
        sdl3_src :: "modules/SDL3/windows/bin/x64/SDL3.dll";
        sdl3_dst :: "SDL3.dll";
    } else #if OS == .LINUX {
        sdl3_src :: "modules/SDL3/linux/bin/x64/libSDL3.so.0";
        sdl3_dst :: "libSDL3.so.0";
    } else #if OS == .MACOS {
        sdl3_src :: "modules/SDL3/macos/bin/arm64/libSDL3.0_dynamic.dylib";
        sdl3_dst :: "libSDL3.0.dylib";
    }
    if !file_exists(sdl3_dst) {
        if !copy_file(sdl3_src, sdl3_dst) {
            compiler_report(tprint("Could not copy SDL3 library from '%' to '%'.", sdl3_src, sdl3_dst), mode=.ERROR_CONTINUABLE);
        }
    }
}
```

`file_exists` and `copy_file` are both from Jai's `File_Utilities` module. Add `SDL3.dll`, `libSDL3.so.0`, and `libSDL3.0.dylib` to your `.gitignore` since they are derived outputs.

### Linux Note

SDL3 does not ship prebuilt Linux binaries in its official releases. Two options are available:

**Option A — system library (default)**

Install SDL3 system-wide and import normally:

```jai
#import "SDL3";
```

To install from the bundled binary:

```sh
sudo cp linux/bin/x64/libSDL3.so.0 /usr/local/lib/
sudo ldconfig
```

**Option B — bundled library**

Use the prebuilt x64 binary in `linux/bin/x64/` directly, without a system install:

```jai
#import "SDL3"(USE_SYSTEM_LIBRARY=false);
```

No installation step required; the module resolves the library path automatically.

---

The bundled binary (SDL 3.4.4, built with `-O3 -DNDEBUG`) is a release build: optimized, no debug info, but **not stripped** (symbol table intact). To reduce size:

```sh
strip --strip-unneeded linux/bin/x64/libSDL3.so.0
```

To rebuild it yourself from source (commands assume you are in the jai-sdl3 repo root):

```sh
mkdir support && cd support
curl -L https://github.com/libsdl-org/SDL/releases/download/release-3.4.4/SDL3-3.4.4.tar.gz \
     -o SDL3-3.4.4.tar.gz
tar xzf SDL3-3.4.4.tar.gz
cmake -S SDL3-3.4.4 -B SDL3-3.4.4/build \
      -DSDL_SHARED=ON -DSDL_STATIC=OFF -DCMAKE_BUILD_TYPE=Release -GNinja \
      -DSDL_UDEV=OFF -DSDL_X11_XTEST=OFF -DSDL_X11_XSCRNSAVER=OFF
ninja -C SDL3-3.4.4/build SDL3-shared
cp SDL3-3.4.4/build/libSDL3.so.0.4.4 ../linux/bin/x64/libSDL3.so.0
```

The `OFF` flags disable optional X11/udev features not installed by default on many distros; remove them if you want full feature coverage.  Note that bundled file is named `libSDL3.so.0` — its SONAME. SDL3's `CMakeLists.txt` hardcodes `SDL_SO_VERSION_MAJOR` to `0`, so the SONAME is always `libSDL3.so.0` regardless of the SDL release version, and for SDL 3.4.4 the build process generates `libSDL3.so.0.4.4` which we rename to `libSDL3.so.0`.


### Windows DLL Note

The prebuilt `SDL3.dll` distributed with this module (and available on the releases page) is a **release build with no debug symbols** — no PDB file, no embedded DWARF, no CodeView data. It is safe to ship alongside your executable as-is. If you need a debug build (e.g. to step into SDL internals), build SDL3 from source with `-DCMAKE_BUILD_TYPE=Debug`.

### MacOS Note

On (some?) MacOS machines the generator **requires** a `.a` static library (it can't generate bindings from a dylib, we get weird errors), but compiling a jai program fails if we try to link to that same `.a` library.

As such, we run the generator on the bundled `.a`, but the bindings link to the bundled `libSDL3.0_dynamic.dylib` and you are required to have `libSDL3.0.dylib` next to your executable.

The reason we do this is to ensure jai uses the dynamic library when compiling. If we simply places `.a` and `.dylib` with the same name in one folder, jai will always pick the `.a` static library and compilation will fail.

What the source of this mess is, and whether it will improve, is to be seen.

## Callbacks API

We have exposed `SDL_EnterAppMainCallbacks` in order to hook into the callback API. This does **not** require the callbacks to be #c_call! Also, you can name the functions whatever you prefer, the following example uses the "standard" names.

```jai
    main :: ()
    {
        SDL_EnterAppMainCallbacks(SDL_AppInit, SDL_AppIterate, SDL_AppEvent, SDL_AppQuit);
    }
```

## Notes

Due to current limitations in the bindings generator, especially around nested macros, some enums (e.g. `SDL_WINDOW_...`) and macros (e.g. `SDL_WINDOWPOS_UNDEFINED`) don't get generated by default.

To fix this we hardcode some code in `generate.jai` that gets put at the top of the generated bindings file. As the bindings generator matures we should be able to get incrementally get rid of these until the bindings are fully automated.

## Vulkan support

Vulkan is supported, but you have to import a Vulkan binding on your own. You can either use the stock vulkan binding by JBlow, generate your own vulkan binding using the binding generator, or use a binding generate from vk.xml like [this](https://github.com/drshapeless/vulkan-jai-binding).

The vulkan support is default to be off. You can generate a binding with vulkan using command line args.

```
jai generate.jai - -vulkan
```

## Contribution

Want to support a new platform or found some missing enums/macros not generated? please feel free to send a PR!

To support a new platform check `generate.jai` and replicate what's done in the Windows/Linux section for your platform, then run `jai generate.jai`.
