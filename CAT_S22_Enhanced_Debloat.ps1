# ============================================================================
# CAT S22 ENHANCED DEBLOAT & APP INSTALLER - STANDALONE
# Remove bloatware + Install privacy-focused alternatives
# Run this AFTER rooting with CAT_S22_Root_Tool.ps1
# ============================================================================

#Requires -Version 5.1

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Find ADB executable
$Script:AdbPath = $null
$possiblePaths = @(
    "C:\Users\allie\CAT_S22_Root\tools\platform-tools\adb.exe",
    "$PSScriptRoot\..\CAT_S22_Root\tools\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "adb.exe"  # Try PATH as fallback
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        $Script:AdbPath = $path
        break
    }
}

if (-not $Script:AdbPath) {
    # Try to find in PATH
    try {
        $null = & adb version 2>&1
        $Script:AdbPath = "adb"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "ADB not found!`n`nPlease run CAT_S22_Root_Tool.ps1 first to set up ADB, or ensure platform-tools is in your PATH.",
            "ADB Not Found",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        exit
    }
}

Write-Host "Using ADB: $Script:AdbPath" -ForegroundColor Cyan

# Helper function: Write colored log messages
function Write-ColorLog {
    param(
        [string]$Message,
        [ValidateSet("INFO","SUCCESS","WARNING","ERROR")]
        [string]$Level = "INFO"
    )
    
    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Helper function: Show user prompt dialog
function Show-Prompt {
    param(
        [string]$Title,
        [string]$Message
    )
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OKCancel,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    return ($result -eq [System.Windows.Forms.DialogResult]::OK)
}

# Check ADB connection
function Test-ADB {
    try {
        $devices = & $Script:AdbPath devices 2>&1 | Out-String
        Write-ColorLog "ADB devices output: $devices" -Level INFO
        
        # Check if any device is connected (not just authorized)
        if ($devices -match "\t(device|unauthorized)") {
            if ($devices -match "unauthorized") {
                Write-ColorLog "Device connected but unauthorized - please authorize on phone" -Level WARNING
                return $true  # Device is there, just not authorized yet
            }
            return $true
        }
        
        return $false
    }
    catch {
        Write-ColorLog "ADB check failed: $_" -Level ERROR
        return $false
    }
}

# Get debloat categories with package lists
function Get-DebloatCategories {
    return @{
        "T-Mobile/Sprint Bloat" = @(
            "com.tmobile.pr.adapt",
            "com.tmobile.echolocate",
            "com.tmobile.pr.mytmobile",
            "com.tmobile.tmoplay",
            "com.tmobile.tuesdays",
            "com.tmobile.services.nameid",
            "com.tmobile.appselector",
            "com.sprint.zone",
            "com.sprint.dsa",
            "com.Sprint.ce.updater",
            "com.nuance.xt9.input",           # T-Mobile keyboard
            "com.asurion.android.vms",        # Visual Voicemail
            "com.sec.vsim.ericssonnsds.webapp" # T-Mobile TDC
        )
        
        "Google Apps - Core Removal" = @(
            "com.google.android.googlequicksearchbox",  # Google Search/Assistant
            "com.google.android.apps.searchlite",       # Google Go
            "com.android.chrome",                       # Chrome
            "com.google.android.apps.messaging",        # Google Messages
            "com.google.android.dialer",                # Google Phone
            "com.google.android.contacts",              # Google Contacts
            "com.google.android.apps.photos",           # Google Photos
            "com.google.android.apps.docs",             # Google Drive
            "com.google.android.youtube",               # YouTube
            "com.google.android.apps.youtube.music",    # YouTube Music
            "com.google.android.gm",                    # Gmail
            "com.google.android.calendar",              # Google Calendar
            "com.google.android.apps.tachyon",          # Google Duo
            "com.google.android.keep",                  # Google Keep
            "com.google.android.apps.wellbeing",        # Digital Wellbeing
            "com.google.ar.lens",                       # Google Lens
            "com.google.android.marvin.talkback",       # Talkback
            "com.google.android.tts",                   # Google TTS
            "com.google.android.apps.turbo",            # Device Health Services
            "com.google.android.partnersetup",          # Google Partner Setup
            "com.google.android.printservice.recommendation", # Print service
            "com.google.android.feedback",              # Google Feedback
            "com.google.mainline.telemetry"            # Google Telemetry
        )
        
        "Google Apps - Keep Essentials" = @(
            "com.google.android.apps.searchlite",       # Google Go
            "com.android.chrome",                       # Chrome
            "com.google.android.apps.messaging",        # Messages (will replace)
            "com.google.android.dialer",                # Phone (will replace)
            "com.google.android.apps.photos",           # Photos (will replace)
            "com.google.android.youtube",               # YouTube (will replace with NewPipe)
            "com.google.android.apps.youtube.music",    # YouTube Music
            "com.google.android.gm",                    # Gmail (will replace with K-9)
            "com.google.android.keep"                   # Keep Notes
        )
        
        "System Bloat" = @(
            "com.facebook.system",
            "com.facebook.appmanager",
            "com.facebook.services",
            "com.facebook.katana",
            "com.android.vending.billing.InAppBillingService.COIN", # Google billing
            "com.google.android.apps.walletnfcrel"      # Google Wallet
        )
    }
}

# Show category selection dialog
function Show-CategoryDialog {
    $categories = Get-DebloatCategories
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Select Bloatware to Remove"
    $form.Size = New-Object System.Drawing.Size(500, 400)
    $form.StartPosition = "CenterScreen"
    
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(480, 30)
    $label.Text = "Select categories of bloatware to remove:"
    $form.Controls.Add($label)
    
    $checkboxes = @{}
    $yPos = 50
    
    foreach ($category in $categories.Keys) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Location = New-Object System.Drawing.Point(20, $yPos)
        $checkbox.Size = New-Object System.Drawing.Size(460, 40)
        $checkbox.Text = "$category ($($categories[$category].Count) apps)"
        $checkbox.Checked = $true
        $checkboxes[$category] = $checkbox
        $form.Controls.Add($checkbox)
        $yPos += 50
    }
    
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(300, 320)
    $okButton.Size = New-Object System.Drawing.Size(80, 30)
    $okButton.Text = "Remove"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)
    
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(390, 320)
    $cancelButton.Size = New-Object System.Drawing.Size(80, 30)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    
    $result = $form.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selected = @()
        foreach ($cat in $checkboxes.Keys) {
            if ($checkboxes[$cat].Checked) {
                $selected += $cat
            }
        }
        return $selected
    }
    
    return $null
}

