# Create release ZIP packages
$ErrorActionPreference = "Stop"

$baseDir = $PSScriptRoot
$releasesDir = Join-Path $baseDir "releases"

# Clean and create releases directory
if (Test-Path $releasesDir) { Remove-Item $releasesDir -Recurse -Force }
New-Item -ItemType Directory -Path $releasesDir -Force | Out-Null

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Creating Release Packages" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Create Portable EXE package
Write-Host "[1/2] Creating CAT_S22_Root_Tool_Portable.zip..." -ForegroundColor Yellow
$portableZip = Join-Path $releasesDir "CAT_S22_Root_Tool_Portable.zip"
Compress-Archive -Path "$baseDir\build\*" -DestinationPath $portableZip -Force
$portableSize = [math]::Round((Get-Item $portableZip).Length / 1MB, 1)
Write-Host "      Created: CAT_S22_Root_Tool_Portable.zip ($portableSize MB)" -ForegroundColor Green

# 2. Create Scripts-only package
Write-Host "[2/2] Creating CAT_S22_Root_Tool_Scripts.zip..." -ForegroundColor Yellow
$scriptsTemp = Join-Path $releasesDir "scripts_temp"
New-Item -ItemType Directory -Path $scriptsTemp -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $scriptsTemp "boot_images") -Force | Out-Null

# Copy only scripts and resources (no EXE, no build artifacts)
Copy-Item (Join-Path $baseDir "CAT_S22_Root_Tool.ps1") $scriptsTemp
Copy-Item (Join-Path $baseDir "CAT_S22_Enhanced_Debloat.ps1") $scriptsTemp
Copy-Item (Join-Path $baseDir "boot_images\boot_v30.img") (Join-Path $scriptsTemp "boot_images")
Copy-Item (Join-Path $baseDir "Magisk-v25.2.apk") $scriptsTemp

$scriptsZip = Join-Path $releasesDir "CAT_S22_Root_Tool_Scripts.zip"
Compress-Archive -Path "$scriptsTemp\*" -DestinationPath $scriptsZip -Force
$scriptsSize = [math]::Round((Get-Item $scriptsZip).Length / 1MB, 1)
Write-Host "      Created: CAT_S22_Root_Tool_Scripts.zip ($scriptsSize MB)" -ForegroundColor Green

# Cleanup temp
Remove-Item $scriptsTemp -Recurse -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Release Packages Ready!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Packages in: $releasesDir" -ForegroundColor Cyan
Write-Host ""
Get-ChildItem $releasesDir -Filter "*.zip" | ForEach-Object {
    $size = [math]::Round($_.Length / 1MB, 1)
    Write-Host "  - $($_.Name) ($size MB)" -ForegroundColor White
}
Write-Host ""
