# Install script for directory: /mnt/c/Dev/Prizm/support/SDL3-3.4.4

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Install shared libraries without execute permission?
if(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)
  set(CMAKE_INSTALL_SO_NO_EXE "1")
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

# Set default install directory permissions.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/usr/bin/objdump")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/pkgconfig" TYPE FILE FILES "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/sdl3.pc")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  foreach(file
      "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSDL3.so.0.4.4"
      "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSDL3.so.0"
      )
    if(EXISTS "${file}" AND
       NOT IS_SYMLINK "${file}")
      file(RPATH_CHECK
           FILE "${file}"
           RPATH "")
    endif()
  endforeach()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE SHARED_LIBRARY FILES
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/libSDL3.so.0.4.4"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/libSDL3.so.0"
    )
  foreach(file
      "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSDL3.so.0.4.4"
      "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSDL3.so.0"
      )
    if(EXISTS "${file}" AND
       NOT IS_SYMLINK "${file}")
      if(CMAKE_INSTALL_DO_STRIP)
        execute_process(COMMAND "/usr/bin/strip" "${file}")
      endif()
    endif()
  endforeach()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSDL3.so" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSDL3.so")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSDL3.so"
         RPATH "")
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE SHARED_LIBRARY FILES "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/libSDL3.so")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSDL3.so" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSDL3.so")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSDL3.so")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/libSDL3_test.a")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3/SDL3headersTargets.cmake")
    file(DIFFERENT EXPORT_FILE_CHANGED FILES
         "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3/SDL3headersTargets.cmake"
         "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/CMakeFiles/Export/lib/cmake/SDL3/SDL3headersTargets.cmake")
    if(EXPORT_FILE_CHANGED)
      file(GLOB OLD_CONFIG_FILES "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3/SDL3headersTargets-*.cmake")
      if(OLD_CONFIG_FILES)
        message(STATUS "Old export file \"$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3/SDL3headersTargets.cmake\" will be replaced.  Removing files [${OLD_CONFIG_FILES}].")
        file(REMOVE ${OLD_CONFIG_FILES})
      endif()
    endif()
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3" TYPE FILE FILES "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/CMakeFiles/Export/lib/cmake/SDL3/SDL3headersTargets.cmake")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3/SDL3sharedTargets.cmake")
    file(DIFFERENT EXPORT_FILE_CHANGED FILES
         "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3/SDL3sharedTargets.cmake"
         "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/CMakeFiles/Export/lib/cmake/SDL3/SDL3sharedTargets.cmake")
    if(EXPORT_FILE_CHANGED)
      file(GLOB OLD_CONFIG_FILES "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3/SDL3sharedTargets-*.cmake")
      if(OLD_CONFIG_FILES)
        message(STATUS "Old export file \"$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3/SDL3sharedTargets.cmake\" will be replaced.  Removing files [${OLD_CONFIG_FILES}].")
        file(REMOVE ${OLD_CONFIG_FILES})
      endif()
    endif()
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3" TYPE FILE FILES "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/CMakeFiles/Export/lib/cmake/SDL3/SDL3sharedTargets.cmake")
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3" TYPE FILE FILES "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/CMakeFiles/Export/lib/cmake/SDL3/SDL3sharedTargets-release.cmake")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3/SDL3testTargets.cmake")
    file(DIFFERENT EXPORT_FILE_CHANGED FILES
         "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3/SDL3testTargets.cmake"
         "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/CMakeFiles/Export/lib/cmake/SDL3/SDL3testTargets.cmake")
    if(EXPORT_FILE_CHANGED)
      file(GLOB OLD_CONFIG_FILES "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3/SDL3testTargets-*.cmake")
      if(OLD_CONFIG_FILES)
        message(STATUS "Old export file \"$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3/SDL3testTargets.cmake\" will be replaced.  Removing files [${OLD_CONFIG_FILES}].")
        file(REMOVE ${OLD_CONFIG_FILES})
      endif()
    endif()
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3" TYPE FILE FILES "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/CMakeFiles/Export/lib/cmake/SDL3/SDL3testTargets.cmake")
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3" TYPE FILE FILES "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/CMakeFiles/Export/lib/cmake/SDL3/SDL3testTargets-release.cmake")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/SDL3" TYPE FILE FILES
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/SDL3Config.cmake"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/SDL3ConfigVersion.cmake"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/SDL3" TYPE FILE FILES
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_assert.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_asyncio.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_atomic.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_audio.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_begin_code.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_bits.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_blendmode.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_camera.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_clipboard.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_close_code.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_copying.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_cpuinfo.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_dialog.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_dlopennote.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_egl.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_endian.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_error.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_events.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_filesystem.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_gamepad.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_gpu.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_guid.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_haptic.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_hidapi.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_hints.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_init.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_intrin.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_iostream.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_joystick.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_keyboard.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_keycode.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_loadso.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_locale.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_log.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_main.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_main_impl.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_messagebox.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_metal.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_misc.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_mouse.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_mutex.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_oldnames.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_opengl.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_opengl_glext.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_opengles.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_opengles2.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_opengles2_gl2.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_opengles2_gl2ext.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_opengles2_gl2platform.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_opengles2_khrplatform.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_pen.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_pixels.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_platform.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_platform_defines.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_power.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_process.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_properties.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_rect.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_render.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_scancode.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_sensor.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_stdinc.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_storage.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_surface.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_system.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_thread.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_time.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_timer.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_touch.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_tray.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_version.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_video.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_vulkan.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/include-revision/SDL3/SDL_revision.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/SDL3" TYPE FILE FILES
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_test.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_test_assert.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_test_common.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_test_compare.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_test_crc32.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_test_font.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_test_fuzzer.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_test_harness.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_test_log.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_test_md5.h"
    "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/include/SDL3/SDL_test_memory.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/share/licenses/SDL3" TYPE FILE FILES "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/LICENSE.txt")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/test/cmake_install.cmake")
endif()

if(CMAKE_INSTALL_COMPONENT)
  set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
else()
  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
file(WRITE "/mnt/c/Dev/Prizm/support/SDL3-3.4.4/build/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