# Remove bloatware packages
function Remove-Bloat {
    param([array]$Categories)
    
    $allCategories = Get-DebloatCategories
    $packagesToRemove = @()
    
    foreach ($category in $Categories) {
        if ($allCategories.ContainsKey($category)) {
            $packagesToRemove += $allCategories[$category]
        }
    }
    
    $packagesToRemove = $packagesToRemove | Select-Object -Unique
    
    Write-ColorLog "Removing $($packagesToRemove.Count) bloatware packages..." -Level INFO
    
    $removed = 0
    $failed = 0
    
    foreach ($package in $packagesToRemove) {
        Write-Host "  Removing: $package..." -NoNewline
        
        $result = & $Script:AdbPath shell pm uninstall --user 0 $package 2>&1
        
        if ($result -match "Success" -or $LASTEXITCODE -eq 0) {
            Write-Host " SUCCESS" -ForegroundColor Green
            $removed++
        }
        else {
            $disableResult = & $Script:AdbPath shell pm disable-user --user 0 $package 2>&1
            if ($disableResult -match "disabled") {
                Write-Host " DISABLED" -ForegroundColor Green
                $removed++
            }
            else {
                Write-Host " FAILED" -ForegroundColor Red
                $failed++
            }
        }
    }
    
    Write-ColorLog "Debloat complete! Removed: $removed, Failed: $failed" -Level SUCCESS
}

