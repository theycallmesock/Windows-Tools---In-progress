@echo off
setlocal EnableExtensions EnableDelayedExpansion

set SCRIPT_DIR=%~dp0

set PS_SCRIPT=Optimization Scripts.ps1

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

echo Running %PS_SCRIPT% as Administrator...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%%PS_SCRIPT%"

echo.
echo Script finished. Press any key to exit...
pause >nul
