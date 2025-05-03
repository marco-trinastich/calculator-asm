REM ASM Build Tools - Copyright (c) 2023 Marco Trinastich
REM Licensed under GNU GPL v3 - see LICENSE file for details
REM ----------------------------------------

@echo off

REM ----------------------------------------
REM Script to link a Win64 application
REM Uses vsexec.bat to set up the environment
REM ----------------------------------------

REM Step 1: Check if input and output files are provided

REM Check if the input object file is provided
if "%~1"=="" (
    echo Error: No input object file specified.
    echo Usage: linkasm.bat ^<input_file.obj^> ^<output_file.exe^> [options]
    exit /b 1
)

REM Check if the output executable file is provided
if "%~2"=="" (
    echo Error: No output executable file specified.
    echo Usage: linkasm.bat ^<input_file.obj^> ^<output_file.exe^> [options]
    exit /b 1
)

REM Check if the input object file exists
if not exist "%~1" (
    echo Error: Input object file not found: "%~1".
    echo Usage: linkasm.bat ^<input_file.obj^> ^<output_file.exe^> [options]
    exit /b 1
)

REM Step 2: Extract vsexec_path, input file, output file, and additional options

REM Resolve the absolute path to vsexec.bat using %~dp0 
REM (we do it here because after the loop the path will be lost)
set "vsexec_path=%~dp0vsexec.bat"

REM Extract the input and output file names from the arguments
set input_file="%~1"
set input_file_unquoted=%~1
set output_file="%~2"

REM Extract additional options (everything after %2)
set "additional_options="
shift
shift
:loop
if not "%~1"=="" (
    set "additional_options=%additional_options% %~1"
    shift
    goto :loop
)

REM Step 3: Link the object file to create the executable

echo Linking %input_file_unquoted% (Win64/x86-64 app)...
echo.

REM Call vsexec.bat to set up the Visual Studio environment and execute the linker
call "%vsexec_path%" link /OUT:"%output_file%" %additional_options% "%input_file%"

REM Check if the linking process succeeded
if errorlevel 1 (
    echo.
    echo Error: Linking failed.
    exit /b 1
)

echo Linking completed successfully.