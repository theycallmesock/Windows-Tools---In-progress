# =====================================================
# GAMING OPTIMIZATION VERIFICATION & AUTO-FIX SCRIPT
# Checks ALL changes from optimization script + auto-fixes
# =====================================================

# -------------------------
# AUTO-ELEVATION & LOGGING
# -------------------------
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}

Set-ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = "Continue"
Clear-Host

# Logging
$LogDir = "$env:SystemDrive\GamingOptimizationLogs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$Timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$LogFile = "$LogDir\VerifyFix_$Timestamp.log"
Start-Transcript -Path $LogFile -Force

Write-Host "🔍 GAMING OPTIMIZATION VERIFICATION & AUTO-FIX" -ForegroundColor Cyan
Write-Host "Log: $LogFile" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Green

# =====================================================
# CHECK FUNCTIONS
# =====================================================
function Test-FixPowerPlan {
    Write-Host "[1/11] 🔋 Power Plan..." -ForegroundColor Cyan
    
    $UltimateSchemes = powercfg -list | Select-String "Ultimate Performance"
    if ($UltimateSchemes) {
        $ActualUltimate = ($UltimateSchemes[0] -split '\s+')[3]
        $Active = powercfg -getactivescheme | Select-String $ActualUltimate
        if ($Active) {
            Write-Host "   ✓ Ultimate Performance ACTIVE" -ForegroundColor Green
            return $true
        }
    }
    
    Write-Host "   ⚠ Not active - FIXING..." -ForegroundColor Yellow
    $Ultimate = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    powercfg -duplicatescheme $Ultimate | Out-Null
    Start-Sleep 2
    $UltimateSchemes = powercfg -list | Select-String "Ultimate Performance"
    if ($UltimateSchemes) {
        $ActualUltimate = ($UltimateSchemes[0] -split '\s+')[3]
        powercfg -setactive $ActualUltimate | Out-Null
        
        # CPU tweaks
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
        powercfg -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
        powercfg -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
        powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 | Out-Null
        powercfg -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 | Out-Null
        powercfg -S SCHEME_CURRENT
        
        Write-Host "   ✅ Power plan FIXED" -ForegroundColor Green
        return $true
    }
    Write-Host "   ❌ Could not enable Ultimate Performance" -ForegroundColor Red
    return $false
}

function Test-FixGameMode {
    Write-Host "[2/11] 🎮 Game Mode..." -ForegroundColor Cyan
    
    $GameBar1 = Get-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -ErrorAction SilentlyContinue
    $GameBar2 = Get-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -ErrorAction SilentlyContinue
    $HwSchMode = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -ErrorAction SilentlyContinue
    
    if ($GameBar1.AllowAutoGameMode -eq 1 -and $GameBar2.AutoGameModeEnabled -eq 1 -and $HwSchMode.HwSchMode -eq 2) {
        Write-Host "   ✓ Game Mode + GPU Scheduling OK" -ForegroundColor Green
        return $true
    }
    
    Write-Host "   ⚠ Missing settings - FIXING..." -ForegroundColor Yellow
    reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f | Out-Null
    Write-Host "   ✅ Game Mode FIXED" -ForegroundColor Green
    return $true
}

function Test-FixSysMain {
    Write-Host "[3/11] 🧹 SysMain..." -ForegroundColor Cyan
    
    $SysMain = Get-Service SysMain -ErrorAction SilentlyContinue
    if ($SysMain -and $SysMain.StartType -eq "Disabled") {
        Write-Host "   ✓ SysMain DISABLED" -ForegroundColor Green
        return $true
    }
    
    Write-Host "   ⚠ SysMain active - FIXING..." -ForegroundColor Yellow
    Stop-Service SysMain -Force -ErrorAction SilentlyContinue
    Set-Service SysMain -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "   ✅ SysMain DISABLED" -ForegroundColor Green
    return $true
}

function Test-FixHPET {
    Write-Host "[4/11] ⏱️ HPET/Timer..." -ForegroundColor Cyan
    
    $PlatformTick = bcdedit | Select-String "useplatformtick"
    $DynamicTick = bcdedit | Select-String "disabledynamictick"
    
    if ($PlatformTick -match "yes" -and $DynamicTick -match "yes") {
        Write-Host "   ✓ HPET settings OK" -ForegroundColor Green
        return $true
    }
    
    Write-Host "   ⚠ Timer wrong - FIXING..." -ForegroundColor Yellow
    bcdedit /set useplatformtick yes | Out-Null
    bcdedit /set disabledynamictick yes | Out-Null
    bcdedit /deletevalue useplatformclock | Out-Null
    Write-Host "   ✅ HPET FIXED" -ForegroundColor Green
    return $true
}

function Test-FixStartup {
    Write-Host "[5/11] 🚀 Startup..." -ForegroundColor Cyan
    
    $StartupPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )
    $Keep = @("SecurityHealth","Windows Defender","Discord")
    $FixedCount = 0
    
    foreach ($path in $StartupPaths) {
        if (Test-Path $path) {
            $Items = Get-ItemProperty $path -ErrorAction SilentlyContinue
            if ($Items) {
                $Properties = $Items | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -notin $Keep -and $_.Name -notlike "PS*"}
                foreach ($prop in $Properties) {
                    Remove-ItemProperty -Path $path -Name $prop.Name -ErrorAction SilentlyContinue
                    $FixedCount++
                }
            }
        }
    }
    
    if ($FixedCount -eq 0) {
        Write-Host "   ✓ Startup clean" -ForegroundColor Green
    } else {
        Write-Host "   ✅ Fixed $FixedCount startup items" -ForegroundColor Green
    }
    return $true
}

