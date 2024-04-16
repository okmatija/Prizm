# Tracy bindings for Jai

Jai bindings for the [Tracy profiler](https://github.com/wolfpld/tracy) v0.9.

It’s originally based on [vrcamillo/jai-tracy](https://github.com/vrcamillo/jai-tracy), but modified to work as an auto-instrumenting metaprogram plugin (like modules/Iprof).

## Setup

1. Ensure that the `tracy` submodule is cloned at the root of the repository.
2. Build the static and shared libraries using `jai build.jai` at the root of the repository.

## Profiling run-time code

Just use this module as a metaprogram plugin by adding `-pluging tracy` to your compile command.
If you want to profile modules code (in addition to your application code) you can append the argument `-modules`.

You might need to add `-- import_dir <path_to_modules_folder_that_contains_tracy>` if this module does not live in your default modules folder.

## Profiling compile-time code

You can even use this plugin to profile your compile-time metaprogram, #run commands, etc. But it requires some inception-style work:

1. Tell the compile to use the Default_Metaprogram _with the tracy plugin_ to compile … the Default_Metaprogram.
2. Then use that second Default_Metaprogram to compile your project.

It looks something like this:

```shell
    jai <path_to_jai>/modules/Default_Metaprogram.jai -plug tracy -modules -no_cwd \ # Compile Default_Metaprogram with the tracy plugin
    - <your_normal_entry_file>.jai <your normal compile arguments> \ # Arguments for the second-stage Default_Metaprogram, which is what you would normally pass to the compiler/metaprogram
    -- import_dir <path_to_modules_folder_that_contains_tracy> # Add this if you need to tell the first-stage Default_Metaprogram where to find the tracy module.
```


## License and more information
Tracy is released under the [3-clause BSD license](https://github.com/wolfpld/tracy/blob/master/LICENSE).

These bindings are released under the [MIT license](https://github.com/vrcamillo/jai-tracy/blob/main/LICENSE).

You can find more detailed information in Tracy documentation, available in the [official repository](https://github.com/wolfpld/tracy).
