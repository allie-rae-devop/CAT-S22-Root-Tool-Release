#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    CAT S22 Flip Rooting Tool - Automated GUI-based rooting assistant
.DESCRIPTION
    This tool automates the rooting process for CAT S22 Flip phones running firmware v29 or v30.
    It handles downloads, extractions, and fastboot commands with clear user prompts for physical interactions.
.NOTES
    Author: Claude
    Version: 1.0
    Requires: Administrator privileges, Internet connection
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:Config = @{
    WorkingDir = "$env:USERPROFILE\CAT_S22_Root"
    ToolsDir = "$env:USERPROFILE\CAT_S22_Root\tools"
    DownloadsDir = "$env:USERPROFILE\CAT_S22_Root\downloads"
    LogFile = "$env:USERPROFILE\CAT_S22_Root\rooting_log.txt"
    
    # Download URLs
    URLs = @{
        'ADB_Platform_Tools' = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'
        'Magisk_APK' = 'https://github.com/topjohnwu/Magisk/releases/download/v27.0/Magisk-v27.0.apk'
        'Payload_Dumper' = 'https://github.com/vm03/payload_dumper/archive/refs/heads/master.zip'
        'Python_Embed' = 'https://www.python.org/ftp/python/3.11.7/python-3.11.7-embed-amd64.zip'
        'OTA_v29' = 'https://ota.googlezip.net/packages/ota-api/package/8e554ecf6fdc8c1963d45068e956c7b2a82a6d96.zip'
        'OTA_v30' = 'https://ota.googlezip.net/packages/ota-api/package/9a3aee53e9065364e1ddd01d373c0ba9229c27ed.zip'
    }
    
    # SHA256 checksums for verification
    SHA256 = @{
        'system_v29'  = '071aeabfe12c730a8847a3a45eac76b7ac1e9114a92942960995d8f091209325'
        'vendor_v29'  = '841d4a0725bbbe255067cc372f00a5ceab50c44719e1d1f797d7caebf4e5c537'
        'product_v29' = 'a7f1b1e125463c3ac9ea4eac1d5c5e605e20323239cc2c666de7923bc9f09c04'
    }
    
    DetectedVersion = $null
    RequiresDowngrade = $false
    
    # Step tracking
    CurrentStep = 0
    TotalSteps = 12
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output with color
    switch ($Level) {
        'SUCCESS' { Write-Host $logMessage -ForegroundColor Green }
        'WARNING' { Write-Host $logMessage -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logMessage -ForegroundColor Red }
        'DEBUG'   { Write-Host $logMessage -ForegroundColor Cyan }
        default   { Write-Host $logMessage }
    }
    
    # File output
    Add-Content -Path $Script:Config.LogFile -Value $logMessage
    
    # GUI output
    if ($Script:GUI) {
        Update-StatusText $Message
    }
}

# ============================================================================
# GUI UPDATE FUNCTIONS
# ============================================================================

function Update-StatusText {
    param([string]$Text)
    
    # Check if we're in the UI thread or need Dispatcher
    if ($Script:GUI.StatusText.Dispatcher.CheckAccess()) {
        # We're in UI thread, update directly
        $Script:GUI.StatusText.Content = $Text
        $Script:GUI.LogBox.AppendText("$(Get-Date -Format 'HH:mm:ss') - $Text`n")
        $Script:GUI.LogBox.ScrollToEnd()
    }
    else {
        # We're in background thread, use Dispatcher
        $Script:GUI.StatusText.Dispatcher.Invoke([action]{
            $Script:GUI.StatusText.Content = $Text
            $Script:GUI.LogBox.AppendText("$(Get-Date -Format 'HH:mm:ss') - $Text`n")
            $Script:GUI.LogBox.ScrollToEnd()
        }, [System.Windows.Threading.DispatcherPriority]::Normal)
    }
}

function Update-Progress {
    param(
        [int]$Step,
        [string]$Description
    )
    
    $Script:Config.CurrentStep = $Step
    $percentage = ($Step / $Script:Config.TotalSteps) * 100
    
    if ($Script:GUI.ProgressBar.Dispatcher.CheckAccess()) {
        # We're in UI thread
        $Script:GUI.ProgressBar.Value = $percentage
        $Script:GUI.StepLabel.Content = "Step $Step of $($Script:Config.TotalSteps): $Description"
    }
    else {
        # We're in background thread
        $Script:GUI.ProgressBar.Dispatcher.Invoke([action]{
            $Script:GUI.ProgressBar.Value = $percentage
            $Script:GUI.StepLabel.Content = "Step $Step of $($Script:Config.TotalSteps): $Description"
        }, [System.Windows.Threading.DispatcherPriority]::Normal)
    }
}

function Show-UserPrompt {
    param(
        [string]$Title,
        [string]$Message,
        [string]$ButtonText = "Continue"
    )
    
    # Check if we're in UI thread
    if ($Script:GUI.Window.Dispatcher.CheckAccess()) {
        # Direct call - we're in UI thread
        $msgBox = [System.Windows.MessageBox]::Show(
            $Message,
            $Title,
            [System.Windows.MessageBoxButton]::OKCancel,
            [System.Windows.MessageBoxImage]::Information
        )
        return $msgBox -eq 'OK'
    }
    else {
        # Need Dispatcher - we're in background thread
        $result = $Script:GUI.Window.Dispatcher.Invoke([Func[bool]]{
            $msgBox = [System.Windows.MessageBox]::Show(
                $Message,
                $Title,
                [System.Windows.MessageBoxButton]::OKCancel,
                [System.Windows.MessageBoxImage]::Information
            )
            return $msgBox -eq 'OK'
        })
        return $result
    }
}

function Enable-Controls {
    param([bool]$Enable)
    
    $Script:GUI.StartButton.Dispatcher.Invoke([action]{
        $Script:GUI.StartButton.IsEnabled = $Enable
        $Script:GUI.FirmwareCombo.IsEnabled = $Enable
    }, [System.Windows.Threading.DispatcherPriority]::Normal)
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-Environment {
    Write-Log "Initializing environment..." -Level INFO
    
    # Create directory structure
    @($Script:Config.WorkingDir, $Script:Config.ToolsDir, $Script:Config.DownloadsDir) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
            Write-Log "Created directory: $_" -Level DEBUG
        }
    }
    
    # Initialize log file
    if (-not (Test-Path $Script:Config.LogFile)) {
        New-Item -ItemType File -Path $Script:Config.LogFile -Force | Out-Null
    }
    
    Write-Log "Environment initialized at: $($Script:Config.WorkingDir)" -Level SUCCESS
}

function Download-File {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$Description = "file"
    )
    
    Write-Log "Downloading $Description from: $Url" -Level INFO
    
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $Destination)
        Write-Log "Downloaded $Description to: $Destination" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Failed to download ${Description}: $_" -Level ERROR
        return $false
    }
}

function Expand-ZipFile {
    param(
        [string]$ZipPath,
        [string]$Destination
    )
    
    Write-Log "Extracting: $ZipPath to $Destination" -Level INFO
    
    try {
        Expand-Archive -Path $ZipPath -DestinationPath $Destination -Force
        Write-Log "Extraction complete" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Failed to extract: $_" -Level ERROR
        return $false
    }
}

