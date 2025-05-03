REM ASM Build Tools - Copyright (c) 2023 Marco Trinastich
REM Licensed under GNU GPL v3 - see LICENSE file for details
REM ----------------------------------------

@echo off

REM ----------------------------------------
REM Script to set up the Visual Studio environment
REM Uses vswhere.exe to autodiscover vcvarsall.bat
REM ----------------------------------------

REM Check if VCVARSALL_PATH is already set in environment
if not "%VCVARSALL_PATH%"=="" (
    echo Using provided vcvarsall: "%VCVARSALL_PATH%"
    echo.
    goto :execute
)

REM Define paths
set "VSWHERE_PATH=C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
set "VCVARSALL_PATH="

REM Step 1: Check if vswhere.exe exists
if not exist "%VSWHERE_PATH%" (
    echo Error: vswhere.exe not found. Please install Visual Studio Installer or specify VCVARSALL_PATH manually.
    exit /b 1
)

REM Step 2: Attempt to autodiscover vcvarsall.bat
for /f "delims=" %%i in ('"%VSWHERE_PATH%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find **/vcvarsall.bat 2^>nul') do set "VCVARSALL_PATH=%%i"

REM Step 3: Check if vcvarsall.bat was found
if "%VCVARSALL_PATH%"=="" (
    echo Error: Could not autodiscover vcvarsall.bat. Ensure Visual Studio is installed or specify VCVARSALL_PATH manually.
    exit /b 1
)

REM Step 3: Display the discovered vcvarsall.bat path
echo Discovered vcvarsall: "%VCVARSALL_PATH%"
echo.

:execute
REM Determine architecture and set appropriate vcvarsall parameters
set VCVARS_ARGS=amd64
set DETECTED_ARCH=unknown

REM Architecture detection
if defined PROCESSOR_ARCHITEW6432 (
    REM Running 32-bit process on 64-bit OS
    set DETECTED_ARCH=%PROCESSOR_ARCHITEW6432%
) else (
    set DETECTED_ARCH=%PROCESSOR_ARCHITECTURE%
)

REM Set appropriate arguments
if /i "%DETECTED_ARCH%"=="AMD64" (
    set VCVARS_ARGS=amd64
    echo Host architecture: AMD64 ^(64-bit^)
) else if /i "%DETECTED_ARCH%"=="x86" (
    set VCVARS_ARGS=x86_amd64
    echo Host architecture: x86 ^(32-bit^), cross-compiling to AMD64
) else if /i "%DETECTED_ARCH%"=="ARM64" (
    set VCVARS_ARGS=arm64_amd64
    echo Host architecture: ARM64, cross-compiling to AMD64
) else (
    echo Warning: Unknown architecture %DETECTED_ARCH%, attempting with %DETECTED_ARCH%_amd64
    set VCVARS_ARGS=%DETECTED_ARCH%_amd64
)

echo Target architecture: AMD64
echo.

REM Step 4: Call vcvarsall.bat and execute the passed command
call "%VCVARSALL_PATH%" %VCVARS_ARGS% && %*

REM Step 5: Check if the command executed successfully
if errorlevel 1 (
    echo Error: Visual Studio command execution failed.
    exit /b 1
)