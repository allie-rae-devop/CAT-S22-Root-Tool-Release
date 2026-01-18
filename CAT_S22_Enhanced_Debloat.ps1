# ============================================================================
# CAT S22 ENHANCED DEBLOAT & APP INSTALLER
# Remove bloatware + Install privacy-focused alternatives
# ============================================================================

function Get-AlternativeApps {
    $apps = @{
        "F-Droid" = @{
            Name = "F-Droid App Store"
            Description = "Open-source app store (install first!)"
            URL = "https://f-droid.org/F-Droid.apk"
            Essential = $true
        }
        
        "Aurora Store" = @{
            Name = "Aurora Store"
            Description = "Anonymous Google Play Store client"
            URL = "https://gitlab.com/AuroraOSS/AuroraStore/-/releases/permalink/latest/downloads/binaries/AuroraStore.apk"
            FDroid = "com.aurora.store"
        }
        
        "Simple Keyboard" = @{
            Name = "Simple Keyboard"
            Description = "Lightweight keyboard with T9 support"
            FDroid = "rkr.simplekeyboard.inputmethod"
        }
        
        "Traditional T9" = @{
            Name = "Traditional T9"
            Description = "Classic T9 predictive text"
            FDroid = "io.github.sspanak.tt9"
            Recommended = $true
        }
        
        "Simple SMS Messenger" = @{
            Name = "Simple SMS Messenger"
            Description = "Clean, ad-free SMS app"
            FDroid = "com.simplemobiletools.smsmessenger"
        }
        
        "Fossify Contacts" = @{
            Name = "Fossify Contacts"
            Description = "Privacy-focused contacts app"
            FDroid = "org.fossify.contacts"
        }
        
        "Fossify Phone" = @{
            Name = "Fossify Phone"
            Description = "Privacy-focused dialer"
            FDroid = "org.fossify.phone"
        }
        
        "Fossify Gallery" = @{
            Name = "Fossify Gallery"
            Description = "Privacy-focused photo gallery"
            FDroid = "org.fossify.gallery"
        }
        
        "Simple File Manager" = @{
            Name = "Simple File Manager"
            Description = "Clean file browser"
            FDroid = "com.simplemobiletools.filemanager.pro"
        }
        
        "K-9 Mail" = @{
            Name = "K-9 Mail"
            Description = "Open-source email client (works with Proton Bridge)"
            FDroid = "com.fsck.k9"
        }
        
        "Organic Maps" = @{
            Name = "Organic Maps"
            Description = "Offline maps (OpenStreetMap)"
            FDroid = "app.organicmaps"
        }
        
        "NewPipe" = @{
            Name = "NewPipe"
            Description = "YouTube without Google (no ads, background play)"
            FDroid = "org.schabi.newpipe"
            Recommended = $true
        }
        
        "Aegis Authenticator" = @{
            Name = "Aegis Authenticator"
            Description = "2FA authenticator"
            FDroid = "com.beemdevelopment.aegis"
        }
        
        "Bitwarden" = @{
            Name = "Bitwarden"
            Description = "Open-source password manager"
            URL = "https://vault.bitwarden.com/download/?app=mobile&platform=android"
        }
        
        "ProtonMail" = @{
            Name = "Proton Mail"
            Description = "Encrypted email (requires APK from Proton)"
            URL = "https://protonapps.com/protonmail-android"
        }
        
        "ProtonVPN" = @{
            Name = "Proton VPN"
            Description = "Encrypted VPN"
            URL = "https://protonapps.com/protonvpn-android"
        }
    }
    
    return $apps
}

function Show-AppInstallerWizard {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Install Alternative Apps"
    $form.Size = New-Object System.Drawing.Size(700, 600)
    $form.StartPosition = "CenterScreen"
    
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(680, 60)
    $label.Text = "Select alternative apps to install:`n(F-Droid will be installed first, then apps from F-Droid, then direct APKs)"
    $form.Controls.Add($label)
    
    # Scrollable panel
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(10, 80)
    $panel.Size = New-Object System.Drawing.Size(660, 440)
    $panel.AutoScroll = $true
    $form.Controls.Add($panel)
    
    $apps = Get-AlternativeApps
    $checkboxes = @{}
    $yPos = 10
    
    foreach ($appKey in $apps.Keys | Sort-Object) {
        $app = $apps[$appKey]
        
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Location = New-Object System.Drawing.Point(10, $yPos)
        $checkbox.Size = New-Object System.Drawing.Size(630, 50)
        
        $text = "$($app.Name)"
        if ($app.Recommended) { $text = "⭐ $text" }
        if ($app.Essential) { $text = "🔧 $text (INSTALL FIRST)" }
        $text += "`n   $($app.Description)"
        
        $checkbox.Text = $text
        
        if ($app.Essential -or $app.Recommended) {
            $checkbox.Checked = $true
            $checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        }
        
        $checkbox.Tag = $app
        $checkboxes[$appKey] = $checkbox
        $panel.Controls.Add($checkbox)
        
        $yPos += 60
    }
    
    # Buttons
    $installBtn = New-Object System.Windows.Forms.Button
    $installBtn.Location = New-Object System.Drawing.Point(480, 530)
    $installBtn.Size = New-Object System.Drawing.Size(100, 30)
    $installBtn.Text = "Install"
    $installBtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($installBtn)
    
    $cancelBtn = New-Object System.Windows.Forms.Button
    $cancelBtn.Location = New-Object System.Drawing.Point(590, 530)
    $cancelBtn.Size = New-Object System.Drawing.Size(80, 30)
    $cancelBtn.Text = "Skip"
    $cancelBtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelBtn)
    
    $result = $form.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selected = @()
        foreach ($key in $checkboxes.Keys) {
            if ($checkboxes[$key].Checked) {
                $selected += @{
                    Key = $key
                    App = $checkboxes[$key].Tag
                }
            }
        }
        return $selected
    }
    
    return $null
}

