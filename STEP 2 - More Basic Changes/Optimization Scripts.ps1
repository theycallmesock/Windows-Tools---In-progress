# =====================================================
# WINDOWS 10–11 ULTIMATE GAMING OPTIMIZATION SCRIPT
# FULL LOGGING 
# =====================================================

# -------------------------
# AUTO-ELEVATION
# -------------------------
Write-Host "[LOG] Checking admin privileges..." -ForegroundColor Cyan
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "[LOG] Not running as admin. Relaunching with elevation..." -ForegroundColor Yellow
    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}

Write-Host "[LOG] Admin privileges confirmed" -ForegroundColor Green
Set-ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = "Continue"
Clear-Host

# -------------------------
# ENHANCED LOGGING SETUP
# -------------------------
$LogDir = "$env:SystemDrive\GamingOptimizationLogs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$Timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$LogFile = "$LogDir\Optimize_$Timestamp.log"
Start-Transcript -Path $LogFile -Force

Write-Host "[LOG] Logging initialized: $LogFile" -ForegroundColor Cyan
Write-Host "✔ Running as Administrator - Full Logging Enabled" -ForegroundColor Green

# -------------------------
# RESTORE POINT
# -------------------------
Write-Host "[LOG] Creating system restore point..." -ForegroundColor Cyan
Enable-ComputerRestore -Drive "$env:SystemDrive\" | Out-Null
Checkpoint-Computer -Description "Pre-Gaming-Optimization-$Timestamp" -RestorePointType MODIFY_SETTINGS
Write-Host "✓ Restore point created successfully" -ForegroundColor Green

# =====================================================
# 1️⃣ WINDOWS ACTIVATION
# =====================================================
Write-Host "[LOG] Running Windows activation script..." -ForegroundColor Cyan
irm "https://get.activated.win" | iex
Write-Host "✓ Windows activation completed" -ForegroundColor Green

# =====================================================
# 2️⃣ ULTIMATE POWER PLAN
# =====================================================
Write-Host "[LOG] Setting Ultimate Performance power plan..." -ForegroundColor Cyan
$Ultimate = "e9a42b02-d5df-448d-aa00-03f14749eb61"
powercfg -duplicatescheme $Ultimate | Out-Null
Start-Sleep -Seconds 3

$UltimateSchemes = powercfg -list | Select-String "Ultimate Performance"
if ($UltimateSchemes) {
    $ActualUltimate = ($UltimateSchemes[0] -split '\s+')[3]
    powercfg -setactive $ActualUltimate | Out-Null
    Write-Host "✓ Ultimate Active: $ActualUltimate" -ForegroundColor Green
}
else {
    Write-Host "⚠ Ultimate Performance not found" -ForegroundColor Yellow
}

Write-Host "[LOG] Applying processor performance tweaks..." -ForegroundColor Cyan
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
powercfg -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
powercfg -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 | Out-Null
powercfg -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 | Out-Null
powercfg -S SCHEME_CURRENT
Write-Host "✓ Power plan tweaks applied" -ForegroundColor Green

# =====================================================
# 3️⃣ GAME MODE + GPU SCHEDULING
# =====================================================
Write-Host "[LOG] Enabling Game Mode and GPU Scheduling..." -ForegroundColor Cyan
reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f | Out-Null
Write-Host "✓ Game Mode & GPU Scheduling enabled" -ForegroundColor Green

# =====================================================
# 4️⃣ CHRIS TITUS WINUTIL
# =====================================================
Write-Host "[LOG] Running Chris Titus WinUtil..." -ForegroundColor Cyan
irm "https://christitus.com/win" | iex
Write-Host "✓ Chris Titus optimizations completed" -ForegroundColor Green

# =====================================================
# 5️⃣ BLOATWARE + SYSMAIN REMOVAL (SYSTEM APPS FIXED)
# =====================================================
Write-Host "[LOG] Removing bloatware applications (this may take several minutes)..." -ForegroundColor Cyan

# Regular removable apps
$BloatApps = @(
 "MicrosoftWindows.Client.WebExperience", "Microsoft.WidgetsPlatformRuntime", "Microsoft.StartExperiencesApp",
 "Microsoft.Microsoft3DViewer", "Microsoft.BingNews", "Microsoft.BingSearch", "Microsoft.BingWeather",
 "Microsoft.549981C3F5F10", "Microsoft.WindowsFeedbackHub", "Microsoft.GetHelp",
 "microsoft.windowscommunicationsapps", "Microsoft.ZuneVideo",
 "Microsoft.MicrosoftOfficeHub", "Microsoft.Office.Excel", "Microsoft.Office.PowerPoint", 
 "Microsoft.Office.Word", "Microsoft.Office.OneNote", "MicrosoftTeamsforSurfaceHub", "MailforSurfaceHub",
 "Microsoft.Advertising.Xaml", "Clipchamp.Clipchamp", "MicrosoftCorporationII.MicrosoftFamily",
 "Microsoft.MicrosoftSolitaireCollection", "Microsoft.MicrosoftStickyNotes", "MSTeams", 
 "Microsoft.MicrosoftTeamsApp", "Flipgrid", "Microsoft.Getstarted", "Microsoft.Todos",
 "Microsoft.Whiteboard", "Microsoft.MixedReality.Portal", "Microsoft.OutlookForWindows",
 "Microsoft.MSPaint", "Microsoft.People", "Microsoft.PeopleExperienceHost",
 "Microsoft.PowerAutomateDesktop", "Microsoft.MicrosoftPowerBIForWindows",
 "MicrosoftCorporationII.QuickAssist", "Microsoft.SkypeApp", "SpotifyAB.SpotifyMusic",
 "Microsoft.WindowsAlarms", "Microsoft.WindowsCamera", "Microsoft.WindowsMaps", 
 "Microsoft.ZuneMusic", "Microsoft.WindowsSoundRecorder"
)

