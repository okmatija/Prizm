# Tracy-Bindings-for-Jai

Jai bindings for the [Tracy profiler](https://github.com/wolfpld/tracy) v0.9.

## Setup 

1. Ensure that the `tracy` submodule is cloned at the root of the repository. 
2. Build the static and shared libraries using `jai build.jai` at the root of the repository.
3. Move this repository to your modules folder and `#import`.

## API
Some helpful macros are provided to help users interface with the C API:
```
{
  ZoneScoped(); // Call this at the beginning of a scope you want to profile.
  do_some_stuff();
}

// If your application runs in frames...
while true {
  do_one_frame();
  FrameMark(); // Call this at the end of every frame. 
}
```

These macros allow various optional arguments to provide more information to Tracy about the zones. Look at `module.jai` for reference.

## Support 

These bindings were tested on Windows only. Porting this library to other platforms would just be a matter of building static and dynamic libraries. 
Feel free to test these on other platforms and file an issue in case of any problems.  

## License and more information 
Tracy is released under the [3-clause BSD license](https://github.com/wolfpld/tracy/blob/master/LICENSE).

These bindings are released under the MIT license.

You can find more detailed information in Tracy documentation, available in the [official repository](https://github.com/wolfpld/tracy).
