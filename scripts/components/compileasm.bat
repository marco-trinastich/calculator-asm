REM ASM Build Tools - Copyright (c) 2023 Marco Trinastich
REM Licensed under GNU GPL v3 - see LICENSE file for details
REM ----------------------------------------

@echo off

REM ----------------------------------------
REM Script to compile a Win64 assembly file
REM Uses NASM to generate an object file
REM ----------------------------------------

REM Step 1: Check if input and output files are provided

REM Check if the input file is provided
if "%~1"=="" (
    echo Error: No input file specified.
    echo Usage: compileasm.bat ^<input_file.asm^> ^<output_file.obj^> [options]
    exit /b 1
)

REM Check if the output file is provided
if "%~2"=="" (
    echo Error: No output file specified.
    echo Usage: compileasm.bat ^<input_file.asm^> ^<output_file.obj^> [options]
    exit /b 1
)

REM Step 2: Extract input file, output file, and additional options

REM Extract the input and output file names from the arguments
set input_file="%~1"
set input_file_name=%~nx1
set "input_dir=%~dp1"
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

REM Step 3: Compile the assembly file

echo Compiling %input_file_name% (Win64/x86-64 arch)...

REM Run NASM to compile the assembly file (-I resolves %include relative to the source dir)
nasm -f win64 "%input_file%" -I "%input_dir%." -o "%output_file%" %additional_options% -g
if errorlevel 1 (
    echo.
    echo Error: Compilation failed.
    exit /b 1
)

echo Compilation completed successfully.