# FinalBoss Mod Release Builder
# Creates two zips in releases/<version>/:
#   FinalBoss-<version>.zip     mod only, in a FinalBoss/ folder (GitHub release, manual install)
#   FinalBoss-<version>-TS.zip  Thunderstore package (manifest.json + icon.png at the root)

param(
    [string]$versionName,
    [switch]$NoPause
)

function Exit-Script([int]$code) {
    if (-not $NoPause) { Read-Host "Press Enter to exit" }
    exit $code
}

Set-Location $PSScriptRoot

# Default to the version in FinalBoss.json
$modVersion = (Get-Content "FinalBoss.json" -Raw | ConvertFrom-Json).version
if ([string]::IsNullOrWhiteSpace($versionName)) {
    $versionName = Read-Host "Enter version name (Enter for v$modVersion)"
    if ([string]::IsNullOrWhiteSpace($versionName)) { $versionName = "v$modVersion" }
}

# FinalBoss.json and manifest.json must agree with the release
$tsVersion = (Get-Content "manifest.json" -Raw | ConvertFrom-Json).version_number
if ($versionName.TrimStart('v') -ne $modVersion -or $tsVersion -ne $modVersion) {
    Write-Host "Error: version mismatch (release $versionName, FinalBoss.json $modVersion, manifest.json $tsVersion)" -ForegroundColor Red
    Exit-Script 1
}

$cleanVersionName = $versionName -replace '[<>:"/\\|?*]', '_'
$versionDir = Join-Path "releases" $cleanVersionName
if (Test-Path $versionDir) {
    Write-Host "Version directory already exists, cleaning..." -ForegroundColor Yellow
    Remove-Item -Path "$versionDir\*" -Recurse -Force
}
else {
    New-Item -ItemType Directory -Path $versionDir -Force | Out-Null
}

$zipFileName = Join-Path $versionDir "FinalBoss-$cleanVersionName.zip"
$zipFileNameTS = Join-Path $versionDir "FinalBoss-$cleanVersionName-TS.zip"

# What the game loads, plus the docs that travel with the mod
$modFiles = @("FinalBoss.json", "main.lua", "config.lua", "src", "assets", "localization", "lovely", "README.md", "CHANGELOG.md", "LICENSE")
$tsExtras = @("manifest.json", "icon.png")

foreach ($file in $modFiles + $tsExtras) {
    if (-not (Test-Path $file)) {
        Write-Host "Error: $file not found!" -ForegroundColor Red
        Exit-Script 1
    }
}

$tempDir1 = "temp_release_mod_$((Get-Date).Ticks)"
$tempDir2 = "temp_release_ts_$((Get-Date).Ticks)"
try {
    Write-Host "Creating mod-only package..." -ForegroundColor Green
    $modFolder = Join-Path $tempDir1 "FinalBoss"
    New-Item -ItemType Directory -Path $modFolder -Force | Out-Null
    foreach ($file in $modFiles) { Copy-Item -Path $file -Destination $modFolder -Recurse -Force }
    Compress-Archive -Path "$tempDir1\*" -DestinationPath $zipFileName -Force
    Write-Host "Successfully created $zipFileName" -ForegroundColor Green

    Write-Host "Creating Thunderstore package..." -ForegroundColor Green
    New-Item -ItemType Directory -Path $tempDir2 -Force | Out-Null
    foreach ($file in $modFiles + $tsExtras) { Copy-Item -Path $file -Destination $tempDir2 -Recurse -Force }
    Compress-Archive -Path "$tempDir2\*" -DestinationPath $zipFileNameTS -Force
    Write-Host "Successfully created $zipFileNameTS" -ForegroundColor Green
}
catch {
    Write-Host "Error creating zip files: $($_.Exception.Message)" -ForegroundColor Red
    Exit-Script 1
}
finally {
    foreach ($dir in @($tempDir1, $tempDir2)) {
        if (Test-Path $dir) { Remove-Item -Path $dir -Recurse -Force }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Both release builds complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Created files in releases/$cleanVersionName/:" -ForegroundColor Cyan
Write-Host "  * FinalBoss-$cleanVersionName.zip (mod only)" -ForegroundColor White
Write-Host "  * FinalBoss-$cleanVersionName-TS.zip (Thunderstore package)" -ForegroundColor White
Exit-Script 0