function Install-AlternativeApps {
    param([array]$SelectedApps)
    
    if (-not $SelectedApps -or $SelectedApps.Count -eq 0) {
        Write-Log "No apps selected for installation" -Level INFO
        return $true
    }
    
    # Step 1: Install F-Droid first if selected
    $fdroidApp = $SelectedApps | Where-Object { $_.Key -eq "F-Droid" }
    if ($fdroidApp) {
        Write-Log "Installing F-Droid..." -Level INFO
        
        $fdroidPath = Join-Path $env:TEMP "F-Droid.apk"
        
        try {
            Invoke-WebRequest -Uri $fdroidApp.App.URL -OutFile $fdroidPath -UseBasicParsing
            $result = Invoke-ADBCommand -Command "install -r `"$fdroidPath`""
            
            if ($result.Success) {
                Write-Log "F-Droid installed successfully" -Level SUCCESS
            }
            else {
                Write-Log "F-Droid installation failed" -Level ERROR
            }
        }
        catch {
            Write-Log "Failed to download F-Droid: $_" -Level ERROR
        }
        
        # Wait for F-Droid to initialize
        Start-Sleep -Seconds 5
    }
    
    # Step 2: Install apps with direct URLs
    $directApps = $SelectedApps | Where-Object { $_.App.URL -and $_.Key -ne "F-Droid" }
    foreach ($item in $directApps) {
        Write-Log "Installing $($item.App.Name)..." -Level INFO
        
        $apkPath = Join-Path $env:TEMP "$($item.Key).apk"
        
        try {
            Invoke-WebRequest -Uri $item.App.URL -OutFile $apkPath -UseBasicParsing
            $result = Invoke-ADBCommand -Command "install -r `"$apkPath`""
            
            if ($result.Success) {
                Write-Log "$($item.App.Name) installed" -Level SUCCESS
            }
            else {
                Write-Log "$($item.App.Name) installation failed" -Level WARNING
            }
        }
        catch {
            Write-Log "Failed to download $($item.App.Name): $_" -Level ERROR
        }
    }
    
    # Step 3: Show instructions for F-Droid apps
    $fdroidApps = $SelectedApps | Where-Object { $_.App.FDroid }
    if ($fdroidApps.Count -gt 0) {
        $fdroidList = $fdroidApps | ForEach-Object { "  • $($_.App.Name)" }
        
        Show-UserPrompt -Title "Install from F-Droid" -Message @"
The following apps need to be installed from F-Droid:

$($fdroidList -join "`n")

MANUAL STEPS:
1. Open F-Droid app on your phone
2. Update repositories (wait ~1 minute)
3. Search for each app by name
4. Install them

These apps are open-source and privacy-focused alternatives!

Click OK when done (or to continue anyway).
"@ | Out-Null
    }
    
    Write-Log "App installation complete!" -Level SUCCESS
    return $true
}

function Start-EnhancedDebloat {
    Write-Log "=== Starting Enhanced Debloat Wizard ===" -Level INFO
    
    # Step 1: Debloat
    $doDeb loat = Show-UserPrompt -Title "Debloat Device" -Message @"
Would you like to remove bloatware from your rooted device?

This includes:
• T-Mobile/Sprint apps
• Unnecessary Google apps (keeps Play Store/Services)
• Facebook services
• Other bloat

Click OK to start debloat wizard
Click Cancel to skip
"@
    
    if ($doDebloat) {
        $categories = Show-CategorySelection
        if ($categories) {
            Remove-BloatwarePackages -Categories $categories
        }
    }
    
    # Step 2: Install Alternative Apps
    $doApps = Show-UserPrompt -Title "Install Alternative Apps" -Message @"
Would you like to install privacy-focused alternative apps?

Available:
• F-Droid (open-source app store)
• Traditional T9 keyboard
• Simple SMS/Contacts/Dialer
• NewPipe (YouTube alternative)
• Proton apps support
• And more!

Click OK to select apps
Click Cancel to skip
"@
    
    if ($doApps) {
        $selectedApps = Show-AppInstallerWizard
        if ($selectedApps) {
            Install-AlternativeApps -SelectedApps $selectedApps
        }
    }
    
    # Step 3: Final optimization
    Show-UserPrompt -Title "Debloat Complete" -Message @"
Post-root setup complete!

Recommendations:
1. Reboot device for all changes to take effect
2. Configure your new apps (F-Droid, T9 keyboard, etc.)
3. Set default apps (Settings → Apps → Default apps)
4. Disable Google backup if desired
5. Install Proton apps if using Proton services

Reboot now?
"@ | Out-Null
    
    Write-Log "Enhanced debloat complete!" -Level SUCCESS
}

Export-ModuleMember -Function Start-EnhancedDebloat
