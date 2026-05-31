# Working in Jai

This project is written in **Jai**, a statically-typed systems language (closed beta). You already know how to program; the rules below are the places where Jai differs from C/C++/Rust/Go and where you will otherwise make mistakes. When you hit something not covered here, read the numbered tutorials in `C:\Dev\jai\how_to\` — they are ordered and meant to be read in sequence. Don't guess at syntax; check the relevant file.

## The #1 gotcha: no implicit numeric narrowing

Numeric *constants* auto-convert to any type they fit in. Numeric *variables* only implicitly convert when the target holds the entire source range (widening, and never signed→unsigned). Everything else needs an explicit `cast`.

```jai
a : u8; b : u16 = 50;
b = a;              // ok: u16 holds all u8
// a = b;           // ERROR: needs cast(u8) b
a = cast(u8) b;     // ok; cast does a runtime range-check
a = cast,no_check(u8) b;  // skip the check when truncation is intended
```

YOU MUST add explicit `cast(T)` when mixing integer sizes/signedness, or assigning between `int`/`s32`/`u32`/`u64` etc. This is the single most common first-pass compile error — expect it and write the cast up front rather than waiting for the compiler.

`int` == `s64`. `float` == `float32`. Untyped integer literals default to `s64`, float literals to `float32`.

## Syntax that trips people up

- **Declarations:** `name : Type = value;` — constant `name :: value;` — inferred `name := value;` — uninitialized (skip zeroing) `name : Type = ---;`
- **Pointers:** `*T` is a pointer type. `*x` takes the address of `x` (this is `&` in C). `x.*` dereferences (this is `*x` in C). So `array_add(*arr, item)` passes a pointer.
- **Procedures:** `name :: (a: int, b: float) -> ReturnType { ... }`. Multiple returns: `-> int, string`. Default + named args are supported and can reorder: `f(b = 2, a = 1)`.
- **Member access auto-derefs:** `ptr.field` works on a pointer; no `->`.
- **`if`-case (switch):** `if value == { case .A; ...; case .B; ...; }`. Cases do **not** fall through unless you write `#through;`. Use `if #complete value == {` to require all enum cases.
- **Enums use the unary dot:** write `.RED`, not `Color.RED`, where the type is known.
- Statements end with `;`. `==`, not assignment, in conditions.

## Arrays and strings

