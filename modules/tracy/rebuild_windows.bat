@echo off
rem Rebuild libtracy.dll (x64) for Windows using the local MSVC toolchain.
rem
rem MUST be run from an x64 Native Tools Command Prompt for VS 2019 or later:
rem   Start menu -> "x64 Native Tools Command Prompt for VS 2022"
rem   cd /d C:\Dev\Prizm\modules\tracy
rem   rebuild_windows.bat
rem
rem Outputs:
rem   windows\libtracy.dll  -- DLL to be copied next to Prizm.exe
rem   windows\libtracy.lib  -- import library used at link time
rem
rem Why /GL and /LTCG are NOT used:
rem   /GL + /LTCG embeds full LTCG object code inside the import library. When Prizm
rem   (a non-LTCG binary) links against that fat import lib, the linker pulls in
rem   TracyClient.obj directly, hits _Thrd_sleep_for (inlined in MSVC 14.36+ STL headers,
rem   no longer exported from msvcp140.dll), and fails with LNK2019. Without LTCG the lib
rem   contains only import stubs; the DLL carries all C++ runtime dependencies on its own.

setlocal
cd /d "%~dp0"

rem Detect whether we are in an x64 environment.
if /i "%VSCMD_ARG_TGT_ARCH%" == "x64" goto arch_ok
if /i "%PLATFORM%" == "X64" goto arch_ok
echo.
echo ERROR: This script must be run from an x64 Native Tools Command Prompt.
echo        Start menu: "x64 Native Tools Command Prompt for VS 2022"
echo        (not the plain "Developer Command Prompt", which defaults to x86)
exit /b 1
:arch_ok

echo Building Tracy 0.12.2 for Windows (x64)...

cl /nologo /c /MD /O2 /GR- ^
   /DTRACY_ENABLE /DTRACY_EXPORTS /DTRACY_ON_DEMAND ^
   /std:c++20 /EHsc /W0 ^
   tracy\public\TracyClient.cpp ^
   /Fo:windows\TracyClient.obj
if errorlevel 1 (
    echo.
    echo ERROR: cl.exe failed. Are you running from a VS Developer Command Prompt?
    exit /b 1
)

link /nologo /DLL /MACHINE:X64 ^
     /OUT:windows\libtracy.dll ^
     /IMPLIB:windows\libtracy.lib ^
     windows\TracyClient.obj ^
     ws2_32.lib advapi32.lib user32.lib
if errorlevel 1 (
    del /q windows\TracyClient.obj 2>nul
    echo.
    echo ERROR: link.exe failed.
    exit /b 1
)

del /q windows\TracyClient.obj
echo.
echo Done. windows\libtracy.dll and windows\libtracy.lib are ready.
echo Now run: jai.exe first.jai - tracy
endlocal
