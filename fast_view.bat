@REM mdbook fast view script with environment checks
@echo off
setlocal enabledelayedexpansion

echo ========================================
echo   mdbook Fast View Script
echo ========================================
echo.

REM 1. Environment Check - Python Version Validation
echo [1/4] Checking Python environment...
python --version >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Python is not installed or not in PATH environment variable
    echo.
    echo Please install Python 3.7+ and ensure it is added to PATH
    echo Download: https://www.python.org/downloads/
    echo.
    pause
    exit /b 1
)

REM Get Python version information
for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo Python version: !PYTHON_VERSION!

REM Check if Python version is 3.7+
for /f "tokens=1,2 delims=." %%a in ("!PYTHON_VERSION!") do (
    set MAJOR=%%a
    set MINOR=%%b
)
if !MAJOR! lss 3 (
    echo [ERROR] Python version too low, requires 3.7+
    echo Current version: !PYTHON_VERSION!
    echo.
    pause
    exit /b 1
)
if !MAJOR! equ 3 if !MINOR! lss 7 (
    echo [ERROR] Python version too low, requires 3.7+
    echo Current version: !PYTHON_VERSION!
    echo.
    pause
    exit /b 1
)
echo [OK] Python environment check passed

echo.
echo [2/4] Checking dependency files...

REM 2. Dependency Validation - Check generate_summary.py
if not exist ".\tools\generate_summary.py" (
    echo [ERROR] File not found: .\tools\generate_summary.py
    echo Please confirm the file exists and path is correct
    echo.
    pause
    exit /b 1
)
echo [OK] generate_summary.py file exists

REM Check mdbook.exe
if not exist ".\tools\mdbook.exe" (
    echo [ERROR] File not found: .\tools\mdbook.exe
    echo Please confirm mdbook.exe exists in tools directory
    echo.
    pause
    exit /b 1
)
echo [OK] mdbook.exe file exists

echo.
echo [3/4] Generating SUMMARY.md file...

REM 3. Automated Execution Flow - Generate SUMMARY.md
python .\tools\generate_summary.py
if !errorlevel! neq 0 (
    echo [ERROR] SUMMARY.md generation failed
    echo Please check if generate_summary.py script works properly
    echo.
    pause
    exit /b 1
)

REM Verify SUMMARY.md was successfully generated
if not exist "SUMMARY.md" (
    echo [ERROR] SUMMARY.md file was not generated
    echo Please check generate_summary.py script output
    echo.
    pause
    exit /b 1
)
echo [OK] SUMMARY.md generated successfully

echo.
echo [4/4] Starting mdbook service...

REM 4. Start mdbook service
echo Starting mdbook server...
echo Server will automatically open in browser
echo Press Ctrl+C to stop server
echo.

.\tools\mdbook.exe serve --open
if !errorlevel! neq 0 (
    echo [ERROR] mdbook service startup failed
    echo Please check if mdbook.exe works properly
    echo.
    pause
    exit /b 1
)

echo.
echo mdbook service stopped
pause
