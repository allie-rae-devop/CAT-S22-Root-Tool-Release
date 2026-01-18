# CAT S22 Root Tool - Self-Contained Build Script
# This script embeds PowerShell scripts directly into the C# source and compiles

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
Write-Host "  CAT S22 Root Tool - Self-Contained" -ForegroundColor Cyan
Write-Host "  Build Script" -ForegroundColor Cyan
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
    "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
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
    exit 1
}

# Read the template source
$templateSource = Join-Path $SourceDir "CAT_S22_Root_Tool_SelfContained.cs"
if (-not (Test-Path $templateSource)) {
    Write-Host "[ERROR] Template source not found: $templateSource" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Reading template source..." -ForegroundColor Cyan
$sourceContent = Get-Content -Path $templateSource -Raw

# Read PowerShell scripts
Write-Host "[INFO] Embedding PowerShell scripts..." -ForegroundColor Cyan

$rootScript = Join-Path $ResourceDir "CAT_S22_Root_Tool.ps1"
$debloatScript = Join-Path $ResourceDir "CAT_S22_Enhanced_Debloat.ps1"

if (-not (Test-Path $rootScript)) {
    Write-Host "[ERROR] Root script not found: $rootScript" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $debloatScript)) {
    Write-Host "[ERROR] Debloat script not found: $debloatScript" -ForegroundColor Red
    exit 1
}

# Function to escape script content for C# string literal
function ConvertTo-CSharpVerbatimString {
    param([string]$Content)

    # For verbatim strings, we just need to escape double quotes by doubling them
    return $Content.Replace('"', '""')
}

$rootScriptContent = Get-Content -Path $rootScript -Raw
$debloatScriptContent = Get-Content -Path $debloatScript -Raw

$escapedRootScript = ConvertTo-CSharpVerbatimString -Content $rootScriptContent
$escapedDebloatScript = ConvertTo-CSharpVerbatimString -Content $debloatScriptContent

# Replace placeholders in source
$sourceContent = $sourceContent.Replace(
    'public const string RootToolScript = @"EMBEDDED_ROOT_SCRIPT_PLACEHOLDER";',
    "public const string RootToolScript = @`"$escapedRootScript`";"
)

$sourceContent = $sourceContent.Replace(
    'public const string DebloatScript = @"EMBEDDED_DEBLOAT_SCRIPT_PLACEHOLDER";',
    "public const string DebloatScript = @`"$escapedDebloatScript`";"
)

# Write modified source to temp file
$tempSourceFile = Join-Path $OutputDir "CAT_S22_Root_Tool_Generated.cs"
Write-Host "[INFO] Writing generated source: $tempSourceFile" -ForegroundColor Cyan
$sourceContent | Out-File -FilePath $tempSourceFile -Encoding UTF8

# Compile
Write-Host "[BUILD] Compiling self-contained executable..." -ForegroundColor Cyan

$outputExe = Join-Path $OutputDir "$ProjectName.exe"

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
    "`"$tempSourceFile`""
)

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

# Copy required binary files (boot image and Magisk APK - too large to embed)
Write-Host "[COPY] Copying binary resources..." -ForegroundColor Cyan

$bootImagesDir = Join-Path $ResourceDir "boot_images"
$outputBootDir = Join-Path $OutputDir "boot_images"

if (Test-Path $bootImagesDir) {
    if (-not (Test-Path $outputBootDir)) {
        New-Item -ItemType Directory -Path $outputBootDir -Force | Out-Null
    }
    Copy-Item -Path "$bootImagesDir\*" -Destination $outputBootDir -Recurse -Force
    Write-Host "  Copied: boot_images\" -ForegroundColor Gray
}

$magiskApk = Join-Path $ResourceDir "Magisk-v25.2.apk"
if (Test-Path $magiskApk) {
    Copy-Item -Path $magiskApk -Destination $OutputDir -Force
    Write-Host "  Copied: Magisk-v25.2.apk" -ForegroundColor Gray
}

# Clean up temp files
Remove-Item -Path "$OutputDir\build.log" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$OutputDir\build_errors.log" -Force -ErrorAction SilentlyContinue
Remove-Item -Path $tempSourceFile -Force -ErrorAction SilentlyContinue

# Calculate sizes
$exeSize = (Get-Item $outputExe).Length / 1KB
$totalSize = (Get-ChildItem -Path $OutputDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  BUILD COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Output directory: $OutputDir" -ForegroundColor Cyan
Write-Host "Executable size: $([math]::Round($exeSize, 1)) KB" -ForegroundColor Cyan
Write-Host "Total package size: $([math]::Round($totalSize, 1)) MB" -ForegroundColor Cyan
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

    $zipSize = (Get-Item $zipPath).Length / 1MB
    Write-Host "[SUCCESS] Created: $zipPath ($([math]::Round($zipSize, 1)) MB)" -ForegroundColor Green
}

Write-Host ""
Write-Host "The executable contains embedded PowerShell scripts." -ForegroundColor Yellow
Write-Host "Boot images and Magisk APK are included as separate files." -ForegroundColor Yellow
Write-Host ""
Write-Host "To distribute:" -ForegroundColor Cyan
Write-Host "  1. Zip the entire 'build' folder" -ForegroundColor Gray
Write-Host "  2. Or run: .\build_selfcontained.ps1 -Package" -ForegroundColor Gray
Write-Host ""
