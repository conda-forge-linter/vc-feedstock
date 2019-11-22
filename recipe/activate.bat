:: Set env vars that tell distutils to use the compiler that we put on path
SET DISTUTILS_USE_SDK=1
:: This is probably not good. It is for the pre-UCRT msvccompiler.py *not* _msvccompiler.py
SET MSSdk=1

:: http://stackoverflow.com/a/26874379/1170370
SET platform=
IF /I [%PROCESSOR_ARCHITECTURE%]==[amd64] set "platform=true"
IF /I [%PROCESSOR_ARCHITEW6432%]==[amd64] set "platform=true"

if defined platform (
set "VSREGKEY=HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\14.0"
)  ELSE (
set "VSREGKEY=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0"
)
for /f "skip=2 tokens=2,*" %%A in ('reg query "%VSREGKEY%" /v InstallDir') do SET "VSINSTALLDIR=%%B"

if "%VSINSTALLDIR%" == "" (
   set "VSINSTALLDIR=%VS140COMNTOOLS%"
)

if "%VSINSTALLDIR%" == "" (
   ECHO "WARNING: Did not find VS in registry or in VS140COMNTOOLS env var - your compiler may not work"
   GOTO End
)

echo "Found VS2014 at %VSINSTALLDIR%"

SET "VS_VERSION=14.0"
SET "VS_MAJOR=14"
SET "VS_YEAR=2015"

set "MSYS2_ARG_CONV_EXCL=/AI;/AL;/OUT;/out"
set "MSYS2_ENV_CONV_EXCL=CL"

:: For Python 3.5+, ensure that we link with the dynamic runtime.  See
:: http://stevedower.id.au/blog/building-for-python-3-5-part-two/ for more info
set "PY_VCRUNTIME_REDIST=%PREFIX%\vcruntime140.dll"

:: ensure that we use the DLL part of the ucrt
set "CFLAGS=%CFLAGS% -MD -GL"
set "CXXFLAGS=%CXXFLAGS% -MD -GL"
set "LDFLAGS_SHARED=%LDFLAGS_SHARED% -LTCG ucrt.lib"

:: set CC and CXX for cmake
set "CXX=cl.exe"
set "CC=cl.exe"

:: translate target platform
IF /I [%target_platform%]==[win-64] (
   set "folder=x64"
) else (
   set "folder=x86"
)

:: find the most recent Win SDK path and add it to PATH (so that rc.exe gets found)
for /f "tokens=*" %%I in ('dir "C:\Program Files (x86)\Windows Kits\*1*" /B /O:N') do for %%A in (%%~I) do if "%%A" == "8.1" set win=%%A

for /f "tokens=*" %%I in ('dir "C:\Program Files (x86)\Windows Kits\*1*" /B /O:N') do for %%A in (%%~I) do if "%%A" == "10" set win=%%A

setlocal enabledelayedexpansion
if "%win%" == "10" (
   for /f "tokens=*" %%I in ('dir "C:\Program Files (x86)\Windows Kits\10\bin\10*" /B /O:N') do for %%A in (%%~I) do set last=%%A
   set "sdk_bin_path=C:\Program Files (x86)\Windows Kits\10\bin\!last!\%folder%"
) else (
   set "sdk_bin_path=C:\Program Files (x86)\Windows Kits\8.1\bin\%folder%"
)
endlocal & set "PATH=%PATH%;%sdk_bin_path%"

IF NOT "%CONDA_BUILD%" == "" (
  set "INCLUDE=%LIBRARY_INC%;%INCLUDE%"
  set "LIB=%LIBRARY_LIB%;%LIB%"
  set "CMAKE_PREFIX_PATH=%LIBRARY_PREFIX%;%CMAKE_PREFIX_PATH%"
)

IF "%CMAKE_GENERATOR%" == "" IF "%cross_compiler_target_platform%" == "win-64" SET "CMAKE_GENERATOR=Visual Studio %VS_MAJOR% %VS_YEAR% Win64"
IF "%CMAKE_GENERATOR%" == "" IF "%cross_compiler_target_platform%" == "win-32" SET "CMAKE_GENERATOR=Visual Studio %VS_MAJOR% %VS_YEAR%"

SET "MSBUILDDEFAULTTOOLSVERSION=14.0"

IF "%CI%" == "azure" (
  IF "%cross_compiler_target_platform%" == "win-64" CALL "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" amd64 -vcvars_ver=14.0
  IF "%cross_compiler_target_platform%" == "win-32" CALL "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" x86 -vcvars_ver=14.0
  GOTO End
)

IF "%cross_compiler_target_platform%" == "win-64" CALL "%VSINSTALLDIR%..\..\VC\vcvarsall.bat" amd64
IF "%cross_compiler_target_platform%" == "win-32" CALL "%VSINSTALLDIR%..\..\VC\vcvarsall.bat" x86

:End
