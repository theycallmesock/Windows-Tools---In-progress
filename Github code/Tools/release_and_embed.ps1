<#
Safe release automation script (PowerShell).
- Builds Updater helper
- Copies Updater.exe to Tools\embedded\Updater.exe
- Builds & publishes main single-file exe
- Computes SHA256 of published exe
- Creates GitHub release and uploads exe (requires gh CLI logged in)
- Generates appupdate.json and commits it to the repo (optional, uses git)

Usage:
  pwsh .\Tools\release_and_embed.ps1 -Version "1.0.1" -Tag "v1.0.1" -Repo "theycallmesock/Windows-Tools---In-progress" -Notes "Release notes..."

Requirements:
- .NET 8 SDK installed
- gh (GitHub CLI) installed and logged in (gh auth login)
- git available and repo is clean or you understand commits made by script
- Run from repository root

Security:
- Script does not embed binary into csproj automatically. Ensure TCMS.Optimizer.csproj already has the EmbeddedResource entry
  (the patch included does this).
- Review before running. The script will create and push an appupdate.json to your repo if you allow it.
#>

param(
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$true)][string]$Tag,
    [Parameter(Mandatory=$true)][string]$Repo,
    [string]$Notes = "Release created by release_and_embed.ps1",
    [string]$MainProject = "TCMS.Optimizer.csproj",
    [string]$UpdaterProject = "Updater/Updater.csproj",
    [string]$OutDir = "publish",
    [switch]$PushAppManifest
)

Set-StrictMode -Version Latest

Write-Host "Release script started. Version=$Version Tag=$Tag Repo=$Repo"

# 1) Build Updater helper
Write-Host "Publishing Updater helper..."
dotnet publish $UpdaterProject -c Release -r win-x64 --self-contained false -o out/updater
if ($LASTEXITCODE -ne 0) { throw "Failed to publish Updater" }

# 2) Copy updater exe to Tools\embedded
$embeddedDir = Join-Path -Path "." -ChildPath "Tools\embedded"
if (-not (Test-Path $embeddedDir)) { New-Item -ItemType Directory -Path $embeddedDir | Out-Null }

$srcUpdater = Join-Path -Path "." -ChildPath "out/updater/Updater.exe"
$destUpdater = Join-Path -Path $embeddedDir -ChildPath "Updater.exe"
if (-not (Test-Path $srcUpdater)) { throw "Updater.exe not found at $srcUpdater" }

Copy-Item -Path $srcUpdater -Destination $destUpdater -Force
Write-Host "Copied Updater.exe to $destUpdater"

# 3) Rebuild main project (embedding updater as resource included in csproj)
Write-Host "Publishing main project..."
dotnet publish $MainProject -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:PublishTrimmed=false -o $OutDir
if ($LASTEXITCODE -ne 0) { throw "Failed to publish main exe" }

$exePath = Join-Path -Path $OutDir -ChildPath "TCMS_Optimizer.exe"
if (-not (Test-Path $exePath)) { throw "Published exe not found at $exePath" }

Write-Host "Published exe at $exePath"

# 4) Compute SHA256
Write-Host "Computing SHA256..."
$hash = (Get-FileHash -Algorithm SHA256 $exePath).Hash.ToLower()
Write-Host "SHA256: $hash"

# 5) Create GitHub release (using gh CLI)
$releaseTitle = $Tag
Write-Host "Creating release $Tag and uploading exe..."
# Use gh to create release and upload exe in one command
$createArgs = @("release", "create", $Tag, $exePath, "--repo", $Repo, "--title", $releaseTitle, "--notes", $Notes)
$proc = Start-Process -FilePath "gh" -ArgumentList $createArgs -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0) { throw "gh release create failed with exit code $($proc.ExitCode)" }

Write-Host "Release created."

# 6) Write appupdate.json locally (template) — will use the release asset URL
$releaseUrl = "https://github.com/$Repo/releases/download/$Tag/TCMS_Optimizer.exe"
$appupdate = @{
    version = $Version
    url = $releaseUrl
    sha256 = $hash
    notes = $Notes
}
$appupdateJson = $appupdate | ConvertTo-Json -Depth 4
$appupdatePath = "appupdate.json"
Set-Content -Path $appupdatePath -Value $appupdateJson -Encoding UTF8
Write-Host "Wrote $appupdatePath with computed SHA256."

# 7) Optionally commit and push appupdate.json
if ($PushAppManifest.IsPresent) {
    Write-Host "Committing and pushing appupdate.json to repo..."
    git add $appupdatePath
    git commit -m "Add appupdate manifest $Version"
    git push origin HEAD
    if ($LASTEXITCODE -ne 0) { Write-Warning "git push had a non-zero exit code." }
    else { Write-Host "appupdate.json pushed." }
}
else {
    Write-Host "appupdate.json is created locally. Add and push it to your repo when ready (or run with -PushAppManifest)."
}

Write-Host "Release script completed successfully."