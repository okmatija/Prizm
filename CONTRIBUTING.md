# Coding style

Non-dogmatic, mostly do what you want but sticking to the following conventions would be appreciated

- function_names
- MacroNames
- Structs_And_Types
- COMPILE_TIME_CONSTANTS (including enum names)
- Using a single space between an identifier and the ::, : or := and don't use backslashes in identifiers. These rules are indended to make searching easier)
- t_ prefix for variables allocated in temporary storage? or functions returning strings in temporary storage?
- g_ prefix for global variables? (gt_ for global temporaries?)

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