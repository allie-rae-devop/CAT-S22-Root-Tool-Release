# CAT S22 Root Tool - Build Script
# This script compiles the C# wrapper into an executable

param(
    [switch]$Clean,
    [switch]$Package
)

$ErrorActionPreference = "Stop"

# Configuration
$ProjectName = "CAT_S22_Root_Tool"
$OutputDir = Join-Path $PSScriptRoot "build"
$SourceDir = Join-Path $PSScriptRoot "src"
$ResourceDir = $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CAT S22 Root Tool - Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Clean if requested
if ($Clean) {
    Write-Host "[CLEAN] Removing build directory..." -ForegroundColor Yellow
    if (Test-Path $OutputDir) {
        Remove-Item -Path $OutputDir -Recurse -Force
    }
}

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Find the latest .NET Framework C# compiler
$cscPaths = @(
    "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe",
    "C:\Windows\Microsoft.NET\Framework64\v3.5\csc.exe",
    "C:\Windows\Microsoft.NET\Framework\v3.5\csc.exe"
)

$cscPath = $null
foreach ($path in $cscPaths) {
    if (Test-Path $path) {
        $cscPath = $path
        Write-Host "[INFO] Found C# compiler: $cscPath" -ForegroundColor Green
        break
    }
}

if (-not $cscPath) {
    Write-Host "[ERROR] C# compiler (csc.exe) not found!" -ForegroundColor Red
    Write-Host "Please install .NET Framework 4.0 or later." -ForegroundColor Yellow
    exit 1
}

# Create a simple icon (or use embedded resource)
Write-Host "[INFO] Preparing resources..." -ForegroundColor Cyan

$sourceFile = Join-Path $SourceDir "CAT_S22_Root_Tool_GUI.cs"
$outputExe = Join-Path $OutputDir "$ProjectName.exe"

# Check if source file exists
if (-not (Test-Path $sourceFile)) {
    Write-Host "[ERROR] Source file not found: $sourceFile" -ForegroundColor Red
    exit 1
}

Write-Host "[BUILD] Compiling $ProjectName..." -ForegroundColor Cyan

# Compile the C# code
$compileArgs = @(
    "/target:winexe",
    "/out:`"$outputExe`"",
    "/optimize+",
    "/platform:anycpu",
    "/reference:System.dll",
    "/reference:System.Core.dll",
    "/reference:System.Drawing.dll",
    "/reference:System.Windows.Forms.dll",
    "/reference:System.IO.Compression.dll",
    "/reference:System.IO.Compression.FileSystem.dll",
    "`"$sourceFile`""
)

$compileCommand = "$cscPath $($compileArgs -join ' ')"
Write-Host "[DEBUG] $compileCommand" -ForegroundColor Gray

$process = Start-Process -FilePath $cscPath -ArgumentList $compileArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$OutputDir\build.log" -RedirectStandardError "$OutputDir\build_errors.log"

$buildLog = Get-Content -Path "$OutputDir\build.log" -ErrorAction SilentlyContinue
$errorLog = Get-Content -Path "$OutputDir\build_errors.log" -ErrorAction SilentlyContinue

if ($buildLog) {
    Write-Host $buildLog -ForegroundColor Gray
}

if ($process.ExitCode -ne 0) {
    Write-Host "[ERROR] Compilation failed!" -ForegroundColor Red
    if ($errorLog) {
        Write-Host $errorLog -ForegroundColor Red
    }
    exit 1
}

Write-Host "[SUCCESS] Compiled: $outputExe" -ForegroundColor Green

# Copy required files to build directory
Write-Host "[COPY] Copying resources to build directory..." -ForegroundColor Cyan

# Copy PowerShell scripts
$scriptsToCopy = @(
    "CAT_S22_Root_Tool.ps1",
    "CAT_S22_Enhanced_Debloat.ps1"
)

foreach ($script in $scriptsToCopy) {
    $sourcePath = Join-Path $ResourceDir $script
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $OutputDir -Force
        Write-Host "  Copied: $script" -ForegroundColor Gray
    } else {
        Write-Host "  [WARN] Not found: $script" -ForegroundColor Yellow
    }
}

# Copy boot images
$bootImagesDir = Join-Path $ResourceDir "boot_images"
$outputBootDir = Join-Path $OutputDir "boot_images"

if (Test-Path $bootImagesDir) {
    if (-not (Test-Path $outputBootDir)) {
        New-Item -ItemType Directory -Path $outputBootDir -Force | Out-Null
    }
    Copy-Item -Path "$bootImagesDir\*" -Destination $outputBootDir -Recurse -Force
    Write-Host "  Copied: boot_images\" -ForegroundColor Gray
}

# Copy Magisk APK
$magiskApk = Join-Path $ResourceDir "Magisk-v25.2.apk"
if (Test-Path $magiskApk) {
    Copy-Item -Path $magiskApk -Destination $OutputDir -Force
    Write-Host "  Copied: Magisk-v25.2.apk" -ForegroundColor Gray
}

# Clean up build logs
Remove-Item -Path "$OutputDir\build.log" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$OutputDir\build_errors.log" -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  BUILD COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Output directory: $OutputDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files:" -ForegroundColor Cyan
Get-ChildItem -Path $OutputDir -Recurse | ForEach-Object {
    $relativePath = $_.FullName.Replace($OutputDir + "\", "")
    $size = if ($_.PSIsContainer) { "[DIR]" } else { "{0:N0} KB" -f ($_.Length / 1KB) }
    Write-Host "  $relativePath - $size" -ForegroundColor Gray
}

# Package if requested
if ($Package) {
    Write-Host ""
    Write-Host "[PACKAGE] Creating portable ZIP archive..." -ForegroundColor Cyan

    $zipPath = Join-Path $PSScriptRoot "CAT_S22_Root_Tool_Portable.zip"

    if (Test-Path $zipPath) {
        Remove-Item -Path $zipPath -Force
    }

    Compress-Archive -Path "$OutputDir\*" -DestinationPath $zipPath -Force

    $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
    Write-Host "[SUCCESS] Created: $zipPath ($zipSize MB)" -ForegroundColor Green
}

Write-Host ""
Write-Host "To run the tool:" -ForegroundColor Yellow
Write-Host "  1. Navigate to: $OutputDir" -ForegroundColor Gray
Write-Host "  2. Run: $ProjectName.exe (as Administrator)" -ForegroundColor Gray
Write-Host ""