# Get alternative apps list
function Get-AlternativeApps {
    return @(
        @{Name="F-Droid"; URL="https://f-droid.org/F-Droid.apk"; Essential=$true; Description="Open-source app store"}
        @{Name="Aurora Store"; FDroid="com.aurora.store"; Recommended=$true; Description="Anonymous Google Play client"}
        
        # Messaging & Communication
        @{Name="Signal"; URL="https://signal.org/android/apk/"; Recommended=$true; Description="Encrypted messaging (replaces Google Messages)"}
        @{Name="QKSMS"; FDroid="com.moez.QKSMS"; Recommended=$true; Description="Beautiful SMS app (replaces Google Messages)"}
        @{Name="Simple SMS Messenger"; FDroid="com.simplemobiletools.smsmessenger"; Description="Lightweight SMS app"}
        
        # Phone & Contacts
        @{Name="Simple Dialer"; FDroid="com.simplemobiletools.dialer"; Recommended=$true; Description="Replaces Google Phone"}
        @{Name="Simple Contacts"; FDroid="com.simplemobiletools.contacts.pro"; Recommended=$true; Description="Replaces Google Contacts"}
        
        # Keyboard (T9 for flip phone!)
        @{Name="Traditional T9"; FDroid="io.github.sspanak.tt9"; Recommended=$true; Description="Perfect T9 keyboard for flip phone"}
        @{Name="Simple Keyboard"; FDroid="rkr.simplekeyboard.inputmethod"; Description="Lightweight keyboard"}
        
        # Media & Gallery
        @{Name="Simple Gallery"; FDroid="com.simplemobiletools.gallery.pro"; Recommended=$true; Description="Replaces Google Photos"}
        @{Name="NewPipe"; FDroid="org.schabi.newpipe"; Recommended=$true; Description="YouTube without Google (no ads!)"}
        @{Name="VLC"; FDroid="org.videolan.vlc"; Description="Media player"}
        
        # Files & Productivity
        @{Name="Simple File Manager"; FDroid="com.simplemobiletools.filemanager.pro"; Recommended=$true; Description="Replaces Google Files"}
        @{Name="Markor"; FDroid="net.gsantner.markor"; Description="Notes app (replaces Google Keep)"}
        @{Name="Notesnook"; URL="https://notesnook.com/"; Description="Encrypted notes"}
        
        # Email
        @{Name="K-9 Mail"; FDroid="com.fsck.k9"; Recommended=$true; Description="Replaces Gmail, works with Proton Bridge"}
        @{Name="FairEmail"; FDroid="eu.faircode.email"; Description="Privacy-focused email"}
        
        # Browser
        @{Name="Fennec F-Droid"; FDroid="org.mozilla.fennec_fdroid"; Recommended=$true; Description="Firefox without Google (replaces Chrome)"}
        @{Name="Bromite"; URL="https://www.bromite.org/"; Description="Privacy Chromium"}
        
        # Maps & Navigation
        @{Name="Organic Maps"; FDroid="app.organicmaps"; Recommended=$true; Description="Offline maps"}
        @{Name="OsmAnd"; FDroid="net.osmand.plus"; Description="Advanced offline maps"}
        
        # Security & Privacy
        @{Name="Aegis Authenticator"; FDroid="com.beemdevelopment.aegis"; Recommended=$true; Description="2FA app"}
        @{Name="Bitwarden"; URL="https://vault.bitwarden.com/download/?app=mobile&platform=android"; Description="Password manager"}
        
        # Calendar
        @{Name="Simple Calendar"; FDroid="com.simplemobiletools.calendar.pro"; Recommended=$true; Description="Replaces Google Calendar"}
        @{Name="Etar"; FDroid="ws.xsoh.etar"; Description="Material calendar"}
        
        # Camera
        @{Name="Open Camera"; FDroid="net.sourceforge.opencamera"; Description="Advanced camera app"}
    )
}

# Show app selection dialog
function Show-AppDialog {
    $apps = Get-AlternativeApps
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Install Alternative Apps"
    $form.Size = New-Object System.Drawing.Size(700, 600)
    $form.StartPosition = "CenterScreen"
    
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(680, 40)
    $label.Text = "Select apps to install (F-Droid will be installed first):`nRecommended apps replace Google defaults"
    $form.Controls.Add($label)
    
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(10, 60)
    $panel.Size = New-Object System.Drawing.Size(660, 470)
    $panel.AutoScroll = $true
    $form.Controls.Add($panel)
    
    $checkboxes = @()
    $yPos = 5
    
    foreach ($app in $apps) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Location = New-Object System.Drawing.Point(10, $yPos)
        $checkbox.Size = New-Object System.Drawing.Size(630, 45)
        
        $text = $app.Name
        if ($app.Recommended) { $text = "[RECOMMENDED] $text" }
        if ($app.Essential) { $text = "[ESSENTIAL] $text" }
        if ($app.Description) { $text += "`n   $($app.Description)" }
        
        $checkbox.Text = $text
        $checkbox.Checked = ($app.Essential -or $app.Recommended)
        $checkbox.Tag = $app
        
        if ($app.Essential) {
            $checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        }
        
        $checkboxes += $checkbox
        $panel.Controls.Add($checkbox)
        $yPos += 50
    }
    
    # Select All / Deselect All buttons
    $selectAllBtn = New-Object System.Windows.Forms.Button
    $selectAllBtn.Location = New-Object System.Drawing.Point(300, 540)
    $selectAllBtn.Size = New-Object System.Drawing.Size(90, 30)
    $selectAllBtn.Text = "Select All"
    $selectAllBtn.Add_Click({
        foreach ($cb in $checkboxes) { $cb.Checked = $true }
    })
    $form.Controls.Add($selectAllBtn)
    
    $deselectAllBtn = New-Object System.Windows.Forms.Button
    $deselectAllBtn.Location = New-Object System.Drawing.Point(400, 540)
    $deselectAllBtn.Size = New-Object System.Drawing.Size(90, 30)
    $deselectAllBtn.Text = "Deselect All"
    $deselectAllBtn.Add_Click({
        foreach ($cb in $checkboxes) { 
            if (-not $cb.Tag.Essential) { $cb.Checked = $false }
        }
    })
    $form.Controls.Add($deselectAllBtn)
    
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(500, 540)
    $okButton.Size = New-Object System.Drawing.Size(80, 30)
    $okButton.Text = "Install"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)
    
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(590, 540)
    $cancelButton.Size = New-Object System.Drawing.Size(80, 30)
    $cancelButton.Text = "Skip"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)
    
    $result = $form.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return ($checkboxes | Where-Object { $_.Checked } | ForEach-Object { $_.Tag })
    }
    
    return $null
}

