# ============================================================================
# ANDROID PACKAGE ANALYZER & REMOVAL TOOL
# Comprehensive package analysis, categorization, and safe removal
# For rooted Android devices via ADB
# ============================================================================

#Requires -Version 5.1

param(
    [switch]$NoGui,
    [switch]$ExportOnly,
    [string]$ExportPath = ".\package_reports"
)

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

$Script:Version = "1.0.0"
$Script:AdbPath = $null
$Script:DeviceSerial = $null
$Script:BackupPath = ".\package_backups"
$Script:ReportPath = $ExportPath

# Safety ratings
$Script:ESSENTIAL = "ESSENTIAL"
$Script:KEEP = "KEEP"
$Script:REVIEW = "REVIEW"
$Script:SAFE_TO_REMOVE = "SAFE_TO_REMOVE"

# ============================================================================
# PACKAGE DATABASE - Known packages and their classifications
# ============================================================================

$Script:PackageDatabase = @{
    # ========== ESSENTIAL - Never remove these ==========
    Essential = @(
        # Core Android
        "com.android.systemui"
        "com.android.settings"
        "com.android.phone"
        "com.android.server.telecom"
        "com.android.providers.telephony"
        "com.android.providers.contacts"
        "com.android.providers.settings"
        "com.android.providers.media"
        "com.android.providers.downloads"
        "com.android.inputmethod.latin"
        "com.android.launcher3"
        "com.android.packageinstaller"
        "com.android.permissioncontroller"
        "com.android.shell"
        "com.android.keychain"
        "com.android.networkstack"
        "com.android.wifi.resources"
        "com.android.bluetooth"
        "com.android.nfc"
        # Google essentials (for Play Store functionality)
        "com.google.android.gms"
        "com.android.vending"
        "com.google.android.gsf"
        "com.google.android.gsf.login"
        # Magisk
        "com.topjohnwu.magisk"
    )

    # ========== KEEP - Important but not critical ==========
    Keep = @(
        # Core functionality
        "com.android.documentsui"
        "com.android.externalstorage"
        "com.android.localtransport"
        "com.android.location.fused"
        "com.android.certinstaller"
        "com.android.webview"
        "com.google.android.webview"
        # Accessibility
        "com.android.accessibilitymanager"
        # Security
        "com.android.keyguard"
        "com.android.se"
    )

    # ========== SAFE TO REMOVE - Common bloatware ==========
    SafeToRemove = @{
        # ----- Google Apps (if replaced) -----
        "com.google.android.googlequicksearchbox" = "Google Search/Assistant"
        "com.google.android.apps.searchlite" = "Google Go"
        "com.android.chrome" = "Chrome Browser"
        "com.google.android.apps.messaging" = "Google Messages"
        "com.google.android.dialer" = "Google Phone"
        "com.google.android.contacts" = "Google Contacts"
        "com.google.android.apps.photos" = "Google Photos"
        "com.google.android.apps.docs" = "Google Drive"
        "com.google.android.youtube" = "YouTube"
        "com.google.android.apps.youtube.music" = "YouTube Music"
        "com.google.android.gm" = "Gmail"
        "com.google.android.calendar" = "Google Calendar"
        "com.google.android.apps.tachyon" = "Google Duo/Meet"
        "com.google.android.keep" = "Google Keep"
        "com.google.android.apps.wellbeing" = "Digital Wellbeing"
        "com.google.ar.lens" = "Google Lens"
        "com.google.android.marvin.talkback" = "TalkBack"
        "com.google.android.tts" = "Google Text-to-Speech"
        "com.google.android.apps.turbo" = "Device Health Services"
        "com.google.android.apps.maps" = "Google Maps"
        "com.google.android.videos" = "Google Play Movies"
        "com.google.android.music" = "Google Play Music"
        "com.google.android.apps.books" = "Google Play Books"
        "com.google.android.apps.magazines" = "Google News"
        "com.google.android.apps.podcasts" = "Google Podcasts"
        "com.google.android.apps.nbu.files" = "Files by Google"
        "com.google.android.projection.gearhead" = "Android Auto"
        "com.google.android.apps.restore" = "Device Setup"
        "com.google.android.apps.cloudprint" = "Cloud Print"
        "com.google.android.printservice.recommendation" = "Print Service"
        "com.google.android.feedback" = "Google Feedback"
        "com.google.android.apps.googleassistant" = "Google Assistant"
        "com.google.android.launcher" = "Google Launcher"
        "com.google.android.configupdater" = "Config Updater"
        "com.google.android.partnersetup" = "Partner Setup"
        "com.google.android.onetimeinitializer" = "One Time Init"
        "com.google.android.setupwizard" = "Setup Wizard"
        "com.google.android.syncadapters.calendar" = "Calendar Sync"
        "com.google.android.syncadapters.contacts" = "Contacts Sync"
        "com.google.android.backuptransport" = "Backup Transport"

        # ----- T-Mobile / Sprint Bloat -----
        "com.tmobile.pr.adapt" = "T-Mobile Device Setup"
        "com.tmobile.echolocate" = "T-Mobile Echolocate (Telemetry)"
        "com.tmobile.pr.mytmobile" = "My T-Mobile"
        "com.tmobile.tmoplay" = "T-Mobile Tuesdays"
        "com.tmobile.tuesdays" = "T-Mobile Tuesdays"
        "com.tmobile.services.nameid" = "Name ID"
        "com.tmobile.appselector" = "T-Mobile App Selector"
        "com.tmobile.services" = "T-Mobile Services"
        "com.tmobile.simlock" = "T-Mobile SIM Lock"
        "com.sprint.zone" = "Sprint Zone"
        "com.sprint.dsa" = "Sprint DSA"
        "com.Sprint.ce.updater" = "Sprint Updater"
        "com.asurion.android.vms" = "Visual Voicemail"
        "com.sec.vsim.ericssonnsds.webapp" = "T-Mobile TDC"
        "com.lookout" = "Lookout Security (T-Mobile)"
        "com.nuance.xt9.input" = "Nuance Keyboard"

        # ----- Facebook -----
        "com.facebook.system" = "Facebook System"
        "com.facebook.appmanager" = "Facebook App Manager"
        "com.facebook.services" = "Facebook Services"
        "com.facebook.katana" = "Facebook"
        "com.facebook.orca" = "Messenger"
        "com.instagram.android" = "Instagram"
        "com.whatsapp" = "WhatsApp (pre-installed)"

        # ----- Samsung (if applicable) -----
        "com.samsung.android.app.tips" = "Samsung Tips"
        "com.samsung.android.bixby.agent" = "Bixby Voice"
        "com.samsung.android.bixby.service" = "Bixby Service"
        "com.samsung.android.visionintelligence" = "Bixby Vision"
        "com.samsung.android.game.gamehome" = "Game Launcher"
        "com.samsung.android.game.gametools" = "Game Tools"
        "com.samsung.android.mobileservice" = "Samsung Experience"
        "com.samsung.android.themestore" = "Galaxy Themes"
        "com.samsung.android.app.watchmanager" = "Galaxy Wearable"
        "com.samsung.android.scloud" = "Samsung Cloud"
        "com.samsung.android.spay" = "Samsung Pay"
        "com.samsung.android.arzone" = "AR Zone"

        # ----- Common Bloatware -----
        "com.netflix.partner.activation" = "Netflix (pre-installed)"
        "com.netflix.mediaclient" = "Netflix"
        "com.spotify.music" = "Spotify (pre-installed)"
        "com.amazon.appmanager" = "Amazon App Manager"
        "com.amazon.kindle" = "Kindle"
        "com.amazon.mp3" = "Amazon Music"
        "com.linkedin.android" = "LinkedIn"
        "flipboard.app" = "Flipboard"
        "com.hancom.office.editor.hidden" = "Hancom Office"
    }

    # ========== TELEMETRY & ANALYTICS ==========
    Telemetry = @{
        "com.google.mainline.telemetry" = "Google Telemetry (high priority)"
        "com.google.android.gms.policy_sidecar_aps" = "Google Policy Sidecar"
        "com.tmobile.echolocate" = "T-Mobile Network Analytics"
        "com.google.android.feedback" = "Google Feedback/Crash Reports"
        "com.google.android.apps.turbo" = "Device Health/Battery Analytics"
        "com.google.android.configupdater" = "Google Config Updates"
        "com.samsung.android.sdm.config" = "Samsung Device Management"
        "com.sec.android.diagmonagent" = "Samsung Diagnostics"
        "com.sec.android.app.samsungapps" = "Samsung Analytics"
        "com.qualcomm.qti.qms.service" = "Qualcomm Metrics"
        "com.qualcomm.qti.qdma" = "Qualcomm Data Analytics"
        "com.android.providers.userdictionary" = "Keyboard Analytics (review)"
        "com.android.vending" = "Play Store Analytics (required)"
    }

    # ========== RUNNING SERVICES TO CONSIDER DISABLING ==========
    UnnecessaryServices = @{
        "com.google.android.gms/.chimera.GmsIntentOperationService" = "GMS Background Sync"
        "com.google.android.gms/.auth.account.authenticator.DefaultAuthenticatorService" = "Google Account Sync"
        "com.google.android.gms/.ads.identifier.service.AdvertisingIdService" = "Ad Tracking Service"
        "com.google.android.gms/.measurement.AppMeasurementService" = "Firebase Analytics"
        "com.google.android.gms/.analytics.service.AnalyticsService" = "Google Analytics"
        "com.google.android.gms/.gcm.GcmService" = "Push Notifications (needed for some apps)"
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [switch]$NoNewline
    )

    $colors = @{
        "INFO" = "Cyan"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR" = "Red"
        "DEBUG" = "Gray"
    }

    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = "[$timestamp][$Level]"

    if ($NoNewline) {
        Write-Host "$prefix $Message" -ForegroundColor $colors[$Level] -NoNewline
    } else {
        Write-Host "$prefix $Message" -ForegroundColor $colors[$Level]
    }
}

