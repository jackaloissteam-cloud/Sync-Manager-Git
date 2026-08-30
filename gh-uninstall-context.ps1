# =====================================================================
#  Rechtsklick-Uninstaller
#  Entfernt "Senden an"-Shortcuts und HKCU-Kontextmenue-Eintraege.
# =====================================================================

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "=== Rechtsklick-Uninstaller ===" -ForegroundColor Cyan

# SendTo
$SendTo = [Environment]::GetFolderPath('SendTo')
foreach ($n in @("GitHub Push","GitHub Sync")) {
    $lnk = Join-Path $SendTo "$n.lnk"
    if (Test-Path $lnk) { Remove-Item $lnk -Force; Write-Host "  - SendTo entfernt: $n" -ForegroundColor Yellow }
}

# HKCU keys
$keys = @(
    "HKCU:\Software\Classes\Directory\shell\GhPush",
    "HKCU:\Software\Classes\Directory\shell\GhSync",
    "HKCU:\Software\Classes\Directory\Background\shell\GhPush",
    "HKCU:\Software\Classes\Directory\Background\shell\GhSync"
)
foreach ($k in $keys) {
    if (Test-Path $k) { Remove-Item -Path $k -Recurse -Force; Write-Host "  - Registry entfernt: $k" -ForegroundColor Yellow }
}

Write-Host ""
Write-Host "Uninstall abgeschlossen." -ForegroundColor Green
Read-Host "Enter zum Schliessen"
