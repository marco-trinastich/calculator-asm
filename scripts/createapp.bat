REM ASM Build Tools - Copyright (c) 2023 Marco Trinastich
REM Licensed under GNU GPL v3 - see LICENSE file for details
REM ----------------------------------------

@echo off

REM ----------------------------------------
REM Script to compile and link a Win64 application
REM This script calls compileasm.bat and linkasm.bat
REM ----------------------------------------

echo Build started
echo.

REM Check if the output directory exists, create it if it doesn't
if not exist out (
    echo Creating output directory...
    echo.
    mkdir out
)

REM Compile the assembly file
call "%~dp0components\compileasm.bat" "%~dpn1.asm" out\%~n1.obj
echo.
if errorlevel 1 (
    exit /b 1
)

REM Link the object file to create the executable 
REM (the %2 argument can be used to pass additional linker options)
call "%~dp0components\linkasm.bat" out\%~n1.obj out\%~n1.exe %2
echo.
if errorlevel 1 (
    exit /b 1
)

echo Build completed successfully. Executable created: out\%~n1.exe

REM ----------------------------------------
REM Powershell Parameters Notes:
REM echo %0         ==> full quoted path+filename ("path\to\file")
REM echo %~f0		==> full path+filename (path\to\file)
REM echo %~dp0		==> full path (path\to\)
REM echo %~nx0		==> filename (file)		