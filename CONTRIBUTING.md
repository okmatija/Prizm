# Coding style

Non-dogmatic, mostly do what you want but sticking to the following conventions would be appreciated

- function_names
- Macro_Names
- Structs_And_Types
- COMPILE_TIME_CONSTANTS (including enum names)
- Using a single space between an identifier and the ::, : or := and don't use backslashes in identifiers. These rules are indended to make searching easier)

# Release process

This tool is intended to be hackable and compiled from source as you use it. So it doesn't really make sense to release binaries, however, this is what we do while Jai is in closed beta.

From the top-level project directory do the following:

1. Update `build.jai` with the new version number
2. Update `CHANGELOG.md` to add the release date
3. Disable the runtime console and compile using: `jai build.jai -x64 -- release set_icon`
4. Test everything works
5. Copy the top-level directory and rename it `Prism-X.Y.Z`
6. Delete the .git folder and other folders/files not to be distributed
7. Zip the release folder
8. Unzip the release zip and test everything works
9. Use the github UI to complete the release: upload the release zip and copy the new section in the changelog to the description

Note: Delete tags using: `git tag --delete vNNN && git push --delete origin vNNN`