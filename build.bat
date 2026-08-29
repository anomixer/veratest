@echo off
setlocal

where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Node.js is not installed or not found in PATH!
    echo Please install Node.js from https://nodejs.org to build this project.
    exit /b 1
)

set "TARGET=%~1"
if "%TARGET%"=="" goto do_help

if /i "%TARGET%"=="veratest" goto do_veratest
if /i "%TARGET%"=="slideshow" goto do_slideshow
if /i "%TARGET%"=="all" goto do_all
if /i "%TARGET%"=="help" goto do_help
if /i "%TARGET%"=="-h" goto do_help
if /i "%TARGET%"=="--help" goto do_help

echo [ERROR] Unknown build target: %TARGET%
echo.
goto do_help

:do_veratest
echo ==============================================================================
echo  Building VERA Test 6-in-1 Showcase Disk: veratest.po ...
echo ==============================================================================
node src\veratest\veratest.mjs
if %ERRORLEVEL% NEQ 0 (
    echo [FAILED] veratest build encountered an error!
    exit /b 1
)
echo [SUCCESS] veratest.po and veratest.png built successfully.
goto end

:do_slideshow
echo ==============================================================================
echo  Building VERA 32MB Slideshow Hard Disk: slideshow.hdv ...
echo ==============================================================================
node src\slideshow\slideshow_hdv.mjs
if %ERRORLEVEL% NEQ 0 (
    echo [FAILED] slideshow build encountered an error!
    exit /b 1
)
echo [SUCCESS] slideshow.hdv and slideshow.png built successfully.
goto end

:do_all
echo ==============================================================================
echo  Building All Targets: veratest.po and slideshow.hdv ...
echo ==============================================================================
echo.
echo [1/2] Building veratest.po...
node src\veratest\veratest.mjs
if %ERRORLEVEL% NEQ 0 (
    echo [FAILED] veratest build encountered an error!
    exit /b 1
)
echo.
echo [2/2] Building slideshow.hdv...
node src\slideshow\slideshow_hdv.mjs
if %ERRORLEVEL% NEQ 0 (
    echo [FAILED] slideshow build encountered an error!
    exit /b 1
)
echo.
echo ==============================================================================
echo  [SUCCESS] All targets built successfully!
echo ==============================================================================
goto end

:do_help
echo.
echo ==============================================================================
echo  VERA Build Script for Apple II
echo  BY ANOMIXER (https://github.com/anomixer)
echo ==============================================================================
echo.
echo  Syntax:
echo    build.bat [target]
echo.
echo  Targets:
echo    veratest    Build 140KB bootable floppy disk (veratest.po ^& veratest.png)
echo    slideshow   Build 32MB fullscreen hard disk image (slideshow.hdv ^& slideshow.png)
echo    all         Build both veratest.po and slideshow.hdv
echo    help        Show this syntax guide
echo.
echo  Examples:
echo    build.bat veratest
echo    build.bat slideshow
echo    build.bat all
echo.
exit /b 0

:end
exit /b 0
