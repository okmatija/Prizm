# Goals

- When you implement a feature adding a comment explaining the user-facing motivation for it next to the implementation is useful, so that we are not tempted to remove an obscure looking feature because we forgot why it was useful. Perhaps start such comments with "Feature documentation:"
- Prizm supports annotations by making comments in .obj files semantically significant, this should be the only way we extend other formats, it would be annoying for users if we encourage them to write data to the file that would make it not loadable in other viewers

# Coding style

Non-dogmatic, mostly do what you want but sticking to the following conventions would be appreciated

- Using a single space between an identifier and the :: or : and don't use backslashes in identifiers. This convention is intended to make searching easier. If explicit types are used use single spaces ie : Type =
- But to improve readability avoid using := for assignments unless the type can be trivially inferred from the context (unfortunately there is a lot of code that doesn't do this, but it can be gradually fixed). Note that with explicit types its a bit harder to search for declarations (unless you also know the type)
- Naming convention: function_names, Structs_And_Types, MacroNames, COMPILE_TIME_CONSTANTS (including enum names)
- Naming convention: Use _model/_world postfix for geometry in model/world space
- Consider using a g_ prefix for global variables
- Consider using a t_ prefix for variables in temporary storage e.g., functions returning strings in temporary storage, or maybe _t postfix for functions returning results in temporary storage
- Consider a naming convention init_Type_Name makes it easier to find the function?
- Consider a naming convention new_Type_Name for functions which internally call New(Type_Name) and init_Type_Name
- Consider a naming convention make_Type_Name for functions which return a copy of a struct?
- init(thing : *Thing)/deinit(thing : *Thing) functions should work on stack instances as well as values on the head. Hence they shouldn't call free. Look up what New does (allocate, init, cast?), we want a placement new type thing
- Consider using `thing_kind` for `enum` variables, `thing_type` for `Type` variables and `thing` otherwise
- When you rename a function, particularly a console command, search all .jai and .obj files for the name so you can fix all the references, we think good, unambiguous user documentation is important!
- Don't indent line with the case keyword in a switch, but do indent the case body


# Release process

This tool is intended to be hackable and compiled from source as you use it. So it doesn't really make sense to release binaries, however, this is what we do while Jai is in closed beta:

1. Update `changelog.jai` with the release date. Update `EXPECTED_COMPILER_VERSION_INFO`

2. Compile using: `jai first.jai - release`

3. Select the following then do `RMB > 7-zip > Add to archive...`, use the naming convention `Prizm_X.Y.Z` and set the archive format to zip
    api/
    shapes/
    Prizm.exe
    SDL2.dll

4. Test the release
    a. Unzip the release zip and launch Prizm.exe
    b. Test all the files in the shapes/ folder load correctly
    c. Test a large obj file (>200MB) file
    d. Test the C++ API works by calling the Prizm::documentation and Prizm::DocumentationForUnreal functions

5. Use the GitHub UI to complete the release: Upload the release zip and copy the new section in the changelog to the description and set the git tag

6. Post a release message:
    a. Write a changelog summary with a SCREENSHOT
    b. Post the zip in a followup message on the thread
    c. Post the full changelog in a further followup

Note: Delete tags using: `git tag --delete vNNN && git push --delete origin vNNN`