# Install apps
function Install-Apps {
    param([array]$SelectedApps)
    
    if (-not $SelectedApps -or $SelectedApps.Count -eq 0) {
        return
    }
    
    # Install F-Droid first
    $fdroid = $SelectedApps | Where-Object { $_.Name -eq "F-Droid" }
    if ($fdroid) {
        Write-ColorLog "Installing F-Droid..." -Level INFO
        try {
            $apkPath = "$env:TEMP\F-Droid.apk"
            Invoke-WebRequest -Uri $fdroid.URL -OutFile $apkPath -UseBasicParsing
            & $Script:AdbPath install -r $apkPath 2>&1 | Out-Null
            Write-ColorLog "F-Droid installed!" -Level SUCCESS
            Start-Sleep -Seconds 3
        }
        catch {
            Write-ColorLog "Failed to install F-Droid: $_" -Level ERROR
        }
    }
    
    # Show F-Droid app list
    $fdroidApps = $SelectedApps | Where-Object { $_.FDroid }
    if ($fdroidApps) {
        $appList = ($fdroidApps | ForEach-Object { "  - $($_.Name)" }) -join "`n"
        
        [System.Windows.Forms.MessageBox]::Show(
            "Install these apps from F-Droid:`n`n$appList`n`nSteps:`n1. Open F-Droid`n2. Update repositories`n3. Search and install each app",
            "Manual F-Droid Installation",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
    
    Write-ColorLog "App installation complete!" -Level SUCCESS
}

# Main workflow
function Start-Debloat {
    Write-ColorLog "=== CAT S22 Enhanced Debloat Tool ===" -Level INFO
    
    # Check ADB
    if (-not (Test-ADB)) {
        [System.Windows.Forms.MessageBox]::Show(
            "No rooted device detected via ADB.`n`nPlease:`n1. Connect your rooted CAT S22`n2. Enable USB debugging`n3. Authorize this computer",
            "Device Not Connected",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }
    
    # Step 1: Debloat
    if (Show-Prompt -Title "Remove Bloatware" -Message "Remove T-Mobile/Google bloatware?`n`nThis will:`n- Remove carrier apps`n- Remove unnecessary Google apps`n- Keep Play Store & Services") {
        $categories = Show-CategoryDialog
        if ($categories) {
            Remove-Bloat -Categories $categories
        }
    }
    
    # Step 2: Install Apps
    if (Show-Prompt -Title "Install Alternative Apps" -Message "Install privacy-focused apps?`n`nIncludes:`n- F-Droid app store`n- Traditional T9 keyboard`n- Simple SMS/Contacts`n- NewPipe (YouTube)") {
        $apps = Show-AppDialog
        if ($apps) {
            Install-Apps -SelectedApps $apps
        }
    }
    
    # Done
    $reboot = Show-Prompt -Title "Complete!" -Message "Debloat complete!`n`nRecommendations:`n- Reboot device`n- Configure new apps`n- Set default apps`n`nReboot now?"
    if ($reboot) {
        & $Script:AdbPath reboot
    }
    
    Write-ColorLog "Debloat wizard complete!" -Level SUCCESS
}

# Run the wizard
Start-Debloat
