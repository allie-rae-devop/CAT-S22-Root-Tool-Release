@echo off
setlocal enabledelayedexpansion

echo ========================================
echo   CAT S22 Root Tool - Build Script
echo ========================================
echo.

:: Configuration
set "PROJECT_NAME=CAT_S22_Root_Tool"
set "SCRIPT_DIR=%~dp0"
set "OUTPUT_DIR=%SCRIPT_DIR%build"
set "SOURCE_DIR=%SCRIPT_DIR%src"

:: Create output directory
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: Find C# compiler
set "CSC="
if exist "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" (
    set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
) else if exist "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe" (
    set "CSC=C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
) else (
    echo [ERROR] C# compiler not found!
    echo Please install .NET Framework 4.0 or later.
    pause
    exit /b 1
)

echo [INFO] Found compiler: %CSC%
echo.

:: Compile
echo [BUILD] Compiling %PROJECT_NAME%...
"%CSC%" /target:winexe /out:"%OUTPUT_DIR%\%PROJECT_NAME%.exe" /optimize+ /platform:anycpu ^
    /reference:System.dll ^
    /reference:System.Core.dll ^
    /reference:System.Drawing.dll ^
    /reference:System.Windows.Forms.dll ^
    /reference:System.IO.Compression.dll ^
    /reference:System.IO.Compression.FileSystem.dll ^
    "%SOURCE_DIR%\CAT_S22_Root_Tool_GUI.cs"

if errorlevel 1 (
    echo [ERROR] Compilation failed!
    pause
    exit /b 1
)

echo [SUCCESS] Compiled successfully!
echo.

:: Copy resources
echo [COPY] Copying resources...

if exist "%SCRIPT_DIR%CAT_S22_Root_Tool.ps1" (
    copy /Y "%SCRIPT_DIR%CAT_S22_Root_Tool.ps1" "%OUTPUT_DIR%\" >nul
    echo   Copied: CAT_S22_Root_Tool.ps1
)

if exist "%SCRIPT_DIR%CAT_S22_Enhanced_Debloat.ps1" (
    copy /Y "%SCRIPT_DIR%CAT_S22_Enhanced_Debloat.ps1" "%OUTPUT_DIR%\" >nul
    echo   Copied: CAT_S22_Enhanced_Debloat.ps1
)

if exist "%SCRIPT_DIR%boot_images" (
    if not exist "%OUTPUT_DIR%\boot_images" mkdir "%OUTPUT_DIR%\boot_images"
    xcopy /Y /Q "%SCRIPT_DIR%boot_images\*" "%OUTPUT_DIR%\boot_images\" >nul
    echo   Copied: boot_images\
)

if exist "%SCRIPT_DIR%Magisk-v25.2.apk" (
    copy /Y "%SCRIPT_DIR%Magisk-v25.2.apk" "%OUTPUT_DIR%\" >nul
    echo   Copied: Magisk-v25.2.apk
)

echo.
echo ========================================
echo   BUILD COMPLETE!
echo ========================================
echo.
echo Output directory: %OUTPUT_DIR%
echo.
echo To run the tool:
echo   1. Navigate to: %OUTPUT_DIR%
echo   2. Run: %PROJECT_NAME%.exe (as Administrator)
echo.
echo Press any key to open the build folder...
pause >nul
explorer "%OUTPUT_DIR%"