function Find-ADB {
    $searchPaths = @(
        "$env:TEMP\CAT_S22_Root\platform-tools\adb.exe"
        "$env:TEMP\CAT_S22_Root\tools\platform-tools\adb.exe"
        "$env:USERPROFILE\CAT_S22_Root\tools\platform-tools\adb.exe"
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
        "$PSScriptRoot\platform-tools\adb.exe"
        "adb.exe"
    )

    foreach ($path in $searchPaths) {
        if (Test-Path $path -ErrorAction SilentlyContinue) {
            return $path
        }
    }

    # Try PATH
    try {
        $null = & adb version 2>&1
        return "adb"
    } catch {
        return $null
    }
}

function Test-DeviceConnection {
    try {
        $result = & $Script:AdbPath devices 2>&1 | Out-String
        if ($result -match "(\S+)\s+device\s*$" -and $result -notmatch "unauthorized") {
            $Script:DeviceSerial = $Matches[1]
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

function Invoke-AdbShell {
    param([string]$Command)
    try {
        $result = & $Script:AdbPath shell $Command 2>&1
        return $result
    } catch {
        return $null
    }
}

# ============================================================================
# PACKAGE ANALYSIS FUNCTIONS
# ============================================================================

function Get-AllPackages {
    Write-Log "Retrieving all installed packages..." -Level INFO

    $packages = @()

    # Get all packages with paths
    $allPackages = Invoke-AdbShell "pm list packages -f" | Where-Object { $_ -match "^package:" }

    $total = $allPackages.Count
    $current = 0

    foreach ($line in $allPackages) {
        $current++
        $percent = [math]::Round(($current / $total) * 100)
        Write-Progress -Activity "Analyzing packages" -Status "$current of $total ($percent%)" -PercentComplete $percent

        # Parse: package:/data/app/com.example-xxx/base.apk=com.example
        if ($line -match "package:(.+)=(.+)$") {
            $apkPath = $Matches[1]
            $packageName = $Matches[2].Trim()

            $pkg = Get-PackageDetails -PackageName $packageName -ApkPath $apkPath
            if ($pkg) {
                $packages += $pkg
            }
        }
    }

    Write-Progress -Activity "Analyzing packages" -Completed

    return $packages
}

function Get-PackageDetails {
    param(
        [string]$PackageName,
        [string]$ApkPath
    )

    # Get package info
    $dumpsys = Invoke-AdbShell "dumpsys package $PackageName" | Out-String

    # Parse details
    $isSystem = $ApkPath -match "^/system/" -or $ApkPath -match "^/product/" -or $ApkPath -match "^/vendor/"
    $isEnabled = -not ($dumpsys -match "enabled=0" -or $dumpsys -match "DISABLED")

    # Get app label
    $label = $PackageName
    if ($dumpsys -match "applicationInfo.*label=([^\s]+)") {
        $label = $Matches[1]
    }

    # Get version
    $version = "Unknown"
    if ($dumpsys -match "versionName=([^\s]+)") {
        $version = $Matches[1]
    }

    # Get install time
    $installTime = "Unknown"
    if ($dumpsys -match "firstInstallTime=([^\s]+)") {
        $installTime = $Matches[1]
    }

    # Get APK size
    $apkSize = "Unknown"
    $sizeOutput = Invoke-AdbShell "stat -c%s `"$ApkPath`" 2>/dev/null"
    if ($sizeOutput -match "^\d+$") {
        $bytes = [long]$sizeOutput
        if ($bytes -gt 1048576) {
            $apkSize = "{0:N1} MB" -f ($bytes / 1048576)
        } else {
            $apkSize = "{0:N0} KB" -f ($bytes / 1024)
        }
    }

    # Determine category and safety rating
    $category = Get-PackageCategory -PackageName $PackageName
    $safetyRating = Get-SafetyRating -PackageName $PackageName
    $description = Get-PackageDescription -PackageName $PackageName
    $isTelemetry = $Script:PackageDatabase.Telemetry.ContainsKey($PackageName)

    return [PSCustomObject]@{
        PackageName = $PackageName
        Label = $label
        Version = $version
        Category = $category
        IsSystem = $isSystem
        IsEnabled = $isEnabled
        ApkPath = $ApkPath
        ApkSize = $apkSize
        InstallTime = $installTime
        SafetyRating = $safetyRating
        Description = $description
        IsTelemetry = $isTelemetry
    }
}

function Get-PackageCategory {
    param([string]$PackageName)

    if ($PackageName -match "^com\.google\.") { return "Google" }
    if ($PackageName -match "^com\.android\.") { return "Android/AOSP" }
    if ($PackageName -match "^com\.tmobile\." -or $PackageName -match "^com\.sprint\.") { return "T-Mobile/Sprint" }
    if ($PackageName -match "^com\.samsung\." -or $PackageName -match "^com\.sec\.") { return "Samsung" }
    if ($PackageName -match "^com\.qualcomm\.") { return "Qualcomm" }
    if ($PackageName -match "^com\.facebook\.") { return "Facebook" }
    if ($PackageName -match "^com\.catphones\." -or $PackageName -match "^com\.cat\.") { return "CAT/OEM" }
    if ($PackageName -match "^org\." -or $PackageName -match "^io\.") { return "Open Source" }

    return "Third-Party"
}

function Get-SafetyRating {
    param([string]$PackageName)

    # Check essential
    if ($Script:PackageDatabase.Essential -contains $PackageName) {
        return $Script:ESSENTIAL
    }

    # Check keep
    if ($Script:PackageDatabase.Keep -contains $PackageName) {
        return $Script:KEEP
    }

    # Check safe to remove
    if ($Script:PackageDatabase.SafeToRemove.ContainsKey($PackageName)) {
        return $Script:SAFE_TO_REMOVE
    }

    # Check telemetry
    if ($Script:PackageDatabase.Telemetry.ContainsKey($PackageName)) {
        return $Script:SAFE_TO_REMOVE
    }

    # Default based on category
    $category = Get-PackageCategory -PackageName $PackageName
    switch ($category) {
        "T-Mobile/Sprint" { return $Script:SAFE_TO_REMOVE }
        "Facebook" { return $Script:SAFE_TO_REMOVE }
        "Samsung" { return $Script:REVIEW }
        "Google" { return $Script:REVIEW }
        "Android/AOSP" { return $Script:KEEP }
        "Open Source" { return $Script:KEEP }
        default { return $Script:REVIEW }
    }
}

function Get-PackageDescription {
    param([string]$PackageName)

    if ($Script:PackageDatabase.SafeToRemove.ContainsKey($PackageName)) {
        return $Script:PackageDatabase.SafeToRemove[$PackageName]
    }
    if ($Script:PackageDatabase.Telemetry.ContainsKey($PackageName)) {
        return $Script:PackageDatabase.Telemetry[$PackageName]
    }

    return ""
}

# ============================================================================
# RUNNING SERVICES ANALYSIS
# ============================================================================

function Get-RunningServices {
    Write-Log "Analyzing running services..." -Level INFO

    $services = @()

    $output = Invoke-AdbShell "dumpsys activity services" | Out-String

    # Parse service records
    $serviceMatches = [regex]::Matches($output, "ServiceRecord\{[^}]+\s+([^\s}]+)/([^\s}]+)\}")

    foreach ($match in $serviceMatches) {
        $packageName = $match.Groups[1].Value
        $serviceName = $match.Groups[2].Value

        $isUnnecessary = $Script:PackageDatabase.UnnecessaryServices.ContainsKey("$packageName/$serviceName")
        $description = if ($isUnnecessary) { $Script:PackageDatabase.UnnecessaryServices["$packageName/$serviceName"] } else { "" }

        $services += [PSCustomObject]@{
            Package = $packageName
            Service = $serviceName
            FullName = "$packageName/$serviceName"
            IsUnnecessary = $isUnnecessary
            Description = $description
        }
    }

    return $services | Sort-Object Package -Unique
}

function Get-BatteryStats {
    Write-Log "Analyzing battery usage..." -Level INFO

    $output = Invoke-AdbShell "dumpsys batterystats --charged" | Out-String

    $stats = @()

    # Parse Uid stats
    $matches = [regex]::Matches($output, "Uid\s+(\S+):\s+(\d+\.?\d*)\s*mAh")

    foreach ($match in $matches) {
        $uid = $match.Groups[1].Value
        $mah = [double]$match.Groups[2].Value

        if ($mah -gt 0.1) {
            $stats += [PSCustomObject]@{
                Uid = $uid
                Usage = "$mah mAh"
            }
        }
    }

    return $stats | Sort-Object { [double]($_.Usage -replace " mAh", "") } -Descending | Select-Object -First 20
}

# ============================================================================
# PACKAGE MANAGEMENT
# ============================================================================

function Remove-Package {
    param(
        [string]$PackageName,
        [switch]$Force
    )

    Write-Log "Removing package: $PackageName" -Level WARNING

    # Try user uninstall first
    $result = Invoke-AdbShell "pm uninstall --user 0 $PackageName"

    if ($result -match "Success") {
        Write-Log "Successfully removed: $PackageName" -Level SUCCESS
        return $true
    }

    # Try disable
    $result = Invoke-AdbShell "pm disable-user --user 0 $PackageName"
    if ($result -match "disabled") {
        Write-Log "Disabled: $PackageName" -Level SUCCESS
        return $true
    }

    Write-Log "Failed to remove: $PackageName" -Level ERROR
    return $false
}

function Enable-Package {
    param([string]$PackageName)

    $result = Invoke-AdbShell "pm enable $PackageName"

    if ($result -match "enabled") {
        Write-Log "Enabled: $PackageName" -Level SUCCESS
        return $true
    }

    Write-Log "Failed to enable: $PackageName" -Level ERROR
    return $false
}

function Backup-PackageList {
    param([array]$Packages)

    if (-not (Test-Path $Script:BackupPath)) {
        New-Item -ItemType Directory -Path $Script:BackupPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $Script:BackupPath "packages_$timestamp.json"

    $Packages | ConvertTo-Json -Depth 5 | Out-File -FilePath $backupFile -Encoding UTF8

    Write-Log "Package list backed up to: $backupFile" -Level SUCCESS
    return $backupFile
}

function Save-RemovalLog {
    param(
        [array]$RemovedPackages,
        [string]$Notes = ""
    )

    if (-not (Test-Path $Script:BackupPath)) {
        New-Item -ItemType Directory -Path $Script:BackupPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFile = Join-Path $Script:BackupPath "removed_$timestamp.md"

    $content = @"
# Package Removal Log
**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Device:** $Script:DeviceSerial

## Removed Packages

| Package | Description | Rating |
|---------|-------------|--------|
"@

    foreach ($pkg in $RemovedPackages) {
        $content += "`n| $($pkg.PackageName) | $($pkg.Description) | $($pkg.SafetyRating) |"
    }

    if ($Notes) {
        $content += "`n`n## Notes`n$Notes"
    }

    $content += @"

## Restore Commands

``````powershell
# To restore these packages, run:
"@

    foreach ($pkg in $RemovedPackages) {
        $content += "`nInvoke-AdbShell `"pm enable $($pkg.PackageName)`""
    }

    $content += "`n``````"

    $content | Out-File -FilePath $logFile -Encoding UTF8

    Write-Log "Removal log saved to: $logFile" -Level SUCCESS
    return $logFile
}

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================

function Export-HTMLReport {
    param(
        [array]$Packages,
        [array]$Services,
        [string]$OutputPath
    )

    if (-not (Test-Path $Script:ReportPath)) {
        New-Item -ItemType Directory -Path $Script:ReportPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $htmlFile = Join-Path $Script:ReportPath "package_report_$timestamp.html"

    # Count by category
    $categoryCounts = $Packages | Group-Object Category | Sort-Object Count -Descending
    $ratingCounts = $Packages | Group-Object SafetyRating | Sort-Object Count -Descending

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Android Package Analysis Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, sans-serif; margin: 20px; background: #1a1a2e; color: #eee; }
        h1 { color: #00d9ff; }
        h2 { color: #00ff88; border-bottom: 1px solid #333; padding-bottom: 10px; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #333; padding: 10px; text-align: left; }
        th { background: #16213e; color: #00d9ff; }
        tr:nth-child(even) { background: #1f2940; }
        tr:hover { background: #2a3f5f; }
        .essential { color: #ff4444; font-weight: bold; }
        .keep { color: #ffaa00; }
        .review { color: #ffff00; }
        .safe { color: #00ff88; }
        .telemetry { background: #4a1a1a !important; }
        .summary { display: flex; flex-wrap: wrap; gap: 20px; margin: 20px 0; }
        .summary-box { background: #16213e; padding: 20px; border-radius: 10px; min-width: 200px; }
        .summary-box h3 { margin: 0 0 10px 0; color: #00d9ff; }
        .summary-box .count { font-size: 2em; color: #00ff88; }
        .filter-btn { padding: 10px 20px; margin: 5px; cursor: pointer; border: none; border-radius: 5px; }
        .filter-btn.active { background: #00d9ff; color: #000; }
        .filter-btn:not(.active) { background: #333; color: #fff; }
        .search { padding: 10px; width: 300px; margin: 10px 0; background: #16213e; border: 1px solid #333; color: #fff; }
    </style>
</head>
<body>
    <h1>Android Package Analysis Report</h1>
    <p>Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") | Device: $Script:DeviceSerial</p>

    <div class="summary">
        <div class="summary-box">
            <h3>Total Packages</h3>
            <div class="count">$($Packages.Count)</div>
        </div>
        <div class="summary-box">
            <h3>Safe to Remove</h3>
            <div class="count">$(($Packages | Where-Object SafetyRating -eq $Script:SAFE_TO_REMOVE).Count)</div>
        </div>
        <div class="summary-box">
            <h3>Telemetry</h3>
            <div class="count">$(($Packages | Where-Object IsTelemetry).Count)</div>
        </div>
        <div class="summary-box">
            <h3>Running Services</h3>
            <div class="count">$($Services.Count)</div>
        </div>
    </div>

    <h2>Category Summary</h2>
    <table>
        <tr><th>Category</th><th>Count</th></tr>
"@

    foreach ($cat in $categoryCounts) {
        $html += "        <tr><td>$($cat.Name)</td><td>$($cat.Count)</td></tr>`n"
    }

    $html += @"
    </table>

    <h2>Packages by Safety Rating</h2>
    <input type="text" class="search" placeholder="Search packages..." onkeyup="filterTable()">
    <div>
        <button class="filter-btn active" onclick="showAll()">All</button>
        <button class="filter-btn" onclick="showSafe()">Safe to Remove</button>
        <button class="filter-btn" onclick="showTelemetry()">Telemetry</button>
        <button class="filter-btn" onclick="showGoogle()">Google</button>
        <button class="filter-btn" onclick="showCarrier()">Carrier</button>
    </div>

    <table id="packageTable">
        <tr>
            <th>Package</th>
            <th>Category</th>
            <th>Rating</th>
            <th>Description</th>
            <th>System</th>
            <th>Enabled</th>
            <th>Size</th>
        </tr>
"@

    foreach ($pkg in $Packages | Sort-Object SafetyRating, Category, PackageName) {
        $ratingClass = switch ($pkg.SafetyRating) {
            $Script:ESSENTIAL { "essential" }
            $Script:KEEP { "keep" }
            $Script:REVIEW { "review" }
            $Script:SAFE_TO_REMOVE { "safe" }
        }
        $telemetryClass = if ($pkg.IsTelemetry) { "telemetry" } else { "" }

        $html += @"
        <tr class="$telemetryClass" data-category="$($pkg.Category)" data-rating="$($pkg.SafetyRating)" data-telemetry="$($pkg.IsTelemetry)">
            <td>$($pkg.PackageName)</td>
            <td>$($pkg.Category)</td>
            <td class="$ratingClass">$($pkg.SafetyRating)</td>
            <td>$($pkg.Description)</td>
            <td>$(if ($pkg.IsSystem) { "Yes" } else { "No" })</td>
            <td>$(if ($pkg.IsEnabled) { "Yes" } else { "No" })</td>
            <td>$($pkg.ApkSize)</td>
        </tr>
"@
    }

    $html += @"
    </table>

    <h2>Running Services</h2>
    <table>
        <tr><th>Package</th><th>Service</th><th>Unnecessary?</th><th>Description</th></tr>
"@

    foreach ($svc in $Services | Sort-Object IsUnnecessary -Descending) {
        $class = if ($svc.IsUnnecessary) { "telemetry" } else { "" }
        $html += "        <tr class=`"$class`"><td>$($svc.Package)</td><td>$($svc.Service)</td><td>$(if ($svc.IsUnnecessary) { 'Yes' } else { 'No' })</td><td>$($svc.Description)</td></tr>`n"
    }

    $html += @"
    </table>

    <script>
        function filterTable() {
            var input = document.querySelector('.search').value.toLowerCase();
            var rows = document.querySelectorAll('#packageTable tr:not(:first-child)');
            rows.forEach(function(row) {
                var text = row.textContent.toLowerCase();
                row.style.display = text.includes(input) ? '' : 'none';
            });
        }

        function showAll() {
            document.querySelectorAll('#packageTable tr').forEach(r => r.style.display = '');
            updateButtons('all');
        }

        function showSafe() {
            document.querySelectorAll('#packageTable tr:not(:first-child)').forEach(function(row) {
                row.style.display = row.dataset.rating === 'SAFE_TO_REMOVE' ? '' : 'none';
            });
            updateButtons('safe');
        }

        function showTelemetry() {
            document.querySelectorAll('#packageTable tr:not(:first-child)').forEach(function(row) {
                row.style.display = row.dataset.telemetry === 'True' ? '' : 'none';
            });
            updateButtons('telemetry');
        }

        function showGoogle() {
            document.querySelectorAll('#packageTable tr:not(:first-child)').forEach(function(row) {
                row.style.display = row.dataset.category === 'Google' ? '' : 'none';
            });
            updateButtons('google');
        }

        function showCarrier() {
            document.querySelectorAll('#packageTable tr:not(:first-child)').forEach(function(row) {
                row.style.display = row.dataset.category === 'T-Mobile/Sprint' ? '' : 'none';
            });
            updateButtons('carrier');
        }

        function updateButtons(active) {
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            event.target.classList.add('active');
        }
    </script>
</body>
</html>
"@

    $html | Out-File -FilePath $htmlFile -Encoding UTF8

    Write-Log "HTML report saved to: $htmlFile" -Level SUCCESS
    return $htmlFile
}

function Export-CSV {
    param(
        [array]$Packages,
        [string]$OutputPath
    )

    if (-not (Test-Path $Script:ReportPath)) {
        New-Item -ItemType Directory -Path $Script:ReportPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $csvFile = Join-Path $Script:ReportPath "packages_$timestamp.csv"

    $Packages | Select-Object PackageName, Label, Category, SafetyRating, Description, IsSystem, IsEnabled, ApkSize, IsTelemetry |
        Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8

    Write-Log "CSV export saved to: $csvFile" -Level SUCCESS
    return $csvFile
}

# ============================================================================
# GUI FUNCTIONS
# ============================================================================

function Show-MainMenu {
    param([array]$Packages, [array]$Services)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Android Package Analyzer v$Script:Version"
    $form.Size = New-Object System.Drawing.Size(1200, 800)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(26, 26, 46)
    $form.ForeColor = [System.Drawing.Color]::White

    # Header
    $header = New-Object System.Windows.Forms.Label
    $header.Text = "Android Package Analyzer"
    $header.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $header.ForeColor = [System.Drawing.Color]::FromArgb(0, 217, 255)
    $header.Location = New-Object System.Drawing.Point(20, 15)
    $header.AutoSize = $true
    $form.Controls.Add($header)

    $deviceLabel = New-Object System.Windows.Forms.Label
    $deviceLabel.Text = "Device: $Script:DeviceSerial | Packages: $($Packages.Count) | Safe to Remove: $(($Packages | Where-Object SafetyRating -eq $Script:SAFE_TO_REMOVE).Count)"
    $deviceLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $deviceLabel.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150)
    $deviceLabel.Location = New-Object System.Drawing.Point(22, 50)
    $deviceLabel.AutoSize = $true
    $form.Controls.Add($deviceLabel)

    # Tab Control
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Location = New-Object System.Drawing.Point(20, 80)
    $tabControl.Size = New-Object System.Drawing.Size(1140, 620)
    $tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 10)

    # ===== TAB 1: All Packages =====
    $tabPackages = New-Object System.Windows.Forms.TabPage
    $tabPackages.Text = "All Packages"
    $tabPackages.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 50)

    # Filter buttons
    $filterPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $filterPanel.Location = New-Object System.Drawing.Point(10, 10)
    $filterPanel.Size = New-Object System.Drawing.Size(1100, 40)
    $filterPanel.FlowDirection = "LeftToRight"

    $filters = @("All", "Safe to Remove", "Telemetry", "Google", "Carrier", "System", "Disabled")
    foreach ($filter in $filters) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $filter
        $btn.Size = New-Object System.Drawing.Size(120, 30)
        $btn.FlatStyle = "Flat"
        $btn.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 80)
        $btn.ForeColor = [System.Drawing.Color]::White
        $btn.Tag = $filter
        $btn.Add_Click({
            param($sender, $e)
            Filter-ListView -ListView $listView -Filter $sender.Tag -Packages $Packages
        })
        $filterPanel.Controls.Add($btn)
    }
    $tabPackages.Controls.Add($filterPanel)

    # Search box
    $searchBox = New-Object System.Windows.Forms.TextBox
    $searchBox.Location = New-Object System.Drawing.Point(10, 55)
    $searchBox.Size = New-Object System.Drawing.Size(300, 25)
    $searchBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $searchBox.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 60)
    $searchBox.ForeColor = [System.Drawing.Color]::White
    $searchBox.Add_TextChanged({
        Search-ListView -ListView $listView -SearchText $searchBox.Text -Packages $Packages
    })
    $tabPackages.Controls.Add($searchBox)

    $searchLabel = New-Object System.Windows.Forms.Label
    $searchLabel.Text = "Search:"
    $searchLabel.Location = New-Object System.Drawing.Point(320, 58)
    $searchLabel.AutoSize = $true
    $searchLabel.ForeColor = [System.Drawing.Color]::Gray
    $tabPackages.Controls.Add($searchLabel)

    # ListView for packages
    $listView = New-Object System.Windows.Forms.ListView
    $listView.Location = New-Object System.Drawing.Point(10, 85)
    $listView.Size = New-Object System.Drawing.Size(1100, 420)
    $listView.View = "Details"
    $listView.FullRowSelect = $true
    $listView.CheckBoxes = $true
    $listView.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 50)
    $listView.ForeColor = [System.Drawing.Color]::White
    $listView.Font = New-Object System.Drawing.Font("Consolas", 9)

    $listView.Columns.Add("Package", 350) | Out-Null
    $listView.Columns.Add("Category", 120) | Out-Null
    $listView.Columns.Add("Rating", 120) | Out-Null
    $listView.Columns.Add("Description", 300) | Out-Null
    $listView.Columns.Add("Size", 80) | Out-Null
    $listView.Columns.Add("Enabled", 70) | Out-Null

    Populate-ListView -ListView $listView -Packages $Packages
    $tabPackages.Controls.Add($listView)

    # Action buttons
    $btnRemoveSelected = New-Object System.Windows.Forms.Button
    $btnRemoveSelected.Text = "Remove Selected"
    $btnRemoveSelected.Location = New-Object System.Drawing.Point(10, 515)
    $btnRemoveSelected.Size = New-Object System.Drawing.Size(150, 35)
    $btnRemoveSelected.BackColor = [System.Drawing.Color]::FromArgb(200, 50, 50)
    $btnRemoveSelected.ForeColor = [System.Drawing.Color]::White
    $btnRemoveSelected.FlatStyle = "Flat"
    $btnRemoveSelected.Add_Click({
        $selected = @()
        foreach ($item in $listView.CheckedItems) {
            $pkg = $Packages | Where-Object PackageName -eq $item.Text
            if ($pkg) { $selected += $pkg }
        }
        if ($selected.Count -gt 0) {
            Remove-SelectedPackages -Packages $selected
        } else {
            [System.Windows.Forms.MessageBox]::Show("No packages selected.", "Info", "OK", "Information")
        }
    })
    $tabPackages.Controls.Add($btnRemoveSelected)

    $btnSelectSafe = New-Object System.Windows.Forms.Button
    $btnSelectSafe.Text = "Select All Safe"
    $btnSelectSafe.Location = New-Object System.Drawing.Point(170, 515)
    $btnSelectSafe.Size = New-Object System.Drawing.Size(130, 35)
    $btnSelectSafe.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 100)
    $btnSelectSafe.ForeColor = [System.Drawing.Color]::White
    $btnSelectSafe.FlatStyle = "Flat"
    $btnSelectSafe.Add_Click({
        foreach ($item in $listView.Items) {
            $pkg = $Packages | Where-Object PackageName -eq $item.Text
            if ($pkg -and $pkg.SafetyRating -eq $Script:SAFE_TO_REMOVE) {
                $item.Checked = $true
            }
        }
    })
    $tabPackages.Controls.Add($btnSelectSafe)

    $btnClearSelection = New-Object System.Windows.Forms.Button
    $btnClearSelection.Text = "Clear Selection"
    $btnClearSelection.Location = New-Object System.Drawing.Point(310, 515)
    $btnClearSelection.Size = New-Object System.Drawing.Size(120, 35)
    $btnClearSelection.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 100)
    $btnClearSelection.ForeColor = [System.Drawing.Color]::White
    $btnClearSelection.FlatStyle = "Flat"
    $btnClearSelection.Add_Click({
        foreach ($item in $listView.Items) {
            $item.Checked = $false
        }
    })
    $tabPackages.Controls.Add($btnClearSelection)

    $tabControl.TabPages.Add($tabPackages)

    # ===== TAB 2: Telemetry =====
    $tabTelemetry = New-Object System.Windows.Forms.TabPage
    $tabTelemetry.Text = "Telemetry & Analytics"
    $tabTelemetry.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 50)

    $telemetryLabel = New-Object System.Windows.Forms.Label
    $telemetryLabel.Text = "These packages collect data and send it to remote servers. Recommended to remove/disable."
    $telemetryLabel.Location = New-Object System.Drawing.Point(10, 10)
    $telemetryLabel.Size = New-Object System.Drawing.Size(800, 25)
    $telemetryLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
    $tabTelemetry.Controls.Add($telemetryLabel)

    $telemetryList = New-Object System.Windows.Forms.ListView
    $telemetryList.Location = New-Object System.Drawing.Point(10, 40)
    $telemetryList.Size = New-Object System.Drawing.Size(1100, 460)
    $telemetryList.View = "Details"
    $telemetryList.FullRowSelect = $true
    $telemetryList.CheckBoxes = $true
    $telemetryList.BackColor = [System.Drawing.Color]::FromArgb(40, 20, 20)
    $telemetryList.ForeColor = [System.Drawing.Color]::White
    $telemetryList.Font = New-Object System.Drawing.Font("Consolas", 9)

    $telemetryList.Columns.Add("Package", 400) | Out-Null
    $telemetryList.Columns.Add("Description", 400) | Out-Null
    $telemetryList.Columns.Add("Enabled", 100) | Out-Null
    $telemetryList.Columns.Add("Status", 150) | Out-Null

    $telemetryPackages = $Packages | Where-Object IsTelemetry
    foreach ($pkg in $telemetryPackages) {
        $item = New-Object System.Windows.Forms.ListViewItem($pkg.PackageName)
        $item.SubItems.Add($pkg.Description) | Out-Null
        $item.SubItems.Add($(if ($pkg.IsEnabled) { "Yes" } else { "No" })) | Out-Null
        $item.SubItems.Add($(if ($pkg.IsEnabled) { "ACTIVE" } else { "Disabled" })) | Out-Null
        if ($pkg.IsEnabled) {
            $item.BackColor = [System.Drawing.Color]::FromArgb(80, 30, 30)
        }
        $telemetryList.Items.Add($item) | Out-Null
    }
    $tabTelemetry.Controls.Add($telemetryList)

    $btnDisableAllTelemetry = New-Object System.Windows.Forms.Button
    $btnDisableAllTelemetry.Text = "DISABLE ALL TELEMETRY"
    $btnDisableAllTelemetry.Location = New-Object System.Drawing.Point(10, 510)
    $btnDisableAllTelemetry.Size = New-Object System.Drawing.Size(250, 40)
    $btnDisableAllTelemetry.BackColor = [System.Drawing.Color]::FromArgb(180, 50, 50)
    $btnDisableAllTelemetry.ForeColor = [System.Drawing.Color]::White
    $btnDisableAllTelemetry.FlatStyle = "Flat"
    $btnDisableAllTelemetry.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $btnDisableAllTelemetry.Add_Click({
        $result = [System.Windows.Forms.MessageBox]::Show(
            "This will disable $($telemetryPackages.Count) telemetry packages.`n`nContinue?",
            "Confirm",
            "YesNo",
            "Warning"
        )
        if ($result -eq "Yes") {
            foreach ($pkg in $telemetryPackages) {
                if ($pkg.IsEnabled -and $pkg.SafetyRating -ne $Script:ESSENTIAL) {
                    Remove-Package -PackageName $pkg.PackageName
                }
            }
            [System.Windows.Forms.MessageBox]::Show("Telemetry packages disabled!", "Complete", "OK", "Information")
        }
    })
    $tabTelemetry.Controls.Add($btnDisableAllTelemetry)

    $tabControl.TabPages.Add($tabTelemetry)

    # ===== TAB 3: Services =====
    $tabServices = New-Object System.Windows.Forms.TabPage
    $tabServices.Text = "Running Services"
    $tabServices.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 50)

    $servicesList = New-Object System.Windows.Forms.ListView
    $servicesList.Location = New-Object System.Drawing.Point(10, 10)
    $servicesList.Size = New-Object System.Drawing.Size(1100, 540)
    $servicesList.View = "Details"
    $servicesList.FullRowSelect = $true
    $servicesList.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 50)
    $servicesList.ForeColor = [System.Drawing.Color]::White
    $servicesList.Font = New-Object System.Drawing.Font("Consolas", 9)

    $servicesList.Columns.Add("Package", 300) | Out-Null
    $servicesList.Columns.Add("Service", 350) | Out-Null
    $servicesList.Columns.Add("Unnecessary", 100) | Out-Null
    $servicesList.Columns.Add("Description", 300) | Out-Null

    foreach ($svc in $Services | Sort-Object IsUnnecessary -Descending) {
        $item = New-Object System.Windows.Forms.ListViewItem($svc.Package)
        $item.SubItems.Add($svc.Service) | Out-Null
        $item.SubItems.Add($(if ($svc.IsUnnecessary) { "Yes" } else { "No" })) | Out-Null
        $item.SubItems.Add($svc.Description) | Out-Null
        if ($svc.IsUnnecessary) {
            $item.BackColor = [System.Drawing.Color]::FromArgb(80, 60, 30)
        }
        $servicesList.Items.Add($item) | Out-Null
    }
    $tabServices.Controls.Add($servicesList)

    $tabControl.TabPages.Add($tabServices)

    # ===== TAB 4: Export =====
    $tabExport = New-Object System.Windows.Forms.TabPage
    $tabExport.Text = "Export Reports"
    $tabExport.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 50)

    $exportLabel = New-Object System.Windows.Forms.Label
    $exportLabel.Text = "Export analysis reports in various formats:"
    $exportLabel.Location = New-Object System.Drawing.Point(20, 20)
    $exportLabel.AutoSize = $true
    $exportLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $tabExport.Controls.Add($exportLabel)

    $btnExportHTML = New-Object System.Windows.Forms.Button
    $btnExportHTML.Text = "Export HTML Report"
    $btnExportHTML.Location = New-Object System.Drawing.Point(20, 60)
    $btnExportHTML.Size = New-Object System.Drawing.Size(200, 40)
    $btnExportHTML.BackColor = [System.Drawing.Color]::FromArgb(50, 100, 150)
    $btnExportHTML.ForeColor = [System.Drawing.Color]::White
    $btnExportHTML.FlatStyle = "Flat"
    $btnExportHTML.Add_Click({
        $file = Export-HTMLReport -Packages $Packages -Services $Services
        [System.Windows.Forms.MessageBox]::Show("Report saved to:`n$file", "Export Complete", "OK", "Information")
        Start-Process $file
    })
    $tabExport.Controls.Add($btnExportHTML)

    $btnExportCSV = New-Object System.Windows.Forms.Button
    $btnExportCSV.Text = "Export CSV"
    $btnExportCSV.Location = New-Object System.Drawing.Point(20, 110)
    $btnExportCSV.Size = New-Object System.Drawing.Size(200, 40)
    $btnExportCSV.BackColor = [System.Drawing.Color]::FromArgb(50, 150, 100)
    $btnExportCSV.ForeColor = [System.Drawing.Color]::White
    $btnExportCSV.FlatStyle = "Flat"
    $btnExportCSV.Add_Click({
        $file = Export-CSV -Packages $Packages
        [System.Windows.Forms.MessageBox]::Show("CSV saved to:`n$file", "Export Complete", "OK", "Information")
    })
    $tabExport.Controls.Add($btnExportCSV)

    $btnBackupList = New-Object System.Windows.Forms.Button
    $btnBackupList.Text = "Backup Package List"
    $btnBackupList.Location = New-Object System.Drawing.Point(20, 160)
    $btnBackupList.Size = New-Object System.Drawing.Size(200, 40)
    $btnBackupList.BackColor = [System.Drawing.Color]::FromArgb(150, 100, 50)
    $btnBackupList.ForeColor = [System.Drawing.Color]::White
    $btnBackupList.FlatStyle = "Flat"
    $btnBackupList.Add_Click({
        $file = Backup-PackageList -Packages $Packages
        [System.Windows.Forms.MessageBox]::Show("Backup saved to:`n$file", "Backup Complete", "OK", "Information")
    })
    $tabExport.Controls.Add($btnBackupList)

    $tabControl.TabPages.Add($tabExport)

    $form.Controls.Add($tabControl)

    # Status bar
    $statusBar = New-Object System.Windows.Forms.StatusStrip
    $statusBar.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 35)
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Text = "Ready | Connected to: $Script:DeviceSerial"
    $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 200, 100)
    $statusBar.Items.Add($statusLabel) | Out-Null
    $form.Controls.Add($statusBar)

    $form.ShowDialog()
}

function Populate-ListView {
    param(
        [System.Windows.Forms.ListView]$ListView,
        [array]$Packages
    )

    $ListView.Items.Clear()

    foreach ($pkg in $Packages | Sort-Object SafetyRating, Category, PackageName) {
        $item = New-Object System.Windows.Forms.ListViewItem($pkg.PackageName)
        $item.SubItems.Add($pkg.Category) | Out-Null
        $item.SubItems.Add($pkg.SafetyRating) | Out-Null
        $item.SubItems.Add($pkg.Description) | Out-Null
        $item.SubItems.Add($pkg.ApkSize) | Out-Null
        $item.SubItems.Add($(if ($pkg.IsEnabled) { "Yes" } else { "No" })) | Out-Null

        # Color coding
        switch ($pkg.SafetyRating) {
            $Script:ESSENTIAL { $item.ForeColor = [System.Drawing.Color]::FromArgb(255, 80, 80) }
            $Script:KEEP { $item.ForeColor = [System.Drawing.Color]::FromArgb(255, 180, 0) }
            $Script:REVIEW { $item.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 100) }
            $Script:SAFE_TO_REMOVE { $item.ForeColor = [System.Drawing.Color]::FromArgb(100, 255, 100) }
        }

        if ($pkg.IsTelemetry) {
            $item.BackColor = [System.Drawing.Color]::FromArgb(60, 30, 30)
        }

        $ListView.Items.Add($item) | Out-Null
    }
}

function Filter-ListView {
    param(
        [System.Windows.Forms.ListView]$ListView,
        [string]$Filter,
        [array]$Packages
    )

    $filtered = switch ($Filter) {
        "All" { $Packages }
        "Safe to Remove" { $Packages | Where-Object SafetyRating -eq $Script:SAFE_TO_REMOVE }
        "Telemetry" { $Packages | Where-Object IsTelemetry }
        "Google" { $Packages | Where-Object Category -eq "Google" }
        "Carrier" { $Packages | Where-Object Category -eq "T-Mobile/Sprint" }
        "System" { $Packages | Where-Object IsSystem }
        "Disabled" { $Packages | Where-Object { -not $_.IsEnabled } }
        default { $Packages }
    }

    Populate-ListView -ListView $ListView -Packages $filtered
}

function Search-ListView {
    param(
        [System.Windows.Forms.ListView]$ListView,
        [string]$SearchText,
        [array]$Packages
    )

    if ([string]::IsNullOrWhiteSpace($SearchText)) {
        Populate-ListView -ListView $ListView -Packages $Packages
        return
    }

    $filtered = $Packages | Where-Object {
        $_.PackageName -match $SearchText -or
        $_.Description -match $SearchText -or
        $_.Category -match $SearchText
    }

    Populate-ListView -ListView $ListView -Packages $filtered
}

function Remove-SelectedPackages {
    param([array]$Packages)

    # Check for essential packages
    $essential = $Packages | Where-Object SafetyRating -eq $Script:ESSENTIAL
    if ($essential) {
        [System.Windows.Forms.MessageBox]::Show(
            "Cannot remove ESSENTIAL packages:`n`n$($essential.PackageName -join "`n")",
            "Error",
            "OK",
            "Error"
        )
        return
    }

    $message = "You are about to remove $($Packages.Count) packages:`n`n"
    $message += ($Packages | Select-Object -First 10 | ForEach-Object { $_.PackageName }) -join "`n"
    if ($Packages.Count -gt 10) {
        $message += "`n... and $($Packages.Count - 10) more"
    }
    $message += "`n`nThis action can be undone by enabling packages later.`n`nContinue?"

    $result = [System.Windows.Forms.MessageBox]::Show($message, "Confirm Removal", "YesNo", "Warning")

    if ($result -eq "Yes") {
        $removed = @()
        foreach ($pkg in $Packages) {
            if (Remove-Package -PackageName $pkg.PackageName) {
                $removed += $pkg
            }
        }

        if ($removed.Count -gt 0) {
            Save-RemovalLog -RemovedPackages $removed
            [System.Windows.Forms.MessageBox]::Show(
                "Successfully removed $($removed.Count) of $($Packages.Count) packages.",
                "Complete",
                "OK",
                "Information"
            )
        }
    }
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

function Main {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  ANDROID PACKAGE ANALYZER v$Script:Version" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""

    # Find ADB
    Write-Log "Searching for ADB..." -Level INFO
    $Script:AdbPath = Find-ADB

    if (-not $Script:AdbPath) {
        Write-Log "ADB not found! Please install Android Platform Tools." -Level ERROR
        Write-Host "`nDownload from: https://developer.android.com/studio/releases/platform-tools" -ForegroundColor Yellow
        return
    }

    Write-Log "Found ADB: $Script:AdbPath" -Level SUCCESS

    # Test device connection
    Write-Log "Checking device connection..." -Level INFO

    if (-not (Test-DeviceConnection)) {
        Write-Log "No device connected or device unauthorized!" -Level ERROR
        Write-Host "`nPlease:" -ForegroundColor Yellow
        Write-Host "  1. Connect your Android device via USB" -ForegroundColor Gray
        Write-Host "  2. Enable USB debugging in Developer Options" -ForegroundColor Gray
        Write-Host "  3. Accept the USB debugging prompt on the device" -ForegroundColor Gray
        return
    }

    Write-Log "Connected to device: $Script:DeviceSerial" -Level SUCCESS

    # Check root
    $rootCheck = Invoke-AdbShell "su -c 'id'"
    if ($rootCheck -match "uid=0") {
        Write-Log "Root access confirmed" -Level SUCCESS
    } else {
        Write-Log "Device may not be rooted - some operations may fail" -Level WARNING
    }

    # Analyze packages
    Write-Host ""
    $packages = Get-AllPackages
    Write-Log "Found $($packages.Count) packages" -Level SUCCESS

    # Analyze services
    $services = Get-RunningServices
    Write-Log "Found $($services.Count) running services" -Level SUCCESS

    # Summary
    Write-Host ""
    Write-Host "===== ANALYSIS SUMMARY =====" -ForegroundColor Cyan
    Write-Host ""

    $categories = $packages | Group-Object Category | Sort-Object Count -Descending
    foreach ($cat in $categories) {
        Write-Host "  $($cat.Name): $($cat.Count)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "Safety Ratings:" -ForegroundColor Yellow
    Write-Host "  ESSENTIAL (Do not remove): $(($packages | Where-Object SafetyRating -eq $Script:ESSENTIAL).Count)" -ForegroundColor Red
    Write-Host "  KEEP (Important): $(($packages | Where-Object SafetyRating -eq $Script:KEEP).Count)" -ForegroundColor Yellow
    Write-Host "  REVIEW (Check manually): $(($packages | Where-Object SafetyRating -eq $Script:REVIEW).Count)" -ForegroundColor DarkYellow
    Write-Host "  SAFE TO REMOVE: $(($packages | Where-Object SafetyRating -eq $Script:SAFE_TO_REMOVE).Count)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Telemetry packages: $(($packages | Where-Object IsTelemetry).Count)" -ForegroundColor Magenta
    Write-Host ""

    # Export only mode
    if ($ExportOnly) {
        Write-Log "Export-only mode - generating reports..." -Level INFO
        Export-HTMLReport -Packages $packages -Services $services
        Export-CSV -Packages $packages
        Backup-PackageList -Packages $packages
        Write-Log "Reports saved to: $Script:ReportPath" -Level SUCCESS
        return
    }

    # Launch GUI
    if (-not $NoGui) {
        Write-Log "Launching GUI..." -Level INFO
        Show-MainMenu -Packages $packages -Services $services
    } else {
        # Console mode - show menu
        Write-Host "Options:" -ForegroundColor Cyan
        Write-Host "  1. Export HTML Report"
        Write-Host "  2. Export CSV"
        Write-Host "  3. Show Safe-to-Remove packages"
        Write-Host "  4. Show Telemetry packages"
        Write-Host "  5. Remove all telemetry"
        Write-Host "  6. Exit"
        Write-Host ""

        $choice = Read-Host "Select option"

        switch ($choice) {
            "1" { Export-HTMLReport -Packages $packages -Services $services | ForEach-Object { Start-Process $_ } }
            "2" { Export-CSV -Packages $packages }
            "3" { $packages | Where-Object SafetyRating -eq $Script:SAFE_TO_REMOVE | Format-Table PackageName, Description -AutoSize }
            "4" { $packages | Where-Object IsTelemetry | Format-Table PackageName, Description, IsEnabled -AutoSize }
            "5" {
                $telemetry = $packages | Where-Object { $_.IsTelemetry -and $_.IsEnabled -and $_.SafetyRating -ne $Script:ESSENTIAL }
                foreach ($pkg in $telemetry) {
                    Remove-Package -PackageName $pkg.PackageName
                }
            }
        }
    }
}

# Run
Main
