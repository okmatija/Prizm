# Coding style

Non-dogmatic, mostly do what you want but sticking to the following conventions would be appreciated

- Using a single space between an identifier and the :: or : and don't use backslashes in identifiers. This convention is intended to make searching easier. If explicit types are used use single spaces ie : Type =
- But to improve readability avoid using := for assignments unless the type can be trivially inferred from the context (unfortunately there is a lot of code that doesn't do this, but it can be gradually fixed). Note that with explicit types its a bit harder to search for declarations (unless you also know the type)
- Naming convention: function_names, Structs_And_Types, MacroNames, COMPILE_TIME_CONSTANTS (including enum names)
- Consider using a g_ prefix for global variables
- Consider using a t_ prefix for variables in temporary storage e.g., functions returning strings in temporary storage

# Release process

This tool is intended to be hackable and compiled from source as you use it. So it doesn't really make sense to release binaries, however, this is what we do while Jai is in closed beta.

From the top-level project directory do the following:

1. Update `changelog.jai` with the release date
2. Disable the runtime console and compile using: `jai build.jai -- release`
3. Test everything works
4. Copy the top-level directory and rename it `Prism-X.Y.Z`
5. Delete the .git, data, source folder and other folders/files not to be distributed
6. Zip the release folder
7. Unzip the release zip and test everything works
8. Use the GitHub UI to complete the release: upload the release zip and copy the new section in the changelog to the description and set the git tag

Note: Delete tags using: `git tag --delete vNNN && git push --delete origin vNNN`