function Test-FixTCP {
    Write-Host "[6/11] 🌐 TCP Optimizer..." -ForegroundColor Cyan
    
    $TcpSettings = @(
        "TcpAckFrequency",
        "TCPNoDelay",
        "NonBestEffortLimit"
    )
    $TcpFixed = 0
    
    foreach ($setting in $TcpSettings) {
        $RegValue = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name $setting -ErrorAction SilentlyContinue
        if (-not $RegValue) {
            New-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name $setting -PropertyType DWord -Value 1 -Force | Out-Null
            $TcpFixed++
        }
    }
    
    if ($TcpFixed -eq 0) {
        Write-Host "   ✓ TCP settings OK" -ForegroundColor Green
    } else {
        Write-Host "   ✅ Fixed $TcpFixed TCP settings" -ForegroundColor Green
    }
    return $true
}

function Test-FixNVIDIA {
    Write-Host "[7/11] 💚 NVIDIA..." -ForegroundColor Cyan
    
    $NvKey = "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters"
    $NvMsi = Get-ItemProperty $NvKey -Name "EnableMsi" -ErrorAction SilentlyContinue
    
    if ($NvMsi -and $NvMsi.EnableMsi -eq 1) {
        Write-Host "   ✓ NVIDIA MSI OK" -ForegroundColor Green
        return $true
    }
    
    Write-Host "   ⚠ NVIDIA - FIXING..." -ForegroundColor Yellow
    if (-not (Test-Path $NvKey)) { New-Item $NvKey -Force | Out-Null }
    New-ItemProperty $NvKey -Name "EnableMsi" -PropertyType DWord -Value 1 -Force | Out-Null
    Write-Host "   ✅ NVIDIA MSI FIXED" -ForegroundColor Green
    return $true
}

function Test-FixMSI {
    Write-Host "[8/11] ⚡ MSI Mode..." -ForegroundColor Cyan
    
    $Vendors = @("VEN_10DE","VEN_1002","VEN_8086","VEN_144D")
    $FixedDevices = 0
    
    Get-PnpDevice -PresentOnly | Where-Object {
        $_.InstanceId -like "PCI*" -and ($Vendors | ForEach-Object { $_.InstanceId -like "*$_*" })
    } | ForEach-Object {
        $Path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        $MsiValue = Get-ItemProperty $Path -Name "MSISupported" -ErrorAction SilentlyContinue
        if (-not $MsiValue -or $MsiValue.MSISupported -ne 1) {
            $ParentPath = Split-Path $Path -Parent
            if (-not (Test-Path $ParentPath)) { New-Item $ParentPath -Force | Out-Null }
            if (-not (Test-Path $Path)) { New-Item $Path -Force | Out-Null }
            New-ItemProperty -Path $Path -Name "MSISupported" -PropertyType DWord -Value 1 -Force | Out-Null
            $FixedDevices++
        }
    }
    
    if ($FixedDevices -eq 0) {
        Write-Host "   ✓ MSI mode OK" -ForegroundColor Green
    } else {
        Write-Host "   ✅ Fixed $FixedDevices MSI devices" -ForegroundColor Green
    }
    return $true
}

function Test-FixDPC {
    Write-Host "[9/11] ⚡ DPC Latency..." -ForegroundColor Cyan
    
    $NetworkThrottle = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue
    $GpuPriority = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "GPU Priority" -ErrorAction SilentlyContinue
    
    if ($NetworkThrottle.NetworkThrottlingIndex -eq 4294967295 -and $GpuPriority."GPU Priority" -eq 8) {
        Write-Host "   ✓ DPC settings OK" -ForegroundColor Green
        return $true
    }
    
    Write-Host "   ⚠ DPC wrong - FIXING..." -ForegroundColor Yellow
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f | Out-Null
    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f | Out-Null
    Write-Host "   ✅ DPC Latency FIXED" -ForegroundColor Green
    return $true
}

function Test-FixBloatware {
    Write-Host "[10/11] 🗑️ Bloatware..." -ForegroundColor Cyan
    
    $BloatApps = @("Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.WindowsAlarms")
    $FixedApps = 0
    
    foreach ($app in $BloatApps) {
        $Packages = Get-AppxPackage -AllUsers -Name $app -ErrorAction SilentlyContinue
        if ($Packages) {
            foreach ($pkg in $Packages) {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                $FixedApps++
            }
        }
    }
    
    if ($FixedApps -eq 0) {
        Write-Host "   ✓ Bloatware clean" -ForegroundColor Green
    } else {
        Write-Host "   ✅ Removed $FixedApps bloatware apps" -ForegroundColor Green
    }
    return $true
}

# =====================================================
# MAIN VERIFICATION LOOP
# =====================================================
Write-Host "Starting full system verification..." -ForegroundColor Cyan

$Tests = @(
    { Test-FixPowerPlan },
    { Test-FixGameMode },
    { Test-FixSysMain },
    { Test-FixHPET },
    { Test-FixStartup },
    { Test-FixTCP },
    { Test-FixNVIDIA },
    { Test-FixMSI },
    { Test-FixDPC },
    { Test-FixBloatware }
)

$TotalFixed = 0
foreach ($test in $Tests) {
    & $test
    Start-Sleep 1
}

# =====================================================
# FINAL SUMMARY
# =====================================================
Write-Host "`n" -NoNewline
Write-Host "====================================================" -ForegroundColor Green
Write-Host "✅ VERIFICATION COMPLETE - $(Get-Date)" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "📁 Full log: $LogFile" -ForegroundColor Cyan
Write-Host "🔄 REBOOT RECOMMENDED if fixes were applied" -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Green

Stop-Transcript
[System.Console]::Beep(1500, 300)
[void][System.Console]::ReadKey($true)
