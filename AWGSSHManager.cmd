@echo off

:: Check if PowerShell (pwsh) is installed and available in PATH
where pwsh >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo PowerShell was not found on your system.
    echo Please download and install the latest version from: https://aka.ms/powershell
    pause
    exit /b 1
)

:: Full path to the PowerShell script (the folder where this .cmd resides)
set "PS_SCRIPT=%~dp0main.ps1"

:: If a command‑line argument was supplied, use it as the XML file path.
:: Otherwise pass an empty string (the PowerShell script will receive $null).
set "XML_ARG=%~1"

:: Call PowerShell
::   -NoProfile          – run without loading any profiles
::   -ExecutionPolicy Bypass – allow execution even when a restrictive policy is set
::   -File               – specify the script file to run
::   "%XML_ARG%"         – first positional parameter of the script (full path to the XML file)
pwsh -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" "%XML_ARG%"