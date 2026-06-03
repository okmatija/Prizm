#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "SDL3::SDL3-shared" for configuration "Release"
set_property(TARGET SDL3::SDL3-shared APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(SDL3::SDL3-shared PROPERTIES
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libSDL3.so.0.4.4"
  IMPORTED_SONAME_RELEASE "libSDL3.so.0"
  )

list(APPEND _IMPORT_CHECK_TARGETS SDL3::SDL3-shared )
list(APPEND _IMPORT_CHECK_FILES_FOR_SDL3::SDL3-shared "${_IMPORT_PREFIX}/lib/libSDL3.so.0.4.4" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