- Three array kinds: `[N]T` fixed (inline), `[]T` view (count+data, points at someone else's memory), `[..]T` resizable (owns memory + allocator). Fixed/resizable auto-cast to views.
- Grow with `array_add(*arr, x)`.
- `string` is effectively `[]u8`, UTF-8, **not** null-terminated. Substrings are free (just adjust `.count`/`.data`). String constants *are* zero-terminated and implicitly cast to `*u8` for C interop; non-constant strings do not.
- Build strings with `tprint`/`sprint` or `String_Builder` (`init_string_builder`, `append`, `print_to_builder`, `builder_to_string`). There is no `+` concatenation.

## Memory management

- No constructors/destructors, no RAII, no GC. Memory is explicit and allocator-based.
- **Temporary storage** is the default for short-lived allocations: `tprint(...)` allocates there and is auto-reclaimed (typically reset each frame / per iteration). Use it for transient strings and scratch buffers instead of malloc/free. See `how_to/012_temporary_storage.jai`.
- Allocations go through `context.allocator`; swap it (often with an arena) to bulk-free a whole phase at once rather than freeing nodes individually. See `how_to/200_memory_management.jai` and `800_allocators.jai`.
- `defer <stmt>;` runs at scope exit — use it for cleanup (`free`, `array_free`, closing handles).

## Print / logging

`print` uses `%` as the placeholder for *every* argument in order (no `%d`/`%s`); `%%` is a literal `%`. Newlines are manual (`\n`). `print("% and %\n", a, b)`. Anything prints with `%`, including structs and types.

## Common idioms

- `for x { use it and it_index }`; `for v, i: x` names them; `for * x` iterates by pointer (to mutate); `for < x` reverses.
- `using` imports a struct's/enum's names into scope.
- `#import "Module";` pulls in a module; `#load "file.jai";` adds a source file to the current program.
- Compile-time errors are the norm and are good — prefer letting the compiler catch things over runtime checks.

## The compiler

The `jai` compiler lives in `C:\Dev\jai\bin\`. **We work in WSL, so use the Linux binary `jai-linux`** (the directory also holds `jai.exe` for native Windows and `jai-macos`). From the repo root that is `/mnt/c/Dev/jai/bin/jai-linux`. Always compile to typecheck before claiming a change works; the first compile of new code commonly fails on missing numeric casts (see top) — fix those and recompile, this is expected, not a sign the approach is wrong.

# Working in Prizm

Prizm is a standalone viewer for debugging computational-geometry algorithms: you write OBJ files from your program and inspect them to find bugs. It loads only the [OBJ format](https://paulbourke.net/dataformats/obj/) (plus Prizm-specific comment extensions for annotations and command annotations) and is built on Dear ImGui (UI) and SDL (platform). See `README.md` and the wiki at `C:\Dev\Prizm.wiki\Home.md` for the feature set and OBJ support details.

## Building

Prizm has no makefile — it is built by its own Jai **metaprogram**, `first.jai`, which compiles `source/prizm.jai` into the `Prizm` executable. Everything after the `-` is passed to the metaprogram:

```bash
/mnt/c/Dev/jai/bin/jai-linux first.jai - debug      # debug build (default)
/mnt/c/Dev/jai/bin/jai-linux first.jai - release    # optimized build
/mnt/c/Dev/jai/bin/jai-linux first.jai - verydebug  # debug + memory debugger (use to check for leaks)
/mnt/c/Dev/jai/bin/jai-linux first.jai - shipping   # release + icon + bundled .zip (release process only)
```

Other metaprogram options: `debug_gl` (GL 4.3 + debug, for RenderDoc), `tracy` (Tracy profiling), `custom` (currently broken). `first.jai` sets its own working directory, so run it from the repo root.

`first.jai` pins `EXPECTED_COMPILER_VERSION_INFO` and reports an error if the `jai` binary's version differs — if you see that, the compiler in `C:\Dev\jai\bin\` and the source are out of sync; don't try to work around it silently.

Run the result against the sample geometry: `./Prizm shapes/*.obj`.

## Console commands

Prizm has an in-app console (toggle with `` ` ``). A console command is just a normal Jai procedure tagged with a `@RegisterCommand` note — the build metaprogram scans for these and generates the boilerplate that makes them callable, with the comment block immediately above the procedure becoming its in-console documentation. See `source/console/commands.jai` for examples. Arguments are space-separated with no parentheses or commas; items are referenced by their integer index.

**When you rename a command (or any procedure referenced by name), search all `.jai` *and* `.obj` files** — OBJ files invoke commands via command annotations (`#! command_name args`), so a rename can break sample data and user files, not just code.

## Coding style

Non-dogmatic, but match these conventions (full list in the wiki's "Coding Style" section):

- Naming: `function_names`, `Structs_And_Types`, `MacroNames`, `COMPILE_TIME_CONSTANTS` (incl. enum values). Optional but common: `g_` prefix for globals, `t_` prefix / `_t` suffix for things in temporary storage, `_model`/`_world`/`_screen` space suffixes, leading `_` for `_auto_generated` symbols.
- One space around `:` / `::` (e.g. `name : Type = value`, `name :: value`). Prefer explicit types over `:=` unless the type is trivially inferable — this keeps declarations searchable.
- In `if ==` (switch) statements, do **not** indent the `case` keyword, but do indent the case body.
- When adding a non-obvious user-facing feature, comment its motivation at the implementation site (start with `Feature documentation:`).
- Prizm must not push users to write OBJ files that fail to load in other viewers — keep extensions inside OBJ comments.
- Task priority convention is borrowed from [fixmee](https://github.com/rolandwalker/fixmee). Priority is encoded by **repeating the final character of the keyword** — more repetitions = more urgent. This applies across all our keyword markers, e.g. `@TODO`/`@TODOOOO` and `@FIXME`/`@FIXMEEEE`. A tool can list and sort markers in descending urgency order. Use the plain (un-repeated) form unless something is genuinely urgent, don't exceed 3 additional characters.
## Git workflow

**Never run `git push` unless the user explicitly says to push.** Committing locally is fine without being asked; pushing to the remote requires an explicit instruction.

## Source code style notes

- **ASCII only**: use only ASCII characters in source code. Replace Unicode symbols with ASCII equivalents (e.g. `in` instead of `∈`, `*` instead of `×`, `>=` instead of `≥`).
- **`:=` spacing**: always write `name := value` — one space between the name and `:=`, no extra spaces between them. Alignment spaces go after `:=` (on the value side), never before it.