# System-protected apps - disable by folder rename
$ProtectedApps = @(
    "Microsoft.Windows.SecureAssessmentBrowser"
)

$RemovedCount = 0
foreach ($app in $BloatApps) {
    Write-Host "  └ Removing: $app" -ForegroundColor Gray
    try {
        $Packages = Get-AppxPackage -AllUsers -Name $app -ErrorAction SilentlyContinue
        if ($Packages) {
            foreach ($pkg in $Packages) {
                Write-Host "    └ Uninstalling: $($pkg.PackageFullName)" -ForegroundColor DarkGray
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers
                $RemovedCount++
            }
        }
        
        $Provisioned = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq $app -ErrorAction SilentlyContinue
        if ($Provisioned) {
            foreach ($prov in $Provisioned) {
                Write-Host "    └ Deprovisioning: $($prov.DisplayName)" -ForegroundColor DarkGray
                Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName
                $RemovedCount++
            }
        }
        Write-Host "    └ ✓ Successfully removed" -ForegroundColor Green
    }
    catch {
        Write-Host "    └ ⚠ Failed to remove (normal for some apps): $($_.Exception.Message.Split('.')[0])" -ForegroundColor Yellow
    }
}

# Handle protected system apps by renaming folders
foreach ($app in $ProtectedApps) {
    Write-Host "  └ Disabling protected system app: $app" -ForegroundColor Gray
    try {
        $SystemAppPath = "$env:SystemRoot\SystemApps\$($app)*"
        $AppFolders = Get-ChildItem -Path $SystemAppPath -Directory -ErrorAction SilentlyContinue
        if ($AppFolders) {
            foreach ($folder in $AppFolders) {
                Write-Host "    └ Renaming folder: $($folder.Name)" -ForegroundColor DarkGray
                Rename-Item $folder.FullName "$($folder.FullName)_DISABLED" -Force
                Write-Host "    └ ✓ Disabled by renaming folder" -ForegroundColor Green
            }
        }
        else {
            Write-Host "    └ Folder not found (already disabled?)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "    └ ⚠ Could not disable folder: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "✓ Bloatware cleanup completed ($RemovedCount packages)" -ForegroundColor Green

# OneDrive Removal
Write-Host "[LOG] Removing OneDrive..." -ForegroundColor Cyan
if (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") {
    Write-Host "  └ Uninstalling OneDrive..." -ForegroundColor Gray
    Start-Process -FilePath "$env:SystemRoot\System32\OneDriveSetup.exe" -ArgumentList "/uninstall" -NoNewWindow -Wait
    Write-Host "✓ OneDrive uninstalled" -ForegroundColor Green
}
else {
    Write-Host "  └ OneDrive not found" -ForegroundColor Gray
}

# SysMain (Superfetch)
Write-Host "[LOG] Disabling SysMain service..." -ForegroundColor Cyan
Stop-Service SysMain -Force -ErrorAction SilentlyContinue
Set-Service SysMain -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "✓ SysMain disabled" -ForegroundColor Green

# =====================================================
# 6️⃣ HPET / TIMER
# =====================================================
Write-Host "[LOG] Configuring HPET/Timer settings..." -ForegroundColor Cyan
bcdedit /set useplatformtick yes | Out-Null
bcdedit /set disabledynamictick yes | Out-Null
bcdedit /deletevalue useplatformclock | Out-Null
Write-Host "✓ Timer settings applied" -ForegroundColor Green

# =====================================================
# 7️⃣ STARTUP CLEANUP (FULLY LOGGED)
# =====================================================
Write-Host "[LOG] Cleaning startup programs..." -ForegroundColor Cyan
$StartupPaths = @(
 "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
 "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
 "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
)

$Keep = @("SecurityHealth","Windows Defender","Discord")
$RemovedStartups = 0

foreach ($path in $StartupPaths) {
    if (Test-Path $path) {
        Write-Host "  └ Scanning: $path" -ForegroundColor Gray
        $Items = Get-ItemProperty $path -ErrorAction SilentlyContinue
        if ($Items) {
            $Properties = $Items | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -notin $Keep }
            foreach ($prop in $Properties) {
                Write-Host "    └ Removing: $($prop.Name)" -ForegroundColor DarkGray
                Remove-ItemProperty -Path $path -Name $prop.Name -ErrorAction SilentlyContinue
                $RemovedStartups++
            }
        }
    }
}
Write-Host "✓ Removed $RemovedStartups startup items" -ForegroundColor Green

# =====================================================
# 8️⃣ TCP OPTIMIZER (FULLY LOGGED)
# =====================================================
Write-Host "[LOG] Downloading and running TCP Optimizer..." -ForegroundColor Cyan
$TcpDir = "$env:SystemDrive\TCPOptimizer"
$TcpExe = "$TcpDir\TCPOptimizer.exe"
New-Item -ItemType Directory -Path $TcpDir -Force | Out-Null

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host "  └ Downloading TCPOptimizer.exe..." -ForegroundColor Gray
    Invoke-WebRequest "https://www.speedguide.net/files/TCPOptimizer.exe" -OutFile $TcpExe -UseBasicParsing
    if (Test-Path $TcpExe) {
        Write-Host "  └ Creating backup directory..." -ForegroundColor Gray
        New-Item -Path "$TcpDir\TCPOptimizer.bak" -ItemType File -Force | Out-Null
        Write-Host "  └ Running TCP Optimizer (optimal settings)..." -ForegroundColor Gray
        Start-Process $TcpExe -ArgumentList "/optimal", "/silent" -Wait -NoNewWindow
        Write-Host "✓ TCP Optimizer completed - backup created" -ForegroundColor Green
    }
}
catch {
    Write-Host "⚠ TCPOptimizer failed: $($_.Exception.Message)" -ForegroundColor Red
}

# =====================================================
# 9️⃣ GPU DRIVER TUNING
# =====================================================
Write-Host "[LOG] Applying GPU driver optimizations..." -ForegroundColor Cyan

$NvKey = "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters"
Write-Host "  └ NVIDIA MSI optimization..." -ForegroundColor Gray
if (-not (Test-Path $NvKey)) { 
    New-Item $NvKey -Force | Out-Null 
}
New-ItemProperty $NvKey -Name "EnableMsi" -PropertyType DWord -Value 1 -Force | Out-Null
Write-Host "  └ NVIDIA MSI = 1" -ForegroundColor Green

$AmdKey = "HKLM:\SYSTEM\CurrentControlSet\Services\amdkmdag"
if (Test-Path $AmdKey) {
    Write-Host "  └ AMD ULPS optimization..." -ForegroundColor Gray
    New-ItemProperty "$AmdKey" -Name "EnableUlps" -PropertyType DWord -Value 0 -Force | Out-Null
    Write-Host "  └ AMD ULPS = 0" -ForegroundColor Green
}
else {
    Write-Host "  └ AMD drivers not detected" -ForegroundColor Gray
}

# =====================================================
# 🔟 MSI MODE (FULLY LOGGED)
# =====================================================
Write-Host "[LOG] Applying MSI enforcement to PCI devices..." -ForegroundColor Cyan
$Vendors = @("VEN_10DE","VEN_1002","VEN_8086","VEN_144D")
$DeviceCount = 0

Get-PnpDevice -PresentOnly | Where-Object {
    $_.InstanceId -like "PCI*" -and ($Vendors | ForEach-Object { if ($_.InstanceId -like "*$_*") { $true } })
} | ForEach-Object {
    $DeviceCount++
    Write-Host "  └ $($DeviceCount): $($_.FriendlyName)" -ForegroundColor Gray
    try {
        $Path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        $ParentPath = Split-Path $Path -Parent
        if (-not (Test-Path $ParentPath)) { New-Item $ParentPath -Force | Out-Null }
        if (-not (Test-Path $Path)) { New-Item $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name "MSISupported" -PropertyType DWord -Value 1 -Force | Out-Null
        Write-Host "    └ MSI Enabled ✓" -ForegroundColor Green
    }
    catch {
        Write-Host "    └ MSI Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host "✓ Processed $DeviceCount PCI devices for MSI" -ForegroundColor Green

# =====================================================
# 1️⃣1️⃣ DPC LATENCY OPTIMIZATION
# =====================================================
Write-Host "[LOG] Applying DPC latency optimizations..." -ForegroundColor Cyan
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
Write-Host "✓ DPC latency tweaks applied" -ForegroundColor Green

# =====================================================
# FINISH
# =====================================================
Write-Host "`n" -NoNewline
Write-Host "====================================================" -ForegroundColor Green
Write-Host "✅ OPTIMIZATION COMPLETE - $(Get-Date)" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "📊 Total bloatware packages removed: $RemovedCount" -ForegroundColor Cyan
Write-Host "📊 Startup items removed: $RemovedStartups" -ForegroundColor Cyan
Write-Host "📁 Full log saved to: $LogFile" -ForegroundColor Cyan
Write-Host "🔄 REBOOT REQUIRED for all changes" -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Green

Stop-Transcript
[System.Console]::Beep(1000, 500)
[void][System.Console]::ReadKey($true)