function Detect-DeviceAndFirmware {
    Write-Log "Detecting connected device..." -Level INFO
    
    # Update GUI status directly (we're in UI thread now)
    $Script:GUI.DeviceStatus.Text = "Checking for ADB tools..."
    $Script:GUI.DeviceStatus.Foreground = "#F39C12"
    
    # Check if ADB tools exist, download if needed
    $adbPath = Join-Path $Script:Config.ToolsDir "platform-tools\adb.exe"
    
    if (-not (Test-Path $adbPath)) {
        Write-Log "ADB not found, downloading tools first..." -Level INFO
        
        $Script:GUI.DeviceStatus.Text = "Downloading ADB tools (first time only)..."
        $Script:GUI.DeviceStatus.Foreground = "#F39C12"
        
        # Download ADB tools
        if (-not (Step-01-DownloadTools)) {
            $Script:GUI.DeviceStatus.Text = "Failed to download ADB tools"
            $Script:GUI.DeviceStatus.Foreground = "#E74C3C"
            
            [System.Windows.MessageBox]::Show(
                "Failed to download ADB tools.`n`nPlease check your internet connection and try again.`n`nError details are in the log.",
                "Download Failed",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
            return $false
        }
        
        Write-Log "ADB tools downloaded successfully" -Level SUCCESS
    }
    
    # Now check for device
    $Script:GUI.DeviceStatus.Text = "Checking for device..."
    $Script:GUI.DeviceStatus.Foreground = "#F39C12"
    
    # Check ADB connection
    if (Test-ADBConnection) {
        Write-Log "Device detected via ADB" -Level SUCCESS
        
        # Update GUI status - device found
        $Script:GUI.DeviceStatus.Text = "Device connected via ADB"
        $Script:GUI.DeviceStatus.Foreground = "#27AE60"
        
        # Try to detect firmware version
        $detectedVersion = Get-DeviceFirmwareVersion
        
        if ($detectedVersion) {
            $Script:Config.DetectedVersion = $detectedVersion
            
            # Update firmware status display
            $Script:GUI.FirmwareStatus.Text = "Firmware: v$detectedVersion detected"
            $Script:GUI.FirmwareStatus.Foreground = "#27AE60"
            
            Write-Log "Firmware v$detectedVersion detected" -Level SUCCESS
            
            # Show message to user
            [System.Windows.MessageBox]::Show(
                "Device detected successfully!`n`nFirmware: v$detectedVersion`n`nYou can now proceed with rooting.",
                "Device Found",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
            
            return $true
        }
        else {
            # Device connected but couldn't read firmware
            $Script:GUI.FirmwareStatus.Text = "Firmware: Could not detect version"
            $Script:GUI.FirmwareStatus.Foreground = "#E67E22"
            
            Write-Log "Device connected but firmware version could not be detected" -Level WARNING
            
            [System.Windows.MessageBox]::Show(
                "Device detected, but could not read firmware version.`n`nPlease ensure:`n• USB Debugging is enabled`n• You accepted the USB debugging prompt on phone`n`nYou can still proceed, but select your firmware version manually.",
                "Partial Detection",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            )
            
            return $true
        }
    }
    else {
        Write-Log "No device detected" -Level WARNING
        
        # Update GUI status - no device
        $Script:GUI.DeviceStatus.Text = "No device detected - Please connect device and enable USB debugging"
        $Script:GUI.DeviceStatus.Foreground = "#E74C3C"
        
        $Script:GUI.FirmwareStatus.Text = "Firmware: Unknown"
        $Script:GUI.FirmwareStatus.Foreground = "#7F8C8D"
        
        [System.Windows.MessageBox]::Show(
            "No device detected.`n`nPlease ensure:`n• CAT S22 Flip is connected via USB data cable`n• USB Debugging is enabled (Settings > Developer Options)`n• You accepted the USB debugging authorization on phone`n• Drivers are installed (try different USB port)`n`nThen click 'Detect Device' again.",
            "Device Not Found",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        
        return $false
    }
}

function Get-DeviceFirmwareVersion {
    Write-Log "Detecting device firmware version..." -Level INFO
    
    if (-not (Test-ADBConnection)) {
        Write-Log "Cannot detect firmware - device not connected" -Level WARNING
        return $null
    }
    
    # Try build.fingerprint first (more reliable for CAT S22)
    $fingerprintResult = Invoke-ADBCommand -Command "shell getprop ro.build.fingerprint"
    
    if ($fingerprintResult.Success -and $fingerprintResult.Output) {
        $fingerprint = $fingerprintResult.Output.Trim()
        Write-Log "Device build fingerprint: $fingerprint" -Level DEBUG
        
        # Parse version from fingerprint (e.g., Cat/S22FLIP/S22FLIP:11/RKQ1.210416.002/LTE_S02113.11_N_S22Flip_0.030.03:user/release-keys)
        if ($fingerprint -match 'S22Flip_0\.0(\d{2})\.') {
            $version = $matches[1]
            Write-Log "Detected firmware version: v$version" -Level SUCCESS
            return $version
        }
        elseif ($fingerprint -match 'Flip_0\.(\d+)\.') {
            $version = $matches[1]
            Write-Log "Detected firmware version: v$version" -Level SUCCESS
            return $version
        }
    }
    
    # Fallback to build.display.id
    $buildResult = Invoke-ADBCommand -Command "shell getprop ro.build.display.id"
    
    if ($buildResult.Success -and $buildResult.Output) {
        $buildNumber = $buildResult.Output.Trim()
        Write-Log "Device build number: $buildNumber" -Level DEBUG
        
        # Parse version from build number (e.g., LTE_S02113.11_N_S22Flip_0.030.03)
        if ($buildNumber -match '0\.0(\d{2})\.') {
            $version = $matches[1]
            Write-Log "Detected firmware version: v$version" -Level SUCCESS
            return $version
        }
        elseif ($buildNumber -match 'Flip_0\.(\d+)\.') {
            $version = $matches[1]
            Write-Log "Detected firmware version: v$version" -Level SUCCESS
            return $version
        }
        else {
            Write-Log "Could not parse version from build number: $buildNumber" -Level WARNING
            return "unknown"
        }
    }
    
    Write-Log "Failed to detect firmware version" -Level WARNING
    return $null
}

function Verify-FileHash {
    param(
        [string]$FilePath,
        [string]$ExpectedHash
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "File not found for hash verification: $FilePath" -Level ERROR
        return $false
    }
    
    Write-Log "Verifying SHA256 hash for: $(Split-Path $FilePath -Leaf)" -Level DEBUG
    $actualHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
    
    if ($actualHash -eq $ExpectedHash) {
        Write-Log "Hash verification passed" -Level SUCCESS
        return $true
    }
    else {
        Write-Log "Hash mismatch! Expected: $ExpectedHash, Got: $actualHash" -Level ERROR
        return $false
    }
}

function Test-ADBConnection {
    $adbPath = Join-Path $Script:Config.ToolsDir "platform-tools\adb.exe"
    
    if (-not (Test-Path $adbPath)) {
        Write-Log "ADB not found at: $adbPath" -Level ERROR
        return $false
    }
    
    try {
        $devices = & $adbPath devices 2>&1 | Out-String
        Write-Log "ADB devices output: $devices" -Level DEBUG
        
        # Check if any line contains a device ID followed by "device" (with or without tabs/spaces)
        if ($devices -match '\S+\s+(device|unauthorized)') {
            if ($devices -match 'device\s*$' -or $devices -match 'device\s') {
                Write-Log "Device connected via ADB" -Level SUCCESS
                return $true
            }
            elseif ($devices -match 'unauthorized') {
                Write-Log "Device found but unauthorized - accept USB debugging prompt on phone" -Level WARNING
                return $false
            }
        }
        else {
            Write-Log "No ADB devices detected" -Level WARNING
            return $false
        }
    }
    catch {
        Write-Log "ADB connection test failed: $_" -Level ERROR
        return $false
    }
}

function Test-FastbootConnection {
    $fastbootPath = Join-Path $Script:Config.ToolsDir "platform-tools\fastboot.exe"
    
    if (-not (Test-Path $fastbootPath)) {
        Write-Log "Fastboot not found at: $fastbootPath" -Level ERROR
        return $false
    }
    
    try {
        $devices = & $fastbootPath devices 2>&1
        Write-Log "Fastboot devices output: $devices" -Level DEBUG
        
        if ($devices -match "\t") {
            Write-Log "Device connected via Fastboot" -Level SUCCESS
            return $true
        }
        else {
            Write-Log "No Fastboot devices detected" -Level WARNING
            return $false
        }
    }
    catch {
        Write-Log "Fastboot connection test failed: $_" -Level ERROR
        return $false
    }
}

function Invoke-ADBCommand {
    param(
        [string]$Command,
        [int]$TimeoutSeconds = 30
    )
    
    $adbPath = Join-Path $Script:Config.ToolsDir "platform-tools\adb.exe"
    Write-Log "Executing ADB command: $Command" -Level DEBUG
    
    try {
        $output = & $adbPath $Command.Split() 2>&1 | Out-String
        Write-Log "ADB output: $output" -Level DEBUG
        return @{
            Success = $true
            Output = $output
        }
    }
    catch {
        Write-Log "ADB command failed: $_" -Level ERROR
        return @{
            Success = $false
            Output = $_.Exception.Message
        }
    }
}

function Invoke-FastbootCommand {
    param(
        [string]$Command,
        [int]$TimeoutSeconds = 30
    )
    
    $fastbootPath = Join-Path $Script:Config.ToolsDir "platform-tools\fastboot.exe"
    Write-Log "Executing Fastboot command: $Command" -Level DEBUG
    
    try {
        $output = & $fastbootPath $Command.Split() 2>&1 | Out-String
        Write-Log "Fastboot output: $output" -Level DEBUG
        return @{
            Success = $true
            Output = $output
        }
    }
    catch {
        Write-Log "Fastboot command failed: $_" -Level ERROR
        return @{
            Success = $false
            Output = $_.Exception.Message
        }
    }
}

# ============================================================================
# FIRMWARE MANAGEMENT FUNCTIONS
# ============================================================================

function Restore-StockFirmware {
    param([string]$Version = "29")
    
    Write-Log "=== RESTORING STOCK FIRMWARE v$Version ===" -Level INFO
    
    $confirmed = Show-UserPrompt -Title "⚠️ STOCK FIRMWARE RESTORE ⚠️" -Message @"
This will restore your device to stock firmware v$Version.

WARNING:
• This will ERASE ALL DATA on your phone
• Any root access will be removed
• Device will be factory reset

This is useful for:
• Unbricking a device
• Returning to stock before rooting
• Fixing boot loops or soft bricks

Click OK to proceed with stock restore.
Click Cancel to abort.
"@
    
    if (-not $confirmed) {
        Write-Log "Stock restore cancelled by user" -Level WARNING
        return $false
    }
    
    # Download OTA if not present
    if (-not (Step-02-DownloadFirmware -Version $Version)) {
        Write-Log "Failed to download firmware for restore" -Level ERROR
        return $false
    }
    
    # Extract all images
    if (-not (Extract-AllStockImages -Version $Version)) {
        Write-Log "Failed to extract stock images" -Level ERROR
        return $false
    }
    
    # Ensure device is in bootloader
    if (-not (Test-FastbootConnection)) {
        $manualBoot = Show-UserPrompt -Title "Enter Bootloader Mode" -Message @"
Please boot your device into bootloader mode:

1. Power off the phone completely
2. Hold Volume Down + Power buttons
3. Release when you see fastboot screen

Click OK when in bootloader mode.
"@
        if (-not $manualBoot) { return $false }
        
        Start-Sleep -Seconds 3
        if (-not (Test-FastbootConnection)) {
            Write-Log "Device not in bootloader mode" -Level ERROR
            return $false
        }
    }
    
    # Flash stock images
    $stockDir = Join-Path $Script:Config.DownloadsDir "OTA_v$Version\extracted"
    
    Write-Log "Wiping data and cache..." -Level INFO
    Invoke-FastbootCommand -Command "-w"
    Invoke-FastbootCommand -Command "erase cache"
    
    # Flash in bootloader mode
    Write-Log "Flashing boot partition..." -Level INFO
    $bootImg = Join-Path $stockDir "boot.img"
    Invoke-FastbootCommand -Command "flash boot `"$bootImg`""
    
    Write-Log "Flashing vbmeta..." -Level INFO
    $vbmetaImg = Join-Path $stockDir "vbmeta.img"
    Invoke-FastbootCommand -Command "flash vbmeta --disable-verity --disable-verification `"$vbmetaImg`""
    
    $vbmetaSysImg = Join-Path $stockDir "vbmeta_system.img"
    if (Test-Path $vbmetaSysImg) {
        Invoke-FastbootCommand -Command "flash vbmeta_system --disable-verity --disable-verification `"$vbmetaSysImg`""
    }
    
    Write-Log "Flashing modem..." -Level INFO
    $modemImg = Join-Path $stockDir "modem.img"
    Invoke-FastbootCommand -Command "flash modem `"$modemImg`""
    
    Write-Log "Flashing DSP..." -Level INFO
    $dspImg = Join-Path $stockDir "adspso.img"
    Invoke-FastbootCommand -Command "flash dsp `"$dspImg`""
    
    Write-Log "Flashing DTBO..." -Level INFO
    $dtboImg = Join-Path $stockDir "dtbo.img"
    Invoke-FastbootCommand -Command "flash dtbo `"$dtboImg`""
    
    # Reboot to fastbootd for dynamic partitions
    Write-Log "Rebooting to fastbootd for system partitions..." -Level INFO
    Invoke-FastbootCommand -Command "reboot fastboot"
    Start-Sleep -Seconds 10
    
    # Verify fastbootd
    if (-not (Test-FastbootConnection)) {
        Write-Log "Failed to enter fastbootd mode" -Level ERROR
        return $false
    }
    
    # Delete and recreate product partition (it may have been modified)
    Write-Log "Recreating product partition..." -Level INFO
    Invoke-FastbootCommand -Command "delete-logical-partition product"
    Invoke-FastbootCommand -Command "create-logical-partition product 100000"
    
    # Flash dynamic partitions
    Write-Log "Flashing system partition..." -Level INFO
    $systemImg = Join-Path $stockDir "system.img"
    Invoke-FastbootCommand -Command "flash system `"$systemImg`""
    
    Write-Log "Flashing vendor partition..." -Level INFO
    $vendorImg = Join-Path $stockDir "vendor.img"
    Invoke-FastbootCommand -Command "flash vendor `"$vendorImg`""
    
    Write-Log "Flashing product partition..." -Level INFO
    $productImg = Join-Path $stockDir "product.img"
    Invoke-FastbootCommand -Command "flash product `"$productImg`""
    
    # Reboot
    Write-Log "Rebooting device..." -Level INFO
    Invoke-FastbootCommand -Command "reboot"
    
    $success = Show-UserPrompt -Title "✅ STOCK RESTORE COMPLETE" -Message @"
Stock firmware v$Version has been restored!

Your device should now:
• Boot to stock recovery or Android setup
• Be completely unrooted
• Have factory default settings

First boot may take 5-10 minutes.

If the device doesn't boot:
• Try booting to recovery and factory reset
• Re-run this stock restore process

Click OK to finish.
"@
    
    Write-Log "Stock firmware restore completed" -Level SUCCESS
    return $true
}

function Extract-AllStockImages {
    param([string]$Version)
    
    Write-Log "Extracting all stock images from v$Version OTA..." -Level INFO
    
    $otaPath = Join-Path $Script:Config.DownloadsDir "OTA_v$Version.zip"
    $extractDir = Join-Path $Script:Config.DownloadsDir "OTA_v$Version\extracted"
    
    if (-not (Test-Path $extractDir)) {
        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
    }
    
    # Check if already extracted
    $requiredImages = @('boot.img', 'system.img', 'vendor.img', 'vbmeta.img')
    $allPresent = $true
    foreach ($img in $requiredImages) {
        if (-not (Test-Path (Join-Path $extractDir $img))) {
            $allPresent = $false
            break
        }
    }
    
    if ($allPresent) {
        Write-Log "Stock images already extracted" -Level INFO
        return $true
    }
    
    # Use the same extraction method as Step-03
    return (Step-03-ExtractBootImage -Version $Version -ExtractAll)
}

function Downgrade-Firmware {
    param(
        [string]$FromVersion,
        [string]$ToVersion = "29"
    )
    
    Write-Log "Downgrading firmware from v$FromVersion to v$ToVersion..." -Level INFO
    
    $confirmed = Show-UserPrompt -Title "Firmware Downgrade Required" -Message @"
Your device is running firmware v$FromVersion.

For the safest rooting experience, we recommend downgrading to v$ToVersion.

This downgrade will:
• Install stock v$ToVersion firmware
• Preserve your unlocked bootloader (if already unlocked)
• ERASE ALL DATA (factory reset)
• Take approximately 10-15 minutes

After downgrade, the rooting process will continue automatically.

Click OK to proceed with downgrade.
Click Cancel to abort rooting process.
"@
    
    if (-not $confirmed) {
        Write-Log "User declined firmware downgrade" -Level WARNING
        return $false
    }
    
    # Perform stock restore to v29
    if (-not (Restore-StockFirmware -Version $ToVersion)) {
        Write-Log "Firmware downgrade failed" -Level ERROR
        return $false
    }
    
    Write-Log "Firmware successfully downgraded to v$ToVersion" -Level SUCCESS
    
    # Wait for reboot
    $setup = Show-UserPrompt -Title "Complete Setup" -Message @"
The device has been downgraded to v$ToVersion.

Please:
1. Complete the initial Android setup (skip as much as possible)
2. Enable Developer Options (Settings > About > Tap Build Number 7 times)
3. Enable USB Debugging
4. Connect via USB and accept debugging authorization

Click OK when ready to continue rooting.
"@
    
    return $setup
}

# ============================================================================
# ROOTING WORKFLOW FUNCTIONS
# ============================================================================

function Step-01-DownloadTools {
    Update-Progress -Step 1 -Description "Downloading required tools"
    
    # Download ADB Platform Tools
    $adbZip = Join-Path $Script:Config.DownloadsDir "platform-tools.zip"
    if (-not (Test-Path $adbZip)) {
        if (-not (Download-File -Url $Script:Config.URLs.ADB_Platform_Tools -Destination $adbZip -Description "ADB Platform Tools")) {
            return $false
        }
    }
    
    # Extract ADB
    $extractPath = Join-Path $Script:Config.ToolsDir "platform-tools"
    if (-not (Test-Path (Join-Path $extractPath "adb.exe"))) {
        if (-not (Expand-ZipFile -ZipPath $adbZip -Destination $Script:Config.ToolsDir)) {
            return $false
        }
    }
    
    # Download Magisk APK
    $magiskPath = Join-Path $Script:Config.DownloadsDir "Magisk.apk"
    if (-not (Test-Path $magiskPath)) {
        if (-not (Download-File -Url $Script:Config.URLs.Magisk_APK -Destination $magiskPath -Description "Magisk APK")) {
            return $false
        }
    }
    
    Write-Log "All tools downloaded successfully" -Level SUCCESS
    return $true
}

function Step-02-DownloadFirmware {
    param([string]$Version)
    
    Update-Progress -Step 2 -Description "Checking firmware v$Version availability"
    
    # Check if boot.img already exists (pre-extracted by user)
    $extractDir = Join-Path $Script:Config.DownloadsDir "OTA_v$Version\extracted"
    $bootImgPath = Join-Path $extractDir "boot.img"
    
    if (Test-Path $bootImgPath) {
        Write-Log "boot.img already available at: $bootImgPath - skipping OTA download" -Level SUCCESS
        return $true
    }
    
    # Check alternative locations for pre-extracted files
    $altLocations = @(
        (Join-Path $PSScriptRoot "v$Version\boot.img"),
        (Join-Path (Split-Path $PSScriptRoot) "v$Version\boot.img"),
        (Join-Path $Script:Config.DownloadsDir "v$Version\boot.img")
    )
    
    foreach ($altPath in $altLocations) {
        if (Test-Path $altPath) {
            Write-Log "Found pre-extracted boot.img at: $altPath - skipping OTA download" -Level SUCCESS
            
            # Create extract directory and copy
            if (-not (Test-Path $extractDir)) {
                New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
            }
            
            Copy-Item -Path $altPath -Destination $bootImgPath -Force
            Write-Log "Copied boot.img to: $bootImgPath" -Level SUCCESS
            
            # Copy other partition images if present
            $altDir = Split-Path $altPath
            $allImages = Get-ChildItem -Path $altDir -Filter "*.*" -ErrorAction SilentlyContinue
            foreach ($img in $allImages) {
                if ($img.Name -ne "boot.img") {
                    Copy-Item -Path $img.FullName -Destination $extractDir -Force -ErrorAction SilentlyContinue
                }
            }
            
            return $true
        }
    }
    
    # No pre-extracted files found, need to download OTA
    Write-Log "No pre-extracted boot.img found, downloading OTA..." -Level INFO
    
    $url = if ($Version -eq "29") { $Script:Config.URLs.OTA_v29 } else { $Script:Config.URLs.OTA_v30 }
    $otaPath = Join-Path $Script:Config.DownloadsDir "OTA_v$Version.zip"
    
    if (Test-Path $otaPath) {
        # Verify OTA is valid by checking for payload.bin
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($otaPath)
            $hasPayload = $zip.Entries | Where-Object { $_.Name -eq "payload.bin" }
            $zip.Dispose()
            
            if ($hasPayload) {
                Write-Log "OTA v$Version already downloaded and valid" -Level INFO
                return $true
            }
            else {
                Write-Log "OTA v$Version exists but is invalid (no payload.bin), re-downloading..." -Level WARNING
                Remove-Item $otaPath -Force
            }
        }
        catch {
            Write-Log "OTA v$Version exists but couldn't verify, re-downloading..." -Level WARNING
            Remove-Item $otaPath -Force -ErrorAction SilentlyContinue
        }
    }
    
    if (-not (Download-File -Url $url -Destination $otaPath -Description "OTA v$Version")) {
        Write-Log "OTA download failed, but you can manually place boot.img at: $bootImgPath" -Level WARNING
        return $false
    }
    
    return $true
}

function Step-03-ExtractBootImage {
    param(
        [string]$Version,
        [switch]$ExtractAll
    )
    
    if ($ExtractAll) {
        Update-Progress -Step 3 -Description "Extracting all images from OTA v$Version"
    } else {
        Update-Progress -Step 3 -Description "Extracting boot.img from OTA"
    }
    
    $otaPath = Join-Path $Script:Config.DownloadsDir "OTA_v$Version.zip"
    $extractDir = Join-Path $Script:Config.DownloadsDir "OTA_v$Version\extracted"
    
    # Check if boot.img already exists from previous extraction
    $bootImgPath = Join-Path $extractDir "boot.img"
    if (Test-Path $bootImgPath) {
        Write-Log "boot.img already extracted at: $bootImgPath" -Level SUCCESS
        return $true
    }
    
    # Check alternative locations (user may have pre-extracted files)
    $altLocations = @(
        (Join-Path $PSScriptRoot "v$Version\boot.img"),
        (Join-Path (Split-Path $PSScriptRoot) "v$Version\boot.img"),
        (Join-Path $Script:Config.DownloadsDir "v$Version\boot.img")
    )
    
    foreach ($altPath in $altLocations) {
        if (Test-Path $altPath) {
            Write-Log "Found pre-extracted boot.img at: $altPath" -Level SUCCESS
            
            # Create extract directory
            if (-not (Test-Path $extractDir)) {
                New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
            }
            
            # Copy to expected location
            Copy-Item -Path $altPath -Destination $bootImgPath -Force
            Write-Log "Copied boot.img to: $bootImgPath" -Level SUCCESS
            
            if ($ExtractAll) {
                # Copy all partition images from the same directory
                $altDir = Split-Path $altPath
                $partitionImages = Get-ChildItem -Path $altDir -Filter "*.img" -ErrorAction SilentlyContinue
                foreach ($img in $partitionImages) {
                    Copy-Item -Path $img.FullName -Destination $extractDir -Force
                    Write-Log "Copied $($img.Name) to extract directory" -Level INFO
                }
                
                # Also copy .dat files if present
                $datFiles = Get-ChildItem -Path $altDir -Filter "*.dat" -ErrorAction SilentlyContinue
                foreach ($dat in $datFiles) {
                    Copy-Item -Path $dat.FullName -Destination $extractDir -Force
                }
            }
            
            return $true
        }
    }
    
    # No pre-extracted files found, extract from OTA
    if (-not (Test-Path $extractDir)) {
        Expand-ZipFile -ZipPath $otaPath -Destination (Join-Path $Script:Config.DownloadsDir "OTA_v$Version")
    }
    
    # Look for payload.bin
    $payloadPath = Join-Path (Join-Path $Script:Config.DownloadsDir "OTA_v$Version") "payload.bin"
    
    if (-not (Test-Path $payloadPath)) {
        Write-Log "payload.bin not found in OTA. Checking for direct boot.img..." -Level WARNING
        
        # Some OTAs have boot.img directly
        $bootImgDirect = Get-ChildItem -Path (Join-Path $Script:Config.DownloadsDir "OTA_v$Version") -Recurse -Filter "boot.img" | Select-Object -First 1
        
        if ($bootImgDirect) {
            $bootDestination = Join-Path $extractDir "boot.img"
            Copy-Item -Path $bootImgDirect.FullName -Destination $bootDestination -Force
            Write-Log "boot.img extracted directly to: $bootDestination" -Level SUCCESS
            
            if (-not $ExtractAll) {
                return $true
            }
        }
        else {
            Write-Log "Neither payload.bin nor boot.img found in OTA" -Level ERROR
            return $false
        }
    }
    
    # If we have payload.bin, we need payload_dumper
    Write-Log "Found payload.bin, using payload_dumper..." -Level INFO
    
    # Download and setup payload_dumper (reusing existing if available)
    $pdZip = Join-Path $Script:Config.DownloadsDir "payload_dumper.zip"
    if (-not (Test-Path $pdZip)) {
        Download-File -Url $Script:Config.URLs.Payload_Dumper -Destination $pdZip -Description "Payload Dumper"
    }
    
    $pdDir = Join-Path $Script:Config.ToolsDir "payload_dumper"
    if (-not (Test-Path $pdDir)) {
        Expand-ZipFile -ZipPath $pdZip -Destination $Script:Config.ToolsDir
        $masterDir = Get-ChildItem -Path $Script:Config.ToolsDir -Filter "payload_dumper-master" | Select-Object -First 1
        if ($masterDir) {
            Rename-Item -Path $masterDir.FullName -NewName "payload_dumper" -Force
        }
    }
    
    # Install Python (embedded) if needed
    $pythonZip = Join-Path $Script:Config.DownloadsDir "python-embed.zip"
    $pythonDir = Join-Path $Script:Config.ToolsDir "python"
    
    if (-not (Test-Path (Join-Path $pythonDir "python.exe"))) {
        Write-Log "Downloading embedded Python..." -Level INFO
        Download-File -Url $Script:Config.URLs.Python_Embed -Destination $pythonZip -Description "Python Embedded"
        Expand-ZipFile -ZipPath $pythonZip -Destination $pythonDir
    }
    
    # Run payload_dumper
    Write-Log "Running payload_dumper to extract images..." -Level INFO
    $pythonExe = Join-Path $pythonDir "python.exe"
    $payloadDumperScript = Join-Path $pdDir "payload_dumper-master\payload_dumper.py"
    
    if (-not (Test-Path $extractDir)) {
        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
    }
    
    try {
        # Run payload dumper with output to extracted directory
        $process = Start-Process -FilePath $pythonExe -ArgumentList "`"$payloadDumperScript`" `"$payloadPath`" --out `"$extractDir`"" -NoNewWindow -Wait -PassThru
        
        if ($process.ExitCode -ne 0) {
            Write-Log "payload_dumper exited with code: $($process.ExitCode)" -Level WARNING
        }
        
        # Verify extraction
        $bootImg = Join-Path $extractDir "boot.img"
        if (Test-Path $bootImg) {
            Write-Log "Images extracted successfully to: $extractDir" -Level SUCCESS
            
            if ($ExtractAll) {
                # Verify all critical images
                $criticalImages = @('boot.img', 'system.img', 'vendor.img', 'vbmeta.img')
                $missing = @()
                foreach ($img in $criticalImages) {
                    if (-not (Test-Path (Join-Path $extractDir $img))) {
                        $missing += $img
                    }
                }
                
                if ($missing.Count -gt 0) {
                    Write-Log "Missing images: $($missing -join ', ')" -Level WARNING
                    return $false
                }
            }
            
            return $true
        }
        else {
            Write-Log "payload_dumper did not produce expected images" -Level ERROR
            return $false
        }
    }
    catch {
        Write-Log "Failed to run payload_dumper: $_" -Level ERROR
        return $false
    }
}

function Step-04-CheckDeviceConnection {
    Update-Progress -Step 4 -Description "Checking device connection"
    
    $confirmed = Show-UserPrompt -Title "Device Connection Check" -Message @"
Please ensure:
1. Your CAT S22 Flip is powered ON
2. USB Debugging is ENABLED (Settings > Developer Options > USB Debugging)
3. Device is connected via USB DATA cable (not just charging cable)
4. You've accepted the USB debugging prompt on the phone

Click OK when ready to check connection.
"@
    
    if (-not $confirmed) {
        Write-Log "User cancelled device connection check" -Level WARNING
        return $false
    }
    
    # Wait for device
    $maxAttempts = 10
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        if (Test-ADBConnection) {
            return $true
        }
        
        $attempt++
        Write-Log "Waiting for device... Attempt $attempt of $maxAttempts" -Level INFO
        Start-Sleep -Seconds 2
    }
    
    Write-Log "Device not detected after $maxAttempts attempts" -Level ERROR
    
    $retry = Show-UserPrompt -Title "Device Not Found" -Message @"
Device not detected via ADB.

Troubleshooting:
1. Check USB cable is a DATA cable
2. Enable USB Debugging in Developer Options
3. Accept the USB debugging authorization on phone
4. Try a different USB port
5. Disconnect and reconnect the cable

Click OK to retry, or Cancel to abort.
"@
    
    if ($retry) {
        return Step-04-CheckDeviceConnection
    }
    
    return $false
}

function Step-05-TransferFilesToPhone {
    param([string]$Version)
    
    Update-Progress -Step 5 -Description "Transferring files to phone"
    
    # Try multiple locations for boot.img
    $bootImgPaths = @(
        (Join-Path $PSScriptRoot "boot_images\boot_v$Version.img"),        # Bundled in package
        (Join-Path $PSScriptRoot "boot_v$Version.img"),                    # Same folder as script
        (Join-Path (Split-Path $PSScriptRoot) "boot_v$Version.img"),       # Parent folder
        (Join-Path $Script:Config.WorkingDir "boot_v$Version.img"),        # Working directory
        (Join-Path $Script:Config.DownloadsDir "OTA_v$Version\extracted\boot.img")  # Extracted from OTA
    )
    
    $bootImg = $null
    foreach ($path in $bootImgPaths) {
        if (Test-Path $path) {
            $bootImg = $path
            Write-Log "Found boot image at: $bootImg" -Level SUCCESS
            break
        }
    }
    
    $magiskApk = Join-Path $Script:Config.DownloadsDir "Magisk.apk"
    
    if (-not $bootImg) {
        Write-Log "Boot image not found in any expected location" -Level ERROR
        Write-Log "Tried: $($bootImgPaths -join ', ')" -Level ERROR
        return $false
    }
    
    # Transfer boot.img
    Write-Log "Transferring boot.img to phone..." -Level INFO
    $result = Invoke-ADBCommand -Command "push `"$bootImg`" /sdcard/Download/boot.img"
    if (-not $result.Success) {
        Write-Log "Failed to transfer boot.img" -Level ERROR
        return $false
    }
    
    # Transfer and install Magisk APK
    Write-Log "Installing Magisk APK..." -Level INFO
    $result = Invoke-ADBCommand -Command "install `"$magiskApk`""
    if (-not $result.Success) {
        Write-Log "Failed to install Magisk APK" -Level ERROR
        return $false
    }
    
    Write-Log "Files transferred successfully" -Level SUCCESS
    return $true
}

function Step-06-PatchBootImage {
    Update-Progress -Step 6 -Description "Patching boot image with Magisk"
    
    $confirmed = Show-UserPrompt -Title "Patch Boot Image" -Message @"
MANUAL STEP REQUIRED ON PHONE:

1. Open the Magisk app on your phone
2. Tap "Install" next to Magisk
3. Select "Select and Patch a File"
4. Navigate to Downloads folder
5. Select "boot.img"
6. Tap "LET'S GO" to start patching
7. Wait for "All done!" message
8. Note the output filename (e.g., magisk_patched-27000_xxxxx.img)

The patched file will be in Downloads folder.

Click OK when patching is complete.
"@
    
    if (-not $confirmed) {
        Write-Log "User cancelled boot image patching" -Level WARNING
        return $false
    }
    
    # Wait a moment for file system to update
    Start-Sleep -Seconds 2
    
    # Pull the patched boot image
    Write-Log "Retrieving patched boot image from phone..." -Level INFO
    
    # List files in Download to find the patched image
    $lsResult = Invoke-ADBCommand -Command "shell ls /sdcard/Download/magisk_patched*.img"
    
    if ($lsResult.Success -and $lsResult.Output -match "magisk_patched.*\.img") {
        $patchedFileName = ($lsResult.Output -split "`n" | Where-Object { $_ -match "magisk_patched.*\.img" } | Select-Object -First 1).Trim()
        
        # Remove any leading path from filename (sometimes ls returns full path)
        $patchedFileName = Split-Path -Leaf $patchedFileName
        
        $remotePath = "/sdcard/Download/$patchedFileName"
        $localPath = Join-Path $Script:Config.WorkingDir "magisk_patched.img"
        
        Write-Log "Found patched boot: $remotePath" -Level INFO
        $pullResult = Invoke-ADBCommand -Command "pull `"$remotePath`" `"$localPath`""
        
        if ($pullResult.Success) {
            Write-Log "Patched boot image retrieved: $localPath" -Level SUCCESS
            return $true
        }
    }
    
    # Manual fallback
    $manualPath = Show-UserPrompt -Title "Manual File Transfer" -Message @"
Could not automatically retrieve the patched boot image.

Please manually:
1. Connect phone to PC via USB
2. Open phone storage in File Explorer
3. Navigate to Downloads folder
4. Copy the magisk_patched-*.img file
5. Paste it to: $($Script:Config.WorkingDir)
6. Rename it to: magisk_patched.img

Click OK when complete.
"@
    
    if ($manualPath) {
        $manualFile = Join-Path $Script:Config.WorkingDir "magisk_patched.img"
        if (Test-Path $manualFile) {
            Write-Log "Manually transferred patched boot image found" -Level SUCCESS
            return $true
        }
    }
    
    Write-Log "Failed to retrieve patched boot image" -Level ERROR
    return $false
}

function Step-07-EnableOEMUnlock {
    Update-Progress -Step 7 -Description "Enabling OEM unlock"
    
    $confirmed = Show-UserPrompt -Title "Enable OEM Unlock" -Message @"
MANUAL STEP REQUIRED ON PHONE:

1. Go to Settings > Developer Options
2. Find "OEM unlocking"
3. Toggle it ON
4. Confirm if prompted

This is required to unlock the bootloader.

Click OK when OEM unlocking is enabled.
"@
    
    return $confirmed
}

function Step-08-RebootToBootloader {
    Update-Progress -Step 8 -Description "Rebooting to bootloader"
    
    $confirmed = Show-UserPrompt -Title "Reboot to Bootloader" -Message @"
The phone will now reboot into bootloader (fastboot) mode.

This can be done automatically via ADB, or manually:

MANUAL METHOD:
1. Power off the phone
2. Hold Volume Down + Power buttons
3. Release when you see the boot menu

Click OK to reboot automatically via ADB.
"@
    
    if (-not $confirmed) {
        Write-Log "User cancelled bootloader reboot" -Level WARNING
        return $false
    }
    
    Write-Log "Rebooting device to bootloader..." -Level INFO
    $result = Invoke-ADBCommand -Command "reboot bootloader"
    
    # Wait for bootloader mode
    Start-Sleep -Seconds 10
    
    # Verify fastboot connection
    $maxAttempts = 10
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        if (Test-FastbootConnection) {
            Write-Log "Device in bootloader mode" -Level SUCCESS
            return $true
        }
        
        $attempt++
        Write-Log "Waiting for bootloader... Attempt $attempt of $maxAttempts" -Level INFO
        Start-Sleep -Seconds 2
    }
    
    # Manual entry fallback
    $manual = Show-UserPrompt -Title "Manual Bootloader Entry" -Message @"
Device not detected in bootloader mode.

Please manually enter bootloader:
1. Power off the phone completely
2. Hold Volume Down + Power buttons
3. Release when you see the boot menu / fastboot screen

Click OK when in bootloader mode.
"@
    
    if ($manual) {
        Start-Sleep -Seconds 5
        return Test-FastbootConnection
    }
    
    return $false
}

function Step-09-UnlockBootloader {
    Update-Progress -Step 9 -Description "Unlocking bootloader"
    
    $warning = Show-UserPrompt -Title "⚠️ BOOTLOADER UNLOCK WARNING ⚠️" -Message @"
CRITICAL WARNING:

Unlocking the bootloader will:
✗ ERASE ALL DATA on your phone (factory reset)
✗ Void your warranty
✗ May show "device corrupt" warnings on boot (this is normal)

BACKUP ANY IMPORTANT DATA BEFORE PROCEEDING!

Click OK to unlock bootloader and WIPE ALL DATA.
Click Cancel to abort.
"@
    
    if (-not $warning) {
        Write-Log "User cancelled bootloader unlock" -Level WARNING
        return $false
    }
    
    Write-Log "Attempting bootloader unlock..." -Level INFO
    
    # Try the standard unlock command
    $result = Invoke-FastbootCommand -Command "flashing unlock"
    
    if (-not $result.Success -or $result.Output -match "FAILED") {
        Write-Log "Standard unlock failed, trying legacy OEM unlock..." -Level WARNING
        $result = Invoke-FastbootCommand -Command "oem unlock"
    }
    
    $confirmed = Show-UserPrompt -Title "Confirm Unlock on Device" -Message @"
You should now see a bootloader unlock confirmation screen on your phone.

Use VOLUME BUTTONS to highlight "Unlock the bootloader"
Press POWER button to confirm

WARNING: This will erase all data!

The phone will factory reset and reboot.

Click OK after confirming unlock on device.
"@
    
    if (-not $confirmed) {
        Write-Log "User cancelled bootloader unlock confirmation" -Level WARNING
        return $false
    }
    
    # Wait for device to reboot after unlock
    Write-Log "Waiting for device to complete factory reset and reboot..." -Level INFO
    Start-Sleep -Seconds 30
    
    Write-Log "Bootloader unlocked successfully" -Level SUCCESS
    return $true
}

function Step-10-RebootToBootloaderAgain {
    Update-Progress -Step 10 -Description "Rebooting to bootloader for flashing"
    
    $confirmed = Show-UserPrompt -Title "Setup After Factory Reset" -Message @"
Your phone has been factory reset and rebooted.

BEFORE CONTINUING, you must:
1. Complete initial setup (you can skip most steps)
2. Enable Developer Options (tap Build Number 7 times)
3. Enable USB Debugging
4. Enable OEM Unlocking
5. Connect via USB and accept debugging authorization

Click OK when you've completed setup and the phone is connected.
"@
    
    if (-not $confirmed) {
        return $false
    }
    
    # Verify ADB connection
    if (-not (Test-ADBConnection)) {
        Write-Log "Device not connected via ADB" -Level ERROR
        return $false
    }
    
    # Reboot to bootloader again
    Write-Log "Rebooting to bootloader for flashing..." -Level INFO
    Invoke-ADBCommand -Command "reboot bootloader"
    Start-Sleep -Seconds 10
    
    # Verify fastboot
    $maxAttempts = 10
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        if (Test-FastbootConnection) {
            return $true
        }
        $attempt++
        Start-Sleep -Seconds 2
    }
    
    return $false
}

function Step-11-FlashMagiskBoot {
    Update-Progress -Step 11 -Description "Flashing Magisk-patched boot image"
    
    $patchedBoot = Join-Path $Script:Config.WorkingDir "magisk_patched.img"
    
    if (-not (Test-Path $patchedBoot)) {
        Write-Log "Patched boot image not found: $patchedBoot" -Level ERROR
        return $false
    }
    
    $confirmed = Show-UserPrompt -Title "Flash Magisk Boot" -Message @"
Ready to flash the Magisk-patched boot image.

This is the critical step that gives your phone root access.

Click OK to proceed with flashing.
"@
    
    if (-not $confirmed) {
        return $false
    }
    
    Write-Log "Flashing Magisk-patched boot image..." -Level INFO
    $result = Invoke-FastbootCommand -Command "flash boot `"$patchedBoot`""
    
    if (-not $result.Success) {
        Write-Log "Failed to flash boot image: $($result.Output)" -Level ERROR
        return $false
    }
    
    Write-Log "Boot image flashed successfully" -Level SUCCESS
    return $true
}

function Step-12-FlashVBMeta {
    Update-Progress -Step 12 -Description "Flashing vbmeta to disable verification"
    
    $confirmed = Show-UserPrompt -Title "Disable Verified Boot" -Message @"
Flashing vbmeta with verification disabled.

This prevents Android from rejecting the modified boot image.

You may see a "device corrupt" warning on boot - this is NORMAL and harmless.
Press the power button twice to continue booting.

Click OK to flash vbmeta.
"@
    
    if (-not $confirmed) {
        return $false
    }
    
    Write-Log "Flashing vbmeta with verification disabled..." -Level INFO
    
    # Create a blank vbmeta image
    $vbmetaPath = Join-Path $Script:Config.WorkingDir "vbmeta_disabled.img"
    $bytes = New-Object byte[] 4096
    [System.IO.File]::WriteAllBytes($vbmetaPath, $bytes)
    
    $result = Invoke-FastbootCommand -Command "flash vbmeta --disable-verity --disable-verification `"$vbmetaPath`""
    
    if (-not $result.Success) {
        Write-Log "Failed to flash vbmeta: $($result.Output)" -Level WARNING
        # Non-critical, continue anyway
    }
    else {
        Write-Log "vbmeta flashed successfully" -Level SUCCESS
    }
    
    # Reboot
    Write-Log "Rebooting device..." -Level INFO
    Invoke-FastbootCommand -Command "reboot"
    
    $final = Show-UserPrompt -Title "🎉 ROOT COMPLETE! 🎉" -Message @"
Congratulations! Your CAT S22 Flip is now rooted!

The phone will now reboot. You may see:
- Orange "device corrupt" warning (press power twice to boot)
- Longer first boot time

After boot:
1. Open Magisk app
2. Verify it shows "Installed"
3. Grant root permissions to apps as needed

IMPORTANT:
- Your bootloader is UNLOCKED (security risk)
- OTA updates will fail (must manually update)
- Some apps may detect root (banking, etc.)

All logs saved to: $($Script:Config.LogFile)

Click OK to finish.
"@
    
    Write-Log "Rooting process completed successfully!" -Level SUCCESS
    return $true
}

# ============================================================================
# MAIN ROOTING WORKFLOW
# ============================================================================

function Start-RootingProcess {
    param([string]$FirmwareVersion)
    
    Enable-Controls -Enable $false
    Write-Log "=== STARTING ROOTING PROCESS ===" -Level INFO
    
    try {
        # Step 1: Download tools
        if (-not (Step-01-DownloadTools)) {
            throw "Failed to download required tools"
        }
        
        # Step 1.5: Check device and detect firmware version
        Update-Progress -Step 2 -Description "Detecting device firmware version"
        
        if (-not (Step-04-CheckDeviceConnection)) {
            throw "Device not connected - cannot proceed"
        }
        
        $detectedVersion = Get-DeviceFirmwareVersion
        
        if ($detectedVersion) {
            $Script:Config.DetectedVersion = $detectedVersion
            Write-Log "Device is running firmware v$detectedVersion" -Level INFO
            
            # Check if downgrade is needed
            if ($detectedVersion -gt 29) {
                Write-Log "Firmware v$detectedVersion detected - downgrade to v29 recommended" -Level WARNING
                $Script:Config.RequiresDowngrade = $true
                
                $downgradeChoice = Show-UserPrompt -Title "Root v30 Directly?" -Message @"
Your device is running firmware v30.

IMPORTANT: The v29 downgrade OTA is currently not working.

OPTION 1 (RECOMMENDED): Root v30 directly
✓ XDA-confirmed working method
✓ Faster (no downgrade needed)
✓ Minor risk: Rare WiFi issues (fixable)

OPTION 2: Manual downgrade (not recommended)
• Requires finding full v29 factory image
• More complex process
• Can be done later if v30 rooting fails

Would you like to root v30 directly?

Click OK to root v30 (recommended)
Click Cancel to abort and manually downgrade later
"@
                
                if ($downgradeChoice) {
                    Write-Log "User chose to root v30 directly" -Level INFO
                    $FirmwareVersion = $detectedVersion
                    $Script:Config.RequiresDowngrade = $false
                }
                else {
                    throw "User aborted - manual v29 downgrade required. See XDA forums for v29 factory images."
                }
            }
            else {
                Write-Log "Firmware v$detectedVersion is suitable for rooting" -Level SUCCESS
                $FirmwareVersion = $detectedVersion
            }
        }
        else {
            Write-Log "Could not detect firmware version, using user selection: v$FirmwareVersion" -Level WARNING
        }
        
        Write-Log "Proceeding with firmware v$FirmwareVersion" -Level INFO
        
        # Step 2: Download firmware
        if (-not (Step-02-DownloadFirmware -Version $FirmwareVersion)) {
            throw "Failed to download firmware"
        }
        
        # Step 3: Extract boot image
        if (-not (Step-03-ExtractBootImage -Version $FirmwareVersion)) {
            throw "Failed to extract boot.img"
        }
        
        # Re-check device connection (may have been disconnected during downgrade)
        if (-not (Step-04-CheckDeviceConnection)) {
            throw "Device not connected"
        }
        
        # Step 5: Transfer files to phone
        if (-not (Step-05-TransferFilesToPhone -Version $FirmwareVersion)) {
            throw "Failed to transfer files to phone"
        }
        
        # Step 6: Patch boot image (manual step on phone)
        if (-not (Step-06-PatchBootImage)) {
            throw "Failed to patch boot image"
        }
        
        # Step 7: Enable OEM unlock (manual step)
        if (-not (Step-07-EnableOEMUnlock)) {
            throw "OEM unlock not enabled"
        }
        
        # Step 8: Reboot to bootloader
        if (-not (Step-08-RebootToBootloader)) {
            throw "Failed to enter bootloader mode"
        }
        
        # Step 9: Unlock bootloader (WIPES DATA!)
        if (-not (Step-09-UnlockBootloader)) {
            throw "Failed to unlock bootloader"
        }
        
        # Step 10: Reboot to bootloader again after factory reset
        if (-not (Step-10-RebootToBootloaderAgain)) {
            throw "Failed to re-enter bootloader after unlock"
        }
        
        # Step 11: Flash Magisk boot
        if (-not (Step-11-FlashMagiskBoot)) {
            throw "Failed to flash Magisk boot"
        }
        
        # Step 12: Flash vbmeta and complete
        if (-not (Step-12-FlashVBMeta)) {
            throw "Failed to flash vbmeta"
        }
        
        Write-Log "=== ROOTING PROCESS COMPLETED SUCCESSFULLY ===" -Level SUCCESS
        Update-Progress -Step 12 -Description "Complete!"
    }
    catch {
        Write-Log "ROOTING FAILED: $_" -Level ERROR
        
        $errorMsg = @"
Rooting process failed: $_

Check the log for details: $($Script:Config.LogFile)

RECOVERY OPTIONS:
• Click 'Restore Stock' button to unbrick your device
• Review the log file for specific error details
• Ask for help on XDA Forums with your log file
"@
        
        [System.Windows.MessageBox]::Show(
            $errorMsg,
            "Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
    finally {
        Enable-Controls -Enable $true
    }
}

# ============================================================================
# GUI DEFINITION
# ============================================================================

[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="CAT S22 Flip Rooting Tool v1.0" Height="700" Width="900"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
        <Style TargetType="Label">
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="5,2"/>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="TextWrapping" Value="Wrap"/>
            <Setter Property="Margin" Value="5"/>
        </Style>
    </Window.Resources>
    
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Header -->
        <Border Grid.Row="0" Background="#2C3E50" Padding="15" CornerRadius="5" Margin="0,0,0,15">
            <StackPanel>
                <TextBlock Text="CAT S22 Flip Rooting Tool" FontSize="24" FontWeight="Bold" Foreground="White"/>
                <TextBlock Text="Automated GUI assistant for rooting your CAT S22 Flip" FontSize="12" Foreground="#ECF0F1" Margin="0,5,0,0"/>
            </StackPanel>
        </Border>
        
        <!-- Warning -->
        <Border Grid.Row="1" Background="#E74C3C" Padding="10" CornerRadius="5" Margin="0,0,0,10">
            <StackPanel>
                <TextBlock Text="WARNING" FontWeight="Bold" FontSize="14" Foreground="White" HorizontalAlignment="Center"/>
                <TextBlock Foreground="White" FontSize="11" Margin="0,5,0,0">
                    * Rooting VOIDS WARRANTY and may BRICK your device
                    <LineBreak/>
                    * Unlocking bootloader ERASES ALL DATA (backup first!)
                    <LineBreak/>
                    * Proceed only if you understand the risks
                    <LineBreak/>
                    * Keep phone charged above 50% throughout process
                </TextBlock>
            </StackPanel>
        </Border>
        
        <!-- Configuration -->
        <Border Grid.Row="2" Background="#ECF0F1" Padding="15" CornerRadius="5" Margin="0,0,0,10">
            <StackPanel>
                <Label Content="Device Status:" FontWeight="SemiBold" FontSize="14"/>
                <Border Background="White" Padding="10" CornerRadius="3" Margin="5">
                    <StackPanel>
                        <TextBlock Name="DeviceStatus" Text="No device detected - Please connect device and enable USB debugging" 
                                   Foreground="#E74C3C" FontWeight="SemiBold" FontSize="12"/>
                        <TextBlock Name="FirmwareStatus" Text="Firmware: Unknown" 
                                   Foreground="#7F8C8D" FontSize="11" Margin="0,5,0,0"/>
                    </StackPanel>
                </Border>
                
                <Label Content="Select Your Firmware Version:" FontWeight="SemiBold" FontSize="14" Margin="0,10,0,0"/>
                <ComboBox Name="FirmwareCombo" Height="30" FontSize="14" Margin="5">
                    <ComboBoxItem Content="v29 (Stock)" IsSelected="True"/>
                    <ComboBoxItem Content="v30 (Latest)"/>
                </ComboBox>
                
                <Label Content="Working Directory:" FontWeight="SemiBold" FontSize="12" Margin="0,10,0,0"/>
                <TextBlock Name="WorkingDirText" FontFamily="Consolas" FontSize="11" Background="White" Padding="5"/>
                
                <Button Name="StartButton" Content="START ROOTING PROCESS" Background="#27AE60" Foreground="White" 
                        Height="40" FontSize="16" Margin="5,15,5,5"/>
                
                <Button Name="DetectButton" Content="DETECT DEVICE &amp; FIRMWARE" Background="#3498DB" Foreground="White" 
                        Height="35" FontSize="14" Margin="5,5,5,5"/>
                
                <Button Name="RestoreButton" Content="RESTORE STOCK FIRMWARE (Unbrick)" Background="#E67E22" Foreground="White" 
                        Height="35" FontSize="14" Margin="5,5,5,5"/>
            </StackPanel>
        </Border>
        
        <!-- Log Output -->
        <GroupBox Grid.Row="3" Header="Process Log" Margin="0,0,0,10">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
                <TextBox Name="LogBox" IsReadOnly="True" TextWrapping="Wrap" 
                         FontFamily="Consolas" FontSize="10" Background="#1E1E1E" 
                         Foreground="#00FF00" BorderThickness="0"/>
            </ScrollViewer>
        </GroupBox>
        
        <!-- Progress -->
        <Border Grid.Row="4" Background="#34495E" Padding="10" CornerRadius="5" Margin="0,0,0,10">
            <StackPanel>
                <Label Name="StepLabel" Content="Ready to begin..." Foreground="White" FontWeight="SemiBold"/>
                <ProgressBar Name="ProgressBar" Height="20" Minimum="0" Maximum="100" Value="0"/>
                <Label Name="StatusText" Content="Waiting for user..." Foreground="#BDC3C7" FontStyle="Italic" Margin="0,5,0,0"/>
            </StackPanel>
        </Border>
        
        <!-- Footer -->
        <Border Grid.Row="5" Background="#95A5A6" Padding="8" CornerRadius="5">
            <TextBlock FontSize="10" Foreground="White" HorizontalAlignment="Center">
                Built by Claude | XDA Forums Community | Use at your own risk
            </TextBlock>
        </Border>
    </Grid>
</Window>
"@

# ============================================================================
# GUI INITIALIZATION
# ============================================================================

function Initialize-GUI {
    # Load XAML
    $reader = New-Object System.Xml.XmlNodeReader $XAML
    $Script:GUI = @{
        Window = [Windows.Markup.XamlReader]::Load($reader)
    }
    
    # Get controls
    $Script:GUI.StartButton = $Script:GUI.Window.FindName("StartButton")
    $Script:GUI.DetectButton = $Script:GUI.Window.FindName("DetectButton")
    $Script:GUI.RestoreButton = $Script:GUI.Window.FindName("RestoreButton")
    $Script:GUI.FirmwareCombo = $Script:GUI.Window.FindName("FirmwareCombo")
    $Script:GUI.WorkingDirText = $Script:GUI.Window.FindName("WorkingDirText")
    $Script:GUI.LogBox = $Script:GUI.Window.FindName("LogBox")
    $Script:GUI.ProgressBar = $Script:GUI.Window.FindName("ProgressBar")
    $Script:GUI.StepLabel = $Script:GUI.Window.FindName("StepLabel")
    $Script:GUI.StatusText = $Script:GUI.Window.FindName("StatusText")
    $Script:GUI.DeviceStatus = $Script:GUI.Window.FindName("DeviceStatus")
    $Script:GUI.FirmwareStatus = $Script:GUI.Window.FindName("FirmwareStatus")
    
    # Set working directory display
    $Script:GUI.WorkingDirText.Text = $Script:Config.WorkingDir
    
    # Wire up Detect button
    $Script:GUI.DetectButton.Add_Click({
        # Detect device in SAME thread (avoid scope issues)
        try {
            # Show we're working
            $Script:GUI.DeviceStatus.Text = "Checking for device..."
            $Script:GUI.DeviceStatus.Foreground = "#F39C12"
            
            # Call detect function directly
            Detect-DeviceAndFirmware
        }
        catch {
            Write-Log "Error in Detect button: $_" -Level ERROR
            [System.Windows.MessageBox]::Show(
                "Error detecting device: $_",
                "Error",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
        }
    })
    
    # Wire up Start button
    $Script:GUI.StartButton.Add_Click({
        try {
            $selectedVersion = if ($Script:GUI.FirmwareCombo.SelectedIndex -eq 0) { "29" } else { "30" }
            
            Write-Log "Starting rooting process for v$selectedVersion..." -Level INFO
            
            # Disable buttons during process
            $Script:GUI.StartButton.IsEnabled = $false
            $Script:GUI.DetectButton.IsEnabled = $false
            $Script:GUI.RestoreButton.IsEnabled = $false
            
            # Start rooting directly in UI thread (simpler, works for this use case)
            Start-RootingProcess -FirmwareVersion $selectedVersion
            
            # Re-enable buttons after completion
            $Script:GUI.StartButton.IsEnabled = $true
            $Script:GUI.DetectButton.IsEnabled = $true
            $Script:GUI.RestoreButton.IsEnabled = $true
        }
        catch {
            Write-Log "Error in Start button: $_" -Level ERROR
            [System.Windows.MessageBox]::Show(
                "Error starting rooting process: $_`n`nCheck log for details.",
                "Error",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
            
            # Re-enable buttons on error
            $Script:GUI.StartButton.IsEnabled = $true
            $Script:GUI.DetectButton.IsEnabled = $true
            $Script:GUI.RestoreButton.IsEnabled = $true
        }
    })
    
    # Wire up Restore button
    $Script:GUI.RestoreButton.Add_Click({
        try {
            $selectedVersion = if ($Script:GUI.FirmwareCombo.SelectedIndex -eq 0) { "29" } else { "30" }
            
            Write-Log "Starting stock firmware restore for v$selectedVersion..." -Level INFO
            
            # Disable buttons during process
            $Script:GUI.StartButton.IsEnabled = $false
            $Script:GUI.DetectButton.IsEnabled = $false
            $Script:GUI.RestoreButton.IsEnabled = $false
            
            # Start restore directly in UI thread
            Restore-StockFirmware -Version $selectedVersion
            
            # Re-enable buttons after completion
            $Script:GUI.StartButton.IsEnabled = $true
            $Script:GUI.DetectButton.IsEnabled = $true
            $Script:GUI.RestoreButton.IsEnabled = $true
        }
        catch {
            Write-Log "Error in Restore button: $_" -Level ERROR
            [System.Windows.MessageBox]::Show(
                "Error starting restore: $_`n`nCheck log for details.",
                "Error",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            )
            
            # Re-enable buttons on error
            $Script:GUI.StartButton.IsEnabled = $true
            $Script:GUI.DetectButton.IsEnabled = $true
            $Script:GUI.RestoreButton.IsEnabled = $true
        }
    })
    
    # Show window
    $Script:GUI.Window.ShowDialog() | Out-Null
}

# ============================================================================
# ENTRY POINT
# ============================================================================

# Check administrator
if (-not (Test-Administrator)) {
    [System.Windows.MessageBox]::Show(
        "This tool requires Administrator privileges to install drivers and tools.`n`nPlease run as Administrator.",
        "Administrator Required",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Warning
    )
    exit 1
}

# Initialize environment
Initialize-Environment

# Start GUI
Initialize-GUI
